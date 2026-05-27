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
# Phase 19 — 식물 정적 cell. _add_cell이 _add_plant_visual placeholder 적용 + build()가
# register_static_body(kind="plant") 호출 → Terrain._cell_kind = "plant"로 등록되어 Cutter 전용 destroy 대상.
const TILE_PLANT_SOLID := "plant"

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_preview()
	else:
		build()

func build() -> void:
	# Phase 16 — ready-time only. 런타임 재호출 시 Terrain._static_occupancy에 stale cell이 누적된다
	# (현재 clear API 없음). 동적 layout swap 필요 시 Terrain에 clear_static_cells() API 추가 필요.
	_clear_children()
	if layout == null:
		return
	# Phase 18 — _add_cell이 StaticBody2D 반환. cell+body 페어로 모아서 끝에서 register_static_body
	# (kind="earth")로 일괄 등록. register_static_body 내부에서 register_static_cell 호출되므로
	# 기존 _static_occupancy 등록 invariant 유지(D8 first-place wins backward compat).
	var generated: Array[Dictionary] = []
	for key in _layout_tile_map().keys():
		var c: Vector2i = _cell_from_key(str(key))
		var tile_type: String = str(_layout_tile_map()[key])
		var body: StaticBody2D = _add_cell(c, tile_type)
		# Phase 19 — TILE_PLANT_SOLID만 kind="plant"로 등록, 기존 solid/slope_*는 모두 "earth"로 backward compat.
		var kind: String = "plant" if tile_type == TILE_PLANT_SOLID else "earth"
		generated.append({"cell": c, "body": body, "kind": kind})
	# Editor preview에서는 Terrain 없는 경우가 정상 → skip.
	if Engine.is_editor_hint():
		return
	var terrain: Terrain = _find_ancestor_terrain()
	if terrain != null:
		terrain.set_cell_size(int(layout.cell_size))
		for g in generated:
			terrain.register_static_body(g["cell"], g["body"], g["kind"])
	else:
		push_warning("StageLayoutBuilder could not find Terrain; cell_size/static occupancy registration skipped")

func _find_ancestor_terrain() -> Terrain:
	# ancestor scan — Ant._resolve_mantle_distance 패턴 답습.
	var node: Node = self
	while node != null:
		var t: Terrain = node.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if node is Terrain:
			return node as Terrain
		node = node.get_parent()
	return null

func _rebuild_preview() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	if not preview_in_editor or layout == null:
		return
	for key in _layout_tile_map().keys():
		# Editor preview는 Terrain 없는 경우가 정상 → 반환값 무캡처.
		_add_cell(_cell_from_key(str(key)), str(_layout_tile_map()[key]))

func _add_cell(cell: Vector2i, tile_type: String = TILE_SOLID) -> StaticBody2D:
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
	elif tile_type == TILE_PLANT_SOLID:
		_add_solid_collision(body, cell_size)
		_add_plant_visual(body, cell_size)
	else:
		_add_solid_collision(body, cell_size)
		_add_solid_visual(body, cell_size, cell)
	return body

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

func _add_plant_visual(body: StaticBody2D, cell_size: int) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "PlantVisual"
	sprite.texture = load("res://assets/sprites/terrain/peppermint_plant.png") as Texture2D
	if sprite.texture != null:
		var texture_size := sprite.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			sprite.scale = Vector2(float(cell_size) / texture_size.x, float(cell_size) / texture_size.y)
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
