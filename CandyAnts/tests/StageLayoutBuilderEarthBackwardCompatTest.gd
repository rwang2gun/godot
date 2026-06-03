extends Node

# Phase 19 — phase 1~18 전수 layout backward-compat 검증 (v3.1.1 R3-M1/R4-M1 fix).
# data/stage_layouts/*.tres 런타임 스캔만 SoT. hand-maintained static enumeration 금지.
# phase 19 신규 plant fixture 4종만 명시 exclude.
#
# PASS criteria:
#  (1) 스캔된 layout 1개 이상 (empty scan = FAIL)
#  (2) 각 layout build 성공 (_static_occupancy.size() > 0)
#  (3) 각 layout의 모든 generated cell kind ∈ {"earth", "cookie"} (plant 0건 across all).
#      S6 "땅굴"이 불괴 cookie(kind="cookie") 타일을 도입 → earth와 함께 허용. plant는 여전히 금지
#      (plant는 dev_cutter_* fixture 전용, 아래 PHASE_19_PLANT_FIXTURES exclude).
#  (4) 각 layout의 occupancy cell 카운트 = 충돌 타일 수 (solid/slope/plant/cookie).
#      3-tier 도입(commit a4cc9d7) 후 surface/background는 visual-only로 occupancy에
#      등록되지 않으므로 tile_map.size()가 아니라 _is_collision_tile 집합만 센다.

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
		# 충돌 타일(StaticBody2D 생성 → occupancy 등록)만 카운트.
		# StageLayoutBuilder._is_collision_tile 집합과 동일하게 유지.
		var expected_count: int = 0
		for v in sld.tile_map.values():
			var t: String = str(v)
			if t == "solid" or t == "slope_right" or t == "slope_left" or t == "plant" or t == "cookie":
				expected_count += 1
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
			if kind != "earth" and kind != "cookie":
				_fail("%s cell %s kind not in {earth,cookie} (got=%s) — plant 회귀 검출" % [path, str(cell), kind])
				return
		world.queue_free()
		await get_tree().process_frame
	print("[StageLayoutBuilderEarthBackwardCompatTest] PASS — %d layouts all-earth" % paths.size())
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("[StageLayoutBuilderEarthBackwardCompatTest] FAIL: " + reason)
	get_tree().quit(1)
