class_name CharacterBase
extends CharacterBody3D

## =====================================================================
##  CharacterBase — 모든 플레이어 캐릭터(FS/EF/WM)의 공통 기반
##  - 스켈레톤 구축 (Node3D 계층)
##  - PoseSystem 보간
##  - StateMachine 보유
##  - 전투 로직 (콤보/대시/피격)
##  서브클래스는 스탯 override + _init_materials + pose_map만 커스터마이즈
## =====================================================================

# --- 치수 (HTML buildGeometry 원본 값) ---
const HEAD_H   := 0.23
const HEAD_W   := 0.19
const HEAD_D   := 0.21
const CHEST_H  := 0.25
const CHEST_W  := 0.33
const CHEST_D  := 0.20
const WAIST_H  := 0.14
const WAIST_W  := 0.22
const WAIST_D  := 0.16
const PELVIS_H := 0.19
const PELVIS_W := 0.30
const PELVIS_D := 0.22
const THIGH_L  := 0.30
const CALF_L   := 0.50
const LEG_H    := THIGH_L + CALF_L  # 0.8
const THIGH_W  := 0.16
const CALF_W   := 0.11
const ARM_W    := 0.08
const UPPER_ARM_L := 0.32
const FOREARM_L   := 0.35
const HAND_S   := 0.07

# --- 캐릭터 스탯 (서브클래스에서 _ready 시작부에 override) ---
var MAX_SPEED: float           = 6.0
var ACCELERATION: float        = 14.0
var DAMPING: float             = 18.0
var TURN_SPEED: float          = 15.0
var GRAVITY: float             = -20.0
var ATTACK_RANGE: float        = 2.0
var ATTACK_ANGLE: float        = PI / 3.0
var AGGRO_RADIUS: float        = 10.5   # 전투 모드 진입 거리
var COMBO_MAX: int             = 3
var DASH_SPEED: float          = 8.0   # HTML 원본 — 0.25s × 8.0 = 약 2m
var DASH_DURATION: float       = 0.25
var SKILL_COOLDOWN_MAX: float  = 8.0

# --- 머티리얼 (서브클래스에서 오버라이드 가능) ---
var mat_chest: StandardMaterial3D
var mat_waist: StandardMaterial3D
var mat_pelvis: StandardMaterial3D
var mat_skin: StandardMaterial3D
var mat_hair: StandardMaterial3D
var mat_right: StandardMaterial3D
var mat_left: StandardMaterial3D

# --- PoseSystem ---
var pose_system: PoseSystem = PoseSystem.new()
var parts: Dictionary = {}
var current_pose: Dictionary = PoseData.POSES["idle"]
var pose_speed: float = 10.0
var skip_pose_update: bool = false   # 절차적 애니메이션 시 true

# --- 포즈 이름 매핑 (서브클래스에서 오버라이드) ---
var pose_map: Dictionary = {}

# --- 전투 변수 ---
var combo_step      : int   = 0
var attack_timer    : float = 0.0
var attack_duration : float = 0.5
var active_end      : float = 0.25
var hold_start      : float = 0.155   # active_end * 0.62 — 이후 forward 감속
var has_hit         : bool  = false
var input_buffered  : bool  = false
var combo_cooldown  : float = 0.0

# --- 첫 공격 거리 분기 ---
# "" = 일반 콤보, "step_strike" / "dash" / "leap" = 특수 첫 공격
var special_mode   : String = ""
var dash_end       : float  = 0.0     # dash/leap phase 전환 시점
var attack_dash_dist: float = 0.0     # 특수 공격 접근 거리

# --- 전투 모드 (aggroRadius 내 적 있으면 true, 2초 linger) ---
var is_combat_mode : bool  = false
var combat_timer   : float = 0.0

var dash_timer : float   = 0.0
var dash_dir   : Vector3 = Vector3.ZERO
var is_back_dash : bool  = false   # 입력 없이 대시 발동 시 true → 뒤로 후퇴

var hurt_timer    : float   = 0.0
var knockback_vel : Vector3 = Vector3.ZERO

var skill_cooldown : float = 0.0
var mp             : int   = 0
var max_mp         : int   = 50

# --- 방향 ---
var facing_angle  : float = 0.0
var target_facing : float = 0.0
var anim_timer    : float = 0.0

