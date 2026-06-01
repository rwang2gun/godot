extends Node

var _failed := false

func _ready() -> void:
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.set_cell_size(48)

	if not terrain.add_tile(Vector2i(0, 0), Terrain.DYNAMIC_TILE_STAIR, 1):
		_fail("right stair add_tile returned false")
		return
	if not terrain.add_tile(Vector2i(1, 0), Terrain.DYNAMIC_TILE_STAIR, -1):
		_fail("left stair add_tile returned false")
		return

	_expect_stair_sprite(Vector2i(0, 0), false)
	_expect_stair_sprite(Vector2i(1, 0), true)

	if _failed:
		return
	print("[DynamicStairTileVisualTest] PASS")
	get_tree().quit(0)

func _expect_stair_sprite(cell: Vector2i, expected_flip_h: bool) -> void:
	var body := terrain_body(cell)
	if body == null:
		_fail("missing placed body at %s" % str(cell))
		return
	var sprite: Sprite2D = null
	for child in body.get_children():
		if child is Sprite2D:
			sprite = child as Sprite2D
			break
	if sprite == null:
		_fail("missing Sprite2D at %s" % str(cell))
		return
	if sprite.texture == null:
		_fail("missing stair texture at %s" % str(cell))
		return
	if not sprite.texture.resource_path.ends_with("cookie_stair_tile.png"):
		_fail("unexpected texture at %s: %s" % [str(cell), sprite.texture.resource_path])
		return
	if sprite.flip_h != expected_flip_h:
		_fail("flip_h mismatch at %s: got %s expected %s" % [str(cell), str(sprite.flip_h), str(expected_flip_h)])
		return
	if not sprite.scale.is_equal_approx(Vector2.ONE):
		_fail("scale mismatch at %s: got %s expected (1, 1)" % [str(cell), str(sprite.scale)])
		return

func terrain_body(cell: Vector2i) -> StaticBody2D:
	var terrain := get_child(0) as Terrain
	return terrain._placed.get(cell) as StaticBody2D

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[DynamicStairTileVisualTest] FAIL %s" % msg)
	get_tree().quit(1)
