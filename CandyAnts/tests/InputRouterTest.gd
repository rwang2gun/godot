extends Node

# Phase 5 CRITICAL 회귀 가드 — EventBus.action_triggered emit 정확성 + payload validity 계약.
#
# case-A: 마우스 motion → cursor_move emit + cache 갱신
# case-B: 마우스 좌클릭 → skill_assign emit
# case-C: Esc → 무 발화 검증 (codex review HIGH Round 15+16 후속)
# case-D: 슬롯 키 1~8 → skill_select_n
# case-E: Q/E → skill_cycle_*, Tab/Shift+Tab → target_*_ant + Ctrl+R → restart_stage exact_match 가드
# case-F: modifier-tolerant 마우스/키 (Ctrl+click, Shift+우클릭, Shift+1)
# case-G: deferred 가드 sanity (camera_pan/camera_zoom/back_menu/nuke 미등록)

const GameAction := preload("res://scripts/input/GameAction.gd")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

var _captured: Array[Dictionary] = []  # [{name, payload}]


func _ready() -> void:
	EventBus.action_triggered.connect(_on_action)
	await get_tree().process_frame
	if not await _case_a():
		_fail("case-A 마우스 motion → cursor_move"); return
	if not await _case_b():
		_fail("case-B 좌클릭 → skill_assign"); return
	if not await _case_c():
		_fail("case-C Esc → 무 발화"); return
	if not await _case_d():
		_fail("case-D 슬롯 키 → skill_select_n"); return
	if not await _case_e():
		_fail("case-E Q/E/Tab/Shift+Tab/Ctrl+R"); return
	if not await _case_f():
		_fail("case-F modifier-tolerant"); return
	if not _case_g():
		_fail("case-G deferred 가드"); return
	print("[InputRouterTest] PASS")
	get_tree().quit(0)


func _on_action(name: StringName, payload: Dictionary) -> void:
	_captured.append({"name": name, "payload": payload})


func _clear() -> void:
	_captured.clear()


