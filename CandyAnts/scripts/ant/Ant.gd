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

# 풋스텝 SFX — 보폭 기반 트리거. 일정 거리(FOOTSTEP_STRIDE_PX) 이동마다 1회 sfx_request(&"footstep").
# 시간 누적이 아니라 x-이동 거리 기준이라 속도에 자동 비례(끈끈이 감속 = 발소리도 느려짐)하고
# Walker↔Carrying 전이로 상태가 바뀌어도 Ant에 누적이 남아 연속적이다. 글로벌 coalesce/볼륨은 SfxPlayer 담당.
# off-floor(낙하·등반) 진입 시 baseline 리셋 — 착지 직후 즉발 step 방지.
const FOOTSTEP_STRIDE_PX: float = 12.0
var _footstep_ready: bool = false
var _footstep_last_x: float = 0.0

var direction: int = 1
# AntSpawner._spawn_one이 add_child 전에 direction을 세팅하므로 _ready 시점의 direction이
# per-ant 최초 스폰 방향(spawn_direction_alternate 분기 결과 포함). Home._on_respawn_timeout에서
# 빈손 귀가 후 재등장 시 이 값으로 복원해 스폰 방향과 동일한 방향으로 다시 나오게 한다.
var _spawn_direction: int = 1
# 스폰 순번(0-based) — AntSpawner._spawn_one이 add_child 전에 세팅. 결정론 셀렉터/리플레이의 안정적
# tie-break 키(instance_id는 reload·실행 간 달라져 부적합). 미세팅(직접 생성)이면 -1.
var spawn_index: int = -1
var has_been_carrying: bool = false
# state(CarryingState)와 무관하게 사탕 보유 여부를 추적. CarryingState.enter()에서 true,
# Home에 운반 성공 시 false. Faller/Walker 전이로도 잃지 않음 — Codex review HIGH 대응.
var has_candy: bool = false
# 다리 무장(armed bridge, 2026-06-02) — BridgeSkill.apply가 낭떠러지가 아닌 곳에서 부여되면 즉시
# 건설하지 않고 이 플래그만 세운다(인벤토리는 부여 시점 차감 = 소비). Walker/Carrying.update가 매
# frame try_build_armed_bridge()로 검사 → 개미가 낭떠러지(전방 바닥 없음)에 도달하면 그 자리
# (지표면 높이)에서 자동으로 WorkerState("bridge") 진입. 이미 낭떠러지에서 부여하면 apply가 즉시 건설.
var bridge_armed: bool = false
# 계단 무장(armed builder, 2026-06-03) — BridgeSkill과 동일 패턴. BuilderSkill.apply가 낭떠러지가 아닌
# 곳에서 부여되면 즉시 건설하지 않고 이 플래그만 세운다(인벤토리는 부여 시점 차감 = 소비). Walker/Carrying.update가
# 매 frame try_build_armed_builder()로 검사 → 개미가 낭떠러지(전방 바닥 없음)에 도달하면 그 자리에서 자동으로
# WorkerState("builder") 진입(대각 계단 건설). 이미 낭떠러지에서 부여하면 apply가 즉시 건설.
var builder_armed: bool = false
# 굴착 무장(armed basher, 2026-06-05) — BridgeSkill/BuilderSkill 패턴 복제. BasherSkill.apply가 전방이
# 막히지 않은(열린) 곳에서 부여되면 즉시 굴착하지 않고 이 플래그만 세운다(인벤토리는 부여 시점 차감 = 소비).
# Walker.update가 매 frame try_bash_armed_wall()로 검사 → 개미가 흙 벽(전방 셀이 earth)에 도달하면 그
# 자리에서 자동으로 WorkerState("basher") 진입(전방 최대 5칸 굴착 후 해제). 이미 벽에서 부여하면 apply가 즉시 처리.
var basher_armed: bool = false
# 절단 무장(armed cutter, 2026-06-05) — basher와 동일 패턴. CutterSkill.apply가 전방이 막히지 않은(열린)
# 곳에서 부여되면 즉시 절단하지 않고 이 플래그만 세운다. Walker.update가 매 frame try_cut_armed_wall()로
# 검사 → 개미가 식물 벽(전방 셀 plant)에 도달하면 그 자리에서 자동으로 WorkerState("cutter") 진입
# (연결 덩쿨 flood-fill 일괄 절단 후 해제). 이미 식물 벽에서 부여하면 apply가 즉시 처리.
var cutter_armed: bool = false
var state_machine: AntStateMachine = null
# 스폰/리스폰 grace — 스폰 위치가 Home Area2D 내부라 직후 body_entered가 즉시 발화하는 것을 차단.
# 기본(SimConfig.deterministic=false): 벽시계 컷오프(_grace_until, 초). 결정론 모드: 물리-프레임 컷오프
# (_grace_until_frame). arm_spawn_grace/in_spawn_grace 단일 진입점이 모드 분기를 감춘다(Home도 위임).
var _grace_until: float = 0.0
var _grace_until_frame: int = 0
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
# climb 프레임은 720px 캔버스(타 애니는 431px)라 동일 scale에서 ~1.8x 커진다.
# → climb 애니에만 전용 scale을 적용하고, 발이 base와 동일한 바닥선에 닿도록 y를 보정.
# 스케일 1개(_CLIMB_SPRITE_SCALE)만 조정하면 y 오프셋은 _ready에서 자동 재계산된다.
const _CLIMB_SPRITE_SCALE := 0.15   # 머리 크기를 walk 기준과 일치시키는 값(검증: verify_climb_scale 비교)
const _CLIMB_CANVAS_H := 720.0      # climb_*.png 캔버스 높이
const _CLIMB_FEET_Y := 716.0        # climb 프레임 내 발(불투명 px) 하단 y
const _BASE_CANVAS_H := 431.0       # idle/walk/carry/... 캔버스 높이
const _BASE_FEET_Y := 426.0         # base 프레임 내 발 하단 y
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_pos: Vector2 = Vector2.ZERO
var _climb_sprite_scale: Vector2 = Vector2.ONE
var _climb_sprite_pos: Vector2 = Vector2.ZERO

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
# 다리 무장 시 꼬리 배지(y=0)에 다리 아이콘 표시. bridge_armed 기반 토글(climber/floater와 동일 패턴).
var _bridge_badge: Sprite2D = null
# 계단 무장 시 꼬리 배지에 계단(builder) 아이콘 표시. builder_armed 기반 토글(bridge 배지와 동일 슬롯·패턴).
var _builder_badge: Sprite2D = null
# 굴착 무장 시 꼬리 배지에 굴착(basher) 아이콘 표시. basher_armed 기반 토글(bridge/builder 배지와 동일 슬롯).
var _basher_badge: Sprite2D = null
# 절단 무장 시 꼬리 배지에 절단(cutter) 아이콘 표시. cutter_armed 기반 토글(동일 슬롯).
var _cutter_badge: Sprite2D = null
# Phase 15 — 정착 시각 표식. visible toggle은 _update_trait_badges()에서 state 기반.
var _settle_badge: Sprite2D = null

