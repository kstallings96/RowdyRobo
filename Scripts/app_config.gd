extends Node

## Supabase credentials, loaded at runtime rather than baked into the export.
##
## On web the file is fetched from the deployed origin, so an existing build can
## be pointed at a different Supabase project by editing one file in the repo and
## redeploying — no re-export, no Godot needed. Everywhere else it is read from
## res://config.json, which ships inside the .pck.
##
## The anon key is PUBLIC by design. It is visible in devtools on any Supabase
## app, and row-level security (supabase/schema.sql) is what protects the data.
## The service_role key must NEVER appear in this file, this project, or the
## repo — it bypasses row-level security completely.

signal loaded

const CONFIG_PATH := "res://config.json"

var supabase_url: String = ""
var supabase_anon_key: String = ""
var is_loaded: bool = false

var _http: HTTPRequest


func _ready() -> void:
	if OS.has_feature("web"):
		_load_from_origin()
	else:
		_apply(_read_bundled())
		_finish()


## True when there is somewhere to send data. Everything in Backend is a no-op
## when this is false, which is the offline-classroom path: the game runs, the
## events queue locally, nothing throws.
func is_configured() -> bool:
	return supabase_url != "" and supabase_anon_key != ""


func _read_bundled() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Fetches /config.json from the page's own origin. Falls back to the bundled
## copy if the request fails, so a missing file on the host degrades to whatever
## was exported rather than to a hard error.
func _load_from_origin() -> void:
	var origin := ""
	if OS.has_feature("web"):
		var result: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if result != null:
			origin = str(result)

	if origin == "":
		_apply(_read_bundled())
		_finish()
		return

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_config_fetched)

	var error := _http.request(origin + "/config.json")
	if error != OK:
		_apply(_read_bundled())
		_finish()


func _on_config_fetched(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data := {}
	if code == 200:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			data = parsed

	if data.is_empty():
		data = _read_bundled()

	_apply(data)
	_finish()


func _apply(data: Dictionary) -> void:
	supabase_url = str(data.get("supabase_url", "")).strip_edges().rstrip("/")
	supabase_anon_key = str(data.get("supabase_anon_key", "")).strip_edges()


func _finish() -> void:
	is_loaded = true
	if is_configured():
		print("AppConfig: Supabase configured (%s)" % supabase_url)
	else:
		print("AppConfig: no Supabase credentials — running offline, events stay local")
	loaded.emit()
