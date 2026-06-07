extends Node

# Phase 2 — SURFACE 카테고리(①④) 글로우. basher/leaf_jump 선택 시 SignPlacement가 valid한
# surface 셀만 글로우(점유/허공 열 제외·아래 스냅·leaf_jump 중복 pad 제외), 개미 무글로우.

const LeafJumpPadScript := preload("res://scripts/world/LeafJumpPad.gd")

func _ready() -> void:
	var failures: Array[String] = []
	var cs := 48

	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.set_cell_size(cs)
	world.add_child(terrain)
	# 지면 row y=10, x=0..5
	for x in range(0, 6):
		terrain.register_static_cell(Vector2i(x, 10))

	var tb := SkillToolbar.new()
	add_child(tb)
	var ctrl := AffordanceGlowController.new()
	add_child(ctrl)
	ctrl.set_process(false)
	ctrl._toolbar = tb
	ctrl._terrain = terrain

	# ① SIGN basher: 커서 col3(허공) → 아래 지면 위 (3,9)로 스냅·글로우
	tb._pending_skill_id = "basher"
	ctrl.refresh(Vector2(3 * cs + 24, 8 * cs + 24))
	await get_tree().process_frame
	if ctrl._surface_marker == null or not ctrl._surface_marker.visible:
		failures.append("basher: surface marker not visible over valid column")
	else:
		var expected := Vector2(3.0 * cs + cs / 2.0, 9.0 * cs + cs / 2.0)
		if not ctrl._surface_marker.position.is_equal_approx(expected):
			failures.append("basher: marker pos %s != expected %s" % [ctrl._surface_marker.position, expected])
		if not ctrl._surface_marker.has_meta(Glow.META_KEY):
			failures.append("basher: surface marker has no glow material")
	if ctrl._glowing_ants.size() != 0:
		failures.append("basher (SURFACE): no ant should glow")

	# 허공 열(col12, 아래 지면 없음) → 무글로우
	ctrl.refresh(Vector2(12 * cs + 24, 8 * cs + 24))
	await get_tree().process_frame
	if ctrl._surface_marker != null and ctrl._surface_marker.visible:
		failures.append("basher: marker should hide over no-ground column")

	# ④ DEVICE leaf_jump: 같은 셀에 pad 있으면 제외
	var pad: LeafJumpPad = LeafJumpPadScript.new()
	pad.setup(Vector2i(2, 9), terrain)
	world.add_child(pad)
	tb._pending_skill_id = "leaf_jump"
	ctrl.refresh(Vector2(2 * cs + 24, 8 * cs + 24))   # snaps to (2,9) = pad cell
	await get_tree().process_frame
	if ctrl._surface_marker != null and ctrl._surface_marker.visible:
		failures.append("leaf_jump: marker should hide on cell with existing pad")

	# leaf_jump 빈 valid 셀(4,9) → 글로우
	ctrl.refresh(Vector2(4 * cs + 24, 8 * cs + 24))
	await get_tree().process_frame
	if ctrl._surface_marker == null or not ctrl._surface_marker.visible:
		failures.append("leaf_jump: marker should show on empty valid cell")

	_finish("TapTargetGlowSurfaceTest", failures)

func _finish(test_name: String, failures: Array) -> void:
	if failures.size() > 0:
		push_error(test_name + " FAIL: " + str(failures))
		print("[%s] FAIL" % test_name)
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[%s] PASS" % test_name)
		get_tree().quit(0)
