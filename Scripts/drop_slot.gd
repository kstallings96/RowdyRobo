class_name DropSlot extends Button

var assigned_action: Global.CodeAction = Global.CodeAction.NULL
var is_hovering: bool = false;

func _ready() -> void:
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)

func _process(_delta: float) -> void:
	if self.is_hovering:
		if Input.is_action_pressed("right_mouse_click") and !Global.is_dragging:
			# The mouse button stays "pressed" for many frames, so only the
			# transition out of an assigned action is worth recording.
			if self.assigned_action != Global.CodeAction.NULL:
				Backend.log_event(Backend.EVENT_BLOCK_REMOVED, {
					"phase": Global.current_phase_name(),
					"slot": get_index(),
					"action": int(self.assigned_action),
				})
			self.clear_action()
		elif Input.is_action_pressed("mouse_click"):
			if Global.holding_action != Global.CodeAction.NULL:
					Global.is_dragging = false
					Backend.log_event(Backend.EVENT_BLOCK_PLACED, {
						"phase": Global.current_phase_name(),
						"slot": get_index(),
						"action": int(Global.holding_action),
						"replaced": int(self.assigned_action),
					})
					self.set_action(Global.holding_action)
					Global.holding_action = Global.CodeAction.NULL
					Global.holding_code_block.queue_free()

func _on_mouse_entered():
	self.is_hovering = true

func _on_mouse_exited():
	self.is_hovering = false

func clear_action():
	self.assigned_action = Global.CodeAction.NULL
	self.text = " "

func set_action(action: Global.CodeAction):
	self.assigned_action = action
	self.text = Global.CodeAction.keys()[self.assigned_action]
