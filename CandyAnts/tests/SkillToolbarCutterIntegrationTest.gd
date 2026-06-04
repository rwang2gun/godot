extends Node

# Phase 19 — SkillToolbar UI 통합 검증 (§10 strict acceptance §6 SkillToolbar-part enforce).
# SkillToolbar.tscn instantiate + 임시 StageData inject + SkillSlot atom 확인.
#
# PASS criteria (5):
#  (1) hbox 자식 SkillSlot 1개 생성
#  (2) slot.skill_id == StringName("cutter")
#  (3) slot.icon_texture == ICONS["cutter"] (non-null)
#  (4) slot.ko_label == "식물 자르기"
#  (5) slot.hotkey == "1"

const TOOLBAR_SCENE: PackedScene = preload("res://scenes/ui/SkillToolbar.tscn")
const SkillSlotScript: Script = preload("res://scripts/ui/atoms/SkillSlot.gd")

func _ready() -> void:
	var stage_data: StageData = StageData.new()
	stage_data.id = 920
	stage_data.display_name = "cutter-toolbar-test"
	var skills_arr: Array[String] = ["cutter"]
	stage_data.available_skills = skills_arr
	stage_data.skill_inventory = {"cutter": 2}

	var toolbar: SkillToolbar = TOOLBAR_SCENE.instantiate() as SkillToolbar
	toolbar.stage_data = stage_data
	add_child(toolbar)
	# SkillToolbar._ready → SkillSlot instantiate → tree에 add_child.
	await get_tree().process_frame
	await get_tree().process_frame

	var hbox: Node = toolbar.get_node_or_null(toolbar.hbox_path)
	if hbox == null:
		_fail("hbox_path 노드 없음 (toolbar.hbox_path=%s)" % toolbar.hbox_path)
		return
	var slots: Array = []
	for c in hbox.get_children():
		if c.get_script() == SkillSlotScript:
			slots.append(c)
	# (1) slot 1개.
	if slots.size() != 1:
		_fail("(1) SkillSlot 개수 != 1 (got=%d)" % slots.size())
		return
	var slot: Node = slots[0]
	# (2) skill_id.
	if slot.skill_id != StringName("cutter"):
		_fail("(2) slot.skill_id != 'cutter' (got=%s)" % str(slot.skill_id))
		return
	# (3) icon_texture.
	var expected_icon: Texture2D = SkillToolbar.ICONS.get("cutter") as Texture2D
	if expected_icon == null:
		_fail("(3a) SkillToolbar.ICONS['cutter'] == null (preload 실패)")
		return
	if slot.icon_texture != expected_icon:
		_fail("(3b) slot.icon_texture != ICONS['cutter']")
		return
	# (4) ko_label.
	if slot.ko_label != "식물 자르기":
		_fail("(4) slot.ko_label != '식물 자르기' (got=%s)" % slot.ko_label)
		return
	# (5) hotkey.
	if slot.hotkey != "1":
		_fail("(5) slot.hotkey != '1' (got=%s)" % slot.hotkey)
		return

	print("[SkillToolbarCutterIntegrationTest] PASS")
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("[SkillToolbarCutterIntegrationTest] FAIL: " + reason)
	get_tree().quit(1)
