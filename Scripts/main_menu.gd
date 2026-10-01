extends Control

## The facilitator keys. Each opens every tool in the week — this one,
## VibeBuilder and CT Week — so a facilitator can demo or test a station without
## borrowing a student's card. KSS* belong to one facilitator, SAM* to the
## other, and within a facilitator they sit close together on purpose: a
## mistyped key lands on another of that person's own keys, or on nothing,
## rather than inside a participant's project.
##
## That is only safe while no participant code is near one. Re-checked for the
## 17 cards printed for this cohort: the nearest is still three keystrokes
## away — KSS11/CGU11, KSS18/AWC18, SAM16/KAN66, and now AFG17/KSS17 with the
## three codes added on 2026-10-01. RE-CHECK THAT whenever the roster or this
## list changes; it is the property the whole arrangement rests on, and the
## check is a Hamming distance over the five characters, not a glance.
##
## An earlier version of this comment justified the key differently: that the
## roster generator never emits the digits 0 or 1, so a code containing one
## had to be a key. That is not true of this cohort — CGU11, AWC18 and IEZ40
## are all real participant codes — so do not reintroduce that test.
const INSTRUCTOR_CODES := [
	"KSS03", "KSS11", "KSS17", "KSS18",
	"SAM12", "SAM14", "SAM16",
]

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
func _is_instructor(code: String) -> bool:
	return INSTRUCTOR_CODES.has(code)


func _normalize_code(raw: String) -> String:
	var cleaned := ""
	for ch in raw.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			cleaned += ch
	if _is_instructor(cleaned):
		return cleaned
	var shape := RegEx.create_from_string("^[A-Z]{3}[0-9]{2}$")
	if shape.search(cleaned) == null:
		return ""
	return cleaned


## The code, handed over by whichever tool sent them here.
##
## CT Week's hub appends `?pc=ABC12` to every tile that links out, because the
## week only becomes ONE dataset if a student's rows carry the same
## participant code in every tool. Without this the join depended on an
## eleven-to-fourteen year old retyping five characters correctly, and a
## single slip makes them two people in the data — found at analysis, when it
## is too late to repair.
##
## IT PREFILLS AND DOES NOT SUBMIT. A link can be forwarded, pasted, or left
## in a history on a shared Chromebook, so arriving with a code in the URL is
## not proof of who is sitting there. The student still presses Start, so a
## wrong code is visible before it becomes somebody else's session — the same
## rule VibeBuilder's login screen follows.
##
## Web export only. `OS.has_feature("web")` guards it because there is no
## query string in the editor or in a desktop build, and `JavaScriptBridge`
## does not exist outside the browser. The name is normalised through
## `_normalize_code` exactly as typed input is: a malformed `?pc=` is ignored
## rather than dropped into the box for the student to puzzle over.
func _ready() -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('pc') || ''", true)
	if raw == null:
		return
	var code := _normalize_code(str(raw))
	if code == "":
		return
	code_box.text = code


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
	# for. A facilitator key never needs asking, and an unanswered check lets
	# the student through — see Backend.check_roster.
	if not _is_instructor(code):
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
