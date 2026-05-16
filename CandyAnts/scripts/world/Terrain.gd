class_name Terrain extends Node2D

const CELL_SIZE: int = 16
# Phase 6 Basher에서 TileMap 동적 파괴 도입 시, 내부를 TileMap으로 교체.
# 외부 인터페이스(add_tile / has_tile)는 유지.

var _placed: Dictionary = {}   # Vector2i → StaticBody2D
var _bridge_tile_texture: Texture2D = null

func add_tile(cell: Vector2i) -> bool:
	if _placed.has(cell):
		return false
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	shape.shape = rect
	body.add_child(shape)
	var sprite: Sprite2D = Sprite2D.new()
	if _bridge_tile_texture == null:
		_bridge_tile_texture = load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D
	sprite.texture = _bridge_tile_texture
	sprite.position = Vector2(0, -13)
	body.add_child(sprite)
	body.global_position = Vector2(
		float(cell.x) * CELL_SIZE + CELL_SIZE / 2.0,
		float(cell.y) * CELL_SIZE + CELL_SIZE / 2.0
	)
	add_child(body)
	_placed[cell] = body
	return true

func has_tile(cell: Vector2i) -> bool:
	return _placed.has(cell)

func tile_count() -> int:
	return _placed.size()
