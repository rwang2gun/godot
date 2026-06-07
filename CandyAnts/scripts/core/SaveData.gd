extends Node

# Phase 13 — UI_GUIDE §5 + plan v2 §3.4 SoT.
# Autoload (project.godot의 [autoload] 등록). EventBus 직후 _ready 보장.
# Strict contract (plan Δ2, codex Round 1 MED-A):
#   - EventBus.stage_cleared (cleared=true 정상)  → record_clear
#   - EventBus.stage_failed  (cleared=false 정상) → record_attempt
# 시그널 의미 검증은 SaveData 책임 아님 (Decoupling).

const SAVE_PATH := "user://save.cfg"
# schema 이력:
#   v1→v2 (Phase 20): stage03 star_thresholds override 도입. (별 규칙 전역화로 의미 폐기 → _migrate_1_to_2 no-op.)
#   v2→v3 (2026-06-08): 별 규칙 전역 고정(saved>=1=1성 / 50%=2성 / 80%=3성). 스테이지별 임계값 폐지.
#     기존 영속 stars는 구 비율 임계값 기준이라 신규 규칙과 desync → best_score(저장된 비율)로 전 스테이지 recompute.
const CURRENT_SCHEMA := 3

var schema_version: int = CURRENT_SCHEMA
var last_played_stage: int = 0
var stage_progress: Dictionary = {}
var created_at: String = ""
var last_saved_at: String = ""
var _save_path: String = SAVE_PATH

