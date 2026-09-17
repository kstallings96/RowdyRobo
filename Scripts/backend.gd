extends Node

## Append-only event log with a durable queue, talking to the Supabase REST API.
##
## School wifi drops, so the game never blocks on a network call. Events are
## appended in memory, mirrored to user:// immediately, and flushed in batches.
## Nothing leaves the queue until the server has confirmed it, and anything
## stranded by a previous session is sent before anything new.
##
## On a web export user:// is IndexedDB, which is exactly the durable local
## mirror this needs — a student can close the tab mid-phase and the events from
## before the crash still go up on the next load.
##
## With no credentials every call here is a no-op and events simply accumulate
## locally. That is deliberate: a classroom with no wifi must still be able to
## run the study.

const QUEUE_PATH := "user://event_queue.json"
const SESSION_PATH := "user://session.json"
const BATCH_SIZE := 20
const FLUSH_SECONDS := 5.0

# Event taxonomy. Anything not in this list is still accepted — the column is
# plain text and the payload is JSONB — but keeping the known set in one place
# makes the analysis queries in supabase/schema.sql legible.
const EVENT_SESSION_START := "session_start"
const EVENT_PHASE_ENTER := "phase_enter"
const EVENT_PHASE_COMPLETE := "phase_complete"
const EVENT_BLOCK_PLACED := "block_placed"
const EVENT_BLOCK_REMOVED := "block_removed"
const EVENT_CODE_RUN := "code_run"
const EVENT_CODE_SUBMIT := "code_submit"
# Per-piece trash pickups are deliberately not logged: a level holds hundreds of
# them and the resulting flood would bury the code events, which are the actual
# computational-thinking signal. The totals ride along on phase_complete.
const EVENT_SESSION_END := "session_end"

var session_id: String = ""

var _queue: Array = []
var _seq: int = 0
var _flushing: bool = false
var _flush_timer: Timer

var _queue_http: HTTPRequest
var _session_http: HTTPRequest
var _score_http: HTTPRequest
var _board_http: HTTPRequest


func _ready() -> void:
	_queue_http = _make_http()
	_session_http = _make_http()
	_score_http = _make_http()
	_board_http = _make_http()

	_restore()

	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_SECONDS
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_on_flush_timer)
	add_child(_flush_timer)

	if not AppConfig.is_loaded:
		await AppConfig.loaded

	# Anything left over from a previous run goes up before anything new.
	flush()


func _make_http() -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	return http


# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------

## Starts (or resumes) a session and inserts the `sessions` row.
##
## The id is persisted, so a reload mid-study resumes the same participant
## rather than creating a second one. The insert is retried on every start and
## a duplicate-key response counts as success — that IS the reload case.
func start_session(first_name: String, last_initial: String, grade: String) -> String:
	var resumed := session_id != ""
	if not resumed:
		session_id = _uuid_v4()
		_persist_session()

	var row := {
		"id": session_id,
		"first_name": first_name,
		"last_initial": last_initial,
		"grade": grade,
		"user_agent": _user_agent(),
		"screen_w": DisplayServer.window_get_size().x,
		"screen_h": DisplayServer.window_get_size().y,
	}

	if not resumed:
		log_event(EVENT_SESSION_START, {"grade": grade})

	_insert_session(row)
	return session_id


func _insert_session(row: Dictionary) -> void:
	if not AppConfig.is_configured():
		return
	var error := _session_http.request(
		_rest_url("sessions"),
		_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(row)
	)
	if error != OK:
		push_warning("Backend: session insert could not be sent (%d)" % error)


## Ends the session and makes a best effort to get the tail of the queue up
## before the process goes away.
func end_session() -> void:
	log_event(EVENT_SESSION_END, {})
	await flush_all()


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

## Appends an event. Never blocks, never throws, never surfaces a network error
## to the student. `seq` is monotonic per session so a gap in the data is
## visible in analysis rather than silent.
func log_event(type: String, payload: Dictionary = {}) -> void:
	if session_id == "":
		# No session yet — the main menu has not been completed. Dropping is
		# correct here: events must reference a sessions row.
		return

	_seq += 1
	_queue.append({
		"session_id": session_id,
		"seq": _seq,
		"type": type,
		"payload": payload,
		"client_ts": Time.get_datetime_string_from_system(true, false) + "Z",
	})
	_persist_queue()

	if _queue.size() >= BATCH_SIZE:
		flush()


func _on_flush_timer() -> void:
	flush()


## Sends what it can; anything that fails stays queued for the next attempt.
func flush() -> void:
	if _flushing or _queue.is_empty():
		return
	# With no backend configured there is nowhere to send them, and dropping
	# them here would silently empty the local rescue copy.
	if not AppConfig.is_configured():
		return

	_flushing = true
	var batch: Array = _queue.slice(0, BATCH_SIZE)

	var error := _queue_http.request(
		_rest_url("events"),
		_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(batch)
	)
	if error != OK:
		_flushing = false
		return

	var response: Array = await _queue_http.request_completed
	var code: int = response[1]
	var body: PackedByteArray = response[3]

	if _is_insert_ok(code, body):
		_queue = _queue.slice(batch.size())
		_persist_queue()

	_flushing = false


