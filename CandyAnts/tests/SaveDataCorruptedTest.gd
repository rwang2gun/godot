extends Node

# Phase 13 — plan §3.4.6 + Δ13. cfg 손상/누락 시 fresh init + crash 0.

const TEST_PATH_A := "user://test_savedata_corrupted_a.cfg"
const TEST_PATH_B := "user://test_savedata_corrupted_b.cfg"
const TEST_PATH_C := "user://test_savedata_corrupted_c.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	await _case_a_garbage_file()
	if _failed: return
	await _case_b_partial_corruption()
	if _failed: return
	# Codex R14 LOW: backup recovery case 추가 — atomic rename 직후 크래시 윈도우 보호.
	# (case D "corrupt main + intact bak"는 ConfigFile permissive parsing 때문에 reliable 트리거가 어려워 제외.
	#  case C가 더 critical한 missing-main 케이스를 커버하므로 R14 의도 충족.)
	await _case_c_missing_main_with_bak()
	if _failed: return
	SaveData._test_reset(_orig_path)
	print("[SaveDataCorruptedTest] PASS")
	get_tree().quit(0)

func _case_a_garbage_file() -> void:
	# (a) garbage cfg → ConfigFile.load 에러 → _init_fresh + save() + warn (crash 0)
	_cleanup(TEST_PATH_A)
	var f := FileAccess.open(TEST_PATH_A, FileAccess.WRITE)
	if f == null:
		_fail("case A: cannot write garbage file"); return
	f.store_string("THIS IS NOT A VALID GODOT CONFIGFILE\n@#$%^&*()\n[meta\nbroken")
	f.close()
	SaveData._test_reset(TEST_PATH_A)
	# fresh init expectation: schema_version == CURRENT_SCHEMA, stage_progress empty
	if SaveData.schema_version != SaveData.CURRENT_SCHEMA:
		_fail("case A: schema_version not reset"); return
	if not SaveData.stage_progress.is_empty():
		_fail("case A: stage_progress not empty after fresh init"); return
	if SaveData.last_played_stage != 0:
		_fail("case A: last_played_stage not 0"); return
	# Save was called → file rewritten with valid v1.
	var cfg := ConfigFile.new()
	if cfg.load(TEST_PATH_A) != OK:
		_fail("case A: file not rewritten with valid cfg"); return
	if int(cfg.get_value("meta", "schema_version", 0)) != SaveData.CURRENT_SCHEMA:
		_fail("case A: rewritten cfg schema_version wrong"); return
	_cleanup(TEST_PATH_A)
	print("[SaveDataCorruptedTest] case A PASS (garbage → fresh)")

func _case_b_partial_corruption() -> void:
	# (b) cfg 정상 + stage_progress.1만 garbage 타입 → 그 stage 0/false reset
	_cleanup(TEST_PATH_B)
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", SaveData.CURRENT_SCHEMA)
	cfg.set_value("meta", "last_played_stage", 2)
	cfg.set_value("meta", "created_at", "2026-05-18T10:00:00")
	cfg.set_value("meta", "last_saved_at", "2026-05-18T10:00:00")
	# stage1 garbage (best_saved이 String이라 int 변환 후 0)
	cfg.set_value("stage_progress.1", "cleared", "not_a_bool")  # bool() 변환은 0이 아닌 모든 String을 true로 — Godot 동작
	cfg.set_value("stage_progress.1", "best_saved", "not_int")
	cfg.set_value("stage_progress.1", "best_score", "nan")
	cfg.set_value("stage_progress.1", "stars", "x")
	cfg.set_value("stage_progress.1", "attempts", "y")
	# stage2 정상
	cfg.set_value("stage_progress.2", "cleared", true)
	cfg.set_value("stage_progress.2", "best_saved", 9)
	cfg.set_value("stage_progress.2", "best_score", 0.9)
	cfg.set_value("stage_progress.2", "stars", 3)
	cfg.set_value("stage_progress.2", "attempts", 5)
	cfg.save(TEST_PATH_B)
	SaveData._test_reset(TEST_PATH_B)
	# stage1: garbage가 int()/float() 변환 후 0 폴백 (cleared는 String→bool로 true가 될 수 있지만 본 테스트는 type fallback만 보장)
	var s1: Dictionary = SaveData.stage_progress.get(1, {})
	if int(s1.get("best_saved", -1)) != 0:
		_fail("case B: stage1.best_saved garbage not reset to 0 (got %s)" % str(s1.get("best_saved"))); return
	if int(s1.get("stars", -1)) != 0:
		_fail("case B: stage1.stars garbage not reset to 0"); return
	if int(s1.get("attempts", -1)) != 0:
		_fail("case B: stage1.attempts garbage not reset to 0"); return
	# stage2 유지
	var s2: Dictionary = SaveData.stage_progress.get(2, {})
	if not s2.get("cleared", false):
		_fail("case B: stage2.cleared lost"); return
	if int(s2.get("best_saved", 0)) != 9:
		_fail("case B: stage2.best_saved corrupted"); return
	if int(s2.get("stars", 0)) != 3:
		_fail("case B: stage2.stars corrupted"); return
	_cleanup(TEST_PATH_B)
	print("[SaveDataCorruptedTest] case B PASS (partial corruption → that stage reset, others intact)")

# Case C (R14): main 부재 + .bak intact (crash window between main→bak and tmp→main rename)
# → load_or_init이 .bak fallback으로 progress 복구해야 함.
func _case_c_missing_main_with_bak() -> void:
	_cleanup(TEST_PATH_C)
	# .bak 직접 작성 (atomic rename window 시뮬레이션). main은 작성 안 함.
	var bak_cfg := ConfigFile.new()
	bak_cfg.set_value("meta", "schema_version", SaveData.CURRENT_SCHEMA)
	bak_cfg.set_value("meta", "last_played_stage", 2)
	bak_cfg.set_value("stage_progress.1", "cleared", true)
	bak_cfg.set_value("stage_progress.1", "best_saved", 7)
	bak_cfg.set_value("stage_progress.1", "best_score", 0.7)
	bak_cfg.set_value("stage_progress.1", "stars", 1)
	bak_cfg.set_value("stage_progress.1", "attempts", 3)
	bak_cfg.save(TEST_PATH_C + ".bak")
	SaveData._test_reset(TEST_PATH_C)
	# .bak fallback path 검증: progress 복구 + last_played 복구
	if SaveData.last_played_stage != 2:
		return _fail("case C: last_played_stage not recovered from .bak (got %d)" % SaveData.last_played_stage)
	var s1: Dictionary = SaveData.stage_progress.get(1, {})
	if not s1.get("cleared", false):
		return _fail("case C: stage1.cleared not recovered from .bak")
	if int(s1.get("best_saved", 0)) != 7:
		return _fail("case C: stage1.best_saved expected 7 from .bak, got %s" % str(s1.get("best_saved")))
	# .bak fallback 시 save()가 호출되어 main 재기록되어야 함
	if not FileAccess.file_exists(TEST_PATH_C):
		return _fail("case C: main not rewritten after .bak recovery (atomic save() in load_or_init missing)")
	_cleanup(TEST_PATH_C)
	print("[SaveDataCorruptedTest] case C PASS (missing main + intact .bak → recover)")

func _cleanup(p: String) -> void:
	SaveData._test_cleanup_files(p)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup(TEST_PATH_A)
	_cleanup(TEST_PATH_B)
	_cleanup(TEST_PATH_C)
	SaveData._test_reset(_orig_path)
	print("[SaveDataCorruptedTest] FAIL ", msg)
	get_tree().quit(1)
