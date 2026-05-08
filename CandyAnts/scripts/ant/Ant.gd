class_name Ant extends CharacterBody2D

@export var walk_speed: float = 60.0
@export var gravity: float = 900.0
@export var carrying_speed_multiplier: float = 0.78
@export var spawn_grace_seconds: float = 0.4

var direction: int = 1
var has_been_carrying: bool = false
var state_machine: AntStateMachine = null
var _grace_until: float = 0.0

func _ready() -> void:
	_grace_until = Time.get_ticks_msec() / 1000.0 + spawn_grace_seconds
	state_machine = $StateMachine
	state_machine.ant = self
	state_machine.change_state(WalkerState.new())

func _physics_process(delta: float) -> void:
	if state_machine != null:
		state_machine.update(delta)

func is_carrying() -> bool:
	return state_machine != null and state_machine.current_state is CarryingState

func effective_speed() -> float:
	return walk_speed * (carrying_speed_multiplier if is_carrying() else 1.0)

func flip() -> void:
	direction = -direction
