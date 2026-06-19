extends Node

# Phase 11 — StageRunner direct-ref toolbar disable (codex v1 HIGH-2 회귀).
# stage_cleared emit 직후 toolbar.set_all_disabled(true) 호출 검증.
# Setup:
#   - spawner_path 비워 _spawner=null → _ready의 spawner.start skip → _spawner_finished=false 유지
#     → no_more_ants gate가 영구 false. is_cleared(0) 분기만 활성화.
#   - candy.hp 초기 10 → 첫 _process에서 is_cleared(10)=false (saved+lost+in_transit=0).
#   - candy.hp = 0 트리거 → 다음 _process에서 stage_cleared + _disable_toolbar.

const _CANDY_SCENE := preload("res://scenes/entities/Candy.tscn")
const _TOOLBAR_SCENE := preload("res://scenes/ui/SkillToolbar.tscn")

func _ready() -> void:
	var failures: Array[String] = []

	var stage_data: StageData = StageData.new()
	stage_data.id = 99
	stage_data.candy_hp = 10
	stage_data.total_ants = 0
	stage_data.release_rate_initial = 30
	stage_data.time_limit_seconds = 999.0
	stage_data.available_skills = ["slideR"]
	stage_data.skill_inventory = {"slideR": 2}

	var candy: Candy = _CANDY_SCENE.instantiate()
	candy.name = "Candy"
	candy.hp = 10
	var toolbar: SkillToolbar = _TOOLBAR_SCENE.instantiate()
	toolbar.name = "SkillToolbar"
	toolbar.stage_data = stage_data

	var runner: StageRunner = StageRunner.new()
	runner.add_child(candy)
	runner.add_child(toolbar)
	runner.stage_data = stage_data
	runner.candy_path = NodePath("Candy")
	runner.toolbar_path = NodePath("SkillToolbar")
	# spawner_path 미설정 → _spawner=null → spawner.start 미호출 → no_more_ants 영구 false
	add_child(runner)
	await get_tree().process_frame
	await get_tree().process_frame

	# 초기 상태: toolbar enabled
	var slot: SkillSlot = toolbar._slots.get("slideR") as SkillSlot
	if slot == null:
		failures.append("builder SkillSlot not created")
	elif slot.disabled:
		failures.append("initial slot should be enabled — auto-completion 의도치 않게 발화한 듯")
	elif toolbar._all_disabled:
		failures.append("initial toolbar._all_disabled should be false")

	# stage_cleared trigger via candy hp = 0
	candy.hp = 0
	# StageRunner._process가 다음 frame에 is_cleared(0)==true 분기 → stage_cleared + _disable_toolbar
	for i in 5:
		await get_tree().process_frame

	if slot != null and not slot.disabled:
		failures.append("after stage_cleared slot.disabled expected true")
	if toolbar._all_disabled != true:
		failures.append("toolbar._all_disabled expected true")
	# Visual check — atom alpha 0.55
	if slot != null:
		var main_bg: Panel = slot.get_node("MainBG")
		if main_bg != null and abs(main_bg.self_modulate.a - 0.55) > 0.01:
			failures.append("MainBG.self_modulate.a expected 0.55 got %s" % str(main_bg.self_modulate.a))

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.size() > 0:
		push_error("StageRunnerToolbarDisableTest FAIL — %d" % failures.size())
		for f in failures: print("  ", f)
		get_tree().quit(1)
	else:
		print("[StageRunnerToolbarDisableTest] PASS")
		get_tree().quit(0)
