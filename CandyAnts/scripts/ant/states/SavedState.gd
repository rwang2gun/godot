class_name SavedState extends AntState

func enter() -> void:
	var a: Ant = ant as Ant
	if a != null:
		a.queue_free()
