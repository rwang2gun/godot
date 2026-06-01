extends Node

# terrain-tier-restructure Phase 2 — surface tier 제거 후 2-tier(under-surface top / interior) 모델 검증.
# (구) surface 타일 타입 / 노출천장 SurfaceSprite 오버레이는 제거됨. 노출 최상단 solid는 under-surface,
# 위가 가려진 solid는 interior. exposure 술어 = `not tile_map.has(above_key)`.

var _failed := false

const COLLISION_KINDS := ["solid", "slope_left", "slope_right", "plant"]

func _ready() -> void:
	_test_texture_tiers_and_visual_only()
	# codex plan R1-M2 — stage01 포함 전 stage 마이그레이션 불변(점유 == collision tile, surface 부재).
	_check_stage("res://data/stage_layouts/stage01_layout.tres")
	_check_stage("res://data/stage_layouts/stage02_layout.tres")
	_check_stage("res://data/stage_layouts/stage03_layout.tres")

	if _failed:
		get_tree().quit(1)
		return
	print("[test_StageLayoutBuilder] PASS")
	get_tree().quit(0)

# codex plan R1-M1 — exposure 술어 edge case: stacked / under-slope / under-background / isolated-exposed.
func _test_texture_tiers_and_visual_only() -> void:
	var world := Node2D.new()
	add_child(world)

	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)

	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = {
		"0,0": "solid",        # isolated 노출 solid (위 빈 칸) → under-surface
		"1,0": "background",   # visual-only (충돌 없음)
		"5,0": "solid",        # stacked 최상단 (위 빈 칸) → under-surface
		"5,1": "solid",        # 위가 solid → interior
		"7,0": "background",
		"7,1": "solid",        # 위가 background → interior (가려짐)
		"9,0": "slope_left",
		"9,1": "solid",        # 위가 slope → interior (가려짐)
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

	# 텍스처 tier (under-surface = 노출 최상단, interior = 가려진 셀)
	_expect_tier(builder, Vector2i(0, 0), "cookie_tile_under_surface.png", "isolated exposed solid uses under-surface")
	_expect_tier(builder, Vector2i(5, 0), "cookie_tile_under_surface.png", "stacked top solid uses under-surface")
	_expect_tier(builder, Vector2i(5, 1), "cookie_tile_background.png", "solid under solid uses interior")
	_expect_tier(builder, Vector2i(7, 1), "cookie_tile_background.png", "solid under background uses interior")
	_expect_tier(builder, Vector2i(9, 1), "cookie_tile_background.png", "solid under slope uses interior")

	# background visual sprite는 정사각 region 크롭 유지
	var background_sprite := builder.get_node("Visual_1_0/Sprite") as Sprite2D
	_expect(background_sprite.region_enabled, "background visual uses a texture region")
	_expect(background_sprite.region_rect.size == Vector2(48, 48), "background visual keeps square cell crop")

	world.queue_free()

# 실제 stage layout 마이그레이션 불변: surface tile type 부재 + 점유 셀 == collision tile 셀 +
# 노출 최상단 solid=under-surface / 가려진 solid=interior + SurfaceSprite 부재.
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
				var suffix := "cookie_tile_background.png" if tile_map.has(above_key) else "cookie_tile_under_surface.png"
				_expect_tier(builder, cell, suffix, "%s: solid %s tier" % [path, key])
		else:
			_expect(not terrain.is_cell_occupied(cell), "%s: visual-only tile %s must not register occupancy" % [path, key])

	world.queue_free()

func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _expect_tier(builder: Node, cell: Vector2i, suffix: String, message: String) -> void:
	var base := builder.get_node_or_null("Cell_%d_%d/BaseSprite" % [cell.x, cell.y]) as Sprite2D
	if base == null or base.texture == null:
		_failed = true
		print("[test_StageLayoutBuilder] FAIL ", message, " (missing BaseSprite/texture)")
		return
	_expect(base.texture.resource_path.ends_with(suffix), message)

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
