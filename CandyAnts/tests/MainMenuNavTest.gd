extends Node

# Phase 13 — plan §3.6.2.

const MainMenuScene := preload("res://scenes/ui/MainMenu.tscn")
const TEST_PATH := "user://test_savedata_mainmenu_nav.cfg"

var _orig_path: String
var _play_emit: Array[int] = []
var _select_emit: int = 0

func _ready() -> void:
	_orig_path = SaveData._save_path
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)
	# Set up: last_played=2 + stage1 cleared (so continue is valid)
	EventBus.stage_cleared.emit({"stage_id": 1, "cleared": true, "saved": 10, "original_hp": 10})
	await get_tree().process_frame
	SaveData.last_played_stage = 2
	SaveData.save()
	EventBus.request_play_stage.connect(func(id: int): _play_emit.append(id))
	# campaign-50 — StageSelectBtn은 이제 request_chapter_select(무인자)를 emit(ChapterSelect 진입).
	EventBus.request_chapter_select.connect(func(): _select_emit += 1)
	var menu: Control = MainMenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	# campaign-50 — PlayBtn → request_play_stage(next_unlocked_stage). stage1 cleared이므로 첫 미클리어=2.
	var expected_play: int = Campaign.next_unlocked_stage()
	if expected_play != 2:
		return _fail("precondition: next_unlocked_stage expected 2 (stage1 cleared), got %d" % expected_play)
	menu.get_node("Center/VBox/PlayBtn").pressed.emit()
	await get_tree().process_frame
	if _play_emit.size() != 1 or _play_emit[0] != expected_play:
		return _fail("Play → request_play_stage(%d) failed, got %s" % [expected_play, str(_play_emit)])
	# ContinueBtn → request_play_stage(last_played=2)
	menu.get_node("Center/VBox/ContinueBtn").pressed.emit()
	await get_tree().process_frame
	if _play_emit.size() != 2 or _play_emit[1] != 2:
		return _fail("Continue → request_play_stage(2) failed, got %s" % str(_play_emit))
	# StageSelectBtn → request_chapter_select
	menu.get_node("Center/VBox/StageSelectBtn").pressed.emit()
	await get_tree().process_frame
	if _select_emit != 1:
		return _fail("ChapterSelect emit failed, got %d" % _select_emit)
	# SettingsBtn → ComingSoonOverlay visible (request_* 0)
	var coming_soon: Control = menu.get_node("ComingSoonOverlay")
	menu.get_node("Center/VBox/SettingsBtn").pressed.emit()
	await get_tree().process_frame
	if not coming_soon.visible:
		return _fail("Settings click should show ComingSoonOverlay")
	if _play_emit.size() != 2 or _select_emit != 1:
		return _fail("Settings click leaked emits")
	# Cleanup
	_cleanup()
	print("[MainMenuNavTest] PASS")
	get_tree().quit(0)

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)

func _fail(msg: String) -> void:
	_cleanup()
	print("[MainMenuNavTest] FAIL ", msg)
	get_tree().quit(1)
