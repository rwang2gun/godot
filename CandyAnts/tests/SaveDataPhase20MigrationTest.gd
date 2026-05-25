extends Node

# Phase 20 — codex impl-review R1 HIGH 회귀 가드.
# v1 → v2 migration이 stage03.stars를 신규 thresholds [0.55, 0.85, 0.97] + STAGE_03_ORIGINAL_HP(9)로
# recompute. v1 데이터의 stale stars는 글로벌 [0.50, 0.80, 0.95] 기반이라 UI ↔ data desync 위험.

const TEST_PATH := "user://test_savedata_phase20_migration.cfg"
var _orig_path: String

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup_file()
	# (1) v1 seed — stage03 best_saved=8, stars=2 (under old global [0.50, 0.80, 0.95]).
	# 8/9 ≈ 0.889 → old: 0.889>=0.50 ✓, 0.889>=0.80 ✓, 0.889>=0.95 ✗ → 2 stars.
	_seed_v1_cfg(8, 2)
	SaveData._test_reset(TEST_PATH)
	# (2) Migration 완료 후 schema_version 갱신 + stage03.stars recompute 검증.
	if SaveData.schema_version != SaveData.CURRENT_SCHEMA:
		return _fail("schema_version expected %d, got %d" % [SaveData.CURRENT_SCHEMA, SaveData.schema_version])
	var s3: Dictionary = SaveData.stage_progress.get(3, {})
	# 신규 thresholds [0.55, 0.85, 0.97] + 8/9 ≈ 0.889 → 0.889>=0.55 ✓, 0.889>=0.85 ✓, 0.889>=0.97 ✗ → 2 stars.
	# (stage03 candy_hp=9에선 boundary가 정수 saved 값에 맞아 0.50→0.55 이동이 영향 없음.)
	if int(s3.get("stars", -1)) != 2:
		return _fail("post-migration stage03.stars expected 2, got %s" % str(s3.get("stars")))
	if int(s3.get("best_saved", 0)) != 8:
		return _fail("post-migration best_saved should be preserved (=8), got %s" % str(s3.get("best_saved")))
	# (3) 경계 케이스: best_saved=5 시나리오는 어떤 thresholds 조합에서도 1 star (0.556 boundary).
	_cleanup_file()
	_seed_v1_cfg(5, 1)
	SaveData._test_reset(TEST_PATH)
	var s3b: Dictionary = SaveData.stage_progress.get(3, {})
	if int(s3b.get("stars", -1)) != 1:
		return _fail("post-migration (saved=5) stage03.stars expected 1, got %s" % str(s3b.get("stars")))
	# (4) 보수적 boundary: best_saved=4 (under-threshold) → 0 stars 양쪽.
	_cleanup_file()
	_seed_v1_cfg(4, 0)
	SaveData._test_reset(TEST_PATH)
	var s3c: Dictionary = SaveData.stage_progress.get(3, {})
	if int(s3c.get("stars", -1)) != 0:
		return _fail("post-migration (saved=4) stage03.stars expected 0, got %s" % str(s3c.get("stars")))
	# (5) Phase 20 codex R5 회귀 가드 — poisoned best_saved=999 (out of [0, _STAGE_03_ORIGINAL_HP=9])
	# 시나리오. Migration이 sanitize 안 했으면 stars = compute_stars(999, 9, [0.55, 0.85, 0.97]) = 3 (inflate).
	# Sanitize 적용 시: best_saved reset to 0 → stars = compute_stars(0, 9, ...) = 0.
	_cleanup_file()
	_seed_v1_cfg(999, 3)   # poison
	SaveData._test_reset(TEST_PATH)
	var s3d: Dictionary = SaveData.stage_progress.get(3, {})
	if int(s3d.get("stars", -1)) != 0:
		return _fail("post-migration (poisoned best_saved=999) stage03.stars expected 0 (sanitized), got %s — codex R5 fix" % str(s3d.get("stars")))
	if int(s3d.get("best_saved", -1)) != 0:
		return _fail("post-migration (poisoned best_saved=999) stage03.best_saved expected 0 (sanitized), got %s" % str(s3d.get("best_saved")))
	_cleanup_file()
	SaveData._test_reset(_orig_path)
	print("[SaveDataPhase20MigrationTest] PASS")
	get_tree().quit(0)

func _seed_v1_cfg(stage03_best_saved: int, stage03_stars: int) -> void:
	# v1 = schema_version 1 + stage_progress.3 + (Phase 20 thresholds override 도입 전 글로벌 기준 stars).
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", 1)
	cfg.set_value("meta", "last_played_stage", 3)
	cfg.set_value("meta", "created_at", "2026-05-25T10:00:00")
	cfg.set_value("meta", "last_saved_at", "2026-05-25T10:00:00")
	cfg.set_value("stage_progress.3", "cleared", true)
	cfg.set_value("stage_progress.3", "best_saved", stage03_best_saved)
	cfg.set_value("stage_progress.3", "best_score", float(stage03_best_saved) / 9.0)
	cfg.set_value("stage_progress.3", "stars", stage03_stars)
	cfg.set_value("stage_progress.3", "attempts", 1)
	cfg.save(TEST_PATH)

func _cleanup_file() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	print("[SaveDataPhase20MigrationTest] FAIL ", msg)
	_cleanup_file()
	SaveData._test_reset(_orig_path)
	get_tree().quit(1)
