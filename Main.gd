extends Node2D
const MIN_INT: int = 0
const MAX_INT: int = 100

func _ready() -> void:
	var first = _create_array(50)
	prints ("Numbers", first)
	
func _create_array(size: int) -> Array[int]:
	var numbers: Array[int] = []
	numbers.resize(size)
	
	for i in size:
		numbers[i] = randi_range(MIN_INT, MAX_INT)
	return numbers
