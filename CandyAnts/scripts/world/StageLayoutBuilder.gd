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
# Phase 19 — 식물 정적 cell. _add_cell이 _add_plant_visual placeholder 적용 + build()가
# register_static_body(kind="plant") 호출 → Terrain._cell_kind = "plant"로 등록되어 Cutter 전용 destroy 대상.
const TILE_PLANT_SOLID := "plant"
# S6 "땅굴" — 불괴(non-destructible) 구조 cell. build()가 register_static_body(kind="cookie") 호출 →
# Terrain._cell_kind = "cookie". digger/basher의 destroy_tile_at(["earth"])·cutter(["plant"])가 모두 거부 →
# 벽·챔버 바닥의 구조 무결성 보장(파괴 불가). 시각은 임시 색조(설계 B3 — 정식 흙/쿠키 텍스처 아트 후속).
const TILE_COOKIE_SOLID := "cookie"
# 정적 막대과자 사다리 cell — 스킬(SandMoundSkill) 없이 레벨 레이아웃에 직접 까는 사다리.
# build()가 register_static_body(kind="earth", ladder_sprite)로 등록 → Terrain._sand_mound_sprites에 올라
# is_ladder_cell=true. 개미가 스킬 없이도 이 셀에 막혀 LadderClimbState로 수직 등반(동적 rung과 동일 경로).
# kind="earth"라 basher/digger 파괴 가능 — 파괴 시 destroy_tile_at이 _sand_mound_sprites.erase → 즉시 FallerState.
const TILE_SAND_MOUND := "sand_mound"

# terrain-tier-restructure Phase 3 — ground 타일을 48×48 단일 정사각 4-variant로 교체.
# 노출 최상단(걷는 면) = surface family, 가려진 본체 + background 시각 채움 = solid family.
# (구) 336×48 가로 아틀라스(cookie_tile_under_surface / cookie_tile_background)는 ground에서 미사용.
const SURFACE_TILES: Array[String] = [
	"res://assets/sprites/terrain/usable_square/cookie_surface_square_01.png",
	"res://assets/sprites/terrain/usable_square/cookie_surface_square_02.png",
	"res://assets/sprites/terrain/usable_square/cookie_surface_square_03.png",
	"res://assets/sprites/terrain/usable_square/cookie_surface_square_04.png",
]
const SOLID_TILES: Array[String] = [
	"res://assets/sprites/terrain/usable_square/cookie_solid_rotatable_square_01.png",
	"res://assets/sprites/terrain/usable_square/cookie_solid_rotatable_square_02.png",
	"res://assets/sprites/terrain/usable_square/cookie_solid_rotatable_square_03.png",
	"res://assets/sprites/terrain/usable_square/cookie_solid_rotatable_square_04.png",
]

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
		# Phase 19 — TILE_PLANT_SOLID만 kind="plant", S6 TILE_COOKIE_SOLID는 kind="cookie"(불괴),
		# 기존 solid/slope_*는 모두 "earth"로 backward compat.
		var kind: String = "earth"
		var ladder_sprite: Sprite2D = null
		if tile_type == TILE_PLANT_SOLID:
			kind = "plant"
		elif tile_type == TILE_COOKIE_SOLID:
			kind = "cookie"
		elif tile_type == TILE_SAND_MOUND:
			# 정적 사다리 — kind는 earth(파괴 가능) 유지, middle sprite를 Terrain에 넘겨 is_ladder_cell 등록.
			ladder_sprite = body.get_node_or_null("LadderVisual") as Sprite2D
		generated.append({"cell": c, "body": body, "kind": kind, "ladder_sprite": ladder_sprite})
	# Editor preview에서는 Terrain 없는 경우가 정상 → skip.
	if Engine.is_editor_hint():
		return
	var terrain: Terrain = _find_ancestor_terrain()
	if terrain != null:
		terrain.set_cell_size(int(layout.cell_size))
		for g in generated:
			terrain.register_static_body(g["cell"], g["body"], g["kind"], g["ladder_sprite"])
		_reskin_static_ladder_caps(terrain, generated)
	else:
		push_warning("StageLayoutBuilder could not find Terrain; cell_size/static occupancy registration skipped")

