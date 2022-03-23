extends Label

var val = 0.0

func _process(delta: float) -> void:
	val -= delta
	text = str(val)
