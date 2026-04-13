class_name WalkState
extends BaseState

func enter() -> void:
	parent.set_pose("walk1", 12.0)

func update(delta: float) -> void:
	var move_dir: Vector3 = parent.get_move_dir()

	if move_dir.length() > 0.1:
		parent.velocity.x = move_toward(parent.velocity.x, move_dir.x * parent.MAX_SPEED, parent.ACCELERATION * delta)
		parent.velocity.z = move_toward(parent.velocity.z, move_dir.z * parent.MAX_SPEED, parent.ACCELERATION * delta)

		# 이동 중 공격
		if InputManager.attack_triggered and parent.combo_cooldown <= 0:
			parent.start_attack()
			return

		# 차지 어택 해제
		if InputManager.charge_attack_released:
			parent.state_machine.change_state("chargeAttack")
			return

		# 대시
		if InputManager.shift_triggered:
			parent.start_dash()
			return

		# 스킬
		if InputManager.skill_triggered and parent.skill_cooldown <= 0:
			parent.state_machine.change_state("skill")
			return

		# 궁극기
		if InputManager.ultimate_triggered and parent.mp >= parent.max_mp:
			parent.state_machine.change_state("ultimate")
			return

		# 교체
		if InputManager.swap_triggered:
			parent.request_swap()
			return
	else:
		parent.apply_friction(delta)
		parent.state_machine.change_state("idle")
