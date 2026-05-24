class_name Terrain extends Node2D

# Phase 16 v4: const CELL_SIZE 제거 — StageLayoutBuilder.build()이 layout.cell_size로 set_cell_size 호출.
# layout 미사용 stage(Stage 02/03 등)는 default 16 유지 → Builder backward-compat.
# _static_occupancy: StageLayoutBuilder가 생성한 정적 cell. add_tile은 정적/동적 둘 다 점유 시 reject (D8).
var cell_size: int = 16
var _placed: Dictionary = {}              # Vector2i → StaticBody2D (동적 cell)
var _static_occupancy: Dictionary = {}    # Vector2i → true (정적 stage cell)
# Phase 17 — hazard 노드들 cell 매핑. Bridge × hazard 통합점.
# v3: Array 저장으로 same-cell overlap(Water+Sticky 등) 지원 → deactivate 시 모든 hazard 일괄 set_active(false).
# registration 순서 무관 D8 정책 robust (codex R1-H1 대응).
var _hazards_by_cell: Dictionary = {}     # Vector2i → Array[HazardBase]
var _bridge_tile_texture: Texture2D = null

func set_cell_size(s: int) -> void:
	if s > 0:
		cell_size = s

func register_static_cell(cell: Vector2i) -> void:
	# idempotent — 중복 register OK (StageLayoutBuilder가 rebuild 시 다시 부를 수 있음).
	_static_occupancy[cell] = true

func add_tile(cell: Vector2i) -> bool:
	# D8 first-place wins — 동적/정적 어느 쪽이든 점유면 reject.
	if _placed.has(cell) or _static_occupancy.has(cell):
		return false
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(cell_size, cell_size)
	shape.shape = rect
	body.add_child(shape)
	var sprite: Sprite2D = Sprite2D.new()
	if _bridge_tile_texture == null:
		_bridge_tile_texture = load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D
	sprite.texture = _bridge_tile_texture
	# v5: 16px native sprite → cell_size에 비례 scale. cs=16이면 scale_factor=1.0 (회귀 0건).
	var scale_factor: float = float(cell_size) / 16.0
	sprite.position = Vector2(0, -13.0 * scale_factor)
	sprite.scale = Vector2(scale_factor, scale_factor)
	body.add_child(sprite)
	body.global_position = Vector2(
		float(cell.x) * cell_size + cell_size / 2.0,
		float(cell.y) * cell_size + cell_size / 2.0
	)
	add_child(body)
	_placed[cell] = body
	return true

func has_tile(cell: Vector2i) -> bool:
	return _placed.has(cell)

func tile_count() -> int:
	return _placed.size()

# Phase 17 — hazard 노드가 _ready에서 자체 호출. 같은 cell의 hazard들이 Array로 누적.
func register_hazard_at_cell(cell: Vector2i, hazard: HazardBase) -> void:
	if hazard == null:
		return
	var arr: Array = _hazards_by_cell.get(cell, [])
	if arr.has(hazard):
		return   # idempotent — 같은 instance 중복 register 무효
	arr.append(hazard)
	_hazards_by_cell[cell] = arr

# Phase 17 — cell의 모든 hazard에 set_active(false) 일괄. registration 순서 무관 (codex R1-H1).
func deactivate_hazards_at(cell: Vector2i) -> void:
	var arr: Array = _hazards_by_cell.get(cell, [])
	for h in arr:
		var hazard: HazardBase = h as HazardBase
		if hazard != null and is_instance_valid(hazard):
			hazard.set_active(false)

# Phase 17 — Bridge/Sand-mound/Builder의 add_tile 직후 호출 (WorkerState._place_*_tile).
# target은 floor row(Bridge/Builder) 또는 body row(Sand-mound). hazard는 항상 body row 컨벤션.
# 따라서 target + target-1 두 cell 모두 비활성 → floor-row placement도 body-row hazard 매칭.
func deactivate_hazards_for_placement(target: Vector2i) -> void:
	deactivate_hazards_at(target)
	deactivate_hazards_at(target + Vector2i(0, -1))
