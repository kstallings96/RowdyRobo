extends Control
@onready var dialogue_manager = DialogueManager
var custom_balloon_scene_path = "res://Scenes/welcome_scene_balloon.tscn"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	dialogue_manager.dialogue_ended.connect(_on_dialogue_finished)
	
	#DialogueManager.show_dialogue_balloon(load(Paths.WELCOME_DIALOGUE))
	dialogue_manager.show_dialogue_balloon_scene(custom_balloon_scene_path, load(Paths.WELCOME_DIALOGUE))
	pass # Replace with function body.

func _on_dialogue_finished(resource):
	print("dialogue finished")
	get_tree().change_scene_to_file(Paths.PHASE0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
