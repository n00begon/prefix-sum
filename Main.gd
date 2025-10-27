extends Node2D
const MIN_INT: int = 1
const MAX_INT: int = 1
const SIZE: int = 100000
const RANDOM: bool = false

func _ready() -> void:
	var original = create_array(SIZE)
	var check = sum(original)
	timed_run("GDScript Linear", original.duplicate_deep(), check, gdscript_linear)
	timed_run("GDScript Hillis Steele Singlethread", original.duplicate_deep(), check, gdscript_hillissteel_single_thread)
	timed_run("GDScript Hillis Steele Multithreaded", original.duplicate_deep(), check, gdscript_hillissteel_multi_threaded)

func sum(numbers: Array[int]) -> int:
	var total: int = 0
	for i in numbers:
		total += i
	return total

func create_array(size: int) -> Array[int]:
	var numbers: Array[int] = []
	numbers.resize(size)
	if RANDOM:
		for i in size:
			numbers[i] = randi_range(MIN_INT, MAX_INT)
	else:
		for i in size:
			numbers[i] = i + 1
	return numbers

func timed_run(functionName: String, numbers: Array[int], check: int, function: Callable) -> void:
	var before = Time.get_ticks_msec()
	var result = function.call(numbers)
	var time = Time.get_ticks_msec() - before
	var total = result[result.size() -1]
	prints (functionName, time, "milliseconds, valid:", total == check)
	if !total == check:
		prints("Expected", check, "Actual", total)

func gdscript_linear(numbers: Array[int]) -> Array[int]:
	for i in range(1, numbers.size()):
		numbers[i] += numbers[i - 1]
	return numbers

func gdscript_hillissteel_single_thread(numbers: Array[int]) -> Array[int]:
	var size: int = numbers.size()
	var buffer: Array[int] = numbers.duplicate_deep()
	var old = numbers
	var new = buffer
	
	for step in range(0, ceil(log(size) / log(2))):
		for i: int in range(size):
			if i >= 2 ** step:
				new[i] = old[i - 2 ** step] + old[i]
			else:
				new[i] = old[i]
		var temp = old
		old = new
		new = temp
	return old

func gdscript_hillissteel_multi_threaded(numbers: Array[int]) -> Array[int]:
	var size: int = numbers.size()
	var buffer: Array[int] = numbers.duplicate_deep()
	var old = numbers
	var new = buffer

	var blockSize: int = 1024
	var elements = ceil(size/float(blockSize))

	for step in range(0, ceil(log(size) / log(2))):
		var callable = Callable(self, "_hillissteel_neighbours").bind(blockSize, step, old, new)
		var task_id = WorkerThreadPool.add_group_task(callable, elements)
		WorkerThreadPool.wait_for_group_task_completion(task_id)
		var temp = old
		old = new
		new = temp
	return old

func _hillissteel_neighbours(block:int, blockSize: int, step: int, old: Array[int], new: Array[int]) -> void:
	var start: int = block * blockSize
	var end: int = min(start + blockSize, old.size())
	for i: int in range(start, end):
		if i >= 2 ** step:
			new[i] = old[i - 2 ** step] + old[i]
		else:
			new[i] = old[i]
