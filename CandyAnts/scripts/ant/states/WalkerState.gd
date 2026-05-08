class_name WalkerState extends AntState

# 첫 frame에 is_on_floor()가 false로 잡혀 즉시 Faller 전이되는 깜박임 방지용 grace.
var _frame: int = 0

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	a.velocity.y += a.gravity * delta
	a.velocity.x = float(a.direction) * a.effective_speed()
	a.move_and_slide()
	_frame += 1

	if a.is_on_wall():
		a.flip()

	if _frame > 1 and not a.is_on_floor():
		a.state_machine.change_state(FallerState.new())
