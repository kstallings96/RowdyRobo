extends Control

@onready var leaderboard_vbox = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/LeaderboardVbox")

const ENTRY_LIMIT := 10

var all_scores: Array = []


func _ready() -> void:
	# Desktop keeps its local copy: on a lab machine the CSV is still the
	# fastest way to see what happened without opening a browser. On web the
	# file lives in the student's own IndexedDB and is never read back.
	if not OS.has_feature("web"):
		_load_local_scores()

	var student = Global.current_student
	if student == null:
		push_warning("Leaderboard: no student in cache")
		_render([])
		return

	var performance: float = 0.0
	if not student.performance_history.is_empty():
		performance = student.performance_history[-1]

	# One decimal place, as a percentage — the same number the screen shows.
	var percentage := snappedf(performance * 100.0, 0.1)

	await Backend.submit_score(student.first_name, percentage)

	# Reaching this screen is what "completed the study" means. The window-close
	# handler emits one too for an early exit; a duplicate is harmless, since
	# analysis derives completion with bool_or.
	Backend.log_event(Backend.EVENT_SESSION_END, {"performance": percentage})
	await Backend.flush_all()

	var entries := await Backend.fetch_leaderboard(ENTRY_LIMIT)

	# With no backend configured there is nothing to read back, so fall back to
	# whatever this device recorded locally rather than showing an empty board.
	if entries.is_empty() and not all_scores.is_empty():
		entries = all_scores

	_render(entries)


func _render(entries: Array) -> void:
	if leaderboard_vbox == null:
		push_warning("Leaderboard: LeaderboardVbox not found")
		return

	for child in leaderboard_vbox.get_children():
		child.queue_free()

	var font := FontFile.new()
	font.font_data = load("res://Fonts/KGRedHands.ttf")

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var player_name := str(entry.get("display_name", "Unknown"))
		var player_score := float(entry.get("score", 0.0))

		var label := Label.new()
		label.text = "%d. %s - %s%%" % [i + 1, player_name, snappedf(player_score, 0.1)]
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 80)
		label.add_theme_color_override("font_color", Color.BLACK)
		leaderboard_vbox.add_child(label)


## Reads the desktop CSV into the same {display_name, score} shape the backend
## returns, so `_render` does not care which source it got.
func _load_local_scores() -> void:
	var rows := _load_csv_as_array(Paths.CSV_PATH)
	for row in rows:
		if row.size() <= 4:
			continue
		var performances = str_to_var(row[4])
		if performances is Array and not performances.is_empty():
			all_scores.append({
				"display_name": row[0],
				"score": snappedf(float(performances[-1]) * 100.0, 0.1),
			})

	all_scores.sort_custom(func(a, b): return a["score"] > b["score"])
	if all_scores.size() > ENTRY_LIMIT:
		all_scores.resize(ENTRY_LIMIT)


func _load_csv_as_array(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		return []

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Leaderboard: could not open %s (%s)" % [
			file_path, error_string(FileAccess.get_open_error())
		])
		return []

	var rows: Array = []
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if not line.is_empty():
			rows.append(line)
	file.close()
	return rows


func _on_retry_button_pressed() -> void:
	get_tree().change_scene_to_file(Paths.PHASE3)