# --- 외부 참조 (GameManager에서 주입) ---
var game_manager : GameManager = null
var goblins      : Array       = []
var camera_rig   : CameraRig   = null

# --- StateMachine ---
var state_machine : StateMachine = StateMachine.new()

# --- Pivot (facing 회전용, 스켈레톤 부모) ---
var pivot: Node3D


# =====================================================================
#  _ready — 스켈레톤 구축 + State 등록
# =====================================================================
func _ready() -> void:
	_init_materials()
	_build_skeleton()

	# State 등록
	state_machine.add_state("idle",         IdleState.new(self))
	state_machine.add_state("walk",         WalkState.new(self))
	state_machine.add_state("attack",       AttackState.new(self))
	state_machine.add_state("dash",         DashState.new(self))
	state_machine.add_state("hurt",         HurtState.new(self))
	state_machine.add_state("chargeAttack", ChargeAttackState.new(self))
	state_machine.add_state("skill",        SkillState.new(self))
	state_machine.add_state("ultimate",     UltimateState.new(self))
	state_machine.add_state("swapOut",      SwapOutState.new(self))
	state_machine.add_state("swapIn",       SwapInState.new(self))
	# IdleState.enter()가 set_pose()를 호출 → pose_map 적용된 current_pose 확정
	state_machine.change_state("idle")

	# 매핑 적용된 idle 포즈를 첫 프레임에 즉시 반영 (보간 없이)
	# — _ready 초기에 적용하면 EF/WM이 잠깐 FS idle을 보이는 문제 회피
	pose_system.apply_pose(parts, current_pose, 999.0, 1.0)

	# 디버그: 공격 판정 범위 시각화
	_setup_debug_hitrange()


# =====================================================================
#  _physics_process — 공통 흐름
# =====================================================================
func _physics_process(delta: float) -> void:
	if game_manager and game_manager.is_game_over:
		return

	combo_cooldown = maxf(0.0, combo_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)

	_update_combat_mode(delta)
	state_machine.update(delta)

	# 포즈 보간 — state.update에서 set_pose()로 갱신된 current_pose를 같은 틱에 반영
	# (절차적 애니메이션 중엔 스킵)
	if not skip_pose_update:
		pose_system.apply_pose(parts, current_pose, pose_speed, delta)

	# 중력
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_update_facing(delta)


# =====================================================================
#  포즈 전환 (pose_map 적용)
# =====================================================================
func set_pose(pose_name: String, speed: float = 10.0) -> void:
	var mapped: String = pose_map.get(pose_name, pose_name)
	if PoseData.POSES.has(mapped):
		current_pose = PoseData.POSES[mapped]
		pose_speed = speed


# =====================================================================
#  공용 메서드 (State에서 호출)
# =====================================================================

func apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DAMPING * delta)
	velocity.z = move_toward(velocity.z, 0.0, DAMPING * delta)

func get_move_dir() -> Vector3:
	var raw: Vector2 = InputManager.move_input
	if raw == Vector2.ZERO:
		return Vector3.ZERO
	var theta: float = camera_rig.theta if camera_rig else 0.0
	var fwd := Vector3(-sin(theta), 0.0, -cos(theta))
	var rgt := Vector3( cos(theta), 0.0, -sin(theta))
	return (rgt * raw.x + fwd * -raw.y).normalized()

func get_nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var min_d: float = INF
	for g in goblins:
		if not is_instance_valid(g) or g.get("is_dead"):
			continue
		var gn: Node3D = g
		var d: float = global_position.distance_to(gn.global_position)
		if d < min_d:
			min_d = d
			nearest = gn
	return nearest

func start_attack() -> void:
	# 거리 기반 첫 공격 분기 (HTML pickComboStep 이식)
	var mode: String = pick_first_attack()

	if mode == "shoulder_bash":
		# 근접: 밀치기 → ChargeAttack 재사용
		special_mode = ""
		state_machine.change_state("chargeAttack")
		return

	special_mode = mode   # "" / "step_strike" / "dash" / "leap"
	combo_step = 1
	state_machine.change_state("attack")


