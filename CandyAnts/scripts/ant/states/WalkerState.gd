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

	if a.is_on_wall():
		# Phase 14 — climber 보유 시 벽에서 ClimberState로 전이, 아니면 기존대로 flip.
		if a.has_trait(&"climber"):
			a.state_machine.change_state(ClimberState.new())
			return
		a.flip()

	if _frame > 1 and not a.is_on_floor():
		a.state_machine.change_state(FallerState.new())
