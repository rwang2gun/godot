class_name FallerState extends AntState

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	# Phase 14 — floater 보유 시 gravity 0.3배 감쇠.
	var gscale: float = a.FLOATER_GRAVITY_SCALE if a.has_trait(&"floater") else 1.0
	a.velocity.y += a.gravity * delta * gscale
	# 수평 속도는 유지 (좌우 흔들림 없음)
	a.velocity.x = float(a.direction) * a.effective_speed() * 0.5

	a.move_and_slide()

	if a.is_on_floor():
		# carry 모션 유지를 위해 has_candy 분기는 Ant.return_to_walking() 단일 진입점에 위임.
		a.return_to_walking()
