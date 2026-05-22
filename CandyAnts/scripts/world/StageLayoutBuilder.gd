@tool
class_name StageLayoutBuilder extends Node2D

@export var layout: Resource = null:
	set(value):
		layout = value
		if Engine.is_editor_hint():
			_rebuild_preview()

@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		if Engine.is_editor_hint():
			_rebuild_preview()

const TILE_SOLID := "solid"
const TILE_SLOPE_RIGHT := "slope_right"
const TILE_SLOPE_LEFT := "slope_left"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_preview()
	else:
		build()

func build() -> void:
	_clear_children()
	if layout == null:
		return
	for key in _layout_tile_map().keys():
		_add_cell(_cell_from_key(str(key)), str(_layout_tile_map()[key]))

func _rebuild_preview() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	if not preview_in_editor or layout == null:
		return
	for key in _layout_tile_map().keys():
		_add_cell(_cell_from_key(str(key)), str(_layout_tile_map()[key]))

func _add_cell(cell: Vector2i, tile_type: String = TILE_SOLID) -> void:
	var cell_size: int = int(layout.cell_size)
	var body := StaticBody2D.new()
	body.name = "Cell_%d_%d" % [cell.x, cell.y]
	body.position = _cell_to_world(cell, cell_size)
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.owner = owner

	if tile_type == TILE_SLOPE_RIGHT or tile_type == TILE_SLOPE_LEFT:
		_add_slope_collision(body, cell_size, tile_type)
		_add_slope_visual(body, cell_size, tile_type)
	else:
		_add_solid_collision(body, cell_size)
		_add_solid_visual(body, cell_size, cell)

func _add_solid_collision(body: StaticBody2D, cell_size: int) -> void:
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(cell_size, cell_size)
	shape.shape = rect
	body.add_child(shape)
	shape.owner = owner

func _add_slope_collision(body: StaticBody2D, cell_size: int, tile_type: String) -> void:
	var polygon := CollisionPolygon2D.new()
	polygon.name = "CollisionPolygon2D"
	polygon.polygon = _slope_points(cell_size, tile_type)
	body.add_child(polygon)
	polygon.owner = owner

func _add_solid_visual(body: StaticBody2D, cell_size: int, cell: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _get_tile_texture_for_cell(cell)
	if sprite.texture != null:
		var texture_size := sprite.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			sprite.scale = Vector2(float(cell_size) / texture_size.x, float(cell_size) / texture_size.y)
	else:
		sprite.modulate = Color(0.45, 0.28, 0.15)
	body.add_child(sprite)
	sprite.owner = owner

func _add_slope_visual(body: StaticBody2D, cell_size: int, tile_type: String) -> void:
	var polygon := Polygon2D.new()
	polygon.name = "SlopeVisual"
	polygon.polygon = _slope_points(cell_size, tile_type)
	
	var theme_name: String = "cookie_crust"
	if layout != null and "theme" in layout:
		theme_name = layout.theme
		
	var surface_tex: Texture2D = null
	if theme_name == "cookie_crust":
		surface_tex = load("res://assets/sprites/terrain/cookie_tile_surface.png") as Texture2D
	elif theme_name == "cookie_segment":
		surface_tex = load("res://assets/sprites/terrain/cookie_platform_segment.png") as Texture2D
	elif theme_name == "thin_floor":
		surface_tex = load("res://assets/sprites/terrain/thin_cookie_floor_segment.png") as Texture2D
	elif theme_name == "cookie_bridge_tile":
		surface_tex = load("res://assets/sprites/terrain/cookie_bridge_tile.png") as Texture2D
	elif theme_name == "thin_bridge":
		surface_tex = load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D

	if surface_tex != null:
		polygon.texture = surface_tex
		# UV coordinates mapping (since polygon points range from -half to half)
		polygon.uv = PackedVector2Array([
			Vector2(0, 0),
			Vector2(0, cell_size),
			Vector2(cell_size, cell_size)
		]) if tile_type == TILE_SLOPE_LEFT else PackedVector2Array([
			Vector2(0, cell_size),
			Vector2(cell_size, cell_size),
			Vector2(cell_size, 0)
		])
	else:
		polygon.color = Color(0.92, 0.60, 0.28, 1.0)
		
	body.add_child(polygon)
	polygon.owner = owner

func _slope_points(cell_size: int, tile_type: String) -> PackedVector2Array:
	var half := float(cell_size) * 0.5
	if tile_type == TILE_SLOPE_LEFT:
		return PackedVector2Array([
			Vector2(-half, -half),
			Vector2(-half, half),
			Vector2(half, half),
		])
	return PackedVector2Array([
		Vector2(-half, half),
		Vector2(half, half),
		Vector2(half, -half),
	])

func _get_tile_texture_for_cell(cell: Vector2i) -> Texture2D:
	var theme_name: String = "cookie_crust"
	if layout != null and "theme" in layout:
		theme_name = layout.theme

	var map := _layout_tile_map()
	var above := cell + Vector2i(0, -1)
	var above_key := "%d,%d" % [above.x, above.y]
	var is_surface: bool = not (map.has(above_key) and map[above_key] == TILE_SOLID)

	if theme_name == "cookie_crust":
		if not is_surface:
			return load("res://assets/sprites/terrain/cookie_tile_background.png") as Texture2D
		else:
			return load("res://assets/sprites/terrain/cookie_tile_surface.png") as Texture2D
	elif theme_name == "cookie_segment":
		if not is_surface:
			return load("res://assets/sprites/terrain/cookie_tile_background.png") as Texture2D
		else:
			return load("res://assets/sprites/terrain/cookie_platform_segment.png") as Texture2D
	elif theme_name == "thin_floor":
		if not is_surface:
			return load("res://assets/sprites/terrain/cookie_tile_background.png") as Texture2D
		else:
			return load("res://assets/sprites/terrain/thin_cookie_floor_segment.png") as Texture2D
	elif theme_name == "cookie_bridge_tile":
		return load("res://assets/sprites/terrain/cookie_bridge_tile.png") as Texture2D
	else:
		return load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _layout_tile_map() -> Dictionary:
	if "tile_map" in layout and not layout.tile_map.is_empty():
		return layout.tile_map
	var fallback := {}
	if "platform_cells" in layout:
		for cell: Vector2i in layout.platform_cells:
			fallback[_cell_key(cell)] = TILE_SOLID
	return fallback

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",", false)
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _cell_to_world(cell: Vector2i, cell_size: int) -> Vector2:
	return Vector2(
		float(cell.x * cell_size + cell_size / 2),
		float(cell.y * cell_size + cell_size / 2)
	)
