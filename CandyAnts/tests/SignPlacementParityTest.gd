extends Node

# Phase 2 — SignPlacement 추출 회귀 가드. 기존 _ground_cell_for_sign/_leaf_jump_pad_exists 규칙
# (점유 거부·아래 스냅·중복 거부·world/cell 입력 동치)을 단언해 추출이 동작을 바꾸지 않음 보장.

const LeafJumpPadScript := preload("res://scripts/world/LeafJumpPad.gd")

func _ready() -> void:
	var failures: Array[String] = []
	var cs := 48

	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.set_cell_size(cs)
	world.add_child(terrain)
	for x in range(0, 4):
		terrain.register_static_cell(Vector2i(x, 10))   # 지면 row y=10, x0..3
	terrain.register_static_cell(Vector2i(1, 9))         # 점유 셀(클릭 거부 테스트용)

	# 1) 점유 클릭 셀 → invalid (no_ground)
	var r1: Dictionary = SignPlacement.resolve_surface_install_cell(terrain, "basher", Vector2i(1, 9))
	if r1.get("valid", true):
		failures.append("occupied click cell should be invalid")
	if r1.get("reason", "") != "no_ground":
		failures.append("occupied reason != no_ground (%s)" % r1.get("reason", ""))

	# 2) 위에서 클릭 → 아래 지면 위로 스냅 (2,7) → (2,9)
	var r2: Dictionary = SignPlacement.resolve_surface_install_cell(terrain, "basher", Vector2i(2, 7))
	if not r2.get("valid", false):
		failures.append("snap-down should be valid")
	if r2.get("cell") != Vector2i(2, 9):
		failures.append("snap cell != (2,9) got %s" % str(r2.get("cell")))

	# 3) 지면 없는 열 → invalid (cliff)
	var r3: Dictionary = SignPlacement.resolve_surface_install_cell(terrain, "basher", Vector2i(20, 5))
	if r3.get("valid", true):
		failures.append("no-ground column should be invalid")

	# 4) world 좌표 입력 = cell 입력 동치 (parity)
	var rw: Dictionary = SignPlacement.resolve_surface_install_cell(terrain, "basher", Vector2(2.0 * cs + 10, 7.0 * cs + 5))
	if rw.get("cell") != r2.get("cell") or rw.get("valid") != r2.get("valid"):
		failures.append("world-input != cell-input parity")

	# 5) leaf_jump 중복 pad 거부 / basher는 같은 셀 허용(pad 무시)
	var pad: LeafJumpPad = LeafJumpPadScript.new()
	pad.setup(Vector2i(2, 9), terrain)
	world.add_child(pad)
	var r5: Dictionary = SignPlacement.resolve_surface_install_cell(terrain, "leaf_jump", Vector2i(2, 7), world)
	if r5.get("valid", true):
		failures.append("leaf_jump on existing pad cell should be invalid")
	if r5.get("reason", "") != "pad_exists":
		failures.append("dup reason != pad_exists (%s)" % r5.get("reason", ""))
	var r6: Dictionary = SignPlacement.resolve_surface_install_cell(terrain, "basher", Vector2i(2, 7), world)
	if not r6.get("valid", false):
		failures.append("basher should ignore existing pad (valid)")

	# 6) null terrain → invalid (no_terrain)
	var r7: Dictionary = SignPlacement.resolve_surface_install_cell(null, "basher", Vector2i(0, 0))
	if r7.get("valid", true) or r7.get("reason", "") != "no_terrain":
		failures.append("null terrain should be no_terrain invalid")

	_finish("SignPlacementParityTest", failures)

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
