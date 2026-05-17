extends Node

# Phase 11 — StageRunner._on_action 소비자 + NEW-M1 pause guard (plan v2 §5.3).
# pause guard는 runner.get_tree().paused를 본다 → runner를 tree에 attach 필요.
# 다만 attach 후 _process가 즉시 stage_failed(no_more_ants) 분기로 _completed=true 만들어버리므로
# assertion phase에서는 `await get_tree().process_frame`을 호출하지 않음 (process 미진입 보장).

const GameAction := preload("res://scripts/input/GameAction.gd")

func _ready() -> void:
	var failures: Array[String] = []

	# Spawner 셋업
	var spawner: AntSpawner = AntSpawner.new()
	add_child(spawner)
	await get_tree().process_frame
	spawner.set_release_rate(30)
	if spawner.release_rate != 30:
		failures.append("initial release_rate expected 30 got %d" % spawner.release_rate)

	# Runner 셋업 — _spawner 직접 set, spawner_path 비워두기 (= _ready의 _spawner 재할당 skip)
	var runner: StageRunner = StageRunner.new()
	add_child(runner)
	# add_child 직후 _ready는 동기 실행됨. 그 뒤 _process는 다음 idle frame에야 fire.
	# 본 시점에서 await 없이 _on_action을 호출 → _process 미진입 → _completed=false 유지.
	runner._spawner = spawner
	runner._completed = false

	# RELEASE_RATE_UP → +5
	runner._on_action(GameAction.RELEASE_RATE_UP, {})
	if spawner.release_rate != 35:
		failures.append("after UP expected 35 got %d" % spawner.release_rate)

	# RELEASE_RATE_DOWN → -5
	runner._on_action(GameAction.RELEASE_RATE_DOWN, {})
	if spawner.release_rate != 30:
		failures.append("after DOWN expected 30 got %d" % spawner.release_rate)

	# pause 중 입력 차단 (NEW-M1)
	get_tree().paused = true
	runner._on_action(GameAction.RELEASE_RATE_UP, {})
	if spawner.release_rate != 30:
		failures.append("paused UP should be blocked, got %d" % spawner.release_rate)
	get_tree().paused = false

	# unpause 후 다시 정상
	runner._on_action(GameAction.RELEASE_RATE_UP, {})
	if spawner.release_rate != 35:
		failures.append("after unpause UP expected 35 got %d" % spawner.release_rate)

	# 경계: 99 clamp
	for i in 20:
		runner._on_action(GameAction.RELEASE_RATE_UP, {})
	if spawner.release_rate != 99:
		failures.append("max clamp expected 99 got %d" % spawner.release_rate)

	# _completed=true 시 차단
	runner._completed = true
	spawner.set_release_rate(50)
	runner._on_action(GameAction.RELEASE_RATE_UP, {})
	if spawner.release_rate != 50:
		failures.append("completed UP should be blocked, got %d" % spawner.release_rate)

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	get_tree().paused = false
	if failures.size() > 0:
		push_error("StageRunnerReleaseRateActionTest FAIL — %d" % failures.size())
		for f in failures: print("  ", f)
		get_tree().quit(1)
	else:
		print("[StageRunnerReleaseRateActionTest] PASS")
		get_tree().quit(0)
