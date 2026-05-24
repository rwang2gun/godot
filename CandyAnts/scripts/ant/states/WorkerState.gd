class_name WorkerState extends AntState

# Phase 16 v4: const CELL_SIZE 삭제 — placement 함수는 terrain.cell_size를 dynamic read.
# Builder 기존 분기도 terrain.cell_size 사용 → Stage 02/03(terrain.cell_size=16 default)
# 회귀 0건. dev_*_layout 사용 stage(cell_size=32)는 새 단위로 placement.

const TICK_SECONDS: float = 0.2
const TOTAL_TILES: int = 12

const SAND_MOUND_TICK: float = 0.25
const SAND_MOUND_MAX_HEIGHT: int = 5

const BRIDGE_TICK: float = 0.20
const BRIDGE_MAX_LENGTH: int = 8

var _work_type: String = ""
var _remaining: int = 0
var _tick_accum: float = 0.0
var _aborted: bool = false
# Phase 16 v7 — bridge floor-contact guard: 첫 tile 전 off-floor는 1-frame grace.
# ant가 다시 floor 위로 안착하면 reset되어 다음 off-floor cycle에 또 grace 1회 사용 가능.
# tile placement는 항상 off-floor frame에서 차단(grace frame은 return으로 skip, abort frame은
# placement loop 진입 전 종료). 진짜 fall은 연속 off-floor 2 frame으로 즉시 abort.
var _bridge_floor_grace_used: bool = false

func _init(work_type: String = "builder") -> void:
	_work_type = work_type

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	# has_candy / has_been_carrying 절대 변경 안 함 (Codex HIGH #4 가드).
	if _work_type == "builder":
		_enter_builder(a)
	elif _work_type == "blocker":
		_enter_blocker(a)
	elif _work_type == "sand_mound":
		_enter_sand_mound(a)
	elif _work_type == "bridge":
		_enter_bridge(a)
	else:
		_aborted = true

func _enter_builder(a: Ant) -> void:
	_remaining = TOTAL_TILES
	_tick_accum = 0.0
	_aborted = false
	a.velocity = Vector2.ZERO

func _enter_blocker(a: Ant) -> void:
	_aborted = false
	a.velocity = Vector2.ZERO
	a.set_blocker_active(true)

func _enter_sand_mound(a: Ant) -> void:
	_remaining = SAND_MOUND_MAX_HEIGHT
	_tick_accum = 0.0
	_aborted = false
	a.velocity = Vector2.ZERO

func _enter_bridge(a: Ant) -> void:
	_remaining = BRIDGE_MAX_LENGTH
	_tick_accum = 0.0
	_aborted = false
	_bridge_floor_grace_used = false
	a.velocity = Vector2.ZERO

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	if _work_type == "blocker":
		_update_blocker(a, delta)
		return
	elif _work_type == "sand_mound":
		_update_sand_mound(a, delta)
		return
	elif _work_type == "bridge":
		_update_bridge(a, delta)
		return

	# builder 분기 (기존 로직 유지, cell_size만 dynamic)
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())
		return

	# 중력 + 바닥 유지 (placement 사이에 ant가 떠있는 시점에도 안정)
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()

	if a.is_on_wall():
		_aborted = true
		a.state_machine.change_state(WalkerState.new())
		return

	_tick_accum += delta
	while _tick_accum >= TICK_SECONDS and _remaining > 0 and not _aborted:
		_tick_accum -= TICK_SECONDS
		_place_one_tile(a)

	if _remaining <= 0 and not _aborted:
		a.state_machine.change_state(WalkerState.new())

func _update_blocker(a: Ant, delta: float) -> void:
	# 영구 정지. 절벽 끝에서만 Faller로 자연 해제.
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	if not a.is_on_floor():
		a.set_blocker_active(false)
		a.state_machine.change_state(FallerState.new())

func _update_sand_mound(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())
		return
	# 정지 — 좌우 무이동. 중력은 적용(tile 사이 떠있을 때 대비).
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	_tick_accum += delta
	while _tick_accum >= SAND_MOUND_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= SAND_MOUND_TICK
		_place_sand_mound_tile(a)
	if _remaining <= 0 and not _aborted:
		a.state_machine.change_state(WalkerState.new())