# 정적 사다리(TILE_SAND_MOUND) 기둥의 맨 위/맨 아래 경계에 인접한 정적 지형 면을 top/root 텍스처로 통합한다
# (동적 사다리와 동일한 root→middle→top 시각). 시각만 — 충돌/점유/kind/is_ladder_cell 불변.
# reskin_cell_to_ladder는 적격(kind="earth" + 정적 _static_bodies 등록 + 직접 Sprite2D)일 때만 적용하고,
# 빈 칸·cookie·plant·슬로프·동적 _placed 타일이면 내부에서 no-op(false). 따라서 사다리 위/아래가 솔리드
# 지면이 아니면 자동으로 건너뛴다(디자이너가 사다리만 허공에 깔아도 안전).
func _reskin_static_ladder_caps(terrain: Terrain, generated: Array[Dictionary]) -> void:
	var ladder_cells: Dictionary = {}
	for g in generated:
		if g["ladder_sprite"] != null:
			ladder_cells[g["cell"]] = true
	for cell: Vector2i in ladder_cells:
		# 위 칸이 사다리가 아니면(기둥 맨 위) 그 위 지면을 top으로 cap.
		var above: Vector2i = cell + Vector2i(0, -1)
		if not ladder_cells.has(above):
			terrain.reskin_cell_to_ladder(above, Terrain.LADDER_TIER_TOP)
		# 아래 칸이 사다리가 아니면(기둥 맨 아래) 그 아래 지면을 root로.
		var below: Vector2i = cell + Vector2i(0, 1)
		if not ladder_cells.has(below):
			terrain.reskin_cell_to_ladder(below, Terrain.LADDER_TIER_ROOT)

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
	if tile_type == TILE_BACKGROUND:
		_add_visual_only_cell(cell, cell_size)
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
	elif tile_type == TILE_COOKIE_SOLID:
		_add_solid_collision(body, cell_size)
		_add_cookie_visual(body, cell_size, cell)
	elif tile_type == TILE_SAND_MOUND:
		_add_solid_collision(body, cell_size)
		_add_ladder_visual(body, cell_size)
	else:
		_add_solid_collision(body, cell_size)
		_add_solid_visual(body, cell_size, cell)
	return body

func _add_visual_only_cell(cell: Vector2i, cell_size: int) -> void:
	# terrain-tier-restructure Phase 2 — visual-only는 background(interior) 한 종류만 (surface tile type 제거).
	# Phase 3 — interior 채움은 solid family(cookie_solid_rotatable_square) 4-variant whole-tile.
	var visual := Node2D.new()
	visual.name = "Visual_%d_%d" % [cell.x, cell.y]
	visual.position = _cell_to_world(cell, cell_size)
	add_child(visual)
	visual.owner = owner

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var texture: Texture2D = load(SOLID_TILES[_variant_index(cell, SOLID_TILES.size())]) as Texture2D
	if texture != null:
		_apply_square_tile(sprite, texture, cell_size)
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
	# 베이스 지형 (정사각형 내부 타일). 노출 최상단(위가 빈 칸)이면 surface family, 아니면 solid family.
	# terrain-tier-restructure Phase 3 — 48×48 단일 타일 whole-tile 렌더. 텍스처 선택은 _solid_texture_for_cell.
	var base_sprite := Sprite2D.new()
	base_sprite.name = "BaseSprite"
	var base_texture := _solid_texture_for_cell(cell)
	if base_texture != null:
		_apply_square_tile(base_sprite, base_texture, cell_size)
	else:
		base_sprite.modulate = Color(0.45, 0.28, 0.15)
	body.add_child(base_sprite)
	base_sprite.owner = owner

func _add_cookie_visual(body: StaticBody2D, cell_size: int, cell: Vector2i) -> void:
	# S6 "땅굴" — 불괴 구조 타일 placeholder 비주얼. 정사각 cookie 텍스처에 차가운 색조를 입혀 굴착 가능한
	# earth(warm cookie 텍스처, 무색조)와 시각적으로 대비한다("단단한 사탕 껍질" 느낌). 임시 색조 구분이며
	# 정식 흙/쿠키 텍스처 스왑은 아트 트랙 후속(설계 B3). 충돌/kind는 _add_solid_collision + build() kind="cookie"가 담당.
	var sprite := Sprite2D.new()
	sprite.name = "CookieVisual"
	var texture: Texture2D = load(SOLID_TILES[_variant_index(cell, SOLID_TILES.size())]) as Texture2D
	if texture != null:
		_apply_square_tile(sprite, texture, cell_size)
		sprite.modulate = Color(0.60, 0.70, 0.95)
	else:
		sprite.modulate = Color(0.55, 0.62, 0.85)
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

