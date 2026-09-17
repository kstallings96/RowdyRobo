extends Node2D
#NOT COMPLETE: Still working to get the proper tracking of robot

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print($Bedroom/floor.local_to_map($robot.position))
	
	#pass # Replace with function body.


#var time_accum = 0.0
var visited_tiles = {}
var perc_cleaned = 0.0
var final_performance: float = 0.0
var performance_history = []

@onready var room1score = $Room1Score

@onready var timerLabel = $TimerLabel
@onready var timer = $Timer

func _process(_delta):
	$Bedroom/floor.set_cell(Vector2i(-33,-22), 5, Vector2i(16,5),0)
	var tile_pos = $Bedroom/floor.local_to_map($robot.position)
	var total_tiles = 1196-60#240 - 63
	
	var seconds = int(timer.get_time_left()) % 60
	var milliseconds: int = int(timer.get_time_left() * 1000.0) % 1000
	timerLabel.text = "%02d.%02d" % [seconds, milliseconds]
	
	#print($Bedroom/floor.get_cell_source_id(tile_pos))
	if not visited_tiles.has(tile_pos):
		visited_tiles[tile_pos] = true
		#$Floorplan/floor.set_cell(tile_pos, -1)
		#$Bedroom/floor.erase_cell(tile_pos)
		$Bedroom/floor.set_cell(tile_pos, 11, Vector2i(18,16),0)
		#$Floorplan/floor.set_cells_terrain_connect([tile_pos], 0, 0)
		#print("visted new tile: ", tile_pos, " and size: ", visited_tiles.size())
		perc_cleaned = float(visited_tiles.size()) / total_tiles * 100
		print("Tiles cleaned: %d / %d (%.2f%%)" % [visited_tiles.size(), total_tiles, perc_cleaned])
		room1score.text = "score: " + str("%.2f" % perc_cleaned) + " %"

		
		

func _on_timer_timeout() -> void:
	print("final performance metrics: ", "%.2f" % perc_cleaned, "%", "visited tiles set: ", visited_tiles)
	room1score.text = "FINAL score: " + str("%.2f" % perc_cleaned) + " %"
	Global.current_student.performance_history.append(perc_cleaned)
	Global.save_data(Global.current_student.get_data())