## Drains the whole queue rather than one batch. Used at session end, where it
## is worth waiting.
func flush_all() -> void:
	var guard := 0
	while not _queue.is_empty() and guard < 50:
		var before := _queue.size()
		await flush()
		if _queue.size() == before:
			break  # Not making progress — the network is gone. Leave it queued.
		guard += 1


# ---------------------------------------------------------------------------
# Leaderboard
# ---------------------------------------------------------------------------

## Submits the student's final percentage to the leaderboard's backing table.
func submit_score(display_name: String, score: float) -> void:
	if not AppConfig.is_configured() or session_id == "":
		return

	var row := {
		"session_id": session_id,
		"display_name": display_name,
		"score": score,
	}

	var error := _score_http.request(
		_rest_url("scores"),
		_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(row)
	)
	if error != OK:
		return
	await _score_http.request_completed


## Reads the top scores back. This is the only read the anon key is allowed —
## it goes through the `leaderboard` view, which exposes a display name and a
## percentage and nothing else. See supabase/schema.sql.
##
## Returns an array of {display_name, score}, highest first. Empty on any
## failure, which the caller should treat as "show nothing" rather than an error.
func fetch_leaderboard(limit: int = 10) -> Array:
	if not AppConfig.is_configured():
		return []

	var url := "%s/rest/v1/leaderboard?select=display_name,score&order=score.desc&limit=%d" % [
		AppConfig.supabase_url, limit
	]

	var error := _board_http.request(url, _read_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		return []

	var response: Array = await _board_http.request_completed
	var code: int = response[1]
	var body: PackedByteArray = response[3]

	if code != 200:
		push_warning("Backend: leaderboard fetch failed (%d)" % code)
		return []

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed is Array else []


# ---------------------------------------------------------------------------
# Local rescue copy
# ---------------------------------------------------------------------------

## Everything logged this session that has not been confirmed by the server.
## The desktop build writes this alongside the CSV so a device that never
## reached the network still has its data on disk.
func pending_events() -> Array:
	return _queue.duplicate(true)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _rest_url(table: String) -> String:
	return "%s/rest/v1/%s" % [AppConfig.supabase_url, table]


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + AppConfig.supabase_anon_key,
		"Authorization: Bearer " + AppConfig.supabase_anon_key,
		"Content-Type: application/json",
		"Prefer: return=minimal",
	])


## Reads must not send `Prefer: return=minimal` — PostgREST honours it on a GET
## too and answers with an empty body, which would blank the leaderboard with no
## error to show for it.
func _read_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + AppConfig.supabase_anon_key,
		"Authorization: Bearer " + AppConfig.supabase_anon_key,
		"Accept: application/json",
	])


## 201 is the happy path. 409 with SQLSTATE 23505 is a unique violation, which
## means the row is already there because the student reloaded — as far as we
## are concerned that is success, and retrying forever would wedge the queue.
func _is_insert_ok(code: int, body: PackedByteArray) -> bool:
	if code == 201 or code == 200 or code == 204:
		return true
	if code == 409:
		return body.get_string_from_utf8().find("23505") != -1
	push_warning("Backend: insert failed (%d) %s" % [code, body.get_string_from_utf8()])
	return false


func _restore() -> void:
	var queue_data: Variant = _read_json(QUEUE_PATH)
	if queue_data is Dictionary:
		var stored: Variant = queue_data.get("queue", [])
		_queue = stored if stored is Array else []
		_seq = int(queue_data.get("seq", 0))

	var session_data: Variant = _read_json(SESSION_PATH)
	if session_data is Dictionary:
		session_id = str(session_data.get("id", ""))


func _persist_queue() -> void:
	_write_json(QUEUE_PATH, {"queue": _queue, "seq": _seq})


func _persist_session() -> void:
	_write_json(SESSION_PATH, {"id": session_id})


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		# Storage blocked or full. The in-memory queue still flushes; we only
		# lose the crash-recovery guarantee, which beats throwing at a student.
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _user_agent() -> String:
	if OS.has_feature("web"):
		var result: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
		if result != null:
			return str(result)
	return "%s %s" % [OS.get_name(), OS.get_version()]


## Godot has no built-in UUID. This is a v4 with the version and variant bits
## set, which is what Postgres's uuid type will accept.
func _uuid_v4() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in range(16):
		bytes[i] = randi() % 256

	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80

	var hex := ""
	for i in range(16):
		hex += "%02x" % bytes[i]

	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]
