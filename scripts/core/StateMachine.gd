class_name StateMachine
extends RefCounted

var states: Dictionary = {}
var current_state: BaseState = null
var current_name: String = ""

func add_state(name: String, state: BaseState) -> void:
	states[name] = state

func change_state(name: String) -> void:
	if not states.has(name):
		push_warning("StateMachine: unknown state '%s'" % name)
		return
	if current_state:
		current_state.exit()
	current_name = name
	current_state = states[name]
	current_state.enter()

func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)
