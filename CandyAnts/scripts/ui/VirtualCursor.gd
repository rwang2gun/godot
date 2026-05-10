extends Control

# Phase 7 — screen-space 표시 전용 커서.
# - 위치 갱신은 InputRouter가 직접 self.position을 쓴다(외부 SoT).
# - 본 노드는 visible 토글 + idle fade만 책임.
# - 마우스 motion → hide(_input), 패드 stick CURSOR_MOVE emit → show(EventBus 구독).
# - _input/_unhandled_input에서 set_input_as_handled 호출 금지 — InputRouter dispatch 우선.

const GameAction := preload("res://scripts/input/GameAction.gd")
const IDLE_FADE_SECONDS: float = 5.0
const FADED_ALPHA: float = 0.4
const FULL_ALPHA: float = 1.0

var _idle_seconds: float = 0.0
# 직전 _input에서 마우스 motion을 받은 경우, 곧이어 InputRouter._unhandled_input이
# 같은 frame에 emit하는 CURSOR_MOVE는 마우스 origin이므로 show 생략.
# Godot 이벤트 순서: _input → _unhandled_input → action_triggered emit → _on_action.
# 본 flag는 _input에서 set, _on_action에서 consume.
var _suppress_next_show: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = FULL_ALPHA
	# Pause 영향 없이 fade 진행 — InputRouter와 같은 always-on 정책(phase 8 도입 시 동일).
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.action_triggered.connect(_on_action)


func _input(event: InputEvent) -> void:
	# 마우스 모션이 들어오면 패드 모드 종료 → hide + 직후 cursor_move show 억제.
	# set_input_as_handled 금지 — InputRouter `_unhandled_input`까지 도달해야 cursor_move emit.
	if event is InputEventMouseMotion:
		visible = false
		_suppress_next_show = true


func _process(delta: float) -> void:
	if not visible:
		return
	_idle_seconds += delta
	if _idle_seconds >= IDLE_FADE_SECONDS:
		modulate.a = FADED_ALPHA


func _on_action(name: StringName, _payload: Dictionary) -> void:
	if name != GameAction.CURSOR_MOVE:
		return
	if _suppress_next_show:
		# 마우스 motion 직후 InputRouter가 emit한 mouse-origin CURSOR_MOVE — show 안 함.
		_suppress_next_show = false
		return
	# 패드 stick polling / D-Pad 스냅 / Tab 등 mouse 외 origin으로 들어온 cursor_move → show.
	if not visible:
		visible = true
	_idle_seconds = 0.0
	modulate.a = FULL_ALPHA
