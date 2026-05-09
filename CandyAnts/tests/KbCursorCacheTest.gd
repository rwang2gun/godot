extends Node

# INPUT_PLAN §6.6 #11 phase 5 부분 (case A + D + E).
# B/C(패드)는 phase 6.

const GameAction := preload("res://scripts/input/GameAction.gd")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

var _captured: Array[Dictionary] = []


func _ready() -> void:
	EventBus.action_triggered.connect(_on_action)
	await get_tree().process_frame

	# (A) 마우스 motion → cache 갱신 → Tab 키 → TARGET_NEXT_ANT payload position_valid:true + from_world_pos
	_captured.clear()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 200)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame
	var move_hit: Dictionary = _find(GameAction.CURSOR_MOVE)
	if move_hit.is_empty():
		_fail("(A) cursor_move not emitted after mouse motion")
		return
	# InputRouter 내부 cache가 갱신됐는지는 Tab 후 응답으로 검증.
	_captured.clear()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await get_tree().process_frame
	await get_tree().process_frame
	var tab_hit: Dictionary = _find(GameAction.TARGET_NEXT_ANT)
	if tab_hit.is_empty():
		_fail("(A) TARGET_NEXT_ANT not emitted after Tab")
		return
	if not tab_hit["payload"].get("position_valid", false):
		_fail("(A) Tab payload position_valid != true (cache should be fresh after motion)")
		return
	if not tab_hit["payload"].has("from_world_pos"):
		_fail("(A) Tab payload missing from_world_pos key")
		return

	# (D) cursor_move 미발화 상태 Tab — codex impl-stage round 1+2 MEDIUM 후속 회귀 가드.
	# stale cache contract: scene 전환 후 cursor_move 미발화 상태에서 Tab 발화 시 위치 잘못 emit되지 않는지.
	# (D-1) 직접 clear API: InputRouter.clear_cursor_cache() 호출로 캐시 강제 invalidate.
	InputRouter.clear_cursor_cache()
	_captured.clear()
	var stale_tab := InputEventKey.new()
	stale_tab.keycode = KEY_TAB
	stale_tab.pressed = true
	Input.parse_input_event(stale_tab)
	await get_tree().process_frame
	await get_tree().process_frame
	var stale_hit: Dictionary = _find(GameAction.TARGET_NEXT_ANT)
	if stale_hit.is_empty():
		_fail("(D-1) TARGET_NEXT_ANT not emitted after stale-cache Tab (should still emit but with position_valid:false)")
		return
	if stale_hit["payload"].get("position_valid", true) != false:
		_fail("(D-1) Tab payload position_valid != false after clear_cursor_cache (stale cache contract broken)")
		return

	# (D-2) 자동 stale 감지 (codex round 2 핵심): cursor_move 후 Camera2D 추가/이동으로 canvas_xform 변경 →
	# Tab 주입 시 _resolve_position이 컨텍스트 차이 감지 → position_valid:false 자동 fallback.
	# (mouse motion으로 cache 채움 → Camera2D current로 canvas_xform 변경 → Tab 주입 → invalid assert.)
	_captured.clear()
	var motion2 := InputEventMouseMotion.new()
	motion2.position = Vector2(50, 60)
	Input.parse_input_event(motion2)
	await get_tree().process_frame
	await get_tree().process_frame
	# 이제 cache valid 상태에서 Camera2D를 추가해 canvas_xform 변경.
	var cam := Camera2D.new()
	cam.position = Vector2(777, 333)
	cam.zoom = Vector2(2.0, 2.0)
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	# canvas_xform 변경 확인 — Camera2D current 후 viewport.canvas_transform이 다를 것.
	# 이 시점 InputRouter는 cache invalid를 인지하지 못함 (scene_changed signal 미연결). 그러나
	# _resolve_position InputEventKey 분기가 컨텍스트 비교로 자동 검출.
	_captured.clear()
	var auto_tab := InputEventKey.new()
	auto_tab.keycode = KEY_TAB
	auto_tab.pressed = true
	Input.parse_input_event(auto_tab)
	await get_tree().process_frame
	await get_tree().process_frame
	var auto_hit: Dictionary = _find(GameAction.TARGET_NEXT_ANT)
	if auto_hit.is_empty():
		_fail("(D-2) TARGET_NEXT_ANT not emitted after canvas_xform change Tab")
		return
	if auto_hit["payload"].get("position_valid", true) != false:
		_fail("(D-2) Tab payload position_valid != false after canvas_xform change (auto-stale detection failed)")
		return

	# (E) stale mode 가드 — InputRouter는 InputModeTracker singleton 부재 환경에서도 동작.
	if Engine.has_singleton("InputModeTracker"):
		_fail("(E) InputModeTracker singleton exists in phase 5 (should be absent)")
		return

	print("[KbCursorCacheTest] PASS")
	get_tree().quit(0)


func _on_action(name: StringName, payload: Dictionary) -> void:
	_captured.append({"name": name, "payload": payload})


func _find(name: StringName) -> Dictionary:
	for c in _captured:
		if c["name"] == name:
			return c
	return {}


func _fail(msg: String) -> void:
	push_error("[KbCursorCacheTest] FAIL %s" % msg)
	print("[KbCursorCacheTest] FAIL %s" % msg)
	get_tree().quit(1)
