class_name Ant extends CharacterBody2D

signal bumped_blocker(direction: int)

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
var _blocker_hitbox: Area2D = null

func _ready() -> void:
	_grace_until = Time.get_ticks_msec() / 1000.0 + spawn_grace_seconds
	add_to_group("ants")
	state_machine = $StateMachine
	state_machine.ant = self
	_blocker_hitbox = get_node_or_null("BlockerHitbox") as Area2D
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

func set_blocker_active(active: bool) -> void:
	# 멱등 — WorkerState("blocker") enter/exit, FallerState 전이 모두 안전 호출.
	if _blocker_hitbox == null:
		_blocker_hitbox = get_node_or_null("BlockerHitbox") as Area2D
	if _blocker_hitbox == null:
		push_error("[Ant] BlockerHitbox node missing — Ant.tscn 갱신 필요")
		return
	_blocker_hitbox.monitoring = active
	var col: CollisionShape2D = _blocker_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.disabled = not active
	if active:
		if not _blocker_hitbox.body_entered.is_connected(_on_blocker_body_entered):
			_blocker_hitbox.body_entered.connect(_on_blocker_body_entered)

func _on_blocker_body_entered(body: Node2D) -> void:
	if body == self:
		return
	var other: Ant = body as Ant
	if other == null:
		return
	# Blocker끼리 무한 반전 차단 — 정지 상태 ant는 안 건드림.
	if other.state_machine != null and other.state_machine.current_state is WorkerState:
		return
	# 절대 설정 — 블로커로부터 멀어지는 방향. flip이 아니므로 double-bump에도 안전.
	var rel_x: float = other.global_position.x - global_position.x
	other.direction = 1 if rel_x >= 0.0 else -1
	bumped_blocker.emit(other.direction)