# 끈끈이(StickyHazard) = 감속 존(2026-06-07 재설계, HTML 원안). 과거 "N초 완전정지 + 카운트다운 게이지" 폐기 —
# 끈끈이 셀과 겹쳐있는 동안 effective_speed에 STICKY_SPEED_MULT를 곱해 느리게 기어가게 한다(정지 아님).
# overlap 집합은 StickyHazard body_entered/exited가 enter_sticky/exit_sticky로 갱신(셀별 hazard instance_id).
const STICKY_SPEED_MULT: float = 0.35   # 끈끈이 겹침 중 이동 속도 배율
var _sticky_sources: Dictionary = {}    # 겹쳐있는 StickyHazard instance_id 집합(Set처럼 사용)
var _sticky_badge: Sprite2D = null      # 머리 위 끈끈이 아이콘 — 상시 숨김(노드만 보존)
# 끈끈이 감속 중 땀 연출 — is_slowed() 동안 표시 + 가벼운 bob/fade tween(2026-06-08 요청).
var _sweat_drop: Sprite2D = null
var _sweat_tween: Tween = null

# 나뭇잎 점프대(leaf_jump, 2026-06-05) — 포물선 비행(LeafJumpState) 동안 끈끈이 면역.
# _leaf_jumping은 발사(leaf_jump_launch) 시 true, 착지(LeafJumpState→end_leaf_jump) 시 false.
# leaf_landing_cell이 "착지면 없음"을 알릴 때 쓰는 sentinel도 함께 둔다.
const LEAF_NO_LANDING: Vector2i = Vector2i(2147483647, 2147483647)
var _leaf_jumping: bool = false

