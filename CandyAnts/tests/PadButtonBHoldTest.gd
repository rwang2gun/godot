extends Node

# Phase 7 — Pad B raw single-tap(0.9초 release) vs hold(1.1초 정확히 1회 RESTART_STAGE).
# B 버튼은 InputMap 미등록이고 InputRouter._on_pad_b raw 처리. 시뮬은 InputEventJoypadButton 직접 주입.

const GameAction := preload("res://scripts/input/GameAction.gd")

var _captured: Array = []


func _ready() -> void:
	EventBus.action_triggered.connect(_on_action)

	# === 시나리오 1: 단발 (release before 1초) → SKILL_CANCEL 1회, RESTART_STAGE 0회 ===
	_captured.clear()
	var press_a := InputEventJoypadButton.new()
	press_a.button_index = JOY_BUTTON_B
	press_a.pressed = true
	Input.parse_input_event(press_a)
	await get_tree().create_timer(0.3).timeout  # 0.3초 후 release(< 1.0)
	var rel_a := InputEventJoypadButton.new()
	rel_a.button_index = JOY_BUTTON_B
	rel_a.pressed = false
	Input.parse_input_event(rel_a)
	await get_tree().process_frame
	if _count(GameAction.SKILL_CANCEL) != 1:
		_fail("single-tap SKILL_CANCEL count != 1 (got %d)" % _count(GameAction.SKILL_CANCEL))
		return
	if _count(GameAction.RESTART_STAGE) != 0:
		_fail("single-tap RESTART_STAGE count != 0 (got %d)" % _count(GameAction.RESTART_STAGE))
		return

	# === 시나리오 2: 홀드 (>= 1초) → RESTART_STAGE 1회, SKILL_CANCEL 0회 ===
	_captured.clear()
	var press_b := InputEventJoypadButton.new()
	press_b.button_index = JOY_BUTTON_B
	press_b.pressed = true
	Input.parse_input_event(press_b)
	# 1.1초 대기 — _tick_b_button이 1초 도달 시 RESTART_STAGE emit + _b_pressed=false.
	await get_tree().create_timer(1.1).timeout
	# 직후 release event (이미 만료 → 무시되어야).
	var rel_b := InputEventJoypadButton.new()
	rel_b.button_index = JOY_BUTTON_B
	rel_b.pressed = false
	Input.parse_input_event(rel_b)
	await get_tree().process_frame
	if _count(GameAction.RESTART_STAGE) != 1:
		_fail("hold RESTART_STAGE count != 1 (got %d)" % _count(GameAction.RESTART_STAGE))
		return
	if _count(GameAction.SKILL_CANCEL) != 0:
		_fail("hold should not emit SKILL_CANCEL (got %d)" % _count(GameAction.SKILL_CANCEL))
		return

	print("[PadButtonBHoldTest] PASS")
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
	push_error("[PadButtonBHoldTest] FAIL %s" % msg)
	get_tree().quit(1)
