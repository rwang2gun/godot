class_name ClimberState extends AntState

# substate flag — -1.0 == climbing(수직 등반), >= 0.0 == mantling(꼭대기 horizontal push)
var _mantle_offset: float = -1.0

# mandatory stall guard — dx==0이 연속 발생하면 FallerState로 강제 탈출.
# (plan-stage Round 2 HIGH 대응 — 옵션이 아니라 항상 적용)
const STALL_DX_THRESHOLD: float = 0.1
const MANTLE_STALL_LIMIT: int = 10
var _mantle_stall_frames: int = 0

# climb 방향을 enter 시점에 lock — 등반/mantle 도중 blocker bounce 등으로 ant.direction이
# 뒤집혀도 climb 방향은 유지. (impl-stage Round 1 HIGH 대응)
var _climb_direction: int = 1

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	a.velocity = Vector2.ZERO
	_mantle_offset = -1.0
	_mantle_stall_frames = 0
	_climb_direction = a.direction if a.direction != 0 else 1

func exit() -> void:
	# 등반 도중 blocker bounce로 ant.direction이 뒤집혔어도 climb 방향으로 복원.
	# 모든 ClimberState 종료 경로(mantle 완료/ceiling/stall guard)에 일관 적용.
	# (impl-stage Round 2 HIGH 대응 — Round 1에선 mantle 완료 경로에만 적용했음)
	var a: Ant = ant as Ant
	if a != null:
		a.direction = _climb_direction

func is_mantling() -> bool:
	return _mantle_offset >= 0.0

# Phase 14 impl-stage Round 3 — codex Round 2 MEDIUM 후속.
# 테스트가 stall guard 동작을 결정론적으로 검증할 수 있도록 내부 상태 노출.
# guard 임계값(MANTLE_STALL_LIMIT, STALL_DX_THRESHOLD)도 외부에서 그대로 참조 가능.
func mantle_stall_frame_count() -> int:
	return _mantle_stall_frames

func mantle_offset() -> float:
	return _mantle_offset

# 시각 전용 — Ant._update_sprite가 호출. 물리/상태 전이에는 영향 없음.
# 등반이 surface 타일 상단의 90% 이상 올라왔거나 mantle(꼭대기 수평 진입) 중이면 true →
# climb 대신 walk/carry 애니 재생(꼭대기에서 climb 포즈가 옆으로 미끄러지는 어색함 제거).
const _NEAR_TOP_FRACTION: float = 0.10   # 남은 높이 10% 이내 == 90% 이상 등반
const _BODY_HALF_H: float = 7.5          # Ant CollisionShape2D(18x15) 절반 높이 = 발 오프셋
func near_surface_top(a: Ant) -> bool:
	if _mantle_offset >= 0.0:
		return true   # mantle 중 = 이미 꼭대기
	var terrain: Terrain = a._find_terrain()
	if terrain == null:
		return false
	var cs: float = float(terrain.cell_size)
	if cs <= 0.0:
		return false
	var feet_y: float = a.global_position.y + _BODY_HALF_H
	var fx: int = int(floor(a.global_position.x / cs)) + _climb_direction
	var feet_row: int = int(floor(feet_y / cs))
	if not terrain.is_cell_occupied(Vector2i(fx, feet_row)):
		return true   # 발이 이미 벽 위(=100% 등반) → walk
	# 전방 벽 칼럼의 최상단 점유 셀까지 위로 스캔 → surface 타일 상단 y.
	var top_row: int = feet_row
	while top_row > feet_row - 64 and terrain.is_cell_occupied(Vector2i(fx, top_row - 1)):
		top_row -= 1
	var surface_top_y: float = float(top_row) * cs
	return feet_y <= surface_top_y + _NEAR_TOP_FRACTION * cs

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	if _mantle_offset < 0.0:
		_update_climbing(a, delta)
	else:
		_update_mantling(a, delta)

func _update_climbing(a: Ant, _delta: float) -> void:
	# 벽 쪽으로 약한 push로 벽 접촉 유지 — _climb_direction (enter 시점 lock) 사용.
	# blocker bounce 등 ant.direction 변동에 무관.
	a.velocity.x = float(_climb_direction) * a.CLIMB_SPEED
	a.velocity.y = -a.CLIMB_SPEED
	a.move_and_slide()

	if a.is_on_ceiling():
		a.state_machine.change_state(FallerState.new())
		return

	# 벽 끝 감지 — 4px 전방 미충돌이면 mantle 진입. _climb_direction 사용.
	var wall_probe: Vector2 = Vector2(float(_climb_direction) * 4.0, 0.0)
	if not a.test_move(a.transform, wall_probe):
		_mantle_offset = 0.0
		_mantle_stall_frames = 0

func _update_mantling(a: Ant, _delta: float) -> void:
	# mantle: 결정적 horizontal push. CLIMB_SPEED 고정(carrying 페널티 무관).
	# _climb_direction 사용 — blocker bounce로 ant.direction이 뒤집혀도 mantle은 진행.
	a.velocity.x = float(_climb_direction) * a.CLIMB_SPEED
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

	# mantle 완료 검사. exit()에서 ant.direction 복원되므로 여기서는 단순 전이만.
	if _mantle_offset >= a.mantle_distance:
		if a.is_on_floor():
			# carry 모션 유지를 위해 has_candy 분기는 Ant.return_to_walking() 단일 진입점에 위임.
			a.return_to_walking()
		else:
			a.state_machine.change_state(FallerState.new())
