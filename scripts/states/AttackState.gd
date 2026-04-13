class_name AttackState
extends BaseState

var _combo3_switched: bool = false  # FS combo3의 a→b 전환 플래그

func enter() -> void:
	parent.attack_timer = 0.0
	parent.has_hit = false
	parent.input_buffered = false
	_combo3_switched = false

	# 가장 가까운 적 방향으로 즉시 회전
	var nearest: Node3D = parent.get_nearest_enemy()
	if nearest:
		var to_t: Vector3 = nearest.global_position - parent.global_position
		to_t.y = 0
		if to_t.length() > 0.1:
			parent.target_facing = atan2(-to_t.x, -to_t.z)

	# 콤보 단계별 타이밍 + 포즈
	match parent.combo_step:
		1:
			parent.attack_duration = 0.50; parent.active_end = 0.25
			parent.set_pose("combo1", 28.0)
		2:
			parent.attack_duration = 0.40; parent.active_end = 0.25
			parent.set_pose("combo2", 28.0)
		3:
			# FS: combo3a→combo3b 2연속, EF/WM: combo3 단일 (pose_map에서 매핑)
			parent.attack_duration = 0.65; parent.active_end = 0.45
			parent.set_pose("combo3a", 28.0)
		4:
			parent.attack_duration = 0.55; parent.active_end = 0.35
			parent.set_pose("combo4", 28.0)
		_:
			parent.attack_duration = 0.50; parent.active_end = 0.25
			parent.set_pose("combo1", 28.0)

func update(delta: float) -> void:
	parent.attack_timer += delta

	# 히트 판정 창
	if not parent.has_hit and parent.attack_timer < parent.active_end:
		parent.check_hit()

	# combo3: 중간 지점에서 combo3b로 전환 + 2번째 히트 판정
	if parent.combo_step == 3 and not _combo3_switched and parent.attack_timer >= 0.30:
		_combo3_switched = true
		parent.has_hit = false  # 2번째 히트 가능
		parent.set_pose("combo3b", 30.0)

	# combo3b 히트 판정 (0.30~0.50 구간)
	if parent.combo_step == 3 and _combo3_switched and not parent.has_hit and parent.attack_timer < 0.50:
		parent.check_hit()

	# 입력 버퍼: 공격 버튼이 눌려있거나 트리거되면 버퍼링
	if parent.attack_timer > 0.05 and not parent.input_buffered and parent.combo_step < parent.COMBO_MAX:
		if InputManager.attack_triggered or Input.is_action_just_pressed("attack"):
			parent.input_buffered = true

	# 공격 중 소량 전진
	var fwd: Vector3 = -parent.pivot.global_transform.basis.z
	parent.velocity.x = lerpf(parent.velocity.x, fwd.x * 2.5, 8.0 * delta)
	parent.velocity.z = lerpf(parent.velocity.z, fwd.z * 2.5, 8.0 * delta)

	# 공격 종료
	if parent.attack_timer >= parent.attack_duration:
		if parent.input_buffered and parent.combo_step < parent.COMBO_MAX:
			parent.combo_step += 1
			parent.state_machine.change_state("attack")   # 재진입으로 다음 콤보
		else:
			parent.combo_step = 0
			parent.combo_cooldown = 0.4
			parent.state_machine.change_state("idle")
