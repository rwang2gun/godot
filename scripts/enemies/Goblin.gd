class_name Goblin
extends CharacterBody3D

# =====================================================================
#  Goblin — 근접 적 AI (HTML Goblin 포트 + 거리 기반 공격 분기 4종)
#
#  role: "attacker"  → 플레이어에게 접근하여 공격
#        "watcher"   → 일정 거리 오빗 대기
#
#  공격 분기 (attacker가 사거리 도달 시):
#    "shove"   — 초근접(~0.8m): 밀어내기/띄우기
#    "melee"   — 근거리(0.8~2.0m): 2타 콤보
#    "approach" — 중거리(2.0~4.0m): 슬라이딩 접근 공격
#    "rush"    — 원거리(4.0~8.0m): 돌진 공격
# =====================================================================

# --- 스탯 ---
const MOVE_SPEED      := 5.5
const GRAVITY         := -20.0
const MAX_HP          := 3

# --- 거리 임계값 ---
const DIST_SHOVE     := 0.8   # 이 이하 → 밀어내기
const DIST_MELEE     := 2.0   # 이 이하 → 근접 콤보
const DIST_APPROACH  := 4.0   # 이 이하 → 접근기
# DIST_APPROACH 초과 → 돌진기

# --- 공격 타입별 파라미터 ---
# { duration, active_start, active_end, windup, dash_speed, cooldown }
const ATK_SHOVE := {
	"duration": 0.7, "windup": 0.2,
	"active_start": 0.2, "active_end": 0.4,
	"dash_speed": 0.0, "cooldown": 2.0,
	"kb_force": 7.0, "launch_force": 5.0,
}
const ATK_MELEE := {
	"duration": 0.9, "windup": 0.3,
	"active_start": 0.3, "active_end": 0.5,
	"hit2_start": 0.55, "hit2_end": 0.7,
	"dash_speed": 2.0, "cooldown": 1.5,
	"kb_force": 4.0,
}
const ATK_APPROACH := {
	"duration": 0.8, "windup": 0.15,
	"active_start": 0.4, "active_end": 0.65,
	"dash_speed": 8.0, "cooldown": 1.8,
	"kb_force": 4.5,
}
const ATK_RUSH := {
	"duration": 1.0, "windup": 0.35,
	"active_start": 0.5, "active_end": 0.8,
	"dash_speed": 12.0, "cooldown": 2.5,
	"kb_force": 5.0,
}

# --- 공개 상태 (GameManager·Player가 참조) ---
var is_dead  : bool   = false
var role     : String = "watcher"

# --- 내부 상태 ---
var hp            : int    = MAX_HP
var ai_state      : String = "idle"   # "idle" | "chase" | "attack" | "hurt" | "knockdown"
var attack_timer  : float  = 0.0
var attack_cd     : float  = 0.0
var hurt_timer    : float  = 0.0
var knockdown_timer: float = 0.0
var knockback_vel : Vector3 = Vector3.ZERO
var orbit_angle   : float  = 0.0

# --- 공격 분기 ---
var attack_type   : String = ""       # "shove" | "melee" | "approach" | "rush"
var attack_params : Dictionary = {}   # 현재 공격의 파라미터
var attack_dir    : Vector3 = Vector3.FORWARD  # 공격 방향 (시작 시 고정)
var has_hit       : bool   = false    # 1타 히트 여부
var has_hit2      : bool   = false    # 2타 히트 여부 (melee 전용)

# --- AI 웨이포인트 ---
var ai_waypoint     : Vector3 = Vector3.ZERO
var has_waypoint    : bool    = false
var ai_cycle_timer  : float   = 0.0

# --- 외부 참조 (GameManager에서 주입) ---
var game_manager : GameManager   = null
var player_ref   : CharacterBase = null

# --- 내부 노드 ---
@onready var pivot: Node3D = $Pivot
var _eye_mat_normal : StandardMaterial3D
var _eye_mat_warn   : StandardMaterial3D
var _eye_left       : MeshInstance3D
var _eye_right      : MeshInstance3D

