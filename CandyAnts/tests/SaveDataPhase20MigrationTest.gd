extends Node

# 별 규칙 전역화(2026-06-08) v2→v3 마이그레이션 회귀 가드.
# 기존 영속 stars는 구 비율 임계값 기준 → _migrate_2_to_3가 best_score(저장된 비율)로 신규 규칙
# (saved>=1=1성 / 50%=2성 / 80%=3성)으로 전 스테이지 stars를 재계산해야 함.
# v1 데이터도 v1→v2(no-op)→v3 체인으로 동일 결과.

const TEST_PATH := "user://test_savedata_starrule_migration.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup_file()
	# v2 seed — 여러 스테이지의 best_score + 구-규칙 stale stars.
	_seed_v2_cfg()
	SaveData._test_reset(TEST_PATH)
	# (1) schema_version → CURRENT(3).
	if SaveData.schema_version != SaveData.CURRENT_SCHEMA:
		return _fail("schema_version expected %d, got %d" % [SaveData.CURRENT_SCHEMA, SaveData.schema_version])
	# (2) stars가 best_score 기준 신규 규칙으로 recompute.
	_expect_stars(1, 3, "stage1 best_score=0.8 (80%) → 3성 (구 stale 2 → 3)")
	if _failed: return
	_expect_stars(2, 2, "stage2 best_score=0.6 (60%) → 2성 (구 stale 1 → 2)")
	if _failed: return
	_expect_stars(3, 1, "stage3 best_score=0.1 (10%, 1조각) → 1성 (구 stale 0 → 1)")
	if _failed: return
	_expect_stars(4, 3, "stage4 best_score=1.0 (100%) → 3성")
	if _failed: return
	# best_saved 보존 확인 (마이그레이션은 stars만 손댐).
	var s1: Dictionary = SaveData.stage_progress.get(1, {})
	if int(s1.get("best_saved", -1)) != 8:
		return _fail("stage1 best_saved should be preserved (=8), got %s" % str(s1.get("best_saved")))

	# (3) v1 → v3 체인도 동일 결과.
	_cleanup_file()
	_seed_v1_single(0.8)   # 80% → 3성
	SaveData._test_reset(TEST_PATH)
	if SaveData.schema_version != SaveData.CURRENT_SCHEMA:
		return _fail("v1→v3: schema_version expected %d, got %d" % [SaveData.CURRENT_SCHEMA, SaveData.schema_version])
	_expect_stars(5, 3, "v1→v3 stage5 best_score=0.8 → 3성")
	if _failed: return

	_cleanup_file()
	SaveData._test_reset(_orig_path)
	print("[SaveDataPhase20MigrationTest] PASS")
	get_tree().quit(0)

func _seed_v2_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", 2)
	cfg.set_value("meta", "last_played_stage", 4)
	cfg.set_value("meta", "created_at", "2026-06-08T10:00:00")
	cfg.set_value("meta", "last_saved_at", "2026-06-08T10:00:00")
	_seed_entry(cfg, 1, 8, 0.8, 2)   # 구-규칙 stale stars
	_seed_entry(cfg, 2, 3, 0.6, 1)
	_seed_entry(cfg, 3, 1, 0.1, 0)
	_seed_entry(cfg, 4, 10, 1.0, 3)
	cfg.save(TEST_PATH)

func _seed_v1_single(best_score: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", 1)
	cfg.set_value("meta", "last_played_stage", 5)
	cfg.set_value("meta", "created_at", "2026-06-08T10:00:00")
	cfg.set_value("meta", "last_saved_at", "2026-06-08T10:00:00")
	_seed_entry(cfg, 5, 8, best_score, 0)   # stale stars 0
	cfg.save(TEST_PATH)

func _seed_entry(cfg: ConfigFile, id: int, best_saved: int, best_score: float, stars: int) -> void:
	var section := "stage_progress.%d" % id
	cfg.set_value(section, "cleared", true)
	cfg.set_value(section, "best_saved", best_saved)
	cfg.set_value(section, "best_score", best_score)
	cfg.set_value(section, "stars", stars)
	cfg.set_value(section, "attempts", 1)

func _expect_stars(id: int, expected: int, label: String) -> void:
	if _failed:
		return
	var e: Dictionary = SaveData.stage_progress.get(id, {})
	if int(e.get("stars", -1)) != expected:
		_fail("%s — got %s" % [label, str(e.get("stars"))])

func _cleanup_file() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[SaveDataPhase20MigrationTest] FAIL ", msg)
	_cleanup_file()
	SaveData._test_reset(_orig_path)
	get_tree().quit(1)
