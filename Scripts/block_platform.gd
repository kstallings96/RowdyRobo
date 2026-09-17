extends StaticBody2D

var current_code_block

func _ready() -> void:
	modulate = Color(Color.MAGENTA)
	
func _process(_delta: float) -> void:
	visible = Global.is_dragging
