extends Node

# CRITICAL 회귀 가드 — Codex review HIGH Round 9 #1 (INPUT_PLAN §6.6 #10).
# position_valid:false 페이로드 emit 시 SkillToolbar가 noop인지 검증.

const GameAction := preload("res://scripts/input/GameAction.gd")
const STAGE_DATA_SCRIPT: GDScript = preload("res://scripts/core/StageData.gd")
const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")


func _ready() -> void:
	# stage_data + toolbar mock
	var stage_data: StageData = STAGE_DATA_SCRIPT.new()
	stage_data.available_skills = ["slideR"]
	stage_data.skill_inventory = {"slideR": 2}
	var toolbar := SkillToolbar.new()
	toolbar.stage_data = stage_data
	var hbox: Control = HBoxContainer.new()
	hbox.name = "HBox"
	toolbar.add_child(hbox)
	toolbar.hbox_path = NodePath("HBox")
	add_child(toolbar)

	# Ant near origin (so _find_closest_ant would find it for the second test)
	var ant: Node = ANT_SCENE.instantiate()
	ant.global_position = Vector2(50, 50)
	ant.add_to_group("ants")
	add_child(ant)
	await get_tree().process_frame

	toolbar._pending_skill_id = "slideR"

	# 1. position_valid:false → noop (인벤토리 + pending 보존)
	EventBus.action_triggered.emit(GameAction.SKILL_ASSIGN, {"position_valid": false})
	await get_tree().process_frame
	if int(toolbar._inventory.get("slideR", -1)) != 2:
		_fail("position_valid:false: inventory consumed unexpectedly (%d != 2)" % int(toolbar._inventory.get("slideR", -1)))
		return
	if toolbar._pending_skill_id != "slideR":
		_fail("position_valid:false: pending cleared unexpectedly: %s" % toolbar._pending_skill_id)
		return

	# 2. position_valid:true + world_pos near ant → _try_assign 진입 → pending 클리어 (성공/can_apply실패 모두)
	# (실제 인벤토리 차감은 BuilderSkill.can_apply가 통과해야 하는데 헤드리스 ant는 보통 not on_floor →
	#  본 테스트의 핵심은 'position_valid:false 일 때 _try_assign 진입 차단' 가드. 진입 자체는 pending 클리어로 검증.)
	EventBus.action_triggered.emit(GameAction.SKILL_ASSIGN, {
		"position_valid": true,
		"screen_pos": Vector2(50, 50),
		"world_pos": Vector2(50, 50),
	})
	await get_tree().process_frame
	if toolbar._pending_skill_id != "":
		_fail("position_valid:true: pending not cleared (entry blocked unexpectedly): %s" % toolbar._pending_skill_id)
		return
	print("[SkillToolbarPositionGuardTest] PASS")
	get_tree().quit(0)


func _fail(msg: String) -> void:
	push_error("[SkillToolbarPositionGuardTest] FAIL %s" % msg)
	print("[SkillToolbarPositionGuardTest] FAIL %s" % msg)
	get_tree().quit(1)
