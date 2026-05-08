class_name AntStateMachine extends Node

var current_state: AntState = null
var ant: Node = null

func change_state(new_state: AntState) -> void:
	if current_state != null:
		current_state.exit()
	current_state = new_state
	current_state.ant = ant
	current_state.enter()

func update(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)