func _update_bridge(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())
		return
	# 정지 — velocity.x=0 유지, 중력만 적용.
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	# 벽 충돌 시 abort (builder 정책 답습).
	if a.is_on_wall():
		_aborted = true
		a.state_machine.change_state(WalkerState.new())
		return
	# v7 — floor-contact guard.
	# 첫 tile 전 off-floor는 1-frame grace만 허용하되 tile placement는 절대 수행하지 않는다.
	# tile 1개 이상 배치 후 off-floor이거나 grace 이후에도 off-floor이면 즉시 중단한다.
	# Grace는 ant가 다시 floor 위로 안착하면 reset되어 1-frame 물리 진동을 false abort에서 보호한다.
	if not a.is_on_floor():
		var placed_count: int = BRIDGE_MAX_LENGTH - _remaining
		if placed_count == 0 and not _bridge_floor_grace_used:
			_bridge_floor_grace_used = true
			return
		_aborted = true
		a.state_machine.change_state(WalkerState.new())
		return
	_bridge_floor_grace_used = false   # 안착 → grace 재충전
	_tick_accum += delta
	while _tick_accum >= BRIDGE_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= BRIDGE_TICK
		if _far_side_floor_reached(a):
			_aborted = true   # 정상 종료 (반대편 floor 도달)
			break
		_place_bridge_tile(a)
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())

func exit() -> void:
	# blocker 정리 — Faller/Walker/Saved/Dead 어떤 경로든 BlockerHitbox 비활성. 멱등.
	if _work_type == "blocker":
		var a: Ant = ant as Ant
		if a != null:
			a.set_blocker_active(false)
	# sand_mound/bridge는 terminal cleanup 불필요 — Walker 복귀 시 자연 해제.

func _place_one_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	# 수평 다리 — ant 발 밑(한 칸 아래) 행에 forward로 12셀.
	var cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = cell + Vector2i(a.direction, 1)
	var ok: bool = terrain.add_tile(target)
	if not ok:
		_aborted = true
		return
	# Phase 17 — Bridge/Water 정책 (D8). hazard 없는 stage는 no-op.
	terrain.deactivate_hazards_for_placement(target)
	a.global_position += Vector2(a.direction * cs, 0.0)
	_remaining -= 1

func _place_sand_mound_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	# Builder 패턴 답습 — (y - 2.0)/cs로 ant 본체 cell 계산. 그 cell에 직접 tile 추가하면 ant가
	# 새 floor 위로 1 cell 끌어올려진다. Builder는 target = cell + (dir, 1) (floor row),
	# Sand-mound는 target = cell (ant 본체 cell)로 ant를 그 floor 위로 끌어올림.
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = body_cell
	var ok: bool = terrain.add_tile(target)
	if not ok:
		_aborted = true
		return
	# Phase 17 — Bridge/Water 정책 (D8). target=body row이므로 target과 그 위(new ant body row) 모두 비활성.
	terrain.deactivate_hazards_for_placement(target)
	a.global_position.y -= float(cs)
	_remaining -= 1

func _place_bridge_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	# Builder 패턴 답습 — (y-2.0)/cs로 ant 본체 cell, target = body_cell + (dir, +1) (floor row).
	# Bridge는 수평이라 ant.y는 불변 + ant.x += dir*cs로 새 floor 위로 한 칸 이동.
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = body_cell + Vector2i(a.direction, 1)
	var ok: bool = terrain.add_tile(target)
	if not ok:
		_aborted = true
		return
	# Phase 17 — Bridge/Water 정책 (D8). hazard 없는 stage는 no-op.
	terrain.deactivate_hazards_for_placement(target)
	a.global_position += Vector2(float(a.direction) * cs, 0.0)
	_remaining -= 1

func _far_side_floor_reached(a: Ant) -> bool:
	# ant 진행 방향 1 cell forward에서 아래로 ray cast.
	# Layer 1 mask는 Terrain 동적 tile + StageLayoutBuilder 정적 cell 모두 감지.
	# Terrain.has_tile만으로는 정적 cell을 못 보므로 ray 방식 필수.
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
	if space == null:
		return false
	var feet: Vector2 = a.global_position + Vector2(0, 2)
	var forward_target: Vector2 = feet + Vector2(float(a.direction) * (cs + 2), 0)
	var down_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		forward_target,
		forward_target + Vector2(0, cs + 4),
		1   # Layer 1 (floor mask)
	)
	down_query.exclude = [a.get_rid()]
	var hit: Dictionary = space.intersect_ray(down_query)
	return not hit.is_empty()

func _find_terrain(a: Ant) -> Terrain:
	# Stage scene tree에서 가장 가까운 Terrain 노드 검색. ancestor 탐색.
	var n: Node = a.get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null
