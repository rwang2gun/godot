extends Node

var _failed := false

func _ready() -> void:
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.set_cell_size(48)

	# 디아그램(2026-06-03): STAIR(01)=표면, STAIR_FILL(02)=그 아래 받침. 각자 별도 셀에 단일 비스킷 렌더.
	if not terrain.add_tile(Vector2i(0, 0), Terrain.DYNAMIC_TILE_STAIR, 1):
		_fail("right stair add_tile returned false")
		return
	if not terrain.add_tile(Vector2i(1, 0), Terrain.DYNAMIC_TILE_STAIR, -1):
		_fail("left stair add_tile returned false")
		return
	if not terrain.add_tile(Vector2i(0, 1), Terrain.DYNAMIC_TILE_STAIR_FILL, 1):
		_fail("stair_fill add_tile returned false")
		return

	# STAIR(01) = 표면, 등반 대상(_stair_cells). 단일 01 비스킷, 셀 중앙, scale=48/76.
	_expect_single(Vector2i(0, 0), "biscuit_stair_45_01.png", false, true)
	_expect_single(Vector2i(1, 0), "biscuit_stair_45_01.png", true, true)
	# STAIR_FILL(02) = 받침, 비등반. 단일 02 비스킷.
	_expect_single(Vector2i(0, 1), "biscuit_stair_45_02.png", false, false)

	if _failed:
		return
	print("[DynamicStairTileVisualTest] PASS")
	get_tree().quit(0)

# 한 셀 = 단일 비스킷 Sprite2D (구 01+02 병합 폐기). region 없음, 셀 중앙(position ZERO),
# scale = cell_size/texture_width * STAIR_OVERLAP, flip_h = (dir<0). is_climbable = _stair_cells 등록 여부.
func _expect_single(cell: Vector2i, tex_suffix: String, expected_flip_h: bool, is_climbable: bool) -> void:
	var body := terrain_body(cell)
	if body == null:
		_fail("missing placed body at %s" % str(cell))
		return
	var sprites: Array[Sprite2D] = []
	for child in body.get_children():
		if child is Sprite2D:
			sprites.append(child as Sprite2D)
	if sprites.size() != 1:
		_fail("expected 1 sprite at %s, got %d" % [str(cell), sprites.size()])
		return
	var sprite: Sprite2D = sprites[0]
	if sprite.texture == null or not sprite.texture.resource_path.ends_with(tex_suffix):
		_fail("texture mismatch at %s: expected %s got %s" % [str(cell), tex_suffix, str(sprite.texture)])
		return
	if sprite.flip_h != expected_flip_h:
		_fail("flip_h mismatch at %s: got %s expected %s" % [str(cell), str(sprite.flip_h), str(expected_flip_h)])
		return
	var expected_scale: float = 48.0 / float(sprite.texture.get_width()) * Terrain.STAIR_OVERLAP
	if not sprite.scale.is_equal_approx(Vector2.ONE * expected_scale):
		_fail("scale mismatch at %s: got %s expected %s" % [str(cell), str(sprite.scale), str(expected_scale)])
		return
	if not sprite.position.is_equal_approx(Vector2.ZERO):
		_fail("position expected ZERO (centered) at %s: got %s" % [str(cell), str(sprite.position)])
		return
	# 표면(STAIR)만 등반 셀, 받침(STAIR_FILL)은 비등반.
	if terrain_node().is_stair_cell(cell) != is_climbable:
		_fail("is_stair_cell(%s) expected %s" % [str(cell), str(is_climbable)])
		return

func terrain_node() -> Terrain:
	return get_child(0) as Terrain

func terrain_body(cell: Vector2i) -> StaticBody2D:
	return terrain_node()._placed.get(cell) as StaticBody2D

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[DynamicStairTileVisualTest] FAIL %s" % msg)
	get_tree().quit(1)
