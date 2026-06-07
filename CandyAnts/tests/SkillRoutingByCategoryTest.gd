extends Node

# Phase 3 — 라우팅이 카테고리 SoT 파생인지 기능 검증(기존 동작 동치).
# SIGN(basher)→표지판 설치 경로 / DEVICE(leaf_jump)→점프대 경로 / ANT(climber)→개미탭 경로.
# 실제 SkillToolbar._try_assign을 호출해 산출물(SkillSign/LeafJumpPad/trait)을 단언.

const AntScene := preload("res://scenes/entities/Ant.tscn")
const SkillSignScript := preload("res://scripts/world/SkillSign.gd")
const LeafJumpPadScript := preload("res://scripts/world/LeafJumpPad.gd")

func _ready() -> void:
	var failures: Array[String] = []
	var cs := 48

	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.set_cell_size(cs)
	world.add_child(terrain)
	for x in range(0, 10):
		terrain.register_static_cell(Vector2i(x, 10))   # 지면 row y=10

	# 실 toolbar (stage_data + hbox) — 슬롯/인벤토리 구성.
	var sd := StageData.new()
	sd.available_skills = ["climber", "basher", "leaf_jump"]
	sd.skill_inventory = {"climber": 1, "basher": 1, "leaf_jump": 1}
	var tb := SkillToolbar.new()
	var hbox := HBoxContainer.new()
	hbox.name = "SkillHBox"
	tb.add_child(hbox)
	tb.hbox_path = NodePath("SkillHBox")
	tb.stage_data = sd
	add_child(tb)
	await get_tree().process_frame

	# --- SIGN (basher) → 표지판 설치 경로 ---
	tb._pending_skill_id = "basher"
	tb._try_assign(Vector2(3 * cs + 24, 8 * cs + 24))   # col3 → 설치 (3,9)
	await get_tree().process_frame
	if _count_children(world, "SkillSign") != 1:
		failures.append("basher(SIGN) routing did not place a SkillSign")
	if int(tb._inventory.get("basher", -1)) != 0:
		failures.append("basher inventory not decremented (%s)" % str(tb._inventory.get("basher")))

	# --- DEVICE (leaf_jump) → 점프대 경로 ---
	tb._pending_skill_id = "leaf_jump"
	tb._try_assign(Vector2(6 * cs + 24, 8 * cs + 24))   # col6 → 설치 (6,9)
	await get_tree().process_frame
	if _count_children(world, "LeafJumpPad") != 1:
		failures.append("leaf_jump(DEVICE) routing did not place a LeafJumpPad")
	if int(tb._inventory.get("leaf_jump", -1)) != 0:
		failures.append("leaf_jump inventory not decremented")

	# --- ANT (climber) → 개미탭 경로 ---
	var ant: Ant = AntScene.instantiate()
	add_child(ant)
	ant.set_physics_process(false)
	ant.global_position = Vector2(2 * cs + 24, 9 * cs)
	if ant.state_machine != null:
		ant.state_machine.change_state(WalkerState.new())
	await get_tree().process_frame
	tb._pending_skill_id = "climber"
	tb._try_assign(ant.tap_target_position())
	await get_tree().process_frame
	if not ant.has_trait(&"climber"):
		failures.append("climber(ANT) routing did not apply climber trait to ant")
	if int(tb._inventory.get("climber", -1)) != 0:
		failures.append("climber inventory not decremented")

	if failures.size() > 0:
		push_error("SkillRoutingByCategoryTest FAIL: " + str(failures))
		print("[SkillRoutingByCategoryTest] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[SkillRoutingByCategoryTest] PASS")
		get_tree().quit(0)

func _count_children(parent: Node, type_name: String) -> int:
	var n := 0
	for c in parent.get_children():
		if (type_name == "SkillSign" and c is SkillSign) or (type_name == "LeafJumpPad" and c is LeafJumpPad):
			n += 1
	return n
