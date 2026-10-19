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
## The marker is a guillemet because KG Red Hands, the slot font, has no
## arrow glyphs at all: U+21B3, U+2192 and U+2514 are each missing and
## render as an empty box. If the font is ever swapped, check has_char
## before reaching for a prettier one.
const GUARD_PREFIX := "      \u00bb "

var assigned_action: Global.CodeAction = Global.CodeAction.NULL
var is_guarded: bool = false
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
	if self.assigned_action == Global.CodeAction.NULL:
		self.text = " "
		return
	var label: String = Global.display_name(self.assigned_action)
	self.text = (GUARD_PREFIX + label) if self.is_guarded else label
