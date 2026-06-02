class_name Ant extends CharacterBody2D

signal bumped_blocker(direction: int)

@export var walk_speed: float = 90.0
@export var gravity: float = 1350.0
@export var carrying_speed_multiplier: float = 0.78
@export var spawn_grace_seconds: float = 0.4

# Phase 14 — traits (Climber/Floater). climber 보유 시 벽 만남에서 ClimberState 전이,
# floater 보유 시 FallerState에서 중력 0.3배. 영구 보유(해제 API 없음).
const FLOATER_GRAVITY_SCALE: float = 0.3
const CLIMB_SPEED: float = 60.0
# mantle 거리는 ancestor chain의 StageLayoutBuilder.layout.cell_size + 6 로 runtime 갱신.
# 미발견 시 54.0(=48+6) fallback. Stage01~03 모두 cell_size=48이므로 fallback 정확.
var mantle_distance: float = 54.0

# Out-of-bounds 탈락 — 개미가 플레이 영역(layout.tile_map 범위) 밖(아래·좌·우)으로 벗어나면 LostState로 처리.
# 경계 = (최저 행 + KILL_MARGIN_CELLS) * cell_size. layout 미발견/파싱 실패 시 _kill_y=INF로
# 비활성(false-trigger 방지). _resolve_mantle_distance가 동일 layout 스캔에서 함께 산출.
# 마진은 layout 최심 셀 기준이라 "바닥 타일 위에 선 개미"는 안 걸리고 실제 낙하만 포착.
const KILL_MARGIN_CELLS: int = 3
var _kill_y: float = INF       # 바닥 경계 — 이 아래로 떨어지면 lost
var _kill_x_min: float = -INF  # 좌 경계 — 이 왼쪽으로 나가면 lost
var _kill_x_max: float = INF   # 우 경계 — 이 오른쪽으로 나가면 lost

# 기절(stun) — 5칸 이상 자유낙하 + floater 미보유 시 FallerState가 DeadState(기절)로 전이.
# 임계 = STUN_FALL_CELLS * _cell_size. _cell_size는 _resolve_mantle_distance가 layout에서 갱신,
# 미발견 시 48(메인 스테이지 표준 cell_size). floater는 높이 무관 기절 무효(레밍즈 정통).
const STUN_FALL_CELLS: int = 5
var _cell_size: float = 48.0

var direction: int = 1
# AntSpawner._spawn_one이 add_child 전에 direction을 세팅하므로 _ready 시점의 direction이
# per-ant 최초 스폰 방향(spawn_direction_alternate 분기 결과 포함). Home._on_respawn_timeout에서
# 빈손 귀가 후 재등장 시 이 값으로 복원해 스폰 방향과 동일한 방향으로 다시 나오게 한다.
var _spawn_direction: int = 1
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
# 스킬 부여 뱃지(climber/floater)는 머리가 아니라 캐릭터 꼬리(진행 반대쪽)에 단다.
# _tail_badges 컨테이너의 x를 direction에 따라 좌우 반전해 항상 후미에 위치시킨다.
# (settle/sticky 표식은 _trait_badges = 머리 위 그대로 유지.)
const TAIL_BADGE_X: float = 26.0
var _tail_badges: Node2D = null
var _climber_badge: Sprite2D = null
var _floater_badge: Sprite2D = null
# blocker 적용 시 꼬리 배지 최상위(y=-44)에 차단 아이콘 표시. WorkerState("blocker") 기반 토글.
var _blocker_badge: Sprite2D = null
# Phase 15 — 정착 시각 표식. visible toggle은 _update_trait_badges()에서 state 기반.
var _settle_badge: Sprite2D = null

