extends Control

@onready var trash_node_count: int = get_tree().get_nodes_in_group("Trash").size()
@onready var progress_bar = $VSplitContainer/TopPanel/HSplitContainer/LeftPanel/VBoxContainer/ProgressBar
@onready var right_panel = $VSplitContainer/TopPanel/HSplitContainer/RightPanel
var custom_balloon_scene_path = "res://Scenes/welcome_scene_balloon.tscn"
#@onready delay_timer = Timer.new()

var times_up = false

var phase_duration: float = 0
var trash_collected: int = 0

func _ready() -> void:
	Global.count_trash()
	progress_bar.max_value = trash_node_count
	Backend.log_event(Backend.EVENT_PHASE_ENTER, {"phase": "phase2"})
	
	var next_timer = Timer.new()
	next_timer.one_shot = true
	next_timer.autostart = false
	next_timer.wait_time = 120.0
	add_child(next_timer)
	
	next_timer.timeout.connect(_on_next_timer_timeout)
	
	next_timer.start()
	
	var delay_timer = Timer.new()
	delay_timer.one_shot = true
	delay_timer.autostart = false
	delay_timer.wait_time = 45.0
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
		
func _process(delta: float) -> void:
	phase_duration += delta
	progress_bar.value = Global.trash_collected
	if right_panel.goto_next_scene or progress_bar.ratio >= .80 or times_up == true:
		print("Phase2: Complete")
		Global.cache_student_phase_data("phase2", phase_duration, progress_bar.ratio, right_panel.user_code)
		get_tree().change_scene_to_file(Paths.PHASE3)
