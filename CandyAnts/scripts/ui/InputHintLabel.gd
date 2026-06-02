extends Label

# Phase 8 — last-input 모드별 키 힌트 표시 (UI 전용).
#
# 계약:
# - InputModeTracker가 EventBus.input_mode_changed로 emit한 mode만 읽는다.
# - InputRouter / game state / cursor 위치 등 다른 source 읽기 금지.
# - autoload tracker 부재 시 mouse fallback으로 안전하게 초기화.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 재진입(노드가 트리에 다시 추가) 시 double-connect 방지.
	if not EventBus.input_mode_changed.is_connected(_on_mode_changed):
		EventBus.input_mode_changed.connect(_on_mode_changed)
	var tracker: Node = get_node_or_null("/root/InputModeTracker")
	var mode: StringName = &"mouse"
	if tracker != null and tracker.has_method("get_mode"):
		mode = tracker.get_mode()
	_on_mode_changed(mode)


func _exit_tree() -> void:
	if EventBus.input_mode_changed.is_connected(_on_mode_changed):
		EventBus.input_mode_changed.disconnect(_on_mode_changed)


func _on_mode_changed(mode: StringName) -> void:
	match mode:
		&"mouse":
			text = "클릭/드래그: 적용  ·  1~8: 스킬  ·  Space: 일시정지"
		&"pad":
			text = "A: 적용  ·  LB/RB: 전환  ·  View: 일시정지"
		&"touch":
			text = "탭/드래그: 적용"
		_:
			text = ""
