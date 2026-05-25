extends Node

# Phase 19 — phase 1~18 전수 layout backward-compat 검증 (v3.1.1 R3-M1/R4-M1 fix).
# data/stage_layouts/*.tres 런타임 스캔만 SoT. hand-maintained static enumeration 금지.
# phase 19 신규 plant fixture 4종만 명시 exclude.
#
# PASS criteria:
#  (1) 스캔된 layout 1개 이상 (empty scan = FAIL)
#  (2) 각 layout build 성공 (_static_occupancy.size() > 0)
#  (3) 각 layout의 모든 generated cell kind == "earth" (plant 0건 across all)
#  (4) 각 layout의 cell 카운트 = layout.tile_map.size()

const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")

const LAYOUTS_DIR: String = "res://data/stage_layouts"
const PHASE_19_PLANT_FIXTURES: Array[String] = [
	"dev_cutter_vine_layout.tres",
	"dev_cutter_edge_stop_layout.tres",
	"dev_earth_plant_separation_layout.tres",
	"dev_cutter_over_hazard_layout.tres",
]

func _ready() -> void:
	var dir: DirAccess = DirAccess.open(LAYOUTS_DIR)
	if dir == null:
		_fail("DirAccess.open(%s) == null" % LAYOUTS_DIR)
		return
	var paths: Array[String] = []
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres") and not PHASE_19_PLANT_FIXTURES.has(fname):
			paths.append("%s/%s" % [LAYOUTS_DIR, fname])
		fname = dir.get_next()
	dir.list_dir_end()
	if paths.size() == 0:
		_fail("scan 결과 0건 — exclude 후 빈 (empty scan FAIL)")
		return
	print("[StageLayoutBuilderEarthBackwardCompatTest] scanned %d layouts (excluded %d phase 19 plant fixtures)" % [
		paths.size(), PHASE_19_PLANT_FIXTURES.size()
	])

	for path in paths:
		var layout: Resource = load(path)
		if layout == null:
			_fail("load(%s) == null" % path)
			return
		if not (layout is StageLayoutData):
			_fail("layout type mismatch — %s is not StageLayoutData" % path)
			return
		var sld: StageLayoutData = layout as StageLayoutData
		var expected_count: int = sld.tile_map.size()
		# 매 layout마다 fresh Terrain + Builder + 일회성 World.
		var world: Node2D = Node2D.new()
		world.name = "World_%s" % path.get_file()
		add_child(world)
		var terrain: Terrain = Terrain.new()
		terrain.set_script(TerrainScript)
		terrain.name = "Terrain"
		world.add_child(terrain)
		var builder: Node2D = Node2D.new()
		builder.set_script(StageLayoutBuilderScript)
		builder.name = "StageLayoutBuilder"
		builder.set("layout", sld)
		world.add_child(builder)
		await get_tree().process_frame
		# (2) build 성공 — _static_occupancy.size() > 0 (tile_map empty면 expected_count=0이므로 skip).
		var occ: Dictionary = terrain._static_occupancy
		if expected_count > 0 and occ.size() == 0:
			_fail("%s build 실패 — _static_occupancy 비어있음 (expected=%d)" % [path, expected_count])
			return
		# (4) cell 카운트 일치.
		if occ.size() != expected_count:
			_fail("%s cell 카운트 불일치 — occ=%d expected=%d" % [path, occ.size(), expected_count])
			return
		# (3) 모든 cell kind == "earth".
		for c in occ.keys():
			var cell: Vector2i = c as Vector2i
			var kind: String = terrain.get_cell_kind(cell)
			if kind != "earth":
				_fail("%s cell %s kind != 'earth' (got=%s) — plant 회귀 검출" % [path, str(cell), kind])
				return
		world.queue_free()
		await get_tree().process_frame
	print("[StageLayoutBuilderEarthBackwardCompatTest] PASS — %d layouts all-earth" % paths.size())
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("[StageLayoutBuilderEarthBackwardCompatTest] FAIL: " + reason)
	get_tree().quit(1)
