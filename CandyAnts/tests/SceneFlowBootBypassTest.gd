extends Node

# Phase 13 — plan Δ10. boot_to_stage_id export — add_child 전에 설정 → STAGE 직행.

const MainScene := preload("res://scenes/Main.tscn")
const TEST_PATH := "user://test_savedata_bootbypass.cfg"
var _orig_path: String

func _ready() -> void:
	_orig_path = SaveData._save_path
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)
	var main: Node = MainScene.instantiate()
	var sf = main.get_node("SceneFlow")
	# ★ add_child 전 export 설정 — _ready가 본 값으로 부트 (race-free)
	sf.boot_to_stage_id = 2
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE:
		return _fail("expected STAGE, got %d" % sf.current_screen)
	if sf._current_stage_id != 2:
		return _fail("expected stage_id=2, got %d" % sf._current_stage_id)
	main.queue_free()
	await get_tree().process_frame
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[SceneFlowBootBypassTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[SceneFlowBootBypassTest] FAIL ", msg)
	get_tree().quit(1)