## 거리 기반 첫 공격 선택 (HTML pickComboStep 이식)
func pick_first_attack() -> String:
	var nearest: Node3D = get_nearest_enemy()
	if nearest == null:
		return ""   # 기본 콤보
	var dist: float = global_position.distance_to(nearest.global_position)
	if dist > 10.0:
		return ""
	if dist < 1.0:
		return "shoulder_bash"
	if dist < 3.0:
		return ""
	if dist < 4.5:
		return "step_strike"
	if dist < 7.0:
		return "dash"
	return "leap"

func start_dash() -> void:
	# HTML DashState.enter 이식 — WASD 입력 있으면 그 방향으로, 없으면 뒤로(백대시)
	var dir: Vector3 = get_move_dir()
	if dir.length() >= 0.1:
		dash_dir = dir.normalized()
		is_back_dash = false
		# 입력 방향으로 즉시 회전 (HTML setFromAxisAngle)
		var ang: float = atan2(-dash_dir.x, -dash_dir.z)
		target_facing    = ang
		facing_angle     = ang
		pivot.rotation.y = ang
	else:
		# 입력 없음 → 현재 forward의 반대(=백대시)
		dir = pivot.global_transform.basis.z   # +Z = 뒤
		dir.y = 0
		dash_dir = dir.normalized()
		is_back_dash = true
	dash_timer = 0.0
	state_machine.change_state("dash")

func check_hit() -> void:
	var fwd: Vector3 = -pivot.global_transform.basis.z
	fwd.y = 0
	if fwd.length() > 0.01:
		fwd = fwd.normalized()

	for g in goblins:
		if not is_instance_valid(g) or g.get("is_dead"):
			continue
		var gn: Node3D = g
		var to_e: Vector3 = gn.global_position - global_position
		to_e.y = 0
		var dist: float = to_e.length()
		if dist > ATTACK_RANGE + 0.4:
			continue
		if dist > 0.05:
			var angle: float = acos(clampf(fwd.dot(to_e.normalized()), -1.0, 1.0))
			if angle > ATTACK_ANGLE + 0.2:
				continue
		_apply_hit(gn)
		return

func take_hit(from_dir: Vector3, _knockdown: bool = false) -> void:
	if state_machine.current_name == "dash":
		return
	# from_dir에 y 성분이 있으면 그대로 보존 (shove 띄우기)
	knockback_vel = Vector3(from_dir.x * 5.0, from_dir.y, from_dir.z * 5.0)
	hurt_timer = 0.4
	combo_step = 0
	state_machine.change_state("hurt")
	if game_manager:
		game_manager.player_take_hit()

func request_swap() -> void:
	if game_manager:
		game_manager.request_swap()