func _inject_and_flush(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _find(name: StringName) -> Dictionary:
	for c in _captured:
		if c["name"] == name:
			return c
	return {}


func _case_a() -> bool:
	# Note: Godot 헤드리스에서 window/viewport stretch가 InputEvent.position을 스케일링한다.
	# 정확한 좌표 비교는 stretch-aware 테스트(InputRouterShiftedCameraTest, InputOriginAtZeroTest)에서.
	# 본 case는 emit 발생 + payload 키/타입 + world == screen_to_world(screen) 자기일관 검증.
	_clear()
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(150, 250)
	await _inject_and_flush(ev)
	var hit: Dictionary = _find(GameAction.CURSOR_MOVE)
	if hit.is_empty():
		push_error("[InputRouterTest] case-A: CURSOR_MOVE not emitted (got %d events)" % _captured.size())
		return false
	var p: Dictionary = hit["payload"]
	if not p.get("position_valid", false):
		push_error("[InputRouterTest] case-A: position_valid != true")
		return false
	if not p.has("screen_pos") or not p.has("world_pos"):
		push_error("[InputRouterTest] case-A: missing screen_pos or world_pos in payload: %s" % p)
		return false
	# self-consistency: world_pos == screen_to_world(screen_pos) by InputRouter
	var expected_world: Vector2 = CoordSpace.screen_to_world(p["screen_pos"], get_viewport())
	if p["world_pos"] != expected_world:
		push_error("[InputRouterTest] case-A: world_pos %s != screen_to_world(%s)=%s" % [p["world_pos"], p["screen_pos"], expected_world])
		return false
	return true


func _case_b() -> bool:
	_clear()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(100, 200)
	await _inject_and_flush(ev)
	var hit: Dictionary = _find(GameAction.SKILL_ASSIGN)
	if hit.is_empty():
		push_error("[InputRouterTest] case-B: SKILL_ASSIGN not emitted")
		return false
	var p: Dictionary = hit["payload"]
	if not p.get("position_valid", false):
		push_error("[InputRouterTest] case-B: position_valid != true")
		return false
	if not p.has("screen_pos") or not p.has("world_pos"):
		push_error("[InputRouterTest] case-B: payload missing screen_pos/world_pos")
		return false
	return true


func _case_c() -> bool:
	# codex review HIGH Round 15+16: phase 5에서 Esc는 어떤 액션도 emit 안 함.
	_clear()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	await _inject_and_flush(ev)
	if _captured.size() != 0:
		push_error("[InputRouterTest] case-C: Esc emitted %d action(s), expected 0: %s" % [_captured.size(), _captured])
		return false
	return true


func _case_d() -> bool:
	for slot in range(8):
		_clear()
		var ev := InputEventKey.new()
		ev.keycode = KEY_1 + slot
		ev.pressed = true
		await _inject_and_flush(ev)
		var expected: StringName = GameAction.SKILL_SELECT_BY_SLOT[slot]
		var hit: Dictionary = _find(expected)
		if hit.is_empty():
			push_error("[InputRouterTest] case-D: %s not emitted (slot %d)" % [expected, slot])
			return false
	return true


func _case_e() -> bool:
	_clear()
	var q := InputEventKey.new(); q.keycode = KEY_Q; q.pressed = true
	await _inject_and_flush(q)
	if _find(GameAction.SKILL_CYCLE_PREV).is_empty():
		push_error("[InputRouterTest] case-E: Q → SKILL_CYCLE_PREV missing"); return false

	_clear()
	var e := InputEventKey.new(); e.keycode = KEY_E; e.pressed = true
	await _inject_and_flush(e)
	if _find(GameAction.SKILL_CYCLE_NEXT).is_empty():
		push_error("[InputRouterTest] case-E: E → SKILL_CYCLE_NEXT missing"); return false

	# Cache 채우기 위해 mouse motion 1회
	_clear()
	var motion := InputEventMouseMotion.new(); motion.position = Vector2(300, 400)
	await _inject_and_flush(motion)

	# Tab → TARGET_NEXT_ANT (cache fresh → position_valid true + from_world_pos)
	_clear()
	var tab := InputEventKey.new(); tab.keycode = KEY_TAB; tab.pressed = true
	await _inject_and_flush(tab)
	var tab_hit: Dictionary = _find(GameAction.TARGET_NEXT_ANT)
	if tab_hit.is_empty():
		push_error("[InputRouterTest] case-E: Tab → TARGET_NEXT_ANT missing"); return false
	if not tab_hit["payload"].get("position_valid", false):
		push_error("[InputRouterTest] case-E: Tab payload position_valid != true"); return false
	if not tab_hit["payload"].has("from_world_pos"):
		push_error("[InputRouterTest] case-E: Tab payload missing from_world_pos key"); return false

	# Shift+Tab → TARGET_PREV_ANT only (exact_match 가드)
	_clear()
	var stab := InputEventKey.new(); stab.keycode = KEY_TAB; stab.shift_pressed = true; stab.pressed = true
	await _inject_and_flush(stab)
	if _find(GameAction.TARGET_PREV_ANT).is_empty():
		push_error("[InputRouterTest] case-E: Shift+Tab → TARGET_PREV_ANT missing"); return false
	if not _find(GameAction.TARGET_NEXT_ANT).is_empty():
		push_error("[InputRouterTest] case-E: Shift+Tab leaked to TARGET_NEXT_ANT (exact_match=true broken)"); return false

	# Ctrl+R → RESTART_STAGE
	_clear()
	var ctrlr := InputEventKey.new(); ctrlr.keycode = KEY_R; ctrlr.ctrl_pressed = true; ctrlr.pressed = true
	await _inject_and_flush(ctrlr)
	if _find(GameAction.RESTART_STAGE).is_empty():
		push_error("[InputRouterTest] case-E: Ctrl+R → RESTART_STAGE missing"); return false
	return true


func _case_f() -> bool:
	# Ctrl+좌클릭 → SKILL_ASSIGN (modifier-tolerant)
	_clear()
	var cclick := InputEventMouseButton.new()
	cclick.button_index = MOUSE_BUTTON_LEFT
	cclick.ctrl_pressed = true
	cclick.pressed = true
	cclick.position = Vector2(100, 200)
	await _inject_and_flush(cclick)
	if _find(GameAction.SKILL_ASSIGN).is_empty():
		push_error("[InputRouterTest] case-F: Ctrl+click → SKILL_ASSIGN missing"); return false
	# Shift+우클릭 → SKILL_CANCEL
	_clear()
	var srclick := InputEventMouseButton.new()
	srclick.button_index = MOUSE_BUTTON_RIGHT
	srclick.shift_pressed = true
	srclick.pressed = true
	await _inject_and_flush(srclick)
	if _find(GameAction.SKILL_CANCEL).is_empty():
		push_error("[InputRouterTest] case-F: Shift+우클릭 → SKILL_CANCEL missing"); return false
	# Shift+1 → SKILL_SELECT_1
	_clear()
	var s1 := InputEventKey.new(); s1.keycode = KEY_1; s1.shift_pressed = true; s1.pressed = true
	await _inject_and_flush(s1)
	if _find(GameAction.SKILL_SELECT_1).is_empty():
		push_error("[InputRouterTest] case-F: Shift+1 → SKILL_SELECT_1 missing"); return false
	return true


func _case_g() -> bool:
	for name in [&"camera_pan", &"camera_zoom", &"back_menu", &"nuke"]:
		if InputMap.has_action(name):
			push_error("[InputRouterTest] case-G: deferred action leaked: %s" % name)
			return false
	return true


func _fail(label: String) -> void:
	print("[InputRouterTest] FAIL %s" % label)
	get_tree().quit(1)