# Phase 17 — 끈끈이(StickyHazard) timer. apply_sticky로 설정, _physics_process에서 매 frame 감소.
# WalkerState/CarryingState update가 is_stuck() 분기로 좌우 정지.
var _sticky_remaining: float = 0.0
var _sticky_badge: Sprite2D = null
# Phase 20 (P-D4 / R1-M3) — progress bar denominator. apply_sticky fresh entry는 새 dur로 set,
# 진행 중 재진입은 max(old, new) 보존. timer 만료(==0 도달) 시 0으로 reset해 다음 fresh entry가
# stale 값을 denominator로 잡지 않도록 한다.
var _sticky_max: float = 0.0
var _sticky_bar: Sprite2D = null
# Phase 20 (P-D5 / R1-H3) — _update_sprite의 `anim != _last_anim` 분기가 unstuck 후 동일 anim
# (예: walk→walk)일 때 play() 미호출 → 영구 pause 위험. flag로 stuck 진입 시 pause + unstuck 시
# 명시 play(_last_anim) 재호출 트리거.
var _sprite_paused_for_sticky: bool = false

func _ready() -> void:
	_grace_until = Time.get_ticks_msec() / 1000.0 + spawn_grace_seconds
	_spawn_direction = direction
	add_to_group("ants")
	state_machine = $StateMachine
	state_machine.ant = self
	_blocker_hitbox = get_node_or_null("BlockerHitbox") as Area2D
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	_trait_badges = get_node_or_null("TraitBadges") as Node2D
	# 스킬 뱃지(climber/floater)는 꼬리 컨테이너 아래. 미보유 .tscn에서는 null 안전 fall-back.
	_tail_badges = get_node_or_null("TailBadges") as Node2D
	if _tail_badges != null:
		_climber_badge = _tail_badges.get_node_or_null("ClimberBadge") as Sprite2D
		_floater_badge = _tail_badges.get_node_or_null("FloaterBadge") as Sprite2D
		_blocker_badge = _tail_badges.get_node_or_null("BlockerBadge") as Sprite2D
	if _trait_badges != null:
		_settle_badge = _trait_badges.get_node_or_null("SettleBadge") as Sprite2D
		_sticky_badge = _trait_badges.get_node_or_null("StickyBadge") as Sprite2D
		# Phase 20 — StickyTimerBar (Sprite2D). 미보유 .tscn에서는 null로 안전 fall-back.
		_sticky_bar = _trait_badges.get_node_or_null("StickyTimerBar") as Sprite2D
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
	# 모두 실패 시 fallback 54.0 유지.
	var node: Node = self
	while node != null:
		var b: Node = node.get_node_or_null("StageLayoutBuilder")
		if b != null:
			var layout: Resource = b.get("layout") as Resource
			if layout != null:
				var cs: Variant = layout.get("cell_size")
				if typeof(cs) == TYPE_INT and int(cs) > 0:
					mantle_distance = float(cs) + 6.0
					_resolve_kill_bounds(layout, int(cs))
					return
		node = node.get_parent()

func _resolve_kill_bounds(layout: Resource, cs: int) -> void:
	# 기절 임계(stun_fall_threshold) 산출용 cell_size 캐시 — mantle/kill 경계와 동일 layout 스캔에서 함께 산출.
	_cell_size = float(cs)
	# 플레이 영역 경계 = layout.tile_map의 셀 범위. 그 밖으로 KILL_MARGIN_CELLS 칸 이상
	# (아래·좌·우) 벗어나면 out-of-bounds. tile_map 비었거나 키 파싱 불가 시 경계 ±INF(비활성).
	# 키는 "x,y" 문자열 (StageLayoutBuilder._cell_from_key 컨벤션 동일). 위쪽은 등반/floater가
	# 정상 상승하므로 경계 없음.
	var tm: Variant = layout.get("tile_map")
	if typeof(tm) != TYPE_DICTIONARY:
		return
	var min_col: int = 0
	var max_col: int = 0
	var max_row: int = 0
	var found: bool = false
	for key in (tm as Dictionary).keys():
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2:
			continue
		var col: int = int(parts[0])
		var row: int = int(parts[1])
		if not found:
			min_col = col
			max_col = col
			max_row = row
			found = true
		else:
			min_col = min(min_col, col)
			max_col = max(max_col, col)
			max_row = max(max_row, row)
	if not found:
		return
	_kill_x_min = float((min_col - KILL_MARGIN_CELLS) * cs)
	_kill_x_max = float((max_col + 1 + KILL_MARGIN_CELLS) * cs)
	_kill_y = float((max_row + 1 + KILL_MARGIN_CELLS) * cs)

