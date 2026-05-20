class_name ClimberState extends AntState

# substate flag — -1.0 == climbing(수직 등반), >= 0.0 == mantling(꼭대기 horizontal push)
var _mantle_offset: float = -1.0

# mandatory stall guard — dx==0이 연속 발생하면 FallerState로 강제 탈출.
# (plan-stage Round 2 HIGH 대응 — 옵션이 아니라 항상 적용)
const STALL_DX_THRESHOLD: float = 0.1
const MANTLE_STALL_LIMIT: int = 10
var _mantle_stall_frames: int = 0

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	a.velocity = Vector2.ZERO
	_mantle_offset = -1.0
	_mantle_stall_frames = 0

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	if _mantle_offset < 0.0:
		_update_climbing(a, delta)
	else:
		_update_mantling(a, delta)

func _update_climbing(a: Ant, _delta: float) -> void:
	# 벽 쪽으로 약한 push로 벽 접촉 유지 — move_and_slide의 collision response가
	# ant를 벽에서 살짝 떼어내는 것을 방지. 실제 진행은 collision로 막혀서 dx≈0.
	a.velocity.x = float(a.direction) * a.CLIMB_SPEED
	a.velocity.y = -a.CLIMB_SPEED
	a.move_and_slide()

	if a.is_on_ceiling():
		a.state_machine.change_state(FallerState.new())
		return

	# 벽 끝 감지 — 4px 전방 미충돌이면 mantle 진입.
	var wall_probe: Vector2 = Vector2(float(a.direction) * 4.0, 0.0)
	if not a.test_move(a.transform, wall_probe):
		_mantle_offset = 0.0
		_mantle_stall_frames = 0

func _update_mantling(a: Ant, _delta: float) -> void:
	# mantle: 결정적 horizontal push. CLIMB_SPEED 고정(carrying 페널티 무관).
	a.velocity.x = float(a.direction) * a.CLIMB_SPEED
	a.velocity.y = 0.0
	var pre_x: float = a.global_position.x
	a.move_and_slide()
	var dx: float = absf(a.global_position.x - pre_x)
	_mantle_offset += dx

	# MANDATORY stall guard — Round 2 HIGH 대응. dx<0.1이 10 frame 연속이면 FallerState로 fall-through.
	if dx < STALL_DX_THRESHOLD:
		_mantle_stall_frames += 1
		if _mantle_stall_frames >= MANTLE_STALL_LIMIT:
			a.state_machine.change_state(FallerState.new())
			return
	else:
		_mantle_stall_frames = 0

	# mantle 완료 검사
	if _mantle_offset >= a.mantle_distance:
		if a.is_on_floor():
			if a.has_candy:
				a.state_machine.change_state(CarryingState.new())
			else:
				a.state_machine.change_state(WalkerState.new())
		else:
			a.state_machine.change_state(FallerState.new())