func _ready() -> void:
	arm_spawn_grace()
	_spawn_direction = direction
	add_to_group("ants")
	state_machine = $StateMachine
	state_machine.ant = self
	_blocker_hitbox = get_node_or_null("BlockerHitbox") as Area2D
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if _sprite != null:
		# base(walk 등) transform 캐시 + climb 전용 transform 산출. climb 프레임은 더 큰
		# 캔버스라 전용 scale을 쓰고, 발이 base와 같은 바닥선에 닿도록 y를 역산한다.
		_base_sprite_scale = _sprite.scale
		_base_sprite_pos = _sprite.position
		_climb_sprite_scale = Vector2(_CLIMB_SPRITE_SCALE, _CLIMB_SPRITE_SCALE)
		var feet_screen_y: float = _base_sprite_pos.y + (_BASE_FEET_Y - _BASE_CANVAS_H * 0.5) * _base_sprite_scale.y
		var climb_y: float = feet_screen_y - (_CLIMB_FEET_Y - _CLIMB_CANVAS_H * 0.5) * _CLIMB_SPRITE_SCALE
		_climb_sprite_pos = Vector2(_base_sprite_pos.x, climb_y)
	_trait_badges = get_node_or_null("TraitBadges") as Node2D
	# 스킬 뱃지(climber/floater)는 꼬리 컨테이너 아래. 미보유 .tscn에서는 null 안전 fall-back.
	_tail_badges = get_node_or_null("TailBadges") as Node2D
	if _tail_badges != null:
		_climber_badge = _tail_badges.get_node_or_null("ClimberBadge") as Sprite2D
		_floater_badge = _tail_badges.get_node_or_null("FloaterBadge") as Sprite2D
		_blocker_badge = _tail_badges.get_node_or_null("BlockerBadge") as Sprite2D
		_bridge_badge = _tail_badges.get_node_or_null("BridgeBadge") as Sprite2D
		_builder_badge = _tail_badges.get_node_or_null("BuilderBadge") as Sprite2D
		_basher_badge = _tail_badges.get_node_or_null("BasherBadge") as Sprite2D
		_cutter_badge = _tail_badges.get_node_or_null("CutterBadge") as Sprite2D
	if _trait_badges != null:
		_settle_badge = _trait_badges.get_node_or_null("SettleBadge") as Sprite2D
		_sticky_badge = _trait_badges.get_node_or_null("StickyBadge") as Sprite2D
		_sweat_drop = _trait_badges.get_node_or_null("SweatDrop") as Sprite2D
	_resolve_mantle_distance()
	state_machine.change_state(WalkerState.new())

func set_trait(name: StringName) -> void:
	if name == &"":
		return
	traits[name] = true

func has_trait(name: StringName) -> bool:
	return traits.has(name)

# 트레잇 제거 — floater 1회 소멸(분배받은 개미가 낙하산으로 첫 낙하 후 소비) 등에 사용(2026-06-17).
# 배지는 _update_trait_badges가 매 _physics_process마다 has_trait로 갱신하므로 별도 호출 없이 자동 반영된다.
func unset_trait(name: StringName) -> void:
	traits.erase(name)

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
	# 끈끈이는 감속 존(타이머 없음) — overlap 동안 effective_speed가 감속. 여기선 별도 처리 불필요.
	if state_machine != null:
		state_machine.update(delta)
	_check_out_of_bounds()   # 플레이 영역 밑 낙하 → LostState (state.update 이후, 시각 갱신 이전).
	_update_sprite()
	_update_trait_badges()

# StickyHazard body_entered/exited가 호출 — 겹친 끈끈이 셀 집합을 갱신(멱등). 같은 hazard 중복 enter는 무해.
func enter_sticky(source_id: int) -> void:
	_sticky_sources[source_id] = true

func exit_sticky(source_id: int) -> void:
	_sticky_sources.erase(source_id)

# 끈끈이 셀과 겹쳐있는 동안 true — Walker/Carrying이 effective_speed로 감속(완전정지 아님).
func is_slowed() -> bool:
	return not _sticky_sources.is_empty()