func _check_out_of_bounds() -> void:
	# 플레이 영역 밖(아래·좌·우)으로 벗어난 개미 → LostState (보유 사탕 candy_piece_lost 정산 + queue_free).
	# is_alive() 가드로 terminal state 멱등 차단. 경계 ±INF(layout 미발견)면 항상 no-op.
	var p: Vector2 = global_position
	if p.y <= _kill_y and p.x >= _kill_x_min and p.x <= _kill_x_max:
		return
	if state_machine == null or not is_alive():
		return
	state_machine.change_state(LostState.new())

func _physics_process(delta: float) -> void:
	# Phase 17 — sticky timer decay. state_machine.update 이전에 처리 (Walker/Carrying이
	# is_stuck()을 같은 frame에 읽음).
	if _sticky_remaining > 0.0:
		_sticky_remaining = max(0.0, _sticky_remaining - delta)
		# Phase 20 (R1-M3) — timer 만료 시 denominator 같이 reset해 다음 fresh entry가 stale 값
		# 사용 안 하도록.
		if _sticky_remaining == 0.0:
			_sticky_max = 0.0
	if state_machine != null:
		state_machine.update(delta)
	_check_out_of_bounds()   # 플레이 영역 밑 낙하 → LostState (state.update 이후, 시각 갱신 이전).
	_update_sprite()
	_update_trait_badges()
	_update_sticky_bar()   # Phase 20 — bar scale + visible toggle (1 호출, 시각 전용).

# Phase 17 — StickyHazard.body_entered가 호출. 멱등 — 더 긴 timer 우선(중복 entry 시 더 큰 값 보존).
# Phase 20 (R1-M3) — `_sticky_max` lifecycle: fresh entry(== 0 도달 후)면 새 dur로 set,
# 진행 중 재진입은 max(old, new) 보존. 단조 감소 보장 — 2회 apply_sticky(3.0 → 1.0) 시 first 만료
# 후 second는 정확히 1.0/1.0=1.0 부터 시작.
func apply_sticky(dur: float) -> void:
	if dur > _sticky_remaining:
		_sticky_remaining = dur
	if _sticky_max == 0.0:
		_sticky_max = dur
	else:
		_sticky_max = max(_sticky_max, dur)

# Phase 20 — StickyTimerBar 시각 갱신. 시각 전용, 게임 로직 무영향.
# bar.scale.x = _sticky_remaining / _sticky_max (범위 [0, 1]). visible은 stuck 중에만 true.
func _update_sticky_bar() -> void:
	if _sticky_bar == null:
		return
	if _sticky_remaining > 0.0 and _sticky_max > 0.0:
		_sticky_bar.scale.x = clamp(_sticky_remaining / _sticky_max, 0.0, 1.0)
		_sticky_bar.visible = true
	else:
		_sticky_bar.visible = false

# Phase 17 — Walker/Carrying State update가 첫 줄에서 검사하여 좌우 정지 분기.
func is_stuck() -> bool:
	return _sticky_remaining > 0.0

