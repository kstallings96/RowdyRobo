extends Panel

@onready var submit_button = $VBoxContainer/MarginContainer/HBoxContainer/SubmitButton
@onready var drop_slot_container = $VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var drop_slots: Array = drop_slot_container.get_children()
@onready var code_timer = $CodeTimer
@onready var performance_timer = $PerformanceTimer
@onready var play_button = $VBoxContainer/MarginContainer/HBoxContainer/PlayButton
@onready var speed_button = $VBoxContainer/MarginContainer/HBoxContainer/SpeedButton

@export var robot: RowdyRobot
@export var is_phase_3: bool
@export var default_code: Array[Global.CodeAction]
@export var is_speed_locked: bool
var is_code_running: bool = false
var code_block_index: int = 0
var user_code: Array[Global.CodeAction] = []
var clean_time: float = 0
var goto_next_scene: bool = false

func _ready() -> void:
	if is_speed_locked:
		code_timer.wait_time = 0.03
		speed_button.disabled = true
		speed_button.modulate = Color8(48, 48, 48)
	
	submit_button.visible = is_phase_3
	if !default_code.is_empty():
		for i in range(default_code.size()):
			drop_slots[i].set_action(default_code[i])

func _on_code_timer_timeout() -> void:
	if is_code_running:
		_gather_user_code()
		if user_code.is_empty():
			return
		_set_drop_slot_highlight()
		var action = user_code[code_block_index % len(user_code)]
		if action != null:
			robot.run_action(action)
		code_block_index = (code_block_index + 1) % len(user_code)
		clean_time += code_timer.wait_time

func _on_play_button_toggled(toggled_on: bool) -> void:
	is_code_running = toggled_on
	if toggled_on:
		_gather_user_code()
		Backend.log_event(Backend.EVENT_CODE_RUN, {
			"phase": Global.current_phase_name(),
			"code": Global.action_array_to_ints(user_code),
			"fast": code_timer.wait_time < 0.5,
		})
		code_block_index = 0
		clean_time = 0
		robot.reset()
		Global.reset_trash()

func _on_speed_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		code_timer.wait_time = 0.03
	else:
		code_timer.wait_time = 0.5

func _on_submit_button_pressed() -> void:
	_gather_user_code()
	Backend.log_event(Backend.EVENT_CODE_SUBMIT, {
		"phase": Global.current_phase_name(),
		"code": Global.action_array_to_ints(user_code),
		"blocks": user_code.size(),
	})
	play_button.disabled = true
	play_button.modulate = Color8(48, 48, 48)
	speed_button.disabled = true
	speed_button.modulate = Color8(48, 48, 48)
	code_timer.wait_time = 0.03
	is_code_running = true
	code_block_index = 0
	clean_time = 0
	robot.reset()
	Global.reset_trash()
	performance_timer.start()

func _set_drop_slot_highlight():
	drop_slots[code_block_index % len(drop_slots)].modulate = Color.AQUA
	drop_slots[(code_block_index - 1 + len(user_code)) % len(user_code)].modulate = Color.WHITE

func _gather_user_code():
	user_code.clear()
	for slot in drop_slot_container.get_children():
		if slot.assigned_action != Global.CodeAction.NULL:
			user_code.append(slot.assigned_action)

func _on_performance_timer_timeout() -> void:
	goto_next_scene = true
