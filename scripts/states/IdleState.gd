class_name IdleState
extends BaseState

func enter() -> void:
	# 진입 시 현재 전투 모드에 맞는 포즈로 시작
	if parent.is_combat_mode:
		parent.set_pose("battle_idle", 8.0)
	else:
		parent.set_pose("idle", 8.0)

func update(delta: float) -> void:
	parent.apply_friction(delta)

	# 전투 모드에 따라 포즈와 오버레이 분기 (매 프레임 전환 감지)
	if parent.is_combat_mode:
		parent.set_pose("battle_idle", 8.0)
		parent.animate_battle_idle(delta)
	else:
		parent.set_pose("idle", 8.0)
		parent.animate_idle(delta)

	# 이동 입력 → Walk
	if InputManager.move_input != Vector2.ZERO:
		parent.state_machine.change_state("walk")
		return

	# 홀드 중 차지 진입 (릴리스 전에 ChargeAttack으로 windup 시작)
	if InputManager.is_charging and parent.combo_cooldown <= 0:
		parent.state_machine.change_state("chargeAttack")
		return

	# 공격 → Attack (릴리스 시점에 짧은 탭으로 판정된 경우)
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
