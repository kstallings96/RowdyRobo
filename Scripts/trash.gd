extends Area2D

@onready var sprite = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var exists: bool = true
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	sprite.frame = rng.randi_range(0, 676)

func _on_body_entered(_body: Node2D) -> void:
	if self.exists:
		Global.trash_collected += 1
	make_not_exist()

func make_exist():
	self.exists = true
	self.visible = true

func make_not_exist():
	self.exists = false
	self.visible = false
