class_name AttackState
extends BaseState

var _combo3_switched: bool = false  # FS combo3의 a→b 전환 플래그
var _phase: String = ""             # dash/leap phase: "" / "dash" / "dashAttack" / "leap" / "leapAttack"

func enter() -> void:
	parent.attack_timer = 0.0
	parent.has_hit = false
	parent.input_buffered = false
	_combo3_switched = false
	_phase = ""

	# 가장 가까운 적 방향으로 즉시 회전 + 특수 공격 접근 거리 갱신
	var nearest: Node3D = parent.get_nearest_enemy()
	if nearest:
		var to_t: Vector3 = nearest.global_position - parent.global_position
		to_t.y = 0
		if to_t.length() > 0.1:
			var ang: float = atan2(-to_t.x, -to_t.z)
			# HTML 원본처럼 즉시 스냅 (lerp 대기 없음 — 첫 프레임부터 타겟 정면)
			parent.target_facing = ang
			parent.facing_angle = ang
			parent.pivot.rotation.y = ang
		# 특수 공격에선 대상 직전까지 접근 (radius 1.2 만큼 앞에서 멈춤)
		parent.attack_dash_dist = maxf(0.5, to_t.length() - 1.2)

	# 특수 첫 공격 분기 (special_mode)
	match parent.special_mode:
		"step_strike":
			parent.attack_duration = 0.40
			parent.active_end      = 0.25
			parent.hold_start      = 0.16
			parent.set_pose("step_strike", 28.0)
			return
		"dash":
			parent.attack_duration = 0.70
			parent.dash_end        = 0.30
			parent.active_end      = 0.55
			parent.set_pose("dash", 22.0)
			_phase = "dash"
			return
		"leap":
			parent.attack_duration = 0.80
			parent.dash_end        = 0.40
			parent.active_end      = 0.65
			parent.set_pose("leap", 22.0)
			_phase = "leap"
			return

	# 콤보 단계별 타이밍 + 포즈
	match parent.combo_step:
		1:
			parent.attack_duration = 0.50; parent.active_end = 0.25
			parent.hold_start = parent.active_end * 0.62
			parent.set_pose("combo1", 28.0)
		2:
			parent.attack_duration = 0.40; parent.active_end = 0.25
			parent.hold_start = parent.active_end * 0.62
			parent.set_pose("combo2", 28.0)
		3:
			# FS: combo3a→combo3b 2연속, EF/WM: combo3 단일 (pose_map에서 매핑)
			parent.attack_duration = 0.65; parent.active_end = 0.45
			parent.hold_start = parent.active_end * 0.62
			parent.set_pose("combo3a", 28.0)
		4:
			parent.attack_duration = 0.55; parent.active_end = 0.35
			parent.hold_start = parent.active_end * 0.62
			parent.set_pose("combo4", 28.0)
		_:
			parent.attack_duration = 0.50; parent.active_end = 0.25
			parent.hold_start = parent.active_end * 0.62
			parent.set_pose("combo1", 28.0)

func update(delta: float) -> void:
	parent.attack_timer += delta
	var t: float = parent.attack_timer
	var fwd: Vector3 = -parent.pivot.global_transform.basis.z

	# ── 특수 공격 (phase 분리) ────────────────────────
	if parent.special_mode == "dash":
		_update_dash_attack(delta, fwd)
	elif parent.special_mode == "leap":
		_update_leap_attack(delta, fwd)
	elif parent.special_mode == "step_strike":
		_update_step_strike(delta, fwd)
	else:
		_update_normal_combo(delta, fwd)

	# 입력 버퍼 (특수 공격은 체인 불가, 일반 콤보만)
	if parent.special_mode == "" and t > 0.05 and not parent.input_buffered and parent.combo_step < parent.COMBO_MAX:
		if InputManager.attack_triggered or Input.is_action_just_pressed("attack"):
			parent.input_buffered = true

	# 공격 종료
	if t >= parent.attack_duration:
		if parent.special_mode == "":
			if parent.input_buffered and parent.combo_step < parent.COMBO_MAX:
				parent.combo_step += 1
				parent.state_machine.change_state("attack")
				return
		parent.combo_step = 0
		parent.combo_cooldown = 0.4
		parent.special_mode = ""
		parent.state_machine.change_state("idle")


