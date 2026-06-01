extends Node

# terrain-tier-restructure Phase 3 — 48×48 단일 정사각 4-variant 타일 모델 검증.
# 노출 최상단 solid = cookie_surface_square family, 가려진 solid + background = cookie_solid_rotatable_square family.
# (Phase 2 모델: surface 타일 타입 / 노출천장 SurfaceSprite 오버레이 제거. exposure 술어 = `not tile_map.has(above_key)`.)
#
# variant index 공식은 테스트가 복제하지 않는다(밴딩 아티팩트 박제 방지 — codex plan R1-M1).
# 대신 (i) family 집합 membership, (ii) 결정성, (iii) 넓은 필드 ≥2 variant 분포,
# (iv) whole-tile 렌더(region_enabled==false), (v) 비-48 cell_size scale(R1-M2)을 검증한다.

var _failed := false

const COLLISION_KINDS := ["solid", "slope_left", "slope_right", "plant"]

func _ready() -> void:
	_test_texture_tiers_and_visual_only()
	_test_variant_distribution_and_determinism()
	_test_non_48_cell_size()
	# codex plan R1-M2 — stage01 포함 전 stage 마이그레이션 불변(점유 == collision tile, surface 부재).
	_check_stage("res://data/stage_layouts/stage01_layout.tres")
	_check_stage("res://data/stage_layouts/stage02_layout.tres")
	_check_stage("res://data/stage_layouts/stage03_layout.tres")

	if _failed:
		get_tree().quit(1)
		return
	print("[test_StageLayoutBuilder] PASS")
	get_tree().quit(0)

# exposure 술어 edge case: stacked / under-slope / under-background / isolated-exposed + family/whole-tile.
func _test_texture_tiers_and_visual_only() -> void:
	var world := Node2D.new()
	add_child(world)

	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)

	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = {
		"0,0": "solid",        # isolated 노출 solid (위 빈 칸) → surface family
		"1,0": "background",   # visual-only (충돌 없음)
		"5,0": "solid",        # stacked 최상단 (위 빈 칸) → surface family
		"5,1": "solid",        # 위가 solid → solid family
		"7,0": "background",
		"7,1": "solid",        # 위가 background → solid family (가려짐)
		"9,0": "slope_left",
		"9,1": "solid",        # 위가 slope → solid family (가려짐)
	}

	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()

	# 충돌/점유
	_expect(terrain.is_cell_occupied(Vector2i(0, 0)), "solid tile registered as occupied")
	_expect(not terrain.is_cell_occupied(Vector2i(1, 0)), "background tile must not register collision occupancy")
	_expect(terrain.is_cell_occupied(Vector2i(9, 0)), "slope tile registered as occupied")

	# 노드 종류
	_expect(builder.get_node_or_null("Cell_0_0") is StaticBody2D, "solid tile creates StaticBody2D")
	_expect(builder.get_node_or_null("Visual_1_0") is Node2D, "background tile creates visual-only node")
	_expect(_has_collision_child(builder.get_node("Visual_1_0")) == false, "background visual has no collision child")

	# surface tier 제거 — 어떤 solid에도 SurfaceSprite 오버레이가 없어야 한다
	_expect(builder.get_node_or_null("Cell_0_0/SurfaceSprite") == null, "exposed solid has no SurfaceSprite overlay")
	_expect(builder.get_node_or_null("Cell_5_0/SurfaceSprite") == null, "stacked-top solid has no SurfaceSprite overlay")

	# 텍스처 family (노출 최상단 = surface, 가려진 = solid) + whole-tile 렌더
	_expect_tier_family(builder, Vector2i(0, 0), true, "isolated exposed solid uses surface family")
	_expect_tier_family(builder, Vector2i(5, 0), true, "stacked top solid uses surface family")
	_expect_tier_family(builder, Vector2i(5, 1), false, "solid under solid uses solid family")
	_expect_tier_family(builder, Vector2i(7, 1), false, "solid under background uses solid family")
	_expect_tier_family(builder, Vector2i(9, 1), false, "solid under slope uses solid family")

	# background visual = solid family + whole-tile (region 비활성)
	var background_sprite := builder.get_node("Visual_1_0/Sprite") as Sprite2D
	_expect(not background_sprite.region_enabled, "background visual uses whole-tile (no region)")
	_expect(_path_in(background_sprite.texture, StageLayoutBuilder.SOLID_TILES), "background visual uses solid family")

	world.queue_free()

# (iii) 넓은 노출 면(surface) + 가려진 본체(solid)에서 ≥2 variant 등장(밴딩 회귀) + (ii) 결정성.
func _test_variant_distribution_and_determinism() -> void:
	var tile_map := {}
	for x in range(16):
		tile_map["%d,0" % x] = "solid"   # 노출 최상단 → surface family
		tile_map["%d,1" % x] = "solid"   # 위 solid → solid family
		tile_map["%d,2" % x] = "solid"   # 위 solid → solid family
	var first := _build_textures(tile_map)
	var second := _build_textures(tile_map)

	# 결정성: 같은 cell 두 번 build → 같은 텍스처
	for cell in first.keys():
		_expect(first[cell] == second[cell], "variant deterministic at %s" % str(cell))

	# 분포: surface 행(y=0)과 solid 본체(y>=1)에 각각 ≥2 variant (단조 밴딩 감지)
	var surface_set := {}
	var solid_set := {}
	for cell in first.keys():
		if cell.y == 0:
			surface_set[first[cell]] = true
		else:
			solid_set[first[cell]] = true
	_expect(surface_set.size() >= 2, "exposed field shows >=2 surface variants (no banding)")
	_expect(solid_set.size() >= 2, "interior field shows >=2 solid variants (no banding)")

