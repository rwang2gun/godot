class_name CarryingState extends AntState

func enter() -> void:
	var a: Ant = ant as Ant
	if a != null:
		a.has_been_carrying = true

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	a.velocity.y += a.gravity * delta
	a.velocity.x = float(a.direction) * a.effective_speed()

	a.move_and_slide()

	if a.is_on_wall():
		a.flip()

	if not a.is_on_floor():
		a.state_machine.change_state(FallerState.new())
