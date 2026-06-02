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

	# Phase 17 — sticky stuck 시 carrying 유지(has_candy=true 그대로) + 좌우 정지.
	# climber/faller 전이 skip. timer 만료 후 carry 정상 재개.
	if a.is_stuck():
		a.velocity.x = 0.0
		a.velocity.y += a.gravity * delta
		a.move_and_slide()
		return

	a.velocity.y += a.gravity * delta
	a.velocity.x = float(a.direction) * a.effective_speed()

	a.move_and_slide()

	# 무장한 다리 스킬 — 운반 중에도 낭떠러지 도달 시 자동 건설(완료 후 return_to_walking이 carry 복원).
	if a.try_build_armed_bridge():
		return

	if a.is_on_wall():
		# Phase 14 — climber 보유 시 carrying 중에도 벽 등반. has_candy=true 보존.
		if a.has_trait(&"climber"):
			a.state_machine.change_state(ClimberState.new())
			return
		a.flip()

	if not a.is_on_floor():
		a.state_machine.change_state(FallerState.new())
