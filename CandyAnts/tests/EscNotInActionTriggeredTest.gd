extends Node

# Phase 13 — plan Δ11 ★MED-D 회귀 가드.
# ESC press → action_triggered가 ESC 관련 액션(`back_menu`, `skill_cancel` 등)으로 emit되지 않음.

const MainScene := preload("res://scenes/Main.tscn")
const TEST_PATH := "user://test_savedata_escnotinaction.cfg"

const ESC_RELATED_ACTIONS := [
	&"back_menu",
	# skill_cancel은 우클릭/Ctrl 등으로 발화 가능하지만 ESC 단독으로는 안 됨.
]

var _orig_path: String
var _violations: Array[StringName] = []

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

	EventBus.action_triggered.connect(_on_action)

	# ESC press
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	var rel := InputEventKey.new()
	rel.keycode = KEY_ESCAPE
	rel.pressed = false
	Input.parse_input_event(rel)

	await get_tree().process_frame
	await get_tree().process_frame

	EventBus.action_triggered.disconnect(_on_action)

	if _violations.size() > 0:
		return _fail("ESC triggered actions: %s" % str(_violations))

	main.queue_free()
	await get_tree().process_frame
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[EscNotInActionTriggeredTest] PASS")
	get_tree().quit(0)

func _on_action(name: StringName, _payload: Dictionary) -> void:
	if name in ESC_RELATED_ACTIONS:
		_violations.append(name)

func _fail(msg: String) -> void:
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[EscNotInActionTriggeredTest] FAIL ", msg)
	get_tree().quit(1)