func _add_ladder_visual(body: StaticBody2D, cell_size: int) -> void:
	# 정적 막대과자 사다리 rung — 동적 사다리(Terrain DYNAMIC_TILE_SAND_MOUND)와 동일한 middle 텍스처 whole-tile.
	# 충돌은 _add_solid_collision이 담당(개미가 막혀 LadderClimbState 진입). 이 sprite를 build()가
	# Terrain._sand_mound_sprites에 등록 → is_ladder_cell=true. 텍스처 경로는 Terrain._ladder_texture와 동일 SoT.
	var sprite := Sprite2D.new()
	sprite.name = "LadderVisual"
	var texture: Texture2D = load("res://assets/sprites/terrain/usable_square/biscuit_ladder_middle_square.png") as Texture2D
	if texture != null:
		_apply_square_tile(sprite, texture, cell_size)
	else:
		sprite.modulate = Color(0.80, 0.62, 0.30)
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

# terrain-tier-restructure Phase 2 — surface tier 제거 후 exposure 술어 반전. Phase 3 — 타일 family 교체.
# 위 칸이 레이아웃에 "존재하지 않을 때만"(= 진짜 빈 칸/공기) 노출 최상단 → surface family(cookie_surface_square).
# 위 칸이 존재하면(solid/slope/plant/background 무엇이든 = 가려진 셀) → solid family(cookie_solid_rotatable_square).
# `not map.has(above_key)` 술어는 단일 SoT다 — 좁은 `== TILE_SOLID` 해석 금지.
func _solid_texture_for_cell(cell: Vector2i) -> Texture2D:
	var map := _layout_tile_map()
	var above := cell + Vector2i(0, -1)
	var above_key := "%d,%d" % [above.x, above.y]
	if not map.has(above_key):
		return load(SURFACE_TILES[_variant_index(cell, SURFACE_TILES.size())]) as Texture2D
	return load(SOLID_TILES[_variant_index(cell, SOLID_TILES.size())]) as Texture2D

# terrain-tier-restructure Phase 3 — 비선형 bit-mixing 정수 해시로 variant 선택.
# 선형식(posmod(a*x+b*y, n))은 대각/줄 밴딩 + 4-bucket 주기성이 눈에 띄므로 bit-mixing으로 분산한다.
# 결정적: 같은 cell → 항상 같은 variant (리빌드 안정). 테스트는 이 공식을 복제하지 않고 family 집합/분포만 검증.
func _variant_index(cell: Vector2i, n: int) -> int:
	if n <= 1:
		return 0
	var h: int = cell.x * 374761393 + cell.y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return posmod(h, n)

# terrain-tier-restructure Phase 3 — discrete 48×48 단일 타일 whole-tile 렌더 (sand-mound §11.3과 동형).
# region 슬라이스 없이 텍스처를 통째로 cell_size에 맞춰 균일 scale → 비-48 cell_size에서도 크롭/오프셋 없이 중앙 정렬.
func _apply_square_tile(sprite: Sprite2D, texture: Texture2D, cell_size: int) -> void:
	var tex_size := texture.get_size()
	sprite.texture = texture
	sprite.region_enabled = false
	sprite.centered = true
	sprite.position = Vector2.ZERO
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		sprite.scale = Vector2(float(cell_size) / tex_size.x, float(cell_size) / tex_size.y)

func _is_collision_tile(tile_type: String) -> bool:
	return (
		tile_type == TILE_SOLID
		or tile_type == TILE_SLOPE_RIGHT
		or tile_type == TILE_SLOPE_LEFT
		or tile_type == TILE_PLANT_SOLID
		or tile_type == TILE_COOKIE_SOLID
		or tile_type == TILE_SAND_MOUND
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
