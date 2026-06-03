class_name WalkerState extends AntState

# 첫 frame에 is_on_floor()가 false로 잡혀 즉시 Faller 전이되는 깜박임 방지용 grace.
var _frame: int = 0

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	# Phase 17 — sticky stuck 시 좌우 0, 중력만 + slide. flip/climber/faller 전이 모두 skip.
	# _frame 증가도 skip(stuck 중 grace 카운트 동결) — stuck 해방 후 첫 frame이 Walker 진입 직후와 동일하게 동작.
	if a.is_stuck():
		a.velocity.x = 0.0
		a.velocity.y += a.gravity * delta
		a.move_and_slide()
		return

	a.velocity.y += a.gravity * delta
	a.velocity.x = float(a.direction) * a.effective_speed()
	a.move_and_slide()
	_frame += 1

	# 무장한 다리 스킬 — 낭떠러지 도달 시 그 자리(지표면 높이)에서 자동 건설. 전이 시 즉시 return.
	if a.try_build_armed_bridge():
		return
	# 무장한 계단 스킬 — 낭떠러지 도달 시 그 자리에서 대각 계단 자동 건설. 전이 시 즉시 return.
	if a.try_build_armed_builder():
		return

	if a.is_on_wall():
		# Phase 14 — climber 보유 시 벽에서 ClimberState로 전이, 아니면 기존대로 flip.
		if a.has_trait(&"climber"):
			a.state_machine.change_state(ClimberState.new())
			return
		# builder 대각 계단(STAIR) 부드러운 45° 등반 — 계단 셀이 관여하는 벽 충돌만 StairClimbState로 처리.
		# 게이트는 Ant.stair_climb_ahead (단일 SoT, StairClimbState 연속 스텝과 공유).
		# 정적 벽(S1 분지 등)은 게이트 불충족 → 기존 flip 유지(climber 필수 퍼즐 보존).
		if a.stair_climb_ahead():
			a.state_machine.change_state(StairClimbState.new())
			return
		a.flip()

	# 계단 하강 — 계단 표면에서 하강 가장자리 도달 시 수직 낙하 대신 45° 미끄럼(StairDescentState).
	# 게이트는 Ant.stair_descent_ahead (전방 빈칸이라 stair_climb_ahead와 상호 배타). 비계단 가장자리는 미발동.
	if a.stair_descent_ahead():
		a.state_machine.change_state(StairDescentState.new())
		return

	if _frame > 1 and not a.is_on_floor():
		a.state_machine.change_state(FallerState.new())
