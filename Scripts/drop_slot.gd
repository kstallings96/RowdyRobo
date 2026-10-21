class_name DropSlot extends Button

## Marks the block a conditional guards. The marker and the indent both
## matter: the marker says "this one belongs to the test above", and the
## indent is the shape a student will meet again in every language they
## ever read.
##
## It has to be the text rather than `modulate`, because the run loop already
## owns modulate — aqua for the block executing right now — and the bottom
## panel's hint glow uses it too.
##
## Three spaces, not six: at the slot font the wider indent pushed the
## longest guarded label ("If obstacle ahead") past the right-hand edge
## of the slot entirely, and under the X once that was added. Measured,
## not guessed — see the width check in the commit that introduced it.
const GUARD_PREFIX := "   » "

@onready var clear_button = get_node_or_null("ClearButton")

var assigned_action: Global.CodeAction = Global.CodeAction.NULL
var is_guarded: bool = false
var is_hovering: bool = false;

func _ready() -> void:
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	if clear_button != null:
		clear_button.pressed.connect(_on_clear_pressed)
	_refresh_text()


## The X on a filled slot. Taking a block out used to be right-click only,
## which nobody discovers without being told — and being told does not scale
## to a room of eleven-year-olds.
##
## It cannot fight the drop handler below: dropping requires a block to be
## carried, clearing requires that none is, so only one can ever apply.
func _on_clear_pressed() -> void:
	if Global.holding_action != Global.CodeAction.NULL:
		return
	if self.assigned_action == Global.CodeAction.NULL:
		return
	_log_removal()
	clear_action()


func _log_removal() -> void:
	Backend.log_event(Backend.EVENT_BLOCK_REMOVED, {
		"phase": Global.current_phase_name(),
		"slot": get_index(),
		"action": int(self.assigned_action),
	})


## Turns a slot into a picture of itself, for the welcome screen: no X, and no
## mouse events reaching either the slot or the button inside it.
func set_interactive(value: bool) -> void:
	self.mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE
	if clear_button != null:
		clear_button.mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE
		clear_button.visible = value and self.assigned_action != Global.CodeAction.NULL

func _process(_delta: float) -> void:
	if self.is_hovering:
		if Input.is_action_pressed("right_mouse_click") and !Global.is_dragging:
			# The mouse button stays "pressed" for many frames, so only the
			# transition out of an assigned action is worth recording.
			if self.assigned_action != Global.CodeAction.NULL:
				_log_removal()
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
	self.is_guarded = false
	_refresh_text()

func set_action(action: Global.CodeAction):
	self.assigned_action = action
	_refresh_text()

## Set by the right panel, which is the only thing that can know: whether a
## block is guarded depends on the whole program, not on this slot.
func set_guarded(value: bool) -> void:
	if self.is_guarded == value:
		return
	self.is_guarded = value
	_refresh_text()

func _refresh_text() -> void:
	var filled: bool = self.assigned_action != Global.CodeAction.NULL

	# The X exists only where there is something to take out, so an empty slot
	# still reads as an empty slot.
	if clear_button != null and clear_button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		clear_button.visible = filled

	if not filled:
		self.text = " "
		return

	var label: String = Global.display_name(self.assigned_action)
	self.text = (GUARD_PREFIX + label) if self.is_guarded else label
