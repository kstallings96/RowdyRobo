extends Node

enum CodeAction {
	NULL,
	MoveForward,
	MoveBackward,
	MoveRandom,
	TurnRight,
	TurnLeft,
	Turn180,
	TurnRandom,
	IsObstacleFront,
	IsObstacleRight,
	IsObstacleLeft,
	IsSpaceTravelledFront,
	IsSpaceTravelledRight,
	IsSpaceTravelledLeft,
}

var current_student: Student = null;
var is_dragging: bool = false
var holding_code_block = null
var holding_code_block_offset: Vector2 = Vector2.ZERO
var holding_action: CodeAction = CodeAction.NULL
var total_time_elapsed: float = 0.0
var is_tracking_time: bool = false

var trash_nodes: Array
var trash_node_count: int = -1
var trash_collected: int = 0

var score = 0


func _ready():
	print("Global Autoload ready!")
	get_tree().set_auto_accept_quit(false)


func _process(delta: float) -> void:
	if is_tracking_time:
		Global.total_time_elapsed += delta
	if is_dragging and holding_code_block != null:
		holding_code_block.global_position = get_viewport().get_mouse_position() - Global.holding_code_block_offset


func cache_student_phase_data(current_phase: String, phase_duration: float, performance: float, user_code: Array[Global.CodeAction]):
	print("Global: Chaching student...")
	if Global.current_student == null:
		print("No student in cache!")
		return

	Global.current_student.phase_durations.append(phase_duration)
	Global.current_student.performance_history.append(performance)
	Global.current_student.code_history.append(user_code)
	print("Global: Cached student - phasedur, perfhist, codehist")

	Backend.log_event(Backend.EVENT_PHASE_COMPLETE, {
		"phase": current_phase,
		"duration": snappedf(phase_duration, 0.01),
		"performance": snappedf(performance, 0.001),
		"code": action_array_to_ints(user_code),
		"trash_collected": Global.trash_collected,
		"trash_total": Global.trash_node_count,
	})


## Derived from the running scene rather than passed in, so no .tscn needs a
## new exported property just to name itself in the event log.
func current_phase_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path.get_file().get_basename()


## The enum values are what the analysis queries read, so they go over the wire
## as plain ints rather than as Godot's typed array.
func action_array_to_ints(actions: Array) -> Array:
	var out: Array = []
	for action in actions:
		out.append(int(action))
	return out


func save_student_data():
	print("Global: Saving student...")
	if Global.current_student == null:
		print("No student in cache!")
		return

	# On web this writes into the student's own IndexedDB, where it is not
	# recoverable after the study. The backend queue is the real record there;
	# the CSV stays for lab machines you can walk up to.
	if OS.has_feature("web"):
		print("Global: web build — skipping CSV, data goes to the backend")
		return

	if not FileAccess.file_exists(Paths.CSV_PATH):
		var new_file = FileAccess.open(Paths.CSV_PATH, FileAccess.WRITE)
		new_file.close()

	var file = FileAccess.open(Paths.CSV_PATH, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_csv_line(Global.current_student.get_data())
	file.close()

	print("Global: Saved Student data!")


func count_trash():
	trash_nodes = get_tree().get_nodes_in_group("Trash")
	Global.trash_node_count = trash_nodes.size()
	Global.trash_collected = 0


func reset_trash():
	Global.trash_collected = 0
	for trash in trash_nodes:
		trash.make_exist()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Early Exit!")
		Global.save_student_data()
		# Best effort: gets the tail of the queue up before the window goes
		# away. If the network is gone it stays on disk for the next launch.
		await Backend.end_session()
		get_tree().quit()
