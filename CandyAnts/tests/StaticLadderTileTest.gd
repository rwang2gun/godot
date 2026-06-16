extends Node

# 정적 막대과자 사다리 타일(StageLayoutBuilder TILE_SAND_MOUND) 등록 계약 검증.
# 스킬(SandMoundSkill) 없이 레이아웃에 직접 까는 사다리가, 동적 rung과 동일하게 Terrain에
# 등록되는지 단언한다. 등반(LadderClimbState)은 is_ladder_cell 단일 게이트 위에서 동작하므로
# (LadderFollowerClimbTest / LadderClimbMotionTest 등이 커버), 여기서는 그 게이트를 켜는 등록
# 계약과 basher/digger 파괴 시 해제를 검증한다.
#
# PASS:
#  (1) sand_mound 셀 = is_ladder_cell=true / is_cell_occupied=true / kind="earth" / LadderVisual=middle 텍스처
#  (2) 일반 solid 셀 = is_ladder_cell=false (정적 벽은 사다리 아님 — climber 퍼즐 보존 불변)
#  (3) destroy_tile_at(sand_mound, ["earth"]) → true 후 is_ladder_cell=false + is_cell_occupied=false (파괴 가능)

const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")
const StageLayoutDataScript: Script = preload("res://scripts/core/StageLayoutData.gd")
const LADDER_MIDDLE_TEX: String = "res://assets/sprites/terrain/usable_square/biscuit_ladder_middle_square.png"
const LADDER_TOP_TEX: String = "res://assets/sprites/terrain/usable_square/biscuit_ladder_top_square.png"
const LADDER_ROOT_TEX: String = "res://assets/sprites/terrain/usable_square/biscuit_ladder_root_square.png"
const CS: int = 48

var _failures: Array[String] = []

func _ready() -> void:
	var tile_map: Dictionary = {}
	for x in range(10, 15):
		tile_map["%d,12" % x] = "solid"          # 바닥 row12 (col10~14)
	for y: int in [11, 10, 9]:
		tile_map["12,%d" % y] = "sand_mound"     # 사다리 기둥 col12 (바닥 위 3칸)
	for x in range(11, 14):
		tile_map["%d,8" % x] = "solid"           # 레지 row8 (col11~13) — 사다리 맨 위 칸 바로 위

	var layout: Resource = StageLayoutDataScript.new()
	layout.cell_size = CS
	layout.tile_map = tile_map

	var world: Node2D = Node2D.new()
	world.name = "World"
	add_child(world)
	var terrain: Terrain = Terrain.new()
	terrain.set_script(TerrainScript)
	terrain.name = "Terrain"
	world.add_child(terrain)
	var builder: Node2D = Node2D.new()
	builder.set_script(StageLayoutBuilderScript)
	builder.name = "StageLayoutBuilder"
	builder.set("layout", layout)
	world.add_child(builder)
	await get_tree().process_frame   # build() 발동 (_ready)

	var ladder_cell: Vector2i = Vector2i(12, 11)
	var solid_cell: Vector2i = Vector2i(10, 12)

	# (1) sand_mound 셀 = 사다리 + solid 충돌 + earth(파괴 가능) + middle 텍스처.
	_check(terrain.is_ladder_cell(ladder_cell), "sand_mound 셀 is_ladder_cell=true")
	_check(terrain.is_cell_occupied(ladder_cell), "sand_mound 셀 is_cell_occupied=true (solid 충돌)")
	_eq("sand_mound kind", terrain.get_cell_kind(ladder_cell), "earth")
	var spr: Sprite2D = terrain._cell_sprite(ladder_cell)
	if spr == null or spr.texture == null:
		_failures.append("sand_mound 셀 LadderVisual sprite/texture 없음 (import 누락 가능 → run_test.py --import)")
	else:
		_eq("sand_mound middle 텍스처", spr.texture.resource_path, LADDER_MIDDLE_TEX)

	# (1b) 사다리 기둥 위 레지 solid = top reskin / 아래 바닥 solid = root reskin (동적 사다리와 동일 시각, 시각만).
	var top_cell: Vector2i = Vector2i(12, 8)    # 사다리 맨 위(12,9) 바로 위 레지.
	var root_cell: Vector2i = Vector2i(12, 12)  # 사다리 맨 아래(12,11) 바로 아래 바닥.
	_check(not terrain.is_ladder_cell(top_cell), "top 레지는 사다리 아님 (reskin은 시각만)")
	var top_spr: Sprite2D = terrain._cell_sprite(top_cell)
	if top_spr == null or top_spr.texture == null:
		_failures.append("top 레지 sprite/texture 없음")
	else:
		_eq("사다리 위 solid = top 텍스처", top_spr.texture.resource_path, LADDER_TOP_TEX)
	var root_spr: Sprite2D = terrain._cell_sprite(root_cell)
	if root_spr == null or root_spr.texture == null:
		_failures.append("root 바닥 sprite/texture 없음")
	else:
		_eq("사다리 아래 solid = root 텍스처", root_spr.texture.resource_path, LADDER_ROOT_TEX)

	# (2) 일반 solid 셀은 사다리가 아니다 (정적 벽 제외 불변 — S1 climber 퍼즐 보존).
	_check(not terrain.is_ladder_cell(solid_cell), "solid 셀 is_ladder_cell=false")
	_check(terrain.is_cell_occupied(solid_cell), "solid 셀 is_cell_occupied=true")

	# (3) 파괴 가능 — basher/digger의 destroy_tile_at(["earth"])로 사다리 해제. 파괴 후 사다리 셀 소멸
	#     → LadderClimbState 매-frame 지지검사 실패 → 등반 중 개미는 FallerState 낙하(동적 rung과 동일).
	_check(terrain.destroy_tile_at(ladder_cell, ["earth"]), "sand_mound destroy_tile_at(earth)=true (파괴 가능)")
	_check(not terrain.is_ladder_cell(ladder_cell), "파괴 후 is_ladder_cell=false")
	_check(not terrain.is_cell_occupied(ladder_cell), "파괴 후 is_cell_occupied=false")

	if _failures.is_empty():
		print("PASS StaticLadderTileTest")
		get_tree().quit(0)
	else:
		print("FAIL StaticLadderTileTest")
		for f: String in _failures:
			print("  - ", f)
		get_tree().quit(1)

func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)

func _eq(label: String, got: Variant, want: Variant) -> void:
	if got != want:
		_failures.append("%s: got=%s want=%s" % [label, str(got), str(want)])
