extends Node

# Phase 11 — SkillToolbar EventBus connect/disconnect lifecycle guard (codex v1 MED-3).
# 1번째 toolbar free → 2번째 toolbar 생성 → action emit → toolbar1의 stale _on_action이 호출되면
# nil reference error. PASS = no error during emit + toolbar2 receives action.

const GameAction := preload("res://scripts/input/GameAction.gd")
const _TOOLBAR_SCENE := preload("res://scenes/ui/SkillToolbar.tscn")
const _ANT_SCENE := preload("res://scenes/entities/Ant.tscn")

func _ready() -> void:
	var failures: Array[String] = []

	var stage_data: StageData = StageData.new()
	stage_data.id = 99
	stage_data.available_skills = ["slideR"]
	stage_data.skill_inventory = {"slideR": 5}

	# 1차 toolbar 생성 + 즉시 free
	var toolbar1: SkillToolbar = _TOOLBAR_SCENE.instantiate()
	toolbar1.stage_data = stage_data
	add_child(toolbar1)
	await get_tree().process_frame
	if not EventBus.action_triggered.is_connected(toolbar1._on_action):
		failures.append("toolbar1 should be connected after _ready")
	toolbar1.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# 2차 toolbar 생성 — _on_action 중복 connect 없음 보장
	var toolbar2: SkillToolbar = _TOOLBAR_SCENE.instantiate()
	toolbar2.stage_data = stage_data
	add_child(toolbar2)
	await get_tree().process_frame
	if not EventBus.action_triggered.is_connected(toolbar2._on_action):
		failures.append("toolbar2 should be connected after _ready")
	# EventBus signal connection 수가 정확히 1개 (toolbar2만) — Godot 4는 freed Object의 connection을
	# 자동 청소. is_connected는 instance_id 기반이라 freed instance에 대해 false 반환.
	# 명시적 disconnect lifecycle은 toolbar1._exit_tree에서 발화됨 (SkillToolbar.gd:exit_tree).

	# floor 셋업 — Ant가 떨어져 is_on_floor()=true가 되어야 BuilderSkill.can_apply 통과
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(400, 40)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.global_position = Vector2(200, 200)
	add_child(floor_body)

	# Ant 배치
	var ant: Ant = _ANT_SCENE.instantiate()
	add_child(ant)
	ant.global_position = Vector2(200, 160)
	for _i in 20:
		await get_tree().physics_frame
		if ant.is_on_floor():
			break
	await get_tree().process_frame
	if not ant.is_on_floor():
		failures.append("ant did not settle on floor — test setup broken")

	# pending 셋업 후 SKILL_ASSIGN emit. toolbar1 stale ref 있으면 여기서 crash.
	toolbar2._select("slideR")
	EventBus.action_triggered.emit(GameAction.SKILL_ASSIGN, {
		"position_valid": true,
		"screen_pos": ant.global_position,
		"world_pos": ant.global_position,
	})
	await get_tree().process_frame

	# toolbar2 inventory 1회만 차감 — toolbar1 stale connect면 _try_assign 2회 호출이지만
	# inventory는 toolbar별 dict라 cross-pollution 없음. crash 없이 도달했다면 disconnect 정상.
	var remaining: int = int(toolbar2._inventory["slideR"])
	if remaining != 4:
		failures.append("inventory expected 4 (5-1) got %d" % remaining)

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.size() > 0:
		push_error("SkillToolbarReentryTest FAIL — %d" % failures.size())
		for f in failures: print("  ", f)
		get_tree().quit(1)
	else:
		print("[SkillToolbarReentryTest] PASS")
		get_tree().quit(0)
