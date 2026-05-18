extends Node

# Phase 13 — TDD stub for SaveData autoload.

func _ready() -> void:
	if SaveData == null:
		_fail("SaveData autoload missing")
		return
	if not SaveData.has_method("load_or_init"):
		_fail("SaveData.load_or_init missing")
		return
	if not SaveData.has_method("record_clear"):
		_fail("SaveData.record_clear missing")
		return
	if not SaveData.has_method("record_attempt"):
		_fail("SaveData.record_attempt missing")
		return
	if not SaveData.has_method("is_unlocked"):
		_fail("SaveData.is_unlocked missing")
		return
	if not SaveData.has_method("total_stars"):
		_fail("SaveData.total_stars missing")
		return
	print("[test_SaveData] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[test_SaveData] FAIL ", msg)
	get_tree().quit(1)