func _update_sprite() -> void:
	# 시각 갱신만 — state 분기 읽어서 animation 매핑 + direction에 따른 flip_h.
	# 게임 로직(state/collision/direction)과 무관, 본 함수 실패해도 시뮬레이션 진행.
	if _sprite == null or state_machine == null:
		return
	# Phase 20 (R1-H3) — stuck 진입 시 sprite pause, unstuck 시 명시 play(_last_anim) 재호출.
	# `anim != _last_anim` 분기가 unstuck 후 동일 anim(예: walk→walk)에서 play() 미호출 →
	# 영구 pause 위험을 flag로 차단.
	if is_stuck():
		if _sprite is AnimatedSprite2D and not _sprite_paused_for_sticky:
			(_sprite as AnimatedSprite2D).pause()
			_sprite_paused_for_sticky = true
		return
	if _sprite_paused_for_sticky:
		# unstuck 직후 명시 play() 재개. _last_anim이 비어있으면 안전 skip (다음 anim 변경에서 play() 발화).
		if _sprite is AnimatedSprite2D and not _last_anim.is_empty():
			(_sprite as AnimatedSprite2D).play(_last_anim)
		_sprite_paused_for_sticky = false
	var s: AntState = state_machine.current_state
	var anim: String = "idle"
	if s is DeadState:
		anim = "stun"   # 기절 — 5칸+ 낙하(non-floater). DeadState가 기절 스프라이트 재생 후 ~1초 뒤 queue_free.
	elif s is CarryingState:
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
		elif anim == "stun" and _sprite.sprite_frames != null and not _sprite.sprite_frames.has_animation("stun"):
			# 기절 애니메이션이 없는 sprite는 안전 fallback "idle".
			_sprite.play("idle")
			_last_anim = "idle"
		else:
			_sprite.play(anim)
			_last_anim = anim
	_sprite.flip_h = direction < 0

func _update_trait_badges() -> void:
	# 시각 전용 — 로직 무영향. _physics_process 끝에서 호출.
	# 꼬리 뱃지 컨테이너를 진행 반대쪽(후미)에 위치 — 스프라이트 flip_h(direction<0)와 동일 추적.
	# direction +1(우향): tail 좌측 → x=-TAIL_BADGE_X. direction -1(좌향): tail 우측 → +TAIL_BADGE_X.
	if _tail_badges != null:
		_tail_badges.position.x = -TAIL_BADGE_X * float(direction)
	if _climber_badge != null:
		_climber_badge.visible = has_trait(&"climber")
	if _floater_badge != null:
		_floater_badge.visible = has_trait(&"floater")
	# blocker 시각 표식 — WorkerState("blocker")일 때 꼬리 배지 최상위(y=-44)에 차단 아이콘.
	if _blocker_badge != null:
		_blocker_badge.visible = _is_blocker_state()
	# Phase 15 — SettledState 진입 시 표식. state 기반(분배자 trait 보유여도 정착 전엔 표식 X).
	if _settle_badge != null:
		_settle_badge.visible = state_machine != null and state_machine.current_state is SettledState
	# Phase 17 — sticky stuck 표식. _sticky_remaining timer 기반 (state 무관 — Walker/Carrying 모두 stuck 가능).
	if _sticky_badge != null:
		_sticky_badge.visible = is_stuck()

func _is_blocker_state() -> bool:
	# WorkerState의 work_type이 "blocker"일 때만 true. _update_sprite의 _work_type 접근 패턴 답습.
	if state_machine == null:
		return false
	var s: AntState = state_machine.current_state
	return s is WorkerState and (s as WorkerState)._work_type == "blocker"

func is_carrying() -> bool:
	return state_machine != null and state_machine.current_state is CarryingState

# 보행 복귀 (Worker/Faller/Climber 작업 종료 시 단일 진입점) — has_candy 검사로 carry 모션 유지.
# Ant._update_sprite는 state class 기반 animation 매핑이라 has_candy=true인 채로 WalkerState로
# 전이하면 sprite가 "walk"로 잘못 표시됨. 모든 종료 분기에서 본 helper로 통일.
func return_to_walking() -> void:
	if state_machine == null:
		return
	if has_candy:
		state_machine.change_state(CarryingState.new())
	else:
		state_machine.change_state(WalkerState.new())

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

func stun_fall_threshold() -> float:
	# 기절 임계 낙하 거리(px). FallerState 착지 시 (착지y − 시작y) >= 이 값 + floater 미보유 → DeadState(기절).
	return float(STUN_FALL_CELLS) * _cell_size

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