func _update_sprite() -> void:
	# 시각 갱신만 — state 분기 읽어서 animation 매핑 + direction에 따른 flip_h.
	# 게임 로직(state/collision/direction)과 무관, 본 함수 실패해도 시뮬레이션 진행.
	if _sprite == null or state_machine == null:
		return
	# 끈끈이는 감속 존 — 개미가 느리게나마 계속 걸으므로 sprite pause 없음(걷기 애니 유지).
	var s: AntState = state_machine.current_state
	var anim: String = "idle"
	if s is DeadState:
		anim = "stun"   # 기절 — 5칸+ 낙하(non-floater). DeadState가 스테이지 종료까지 기절 스프라이트 재생(swim 표류와 동일, queue_free 없음).
	elif s is AdriftState:
		anim = "swim"   # 물 표류 — 수면에서 헤엄(swim) 모션. AdriftState가 매 frame 부유 위치를 갱신.
	elif s is CarryingState:
		anim = "carry"
	elif s is FallerState:
		# 낙하산(floater) 트레잇 보유 시 낙하산 강하 모션, 아니면 일반 낙하.
		anim = "floater" if has_trait(&"floater") else "fall"
	elif s is LeafJumpState:
		# 나뭇잎 점프대 포물선 비행 — 낙하 모션 재사용(상승·하강 구간 모두 fall).
		anim = "fall"
	elif s is ClimberState:
		# 등반 꼭대기(surface 타일 90%+) 또는 mantle 중에는 climb 대신 walk/carry로 전환(시각만).
		if (s as ClimberState).near_surface_top(self):
			anim = "carry" if has_candy else "walk"
		else:
			anim = "climb"
	elif s is LadderClimbState:
		# 막대과자 사다리(sand_mound rung) 수직 등반 — ClimberState와 동일한 등반 모션. 글라이드 중
		# climb 프레임(720px 캔버스) 전용 scale/position 보정은 아래 _last_anim=="climb" 분기가 처리.
		anim = "climb"
	elif s is StairClimbState:
		# 45° 계단 등반 — 회전은 StairClimbState가 _sprite.rotation으로 적용. 운반 중이면 carry 애니 유지.
		anim = "carry" if has_candy else "walk"
	elif s is StairDescentState:
		# 45° 계단 하강 — 낙하 자세(fall)로 미끄럼. 회전은 StairDescentState가 _sprite.rotation으로 적용.
		anim = "fall"
	elif s is SettledState:
		# 낙하산 분배(정착) 중인 캐릭터는 idle 동작.
		anim = "idle"
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
		elif anim == "floater" and _sprite.sprite_frames != null and not _sprite.sprite_frames.has_animation("floater"):
			# 낙하산 애니메이션이 없는 sprite는 안전 fallback "fall".
			_sprite.play("fall")
			_last_anim = "fall"
		elif anim == "swim" and _sprite.sprite_frames != null and not _sprite.sprite_frames.has_animation("swim"):
			# 헤엄 애니메이션이 없는 sprite는 안전 fallback "idle".
			_sprite.play("idle")
			_last_anim = "idle"
		else:
			_sprite.play(anim)
			_last_anim = anim
	# climb 프레임(720px 캔버스) 전용 scale/position 보정. 그 외 애니는 base 복원.
	# _last_anim은 위에서 실제 재생된 애니(climb 미보유 sprite는 "walk"로 fallback)를 반영.
	if _last_anim == "climb":
		_sprite.scale = _climb_sprite_scale
		_sprite.position = _climb_sprite_pos
	elif _last_anim == "floater":
		# 낙하산 모션은 base 대비 30% 크게.
		_sprite.scale = _base_sprite_scale * 1.3
		_sprite.position = _base_sprite_pos
	elif _last_anim == "swim":
		# 수영(표류) 모션은 base 대비 25% 크게. 수면 정렬은 AdriftState.SURFACE_SINK가 담당.
		_sprite.scale = _base_sprite_scale * 1.25
		_sprite.position = _base_sprite_pos
	else:
		_sprite.scale = _base_sprite_scale
		_sprite.position = _base_sprite_pos
	_sprite.flip_h = direction < 0

func _update_trait_badges() -> void:
	# 시각 전용 — 로직 무영향. _physics_process 끝에서 호출.
	# 꼬리 뱃지 컨테이너를 진행 반대쪽(후미)에 위치 — 스프라이트 flip_h(direction<0)와 동일 추적.
	# direction +1(우향): tail 좌측 → x=-TAIL_BADGE_X. direction -1(좌향): tail 우측 → +TAIL_BADGE_X.
	if _tail_badges != null:
		_tail_badges.position.x = -TAIL_BADGE_X * float(direction)
	if _climber_badge != null:
		_climber_badge.visible = has_trait(&"climber")
	# 2026-06-03: 작은 우산(floater) 배지는 *분배 받은* 개미에게만 표시. 분배하는 개미(distributor 트레잇)는
	# 배지 대신 캐릭터 뒤 간판(SettlementMarker·큰 우산)을 달므로 배지 숨김.
	if _floater_badge != null:
		_floater_badge.visible = has_trait(&"floater") and not has_trait(&"distributor")
	# blocker 시각 표식 — WorkerState("blocker")일 때 꼬리 배지 최상위(y=-44)에 차단 아이콘.
	if _blocker_badge != null:
		_blocker_badge.visible = _is_blocker_state()
	# 다리 무장 표식 — bridge_armed인 동안(부여 후 낭떠러지 도달 전까지) 꼬리에 다리 아이콘.
	# 낭떠러지 도달해 건설 진입 시 bridge_armed=false → 배지 사라지고 build 애니로 전환.
	if _bridge_badge != null:
		_bridge_badge.visible = bridge_armed
	# 계단 무장 표식 — builder_armed인 동안(부여 후 낭떠러지 도달 전까지) 꼬리에 계단 아이콘.
	if _builder_badge != null:
		_builder_badge.visible = builder_armed
	# 굴착 무장 표식 — basher_armed인 동안(부여 후 흙 벽 도달 전까지) 꼬리에 굴착 아이콘.
	if _basher_badge != null:
		_basher_badge.visible = basher_armed
	# 절단 무장 표식 — cutter_armed인 동안(부여 후 식물 벽 도달 전까지) 꼬리에 절단 아이콘.
	if _cutter_badge != null:
		_cutter_badge.visible = cutter_armed
	# Phase 15 — SettledState 진입 시 표식. 2026-06-03: 분배 아이콘을 SettlementMarker(캐릭터 뒤쪽·크게)로
	# 일원화하면서, 머리 위 작은 SettleBadge는 중복이라 상시 숨김(노드는 보존).
	if _settle_badge != null:
		_settle_badge.visible = false
	# 끈끈이 표식 — 머리 위 아이콘은 상시 숨김(노드는 보존, 2026-06-07 요청). 감속 존이라 별도 게이지/표식 없음.
	if _sticky_badge != null:
		_sticky_badge.visible = false
	_update_sweat()

