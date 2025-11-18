extends Node2D
const MIN_INT: int = 1
const MAX_INT: int = 1
const SIZE: int = 10000000
const RANDOM: bool = false

func _ready() -> void:
	var original = create_array(SIZE)
	var check = create_check_array(original.duplicate_deep())
	timed_run("GDScript Linear", original.duplicate_deep(), check, gdscript_linear)
	timed_run("GDScript Hillis Steele Singlethread", original.duplicate_deep(), check, gdscript_hillissteele_single_thread)
	timed_run("GDScript Hillis Steele Multithreaded", original.duplicate_deep(), check, gdscript_hillissteele_multi_threaded)
	timed_run("GDScript Blelloch Singlethread Gem", original.duplicate_deep(), check, gdscript_blelloch_singlethread_gem)
	timed_run("GDScript Blelloch Singlethread Named", original.duplicate_deep(), check, gdscript_blelloch_singlethread_named)
	timed_run("GDScript Blelloch Multithreaded", original.duplicate_deep(), check, gdscript_blelloch_multithreaded)
	timed_run("GDScript Blocks", original.duplicate_deep(), check, blocks)
	
func create_check_array(numbers: Array[int]) -> Array[int]:
	var total: int = 0
	for i in numbers:
		total += i

	var result: Array[int] = gdscript_linear(numbers)

	assert(result[result.size() - 1] == total)
	return result

func create_array(size: int) -> Array[int]:
	var label: Label = Label.new()
	label.text = "Size: " + str(size)
	%Results.add_child(label)
	
	var numbers: Array[int] = []
	numbers.resize(size)
	if RANDOM:
		for i in size:
			numbers[i] = randi_range(MIN_INT, MAX_INT)
	else:
		for i in size:
			numbers[i] = i + 1
	return numbers

func timed_run(functionName: String, numbers: Array[int], check: Array[int], function: Callable) -> void:
	var before: int = Time.get_ticks_msec()
	var result: Array[int] = function.call(numbers)
	var time: int = Time.get_ticks_msec() - before
	var label: Label = Label.new()
	var output: String = str(functionName) + " " + str(time) + " milliseconds"
	if check.size() != result.size():
		output += ", Invalid! expected length " + str(check.size()) + ", actual " + str(result.size()) 
	
	var differences: int = 0
	
	for i in range(check.size()):
		if check[i] != result[i]:
			differences += 1
	
	if differences > 0:
		output += ", Invalid! Found " + str(differences) + " differences from the check array"
	
	print(output)
	label.text = output
	%Results.add_child(label)

# The single threaded approach
func gdscript_linear(numbers: Array[int]) -> Array[int]:
	for i in range(1, numbers.size()):
		numbers[i] += numbers[i - 1]
	return numbers

#  Hillis Steele in a single thread to learn the algorithm and comparison
func gdscript_hillissteele_single_thread(numbers: Array[int]) -> Array[int]:
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
	
#  Hillis Steele in a multithread in gdscript to learn the algorithm and comparison
func gdscript_hillissteele_multi_threaded(numbers: Array[int]) -> Array[int]:
	var size: int = numbers.size()
	var buffer: Array[int] = numbers.duplicate_deep()
	var old = numbers
	var new = buffer

	var blockSize: int = 1024
	var elements = ceil(size/float(blockSize))

	for step in range(0, ceil(log(size) / log(2))):
		var callable = Callable(self, "_hillissteele_neighbours").bind(blockSize, step, old, new)
		var task_id = WorkerThreadPool.add_group_task(callable, elements)
		WorkerThreadPool.wait_for_group_task_completion(task_id)
		var temp = old
		old = new
		new = temp
	return old

# The thread specific part of Hillis Steele
func _hillissteele_neighbours(block:int, blockSize: int, step: int, old: Array[int], new: Array[int]) -> void:
	var start: int = block * blockSize
	var end: int = min(start + blockSize, old.size())
	for i: int in range(start, end):
		if i >= 2 ** step:
			new[i] = old[i - 2 ** step] + old[i]
		else:
			new[i] = old[i]

# Blelloch algorithm following https://developer.nvidia.com/gpugems/gpugems3/part-vi-gpu-computing/chapter-39-parallel-prefix-sum-scan-cuda
func gdscript_blelloch_singlethread_gem(numbers: Array[int]) -> Array[int]:
	var originalSize: int = numbers.size()
	
	var maxSteps: int = ceil(log(originalSize) / log(2))
	var paddedSize: int = 2 ** maxSteps
	numbers.resize(paddedSize + 1) # Have an extra spot to turn it into an inclusive sum

	# Upsweep
	for step in range(0, maxSteps):
		var stepSize = 2 ** step
		for i in range(stepSize - 1, paddedSize, stepSize * 2):
			numbers[i + stepSize] = numbers[i] + numbers[i + stepSize]
	# Store the end result in the spare slot
	numbers[paddedSize] =  numbers[paddedSize - 1]
	
	# Downsweep
	numbers[paddedSize - 1] = 0

	for step in range(maxSteps - 1, -1, -1):
		var stepSize = 2 ** step
		for i in range(stepSize - 1, paddedSize, stepSize * 2):
			var temp = numbers[i + stepSize]
			numbers[i + stepSize] = numbers[i] + numbers[i + stepSize]
			numbers[i] = temp
	
	# Trim to change it to inclusive
	return numbers.slice(1, originalSize + 1)

