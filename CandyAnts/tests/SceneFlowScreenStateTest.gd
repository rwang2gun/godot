extends Node

# Phase 13 — plan §3.5. TITLE → MAIN_MENU → STAGE_SELECT → STAGE → MAIN_MENU 라우팅.

const MainScene := preload("res://scenes/Main.tscn")
const TEST_PATH := "user://test_savedata_sceneflow_screen.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	var main: Node = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var sf = main.get_node("SceneFlow")
	# TITLE
	if sf.current_screen != sf.ScreenState.TITLE:
		return _fail("expected TITLE on boot, got %d" % sf.current_screen)
	if not _verify_root_child(main, "TitleScene"):
		return _fail("CurrentStageRoot should hold TitleScene")
	# request_main_menu → MAIN_MENU
	EventBus.request_main_menu.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.MAIN_MENU:
		return _fail("MAIN_MENU transition failed, got %d" % sf.current_screen)
	# request_stage_select → STAGE_SELECT
	EventBus.request_stage_select.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE_SELECT:
		return _fail("STAGE_SELECT transition failed, got %d" % sf.current_screen)
	# request_play_stage(1) → STAGE
	EventBus.request_play_stage.emit(1)
	await get_tree().process_frame
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE:
		return _fail("STAGE transition failed, got %d" % sf.current_screen)
	# request_menu (StageDialog alias) → MAIN_MENU
	EventBus.request_menu.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.MAIN_MENU:
		return _fail("request_menu alias → MAIN_MENU failed, got %d" % sf.current_screen)
	main.queue_free()
	await get_tree().process_frame
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SceneFlowScreenStateTest] PASS")
	get_tree().quit(0)

func _verify_root_child(main: Node, expected_class_substr: String) -> bool:
	var root: Node = main.get_node("CurrentStageRoot")
	if root.get_child_count() != 1:
		return false
	var child: Node = root.get_child(0)
	# expected class via has_method/has_node 등 또는 class_name 확인
	return child.get_class() == "Control" or expected_class_substr in str(child.get_script().resource_path) if child.get_script() != null else false

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[SceneFlowScreenStateTest] FAIL ", msg)
	get_tree().quit(1)
