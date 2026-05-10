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
# Phase 4 sweep round8 — overlap-lifetime idempotency (Codex round 4–7 HIGH 종합 대응):
# (1) `_active_blocker_overlaps` (per-pair): 같은 (blocker, walker) 쌍이 active overlap
#     중인 동안엔 bounce/skip 무관 추가 발화 무효 — body_exited 후 재진입 시에만 fresh bounce.
#     키=blocker InstanceID(int), 값=true (Set처럼 사용).
# (2) `_last_blocker_bounce_frame` (per-frame): 같은 physics frame에 다중 blocker 동시
#     발화해도 단 1회만 flip — round 2 HIGH 유지.
# 두 guard 조합으로 round 1/2/4/5/6/7의 모든 attack vector(deep overlap, dual blocker
# same-frame, cross-frame replay, distinct blocker cross-frame, synthetic monitoring
# replay, delayed double-flip)를 동시에 차단.
var _active_blocker_overlaps: Dictionary = {}
var _last_blocker_bounce_frame: int = -1

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

func is_alive() -> bool:
	# Phase 7 — CursorTargeting alive 필터. SavedState/DeadState 제외, 그 외(Walker/Faller/Carrying/Worker)는 alive.
	if state_machine == null or state_machine.current_state == null:
		return false
	var s: AntState = state_machine.current_state
	return not (s is SavedState or s is DeadState)

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
	if not active and _blocker_hitbox.monitoring:
		# 비활성화 직전(monitoring 켜져있을 때만) overlap 정리. monitoring=false 후엔
		# get_overlapping_bodies()가 에러를 내고 body_exited도 자동 발화하지 않으므로
		# stale set entry 방지. 멱등 — 이미 비활성화된 경우 스킵.
		var blocker_id: int = get_instance_id()
		for body in _blocker_hitbox.get_overlapping_bodies():
			var ant: Ant = body as Ant
			if ant != null and is_instance_valid(ant):
				ant._active_blocker_overlaps.erase(blocker_id)
	_blocker_hitbox.monitoring = active
	var col: CollisionShape2D = _blocker_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.disabled = not active
	if active:
		if not _blocker_hitbox.body_entered.is_connected(_on_blocker_body_entered):
			_blocker_hitbox.body_entered.connect(_on_blocker_body_entered)
		if not _blocker_hitbox.body_exited.is_connected(_on_blocker_body_exited):
			_blocker_hitbox.body_exited.connect(_on_blocker_body_exited)

func _on_blocker_body_entered(body: Node2D) -> void:
	if body == self:
		return
	var other: Ant = body as Ant
	if other == null:
		return
	# Blocker끼리 무한 반전 차단 — 정지 상태 ant는 안 건드림.
	if other.state_machine != null and other.state_machine.current_state is WorkerState:
		return
	var blocker_id: int = get_instance_id()
	# (1) 같은 (blocker, walker) 쌍이 이미 active overlap이면 skip — bounce/skip 상태 무관.
	#     overlap이 지속되는 동안엔 추가 bounce 없음. body_exited 후 재진입 시 fresh bounce
	#     (Codex round 7 HIGH 대응 — skipped를 set에 기록하지 않으면 next-frame synthetic
	#     replay가 지연된 double-flip을 만들어 §B-5의 "한 번만 반전" spec을 깸).
	if other._active_blocker_overlaps.has(blocker_id):
		return
	other._active_blocker_overlaps[blocker_id] = true
	# (2) 같은 physics frame에 다중 blocker 동시 발화 시 double-flip 방지 (round 2 HIGH).
	#     skip되어도 set에는 기록되어 있으므로 overlap 종료(body_exited) 전까지 추가 발화 무효.
	var phys_frame: int = Engine.get_physics_frames()
	if other._last_blocker_bounce_frame == phys_frame:
		return
	other._last_blocker_bounce_frame = phys_frame
	# 유입 방향 반전 — 활성화 순간 깊은 overlap·큰 physics delta로 ant 중심이
	# 이미 blocker를 통과했어도 결정론적 바운스 (post-overlap 위치 기반은 통과
	# 방향을 그대로 유지시킬 수 있음, Codex round 1 HIGH). direction은 ±1 invariant.
	other.direction = -other.direction
	bumped_blocker.emit(other.direction)

func _on_blocker_body_exited(body: Node2D) -> void:
	if body == self:
		return
	var other: Ant = body as Ant
	if other == null or not is_instance_valid(other):
		return
	other._active_blocker_overlaps.erase(get_instance_id())

func _exit_tree() -> void:
	# Blocker가 set_blocker_active(false)를 거치지 않고 직접 free되는 경우(폭발 등)
	# 대비 — overlap 중이던 walker들의 set에서 자기 ID 제거. 누락 시 walker가
	# stale entry로 인해 영구 flip 불가 상태가 될 수 있음.
	if _blocker_hitbox != null and is_instance_valid(_blocker_hitbox) and _blocker_hitbox.monitoring:
		var blocker_id: int = get_instance_id()
		for body in _blocker_hitbox.get_overlapping_bodies():
			var ant: Ant = body as Ant
			if ant != null and is_instance_valid(ant):
				ant._active_blocker_overlaps.erase(blocker_id)
