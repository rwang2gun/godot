class_name Terrain extends Node2D

# Phase 16 v4: const CELL_SIZE 제거 — StageLayoutBuilder.build()이 layout.cell_size로 set_cell_size 호출.
# layout 미사용 stage(Stage 02/03 등)는 default 16 유지 → Builder backward-compat.
# _static_occupancy: StageLayoutBuilder가 생성한 정적 cell. add_tile은 정적/동적 둘 다 점유 시 reject (D8).
var cell_size: int = 16
var _placed: Dictionary = {}              # Vector2i → StaticBody2D (동적 cell)
var _static_occupancy: Dictionary = {}    # Vector2i → true (정적 stage cell)
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
