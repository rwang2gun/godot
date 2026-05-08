class_name FallerState extends AntState

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	a.velocity.y += a.gravity * delta
	# 수평 속도는 유지 (좌우 흔들림 없음)
	a.velocity.x = float(a.direction) * a.effective_speed() * 0.5

	a.move_and_slide()

	if a.is_on_floor():
		a.state_machine.change_state(WalkerState.new())
