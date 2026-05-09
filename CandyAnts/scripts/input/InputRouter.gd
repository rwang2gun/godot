extends Node

# Autoload — 단일 입력 진입점.
# - _unhandled_input(event): InputMap 액션 dispatch + raw InputEventMouseMotion → cursor_move synthetic
# - _process(delta): 패드 stick polling (Phase 6 본체, Phase 5는 가드 only)
#
# CURSOR_MOVE의 유일한 emit 경로 = _emit_cursor_move (cache 갱신 + 단일 발화). 그 외 직접 emit 금지.
# 좌표 변환은 CoordSpace 단일 SoT 사용. 디바이스 분기는 _resolve_position 내부에서만.
#
# class_name 의존(GameAction/CoordSpace)은 autoload 첫 로드 시점에 미해결되므로 preload로 우회.

const GameAction := preload("res://scripts/input/GameAction.gd")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

var _virtual_cursor: Control = null
var _virtual_cursor_initialized: bool = false
var _last_cursor_screen: Vector2 = Vector2.ZERO
var _last_cursor_world: Vector2 = Vector2.ZERO
var _last_cursor_valid: bool = false
# codex impl-stage round 1+2 MEDIUM 후속 — stale cache 자동 invalidate.
# cursor_move 시점의 (current_scene, canvas_xform) 컨텍스트를 함께 저장.
# _resolve_position에서 InputEventKey 분기 진입 시 컨텍스트가 달라졌으면 stale로 판정.
var _last_cursor_scene: Node = null
var _last_cursor_canvas_xform: Transform2D = Transform2D.IDENTITY


func _unhandled_input(event: InputEvent) -> void:
	# 1. 마우스 모션 → synthetic cursor_move (InputMap 미등록)
	if event is InputEventMouseMotion:
		_emit_cursor_move((event as InputEventMouseMotion).position)
		return
	# 2. InputMap 액션 dispatch
	_dispatch_input_map_action(event)


func _dispatch_input_map_action(event: InputEvent) -> void:
	for entry: Dictionary in GameAction.REGISTRY:
		var kind: String = entry["kind"]
		if kind != "input_map":
			continue
		var name: StringName = entry["name"]
		var exact_match: bool = entry["exact_match"]
		if not event.is_action_pressed(name, false, exact_match):
			continue
		if GameAction.is_positional(name):
			_emit_positional(name, event)
		else:
			EventBus.action_triggered.emit(name, {})
		var vp: Viewport = get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		return  # 첫 매칭 액션만 처리


func _emit_positional(action: StringName, event: InputEvent) -> void:
	var pos: Dictionary = _resolve_position(event)
	if not pos.get("position_valid", false):
		var payload_invalid: Dictionary = {"position_valid": false}
		if action == GameAction.TARGET_NEXT_ANT or action == GameAction.TARGET_PREV_ANT:
			payload_invalid["from_world_pos"] = Vector2.ZERO
		EventBus.action_triggered.emit(action, payload_invalid)
		return
	var screen_pos: Vector2 = pos["screen_pos"]
	if action == GameAction.CURSOR_MOVE:
		_emit_cursor_move(screen_pos)
		return
	var vp: Viewport = get_viewport()
	var world: Vector2 = CoordSpace.screen_to_world(screen_pos, vp)
	var payload: Dictionary = {
		"position_valid": true,
		"screen_pos": screen_pos,
		"world_pos": world,
	}
	# Tab/Shift+Tab 액션은 from_world_pos 키 (INPUT_PLAN §5.3 표)
	if action == GameAction.TARGET_NEXT_ANT or action == GameAction.TARGET_PREV_ANT:
		payload = {
			"position_valid": true,
			"screen_pos": screen_pos,
			"from_world_pos": world,
		}
	EventBus.action_triggered.emit(action, payload)