# =====================================================================
#  절차적 걷기 애니메이션 — HTML animateWalk() 이식 (좌표 변환 적용)
#  서브클래스가 오버라이드 가능
# =====================================================================
func animate_walk(delta: float) -> void:
	anim_timer += delta * 10.0
	var swing: float = sin(anim_timer)
	var cos_swing: float = cos(anim_timer)
	var walk_bob: float = absf(swing) * 0.04

	# 전투 모드 기본값 (좌표 변환: rx,rz,sx,sz,ex,wx → 부호 반전)
	var base_root_y: float = 0.74
	var root_ry: float = -0.5
	var waist_rx: float = -0.2
	var waist_ry: float = 0.2 + sin(anim_timer) * 0.05
	var chest_ry: float = sin(anim_timer) * 0.08
	var chest_rx: float = -0.1

	var hip_base_x: float = 0.2
	var hip_swing: float = 0.65
	var hip_z: float = 0.35
	var knee_base: float = -0.3
	var knee_mult: float = 0.7

	var a12: float = minf(1.0, 12.0 * delta)
	var a10: float = minf(1.0, 10.0 * delta)
	var a15: float = minf(1.0, 15.0 * delta)

	# Root
	var root: Node3D = parts["root"]
	root.position.y = lerpf(root.position.y, base_root_y + walk_bob, a12)
	root.rotation.x = lerpf(root.rotation.x, 0.0, a12)
	root.rotation.y = lerpf(root.rotation.y, root_ry, a12)

	# Waist / Chest
	var waist: Node3D = parts["waist"]
	waist.rotation.x = lerpf(waist.rotation.x, waist_rx, a10)
	waist.rotation.y = lerpf(waist.rotation.y, waist_ry, a10)
	var chest: Node3D = parts["chest"]
	chest.rotation.x = lerpf(chest.rotation.x, chest_rx, a10)
	chest.rotation.y = lerpf(chest.rotation.y, chest_ry, a10)

	# 다리
	var r_hip: Node3D = parts["right_leg"]["hip"]
	var l_hip: Node3D = parts["left_leg"]["hip"]
	var r_knee: Node3D = parts["right_leg"]["knee"]
	var l_knee: Node3D = parts["left_leg"]["knee"]

	r_hip.rotation.x = lerpf(r_hip.rotation.x, hip_base_x - swing * hip_swing, a15)
	r_hip.rotation.y = lerpf(r_hip.rotation.y, 0.0, a15)
	r_hip.rotation.z = lerpf(r_hip.rotation.z, hip_z, a15)
	r_knee.rotation.x = lerpf(r_knee.rotation.x, -maxf(0.0, -cos_swing) * knee_mult + knee_base, a15)

	l_hip.rotation.x = lerpf(l_hip.rotation.x, hip_base_x + swing * hip_swing, a15)
	l_hip.rotation.y = lerpf(l_hip.rotation.y, 0.0, a15)
	l_hip.rotation.z = lerpf(l_hip.rotation.z, -hip_z, a15)
	l_knee.rotation.x = lerpf(l_knee.rotation.x, -maxf(0.0, cos_swing) * knee_mult + knee_base, a15)

	# 오른팔 — 전투 자세
	var rs: Node3D = parts["right_arm"]["shoulder"]
	rs.rotation.x = lerpf(rs.rotation.x, -0.2 + swing * 0.1, a12)
	rs.rotation.y = lerpf(rs.rotation.y, 0.5, a12)
	rs.rotation.z = lerpf(rs.rotation.z, 0.6, a12)
	var re: Node3D = parts["right_arm"]["elbow"]
	re.rotation.x = lerpf(re.rotation.x, 0.1, a12)
	var rw: Node3D = parts["right_arm"]["wrist"]
	rw.rotation.x = lerpf(rw.rotation.x, -1.4, a12)
	rw.rotation.y = lerpf(rw.rotation.y, -1.0, a12)

	# 왼팔
	var ls: Node3D = parts["left_arm"]["shoulder"]
	ls.rotation.x = lerpf(ls.rotation.x, -0.1 - swing * 0.1, a12)
	ls.rotation.y = lerpf(ls.rotation.y, 0.1, a12)
	ls.rotation.z = lerpf(ls.rotation.z, -0.2, a12)
	var le: Node3D = parts["left_arm"]["elbow"]
	le.rotation.x = lerpf(le.rotation.x, 1.0, a12)


# =====================================================================
#  전투 모드 판정 — 가장 가까운 적 거리 + 공격 중 여부 + 2초 linger
# =====================================================================
func _update_combat_mode(delta: float) -> void:
	var min_d: float = INF
	for g in goblins:
		if not is_instance_valid(g) or g.get("is_dead"):
			continue
		var gn: Node3D = g
		var d: float = global_position.distance_to(gn.global_position)
		if d < min_d:
			min_d = d

	var in_attack: bool = state_machine.current_name == "attack" or state_machine.current_name == "chargeAttack"
	if min_d < AGGRO_RADIUS or in_attack:
		combat_timer = 2.0

	combat_timer = maxf(0.0, combat_timer - delta)
	is_combat_mode = combat_timer > 0.0

	# 전투 모드에서만 무기 표시 (FS→sword, WM→wand, EF→없음)
	if parts.has("sword"):
		var sword: MeshInstance3D = parts["sword"]
		# Player만 sword.scale=1.0으로 올리므로, 스케일이 큰 경우만 토글
		if sword.scale.x > 0.01:
			sword.visible = is_combat_mode
	if parts.has("wand"):
		var wand: Node3D = parts["wand"]
		wand.visible = is_combat_mode


# =====================================================================
#  일반 대기 프로시저럴 오버레이 — HTML animateIdle 이식
# =====================================================================
func animate_idle(delta: float) -> void:
	anim_timer += delta * 1.5
	var breath: float = sin(anim_timer) * 0.04

	var root: Node3D  = parts["root"]
	var waist: Node3D = parts["waist"]
	var chest: Node3D = parts["chest"]
	var rs: Node3D    = parts["right_arm"]["shoulder"]
	var ls: Node3D    = parts["left_arm"]["shoulder"]

	root.rotation.x  += breath * 0.1
	waist.rotation.x += breath * 0.15
	chest.rotation.x += breath * 0.1
	rs.rotation.x    += breath * 0.1
	ls.rotation.x    += breath * 0.1


