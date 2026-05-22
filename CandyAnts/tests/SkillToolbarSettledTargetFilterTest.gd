extends Node

# Phase 15 impl Round 2 F-impl-R2-1 MEDIUM 회귀 가드.
# SkillToolbar._find_closest_ant이 SettledState(is_alive()=false) ant를 후보에서 제외하는지 검증.
# settled distributor와 live follower walker가 같은 CLICK_RADIUS에 함께 있을 때 walker가 선택되어야 함.
#
# 시나리오:
# - settled ant: position (50, 50), SettledState 강제 전이.
# - live ant: position (50, 60), Walker 유지.
# - _find_closest_ant((50, 50)) 호출 → settled 더 가까우나 is_alive=false → live ant(walker) 반환.
#
# PASS: quit(0). FAIL: quit(1).

const STAGE_DATA_SCRIPT: GDScript = preload("res://scripts/core/StageData.gd")
const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")

func _ready() -> void:
	# Toolbar (skill list 단순화)
	var stage_data: StageData = STAGE_DATA_SCRIPT.new()
	stage_data.available_skills = ["distributor"]
	stage_data.skill_inventory = {"distributor": 1}
	var toolbar := SkillToolbar.new()
	toolbar.stage_data = stage_data
	var hbox: Control = HBoxContainer.new()
	hbox.name = "HBox"
	toolbar.add_child(hbox)
	toolbar.hbox_path = NodePath("HBox")
	add_child(toolbar)

	# settled ant — position (50, 50), SettledState 강제.
	var settled_ant: Ant = ANT_SCENE.instantiate()
	settled_ant.global_position = Vector2(50, 50)
	add_child(settled_ant)
	await get_tree().physics_frame   # _ready 실행 → state_machine 초기화 대기
	if settled_ant.state_machine != null:
		settled_ant.state_machine.change_state(SettledState.new())

	# live ant — position (50, 60), Walker 유지.
	var live_ant: Ant = ANT_SCENE.instantiate()
	live_ant.global_position = Vector2(50, 60)
	add_child(live_ant)
	await get_tree().physics_frame   # _ready 실행 → WalkerState 진입

	# 한 frame 더 — state 안정.
	await get_tree().physics_frame

	# 사전 검증 — is_alive() 동작 확인.
	if settled_ant.is_alive():
		_fail("settled ant is_alive() returned true — terminal contract 위반 (F-impl-1 회귀)")
		return
	if not live_ant.is_alive():
		_fail("live walker ant is_alive() returned false — 회귀")
		return

	# 핵심 검증: _find_closest_ant((50, 50)) → settled가 더 가깝지만 is_alive=false → live_ant 반환.
	var picked: Ant = toolbar._find_closest_ant(Vector2(50, 50))
	if picked == null:
		_fail("_find_closest_ant returned null — live ant도 후보에서 제외됨 (잘못된 필터)")
		return
	if picked == settled_ant:
		_fail("_find_closest_ant picked settled ant — terminal state shadow 발생 (F-impl-R2-1 회귀)")
		return
	if picked != live_ant:
		_fail("_find_closest_ant picked unexpected ant: %s" % picked)
		return

	print("[SkillToolbarSettledTargetFilterTest] PASS — _find_closest_ant skipped settled ant, picked live walker")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SkillToolbarSettledTargetFilterTest] FAIL %s" % msg)
	get_tree().quit(1)
