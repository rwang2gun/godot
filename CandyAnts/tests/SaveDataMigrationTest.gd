extends Node

# Phase 13 — plan §3.4.2 v0 → v1 migration + plan Δ13 test 격리.

const TEST_PATH := "user://test_savedata_migration.cfg"
var _orig_path: String

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup_file()
	_seed_v0_cfg()
	SaveData._test_reset(TEST_PATH)
	# load_or_init → _migrate(0,1) → _populate_from
	if SaveData.schema_version != SaveData.CURRENT_SCHEMA:
		return _fail("schema_version expected %d, got %d" % [SaveData.CURRENT_SCHEMA, SaveData.schema_version])
	var s1: Dictionary = SaveData.stage_progress.get(1, {})
	if not s1.get("cleared", false):
		return _fail("stage1.cleared lost during migration: %s" % str(s1))
	if int(s1.get("best_saved", -1)) != 7:
		return _fail("stage1.best_saved expected 7, got %s" % str(s1.get("best_saved")))
	# Reload from disk → schema_version should be persisted on disk.
	SaveData._test_reset(TEST_PATH)
	var cfg := ConfigFile.new()
	if cfg.load(TEST_PATH) != OK:
		return _fail("cfg reload failed")
	if int(cfg.get_value("meta", "schema_version", 0)) != SaveData.CURRENT_SCHEMA:
		return _fail("schema_version not persisted on disk")
	_cleanup_file()
	SaveData._test_reset(_orig_path)
	print("[SaveDataMigrationTest] PASS")
	get_tree().quit(0)

func _seed_v0_cfg() -> void:
	# v0 = schema_version 키 없음. stage_progress.1만 있음.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "last_played_stage", 1)
	cfg.set_value("meta", "created_at", "2026-05-18T10:00:00")
	cfg.set_value("meta", "last_saved_at", "2026-05-18T10:00:00")
	cfg.set_value("stage_progress.1", "cleared", true)
	cfg.set_value("stage_progress.1", "best_saved", 7)
	cfg.set_value("stage_progress.1", "best_score", 0.7)
	cfg.set_value("stage_progress.1", "stars", 1)
	cfg.set_value("stage_progress.1", "attempts", 2)
	cfg.save(TEST_PATH)

func _cleanup_file() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	print("[SaveDataMigrationTest] FAIL ", msg)
	_cleanup_file()
	SaveData._test_reset(_orig_path)
	get_tree().quit(1)