func _ready() -> void:
	# 테스트 격리(2026-06-04) — 환경변수 CANDYANTS_SAVE_PATH가 있으면 그 경로를 저장소로 사용한다.
	# run_test.py가 헤드리스 테스트 실행 시에만 throwaway 경로로 설정 → Campaign/GameFlow 등
	# stage_cleared/failed를 발화하는 통합 테스트가 실제 user://save.cfg(플레이어 진행)를 오염시키지 않는다.
	# 일반 게임 실행(에디터/익스포트)은 이 변수가 없으므로 기본 SAVE_PATH(user://save.cfg) 그대로 사용.
	var override_path: String = OS.get_environment("CANDYANTS_SAVE_PATH")
	if override_path != "":
		_save_path = override_path
	load_or_init()
	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.stage_failed.connect(_on_stage_failed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()

func _on_stage_cleared(result: Dictionary) -> void:
	var stage_id: int = int(result.get("stage_id", 0))
	if stage_id <= 0:
		return
	record_clear(
		stage_id,
		int(result.get("saved", 0)),
		int(result.get("original_hp", 0)),
	)

func _on_stage_failed(result: Dictionary) -> void:
	var stage_id: int = int(result.get("stage_id", 0))
	if stage_id <= 0:
		return
	record_attempt(stage_id)

func load_or_init() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(_save_path)
	if err == OK:
		var v: int = _safe_int(cfg.get_value("meta", "schema_version", 0))
		if v > CURRENT_SCHEMA:
			push_warning("[SaveData] future schema_version=%d > current=%d, init fresh in-memory" % [v, CURRENT_SCHEMA])
			_init_fresh()
			return
		var migrated: bool = v < CURRENT_SCHEMA
		if migrated:
			_migrate(cfg, v, CURRENT_SCHEMA)
		_populate_from(cfg)
		if migrated:
			# Codex R13 MED fix: _migrate 자체는 in-memory cfg만 변경 — atomic save로 영속.
			save()
		return
	# Main load failed — Codex R11/R12 MED fix: try .bak whenever main fails (incl. ERR_FILE_NOT_FOUND).
	# 크래시가 main→bak rename 직후 + tmp→main rename 직전에 발생하면 main이 사라지고 bak만 남는다.
	# 이 케이스를 fresh init으로 잘못 분류하면 progress 손실 → bak 존재 시 무조건 시도.
	var bak_path: String = _save_path + ".bak"
	if FileAccess.file_exists(bak_path):
		var bak_cfg := ConfigFile.new()
		if bak_cfg.load(bak_path) == OK:
			var bv: int = _safe_int(bak_cfg.get_value("meta", "schema_version", 0))
			if bv <= CURRENT_SCHEMA:
				if bv < CURRENT_SCHEMA:
					_migrate(bak_cfg, bv, CURRENT_SCHEMA)
				_populate_from(bak_cfg)
				push_warning("[SaveData] main cfg unavailable (err=%d) — recovered from .bak" % err)
				save()   # rewrite main with recovered data (atomic)
				return
	if err != ERR_FILE_NOT_FOUND:
		push_warning("[SaveData] cfg load failed err=%d, init fresh" % err)
	_init_fresh()
	save()

func save() -> void:
	# Codex R11 MED fix: atomic-ish write via tmp + rename + backup.
	# 1. Write to tmp path.
	# 2. Move existing main → .bak (overwriting old .bak).
	# 3. Move tmp → main.
	# 크래시 시점에 따른 복구:
	#  - (1) 도중 크래시: tmp 부분 작성, main/bak intact → 다음 load는 main OK.
	#  - (2) 도중 크래시: main 사라짐, bak 부재 → 다음 load는 bak ENOENT → fresh.
	#  - (3) 도중 크래시: main 사라짐, bak intact, tmp 완전 → 다음 load는 main ENOENT → fresh
	#    (다음 save가 즉시 호출되어 새로 저장됨). bak는 fallback으로 load_or_init에서 시도.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", CURRENT_SCHEMA)
	cfg.set_value("meta", "last_played_stage", last_played_stage)
	if created_at.is_empty():
		created_at = Time.get_datetime_string_from_system(false, true)
	cfg.set_value("meta", "created_at", created_at)
	last_saved_at = Time.get_datetime_string_from_system(false, true)
	cfg.set_value("meta", "last_saved_at", last_saved_at)
	for stage_id in stage_progress.keys():
		var section := "stage_progress.%d" % int(stage_id)
		var entry: Dictionary = stage_progress[stage_id]
		for k in entry.keys():
			cfg.set_value(section, str(k), entry[k])
	var tmp_path: String = _save_path + ".tmp"
	var bak_path: String = _save_path + ".bak"
	var err := cfg.save(tmp_path)
	if err != OK:
		push_warning("[SaveData] tmp save failed err=%d" % err)
		return
	# Move main → bak (overwriting old bak if exists).
	if FileAccess.file_exists(_save_path):
		var bak_abs := ProjectSettings.globalize_path(bak_path)
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_abs)
		var bak_err := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(_save_path),
			bak_abs
		)
		if bak_err != OK:
			push_warning("[SaveData] main→bak rename failed err=%d" % bak_err)
	# Move tmp → main.
	var main_err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path),
		ProjectSettings.globalize_path(_save_path)
	)
	if main_err != OK:
		push_warning("[SaveData] tmp→main rename failed err=%d" % main_err)