# =====================================================================
#  전투 대기 프로시저럴 오버레이 — HTML animateBattleIdle 이식
#  PoseSystem이 battle_idle 포즈를 lerp로 적용한 후, 그 위에 breath/sway 오버레이를 덧씌움
# =====================================================================
func animate_battle_idle(delta: float) -> void:
	anim_timer += delta * 1.0
	var t: float = anim_timer

	var breath: float    = sin(t * 0.8) * 0.025
	var sway: float      = sin(t * 0.5) * 0.015
	var sword_wig: float = sin(t * 1.1) * 0.018

	var root: Node3D  = parts["root"]
	var waist: Node3D = parts["waist"]
	var chest: Node3D = parts["chest"]
	var rs: Node3D    = parts["right_arm"]["shoulder"]
	var rw: Node3D    = parts["right_arm"]["wrist"]
	var ls: Node3D    = parts["left_arm"]["shoulder"]
	var r_hip: Node3D = parts["right_leg"]["hip"]
	var l_hip: Node3D = parts["left_leg"]["hip"]

	root.rotation.x  += breath * 0.15
	root.rotation.y  += sway * 0.1
	waist.rotation.x += breath * 0.2
	waist.rotation.y += sway * 0.08
	chest.rotation.x += breath * 0.15
	rs.rotation.x    += breath * 0.1
	rs.rotation.z    += sword_wig * 0.3
	rw.rotation.x    += sword_wig * 0.3
	ls.rotation.x    += breath * 0.1
	l_hip.rotation.y += sway * 0.04
	r_hip.rotation.y += sway * 0.03


# =====================================================================
#  내부 메서드
# =====================================================================
func _apply_hit(goblin: Node3D) -> void:
	has_hit = true
	var kb: Vector3 = goblin.global_position - global_position
	kb.y = 0
	if kb.length() > 0.01:
		kb = kb.normalized()

	var is_last_hit: bool = (combo_step == COMBO_MAX)
	if goblin.has_method("take_hit"):
		goblin.take_hit(kb, is_last_hit)

	if game_manager:
		game_manager.add_score(10 * combo_step)
		game_manager.trigger_hitstop(0.06)
		if is_last_hit:
			game_manager.trigger_slow_mo(0.8)
	mp = mini(mp + 5, max_mp)


func _update_facing(delta: float) -> void:
	if state_machine.current_name == "walk":
		var vel2: Vector2 = Vector2(velocity.x, velocity.z)
		if vel2.length() > 0.5:
			target_facing = atan2(-vel2.x, -vel2.y)
	facing_angle = lerp_angle(facing_angle, target_facing, TURN_SPEED * delta)
	pivot.rotation.y = facing_angle


# =====================================================================
#  머티리얼 초기화 — 서브클래스에서 오버라이드하여 색상 변경
# =====================================================================
func _init_materials() -> void:
	mat_chest = _make_mat(Color(0.29, 0.29, 0.29))
	mat_waist = _make_mat(Color(0.2, 0.2, 0.2))
	mat_pelvis = _make_mat(Color(0.29, 0.29, 0.29))
	mat_skin = _make_mat(Color(1.0, 0.86, 0.67))
	mat_hair = _make_mat(Color(1.0, 0.2, 0.0))
	mat_right = _make_mat(Color(0.91, 0.12, 0.39))
	mat_left = _make_mat(Color(0.13, 0.59, 0.95))


