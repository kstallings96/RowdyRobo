class_name RowdyRobot extends CharacterBody2D

@onready var ray_forward = $ForwardRayCast2D
@onready var ray_backward = $BackwardRayCast2D
@onready var ray_right = $RightRayCast2D
@onready var ray_left = $LeftRayCast2D
@onready var start_position: Vector2 = self.position

var grid_cell_size = 16
var direction: Vector2 = Vector2(0, 1)
var rng = RandomNumberGenerator.new()
var current_conditional = false
var conditional_just_played = false
var travelled_positions = {}

func run_action(action: Global.CodeAction):
	match action:
		Global.CodeAction.MoveForward:
			_move_forward()
		Global.CodeAction.MoveBackward:
			_move_backward()
		Global.CodeAction.MoveRandom:
			if rng.randf() > 0.5:
				_move_forward()
			else:
				_move_backward()
		Global.CodeAction.TurnRight:
			_turn_right()
		Global.CodeAction.TurnLeft:
			_turn_left()
		Global.CodeAction.Turn180:
			_turn_180()
		Global.CodeAction.TurnRandom:
			match rng.randi_range(0, 2):
				0: _turn_right()
				1: _turn_left()
				2: _turn_180()
		Global.CodeAction.IsObstacleFront:
			_is_obstacle_front()
		Global.CodeAction.IsObstacleRight:
			_is_obstacle_right()
		Global.CodeAction.IsObstacleLeft:
			_is_obstacle_left()
		Global.CodeAction.IsSpaceTravelledFront:
			_is_travelled_front()
		Global.CodeAction.IsSpaceTravelledRight:
			_is_travelled_right()
		Global.CodeAction.IsSpaceTravelledLeft:
			_is_travelled_left()
	
	# prevent floating point errors
	self.position = round(self.position)
	self.direction = round(self.direction)
	self.rotation_degrees = float(int(round(self.rotation_degrees)) % 360)
	
	travelled_positions[self.position] = true

func reset():
	self.position = start_position
	self.direction = Vector2(0.0, 1.0)
	self.rotation_degrees = 0
	self.current_conditional = false
	_reset_conditional()
	travelled_positions.clear()

func _reset_conditional():
	self.current_conditional = false
	self.conditional_just_played = false

func _move_forward():
	if self.conditional_just_played and !self.current_conditional:
		_reset_conditional()
		return
	if !ray_forward.is_colliding():
		self.position += direction * grid_cell_size
	_reset_conditional()

func _move_backward():
	if self.conditional_just_played and !self.current_conditional:
		_reset_conditional()
		return
	if !ray_backward.is_colliding():
		self.position -= direction * grid_cell_size
	_reset_conditional()

func _turn_right():
	if self.conditional_just_played and !self.current_conditional:
		_reset_conditional()
		return
	self.direction = self.direction.rotated(deg_to_rad(90))
	self.rotate(deg_to_rad(90))
	_reset_conditional()

func _turn_left():
	if self.conditional_just_played and !self.current_conditional:
		_reset_conditional()
		return
	self.direction = self.direction.rotated(deg_to_rad(-90))
	self.rotate(deg_to_rad(-90))
	_reset_conditional()

func _turn_180():
	if self.conditional_just_played and !self.current_conditional:
		_reset_conditional()
		return
	self.direction = self.direction.rotated(deg_to_rad(180))
	self.rotate(deg_to_rad(180))
	_reset_conditional()

func _is_obstacle_front():
	current_conditional = ray_forward.is_colliding()
	self.conditional_just_played = true

func _is_obstacle_back():
	current_conditional = ray_backward.is_colliding()
	self.conditional_just_played = true

func _is_obstacle_right():
	current_conditional = ray_right.is_colliding()
	self.conditional_just_played = true

func _is_obstacle_left():
	current_conditional = ray_left.is_colliding()
	self.conditional_just_played = true

func _is_travelled_front():
	var global_target_pos = self.position + ray_forward.target_position
	current_conditional = travelled_positions.has(global_target_pos)
	self.conditional_just_played = true

func _is_travelled_right():
	var global_target_pos = self.position + ray_right.target_position
	current_conditional = travelled_positions.has(global_target_pos)
	self.conditional_just_played = true

func _is_travelled_left():
	var global_target_pos = self.position + ray_left.target_position
	current_conditional = travelled_positions.has(global_target_pos)
	self.conditional_just_played = true