# Blelloch Algoirthm with the parts separated out to make it easier to multithread
func gdscript_blelloch_singlethread_named(numbers: Array[int]) -> Array[int]:
	var originalSize: int = numbers.size()
	var maxSteps: int = ceil(log(originalSize) / log(2))
	var paddedSize: int = 2 ** maxSteps
	numbers.resize(paddedSize + 1) # Have an extra spot to turn it into an inclusive sum

	# Upsweep
	for step in range(0, maxSteps):
		var stepSize: int = 2 ** step
		var subSteps: int = ceil(float(paddedSize)/stepSize) / 2
		for i in range(subSteps):
			var first: int = i * stepSize * 2 + stepSize - 1 
			var second: int = first + stepSize
			numbers[second] = numbers[first] + numbers[second]

	# Store the end result in the spare slot
	numbers[paddedSize] =  numbers[paddedSize - 1]

	# Downsweep
	numbers[paddedSize - 1] = 0

	for step in range(maxSteps - 1, -1, -1):
		var stepSize = 2 ** step
		var subSteps: int = ceil(float(paddedSize)/stepSize) / 2
		for i in range(subSteps):
			var first: int = i * stepSize * 2 + stepSize - 1 
			var second: int = first + stepSize
			var temp = numbers[second]
			numbers[second] = numbers[first] + numbers[second]
			numbers[first] = temp
	
	# Trim to change it to inclusive
	return numbers.slice(1, originalSize + 1)

# Blelloch Algoirthm multithread
func gdscript_blelloch_multithreaded(numbers: Array[int]) -> Array[int]:
	var originalSize: int = numbers.size()
	var maxSteps: int = ceil(log(originalSize) / log(2))
	var paddedSize: int = 2 ** maxSteps
	numbers.resize(paddedSize + 1) # Have an extra spot to turn it into an inclusive sum

	# Upsweep
	for step in range(0, maxSteps):
		var stepSize: int = 2 ** step
		var elements: int = ceil(float(paddedSize)/stepSize) / 2
		var callable = Callable(self, "_upsweep").bind(stepSize, numbers)
		var taskId = WorkerThreadPool.add_group_task(callable, elements)
		WorkerThreadPool.wait_for_group_task_completion(taskId)

	# Store the end result in the spare slot
	numbers[paddedSize] =  numbers[paddedSize - 1]

	# Downsweep
	numbers[paddedSize - 1] = 0
	
	for step in range(maxSteps - 1, -1, -1):
		var stepSize = 2 ** step
		var elements: int = ceil(float(paddedSize)/stepSize) / 2
		var callable = Callable(self, "_downsweep").bind(stepSize, numbers)
		var taskId = WorkerThreadPool.add_group_task(callable, elements)
		WorkerThreadPool.wait_for_group_task_completion(taskId)
		
	# Trim to change it to inclusive
	return numbers.slice(1, originalSize + 1)

# Blelloch Algoirthm upsweep individual thread code
func _upsweep(index: int, stepSize: int, numbers: Array[int]) -> void:
	var first: int = index * stepSize * 2 + stepSize - 1 
	var second: int = first + stepSize
	numbers[second] = numbers[first] + numbers[second]

# Blelloch Algoirthm downsweep individual thread code
func _downsweep(index: int, stepSize: int, numbers: Array[int]) -> void:
	var first: int = index * stepSize * 2 + stepSize - 1 
	var second: int = first + stepSize
	var temp = numbers[second]
	numbers[second] = numbers[first] + numbers[second]
	numbers[first] = temp

func blocks(numbers: Array[int]) -> Array[int]:
	var blockSize = 1024
	
	# Skip threads if it can be done in one block
	if numbers.size() <= blockSize:
		return gdscript_linear(numbers)

	var elements: int = ceil(float(numbers.size())/blockSize)
	var offsets: Array[int] = []
	offsets.resize(elements + 1)

	var sum_callable = Callable(self, "_block_sum").bind(blockSize, numbers, offsets)
	var sum_taskId = WorkerThreadPool.add_group_task(sum_callable, elements)
	WorkerThreadPool.wait_for_group_task_completion(sum_taskId)
	
	offsets = blocks(offsets)
	
	var offset_callable = Callable(self, "_block_offset").bind(blockSize, numbers, offsets)
	var offset_taskId = WorkerThreadPool.add_group_task(offset_callable, elements)
	WorkerThreadPool.wait_for_group_task_completion(offset_taskId)
	
	return numbers

func _block_sum(block: int, blocksize: int, numbers: Array[int], offsets: Array[int]) -> void:
	var start = blocksize * block
	var end = min(start + blocksize, numbers.size())
	for i in range(start + 1, end):
		numbers[i] += numbers[i - 1]
	offsets[block + 1] = numbers[end - 1]

func _block_offset(block: int, blocksize: int, numbers: Array[int], offsets: Array[int]) -> void:
	var start = blocksize * block
	var end = min(start + blocksize, numbers.size())
	for i in range(start, end):
		numbers[i] += offsets[block]