func record_clear(stage_id: int, saved: int, original_hp: int) -> void:
	# malformed 입력(original_hp <= 0 / saved 범위 밖)은 기존 cleared/best_saved/best_score/stars를 보존하고
	# attempts만 증가 — 손상 입력이 진행도를 downgrade/poison하지 못하게 한다.
	var entry: Dictionary = _get_or_init_entry(stage_id)
	if original_hp <= 0 or saved < 0 or saved > original_hp:
		push_warning("[SaveData.record_clear] malformed input (stage_id=%d, saved=%d, original_hp=%d) — preserving progress, attempts만 +1" % [stage_id, saved, original_hp])
		entry["attempts"] = int(entry.get("attempts", 0)) + 1
		stage_progress[stage_id] = entry
		last_played_stage = stage_id
		save()
		return
	# valid path — 외부 corruption(수동 .cfg 편집 등)으로 stored best_saved/best_score가 범위 밖이면 sanitize.
	var stored_best_saved: int = int(entry.get("best_saved", 0))
	if stored_best_saved < 0 or stored_best_saved > original_hp:
		push_warning("[SaveData.record_clear] stored best_saved=%d out of [0, %d] for stage %d — corruption detected, resetting baseline to current saved=%d" % [stored_best_saved, original_hp, stage_id, saved])
		stored_best_saved = saved
	var stored_best_score: float = float(entry.get("best_score", 0.0))
	if stored_best_score < 0.0 or stored_best_score > 1.0:
		push_warning("[SaveData.record_clear] stored best_score=%f out of [0, 1] for stage %d — corruption detected, clamping" % [stored_best_score, stage_id])
		stored_best_score = clampf(stored_best_score, 0.0, 1.0)
	var score: float = float(saved) / float(original_hp)
	entry["cleared"] = true
	entry["best_saved"] = max(stored_best_saved, saved)
	entry["best_score"] = max(stored_best_score, score)
	# stars: best_saved 기반 derive — UI 별점과 동일 입력(전역 Scoring 규칙)으로 동기.
	entry["stars"]      = Scoring.compute_stars(int(entry["best_saved"]), original_hp)
	entry["attempts"]   = int(entry.get("attempts", 0)) + 1
	stage_progress[stage_id] = entry
	last_played_stage = stage_id
	save()

func record_attempt(stage_id: int) -> void:
	var entry: Dictionary = _get_or_init_entry(stage_id)
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	stage_progress[stage_id] = entry
	last_played_stage = stage_id
	save()

func is_unlocked(stage_id: int) -> bool:
	# Codex R10 LOW fix: stage_id <= 0 / 음수도 unlocked로 잘못 보고하지 않도록.
	if stage_id < 1:
		return false
	if stage_id == 1:
		return true
	var prev: Dictionary = stage_progress.get(stage_id - 1, {})
	return _safe_bool(prev.get("cleared", false))

func get_stage_entry(stage_id: int) -> Dictionary:
	return stage_progress.get(stage_id, {}).duplicate()

func total_stars() -> int:
	var sum: int = 0
	for entry in stage_progress.values():
		sum += int(entry.get("stars", 0))
	return sum

func _get_or_init_entry(stage_id: int) -> Dictionary:
	if not stage_progress.has(stage_id):
		stage_progress[stage_id] = {
			"cleared": false,
			"best_saved": 0,
			"best_score": 0.0,
			"stars": 0,
			"attempts": 0,
		}
	return stage_progress[stage_id]

func _init_fresh() -> void:
	schema_version = CURRENT_SCHEMA
	last_played_stage = 0
	stage_progress = {}
	created_at = Time.get_datetime_string_from_system(false, true)
	last_saved_at = created_at

func _populate_from(cfg: ConfigFile) -> void:
	schema_version = CURRENT_SCHEMA
	last_played_stage = _safe_int(cfg.get_value("meta", "last_played_stage", 0))
	created_at = str(cfg.get_value("meta", "created_at", Time.get_datetime_string_from_system(false, true)))
	last_saved_at = str(cfg.get_value("meta", "last_saved_at", created_at))
	stage_progress = {}
	for section in cfg.get_sections():
		if not section.begins_with("stage_progress."):
			continue
		var id_str := section.substr("stage_progress.".length())
		if not id_str.is_valid_int():
			push_warning("[SaveData] invalid section %s, skip" % section)
			continue
		var id := id_str.to_int()
		# Godot 4: bool()/int()/float() 생성자는 String 인자 raise — type-checked safe cast helper.
		stage_progress[id] = {
			"cleared":    _safe_bool(cfg.get_value(section, "cleared", false)),
			"best_saved": _safe_int(cfg.get_value(section, "best_saved", 0)),
			"best_score": _safe_float(cfg.get_value(section, "best_score", 0.0)),
			"stars":      _safe_int(cfg.get_value(section, "stars", 0)),
			"attempts":   _safe_int(cfg.get_value(section, "attempts", 0)),
		}

