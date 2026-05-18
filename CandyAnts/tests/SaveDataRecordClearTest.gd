extends Node

# Phase 13 — plan §3.4 strict contract (Δ2/Δ12).
# stage_cleared → record_clear / stage_failed → record_attempt.

const TEST_PATH := "user://test_savedata_recordclear.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	await _case_a_clear_emit()
	if _failed: return
	await _case_b_failed_emit()
	if _failed: return
	await _case_c_repeat_clear_monotonic()
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataRecordClearTest] PASS")
	get_tree().quit(0)

func _case_a_clear_emit() -> void:
	# (a) stage_cleared emit → record_clear, stars/best 갱신
	var result := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
	EventBus.stage_cleared.emit(result)
	await get_tree().process_frame
	var s1: Dictionary = SaveData.stage_progress.get(1, {})
	if not s1.get("cleared", false):
		return _fail("case A: stage1.cleared not true")
	if int(s1.get("best_saved", 0)) != 8:
		return _fail("case A: best_saved expected 8, got %s" % str(s1.get("best_saved")))
	if int(s1.get("stars", 0)) != 2:    # 0.8 >= 0.5 + 0.8, < 0.95
		return _fail("case A: stars expected 2, got %s" % str(s1.get("stars")))
	if int(s1.get("attempts", 0)) != 1:
		return _fail("case A: attempts expected 1, got %s" % str(s1.get("attempts")))
	if SaveData.last_played_stage != 1:
		return _fail("case A: last_played_stage expected 1")
	print("[SaveDataRecordClearTest] case A PASS (stage_cleared → record_clear)")

func _case_b_failed_emit() -> void:
	# (b) Δ12: stage_failed emit → record_attempt만. cleared 토글 안 함.
	var fail_result := {"stage_id": 2, "cleared": false, "saved": 0, "lost": 10, "original_hp": 10, "score": 0.0, "time_left": 0.0, "reason": "no_more_ants"}
	EventBus.stage_failed.emit(fail_result)
	await get_tree().process_frame
	var s2: Dictionary = SaveData.stage_progress.get(2, {})
	if s2.get("cleared", false):
		return _fail("case B: stage2 should not be cleared after stage_failed")
	if int(s2.get("attempts", 0)) != 1:
		return _fail("case B: stage2 attempts expected 1")
	if SaveData.last_played_stage != 2:
		return _fail("case B: last_played_stage expected 2")
	print("[SaveDataRecordClearTest] case B PASS (stage_failed → record_attempt)")

func _case_c_repeat_clear_monotonic() -> void:
	# (c) 같은 stage 두 번 clear → best monotonic, attempts +1
	var lower := {"stage_id": 1, "cleared": true, "saved": 5, "lost": 5, "original_hp": 10, "score": 0.5, "time_left": 10.0, "reason": ""}
	EventBus.stage_cleared.emit(lower)
	await get_tree().process_frame
	var s1: Dictionary = SaveData.stage_progress.get(1, {})
	if int(s1.get("best_saved", 0)) != 8:    # 5 < 8, 보존
		return _fail("case C: best_saved monotonic broken, got %s" % str(s1.get("best_saved")))
	if int(s1.get("stars", 0)) != 2:    # max(2, 1) = 2
		return _fail("case C: stars monotonic broken")
	if int(s1.get("attempts", 0)) != 2:
		return _fail("case C: attempts expected 2, got %s" % str(s1.get("attempts")))
	print("[SaveDataRecordClearTest] case C PASS (repeat monotonic)")

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataRecordClearTest] FAIL ", msg)
	get_tree().quit(1)
