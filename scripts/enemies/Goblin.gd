class_name Goblin
extends CharacterBody3D

# =====================================================================
#  Goblin — 기본 근접 적 AI (HTML 원본 Goblin 클래스 포트)
#  role: "attacker"  → 플레이어에게 달려들어 공격
#        "watcher"   → 일정 거리 오빗 대기
# =====================================================================

# --- 스탯 ---
const MOVE_SPEED      := 5.5
const ATTACK_RANGE    := 1.8
const ATTACK_COOLDOWN := 1.5
const GRAVITY         := -20.0
const MAX_HP          := 3

# --- 공개 상태 (GameManager·Player가 참조) ---
var is_dead  : bool   = false
var role     : String = "watcher"   # "attacker" | "watcher"

# --- 내부 상태 ---
var hp           : int   = MAX_HP
var ai_state     : String = "idle"   # "idle" | "chase" | "attack" | "hurt" | "knockdown"
var attack_timer : float = 0.0
var attack_cd    : float = 0.0
var hurt_timer   : float = 0.0
var knockdown_timer: float = 0.0
var knockback_vel: Vector3 = Vector3.ZERO
var orbit_angle  : float  = 0.0      # watcher 오빗용

# --- 외부 참조 (GameManager에서 주입) ---
var game_manager: Node    = null
var player_ref  : Node3D  = null

# --- 내부 노드 ---
@onready var pivot: Node3D = $Pivot
var _eye_mat_normal: StandardMaterial3D
var _eye_mat_warn  : StandardMaterial3D
var _eye_left      : MeshInstance3D
var _eye_right     : MeshInstance3D

# =====================================================================
#  _ready
# =====================================================================
func _ready() -> void:
	# Pivot을 올려서 다리 하단이 CharacterBody3D 원점에 맞게
	pivot.position.y = 0.35
	_build_visuals()
	attack_cd = randf_range(0.5, 2.0)   # 초기 어긋남

func _build_visuals() -> void:
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.15, 0.45, 0.15)

	var dark_green := StandardMaterial3D.new()
	dark_green.albedo_color = Color(0.1, 0.3, 0.1)

	_eye_mat_normal = StandardMaterial3D.new()
	_eye_mat_normal.albedo_color = Color(1, 0, 0)

	_eye_mat_warn = StandardMaterial3D.new()
	_eye_mat_warn.albedo_color = Color(1, 1, 0)   # 공격 예고: 노란색

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

	# 눈 (공격 예고 시 노란색으로 변함)
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

	# 넉백 감쇠
	velocity.x = knockback_vel.x
	velocity.z = knockback_vel.z
	knockback_vel = knockback_vel.lerp(Vector3.ZERO, 5.0 * delta)

	move_and_slide()

# =====================================================================
#  AI
# =====================================================================
func _ai_update(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return

	var to_p: Vector3 = player_ref.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()

	# 항상 플레이어 방향으로 얼굴
	if dist > 0.1:
		var target_angle := atan2(-to_p.x, -to_p.z)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_angle, 8.0 * delta)

	if role == "attacker":
		_attacker_ai(delta, to_p, dist)
	else:
		_watcher_ai(delta, to_p, dist)

func _attacker_ai(delta: float, to_p: Vector3, dist: float) -> void:
	if dist > ATTACK_RANGE:
		# 추격
		var dir := to_p.normalized()
		velocity.x = move_toward(velocity.x, dir.x * MOVE_SPEED, 20.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * MOVE_SPEED, 20.0 * delta)
		ai_state = "chase"
	elif attack_cd <= 0:
		_start_attack()
	else:
		# 공격 쿨다운 대기: 제자리
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

func _watcher_ai(delta: float, to_p: Vector3, dist: float) -> void:
	const ORBIT_RADIUS := 6.5
	const ORBIT_SPEED  := 0.6   # 라디안/초

	if dist < ORBIT_RADIUS - 1.2:
		# 너무 가까우면 멀어짐
		var away := -to_p.normalized()
		velocity.x = away.x * 3.0
		velocity.z = away.z * 3.0
	elif dist > ORBIT_RADIUS + 1.2:
		# 너무 멀면 가까이
		var toward := to_p.normalized()
		velocity.x = toward.x * 3.0
		velocity.z = toward.z * 3.0
	else:
		# 오빗
		orbit_angle += ORBIT_SPEED * delta
		var orbit_dir := Vector3(sin(orbit_angle), 0, cos(orbit_angle))
		velocity.x = orbit_dir.x * 2.0
		velocity.z = orbit_dir.z * 2.0

# =====================================================================
#  Attack (1.0s 시퀀스)
#  0.00~0.50s : 와인드업 (눈 노란색 경고)
#  0.50~0.80s : 돌진 + 히트 판정
#  0.80~1.00s : 회복
# =====================================================================
func _start_attack() -> void:
	ai_state     = "attack"
	attack_timer = 0.0
	velocity     = Vector3.ZERO

func _attack_update(delta: float) -> void:
	attack_timer += delta

	# 눈 색깔로 공격 예고
	var warn := attack_timer >= 0.35
	if _eye_left:
		_eye_left.material_override  = _eye_mat_warn if warn else _eye_mat_normal
	if _eye_right:
		_eye_right.material_override = _eye_mat_warn if warn else _eye_mat_normal

	if attack_timer < 0.50:
		# 와인드업: 정지
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

	elif attack_timer < 0.80:
		# 돌진
		if player_ref and is_instance_valid(player_ref):
			var to_p := player_ref.global_position - global_position
			to_p.y = 0
			var dir := to_p.normalized() if to_p.length() > 0.01 else Vector3.FORWARD
			velocity.x = dir.x * 9.0
			velocity.z = dir.z * 9.0

			# 히트 체크
			if global_position.distance_to(player_ref.global_position) < ATTACK_RANGE:
				var kb := dir
				if player_ref.has_method("take_hit"):
					player_ref.take_hit(kb)
				_end_attack()
				return

	else:
		# 회복
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if attack_timer >= 1.0:
			_end_attack()

func _end_attack() -> void:
	ai_state  = "idle"
	attack_cd = ATTACK_COOLDOWN
	velocity  = Vector3.ZERO
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
	# 쓰러지는 연출: pivot X축 회전
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

	# GameManager에 교체 요청
	if game_manager and game_manager.has_method("on_goblin_hit_interrupted"):
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
	# 사망 연출: 쓰러짐
	pivot.rotation.x = PI * 0.5
	# 2초 후 제거
	get_tree().create_timer(2.0).timeout.connect(queue_free)
