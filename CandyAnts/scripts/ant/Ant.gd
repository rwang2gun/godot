class_name Ant extends CharacterBody2D

signal bumped_blocker(direction: int)

@export var walk_speed: float = 60.0
@export var gravity: float = 900.0
@export var carrying_speed_multiplier: float = 0.78
@export var spawn_grace_seconds: float = 0.4

# Phase 14 — traits (Climber/Floater). climber 보유 시 벽 만남에서 ClimberState 전이,
# floater 보유 시 FallerState에서 중력 0.3배. 영구 보유(해제 API 없음).
const FLOATER_GRAVITY_SCALE: float = 0.3
const CLIMB_SPEED: float = 40.0
# mantle 거리는 ancestor chain의 StageLayoutBuilder.layout.cell_size + 4 로 runtime 갱신.
# 미발견 시 36.0(=32+4) fallback. Stage01~03 모두 cell_size=32이므로 fallback 정확.
var mantle_distance: float = 36.0

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

# Sprite — 시각 전용. 게임 로직 무영향 (collision/state 무관).
var _sprite: AnimatedSprite2D = null
var _last_anim: String = ""

# Phase 14 — trait 보유 dict + 시각 표식 badge 노드.
# traits: StringName(name) → true. 빈 dict = 트레잇 없음.
var traits: Dictionary = {}
var _trait_badges: Node2D = null
var _climber_badge: Sprite2D = null
var _floater_badge: Sprite2D = null
# Phase 15 — 정착 시각 표식. visible toggle은 _update_trait_badges()에서 state 기반.
var _settle_badge: Sprite2D = null

# Phase 17 — 끈끈이(StickyHazard) timer. apply_sticky로 설정, _physics_process에서 매 frame 감소.
# WalkerState/CarryingState update가 is_stuck() 분기로 좌우 정지.
var _sticky_remaining: float = 0.0
var _sticky_badge: Sprite2D = null

func _ready() -> void:
	_grace_until = Time.get_ticks_msec() / 1000.0 + spawn_grace_seconds
	add_to_group("ants")
	state_machine = $StateMachine
	state_machine.ant = self
	_blocker_hitbox = get_node_or_null("BlockerHitbox") as Area2D
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	_trait_badges = get_node_or_null("TraitBadges") as Node2D
	if _trait_badges != null:
		_climber_badge = _trait_badges.get_node_or_null("ClimberBadge") as Sprite2D
		_floater_badge = _trait_badges.get_node_or_null("FloaterBadge") as Sprite2D
		_settle_badge = _trait_badges.get_node_or_null("SettleBadge") as Sprite2D
		_sticky_badge = _trait_badges.get_node_or_null("StickyBadge") as Sprite2D
	_resolve_mantle_distance()
	state_machine.change_state(WalkerState.new())

func set_trait(name: StringName) -> void:
	if name == &"":
		return
	traits[name] = true

func has_trait(name: StringName) -> bool:
	return traits.has(name)

func _resolve_mantle_distance() -> void:
	# ancestor chain 스캔 — global 그룹 lookup 미사용 (plan-stage Round 3 MEDIUM 대응, scope-safe).
	# ant의 ancestor를 따라 올라가며 각 노드 아래 "StageLayoutBuilder" 자식이 있는지 확인.
	# 첫 매치된 builder의 layout.cell_size 사용. layout 없거나 cell_size 부정확하면 다음 ancestor 시도.
	# 모두 실패 시 fallback 36.0 유지.
	var node: Node = self
	while node != null:
		var b: Node = node.get_node_or_null("StageLayoutBuilder")
		if b != null:
			var layout: Resource = b.get("layout") as Resource
			if layout != null:
				var cs: Variant = layout.get("cell_size")
				if typeof(cs) == TYPE_INT and int(cs) > 0:
					mantle_distance = float(cs) + 4.0
					return
		node = node.get_parent()

