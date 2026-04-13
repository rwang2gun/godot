class_name IdleState
extends BaseState

func enter() -> void:
	parent.set_pose("idle", 10.0)

func update(delta: float) -> void:
	parent.apply_friction(delta)

	# 이동 입력 → Walk
	if InputManager.move_input != Vector2.ZERO:
		parent.state_machine.change_state("walk")
		return

	# 차지 어택 해제 → ChargeAttack
	if InputManager.charge_attack_released:
		parent.state_machine.change_state("chargeAttack")
		return

	# 공격 → Attack
	if InputManager.attack_triggered and parent.combo_cooldown <= 0:
		parent.start_attack()
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
