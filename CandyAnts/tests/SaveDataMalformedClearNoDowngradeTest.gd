extends Node

# record_clear가 malformed 입력(original_hp <= 0 또는 saved 범위 밖)으로 호출되면 기존
# stage_progress[id].stars/best_saved/best_score를 downgrade·poison하지 않고 보존해야 함.
# 전역 별 규칙: saved>=1 → 1성 / 50% → 2성 / 80% → 3성.

const TEST_PATH := "user://test_savedata_malformed_clear.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	await _case_a_existing_then_zero_original_hp()
	if _failed: return
	await _case_c_fresh_entry_malformed()
	if _failed: return
	await _case_d_legit_zero_saved_still_recomputes()
	if _failed: return
	await _case_e_poisoned_best_saved()
	if _failed: return
	await _case_f_preexisting_poisoned_storage()
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataMalformedClearNoDowngradeTest] PASS")
	get_tree().quit(0)

func _case_a_existing_then_zero_original_hp() -> void:
	# (1) 정상 clear → stars=3.
	SaveData.record_clear(1, 10, 10)   # 10/10=100% → 3성
	await get_tree().process_frame
	var s1: Dictionary = SaveData.stage_progress.get(1, {})
	if int(s1.get("stars", -1)) != 3:
		return _fail("case A setup: expected stars=3, got %s" % str(s1.get("stars")))
	# (2) malformed clear (original_hp=0) → stars 보존(=3), warning emit.
	SaveData.record_clear(1, 5, 0)
	await get_tree().process_frame
	s1 = SaveData.stage_progress.get(1, {})
	if int(s1.get("stars", -1)) != 3:
		return _fail("case A: stars expected preserved=3 after malformed (original_hp=0), got %s" % str(s1.get("stars")))
	print("[SaveDataMalformedClearNoDowngradeTest] case A PASS (original_hp=0 preserves stars)")

func _case_c_fresh_entry_malformed() -> void:
	# 새 stage_id, malformed 첫 clear → progress 전부 보존(초기값), attempts만 +1.
	SaveData.record_clear(3, 5, 0)   # original_hp=0 malformed
	await get_tree().process_frame
	var s3: Dictionary = SaveData.stage_progress.get(3, {})
	if int(s3.get("stars", -1)) != 0:
		return _fail("case C: fresh entry malformed expected stars=0 (initial), got %s" % str(s3.get("stars")))
	if bool(s3.get("cleared", false)):
		return _fail("case C: cleared expected false (malformed clear는 cleared 토글 안 함)")
	if int(s3.get("best_saved", -1)) != 0:
		return _fail("case C: best_saved expected 0 (malformed은 progress update 안 함), got %s" % str(s3.get("best_saved")))
	if int(s3.get("attempts", 0)) != 1:
		return _fail("case C: attempts expected 1 (malformed도 시도 횟수는 기록), got %s" % str(s3.get("attempts")))
	print("[SaveDataMalformedClearNoDowngradeTest] case C PASS (fresh malformed → all progress preserved, attempts +1)")

func _case_d_legit_zero_saved_still_recomputes() -> void:
	# 새 stage_id, legit 0 saved with valid input → stars=0 (legitimate 0). best_saved=0, stars 갱신.
	SaveData.record_clear(4, 0, 10)   # 0/10=0.0 → 0성 (legit)
	await get_tree().process_frame
	var s4: Dictionary = SaveData.stage_progress.get(4, {})
	if int(s4.get("stars", -1)) != 0:
		return _fail("case D: legit saved=0 expected stars=0, got %s" % str(s4.get("stars")))
	# Replay with saved=8 → 80% → 3성 (best_saved=8). best_saved monotonic.
	SaveData.record_clear(4, 8, 10)
	await get_tree().process_frame
	s4 = SaveData.stage_progress.get(4, {})
	if int(s4.get("stars", -1)) != 3:
		return _fail("case D: after replay saved=8 expected stars=3 (80%), got %s" % str(s4.get("stars")))
	# Replay with saved=3 → best_saved=max(8,3)=8 유지, stars derive from best_saved=8 → 3.
	SaveData.record_clear(4, 3, 10)
	await get_tree().process_frame
	s4 = SaveData.stage_progress.get(4, {})
	if int(s4.get("stars", -1)) != 3:
		return _fail("case D: worse replay should preserve stars=3 (best_saved monotonic), got %s" % str(s4.get("stars")))
	print("[SaveDataMalformedClearNoDowngradeTest] case D PASS (legit zero recomputes + best_saved monotonic)")