# 끈끈이 감속 중 땀방울 연출. is_slowed() 진입/이탈 전이에서만 tween을 켜고/끈다(매 프레임 churn 방지).
func _update_sweat() -> void:
	if _sweat_drop == null:
		return
	var sweating: bool = is_alive() and is_slowed()
	if sweating == _sweat_drop.visible:
		return
	if sweating:
		_sweat_drop.visible = true
		_start_sweat_tween()
	else:
		_stop_sweat_tween()
		_sweat_drop.visible = false

func _start_sweat_tween() -> void:
	_stop_sweat_tween()
	var base_y: float = _sweat_drop.position.y
	_sweat_drop.position.y = base_y
	_sweat_drop.modulate.a = 1.0
	# 살짝 흘러내렸다(+fade) 되돌아오는 yoyo 반복 — 가벼운 땀 연출.
	_sweat_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_sweat_tween.tween_property(_sweat_drop, "position:y", base_y + 4.0, 0.55)
	_sweat_tween.parallel().tween_property(_sweat_drop, "modulate:a", 0.35, 0.55)
	_sweat_tween.tween_property(_sweat_drop, "position:y", base_y, 0.45)
	_sweat_tween.parallel().tween_property(_sweat_drop, "modulate:a", 1.0, 0.45)

func _stop_sweat_tween() -> void:
	if _sweat_tween != null and _sweat_tween.is_valid():
		_sweat_tween.kill()
	_sweat_tween = null

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

# 다리 무장 자동 건설 — Walker/Carrying.update가 매 frame 호출. 무장 상태 + 낭떠러지 도달 시
# 무장 해제 후 WorkerState("bridge") 진입(지표면 높이 그대로). 전이했으면 true(호출부는 즉시 return).
func try_build_armed_bridge() -> bool:
	if not bridge_armed:
		return false
	if state_machine == null or not cliff_ahead():
		return false
	bridge_armed = false
	state_machine.change_state(WorkerState.new("bridge"))
	return true

# 계단 무장 자동 건설 — Walker/Carrying.update가 매 frame 호출. 무장 상태 + 낭떠러지 도달 시
# 무장 해제 후 WorkerState("builder") 진입(대각 계단 건설). 전이했으면 true(호출부는 즉시 return).
# try_build_armed_bridge의 복제 — 공용 cliff_ahead() 술어 사용, work_type만 "builder".
func try_build_armed_builder() -> bool:
	if not builder_armed:
		return false
	if state_machine == null or not cliff_ahead():
		return false
	builder_armed = false
	state_machine.change_state(WorkerState.new("builder"))
	return true

# 굴착 무장 자동 굴착 — Walker.update가 매 frame 호출. 무장 상태 + 흙 벽(전방 셀 earth) 도달 시
# 무장 해제 후 WorkerState("basher") 진입(전방 최대 5칸 굴착). 전이했으면 true(호출부는 즉시 return).
func try_bash_armed_wall() -> bool:
	if not basher_armed:
		return false
	if state_machine == null or not basher_wall_ahead():
		return false
	basher_armed = false
	state_machine.change_state(WorkerState.new("basher"))
	return true

# 절단 무장 자동 절단 — Walker.update가 매 frame 호출. 무장 상태 + 식물 벽(전방 셀 plant) 도달 시
# 무장 해제 후 WorkerState("cutter") 진입(연결 덩쿨 일괄 절단). 전이했으면 true(호출부는 즉시 return).
func try_cut_armed_wall() -> bool:
	if not cutter_armed:
		return false
	if state_machine == null or not cutter_plant_ahead():
		return false
	cutter_armed = false
	state_machine.change_state(WorkerState.new("cutter"))
	return true

# 전방 body-row 셀이 굴착 가능한 흙 벽인지 — basher 무장 자동 굴착 트리거. WorkerState._basher_forward_has_earth와
# 동일 좌표식(body_cell + (dir, 0), kind=="earth")이라 무장 트리거와 실제 굴착 진입 조건이 일치한다.
func basher_wall_ahead() -> bool:
	return _forward_body_cell_kind() == "earth"