# =====================================================================
#  _ready
# =====================================================================
func _ready() -> void:
	pivot.position.y = 0.35
	_build_visuals()
	attack_cd = randf_range(0.5, 2.0)

func _build_visuals() -> void:
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.15, 0.45, 0.15)

	var dark_green := StandardMaterial3D.new()
	dark_green.albedo_color = Color(0.1, 0.3, 0.1)

	_eye_mat_normal = StandardMaterial3D.new()
	_eye_mat_normal.albedo_color = Color(1, 0, 0)

	_eye_mat_warn = StandardMaterial3D.new()
	_eye_mat_warn.albedo_color = Color(1, 1, 0)

	# 몸통
	_add_box(pivot, Vector3(0.45, 0.55, 0.3), Vector3(0, 0.05, 0), green)
	# 머리
	_add_box(pivot, Vector3(0.35, 0.35, 0.3), Vector3(0, 0.55, 0), green)
	# 다리
	for s in [-1, 1]:
		_add_box(pivot, Vector3(0.14, 0.42, 0.14), Vector3(s * 0.12, -0.35, 0), dark_green)
	# 팔
	for s in [-1, 1]:
		_add_box(pivot, Vector3(0.13, 0.42, 0.13), Vector3(s * 0.32, 0.0, 0), dark_green)

	# 눈
	for s in [-1, 1]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055; sm.height = 0.11
		eye.mesh = sm
		eye.position = Vector3(s * 0.10, 0.60, 0.17)
		eye.material_override = _eye_mat_normal
		pivot.add_child(eye)
		if s == -1:
			_eye_left = eye
		else:
			_eye_right = eye

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi  := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)

# =====================================================================
#  Physics Process
# =====================================================================
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_cd = maxf(0.0, attack_cd - delta)

	match ai_state:
		"idle", "chase":
			_ai_update(delta)
		"attack":
			_attack_update(delta)
		"hurt":
			_hurt_update(delta)
		"knockdown":
			_knockdown_update(delta)

	# 중력
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# 넉백: 활성일 때만 velocity 덮어씌움 (비활성 시 AI가 설정한 velocity 유지)
	if knockback_vel.length_squared() > 0.01:
		velocity.x = knockback_vel.x
		velocity.z = knockback_vel.z
		knockback_vel = knockback_vel.lerp(Vector3.ZERO, 5.0 * delta)
	else:
		knockback_vel = Vector3.ZERO

	move_and_slide()

# =====================================================================
#  AI — 웨이포인트 기반 (HTML 패턴 이식)
# =====================================================================
func _ai_update(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return

	var to_p: Vector3 = player_ref.global_position - global_position
	to_p.y = 0
	var dist: float = to_p.length()

	# 항상 플레이어 방향으로 얼굴
	if dist > 0.1:
		var target_angle: float = atan2(-to_p.x, -to_p.z)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_angle, 8.0 * delta)

	# 웨이포인트 주기 갱신
	ai_cycle_timer -= delta
	if ai_cycle_timer <= 0 and ai_state != "attack":
		var cycle_dur: float = 0.8 + randf() * 0.5 if role == "attacker" else 1.2 + randf() * 1.0
		ai_cycle_timer = cycle_dur
		_pick_waypoint(dist)

	if role == "attacker":
		_attacker_ai(delta, to_p, dist)
	else:
		_watcher_ai(delta, to_p, dist)