# ─────────────────────────────────────────────
#  일반 콤보 (hold phase 감속 포함)
# ─────────────────────────────────────────────
func _update_normal_combo(delta: float, fwd: Vector3) -> void:
	var t: float = parent.attack_timer

	# 히트 판정 창
	if not parent.has_hit and t < parent.active_end:
		parent.check_hit()

	# combo3: 중간 지점에서 combo3b로 전환 + 2번째 히트 판정
	if parent.combo_step == 3 and not _combo3_switched and t >= 0.30:
		_combo3_switched = true
		parent.has_hit = false
		parent.set_pose("combo3b", 30.0)

	if parent.combo_step == 3 and _combo3_switched and not parent.has_hit and t < 0.50:
		parent.check_hit()

	# 전진: hold_start 이전만 forward 가속, 이후 감속
	var dash_speed: float = 3.2
	if parent.combo_step == 3:
		dash_speed = 3.33
	if t < parent.hold_start:
		parent.velocity.x = fwd.x * dash_speed
		parent.velocity.z = fwd.z * dash_speed
	else:
		parent.velocity.x = lerpf(parent.velocity.x, 0.0, minf(1.0, 20.0 * delta))
		parent.velocity.z = lerpf(parent.velocity.z, 0.0, minf(1.0, 20.0 * delta))


# ─────────────────────────────────────────────
#  step_strike (중거리 런지)
# ─────────────────────────────────────────────
func _update_step_strike(delta: float, fwd: Vector3) -> void:
	var t: float = parent.attack_timer
	if not parent.has_hit and t < parent.active_end:
		parent.check_hit()

	var dash_speed: float = parent.attack_dash_dist / maxf(0.01, parent.active_end)
	if t < parent.hold_start:
		parent.velocity.x = fwd.x * dash_speed
		parent.velocity.z = fwd.z * dash_speed
	else:
		parent.velocity.x = lerpf(parent.velocity.x, 0.0, minf(1.0, 20.0 * delta))
		parent.velocity.z = lerpf(parent.velocity.z, 0.0, minf(1.0, 20.0 * delta))


# ─────────────────────────────────────────────
#  dash attack (phase 1: 접근 / phase 2: 타격)
# ─────────────────────────────────────────────
func _update_dash_attack(delta: float, fwd: Vector3) -> void:
	var t: float = parent.attack_timer

	if t < parent.dash_end:
		# phase 1: 접근
		var dist: float = maxf(0.5, parent.attack_dash_dist)
		var dash_speed: float = dist / maxf(0.01, parent.dash_end)
		parent.velocity.x = fwd.x * dash_speed
		parent.velocity.z = fwd.z * dash_speed
	else:
		# phase 2: 타격
		if _phase != "dashAttack":
			_phase = "dashAttack"
			parent.velocity.x = 0.0
			parent.velocity.z = 0.0
			parent.set_pose("dashAttack", 28.0)
		parent.velocity.x = lerpf(parent.velocity.x, 0.0, minf(1.0, 25.0 * delta))
		parent.velocity.z = lerpf(parent.velocity.z, 0.0, minf(1.0, 25.0 * delta))
		if not parent.has_hit and t < parent.active_end:
			parent.check_hit()


# ─────────────────────────────────────────────
#  leap attack (공중 → 착지 타격)
# ─────────────────────────────────────────────
func _update_leap_attack(delta: float, fwd: Vector3) -> void:
	var t: float = parent.attack_timer

	if t < parent.dash_end:
		# phase 1: 전방 이동 + 스켈레톤 아크 (물리 body는 지면 유지)
		var dist: float = maxf(1.0, parent.attack_dash_dist)
		var leap_speed: float = dist / maxf(0.01, parent.dash_end)
		parent.velocity.x = fwd.x * leap_speed
		parent.velocity.z = fwd.z * leap_speed
		# 점프 아크는 skeleton root.position.y에 오버레이 (물리 y 건드리지 않음)
		var p: float = t / parent.dash_end
		var root: Node3D = parent.parts["root"]
		var base_y: float = 0.65   # POSES.leap root.y
		root.position.y = base_y + sin(p * PI) * 2.0
	else:
		# phase 2: 착지 타격
		if _phase != "leapAttack":
			_phase = "leapAttack"
			parent.velocity.x = 0.0
			parent.velocity.z = 0.0
			parent.set_pose("leapAttack", 28.0)
		parent.velocity.x = lerpf(parent.velocity.x, 0.0, minf(1.0, 25.0 * delta))
		parent.velocity.z = lerpf(parent.velocity.z, 0.0, minf(1.0, 25.0 * delta))
		if not parent.has_hit and t < parent.active_end:
			parent.check_hit()
