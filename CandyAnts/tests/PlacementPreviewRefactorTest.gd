extends Node

# Phase 3 — PlacementPreview 카테고리 파생 재작성 검증.
# ③(bridge/builder/climber) 탭-타임 ghost 없음 + ②(blocker) 없음 + ①SIGN(sand_mound/basher/digger/cutter)
# deferred라 결과 ghost 없음(설치셀≠빌드셀 가능, codex R1 MEDIUM) + ④leaf_jump pad ghost 1칸(결정적 설치).

func _ready() -> void:
	var failures: Array[String] = []
	var cs := 48

	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.set_cell_size(cs)
	world.add_child(terrain)
	for x in range(0, 6):
		terrain.register_static_cell(Vector2i(x, 10))   # 지면 row y=10, x0..5

	var pp := PlacementPreview.new()
	add_child(pp)
	pp.set_process(false)
	pp._terrain = terrain

	var cursor := Vector2(3 * cs + 24, 8 * cs + 24)   # col3, 허공 → 설치 셀 (3,9)

	# ③ 무장 — 탭-타임 ghost 없음
	for sid in ["bridge", "builder", "climber"]:
		if not pp._preview_cells(sid, cursor).is_empty():
			failures.append("%s(③) should have NO tap-time ghost" % sid)

	# ② 정착 — 현재 ghost 없음(아트 Phase 7)
	if not pp._preview_cells("blocker", cursor).is_empty():
		failures.append("blocker(②) should have no ghost yet (Phase 7 art)")

	# ① SIGN — deferred(설치셀≠빌드셀 가능)라 결과 ghost 없음(sand_mound 포함, codex R1 MEDIUM)
	for sid in ["sand_mound", "basher", "digger", "cutter"]:
		if not pp._preview_cells(sid, cursor).is_empty():
			failures.append("%s(①SIGN deferred) should have no result ghost" % sid)

	# ④ leaf_jump — 설치 셀에 pad ghost 1칸(장치는 결정적 설치=빌드 셀 일치)
	var lj: Array = pp._preview_cells("leaf_jump", cursor)
	if lj.size() != 1 or lj[0] != Vector2i(3, 9):
		failures.append("leaf_jump should show 1 pad ghost at install cell (3,9), got %s" % str(lj))

	# 허공(지면 없음) 커서 → leaf_jump도 빈 배열
	var empty_cursor := Vector2(12 * cs + 24, 8 * cs + 24)
	if not pp._preview_cells("leaf_jump", empty_cursor).is_empty():
		failures.append("leaf_jump over no-ground column should be empty")

	if failures.size() > 0:
		push_error("PlacementPreviewRefactorTest FAIL: " + str(failures))
		print("[PlacementPreviewRefactorTest] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[PlacementPreviewRefactorTest] PASS")
		get_tree().quit(0)