func _case_e_poisoned_best_saved() -> void:
	# malformed clear에서 saved=999, original_hp=0이라도 best_saved가 999로 poison되면 안 됨.
	# 새 stage_id=7 분리.
	SaveData.record_clear(7, 999, 0)
	await get_tree().process_frame
	var s7: Dictionary = SaveData.stage_progress.get(7, {})
	if int(s7.get("best_saved", -1)) != 0:
		return _fail("case E: poisoned best_saved expected 0 (preserved initial), got %s" % str(s7.get("best_saved")))
	# 후속 valid clear: saved=5, original_hp=10 → 50% → 2성. (poison 잔존 시 compute_stars(999,10)=3 corruption.)
	SaveData.record_clear(7, 5, 10)
	await get_tree().process_frame
	s7 = SaveData.stage_progress.get(7, {})
	if int(s7.get("best_saved", -1)) != 5:
		return _fail("case E: post-valid best_saved expected 5 (no poison), got %s" % str(s7.get("best_saved")))
	if int(s7.get("stars", -1)) != 2:
		return _fail("case E: post-valid stars expected 2 (5/10=50% → 2성, NOT poisoned 3), got %s" % str(s7.get("stars")))
	if not bool(s7.get("cleared", false)):
		return _fail("case E: post-valid cleared expected true")
	print("[SaveDataMalformedClearNoDowngradeTest] case E PASS (poisoned saved=999/original_hp=0 not persisted, post-valid stars correct)")

func _case_f_preexisting_poisoned_storage() -> void:
	# 외부 corruption(수동 .cfg 편집 등)으로 stored best_saved=999가 영속됐을 때, 후속 valid clear가
	# best_saved/stars를 sanitize 해야 함. stage_id=8 분리.
	_cleanup()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", SaveData.CURRENT_SCHEMA)
	cfg.set_value("meta", "last_played_stage", 8)
	cfg.set_value("meta", "created_at", "2026-06-08T10:00:00")
	cfg.set_value("meta", "last_saved_at", "2026-06-08T10:00:00")
	cfg.set_value("stage_progress.8", "cleared", true)
	cfg.set_value("stage_progress.8", "best_saved", 999)   # poison
	cfg.set_value("stage_progress.8", "best_score", 99.9)  # poison
	cfg.set_value("stage_progress.8", "stars", 3)
	cfg.set_value("stage_progress.8", "attempts", 1)
	cfg.save(TEST_PATH)
	SaveData._test_reset(TEST_PATH)
	await get_tree().process_frame
	# Valid clear: saved=5, original_hp=10 → 50% → 2성. sanitize 없으면 best_saved=max(999,5)=999 → stars 3.
	SaveData.record_clear(8, 5, 10)
	await get_tree().process_frame
	var s8: Dictionary = SaveData.stage_progress.get(8, {})
	if int(s8.get("best_saved", -1)) != 5:
		return _fail("case F: best_saved expected 5 (sanitized from poisoned 999), got %s" % str(s8.get("best_saved")))
	if int(s8.get("stars", -1)) != 2:
		return _fail("case F: stars expected 2 (no longer corrupted by stored 999), got %s" % str(s8.get("stars")))
	var bs: float = float(s8.get("best_score", -1.0))
	if bs < 0.0 or bs > 1.0:
		return _fail("case F: best_score expected in [0, 1] (clamped from poisoned 99.9), got %f" % bs)
	print("[SaveDataMalformedClearNoDowngradeTest] case F PASS (pre-existing poisoned best_saved=999 sanitized → post-valid stars=2, best_score in [0,1])")

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataMalformedClearNoDowngradeTest] FAIL ", msg)
	get_tree().quit(1)
