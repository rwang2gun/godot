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
const TILE_BACKGROUND := "background"
const TILE_SURFACE := "surface"
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
		if body == null:
			continue
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
	if tile_type == TILE_BACKGROUND or tile_type == TILE_SURFACE:
		_add_visual_only_cell(cell, cell_size, tile_type)
		return null

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

func _add_visual_only_cell(cell: Vector2i, cell_size: int, tile_type: String) -> void:
	var visual := Node2D.new()
	visual.name = "Visual_%d_%d" % [cell.x, cell.y]
	visual.position = _cell_to_world(cell, cell_size)
	add_child(visual)
	visual.owner = owner

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var texture: Texture2D = _surface_texture() if tile_type == TILE_SURFACE else load("res://assets/sprites/terrain/cookie_tile_background.png") as Texture2D
	if texture != null:
		if tile_type == TILE_SURFACE:
			_configure_repeating_region(sprite, texture, cell, Vector2(cell_size, cell_size))
		else:
			_configure_repeating_region(sprite, texture, cell, Vector2(cell_size, cell_size))
	else:
		sprite.modulate = Color(0.45, 0.28, 0.15)
	visual.add_child(sprite)
	sprite.owner = owner

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
	# 1. 베이스 지형 (정사각형 내부 타일)
	var base_sprite := Sprite2D.new()
	base_sprite.name = "BaseSprite"
	var base_texture := _solid_texture_for_cell(cell)
	if base_texture != null:
		_configure_repeating_region(base_sprite, base_texture, cell, Vector2(cell_size, cell_size))
	else:
		base_sprite.modulate = Color(0.45, 0.28, 0.15)
	body.add_child(base_sprite)
	base_sprite.owner = owner

	# 2. 표면일 경우 상단에 얇은 표면 데코레이션 레이어 오버레이 (충돌 없음)
	var map := _layout_tile_map()
	var above := cell + Vector2i(0, -1)
	var above_key := "%d,%d" % [above.x, above.y]
	var is_surface: bool = not map.has(above_key)

	if is_surface:
		var surface_sprite := Sprite2D.new()
		surface_sprite.name = "SurfaceSprite"
		var surface_tex: Texture2D = _surface_texture()
			
		if surface_tex != null:
			var region_size := Vector2(cell_size, cell_size)
			_configure_repeating_region(surface_sprite, surface_tex, cell, region_size)
			body.add_child(surface_sprite)
			surface_sprite.owner = owner

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
	var is_surface: bool = not map.has(above_key)

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

func _surface_texture() -> Texture2D:
	var theme_name: String = "cookie_crust"
	if layout != null and "theme" in layout:
		theme_name = layout.theme

	if theme_name == "cookie_crust":
		return load("res://assets/sprites/terrain/cookie_tile_surface.png") as Texture2D
	elif theme_name == "cookie_segment":
		return load("res://assets/sprites/terrain/cookie_platform_segment.png") as Texture2D
	elif theme_name == "thin_floor":
		return load("res://assets/sprites/terrain/thin_cookie_floor_segment.png") as Texture2D
	elif theme_name == "cookie_bridge_tile":
		return load("res://assets/sprites/terrain/cookie_bridge_tile.png") as Texture2D
	return load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D

func _solid_texture_for_cell(cell: Vector2i) -> Texture2D:
	var map := _layout_tile_map()
	var above := cell + Vector2i(0, -1)
	var above_key := "%d,%d" % [above.x, above.y]
	if str(map.get(above_key, "")) == TILE_SURFACE:
		return load("res://assets/sprites/terrain/cookie_tile_under_surface.png") as Texture2D
	return load("res://assets/sprites/terrain/cookie_tile_background.png") as Texture2D

func _configure_repeating_region(sprite: Sprite2D, texture: Texture2D, cell: Vector2i, region_size: Vector2) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var source_size := Vector2(minf(region_size.x, tex_size.x), minf(region_size.y, tex_size.y))
	var source_x := 0.0
	if tex_size.x > source_size.x:
		var columns := maxi(1, int(floor(tex_size.x / source_size.x)))
		source_x = float(posmod(cell.x, columns)) * source_size.x
	var source_y := maxf(0.0, (tex_size.y - source_size.y) * 0.5)
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(source_x, source_y), source_size)
	sprite.scale = Vector2(region_size.x / source_size.x, region_size.y / source_size.y)

func _is_collision_tile(tile_type: String) -> bool:
	return (
		tile_type == TILE_SOLID
		or tile_type == TILE_SLOPE_RIGHT
		or tile_type == TILE_SLOPE_LEFT
		or tile_type == TILE_PLANT_SOLID
	)

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
