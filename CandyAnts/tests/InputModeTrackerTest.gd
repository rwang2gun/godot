extends Node

# Phase 8 — InputModeTracker mouse/pad/touch 분류 + KB 무시 + spam 차단.

var _captured: Array = []  # [{mode}]


func _ready() -> void:
	EventBus.input_mode_changed.connect(_on_mode_changed)
	await get_tree().process_frame

	if not _case_a_initial_mode():
		_fail("case-A: 초기 mode=mouse"); return
	if not await _case_b_pad_event():
		_fail("case-B: pad event → pad emit"); return
	if not await _case_c_pad_spam_blocked():
		_fail("case-C: 연속 pad event는 추가 emit 없음"); return
	if not await _case_d_mouse_event():
		_fail("case-D: mouse motion → mouse emit"); return
	if not await _case_e_key_event_ignored():
		_fail("case-E: KB event는 mode 변경 없음"); return
	if not await _case_f_touch_event():
		_fail("case-F: touch event → touch emit"); return

	print("[InputModeTrackerTest] PASS")
	get_tree().quit(0)


func _on_mode_changed(mode: StringName) -> void:
	_captured.append({"mode": mode})


func _case_a_initial_mode() -> bool:
	if InputModeTracker.get_mode() != &"mouse":
		push_error("[InputModeTrackerTest] case-A: get_mode=%s" % InputModeTracker.get_mode()); return false
	return true


func _case_b_pad_event() -> bool:
	_captured.clear()
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = 0.5
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	if _captured.size() != 1 or _captured[0]["mode"] != &"pad":
		push_error("[InputModeTrackerTest] case-B: captured=%s" % _captured); return false
	if InputModeTracker.get_mode() != &"pad":
		push_error("[InputModeTrackerTest] case-B: get_mode=%s" % InputModeTracker.get_mode()); return false
	return true


func _case_c_pad_spam_blocked() -> bool:
	_captured.clear()
	# 이미 mode=pad — 추가 pad event는 emit 없어야 함.
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	if _captured.size() != 0:
		push_error("[InputModeTrackerTest] case-C: spam emit %d개" % _captured.size()); return false
	return true


func _case_d_mouse_event() -> bool:
	_captured.clear()
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(100, 100)
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	if _captured.size() != 1 or _captured[0]["mode"] != &"mouse":
		push_error("[InputModeTrackerTest] case-D: captured=%s" % _captured); return false
	return true


func _case_e_key_event_ignored() -> bool:
	_captured.clear()
	var prev: StringName = InputModeTracker.get_mode()
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	if _captured.size() != 0:
		push_error("[InputModeTrackerTest] case-E: KB가 emit 유발 %d개" % _captured.size()); return false
	if InputModeTracker.get_mode() != prev:
		push_error("[InputModeTrackerTest] case-E: mode 변경됨 %s → %s" % [prev, InputModeTracker.get_mode()]); return false
	return true


func _case_f_touch_event() -> bool:
	_captured.clear()
	var ev := InputEventScreenTouch.new()
	ev.position = Vector2(50, 50)
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	if _captured.size() != 1 or _captured[0]["mode"] != &"touch":
		push_error("[InputModeTrackerTest] case-F: captured=%s" % _captured); return false
	return true


func _fail(label: String) -> void:
	push_error("[InputModeTrackerTest] FAIL %s" % label)
	print("[InputModeTrackerTest] FAIL %s" % label)
	get_tree().quit(1)
