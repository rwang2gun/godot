class_name SpeedBtn
extends CButton

# 하단 HUD 배속 버튼 — 누르거나 SPEED_TOGGLE(키보드 F / 패드)로 게임 진행 속도를 순환.
# PauseBtn과 동형의 atom-like wrapper (GHOST CButton + action_triggered 경로).
#
# 설계 — 상대 배수(relative multiplier):
#   진입 시점의 Engine.time_scale을 _base_scale로 캡처하고, 그 위에 MULTIPLIERS[_idx]를 곱한다.
#   - 실제 플레이: base=1.0 → 1× / 2× / 3×.
#   - 헤드리스 테스트(GameFlowTest가 time_scale=8로 구동): idx 0이면 base*1.0=8 그대로 → 비간섭.
#   _exit_tree에서 _base_scale로 복원 → 스테이지 이탈 시 메뉴/다음 씬이 가속되지 않음.

const GameAction := preload("res://scripts/input/GameAction.gd")
const MULTIPLIERS: Array[float] = [1.0, 2.0, 3.0]

var _idx: int = 0
var _base_scale: float = 1.0

func _ready() -> void:
	kind = ButtonKind.GHOST
	custom_minimum_size = Vector2(56, 56)
	process_mode = PROCESS_MODE_ALWAYS
	super._ready()
	_base_scale = Engine.time_scale
	_idx = 0
	_apply_scale()
	if not pressed.is_connected(_on_pressed_emit):
		pressed.connect(_on_pressed_emit)
	if not EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.connect(_on_action)

func _exit_tree() -> void:
	Engine.time_scale = _base_scale
	if EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.disconnect(_on_action)

# 버튼 클릭 → SPEED_TOGGLE emit. 실제 순환은 _on_action 단일 경로에서 처리(키보드 F와 공유).
func _on_pressed_emit() -> void:
	EventBus.action_triggered.emit(GameAction.SPEED_TOGGLE, {})

func _on_action(name: StringName, _payload: Dictionary) -> void:
	if name == GameAction.SPEED_TOGGLE:
		_idx = (_idx + 1) % MULTIPLIERS.size()
		_apply_scale()

func _apply_scale() -> void:
	Engine.time_scale = _base_scale * MULTIPLIERS[_idx]
	text = "%d×" % int(MULTIPLIERS[_idx])
