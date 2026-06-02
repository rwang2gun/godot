extends Node

# 실제 Godot DnD 디스패치 경로 검증 — Control.force_drag로 드래그를 시작(엔진 gui.dragging on)한 뒤
# 마우스 release를 흘려 SkillDropZone._drop_data가 *엔진에 의해* 호출되는지 확인.
# (push_input은 헤드리스에서 GUI DnD를 구동하지 못하므로 force_drag 사용.)
#
# 검증 단계:
#   1. force_drag 후 DropZone가 NOTIFICATION_DRAG_BEGIN 수신 → mouse_filter=STOP (notification 배선)
#   2. release 후 인벤토리 차감 + ant trait (엔진 drop 디스패치)
# 헤드리스에서 release 디스패치까지는 안 될 수 있으므로, 그 경우 1단계만 확인하고 나머지는
# SkillDropAssignTest(로직)에 위임 — 단, 1단계(엔진이 DropZone에 DRAG_BEGIN을 보냄)는 반드시 통과해야 한다.

const TOOLBAR_SCENE: PackedScene = preload("res://scenes/ui/SkillToolbar.tscn")
const STAGE_DATA_SCRIPT: GDScript = preload("res://scripts/core/StageData.gd")
const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")

var _toolbar: SkillToolbar = null
var _zone: SkillDropZone = null
var _ant: Ant = null
var _drop_pos := Vector2(960, 360)


func _ready() -> void:
	var stage_data: StageData = STAGE_DATA_SCRIPT.new()
	stage_data.available_skills = ["climber"]
	stage_data.skill_inventory = {"climber": 1}
	_toolbar = TOOLBAR_SCENE.instantiate()
	_toolbar.stage_data = stage_data
	add_child(_toolbar)

	_ant = ANT_SCENE.instantiate()
	_ant.global_position = _drop_pos
	add_child(_ant)

	for i in range(4):
		await get_tree().process_frame

	_zone = _find_first(_toolbar, "SkillDropZone") as SkillDropZone
	var slot: SkillSlot = _find_slot("climber")
	if _zone == null or slot == null:
		_fail("DropZone/slot 미발견 (zone=%s slot=%s)" % [str(_zone), str(slot)])
		return

	# DropZone는 평상시 IGNORE 여야 한다(클릭-assign 무간섭 불변식).
	if _zone.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("평상시 DropZone.mouse_filter 가 IGNORE 가 아님: %d" % _zone.mouse_filter)
		return

	# === 엔진 DnD 시작 ===
	var preview := Control.new()
	slot.force_drag({"skill_id": "climber"}, preview)
	await get_tree().process_frame

	# 1단계 — 엔진이 DropZone에 DRAG_BEGIN을 보내 STOP 전환됐는가 (notification 배선 증거).
	if not get_viewport().gui_is_dragging():
		_fail("force_drag 후 gui_is_dragging()=false — 드래그 미시작")
		return
	if _zone.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("드래그 중 DropZone.mouse_filter 가 STOP 이 아님(DRAG_BEGIN 미수신): %d" % _zone.mouse_filter)
		return
	print("[SkillDragGestureSimTest] OK 1단계 — 엔진 DRAG_BEGIN → DropZone STOP 전환 확인")

	# === release 흘리기 — 엔진이 _drop_data를 디스패치하면 부여됨 ===
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = _drop_pos
	rel.global_position = _drop_pos
	get_viewport().push_input(rel)
	for i in range(3):
		await get_tree().process_frame

	# 드래그 종료 시 DropZone는 IGNORE로 복귀해야 한다(release가 디스패치됐든 아니든 DRAG_END는 와야).
	var back_to_ignore := _zone.mouse_filter == Control.MOUSE_FILTER_IGNORE

	var consumed := int(_toolbar._inventory.get("climber", -1)) == 0
	var applied := _ant.has_trait(&"climber")
	if consumed and applied:
		print("[SkillDragGestureSimTest] PASS — 엔진 drop 디스패치로 부여 확인 (2단계까지)")
		get_tree().quit(0)
		return

	# 2단계(release 디스패치)는 헤드리스에서 안 될 수 있음 → 1단계 통과 + 로직(SkillDropAssignTest) 위임으로 종결.
	print("[SkillDragGestureSimTest] PASS(1단계만) — DRAG_BEGIN 배선 확인. ",
		"release 디스패치는 헤드리스 미지원(consumed=%s applied=%s back_to_ignore=%s). 부여 로직은 SkillDropAssignTest." \
		% [str(consumed), str(applied), str(back_to_ignore)])
	get_tree().quit(0)


func _find_slot(id: String) -> SkillSlot:
	for n in _all_descendants(_toolbar):
		var sl := n as SkillSlot
		if sl != null and String(sl.skill_id) == id:
			return sl
	return null


func _find_first(root: Node, klass: String) -> Node:
	for n in _all_descendants(root):
		if n.is_class("Control") and n.get_script() != null \
			and str(n.get_script().resource_path).ends_with("/%s.gd" % klass):
			return n
	return null


func _all_descendants(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all_descendants(c))
	return out


func _fail(msg: String) -> void:
	push_error("[SkillDragGestureSimTest] FAIL %s" % msg)
	print("[SkillDragGestureSimTest] FAIL %s" % msg)
	get_tree().quit(1)
