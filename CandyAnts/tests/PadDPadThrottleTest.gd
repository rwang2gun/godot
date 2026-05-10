extends Node

# Phase 7 — D-Pad 같은 방향 100ms 이내 두 번째는 throttle (silent skip).
# 방향 전환은 즉시 허용(per-direction throttle).

const GameAction := preload("res://scripts/input/GameAction.gd")

var _captured: Array = []


func _ready() -> void:
	EventBus.action_triggered.connect(_on_action)
	# VirtualCursor stub + cache valid 만들기 위해 한번 init.
	var cursor: Control = Control.new()
	add_child(cursor)
	InputRouter.set_virtual_cursor(cursor)

	# 같은 방향 (DPAD_RIGHT → target_next_ant) 두 번 50ms 간격 → 첫 번째만 emit.
	_captured.clear()
	var ev1 := InputEventJoypadButton.new()
	ev1.button_index = JOY_BUTTON_DPAD_RIGHT
	ev1.pressed = true
	Input.parse_input_event(ev1)
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout  # 50ms
	var ev2 := InputEventJoypadButton.new()
	ev2.button_index = JOY_BUTTON_DPAD_RIGHT
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await get_tree().process_frame
	if _count(GameAction.TARGET_NEXT_ANT) != 1:
		_fail("same-direction 50ms apart should emit once, got %d" % _count(GameAction.TARGET_NEXT_ANT))
		return

	# 방향 전환 (DPAD_LEFT) 즉시 허용 — per-direction throttle.
	_captured.clear()
	var ev3 := InputEventJoypadButton.new()
	ev3.button_index = JOY_BUTTON_DPAD_LEFT
	ev3.pressed = true
	Input.parse_input_event(ev3)
	await get_tree().process_frame
	await get_tree().process_frame
	if _count(GameAction.TARGET_PREV_ANT) != 1:
		_fail("direction switch should emit immediately, got %d" % _count(GameAction.TARGET_PREV_ANT))
		return

	# 같은 방향 100ms 이상 후 다시 → 통과.
	_captured.clear()
	await get_tree().create_timer(0.15).timeout  # 150ms (100ms 이상 대기)
	var ev4 := InputEventJoypadButton.new()
	ev4.button_index = JOY_BUTTON_DPAD_RIGHT
	ev4.pressed = true
	Input.parse_input_event(ev4)
	await get_tree().process_frame
	if _count(GameAction.TARGET_NEXT_ANT) != 1:
		_fail("after cooldown next emit should pass, got %d" % _count(GameAction.TARGET_NEXT_ANT))
		return

	print("[PadDPadThrottleTest] PASS")
	get_tree().quit(0)


func _on_action(name: StringName, _payload: Dictionary) -> void:
	_captured.append(name)


func _count(name: StringName) -> int:
	var c: int = 0
	for n in _captured:
		if n == name:
			c += 1
	return c


func _fail(msg: String) -> void:
	push_error("[PadDPadThrottleTest] FAIL %s" % msg)
	get_tree().quit(1)
