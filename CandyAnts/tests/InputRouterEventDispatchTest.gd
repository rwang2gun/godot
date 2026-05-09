extends Node

# INPUT_PLAN §6.6 #7의 phase 5 가능 부분 — InputEventMouse 분기 위주.
# Pad 분기는 phase 6에서 본 driver 확장.

const GameAction := preload("res://scripts/input/GameAction.gd")

var _captured: Array[Dictionary] = []


func _ready() -> void:
	EventBus.action_triggered.connect(_on_action)
	await get_tree().process_frame

	# InputEventMouseButton: skill_assign 매칭 + position 동봉
	_captured.clear()
	var btn := InputEventMouseButton.new()
	btn.button_index = MOUSE_BUTTON_LEFT
	btn.pressed = true
	btn.position = Vector2(100, 200)
	Input.parse_input_event(btn)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _has(GameAction.SKILL_ASSIGN):
		_fail("InputEventMouseButton 분기 → SKILL_ASSIGN missing")
		return

	# InputEventMouseMotion: cursor_move 분기
	_captured.clear()
	var mot := InputEventMouseMotion.new()
	mot.position = Vector2(150, 250)
	Input.parse_input_event(mot)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _has(GameAction.CURSOR_MOVE):
		_fail("InputEventMouseMotion 분기 → CURSOR_MOVE missing")
		return
	# Mouse 분기 payload는 position_valid:true + screen_pos + world_pos 셋 다 존재
	var hit: Dictionary = _find(GameAction.CURSOR_MOVE)
	var p: Dictionary = hit["payload"]
	if not p.get("position_valid", false) or not p.has("screen_pos") or not p.has("world_pos"):
		_fail("CURSOR_MOVE payload 누락: %s" % p)
		return

	print("[InputRouterEventDispatchTest] PASS")
	get_tree().quit(0)


func _on_action(name: StringName, payload: Dictionary) -> void:
	_captured.append({"name": name, "payload": payload})


func _has(name: StringName) -> bool:
	for c in _captured:
		if c["name"] == name:
			return true
	return false


func _find(name: StringName) -> Dictionary:
	for c in _captured:
		if c["name"] == name:
			return c
	return {}


func _fail(msg: String) -> void:
	push_error("[InputRouterEventDispatchTest] FAIL %s" % msg)
	print("[InputRouterEventDispatchTest] FAIL %s" % msg)
	get_tree().quit(1)
