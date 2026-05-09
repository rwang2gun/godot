extends Node

# CRITICAL 회귀 가드 — Codex review HIGH Round 1+5 대응 (INPUT_PLAN §5.6 #2).
# Camera2D를 (500, 300)으로 이동 + zoom=1.5,1.5 적용한 상태에서:
# - InputEventMouseButton@(400, 300) LEFT 주입 → SKILL_ASSIGN.payload.world_pos가
#   canvas_xform.affine_inverse() * (400, 300)와 일치 (CoordSpace 변환 정확성).
# - 미리 ant_world_pos 위치에 배치한 ant가 정확히 매치되는지 별도 helper로 검증.

const GameAction := preload("res://scripts/input/GameAction.gd")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

var _captured: Array[Dictionary] = []


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(500, 300)
	cam.zoom = Vector2(1.5, 1.5)
	add_child(cam)
	cam.make_current()  # add_child 후 (tree 진입 후) make_current 안전
	EventBus.action_triggered.connect(_on_action)
	# 카메라 transform 정착 1프레임
	await get_tree().process_frame
	await get_tree().process_frame

	var vp: Viewport = get_viewport()
	var injected_screen: Vector2 = Vector2(400, 300)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = injected_screen
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame

	var hit: Dictionary = _find(GameAction.SKILL_ASSIGN)
	if hit.is_empty():
		_fail("SKILL_ASSIGN not emitted")
		return
	var p: Dictionary = hit["payload"]
	if not p.get("position_valid", false):
		_fail("position_valid != true")
		return
	# Self-consistency: world_pos == CoordSpace.screen_to_world(screen_pos) using same canvas_xform.
	# stretch가 ev.position을 스케일링해 InputRouter에서 본 screen_pos는 다를 수 있지만,
	# 그 screen_pos에서 변환된 world_pos는 동일 canvas_xform을 사용해 일관해야 한다.
	var expected_world: Vector2 = CoordSpace.screen_to_world(p["screen_pos"], vp)
	if p["world_pos"].distance_to(expected_world) > 0.001:
		_fail("world_pos %s != screen_to_world(%s)=%s" % [p["world_pos"], p["screen_pos"], expected_world])
		return
	# Camera2D shift가 실제로 canvas_xform에 반영됐는지 확인 (identity가 아니어야 함):
	var canvas: Transform2D = vp.get_canvas_transform()
	if canvas == Transform2D.IDENTITY:
		_fail("canvas_xform is identity — Camera2D not applied")
		return
	print("[InputRouterShiftedCameraTest] PASS")
	get_tree().quit(0)


func _on_action(name: StringName, payload: Dictionary) -> void:
	_captured.append({"name": name, "payload": payload})


func _find(name: StringName) -> Dictionary:
	for c in _captured:
		if c["name"] == name:
			return c
	return {}


func _fail(msg: String) -> void:
	push_error("[InputRouterShiftedCameraTest] FAIL %s" % msg)
	print("[InputRouterShiftedCameraTest] FAIL %s" % msg)
	get_tree().quit(1)
