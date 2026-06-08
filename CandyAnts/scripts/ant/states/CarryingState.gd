class_name CarryingState extends AntState

func enter() -> void:
	var a: Ant = ant as Ant
	if a != null:
		a.has_been_carrying = true
		a.has_candy = true

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	# 끈끈이는 감속 존 — carrying 유지(has_candy 보존) + 정지 분기 없이 effective_speed로 느리게 운반 보행.
	a.velocity.y += a.gravity * delta
	a.velocity.x = float(a.direction) * a.effective_speed()

	a.move_and_slide()
	a.footstep_tick()   # 보폭 기반 풋스텝 SFX (운반 보행도 동일).

	# 무장한 다리 스킬 — 운반 중에도 낭떠러지 도달 시 자동 건설(완료 후 return_to_walking이 carry 복원).
	if a.try_build_armed_bridge():
		return
	# 무장한 계단 스킬 — 운반 중에도 낭떠러지 도달 시 대각 계단 자동 건설(완료 후 carry 복원).
	if a.try_build_armed_builder():
		return

	if a.is_on_wall():
		# Phase 14 — climber 보유 시 carrying 중에도 벽 등반. has_candy=true 보존.
		if a.has_trait(&"climber"):
			a.state_machine.change_state(ClimberState.new())
			return
		# 운반 중에도 계단 STAIR 벽은 부드러운 45° 등반(StairClimbState). has_candy 보존 —
		# StairClimbState는 has_candy 불변 + 종료 시 return_to_walking이 CarryingState로 복원(codex 2026-06-03 MEDIUM).
		if a.stair_climb_ahead():
			a.state_machine.change_state(StairClimbState.new())
			return
		a.flip()

	# 계단 하강 — 운반 중에도 계단 표면 가장자리에서 45° 미끄럼(StairDescentState). has_candy 보존 +
	# 종료 시 return_to_walking이 CarryingState로 복원. 비계단 가장자리는 미발동(정상 낙하 유지).
	if a.stair_descent_ahead():
		a.state_machine.change_state(StairDescentState.new())
		return

	if not a.is_on_floor():
		a.state_machine.change_state(FallerState.new())
