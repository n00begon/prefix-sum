extends Node2D
const MIN_INT: int = 1
const MAX_INT: int = 100
const ARRAY_SIZE = 1000000

func _ready() -> void:
	var original = _create_array(ARRAY_SIZE)
	var check = _sum(original)
	_timed_run("GDScript Linear", original.duplicate(), check, _gdscript_prefix_sum)

func _sum(numbers: Array[int]) -> int:
	var total: int = 0
	for i in numbers:
		total += i
	return total

func _create_array(size: int) -> Array[int]:
	var numbers: Array[int] = []
	numbers.resize(size)
	
	for i in size:
		numbers[i] = randi_range(MIN_INT, MAX_INT)
	return numbers

func _timed_run(functionName: String, numbers: Array[int], check: int, function: Callable) -> void:
	var before = Time.get_ticks_msec()
	var result = function.call(numbers)
	var time = Time.get_ticks_msec() - before
	prints (functionName, time, "milliseconds, valid:", result[result.size() -1] == check)

func _gdscript_prefix_sum(numbers: Array[int]) -> Array[int]:
	for i in range(1, numbers.size()):
		numbers[i] += numbers[i - 1]
	return numbers
