extends Control

## The example program shown beside RowdyRobo's introduction.
##
## This used to be Sprites/code blocks.png — a screenshot taken back when the
## blocks were called MoveForward and IsObstacleFront. A picture cannot follow
## a rename, so the welcome screen went on teaching the old names long after
## the game had stopped using them. These are real DropSlots filled from the
## same display map the levels use, so they cannot drift again.
##
## IsObstacleFront is in the middle on purpose: it means the slot after it
## shows the guard indent, so the first thing a student sees is the shape the
## levels will ask them to build.
const DEMO_PROGRAM := [
	Global.CodeAction.MoveForward,
	Global.CodeAction.IsObstacleFront,
	Global.CodeAction.TurnRight,
	Global.CodeAction.TurnRandom,
]

## Empty slots after the program, so it reads as a part-filled workspace
## rather than a finished list.
const DEMO_EMPTY_SLOTS := 3

const DROP_SLOT := preload("res://Scenes/drop_slot.tscn")

@onready var dialogue_manager = DialogueManager
@onready var demo_slots = $CodeBlocksDemo
var custom_balloon_scene_path = "res://Scenes/welcome_scene_balloon.tscn"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_demo_program()
	dialogue_manager.dialogue_ended.connect(_on_dialogue_finished)
	
	#DialogueManager.show_dialogue_balloon(load(Paths.WELCOME_DIALOGUE))
	dialogue_manager.show_dialogue_balloon_scene(custom_balloon_scene_path, load(Paths.WELCOME_DIALOGUE))
	pass # Replace with function body.

## Mouse input is ignored on the container and on every slot: these are a
## picture made of real widgets, not something to edit. A DropSlot only ever
## changes what it holds from inside its own _process, and that is gated on
## is_hovering, which can never become true without mouse events.
func _build_demo_program() -> void:
	if demo_slots == null:
		return

	for i in range(DEMO_PROGRAM.size() + DEMO_EMPTY_SLOTS):
		var slot = DROP_SLOT.instantiate()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		demo_slots.add_child(slot)
		if i < DEMO_PROGRAM.size():
			slot.set_action(DEMO_PROGRAM[i])

	# Show the guard the way a level does: the block after the conditional is
	# the one it decides about.
	var children = demo_slots.get_children()
	for i in range(DEMO_PROGRAM.size()):
		if Global.is_conditional(DEMO_PROGRAM[i]) and i + 1 < DEMO_PROGRAM.size():
			children[i + 1].set_guarded(true)


func _on_dialogue_finished(resource):
	print("dialogue finished")
	get_tree().change_scene_to_file(Paths.PHASE0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
