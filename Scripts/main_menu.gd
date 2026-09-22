extends Control

## The instructor's key. KSS17 opens every tool in the week — this one,
## VibeBuilder and CTx3 — so a facilitator can demo or test a station without
## borrowing a student's card. It is the same shape as a student code; what
## keeps it from ever being handed to a student is that the roster generator
## never emits the digits 0 or 1 — they are misread as O and I off a printed
## card — and this key contains a 1.
const INSTRUCTOR_CODE := "KSS17"

@onready var code_box = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/ParticipantCodeLineEdit
@onready var status_label = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/StatusLabel
@onready var start_button = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/StartButton
@onready var first_name_box = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/FirstNameLineEdit
@onready var last_name_box = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/LastNameLineEdit
@onready var grade_dropdown = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/GradeOptionButton


## What the student typed, as a participant code — or "" if it could never be
## one. Cards get read by 11-14 year olds, so lowercase, spaces and stray
## dashes are forgiven; anything still not code-shaped is a typo every time,
## and is rejected here before the roster is asked.
func _normalize_code(raw: String) -> String:
	var cleaned := ""
	for ch in raw.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			cleaned += ch
	if cleaned == INSTRUCTOR_CODE:
		return cleaned
	var shape := RegEx.create_from_string("^[A-Z]{3}[0-9]{2}$")
	if shape.search(cleaned) == null:
		return ""
	return cleaned


func _say(message: String) -> void:
	status_label.text = message
	print(message)


func _on_start_button_pressed() -> void:
	var first_name = first_name_box.text.strip_edges()
	var last_name = last_name_box.text.strip_edges()

	var code := _normalize_code(code_box.text)
	if code == "":
		_say("Codes look like ABC12 — three letters, then two numbers.")
		return

	if first_name == "" or last_name == "":
		_say("Please enter both names")
		return

	if grade_dropdown.selected < 1:
		_say("Please select a grade")
		return

	if len(last_name) > 1:
		_say("Please only enter last initial")
		return

	# Catch a mistyped card before it becomes a participant nobody can account
	# for. The instructor's key never needs asking, and an unanswered check
	# lets the student through — see Backend.check_roster.
	if code != INSTRUCTOR_CODE:
		start_button.disabled = true
		_say("Checking your code…")
		# Explicit type: await yields Variant, so := cannot infer int here.
		var known: int = await Backend.check_roster(code)
		start_button.disabled = false
		if known == Backend.ROSTER_MISSING:
			_say("That code isn't on the list. Check the card your teacher gave you.")
			return
		_say("")

	var grade: int
	match grade_dropdown.selected:
		1: grade = 5
		2: grade = 6
		3: grade = 7
		4: grade = 8
		5: grade = 9
		6: grade = 0

	# Desktop only. On web every device starts with an empty CSV, so this check
	# would pass for a student who has already played on another machine — it
	# is a convenience for a shared lab PC, not a real identity gate.
	if not OS.has_feature("web") and _already_played(first_name, last_name, grade):
		print("Student already exists")
		return

	Global.current_student = Student.new(first_name, last_name, grade)

	# Creates or resumes the sessions row every event will hang off. Returns
	# immediately; the insert and everything after it is queued, so a dead
	# network here costs the student nothing.
	Backend.start_session(first_name, last_name, str(grade), code)

	print("Cached student: first, last, grade")
	get_tree().change_scene_to_file(Paths.WELCOME2)


func _already_played(first_name: String, last_name: String, grade: int) -> bool:
	if not FileAccess.file_exists(Paths.CSV_PATH):
		return false

	var file := FileAccess.open(Paths.CSV_PATH, FileAccess.READ)
	if file == null:
		return false
	var contents := file.get_as_text()
	file.close()

	for line in contents.split("\n"):
		if line.is_empty():
			continue
		var fields := line.split(",")
		if fields.size() < 3:
			continue
		if fields[0] == first_name and fields[1] == last_name and int(fields[2]) == grade:
			return true

	return false
