extends Node

# Phase 7 — VirtualCursor 주입 후 패드 A → skill_assign valid payload 검증.
# JoyButton A는 InputMap에 등록 — Input.action_press를 통해 시뮬.

const GameAction := preload("res://scripts/input/GameAction.gd")

var _captured: Array = []


func _ready() -> void:
	EventBus.action_triggered.connect(_on_action)
	# VirtualCursor stub 주입.
	var cursor: Control = Control.new()
	cursor.name = "FakeCursor"
	add_child(cursor)
	cursor.position = Vector2(400, 300)
	InputRouter.set_virtual_cursor(cursor)
	await get_tree().process_frame
	# 패드 A — raw InputEventJoypadButton(button_index=0) 주입 → InputMap dispatch.
	_captured.clear()
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame
	var hit: Dictionary = _find(GameAction.SKILL_ASSIGN)
	if hit.is_empty():
		_fail("skill_assign emit missing"); return
	var payload: Dictionary = hit["payload"]
	if not payload.get("position_valid", false):
		_fail("skill_assign payload position_valid should be true after VirtualCursor injection"); return
	if not payload.has("world_pos") or not payload.has("screen_pos"):
		_fail("skill_assign payload missing screen/world keys"); return
	# screen_pos는 _ensure_virtual_cursor_ready의 lazy-init으로 viewport center가 들어옴 (첫 emit).
	# 정확한 (400,300) 검증은 PadShiftedCameraTest에서 cursor pre-init 후 수행.
	# 본 테스트는 valid 경로 자체와 payload 구조만 검증.
	print("[PadInputTest] PASS payload=", payload)
	get_tree().quit(0)


func _on_action(name: StringName, payload: Dictionary) -> void:
	_captured.append({"name": name, "payload": payload})


func _find(name: StringName) -> Dictionary:
	for c in _captured:
		if c["name"] == name:
			return c
	return {}


func _fail(msg: String) -> void:
	push_error("[PadInputTest] FAIL %s" % msg)
	get_tree().quit(1)
