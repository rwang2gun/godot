extends Node

var _failed := false

func _ready() -> void:
	_test_visual_only_tile_types()
	_test_stage01_background_fill_is_visual_only()

	if _failed:
		get_tree().quit(1)
		return
	print("[test_StageLayoutBuilder] PASS")
	get_tree().quit(0)

func _test_visual_only_tile_types() -> void:
	var world := Node2D.new()
	add_child(world)

	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)

	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = {
		"0,0": "solid",
		"1,0": "background",
		"2,0": "surface",
		"3,0": "surface",
		"3,1": "solid",
		"3,2": "solid",
	}

	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()

	_expect(terrain.is_cell_occupied(Vector2i(0, 0)), "solid tile registered as occupied")
	_expect(not terrain.is_cell_occupied(Vector2i(1, 0)), "background tile must not register collision occupancy")
	_expect(not terrain.is_cell_occupied(Vector2i(2, 0)), "surface tile must not register collision occupancy")
	_expect(builder.get_node_or_null("Cell_0_0") is StaticBody2D, "solid tile creates StaticBody2D")
	_expect(builder.get_node_or_null("Visual_1_0") is Node2D, "background tile creates visual-only node")
	_expect(builder.get_node_or_null("Visual_2_0") is Node2D, "surface tile creates visual-only node")
	_expect(_has_collision_child(builder.get_node("Visual_1_0")) == false, "background visual has no collision child")
	_expect(_has_collision_child(builder.get_node("Visual_2_0")) == false, "surface visual has no collision child")
	var background_sprite := builder.get_node("Visual_1_0/Sprite") as Sprite2D
	var surface_sprite := builder.get_node("Visual_2_0/Sprite") as Sprite2D
	_expect(background_sprite.region_enabled, "background visual uses a texture region")
	_expect(background_sprite.region_rect.size == Vector2(48, 48), "background visual keeps square cell crop")
	_expect(surface_sprite.region_enabled, "surface visual uses a texture region")
	_expect(surface_sprite.region_rect.size == Vector2(48, 48), "surface visual keeps square cell crop")
	var under_surface_sprite := builder.get_node("Cell_3_1/BaseSprite") as Sprite2D
	var interior_sprite := builder.get_node("Cell_3_2/BaseSprite") as Sprite2D
	_expect(under_surface_sprite.texture.resource_path.ends_with("cookie_tile_under_surface.png"), "solid touching surface uses transition tile")
	_expect(interior_sprite.texture.resource_path.ends_with("cookie_tile_background.png"), "deep solid uses interior tile")
	world.queue_free()

func _test_stage01_background_fill_is_visual_only() -> void:
	var world := Node2D.new()
	add_child(world)

	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)

	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = load("res://data/stage_layouts/stage01_layout.tres")
	world.add_child(builder)
	builder.build()

	_expect(not terrain.is_cell_occupied(Vector2i(3, 17)), "stage01 surface row is visual-only")
	_expect(terrain.is_cell_occupied(Vector2i(3, 18)), "stage01 interior tile carries collision below surface")
	_expect(not terrain.is_cell_occupied(Vector2i(10, 22)), "stage01 lower surface row is visual-only")
	_expect(terrain.is_cell_occupied(Vector2i(10, 23)), "stage01 lower interior tile carries collision below surface")
	_expect(builder.get_node_or_null("Visual_3_17") is Node2D, "stage01 surface creates visual node")
	var stage_surface_sprite := builder.get_node("Visual_3_17/Sprite") as Sprite2D
	_expect(stage_surface_sprite.region_rect.size == Vector2(48, 48), "stage01 surface is a square tile")
	var stage_under_surface_sprite := builder.get_node("Cell_3_18/BaseSprite") as Sprite2D
	var stage_interior_sprite := builder.get_node("Cell_9_19/BaseSprite") as Sprite2D
	_expect(stage_under_surface_sprite.texture.resource_path.ends_with("cookie_tile_under_surface.png"), "stage01 surface-contact solid uses transition tile")
	_expect(stage_interior_sprite.texture.resource_path.ends_with("cookie_tile_background.png"), "stage01 deep solid uses interior tile")
	world.queue_free()

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
