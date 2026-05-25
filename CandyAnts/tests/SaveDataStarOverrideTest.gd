extends Node

# Phase 20 — R1-H2 회귀 가드. SaveData.record_clear(stage_id, saved, original_hp, thresholds)
# 시그니처 확장 + _on_stage_cleared(result)가 result.star_thresholds를 4번째 인자로 전달하는지 검증.
# UI(StageDialog) 별점과 영속 데이터(stage_progress.stars) 동기성 확인.

const TEST_PATH := "user://test_savedata_star_override.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	await _case_a_direct_call()
	if _failed: return
	await _case_b_empty_fallback()
	if _failed: return
	await _case_c_emit_path()
	if _failed: return
	await _case_d_invalid_thresholds()
	if _failed: return
	await _case_e_no_obsolete_stars()
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataStarOverrideTest] PASS")
	get_tree().quit(0)

func _case_a_direct_call() -> void:
	# stage03 override [0.55, 0.85, 0.97]: saved=8/10 → ratio 0.8 < 0.85 → 1 star
	SaveData.record_clear(3, 8, 10, [0.55, 0.85, 0.97])
	await get_tree().process_frame
	var s3: Dictionary = SaveData.stage_progress.get(3, {})
	if int(s3.get("stars", -1)) != 1:
		return _fail("case A: stars expected 1 (0.8 < 0.85), got %s" % str(s3.get("stars")))
	if int(s3.get("best_saved", 0)) != 8:
		return _fail("case A: best_saved expected 8, got %s" % str(s3.get("best_saved")))
	if not bool(s3.get("cleared", false)):
		return _fail("case A: cleared not true")
	print("[SaveDataStarOverrideTest] case A PASS (direct record_clear with override)")

func _case_b_empty_fallback() -> void:
	# 새 stage_id로 분리 — 빈 배열 fall-back은 글로벌 [0.50, 0.80, 0.95]
	# 동일 saved=8/10 → ratio 0.8 >= 0.80 → 2 star
	SaveData.record_clear(2, 8, 10, [])
	await get_tree().process_frame
	var s2: Dictionary = SaveData.stage_progress.get(2, {})
	if int(s2.get("stars", -1)) != 2:
		return _fail("case B: stars expected 2 (global fallback 0.80), got %s" % str(s2.get("stars")))
	print("[SaveDataStarOverrideTest] case B PASS (empty thresholds → global fallback)")

func _case_c_emit_path() -> void:
	# EventBus.stage_cleared.emit(result) → _on_stage_cleared → record_clear with thresholds.
	# stage_id=4 분리, saved=10/10 → ratio 1.0 >= 0.97 → 3 stars (with override).
	# 만약 thresholds 전달 path가 끊겼으면 글로벌 fallback으로도 ratio 1.0 → 3 stars (검증 안 됨)
	# → 별도 saved=8/10 시나리오로 검증.
	var result := {
		"stage_id": 4, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10,
		"score": 0.8, "time_left": 30.0, "reason": "",
		"star_thresholds": [0.55, 0.85, 0.97],
	}
	EventBus.stage_cleared.emit(result)
	await get_tree().process_frame
	var s4: Dictionary = SaveData.stage_progress.get(4, {})
	if int(s4.get("stars", -1)) != 1:
		return _fail("case C: stars expected 1 (override path via EventBus), got %s" % str(s4.get("stars")))
	print("[SaveDataStarOverrideTest] case C PASS (EventBus.stage_cleared → _on_stage_cleared → record_clear with thresholds)")

func _case_d_invalid_thresholds() -> void:
	# R1-M2 invalid → 0 stars. stage_id=5 분리.
	SaveData.record_clear(5, 10, 10, [0.50, 0.80])
	await get_tree().process_frame
	var s5: Dictionary = SaveData.stage_progress.get(5, {})
	if int(s5.get("stars", -1)) != 0:
		return _fail("case D: stars expected 0 (invalid length=2), got %s" % str(s5.get("stars")))
	print("[SaveDataStarOverrideTest] case D PASS (invalid thresholds → 0 stars)")

func _case_e_no_obsolete_stars() -> void:
	# Phase 20 (codex impl-review 추가) — 동일 stage_id 두 번 record_clear.
	# 1차: 글로벌 thresholds + saved=8 → stars=2, best_saved=8.
	# 2차: 더 빡빡한 override + saved=7 → best_saved=max(8,7)=8 유지.
	#   max 보존 로직이면 stars=max(2, compute_stars(7,10,[0.55,...])=0)=2 (obsolete 잔존).
	#   best_saved 기반 derive 로직: stars=compute_stars(8,10,[0.55,...])=1 (정확).
	# stage_id=6 분리 (case A~D와 겹치지 않음).
	SaveData.record_clear(6, 8, 10, [])
	await get_tree().process_frame
	var s6_first: Dictionary = SaveData.stage_progress.get(6, {})
	if int(s6_first.get("stars", -1)) != 2:
		return _fail("case E precondition: first clear stars expected 2 (global 0.80), got %s" % str(s6_first.get("stars")))
	if int(s6_first.get("best_saved", 0)) != 8:
		return _fail("case E precondition: first clear best_saved expected 8, got %s" % str(s6_first.get("best_saved")))
	# 2차 클리어 — 더 빡빡한 override + 더 낮은 saved.
	SaveData.record_clear(6, 7, 10, [0.55, 0.85, 0.97])
	await get_tree().process_frame
	var s6_second: Dictionary = SaveData.stage_progress.get(6, {})
	if int(s6_second.get("best_saved", 0)) != 8:
		return _fail("case E: best_saved expected 8 (monotonic max preserved), got %s" % str(s6_second.get("best_saved")))
	if int(s6_second.get("stars", -1)) != 1:
		return _fail("case E: stars expected 1 (derive from best_saved=8 + new thresholds [0.55,0.85,0.97], NOT max-preserved obsolete 2), got %s" % str(s6_second.get("stars")))
	print("[SaveDataStarOverrideTest] case E PASS (no obsolete stars — derive from best_saved + current thresholds)")

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataStarOverrideTest] FAIL ", msg)
	get_tree().quit(1)
