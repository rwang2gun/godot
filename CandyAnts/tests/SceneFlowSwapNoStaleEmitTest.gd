extends Node

# Phase 13 — plan Δ9 ★HIGH-1 회귀 가드.
# stage1 진입 → request_main_menu → 5 frame await → stale stage_cleared/failed emit 0.

const MainScene := preload("res://scenes/Main.tscn")
const TEST_PATH := "user://test_savedata_swap_no_stale.cfg"
var _orig_path: String

var _stale_cleared: int = 0
var _stale_failed: int = 0
var _baseline_set: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)
	var main: Node = MainScene.instantiate()
	var sf = main.get_node("SceneFlow")
	sf.boot_to_stage_id = 1
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE:
		return _fail("baseline not STAGE")

	# 카운터 초기화 + 구독 (baseline 이후 emit만 추적)
	EventBus.stage_cleared.connect(_on_stale_cleared)
	EventBus.stage_failed.connect(_on_stale_failed)
	_baseline_set = true

	# 메뉴 전이 트리거
	EventBus.request_main_menu.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.MAIN_MENU:
		return _fail("MAIN_MENU transition failed")
	# CurrentStageRoot에 옛 StageRunner가 남아있지 않은지
	var root: Node = main.get_node("CurrentStageRoot")
	for child in root.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("StageRunner.gd"):
			return _fail("old StageRunner still in tree after swap (race violation)")
	# process_mode 복귀
	if root.process_mode != Node.PROCESS_MODE_INHERIT:
		return _fail("CurrentStageRoot.process_mode not INHERIT, got %d" % root.process_mode)

	# 5 frame await → stale emit 0회 검증
	for i in 5:
		await get_tree().process_frame
	if _stale_cleared != 0 or _stale_failed != 0:
		return _fail("stale emit detected: cleared=%d, failed=%d" % [_stale_cleared, _stale_failed])

	EventBus.stage_cleared.disconnect(_on_stale_cleared)
	EventBus.stage_failed.disconnect(_on_stale_failed)
	main.queue_free()
	await get_tree().process_frame
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[SceneFlowSwapNoStaleEmitTest] PASS")
	get_tree().quit(0)

func _on_stale_cleared(_r: Dictionary) -> void:
	if _baseline_set:
		_stale_cleared += 1

func _on_stale_failed(_r: Dictionary) -> void:
	if _baseline_set:
		_stale_failed += 1

func _fail(msg: String) -> void:
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[SceneFlowSwapNoStaleEmitTest] FAIL ", msg)
	get_tree().quit(1)
