extends CharacterBody3D

# =====================================================================
#  FreeFlow Player — GDScript 4 port of CharacterFS/CharacterEF
#  State machine: IDLE → WALK → ATTACK → DASH → HURT
# =====================================================================

# --- 기본 스탯 (HTML 원본 값 유지) ---
const MAX_SPEED    := 6.0
const ACCELERATION := 14.0
const DAMPING      := 18.0
const TURN_SPEED   := 15.0
const GRAVITY      := -20.0

const ATTACK_RANGE := 2.0
const ATTACK_ANGLE := PI / 3.0   # 60도
const COMBO_MAX    := 3

const DASH_SPEED    := 14.0
const DASH_DURATION := 0.25

# --- 상태 열거형 ---
enum State { IDLE, WALK, ATTACK, DASH, HURT }
var state: State = State.IDLE

# --- 전투 변수 ---
var combo_step     : int   = 0
var attack_timer   : float = 0.0
var attack_duration: float = 0.5
var active_end     : float = 0.25   # 히트 판정 끝 시점
var has_hit        : bool  = false
var input_buffered : bool  = false
var combo_cooldown : float = 0.0

# --- 대시 ---
var dash_timer : float   = 0.0
var dash_dir   : Vector3 = Vector3.ZERO

# --- 피격 ---
var hurt_timer       : float   = 0.0
var knockback_vel    : Vector3 = Vector3.ZERO

# --- 방향 ---
var facing_angle : float = 0.0
var target_facing: float = 0.0

# --- 외부 참조 (GameManager에서 주입) ---
var game_manager: Node        = null
var goblins     : Array       = []
var camera_rig = null

# --- 내부 노드 ---
@onready var pivot: Node3D = $Pivot

# =====================================================================
#  _ready : 시각적 메시 생성
# =====================================================================
func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	# 파란색 플레이어 (Three.js 원본과 동일한 박스 스타일)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.3, 0.5, 0.8)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.3, 0.6)

	# 몸통
	_add_box(pivot, Vector3(0.5, 0.6, 0.3), Vector3(0, 0.1, 0), blue)
	# 머리
	_add_box(pivot, Vector3(0.35, 0.35, 0.3), Vector3(0, 0.65, 0), blue)
	# 팔 (좌우)
	for s in [-1, 1]:
		_add_box(pivot, Vector3(0.15, 0.5, 0.15), Vector3(s * 0.35, 0.05, 0), dark)
	# 다리 (좌우)
	for s in [-1, 1]:
		_add_box(pivot, Vector3(0.18, 0.5, 0.18), Vector3(s * 0.15, -0.38, 0), dark)

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
	if game_manager and game_manager.is_game_over:
		return

	combo_cooldown = maxf(0.0, combo_cooldown - delta)

	match state:
		State.IDLE:   _idle_update(delta)
		State.WALK:   _walk_update(delta)
		State.ATTACK: _attack_update(delta)
		State.DASH:   _dash_update(delta)
		State.HURT:   _hurt_update(delta)

	# 중력
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_update_facing(delta)

# =====================================================================
#  State Handlers
# =====================================================================
func _idle_update(delta: float) -> void:
	_apply_friction(delta)
	var move_dir := _get_move_dir()
	if move_dir.length() > 0.1:
		_change_state(State.WALK)
	elif Input.is_action_just_pressed("attack") and combo_cooldown <= 0:
		_start_attack()
	elif Input.is_action_just_pressed("dodge"):
		_start_dash()

func _walk_update(delta: float) -> void:
	var move_dir := _get_move_dir()
	if move_dir.length() > 0.1:
		velocity.x = move_toward(velocity.x, move_dir.x * MAX_SPEED, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * MAX_SPEED, ACCELERATION * delta)
		# 이동 중 공격 입력
		if Input.is_action_just_pressed("attack") and combo_cooldown <= 0:
			_start_attack()
			return
		elif Input.is_action_just_pressed("dodge"):
			_start_dash()
			return
	else:
		_apply_friction(delta)
		_change_state(State.IDLE)

func _attack_update(delta: float) -> void:
	attack_timer += delta

	# 히트 판정 창 안이면 체크
	if not has_hit and attack_timer < active_end:
		_check_hit()

	# 입력 버퍼 (0.05s 이후부터 수집)
	if attack_timer > 0.05 and not input_buffered and combo_step < COMBO_MAX:
		if Input.is_action_just_pressed("attack"):
			input_buffered = true

	# 공격 중 소량 전진
	var fwd := -pivot.global_transform.basis.z
	velocity.x = lerpf(velocity.x, fwd.x * 2.5, 8.0 * delta)
	velocity.z = lerpf(velocity.z, fwd.z * 2.5, 8.0 * delta)

	# 공격 종료
	if attack_timer >= attack_duration:
		if input_buffered and combo_step < COMBO_MAX:
			combo_step += 1
			_begin_attack_step()
		else:
			combo_step = 0
			combo_cooldown = 0.4
			_change_state(State.IDLE)

func _dash_update(delta: float) -> void:
	dash_timer += delta
	velocity.x = dash_dir.x * DASH_SPEED
	velocity.z = dash_dir.z * DASH_SPEED
	if dash_timer >= DASH_DURATION:
		_change_state(State.IDLE)

