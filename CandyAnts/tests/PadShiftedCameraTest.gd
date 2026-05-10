extends Node2D

# Phase 7 — shifted Camera2D + cursor (400,300) pre-init → 패드 A → world_pos가
# CoordSpace.screen_to_world(Vector2(400,300), viewport)와 일치 + 그 world에 배치한 ant 반환 검증.

const GameAction := preload("res://scripts/input/GameAction.gd")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

var _captured: Array = []


func _ready() -> void:
	# Camera2D shift + zoom 적용.
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(500, 300)
	cam.zoom = Vector2(1.5, 1.5)
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame

	EventBus.action_triggered.connect(_on_action)

	# VirtualCursor stub 주입 후 강제 init(cursor.position 직접 설정).
	var cursor: Control = Control.new()
	add_child(cursor)
	InputRouter.set_virtual_cursor(cursor)
	# _ensure_virtual_cursor_ready를 우회 init: 먼저 한번 lazy-init 발동 → 그 다음 위치 덮어쓰기.
	# joypad event 1회 주입해 init만 트리거 → 그 후 cursor.position 직접 설정 + 두 번째 주입.
	var seed := InputEventJoypadButton.new()
	seed.button_index = JOY_BUTTON_A
	seed.pressed = true
	Input.parse_input_event(seed)
	await get_tree().process_frame
	await get_tree().process_frame
	# 첫 번째 emit은 viewport center 기반 — 무시.
	_captured.clear()

	# 이제 cursor 직접 (400, 300)으로 설정 후 다시 A 주입.
	cursor.position = Vector2(400, 300)
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
		_fail("payload position_valid != true"); return
	if payload["screen_pos"] != Vector2(400, 300):
		_fail("screen_pos %s != (400,300)" % str(payload["screen_pos"])); return
	var expected_world: Vector2 = CoordSpace.screen_to_world(Vector2(400, 300), get_viewport())
	if not payload["world_pos"].is_equal_approx(expected_world):
		_fail("world_pos %s != expected %s (canvas_xform inverse)" % [str(payload["world_pos"]), str(expected_world)])
		return
	print("[PadShiftedCameraTest] PASS world_pos=", payload["world_pos"], " expected=", expected_world)
	get_tree().quit(0)


func _on_action(name: StringName, payload: Dictionary) -> void:
	_captured.append({"name": name, "payload": payload})


func _find(name: StringName) -> Dictionary:
	for c in _captured:
		if c["name"] == name:
			return c
	return {}


func _fail(msg: String) -> void:
	push_error("[PadShiftedCameraTest] FAIL %s" % msg)
	get_tree().quit(1)