func _pick_waypoint(dist: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var char_pos: Vector3 = player_ref.global_position

	if role == "attacker":
		if dist > DIST_MELEE:
			var off := Vector3((randf() - 0.5) * 0.6, 0, (randf() - 0.5) * 0.6)
			ai_waypoint = char_pos + off
			has_waypoint = true
		else:
			has_waypoint = false
	else:
		var orbit_r: float = 7.0 + randf() * 1.5 if dist < 3.5 else 5.0 + randf() * 2.0
		var angle_step: float = PI * (0.33 + randf() * 0.5)
		if randf() < 0.5:
			angle_step = -angle_step
		orbit_angle += angle_step
		ai_waypoint = Vector3(
			char_pos.x + sin(orbit_angle) * orbit_r,
			0,
			char_pos.z + cos(orbit_angle) * orbit_r
		)
		has_waypoint = true

func _attacker_ai(delta: float, to_p: Vector3, dist: float) -> void:
	# 공격 사거리 판정 — 거리별 분기
	if attack_cd <= 0:
		if dist <= DIST_SHOVE:
			_start_attack("shove", ATK_SHOVE, to_p)
			return
		elif dist <= DIST_MELEE:
			_start_attack("melee", ATK_MELEE, to_p)
			return
		elif dist <= DIST_APPROACH:
			_start_attack("approach", ATK_APPROACH, to_p)
			return
		# 원거리 돌진: 접근 중 일정 거리 이내일 때
		elif dist <= 8.0 and dist > DIST_APPROACH:
			_start_attack("rush", ATK_RUSH, to_p)
			return

	# 웨이포인트로 이동
	if has_waypoint:
		var wp_dist: float = global_position.distance_to(ai_waypoint)
		if wp_dist > 0.35:
			var dir: Vector3 = (ai_waypoint - global_position).normalized()
			dir.y = 0
			velocity.x = move_toward(velocity.x, dir.x * MOVE_SPEED, 20.0 * delta)
			velocity.z = move_toward(velocity.z, dir.z * MOVE_SPEED, 20.0 * delta)
			ai_state = "chase"
			return

	# 웨이포인트 없으면 직접 접근
	if dist > DIST_MELEE:
		var dir: Vector3 = to_p.normalized()
		velocity.x = move_toward(velocity.x, dir.x * MOVE_SPEED, 20.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * MOVE_SPEED, 20.0 * delta)
		ai_state = "chase"
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

func _watcher_ai(delta: float, _to_p: Vector3, _dist: float) -> void:
	if has_waypoint:
		var wp_dist: float = global_position.distance_to(ai_waypoint)
		if wp_dist > 0.35:
			var dir: Vector3 = (ai_waypoint - global_position).normalized()
			dir.y = 0
			velocity.x = dir.x * 3.0
			velocity.z = dir.z * 3.0
			return
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

# =====================================================================
#  공격 시작 — 타입에 따라 파라미터 세팅
# =====================================================================
func _start_attack(type: String, params: Dictionary, to_player: Vector3) -> void:
	ai_state      = "attack"
	attack_type   = type
	attack_params = params
	attack_timer  = 0.0
	has_hit       = false
	has_hit2      = false
	has_waypoint  = false
	velocity      = Vector3.ZERO

	# 공격 방향 고정
	if to_player.length() > 0.01:
		attack_dir = to_player.normalized()
	else:
		attack_dir = -pivot.global_transform.basis.z
		attack_dir.y = 0
		attack_dir = attack_dir.normalized()

# =====================================================================
#  공격 업데이트 — 타입별 분기
# =====================================================================
func _attack_update(delta: float) -> void:
	attack_timer += delta

	var windup: float    = attack_params.get("windup", 0.3)
	var duration: float  = attack_params.get("duration", 1.0)
	var a_start: float   = attack_params.get("active_start", 0.3)
	var a_end: float     = attack_params.get("active_end", 0.6)
	var dash_spd: float  = attack_params.get("dash_speed", 0.0)

	# 눈 색깔 경고 (와인드업 80% 시점부터)
	var warn: bool = attack_timer >= windup * 0.8
	if _eye_left:
		_eye_left.material_override  = _eye_mat_warn if warn else _eye_mat_normal
	if _eye_right:
		_eye_right.material_override = _eye_mat_warn if warn else _eye_mat_normal

	# ── 와인드업: 정지 ──
	if attack_timer < windup:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		return

	# ── 액티브 페이즈: 대시 + 히트 판정 ──
	if attack_timer < a_end:
		# 대시 이동 (shove는 dash_speed=0 → 제자리)
		if dash_spd > 0.0:
			velocity.x = attack_dir.x * dash_spd
			velocity.z = attack_dir.z * dash_spd

		# 히트 판정
		if attack_timer >= a_start and not has_hit:
			_check_attack_hit()

		# melee 2타 판정
		if attack_type == "melee":
			var h2_start: float = attack_params.get("hit2_start", 0.55)
			var h2_end: float   = attack_params.get("hit2_end", 0.7)
			if attack_timer >= h2_start and attack_timer < h2_end and not has_hit2:
				_check_attack_hit_2()
		return

	# ── 리커버리: 감속 ──
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

	if attack_timer >= duration:
		_end_attack()

func _check_attack_hit() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var dist: float = global_position.distance_to(player_ref.global_position)
	# 타입별 히트 범위
	var hit_range: float = 1.5 if attack_type == "shove" else DIST_MELEE
	if dist < hit_range:
		has_hit = true
		_apply_attack_to_player()

func _check_attack_hit_2() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var dist: float = global_position.distance_to(player_ref.global_position)
	if dist < DIST_MELEE:
		has_hit2 = true
		_apply_attack_to_player()

func _apply_attack_to_player() -> void:
	if not player_ref or not player_ref.has_method("take_hit"):
		return

	var kb: Vector3 = attack_dir

	match attack_type:
		"shove":
			# 밀어내기 + 띄우기: 강한 넉백 + 상향 벡터
			kb = attack_dir * attack_params.get("kb_force", 7.0)
			kb.y = attack_params.get("launch_force", 5.0)
			player_ref.take_hit(kb)
		"melee":
			kb = attack_dir * attack_params.get("kb_force", 4.0)
			player_ref.take_hit(kb)
		"approach":
			kb = attack_dir * attack_params.get("kb_force", 4.5)
			player_ref.take_hit(kb)
		"rush":
			kb = attack_dir * attack_params.get("kb_force", 5.0)
			player_ref.take_hit(kb)

func _end_attack() -> void:
	ai_state    = "idle"
	attack_cd   = attack_params.get("cooldown", 1.5)
	attack_type = ""
	velocity    = Vector3.ZERO
	if _eye_left:  _eye_left.material_override  = _eye_mat_normal
	if _eye_right: _eye_right.material_override = _eye_mat_normal

# =====================================================================
#  Hurt / Knockdown
# =====================================================================
func _hurt_update(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0:
		ai_state = "idle"

func _knockdown_update(delta: float) -> void:
	knockdown_timer -= delta
	pivot.rotation.x = lerpf(pivot.rotation.x, PI * 0.5, 6.0 * delta)
	if knockdown_timer <= 0:
		ai_state = "idle"
		pivot.rotation.x = 0.0

# =====================================================================
#  Public: 플레이어 공격 수신
# =====================================================================
func take_hit(from_dir: Vector3, knockdown: bool = false) -> void:
	if is_dead:
		return

	hp -= 1
	knockback_vel = from_dir * 4.0

	# 공격 중이었다면 중단
	if ai_state == "attack":
		_end_attack()

	if game_manager:
		game_manager.on_goblin_hit_interrupted()

	if hp <= 0:
		_die()
		return

	if knockdown:
		ai_state        = "knockdown"
		knockdown_timer = 1.5
		pivot.rotation.x = PI * 0.5
	else:
		ai_state   = "hurt"
		hurt_timer = 0.3

func _die() -> void:
	is_dead  = true
	velocity = Vector3.ZERO
	pivot.rotation.x = PI * 0.5
	get_tree().create_timer(2.0).timeout.connect(queue_free)
