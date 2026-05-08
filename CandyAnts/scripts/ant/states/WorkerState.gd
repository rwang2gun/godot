class_name WorkerState extends AntState

const TICK_SECONDS: float = 0.2
const TOTAL_TILES: int = 12
const CELL_SIZE: int = 16

var _work_type: String = ""
var _remaining: int = 0
var _tick_accum: float = 0.0
var _aborted: bool = false

func _init(work_type: String = "builder") -> void:
	_work_type = work_type

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	# Builder 외 work_type은 즉시 Walker로 — Phase 4+에서 확장.
	if _work_type != "builder":
		_aborted = true
		return
	_remaining = TOTAL_TILES
	_tick_accum = 0.0
	_aborted = false
	a.velocity = Vector2.ZERO
	# has_candy / has_been_carrying 절대 변경 안 함 (Codex HIGH #4 가드).

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

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

func _place_one_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	# 수평 다리 — ant 발 밑(한 칸 아래) 행에 forward로 12셀.
	# Walker ant가 climb 없이 통과 가능하도록 같은 y level 유지.
	# (참고: ARCHITECTURE §5.3의 "사선 12셀"은 Climber/슬로프 도입 후 Phase 8+에서 정확화 예정.
	# 본 phase는 수평 brige로 minimum scope 유지.)
	var cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / CELL_SIZE)),
		int(floor((a.global_position.y - 2.0) / CELL_SIZE))
	)
	var target: Vector2i = cell + Vector2i(a.direction, 1)
	var ok: bool = terrain.add_tile(target)
	if not ok:
		_aborted = true
		return
	a.global_position += Vector2(a.direction * CELL_SIZE, 0.0)
	_remaining -= 1

func _find_terrain(a: Ant) -> Terrain:
	# Stage scene tree에서 가장 가까운 Terrain 노드 검색.
	# Ant는 World/Spawner의 자식이므로 ancestor 탐색.
	var n: Node = a.get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		# 노드 자체가 Terrain일 수도
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null
