class_name Ant extends CharacterBody2D

@export var walk_speed: float = 60.0
@export var gravity: float = 900.0
@export var carrying_speed_multiplier: float = 0.78
@export var spawn_grace_seconds: float = 0.4

var direction: int = 1
var has_been_carrying: bool = false
# state(CarryingState)와 무관하게 사탕 보유 여부를 추적. CarryingState.enter()에서 true,
# Home에 운반 성공 시 false. Faller/Walker 전이로도 잃지 않음 — Codex review HIGH 대응.
var has_candy: bool = false
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
	# 사탕 보유 = 0.78배. state가 Faller/Walker로 잠시 빠져도 속도 페널티 유지.
	return walk_speed * (carrying_speed_multiplier if has_candy else 1.0)

func flip() -> void:
	direction = -direction
