extends Node

const TEST_PATH := "user://test_savedata_unlock.cfg"
var _orig_path: String

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	# stage1 항상 unlocked
	if not SaveData.is_unlocked(1):
		return _fail("stage1 should always be unlocked")
	# stage2 잠금 (stage1 미클리어)
	if SaveData.is_unlocked(2):
		return _fail("stage2 should be locked initially")
	# stage1 clear → stage2 unlock, stage3 lock
	EventBus.stage_cleared.emit({"stage_id": 1, "cleared": true, "saved": 6, "original_hp": 10})
	await get_tree().process_frame
	if not SaveData.is_unlocked(2):
		return _fail("stage2 should unlock after stage1 cleared")
	if SaveData.is_unlocked(3):
		return _fail("stage3 should still be locked")
	# stage2 clear → stage3 unlock
	EventBus.stage_cleared.emit({"stage_id": 2, "cleared": true, "saved": 10, "original_hp": 10})
	await get_tree().process_frame
	if not SaveData.is_unlocked(3):
		return _fail("stage3 should unlock after stage2 cleared")
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataIsUnlockedTest] PASS")
	get_tree().quit(0)

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SaveDataIsUnlockedTest] FAIL ", msg)
	get_tree().quit(1)