func _physics_process(delta: float) -> void:
	# Phase 17 — sticky timer decay. state_machine.update 이전에 처리 (Walker/Carrying이
	# is_stuck()을 같은 frame에 읽음).
	if _sticky_remaining > 0.0:
		_sticky_remaining = max(0.0, _sticky_remaining - delta)
	if state_machine != null:
		state_machine.update(delta)
	_update_sprite()
	_update_trait_badges()

# Phase 17 — StickyHazard.body_entered가 호출. 멱등 — 더 긴 timer 우선(중복 entry 시 더 큰 값 보존).
func apply_sticky(dur: float) -> void:
	if dur > _sticky_remaining:
		_sticky_remaining = dur

# Phase 17 — Walker/Carrying State update가 첫 줄에서 검사하여 좌우 정지 분기.
func is_stuck() -> bool:
	return _sticky_remaining > 0.0

func _update_sprite() -> void:
	# 시각 갱신만 — state 분기 읽어서 animation 매핑 + direction에 따른 flip_h.
	# 게임 로직(state/collision/direction)과 무관, 본 함수 실패해도 시뮬레이션 진행.
	if _sprite == null or state_machine == null:
		return
	var s: AntState = state_machine.current_state
	var anim: String = "idle"
	if s is CarryingState:
		anim = "carry"
	elif s is FallerState:
		anim = "fall"
	elif s is ClimberState:
		anim = "climb"
	elif s is WalkerState:
		anim = "walk"
	elif s is WorkerState:
		var w: String = (s as WorkerState)._work_type
		if w == "blocker":
			anim = "blocker"
		elif w == "builder" or w == "sand_mound" or w == "bridge":
			anim = "build"
		else:
			anim = "dig"
	if anim != _last_anim:
		# climb 애니메이션이 없는 sprite는 fallback "walk"로 재생.
		if anim == "climb" and _sprite.sprite_frames != null and not _sprite.sprite_frames.has_animation("climb"):
			_sprite.play("walk")
			_last_anim = "walk"
		else:
			_sprite.play(anim)
			_last_anim = anim
	_sprite.flip_h = direction < 0

func _update_trait_badges() -> void:
	# 시각 전용 — 로직 무영향. _physics_process 끝에서 호출.
	if _climber_badge != null:
		_climber_badge.visible = has_trait(&"climber")
	if _floater_badge != null:
		_floater_badge.visible = has_trait(&"floater")
	# Phase 15 — SettledState 진입 시 표식. state 기반(분배자 trait 보유여도 정착 전엔 표식 X).
	if _settle_badge != null:
		_settle_badge.visible = state_machine != null and state_machine.current_state is SettledState
	# Phase 17 — sticky stuck 표식. _sticky_remaining timer 기반 (state 무관 — Walker/Carrying 모두 stuck 가능).
	if _sticky_badge != null:
		_sticky_badge.visible = is_stuck()

func is_carrying() -> bool:
	return state_machine != null and state_machine.current_state is CarryingState

func is_alive() -> bool:
	# Phase 7 — CursorTargeting alive 필터. SavedState/DeadState 제외, 그 외(Walker/Faller/Carrying/Worker)는 alive.
	# Phase 15 (F-impl-1 HIGH 대응) — SettledState도 terminal로 분류해 alive=false. 정착 후
	# 어떤 스킬도 적용되지 않도록 단일 진입점 차단. 후속 trait 전이는 정착 시점의 분배자
	# trait dict만 사용 (정착 후 trait 변동 불가).
	# Phase 17 — LostState 추가. HazardBase가 본 함수 단일 진입점으로 terminal 일괄 차단
	# (§0.2 어휘 정합 — HazardBase에서 terminal state 식별자 직접 참조 회피).
	if state_machine == null or state_machine.current_state == null:
		return false
	var s: AntState = state_machine.current_state
	return not (s is SavedState or s is DeadState or s is SettledState or s is LostState)

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
