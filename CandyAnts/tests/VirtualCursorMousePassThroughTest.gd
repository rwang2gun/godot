extends Node

# Phase 7 — VirtualCursor가 마우스 모션을 잡아도 InputRouter cursor_move emit이 막히지 않음.
# VirtualCursor._input은 set_input_as_handled 호출 안 함 — _unhandled_input까지 마우스 모션 도달 → InputRouter._emit_cursor_move 발화.

const GameAction := preload("res://scripts/input/GameAction.gd")

var _captured: Array = []


func _ready() -> void:
	# VirtualCursor scene 인스턴스화.
	var vc_scene: PackedScene = load("res://scenes/ui/VirtualCursor.tscn")
	var vc: Node = vc_scene.instantiate()
	add_child(vc)
	await get_tree().process_frame

	EventBus.action_triggered.connect(_on_action)
	_captured.clear()

	# 마우스 모션 주입.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(123, 456)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame

	# VirtualCursor._input → visible=false. InputRouter._unhandled_input → cursor_move emit.
	var hit: Dictionary = _find(GameAction.CURSOR_MOVE)
	if hit.is_empty():
		_fail("CURSOR_MOVE not emitted — VirtualCursor may have set_input_as_handled (forbidden)")
		return
	# 헤드리스 viewport stretch로 인해 InputEventMouseMotion.position이 viewport 좌표로 변환됨 —
	# 정확한 (123,456)이 아니더라도 emit 자체와 cursor visible=false만 검증.
	# Cursor child의 visible은 false여야(마우스 motion 시).
	var cursor: Control = vc.get_node("Cursor") as Control
	if cursor.visible:
		_fail("Cursor.visible should be false after mouse motion")
		return

	print("[VirtualCursorMousePassThroughTest] PASS")
	get_tree().quit(0)


func _on_action(name: StringName, payload: Dictionary) -> void:
	_captured.append({"name": name, "payload": payload})


func _find(name: StringName) -> Dictionary:
	for c in _captured:
		if c["name"] == name:
			return c
	return {}


func _fail(msg: String) -> void:
	push_error("[VirtualCursorMousePassThroughTest] FAIL %s" % msg)
	get_tree().quit(1)