func _make_mat(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	return m


# =====================================================================
#  스켈레톤 구축
# =====================================================================
func _build_skeleton() -> void:
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)

	var root: Node3D = _make_joint("Root")
	root.position.y = LEG_H
	pivot.add_child(root)
	parts["root"] = root

	_add_box(root, Vector3(PELVIS_W, PELVIS_H, PELVIS_D), Vector3(0, PELVIS_H / 2.0, 0), mat_pelvis)

	var waist: Node3D = _make_joint("Waist")
	waist.position.y = PELVIS_H
	root.add_child(waist)
	parts["waist"] = waist
	_add_box(waist, Vector3(WAIST_W, WAIST_H, WAIST_D), Vector3(0, WAIST_H / 2.0, 0), mat_waist)

	var chest: Node3D = _make_joint("Chest")
	chest.position.y = WAIST_H
	waist.add_child(chest)
	parts["chest"] = chest
	_add_box(chest, Vector3(CHEST_W, CHEST_H, CHEST_D), Vector3(0, CHEST_H / 2.0, 0), mat_chest)

	var neck: Node3D = _make_joint("Neck")
	neck.position.y = CHEST_H
	chest.add_child(neck)

	var head_mesh: MeshInstance3D = _add_box(neck, Vector3(HEAD_W, HEAD_H, HEAD_D), Vector3(0, HEAD_H / 2.0 + 0.03, 0), mat_skin)

	var nose: MeshInstance3D = _add_box(head_mesh, Vector3(0.04, 0.04, 0.04), Vector3(0, -0.02, -(HEAD_D / 2.0 + 0.02)), _make_mat(Color(0, 1, 0)))
	nose.visible = false
	parts["nose"] = nose

	_add_box(head_mesh, Vector3(HEAD_W + 0.04, 0.06, HEAD_D + 0.04), Vector3(0, HEAD_H / 2.0 + 0.01, 0), mat_hair)
	_add_box(head_mesh, Vector3(HEAD_W + 0.04, 0.1, 0.05), Vector3(0, HEAD_H / 2.0 - 0.03, -(HEAD_D / 2.0 + 0.02)), mat_hair)
	_add_box(head_mesh, Vector3(HEAD_W + 0.03, 0.38, 0.08), Vector3(0, -0.05, HEAD_D / 2.0 + 0.02), mat_hair)
	_add_box(head_mesh, Vector3(0.03, 0.2, 0.1), Vector3(HEAD_W / 2.0 + 0.02, 0.03, 0.04), mat_hair)
	_add_box(head_mesh, Vector3(0.03, 0.2, 0.1), Vector3(-(HEAD_W / 2.0 + 0.02), 0.03, 0.04), mat_hair)

	parts["right_arm"] = _create_arm(chest, true)
	parts["left_arm"] = _create_arm(chest, false)

	var sword: MeshInstance3D = _add_box(parts["right_arm"]["wrist"], Vector3(0.04, 0.04, 1.2), Vector3(0, -HAND_S / 2.0, -0.6), _make_mat(Color(0.8, 0.8, 0.8)))
	sword.visible = false
	sword.scale = Vector3(0.001, 0.001, 0.001)
	parts["sword"] = sword

	parts["right_leg"] = _create_leg(root, true)
	parts["left_leg"] = _create_leg(root, false)


func _create_arm(parent_node: Node3D, is_right: bool) -> Dictionary:
	var side_x: float = 0.23 if is_right else -0.23
	var mat: StandardMaterial3D = mat_right if is_right else mat_left
	var group_name: String = "RightArm" if is_right else "LeftArm"
	var prefix: String = "R_" if is_right else "L_"

	var arm_group: Node3D = Node3D.new()
	arm_group.name = group_name
	parent_node.add_child(arm_group)

	var shoulder: Node3D = _make_joint(prefix + "Shoulder")
	shoulder.position = Vector3(side_x, CHEST_H * 0.8, 0)
	arm_group.add_child(shoulder)
	_add_box(shoulder, Vector3(ARM_W, UPPER_ARM_L, ARM_W), Vector3(0, -UPPER_ARM_L / 2.0, 0), mat)

	var elbow: Node3D = _make_joint(prefix + "Elbow")
	elbow.position.y = -UPPER_ARM_L
	shoulder.add_child(elbow)
	_add_box(elbow, Vector3(ARM_W * 0.9, FOREARM_L, ARM_W * 0.9), Vector3(0, -FOREARM_L / 2.0, 0), mat)

	var wrist: Node3D = _make_joint(prefix + "Wrist")
	wrist.position.y = -FOREARM_L
	elbow.add_child(wrist)
	_add_box(wrist, Vector3(HAND_S, HAND_S, HAND_S), Vector3(0, -HAND_S / 2.0, 0), mat_skin)

	return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist}


