extends Control

## How long a student gets on the random level before it moves them on.
## Five minutes rather than the two it used to be: the point of this level is
## to sit and watch a random walk eventually cover the room, and two minutes
## cut most students off while they were still assembling the program.
const PHASE_SECONDS := 300.0

## When RowdyRobo offers a nudge if nothing has clicked yet. Two minutes, not
## the old 45 seconds: on a five-minute level that arrived while most students
## were still reading the blocks, so it read as an interruption rather than
## help. Two minutes is long enough that anyone still stuck is actually stuck.
const HELP_AFTER_SECONDS := 120.0

@onready var trash_node_count: int = get_tree().get_nodes_in_group("Trash").size()
@onready var progress_bar = $VSplitContainer/TopPanel/HSplitContainer/LeftPanel/VBoxContainer/ProgressBar
@onready var praise_label = $VSplitContainer/TopPanel/HSplitContainer/LeftPanel/VBoxContainer/PraiseLabel
@onready var right_panel = $VSplitContainer/TopPanel/HSplitContainer/RightPanel
var custom_balloon_scene_path = "res://Scenes/welcome_scene_balloon.tscn"
#@onready delay_timer = Timer.new()

var times_up = false
var has_praised = false

var phase_duration: float = 0
var trash_collected: int = 0

func _ready() -> void:
	Global.count_trash()
	progress_bar.max_value = trash_node_count
	Backend.log_event(Backend.EVENT_PHASE_ENTER, {"phase": "phase2"})
	
	var next_timer = Timer.new()
	next_timer.one_shot = true
	next_timer.autostart = false
	next_timer.wait_time = PHASE_SECONDS
	add_child(next_timer)
	
	next_timer.timeout.connect(_on_next_timer_timeout)
	
	next_timer.start()
	
	var delay_timer = Timer.new()
	delay_timer.one_shot = true
	delay_timer.autostart = false
	delay_timer.wait_time = HELP_AFTER_SECONDS
	add_child(delay_timer)
	
	delay_timer.timeout.connect(_on_delay_timer_timeout)
	
	delay_timer.start()
	
	DialogueManager.show_dialogue_balloon(load(Paths.PHASE2_DIALOGUE))
	progress_bar.value_changed.connect(_on_progress_value_changed)

func _on_progress_value_changed(new_value):
	if new_value >= 99:
		#print("top line")
		right_panel.goto_next_scene = true

func _on_delay_timer_timeout():
	DialogueManager.show_dialogue_balloon_scene(custom_balloon_scene_path, load(Paths.PHASE2_HELP_DIALOGUE))
	
func _on_next_timer_timeout():
		times_up = true
		
## Both random blocks in the program at once is the whole idea of this level:
## the robot stops following a fixed path and starts covering the room by
## chance. Say so the moment it happens, so a student who has got there is not
## left wondering whether they were supposed to do something else.
func _check_random_combo() -> void:
	if has_praised:
		return

	# Explicit type: right_panel is an untyped @onready, so := has nothing to
	# infer the return type from and the script fails to parse.
	var actions: Array = right_panel.assigned_actions()
	if not actions.has(Global.CodeAction.MoveRandom):
		return
	if not actions.has(Global.CodeAction.TurnRandom):
		return

	has_praised = true
	praise_label.text = "Good job! Now sit back and watch your robot get to work."
	praise_label.visible = true
	Backend.log_event(Backend.EVENT_RANDOM_COMBO, {
		"phase": "phase2",
		"seconds": snappedf(phase_duration, 0.01),
		"blocks": actions.size(),
	})


func _process(delta: float) -> void:
	phase_duration += delta
	progress_bar.value = Global.trash_collected
	_check_random_combo()
	if right_panel.goto_next_scene or progress_bar.ratio >= .80 or times_up == true:
		print("Phase2: Complete")
		Global.cache_student_phase_data("phase2", phase_duration, progress_bar.ratio, right_panel.user_code)
		get_tree().change_scene_to_file(Paths.PHASE3)
