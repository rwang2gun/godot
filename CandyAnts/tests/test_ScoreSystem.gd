extends Node

# Phase 5 sweep — ScoreSystem.stop()이 EventBus signal을 disconnect하여 reload 시
# 카운트 중복을 방지하는지 검증. Phase 6 진입 전 prerequisite (GAME_FLOW_PROPOSAL_V5 §3.1).
# headless: scripts/run_test.py tests/test_ScoreSystem.tscn

func _ready() -> void:
	var failures: Array[String] = []
	failures.append_array(_test_stop_disconnects())
	failures.append_array(_test_reload_no_double_count())
	failures.append_array(_test_stop_idempotent())

	if failures.is_empty():
		print("[ScoreSystemTest] PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			print("[ScoreSystemTest] FAIL ", f)
		get_tree().quit(1)

func _test_stop_disconnects() -> Array[String]:
	var fails: Array[String] = []
	var ss: ScoreSystem = ScoreSystem.new()
	ss.start(5)
	EventBus.candy_piece_picked.emit(4)
	if ss.in_transit_pieces != 1:
		fails.append("after start+picked, in_transit expected 1 got %d" % ss.in_transit_pieces)
	ss.stop()
	EventBus.candy_piece_picked.emit(3)
	if ss.in_transit_pieces != 1:
		fails.append("after stop+picked, in_transit expected 1 (no change) got %d" % ss.in_transit_pieces)
	return fails

func _test_reload_no_double_count() -> Array[String]:
	var fails: Array[String] = []
	var first: ScoreSystem = ScoreSystem.new()
	first.start(5)
	first.stop()  # 이전 stage 종료
	var second: ScoreSystem = ScoreSystem.new()
	second.start(5)
	EventBus.candy_piece_picked.emit(4)
	if second.in_transit_pieces != 1:
		fails.append("reload: second.in_transit expected 1 got %d" % second.in_transit_pieces)
	if first.in_transit_pieces != 0:
		fails.append("reload: first.in_transit must stay 0 after stop, got %d" % first.in_transit_pieces)
	second.stop()
	return fails

func _test_stop_idempotent() -> Array[String]:
	var fails: Array[String] = []
	var ss: ScoreSystem = ScoreSystem.new()
	ss.start(3)
	ss.stop()
	# 두 번째 stop은 이미 disconnect된 signal에서 disconnect 시도 안 해야 함 (no error).
	ss.stop()
	# start → stop → start 다시 — 중복 connect 없이 동작
	ss.start(3)
	EventBus.candy_piece_picked.emit(2)
	if ss.in_transit_pieces != 1:
		fails.append("re-start after stop: in_transit expected 1 got %d" % ss.in_transit_pieces)
	ss.stop()
	return fails
