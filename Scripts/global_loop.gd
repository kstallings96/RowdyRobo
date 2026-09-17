class_name GlobalMainLoop
extends MainLoop

var time_elapsed: int = 0

func _initialize():
	print("Initialized:")
	print("  Starting time: %s" % str(time_elapsed))

func _process(delta):
	time_elapsed += delta
	# Return true to end the main loop.
	return Input.is_key_pressed(Key.KEY_ESCAPE)

func _finalize():
	print("Early Exit!")
	Global.current_student.total_time = time_elapsed
	Global.save_student_data()
	print("Finalized:")
	print("  End time: %s" % str(time_elapsed))
