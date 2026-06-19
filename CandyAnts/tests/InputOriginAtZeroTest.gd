extends Node

# CRITICAL 회귀 가드 — Codex review HIGH Round 7 #1 (INPUT_PLAN §6.6 #8).
# World Ant @ global_position=(0,0) — Vector2.ZERO sentinel 오인 안 함 검증.
#
# - SkillToolbar mock(_pending_skill_id="slideR")로 SKILL_ASSIGN 흐름 검증.
# - position_valid: true + world_pos == Vector2.ZERO 인 페이로드를 직접 emit해서
#   _try_assign이 Vector2.ZERO를 sentinel로 reject 안 하고 정상 진행하는지 검증.

const GameAction := preload("res://scripts/input/GameAction.gd")
const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const STAGE_DATA_SCRIPT: GDScript = preload("res://scripts/core/StageData.gd")


func _ready() -> void:
	# Origin ant — Vector2.ZERO sentinel 오인 검증의 핵심.
	var ant: Node = ANT_SCENE.instantiate()
	ant.global_position = Vector2.ZERO
	ant.add_to_group("ants")
	add_child(ant)

	var toolbar := SkillToolbar.new()
	var stage_data: StageData = STAGE_DATA_SCRIPT.new()
	stage_data.available_skills = ["slideR"]
	stage_data.skill_inventory = {"slideR": 2}
	toolbar.stage_data = stage_data
	var hbox: Control = HBoxContainer.new()
	hbox.name = "HBox"
	toolbar.add_child(hbox)
	toolbar.hbox_path = NodePath("HBox")
	add_child(toolbar)
	await get_tree().process_frame

	toolbar._pending_skill_id = "slideR"

	# world_pos == Vector2.ZERO + position_valid:true emit:
	# 핵심 검증 = SkillToolbar가 Vector2.ZERO를 sentinel로 reject 하지 않고 _try_assign 진입.
	# 진입 후 can_apply 실패해도 pending 클리어됨 → pending=="" 으로 진입 자체 검증.
	EventBus.action_triggered.emit(GameAction.SKILL_ASSIGN, {
		"position_valid": true,
		"screen_pos": Vector2.ZERO,
		"world_pos": Vector2.ZERO,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	if toolbar._pending_skill_id != "":
		# pending이 보존됐다는 건 _find_closest_ant가 ant를 못 찾았다는 뜻 (origin ant reject = sentinel 오인)
		_fail("Vector2.ZERO sentinel-reject 의심: pending preserved=%s, _find_closest_ant likely returned null" % toolbar._pending_skill_id)
		return
	print("[InputOriginAtZeroTest] PASS")
	get_tree().quit(0)


func _fail(msg: String) -> void:
	push_error("[InputOriginAtZeroTest] FAIL %s" % msg)
	print("[InputOriginAtZeroTest] FAIL %s" % msg)
	get_tree().quit(1)