func _create_leg(parent_node: Node3D, is_right: bool) -> Dictionary:
	var side_x: float = 0.11 if is_right else -0.11
	var mat: StandardMaterial3D = mat_right if is_right else mat_left
	var group_name: String = "RightLeg" if is_right else "LeftLeg"
	var prefix: String = "R_" if is_right else "L_"

	var leg_group: Node3D = Node3D.new()
	leg_group.name = group_name
	parent_node.add_child(leg_group)

	var hip: Node3D = _make_joint(prefix + "Hip")
	hip.position = Vector3(side_x, 0, 0)
	leg_group.add_child(hip)
	_add_box(hip, Vector3(THIGH_W, THIGH_L, THIGH_W), Vector3(0, -THIGH_L / 2.0, 0), mat)

	var knee: Node3D = _make_joint(prefix + "Knee")
	knee.position.y = -THIGH_L
	hip.add_child(knee)
	_add_box(knee, Vector3(CALF_W, CALF_L, CALF_W), Vector3(0, -CALF_L / 2.0, 0), mat)

	return {"hip": hip, "knee": knee}


# =====================================================================
#  유틸
# =====================================================================
func _make_joint(joint_name: String) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.name = joint_name
	joint.rotation_order = EULER_ORDER_XYZ
	return joint


func _add_box(parent_node: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	parent_node.add_child(mi)
	return mi


# =====================================================================
#  디버그: 공격 판정 범위 시각화
#  - 노란 부채꼴: 일반 공격 cone (ATTACK_RANGE + 0.4, ATTACK_ANGLE + 0.2)
#  - 주황 원:    차지 어택 AOE 5m (show_blast_radius로 토글)
# =====================================================================
const DEBUG_HITRANGE_VISIBLE := true

var hitrange_wedge: MeshInstance3D = null
var blast_ring:     MeshInstance3D = null

func _setup_debug_hitrange() -> void:
	if not DEBUG_HITRANGE_VISIBLE:
		return
	hitrange_wedge = _make_wedge_mesh(ATTACK_RANGE + 0.4, ATTACK_ANGLE + 0.2, Color(1.0, 0.95, 0.0, 0.18))
	hitrange_wedge.name = "DebugHitRange"
	pivot.add_child(hitrange_wedge)
	hitrange_wedge.position.y = 0.02   # 지면 살짝 위 (z-fighting 회피)

	blast_ring = _make_ring_mesh(0.0, Color(1.0, 0.4, 0.0, 0.22))
	blast_ring.name = "DebugBlastRing"
	pivot.add_child(blast_ring)
	blast_ring.position.y = 0.025
	blast_ring.visible = false


func show_blast_radius(visible_now: bool, radius: float = 5.0) -> void:
	if blast_ring == null:
		return
	if visible_now:
		_resize_ring(blast_ring, radius)
	blast_ring.visible = visible_now


## 부채꼴(쐐기) 메시 — XZ 평면, -Z forward 기준
## half_angle: 절반 각 (라디안)
func _make_wedge_mesh(radius: float, half_angle: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	var verts: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	verts.append(Vector3.ZERO)
	var segments: int = 24
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		# -Z forward 기준: 중심 각 = -PI/2 (즉 -Z 방향), 좌우 ±half_angle
		var ang: float = -PI / 2.0 + (t - 0.5) * 2.0 * half_angle
		var x: float = cos(ang) * radius
		var z: float = sin(ang) * radius
		verts.append(Vector3(x, 0.0, z))
		if i > 0:
			indices.append(0)
			indices.append(i)
			indices.append(i + 1)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mi.mesh = arr_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi


## 원반(disc) 메시 — 폭발 반경 표시용
func _make_ring_mesh(radius: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	mi.mesh = arr_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	if radius > 0.0:
		_resize_ring(mi, radius)
	return mi


func _resize_ring(mi: MeshInstance3D, radius: float) -> void:
	var arr_mesh: ArrayMesh = mi.mesh as ArrayMesh
	if arr_mesh == null:
		return
	arr_mesh.clear_surfaces()
	var verts: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.append(Vector3.ZERO)
	var segments: int = 48
	for i in range(segments + 1):
		var ang: float = TAU * float(i) / float(segments)
		verts.append(Vector3(cos(ang) * radius, 0.0, sin(ang) * radius))
		if i > 0:
			indices.append(0)
			indices.append(i)
			indices.append(i + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