# 전방 body-row 셀이 절단 대상 식물 벽인지 — cutter 무장 자동 절단 트리거. WorkerState._cutter_forward_has_plant와
# 동일 좌표식(body_cell + (dir, 0), kind=="plant").
func cutter_plant_ahead() -> bool:
	return _forward_body_cell_kind() == "plant"

# 무장 스킬(basher/cutter) 부여 시 무장 여부 판단 — 전방이 열려 있으면(벽 없음) true → 무장 후 보행.
# 막혀 있으면(흙/식물/쿠키 등) false → Skill.apply가 즉시 WorkerState로 처리(대상이면 작업, 아니면 자연 abort,
# 기존 동작·cross-kind 침범 차단 보존).
func forward_cell_open() -> bool:
	if state_machine == null or direction == 0 or not is_on_floor():
		return false
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor((global_position.y - 2.0) / cs))
	)
	return not terrain.is_cell_occupied(body_cell + Vector2i(direction, 0))

func _forward_body_cell_kind() -> String:
	if state_machine == null or direction == 0 or not is_on_floor():
		return ""
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return ""
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor((global_position.y - 2.0) / cs))
	)
	return terrain.get_cell_kind(body_cell + Vector2i(direction, 0))

# 발판 위 + 진행 방향 전방이 낭떠러지인지 — 전방 셀이 벽이 아니고(벽이면 flip/climb/step-up이 처리)
# 전방 아래 셀에 바닥이 없을 때(=한 칸 더 가면 추락). bridge/builder 무장 즉시 건설 분기와 공용(2026-06-03 리네임).
# add_tile은 target=발밑 전방 셀(body_cell+(dir,+1))에 놓으므로, 이 셀이 비어야(낭떠러지) 건설 가능.
func cliff_ahead() -> bool:
	if state_machine == null or direction == 0 or not is_on_floor():
		return false
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor((global_position.y - 2.0) / cs))
	)
	var forward: Vector2i = body_cell + Vector2i(direction, 0)
	var forward_down: Vector2i = body_cell + Vector2i(direction, 1)
	return not terrain.is_cell_occupied(forward) and not terrain.is_cell_occupied(forward_down)

# 나뭇잎 점프대(leaf_jump) 홉 착지 셀 — 전방 cells칸 열에서 "빈 셀 + 바로 아래 점유(=바닥)"인 착지면을
# 찾는다. 현재 몸 셀 높이에 가까운 행 우선(같은 높이 → 한두 칸 하강 → 한 칸 상승). 없으면 LEAF_NO_LANDING.
# 하단 끈끈이(StickyHazard)는 _placed/_static_occupancy 점유가 아니므로 is_cell_occupied에 안 잡힌다 →
# 착지 후보 셀로 선택되지 않는다(끈끈이 위가 아니라 그 너머 바닥에 내린다).
func leaf_landing_cell(cells: int) -> Vector2i:
	if state_machine == null or direction == 0 or not is_on_floor():
		return LEAF_NO_LANDING
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return LEAF_NO_LANDING
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor((global_position.y - 2.0) / cs))
	)
	var tx: int = body_cell.x + direction * cells
	for dy: int in [0, 1, 2, 3, -1]:
		var c: Vector2i = Vector2i(tx, body_cell.y + dy)
		if not terrain.is_cell_occupied(c) and terrain.is_cell_occupied(c + Vector2i(0, 1)):
			return c
	return LEAF_NO_LANDING

# 나뭇잎 점프대 발동 — 전방 cells타일을 포물선으로 비행(LeafJumpState). 정점 2타일·사거리 cells타일
# (평지) 조건으로 초기 속도를 산출한다. 유도(평지, launch=land 높이 동일):
#   정점 h = v_up²/(2g) = 2·cs           → v_up = 2·√(g·cs)
#   체공 t = 2·v_up/g = 4·√(cs/g)
#   사거리 = vx·t = cells·cs             → vx = (cells/4)·√(g·cs)
# 모션은 낙하(fall) 애니. 비행 내내 끈끈이 면역(_leaf_jumping). can_apply가 착지면을 선제 검증하므로
# 정상 경로에선 허공/벽으로 날지 않는다.
func leaf_jump_launch(cells: int) -> bool:
	if state_machine == null:
		return false
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var base: float = sqrt(gravity * float(cs))   # = √(g·cs)
	var v_up: float = 2.0 * base
	var vx: float = (float(cells) / 4.0) * base * float(direction)
	_leaf_jumping = true
	state_machine.change_state(LeafJumpState.new(vx, -v_up))
	return true

# LeafJumpState가 착지 시 호출 — 끈끈이 면역 해제. (발사~착지 사이에만 면역.)
func end_leaf_jump() -> void:
	_leaf_jumping = false