# (iv)(v) 비-48 cell_size 회귀 가드 — whole-tile scale=cell_size/tex, region 비활성, 중앙 정렬.
func _test_non_48_cell_size() -> void:
	var world := Node2D.new()
	add_child(world)

	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)

	var layout := StageLayoutData.new()
	layout.cell_size = 32
	layout.tile_map = {
		"0,0": "solid",        # 노출 → surface family
		"0,1": "solid",        # 위 solid → solid family
		"2,0": "background",   # visual-only
	}

	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()

	_check_square_scale(builder.get_node_or_null("Cell_0_0/BaseSprite") as Sprite2D, 32, "exposed solid 32px")
	_check_square_scale(builder.get_node_or_null("Cell_0_1/BaseSprite") as Sprite2D, 32, "covered solid 32px")
	_check_square_scale(builder.get_node_or_null("Visual_2_0/Sprite") as Sprite2D, 32, "background 32px")

	world.queue_free()

# 실제 stage layout 마이그레이션 불변: surface tile type 부재 + 점유 셀 == collision tile 셀 +
# 노출 최상단 solid=surface family / 가려진 solid=solid family + SurfaceSprite 부재.
func _check_stage(path: String) -> void:
	var world := Node2D.new()
	add_child(world)

	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)

	var layout: Resource = load(path)
	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()

	var tile_map: Dictionary = layout.tile_map
	for key in tile_map.keys():
		var t := str(tile_map[key])
		_expect(t != "surface", "%s: no surface tile type remains at %s" % [path, key])
		var cell := _cell_from_key(str(key))
		if t in COLLISION_KINDS:
			_expect(terrain.is_cell_occupied(cell), "%s: collision tile %s registers occupancy" % [path, key])
			_expect(builder.get_node_or_null("Cell_%d_%d/SurfaceSprite" % [cell.x, cell.y]) == null,
				"%s: collision tile %s has no SurfaceSprite overlay" % [path, key])
			if t == "solid":
				var above_key := "%d,%d" % [cell.x, cell.y - 1]
				var is_surface := not tile_map.has(above_key)
				_expect_tier_family(builder, cell, is_surface, "%s: solid %s tier" % [path, key])
		else:
			_expect(not terrain.is_cell_occupied(cell), "%s: visual-only tile %s must not register occupancy" % [path, key])

	world.queue_free()

# fresh world에서 layout build → cell→texture resource_path Dictionary 반환 (분포/결정성 검사용).
func _build_textures(tile_map: Dictionary) -> Dictionary:
	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = tile_map
	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()
	var out := {}
	for key in tile_map.keys():
		var cell := _cell_from_key(str(key))
		var base := builder.get_node_or_null("Cell_%d_%d/BaseSprite" % [cell.x, cell.y]) as Sprite2D
		if base != null and base.texture != null:
			out[cell] = base.texture.resource_path
	world.queue_free()
	return out

func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

# tier family + whole-tile membership 검사 (variant index 공식 비복제).
func _expect_tier_family(builder: Node, cell: Vector2i, is_surface: bool, message: String) -> void:
	var base := builder.get_node_or_null("Cell_%d_%d/BaseSprite" % [cell.x, cell.y]) as Sprite2D
	if base == null or base.texture == null:
		_failed = true
		print("[test_StageLayoutBuilder] FAIL ", message, " (missing BaseSprite/texture)")
		return
	var family: Array = StageLayoutBuilder.SURFACE_TILES if is_surface else StageLayoutBuilder.SOLID_TILES
	_expect(_path_in(base.texture, family), message)
	_expect(not base.region_enabled, message + " (whole-tile, region disabled)")

func _check_square_scale(sprite: Sprite2D, cell_size: int, message: String) -> void:
	if sprite == null or sprite.texture == null:
		_failed = true
		print("[test_StageLayoutBuilder] FAIL ", message, " (missing sprite/texture)")
		return
	_expect(not sprite.region_enabled, message + " (region disabled)")
	_expect(sprite.centered, message + " (centered)")
	_expect(sprite.position == Vector2.ZERO, message + " (position zero → cell-centered)")
	var tex := sprite.texture.get_size()
	var expected := Vector2(float(cell_size) / tex.x, float(cell_size) / tex.y)
	_expect(sprite.scale.is_equal_approx(expected), "%s scale == %s (got %s)" % [message, str(expected), str(sprite.scale)])

func _path_in(texture: Texture2D, paths: Array) -> bool:
	if texture == null:
		return false
	return texture.resource_path in paths

func _has_collision_child(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return true
		if _has_collision_child(child):
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	print("[test_StageLayoutBuilder] FAIL ", message)