# Self-Review R2 fix (테스트 실행 후 발견): Godot 4 `bool()` constructor는 String/Object 인자 raise.
# 손상된 cfg 값을 type-safe하게 처리하기 위해 typeof guard.
func _safe_bool(v) -> bool:
	return v if typeof(v) == TYPE_BOOL else false

func _safe_int(v) -> int:
	match typeof(v):
		TYPE_INT:    return v
		TYPE_FLOAT:  return int(v)
		TYPE_BOOL:   return 1 if v else 0
		TYPE_STRING: return (v as String).to_int() if (v as String).is_valid_int() else 0
		_:           return 0

func _safe_float(v) -> float:
	match typeof(v):
		TYPE_FLOAT:  return v
		TYPE_INT:    return float(v)
		TYPE_BOOL:   return 1.0 if v else 0.0
		TYPE_STRING: return (v as String).to_float() if (v as String).is_valid_float() else 0.0
		_:           return 0.0

func _migrate(cfg: ConfigFile, from_v: int, to_v: int) -> void:
	# Codex R13 MED fix: in-memory cfg만 변환. `cfg.save(_save_path)` 직접 호출 제거 (R11 atomic 우회).
	# load_or_init() caller가 _populate_from(cfg) 후 save() (atomic)를 호출.
	# stage4~10 phase에서 schema bump 시 본 함수에 case 추가.
	for v in range(from_v, to_v):
		match v:
			0: _migrate_0_to_1(cfg)
			1: _migrate_1_to_2(cfg)
			2: _migrate_2_to_3(cfg)
	cfg.set_value("meta", "schema_version", to_v)

func _migrate_0_to_1(_cfg: ConfigFile) -> void:
	# v0 → v1: schema_version 키만 추가 (_migrate 본체에서 처리), 데이터 변환 없음.
	pass

func _migrate_1_to_2(_cfg: ConfigFile) -> void:
	# (구) Phase 20 stage03 star_thresholds override 기반 stars recompute.
	# 별 규칙 전역화(v2→v3)로 스테이지별 임계값이 폐지되어 의미 소멸 → no-op.
	# v3 마이그레이션이 best_score 기준으로 전 스테이지 stars를 재계산하므로 여기서 별도 처리 불필요.
	pass

func _migrate_2_to_3(cfg: ConfigFile) -> void:
	# 별 규칙 전역 고정(2026-06-08) — 스테이지별 star_thresholds 폐지, 전역 규칙(saved>=1=1성 / 50%=2성 / 80%=3성).
	# 기존 영속 stars는 구 비율 임계값 기준이라 신규 규칙과 desync. best_score(=saved/hp 비율, 이미 저장됨)로
	# 모든 스테이지 stars를 신규 규칙으로 재계산. best_score만으로 신규 규칙 완전 결정(saved>=1 ⟺ ratio>0).
	for section in cfg.get_sections():
		if not section.begins_with("stage_progress."):
			continue
		var best_score := clampf(_safe_float(cfg.get_value(section, "best_score", 0.0)), 0.0, 1.0)
		cfg.set_value(section, "stars", Scoring.compute_stars_from_ratio(best_score))

# ─── test-only (plan Δ13) ─────────────────────────────────────────
# 테스트가 본 함수 호출:
#   var orig := SaveData._save_path
#   SaveData._test_reset("user://test_savedata_<TEST>.cfg")
#   ... test ...
#   SaveData._test_reset(orig)
# in-memory state만 reset, signal connection은 _ready에서 1회 connect된 채 유지.
func _test_reset(path: String) -> void:
	_save_path = path
	schema_version = CURRENT_SCHEMA
	last_played_stage = 0
	stage_progress = {}
	created_at = ""
	last_saved_at = ""
	load_or_init()

# atomic write의 .tmp/.bak 파일까지 일괄 정리 (R11 fix 이후 테스트 격리 필수).
# Autoload instance method — `SaveData._test_cleanup_files(path)`로 호출.
func _test_cleanup_files(base_path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p: String = base_path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