# 나뭇잎 점프대 비행 중 면역 — StickyHazard가 enter_sticky 전 검사(포물선으로 넘는 동안 끈끈이 감속 무효).
func is_jump_immune() -> bool:
	return _leaf_jumping

# 계단(STAIR) 부드러운 45° 등반 게이트 — 단일 SoT. Walker/Carrying 진입(dir=direction)과
# StairClimbState 연속 스텝(dir=_dir lock) 양쪽이 공유. dir_override=0이면 self.direction 사용.
# 조건(전부 충족): (1) 전방 셀이 점유=올라설 벽 존재 → 허공 over-climb 차단(codex 2026-06-03 HIGH).
#   (2) 올라설 자리(전방+위) 빔. (3) 전방 또는 발밑이 STAIR 셀 → 정적 벽은 게이트 불충족=flip(climber 퍼즐 보존).
# 하강은 전방 셀이 비어 점유 조건 불충족 → 비대칭(상승만 발동).
func stair_climb_ahead(dir_override: int = 0) -> bool:
	var dir: int = dir_override if dir_override != 0 else direction
	if dir == 0:
		return false
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor((global_position.y - 2.0) / cs))
	)
	var front: Vector2i = body_cell + Vector2i(dir, 0)
	var below: Vector2i = body_cell + Vector2i(0, 1)
	var dest: Vector2i = body_cell + Vector2i(dir, -1)
	if not terrain.is_cell_occupied(front):
		return false   # 전방 벽 없음 = 올라설 대상 없음(계단 꼭대기 허공) → 등반 금지(over-climb 차단).
	if terrain.is_cell_occupied(dest):
		return false   # 올라설 자리 막힘(레지/천장).
	return terrain.is_stair_cell(front) or terrain.is_stair_cell(below)

# 계단(STAIR) 부드러운 45° 하강 게이트 (2026-06-03). stair_climb_ahead의 하강 대칭.
# 계단 표면에서 하강 방향으로 진행 시 수직 낙하 대신 전방+아래 대각 미끄럼(StairDescentState)으로 전이.
# 조건(전부): (1) 발밑(body+아래)이 STAIR = 계단 위에 서 있음. (2) 전방 빔 = 올라설 벽 없음(등반 아님).
# (3) 전방-아래 빔 = 전방 바닥 없음(가장자리/허공). (4) 착지 칸(전방 2칸 아래)이 STAIR(다음 계단) 또는
# solid 지면(맨 아래 단 → 플랫폼 최종 미끄럼). (3)이 위를 비워두므로 벽에 박지 않고 그 위로 올라선다.
func stair_descent_ahead(dir_override: int = 0) -> bool:
	var dir: int = dir_override if dir_override != 0 else direction
	if dir == 0:
		return false
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor((global_position.y - 2.0) / cs))
	)
	if not terrain.is_stair_cell(body_cell + Vector2i(0, 1)):
		return false   # 발밑이 계단 아님 → 일반 보행/낙하.
	if terrain.is_cell_occupied(body_cell + Vector2i(dir, 0)):
		return false   # 전방 벽 = 등반 상황(stair_climb_ahead 담당), 하강 아님.
	if terrain.is_cell_occupied(body_cell + Vector2i(dir, 1)):
		return false   # 전방 바닥 있음 = 아직 가장자리 아님(평평 보행 중).
	# 착지 칸이 다음 계단(STAIR)이면 연속 하강, solid 지면이면 맨 아래 단→플랫폼 최종 미끄럼.
	var land: Vector2i = body_cell + Vector2i(dir, 2)
	return terrain.is_stair_cell(land) or terrain.is_cell_occupied(land)

# 막대과자 사다리(SAND_MOUND rung) 수직 등반 게이트 (2026-06-03 follower 통행).
# 시전 개미가 깔아둔 rung 벽에 막혀 멈춘 후속 walker를 LadderClimbState로 전이시키는 단일 SoT.
# 조건: 진행 방향 전방 셀이 동적 ladder rung 셀일 것. 정적 벽(분지/단)은 is_ladder_cell=false라
# 게이트 불충족 → 기존 flip 유지(climber/캡 퍼즐 보존). 등반 종료·캡은 LadderClimbState가 담당한다
# (전방이 rung인 한 진입만 책임지고, 허공 over-climb·런어웨이는 상태 안전망이 처리).
func ladder_climb_ahead(dir_override: int = 0) -> bool:
	var dir: int = dir_override if dir_override != 0 else direction
	if dir == 0:
		return false
	var terrain: Terrain = _find_terrain()
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor((global_position.y - 2.0) / cs))
	)
	var front: Vector2i = body_cell + Vector2i(dir, 0)
	return terrain.is_ladder_cell(front)

