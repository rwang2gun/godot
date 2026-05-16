extends Node

# Phase 8 Autoload — last-input 디바이스 분류기 (UI 힌트 전용).
#
# 계약:
# - 이벤트를 소비하지 않는다 (set_input_as_handled 호출 금지).
# - 게임 액션 emit 금지 — EventBus.input_mode_changed만 emit.
# - autoload sibling order에 의존하지 않는다 (read-only observer).
# - 게임 로직 코드는 본 노드를 참조하지 않는다(leak guard test로 검증).

var _mode: StringName = &"mouse"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_mode() -> StringName:
	return _mode


func _input(event: InputEvent) -> void:
	var new_mode: StringName = _classify(event)
	if new_mode == StringName():
		return  # 분류 대상 아님 (예: InputEventKey)
	if new_mode == _mode:
		return  # 동일 디바이스 spam 차단
	_mode = new_mode
	EventBus.input_mode_changed.emit(new_mode)


func _classify(event: InputEvent) -> StringName:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return &"mouse"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return &"pad"
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return &"touch"
	return StringName()
