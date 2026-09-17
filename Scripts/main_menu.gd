extends Control

@onready var first_name_box = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/FirstNameLineEdit
@onready var last_name_box = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/LastNameLineEdit
@onready var grade_dropdown = $MarginContainer/VBoxContainer2/MarginContainer/VBoxContainer/GradeOptionButton


func _on_start_button_pressed() -> void:
	var first_name = first_name_box.text.strip_edges()
	var last_name = last_name_box.text.strip_edges()

	if first_name == "" or last_name == "":
		print("Please enter both names")
		return

	if grade_dropdown.selected < 1:
		print("Please select a grade")
		return

	if len(last_name) > 1:
		print("Please only enter last initial")
		return

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
	Backend.start_session(first_name, last_name, str(grade))

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