func _resolve_position(event: InputEvent) -> Dictionary:
	if event is InputEventMouse:
		return {"position_valid": true, "screen_pos": (event as InputEventMouse).position}
	if event is InputEventScreenTouch:
		return {"position_valid": true, "screen_pos": (event as InputEventScreenTouch).position}
	if event is InputEventScreenDrag:
		return {"position_valid": true, "screen_pos": (event as InputEventScreenDrag).position}
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not _ensure_virtual_cursor_ready():
			return {"position_valid": false, "screen_pos": Vector2.ZERO}
		return {"position_valid": true, "screen_pos": _virtual_cursor.position}
	if event is InputEventKey:
		if not _last_cursor_valid:
			return {"position_valid": false, "screen_pos": Vector2.ZERO}
		# Stale 컨텍스트 가드 (codex round 1+2): cursor_move 시점의 scene + canvas_xform과
		# 현재가 다르면 cache 폐기 + invalid 리턴. scene 전환 / Camera2D 이동 자동 감지.
		var vp: Viewport = get_viewport()
		var current_scene: Node = get_tree().current_scene if get_tree() != null else null
		var current_xform: Transform2D = vp.get_canvas_transform() if vp != null else Transform2D.IDENTITY
		if _last_cursor_scene != current_scene or _last_cursor_canvas_xform != current_xform:
			clear_cursor_cache()
			return {"position_valid": false, "screen_pos": Vector2.ZERO}
		return {"position_valid": true, "screen_pos": _last_cursor_screen}
	push_error("[InputRouter] unknown event type for positional action: %s" % event)
	return {"position_valid": false, "screen_pos": Vector2.ZERO}


func _ensure_virtual_cursor_ready() -> bool:
	# Phase 6에서 set_virtual_cursor 호출 후 lazy init. Phase 5는 항상 false.
	if _virtual_cursor == null:
		return false
	if _virtual_cursor_initialized:
		return true
	# Phase 6에서 viewport center로 초기 위치 설정 + emit_cursor_move(viewport_center).
	_virtual_cursor_initialized = true
	return true


func _emit_cursor_move(screen_pos: Vector2) -> void:
	# CURSOR_MOVE의 유일한 emit 경로. cache 갱신 + EventBus emit.
	var vp: Viewport = get_viewport()
	var world: Vector2 = CoordSpace.screen_to_world(screen_pos, vp)
	_last_cursor_screen = screen_pos
	_last_cursor_world = world
	_last_cursor_valid = true
	# 컨텍스트 동시 캡처 — _resolve_position InputEventKey 분기에서 stale 검출용.
	_last_cursor_scene = get_tree().current_scene if get_tree() != null else null
	_last_cursor_canvas_xform = vp.get_canvas_transform() if vp != null else Transform2D.IDENTITY
	EventBus.action_triggered.emit(GameAction.CURSOR_MOVE, {
		"position_valid": true,
		"screen_pos": screen_pos,
		"world_pos": world,
	})


func _process(_delta: float) -> void:
	# Phase 6에서 패드 stick polling 본체. Phase 5는 가드 only.
	if not _has_pad_connected():
		return
	# Phase 6 본체 — 좌 스틱 → cursor_move, 우 스틱 → camera_pan, LT/RT → camera_zoom


func _has_pad_connected() -> bool:
	return Input.get_connected_joypads().size() > 0


func set_virtual_cursor(c: Control) -> void:
	# Phase 6 주입 hook. Phase 5에서는 호출자 없음.
	_virtual_cursor = c
	_virtual_cursor_initialized = false


func clear_cursor_cache() -> void:
	# Autoload 자체는 scene 전환 시 살아남는다. _last_cursor_* cache는
	# 이전 viewport/canvas_xform 컨텍스트에서 측정된 값이므로 새 scene에서는 stale.
	# 자동 invalidate 경로 (codex round 1+2): _resolve_position InputEventKey 분기에서
	# scene/canvas_xform 비교로 검출 → 본 함수 호출. 외부에서도 강제 호출 가능 (테스트, 명시적 hook).
	_last_cursor_screen = Vector2.ZERO
	_last_cursor_world = Vector2.ZERO
	_last_cursor_valid = false
	_last_cursor_scene = null
	_last_cursor_canvas_xform = Transform2D.IDENTITY
