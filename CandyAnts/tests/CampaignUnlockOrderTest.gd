extends Node

# campaign-50 Phase A — Campaign 언락/순서 파생 결정성 검증.
# 통제된 매니페스트를 _test_set_manifest로 주입(비선형 씬 id로 ±1 산술 아님을 실증) + SaveData 통제.
# 케이스: first always unlocked / prev cleared→next unlocked(manifest 순서) / 챕터 게이팅 +
#   빈 챕터 skip / next_unlocked_stage / 재배치 시 언락 재계산(cleared 보존) / 챕터 1-based 가드(codex R2 MED-1).

const TEST_PATH := "user://test_campaign_unlock_order.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	_run()
	# 원복: SaveData 격리 해제 + Campaign 라이브 매니페스트 재로드(주입분 폐기).
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	Campaign._load_manifest()
	if not _failed:
		print("[CampaignUnlockOrderTest] PASS")
		get_tree().quit(0)

func _run() -> void:
	# Ch1=[10,20] Ch2=[30] Ch3=[](빈) Ch4=[40]. 비선형 id + 빈 챕터.
	var m := CampaignManifest.new()
	m.chapters = [
		{"title": "C1", "theme": "t", "stage_ids": [10, 20]},
		{"title": "C2", "theme": "t", "stage_ids": [30]},
		{"title": "C3", "theme": "t", "stage_ids": []},
		{"title": "C4", "theme": "t", "stage_ids": [40]},
	]
	if not m.is_valid():
		return _fail("test manifest invalid")
	Campaign._test_set_manifest(m)

	# --- stage unlock: 매니페스트 순서(±1 아님) ---
	_reset_save()
	_t(Campaign.is_stage_unlocked(10), "first stage 10 unlocked on fresh save")
	_t(not Campaign.is_stage_unlocked(20), "stage 20 locked before 10 cleared")
	_t(not Campaign.is_stage_unlocked(30), "stage 30 locked before 20 cleared")
	_t(not Campaign.is_stage_unlocked(999), "unregistered stage locked")
	_clear(10)
	_t(Campaign.is_stage_unlocked(20), "stage 20 unlocked after 10 cleared (order 10→20, not +1)")
	_t(not Campaign.is_stage_unlocked(30), "stage 30 still locked (20 not cleared)")
	_clear(20)
	_t(Campaign.is_stage_unlocked(30), "stage 30 unlocked after 20 cleared (crosses chapter boundary)")
	if _failed: return

	# --- chapter unlock + 빈 챕터 skip ---
	_reset_save()
	_t(Campaign.is_chapter_unlocked(1), "chapter 1 always unlocked")
	_t(not Campaign.is_chapter_unlocked(2), "chapter 2 locked before ch1 last(20) cleared")
	_clear(10); _clear(20)
	_t(Campaign.is_chapter_unlocked(2), "chapter 2 unlocked after ch1 last(20) cleared")
	_t(not Campaign.is_chapter_unlocked(4), "chapter 4 locked before ch2 last(30) cleared (empty ch3 skipped)")
	_clear(30)
	_t(Campaign.is_chapter_unlocked(3), "empty chapter 3 unlocked once preceding ch2 cleared")
	_t(Campaign.is_chapter_unlocked(4), "chapter 4 unlocked after ch2 last(30) cleared (empty ch3 skipped to ch2)")
	if _failed: return

	# --- 챕터 1-based 가드 (codex R2 MED-1) ---
	_t(not Campaign.is_chapter_unlocked(0), "chapter 0 (not-found sentinel) NOT unlocked")
	_t(not Campaign.is_chapter_unlocked(-1), "negative chapter NOT unlocked")
	_t(not Campaign.is_chapter_unlocked(5), "chapter > count NOT unlocked")
	_t(Campaign.is_chapter_unlocked(1), "chapter 1 still unlocked after guard rejects out-of-range")
	if _failed: return

	# --- next_unlocked_stage (Play 이어가기) ---
	_reset_save()
	_eq(Campaign.next_unlocked_stage(), 10, "next_unlocked = first uncleared (10)")
	_clear(10)
	_eq(Campaign.next_unlocked_stage(), 20, "next_unlocked advances to 20")
	if _failed: return

	# --- 재배치 시 언락 재계산 (cleared 보존, ordering만 재도출) ---
	_reset_save()
	_clear(10)
	var m2 := CampaignManifest.new()
	m2.chapters = [{"title": "C1", "theme": "t", "stage_ids": [20, 10]}]  # 순서 뒤집기
	Campaign._test_set_manifest(m2)
	_t(Campaign.is_stage_unlocked(20), "after reorder, 20 is first → unlocked")
	_t(not Campaign.is_stage_unlocked(10), "after reorder, 10 locked (new prev=20 not cleared) — unlock re-derived")
	_t(bool(SaveData.get_stage_entry(10).get("cleared", false)), "cleared(10) data preserved across reorder")

func _reset_save() -> void:
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)

func _clear(sid: int) -> void:
	SaveData.record_clear(sid, 10, 10)

func _t(cond: bool, label: String) -> void:
	if _failed: return
	if not cond:
		_fail(label)

func _eq(actual: int, expected: int, label: String) -> void:
	if _failed: return
	if actual != expected:
		_fail("%s — expected %d, got %d" % [label, expected, actual])

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	Campaign._load_manifest()
	print("[CampaignUnlockOrderTest] FAIL ", msg)
	get_tree().quit(1)
