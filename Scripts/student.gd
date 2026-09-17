class_name Student extends Resource

var first_name: String = "null"
var last_name: String = "null"
var grade: int = -1
var phase_durations: Array[float]
#
var phase0_duration: float = -1
var phase1_duration: float = -1
var phase2_duration: float = -1
var phase3_duration: float = -1 
var performance_history: Array[float]
#
var phase0_performance_history: Array[float] = []
var phase1_performance_history: Array[float] = []
var phase2_performance_history: Array[float] = []
var phase3_performance_history: Array[float] = [] 
var code_history: Array[Array]
#
var phase0_code_history: Array[Array] = []
var phase1_code_history: Array[Array] = []
var phase2_code_history: Array[Array] = []
var phase3_code_history: Array[Array] = []

var total_time: float

func _init(f_name: String, l_name: String, s_grade: int) -> void:
	self.first_name = f_name
	self.last_name = l_name
	self.grade = s_grade
	self.phase_durations = []
	self.performance_history = []
	self.code_history = []
	self.total_time = 0
	Global.is_tracking_time = true

func get_data() -> Array:
	var data = [
		self.first_name,
		self.last_name,
		self.grade,
		self.phase_durations,
		self.performance_history,
		self.code_history,
		self.total_time,
	]
	return data
