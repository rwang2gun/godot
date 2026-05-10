extends Node

# Autoload — 단일 입력 진입점.
# - _unhandled_input(event): Pad B raw 처리 우선 → InputMap 액션 dispatch + raw InputEventMouseMotion → cursor_move synthetic
# - _process(delta): 패드 stick polling (Phase 7) + B-hold timer
#
# CURSOR_MOVE의 유일한 emit 경로 = _emit_cursor_move (cache 갱신 + 단일 발화). 그 외 직접 emit 금지.
# 좌표 변환은 CoordSpace 단일 SoT 사용. 디바이스 분기는 _resolve_position 내부에서만.
#
# class_name 의존(GameAction/CoordSpace)은 autoload 첫 로드 시점에 미해결되므로 preload로 우회.

const GameAction := preload("res://scripts/input/GameAction.gd")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

const B_HOLD_THRESHOLD: float = 1.0
const PAD_STICK_DEADZONE: float = 0.15
const PAD_CURSOR_SPEED: float = 800.0
const TARGET_EMIT_COOLDOWN_MSEC: int = 100

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

# Phase 7 — Pad B raw timer 상태.
var _b_pressed: bool = false
var _b_press_time: float = 0.0

# Phase 7 — D-Pad target_*_ant throttle (100ms, per-direction).
# 같은 방향 연타만 차단 — 방향 전환(next ↔ prev)은 즉시 허용. 군중 속 정밀 조작 UX 우선.
var _last_next_emit_msec: int = -1000  # 첫 호출도 cooldown 통과하도록 음수 초기값.
var _last_prev_emit_msec: int = -1000


func _ready() -> void:
	# B-hold timer / stick polling은 paused 상태에서도 동작해야 함(phase 8 pause 고려).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	# 0. Pad B raw 우선 처리 (InputMap 미등록, single/hold race-free)
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_on_pad_b(event as InputEventJoypadButton)
		var vp_b: Viewport = get_viewport()
		if vp_b != null:
			vp_b.set_input_as_handled()
		return
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
		# Phase 7 — throttle은 _emit_positional 내부에서 valid emit에만 적용.
		# 이렇게 해야 invalid payload(stale cache 등)는 throttle 우회 → 회귀 contract 유지.
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
		# invalid payload는 throttle 우회 — 회귀 contract(stale cache D-1) 유지.
		var payload_invalid: Dictionary = {"position_valid": false}
		if action == GameAction.TARGET_NEXT_ANT or action == GameAction.TARGET_PREV_ANT:
			payload_invalid["from_world_pos"] = Vector2.ZERO
		EventBus.action_triggered.emit(action, payload_invalid)
		return
	# Phase 7 — valid emit에만 D-Pad/Tab throttle (per-direction).
	if action == GameAction.TARGET_NEXT_ANT or action == GameAction.TARGET_PREV_ANT:
		var now: int = Time.get_ticks_msec()
		var last_msec: int = _last_next_emit_msec if action == GameAction.TARGET_NEXT_ANT else _last_prev_emit_msec
		if now - last_msec < TARGET_EMIT_COOLDOWN_MSEC:
			return  # silent throttle
		if action == GameAction.TARGET_NEXT_ANT:
			_last_next_emit_msec = now
		else:
			_last_prev_emit_msec = now
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
	# Tab/Shift+Tab/D-Pad 액션은 from_world_pos 키 (INPUT_PLAN §5.3 표)
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
	if _virtual_cursor == null:
		return false
	if not _virtual_cursor.is_inside_tree():
		return false
	if _virtual_cursor_initialized:
		return true
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	_virtual_cursor.position = vp.get_visible_rect().size * 0.5
	_virtual_cursor_initialized = true
	_emit_cursor_move(_virtual_cursor.position)  # 첫 emit + cache 갱신 단일 경로
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


func _process(delta: float) -> void:
	# B-hold timer는 패드 연결 무관(이미 press 받았다면 release 안 와도 만료해야).
	_tick_b_button(delta)
	if not _has_pad_connected():
		return
	# Phase 7 — 좌 스틱 polling (synthetic cursor_move).
	var stick: Vector2 = Input.get_vector(
		&"pad_cursor_left", &"pad_cursor_right",
		&"pad_cursor_up", &"pad_cursor_down",
		PAD_STICK_DEADZONE,
	)
	if stick == Vector2.ZERO:
		return
	if not _ensure_virtual_cursor_ready():
		return  # 노드 미주입/미준비 — silent skip (다음 프레임에 다시 시도)
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var size: Vector2 = vp.get_visible_rect().size
	var new_pos: Vector2 = (_virtual_cursor.position + stick * PAD_CURSOR_SPEED * delta).clamp(Vector2.ZERO, size)
	_virtual_cursor.position = new_pos
	_emit_cursor_move(new_pos)


func _on_pad_b(event: InputEventJoypadButton) -> void:
	# press 시점: timer 시작. action emit 안 함.
	# release 전 1초: skill_cancel emit.
	# release 후 1초 (timer 만료): _tick_b_button에서 restart_stage emit + _b_pressed=false.
	if event.pressed:
		_b_pressed = true
		_b_press_time = 0.0
		return
	# release
	if not _b_pressed:
		return  # spurious release(이미 timer 만료로 처리됨)
	_b_pressed = false
	if _b_press_time < B_HOLD_THRESHOLD:
		# Phase 7: 메뉴 없음 → 항상 skill_cancel.
		# Phase 12에서 game state 분기 도입 시 이 분기 갱신 (skill_cancel vs back_menu).
		EventBus.action_triggered.emit(GameAction.SKILL_CANCEL, {})


func _tick_b_button(delta: float) -> void:
	if not _b_pressed:
		return
	_b_press_time += delta
	if _b_press_time >= B_HOLD_THRESHOLD:
		# 홀드 만료 — restart_stage 1회 emit + release 무시 플래그.
		_b_pressed = false
		_b_press_time = 0.0
		EventBus.action_triggered.emit(GameAction.RESTART_STAGE, {})


func _has_pad_connected() -> bool:
	return Input.get_connected_joypads().size() > 0


func set_virtual_cursor(c: Control) -> void:
	# Phase 6 hook (Phase 7 본체). SceneFlow._ready에서 호출.
	_virtual_cursor = c
	_virtual_cursor_initialized = false


func request_cursor_jump(screen_pos: Vector2) -> void:
	# CursorTargetingResolver가 D-Pad/Tab snap 결과를 적용할 때 호출.
	# cursor 위치 갱신 + CURSOR_MOVE emit은 모두 _emit_cursor_move 단일 경로 경유.
	if not _ensure_virtual_cursor_ready():
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var size: Vector2 = vp.get_visible_rect().size
	var clamped: Vector2 = screen_pos.clamp(Vector2.ZERO, size)
	_virtual_cursor.position = clamped
	_emit_cursor_move(clamped)


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