func _find_terrain() -> Terrain:
	# WalkerState/WorkerState._find_terrain와 동일 — ancestor chain에서 Terrain 노드 탐색.
	var n: Node = get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null

func is_alive() -> bool:
	# Phase 7 — CursorTargeting alive 필터. SavedState/DeadState 제외, 그 외(Walker/Faller/Carrying/Worker)는 alive.
	# Phase 15 (F-impl-1 HIGH 대응) — SettledState도 terminal로 분류해 alive=false. 정착 후
	# 어떤 스킬도 적용되지 않도록 단일 진입점 차단. 후속 trait 전이는 정착 시점의 분배자
	# trait dict만 사용 (정착 후 trait 변동 불가).
	# Phase 17 — LostState 추가. HazardBase가 본 함수 단일 진입점으로 terminal 일괄 차단
	# (§0.2 어휘 정합 — HazardBase에서 terminal state 식별자 직접 참조 회피).
	# 2026-06-04 — AdriftState(물 표류) terminal 추가. 표류 중 추가 hazard·스킬·out-of-bounds 차단.
	if state_machine == null or state_machine.current_state == null:
		return false
	var s: AntState = state_machine.current_state
	return not (s is SavedState or s is DeadState or s is SettledState or s is LostState or s is AdriftState)

# 터치/클릭 스킬 부여 타겟 좌표 — 충돌 원점(발, y=0)이 아니라 보이는 캐릭터(스프라이트) 중심.
# 스프라이트는 원점보다 ~44px 위에 그려지므로(Sprite.position.y=-43.5), 원점 기준 판정 시
# 머리 터치가 빠진다(2026-06-04 버그). 등반 등으로 _sprite.position이 바뀌어도 global이 따라감.
func tap_target_position() -> Vector2:
	if _sprite != null:
		return _sprite.global_position
	return global_position

func effective_speed() -> float:
	# 사탕 보유 = 0.78배(state가 Faller/Walker로 잠시 빠져도 페널티 유지) + 끈끈이 겹침 = STICKY_SPEED_MULT배(감속 존).
	var mult: float = (carrying_speed_multiplier if has_candy else 1.0)
	if is_slowed():
		mult *= STICKY_SPEED_MULT
	return walk_speed * mult

func stun_fall_threshold() -> float:
	# 기절 임계 낙하 거리(px). FallerState 착지 시 (착지y − 시작y) >= 이 값 + floater 미보유 → DeadState(기절).
	return float(STUN_FALL_CELLS) * _cell_size

# 스폰/리스폰 직후 grace 무장 — Home Area2D 즉시 재발화 차단. 결정론 모드는 물리-프레임 컷오프,
# 기본은 벽시계. spawn_grace_seconds 의미 동일(time_scale=1에서 동일 프레임 수). Ant._ready + Home 리스폰 공용.
func arm_spawn_grace() -> void:
	if SimConfig.deterministic:
		_grace_until_frame = Engine.get_physics_frames() + SimConfig.seconds_to_frames(spawn_grace_seconds)
	else:
		_grace_until = Time.get_ticks_msec() / 1000.0 + spawn_grace_seconds

# grace 기간 내인지 — Home._on_body_entered가 spawn/respawn 직후 1회 발화 차단에 사용(모드 분기 캡슐화).
func in_spawn_grace() -> bool:
	if SimConfig.deterministic:
		return Engine.get_physics_frames() < _grace_until_frame
	return Time.get_ticks_msec() / 1000.0 < _grace_until

func flip() -> void:
	direction = -direction

# 보폭 기반 풋스텝 — Walker/Carrying.update가 move_and_slide 직후 매 frame 호출.
# 바닥에 있고 직전 발소리 지점에서 FOOTSTEP_STRIDE_PX 이상 이동했으면 footstep 요청.
# 다수 개미 동시 보행은 SfxPlayer의 글로벌 쓰로틀이 잔잔한 patter로 뭉친다(여기선 cap 없음).
func footstep_tick() -> void:
	if not is_on_floor():
		_footstep_ready = false   # 공중 진입 → 착지 시 baseline 재설정(즉발 step 방지)
		return
	if not _footstep_ready:
		_footstep_ready = true
		_footstep_last_x = global_position.x
		return
	if absf(global_position.x - _footstep_last_x) >= FOOTSTEP_STRIDE_PX:
		_footstep_last_x = global_position.x
		# 끈끈이 감속 중엔 먹먹한 전용 발소리 — 거리 기반이라 보폭 간격도 자동으로 벌어진다(질척 느낌).
		# 리터럴 emit 2개로 분기(삼항 금지) — SfxReceiverTest repo-스캐너가 두 id를 모두 잡도록.
		if is_slowed():
			EventBus.sfx_request.emit(&"footstep_sticky")
		else:
			EventBus.sfx_request.emit(&"footstep")

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
