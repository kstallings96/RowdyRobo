extends Panel

@onready var codeblocks = $MarginContainer/HFlowContainer.get_children()

@export var enabled_movement: bool
@export var enabled_random: bool
@export var enabled_ifs: bool

@export var glow_blocks: Array[Global.CodeAction]

const MOVMENT = [
	Global.CodeAction.MoveForward,
	Global.CodeAction.MoveBackward,
	Global.CodeAction.TurnRight,
	Global.CodeAction.TurnLeft,
	Global.CodeAction.Turn180,
]

const RANDOM = [
	Global.CodeAction.MoveRandom,
	Global.CodeAction.TurnRandom,
]

const IFS = [
	Global.CodeAction.IsObstacleRight,
	Global.CodeAction.IsObstacleFront,
	Global.CodeAction.IsObstacleLeft,
]


func _ready() -> void:
	for codeblock in codeblocks:
		if enabled_movement and codeblock.action_type in MOVMENT:
			continue
		elif enabled_random and codeblock.action_type in RANDOM:
			continue
		elif enabled_ifs and codeblock.action_type in IFS:
			continue
		else:
			codeblock.hide()


func _on_hint_timer_timeout() -> void:
	print("Glow")
	for codeblock in codeblocks:
		if codeblock.action_type in glow_blocks:
			var glow_color = Color8(255, 0, 255)
			codeblock.modulate = glow_color
			
