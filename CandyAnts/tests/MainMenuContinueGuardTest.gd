extends Node

# Phase 13 — plan Δ4. Continue 가드 4 케이스.

const MainMenuScene := preload("res://scenes/ui/MainMenu.tscn")
const TEST_PATH := "user://test_savedata_continue.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	await _case(0, false, "(a) last=0 → disabled")
	if _failed: return
	await _case(99, false, "(b) last=99 (SceneFlow 미존재) → disabled")
	if _failed: return
	await _case_with_progression(2, false, "(c) last=2 unlocked=false → disabled")
	if _failed: return
	await _case_with_progression(2, true, "(d) last=2 unlocked=true → enabled")
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[MainMenuContinueGuardTest] PASS")
	get_tree().quit(0)

func _case(last_id: int, expect_enabled: bool, label: String) -> void:
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	SaveData.last_played_stage = last_id
	var menu: Control = MainMenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var continue_btn: Button = menu.get_node("Center/VBox/ContinueBtn")
	if continue_btn.disabled == expect_enabled:
		menu.queue_free()
		return _fail("%s: disabled=%s, expected disabled=%s" % [label, continue_btn.disabled, not expect_enabled])
	menu.queue_free()
	await get_tree().process_frame
	print("[MainMenuContinueGuardTest] %s OK" % label)

func _case_with_progression(last_id: int, set_unlocked: bool, label: String) -> void:
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	if set_unlocked:
		# Mark stage(last_id - 1) as cleared so is_unlocked(last_id) → true
		EventBus.stage_cleared.emit({"stage_id": last_id - 1, "cleared": true, "saved": 10, "original_hp": 10})
		await get_tree().process_frame
	SaveData.last_played_stage = last_id
	var menu: Control = MainMenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var continue_btn: Button = menu.get_node("Center/VBox/ContinueBtn")
	# expect_enabled = set_unlocked
	if continue_btn.disabled == set_unlocked:
		menu.queue_free()
		return _fail("%s: disabled=%s, expected disabled=%s" % [label, continue_btn.disabled, not set_unlocked])
	menu.queue_free()
	await get_tree().process_frame
	print("[MainMenuContinueGuardTest] %s OK" % label)

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[MainMenuContinueGuardTest] FAIL ", msg)
	get_tree().quit(1)