func _hurt_update(delta: float) -> void:
	hurt_timer -= delta
	velocity.x = knockback_vel.x
	velocity.z = knockback_vel.z
	knockback_vel = knockback_vel.lerp(Vector3.ZERO, 6.0 * delta)
	if hurt_timer <= 0:
		_change_state(State.IDLE)

# =====================================================================
#  Combat
# =====================================================================
func _start_attack() -> void:
	combo_step = 1
	_begin_attack_step()

func _begin_attack_step() -> void:
	_change_state(State.ATTACK)
	attack_timer   = 0.0
	has_hit        = false
	input_buffered = false

	# 가장 가까운 고블린 방향으로 즉시 회전
	var nearest := _get_nearest_goblin()
	if nearest:
		var to_t := (nearest.global_position - global_position)
		to_t.y = 0
		if to_t.length() > 0.1:
			target_facing = atan2(to_t.x, to_t.z)

	# 콤보 단계별 타이밍 (HTML 원본 값)
	match combo_step:
		1:
			attack_duration = 0.50; active_end = 0.25
		2:
			attack_duration = 0.40; active_end = 0.25
		3:
			attack_duration = 0.65; active_end = 0.45
		_:
			attack_duration = 0.50; active_end = 0.25

func _check_hit() -> void:
	var fwd := -pivot.global_transform.basis.z
	fwd.y = 0
	if fwd.length() > 0.01:
		fwd = fwd.normalized()

	for g in goblins:
		if not is_instance_valid(g):
			continue
		if g.get("is_dead"):
			continue

		var to_e: Vector3 = g.global_position - global_position
		to_e.y = 0
		var dist := to_e.length()

		if dist > ATTACK_RANGE + 0.4:
			continue

		# 전방 원뿔 체크 (거리가 거의 0이면 무조건 히트)
		if dist > 0.05:
			var angle := acos(clampf(fwd.dot(to_e.normalized()), -1.0, 1.0))
			if angle > ATTACK_ANGLE + 0.2:
				continue

		_apply_hit(g)
		return   # 한 번에 한 마리만 히트

func _apply_hit(goblin: Node3D) -> void:
	has_hit = true
	var kb := (goblin.global_position - global_position)
	kb.y = 0
	if kb.length() > 0.01:
		kb = kb.normalized()

	var is_last_hit := (combo_step == COMBO_MAX)
	if goblin.has_method("take_hit"):
		goblin.take_hit(kb, is_last_hit)

	if game_manager:
		game_manager.add_score(10 * combo_step)
		game_manager.trigger_hitstop(0.06)
		if is_last_hit:
			game_manager.trigger_slow_mo(0.8)

## 고블린 공격에 피격됨 (고블린 스크립트에서 호출)
func take_hit(from_dir: Vector3, _knockdown: bool = false) -> void:
	# 대시 중 무적
	if state == State.DASH:
		return

	knockback_vel = from_dir * 5.0
	hurt_timer = 0.4
	combo_step = 0
	_change_state(State.HURT)

	if game_manager:
		game_manager.player_take_hit()

# =====================================================================
#  Dash
# =====================================================================
func _start_dash() -> void:
	var dir := _get_move_dir()
	if dir.length() < 0.1:
		dir = -pivot.global_transform.basis.z
		dir.y = 0
		dir = dir.normalized()
	dash_dir   = dir
	dash_timer = 0.0
	_change_state(State.DASH)

# =====================================================================
#  Helpers
# =====================================================================
func _change_state(new_state: State) -> void:
	state = new_state

func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DAMPING * delta)
	velocity.z = move_toward(velocity.z, 0.0, DAMPING * delta)

## WASD 입력 → 카메라 기준 방향 벡터
func _get_move_dir() -> Vector3:
	var raw := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): raw.y -= 1
	if Input.is_physical_key_pressed(KEY_S): raw.y += 1
	if Input.is_physical_key_pressed(KEY_A): raw.x -= 1
	if Input.is_physical_key_pressed(KEY_D): raw.x += 1
	if raw == Vector2.ZERO:
		return Vector3.ZERO

	raw = raw.normalized()

	# 카메라 수평각 기반 변환
	var theta: float = camera_rig.theta if camera_rig else 0.0
	# forward = (-sin θ, 0, -cos θ), right = (cos θ, 0, -sin θ)
	var fwd := Vector3(-sin(theta), 0.0, -cos(theta))
	var rgt := Vector3( cos(theta), 0.0, -sin(theta))
	return (rgt * raw.x + fwd * -raw.y).normalized()

func _get_nearest_goblin() -> Node3D:
	var nearest: Node3D = null
	var min_d := INF
	for g in goblins:
		if not is_instance_valid(g) or g.get("is_dead"):
			continue
		var d := global_position.distance_to(g.global_position)
		if d < min_d:
			min_d = d
			nearest = g
	return nearest

## 이동/공격 방향으로 캐릭터 Pivot 회전
func _update_facing(delta: float) -> void:
	if state == State.WALK:
		var vel2 := Vector2(velocity.x, velocity.z)
		if vel2.length() > 0.5:
			target_facing = atan2(vel2.x, vel2.y)

	facing_angle = lerp_angle(facing_angle, target_facing, TURN_SPEED * delta)
	pivot.rotation.y = facing_angle
