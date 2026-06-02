class_name SkillDropZone extends Control

# SkillToolbar 드래그앤드롭의 drop 타겟 — 플레이 영역 전체를 덮는 투명 Control.
#
# mouse_filter 정책 (CRITICAL):
# - 평상시 IGNORE → 기존 클릭-assign(InputRouter._unhandled_input의 SKILL_ASSIGN)에 무간섭.
#   플레이 영역 위에 STOP/PASS Control이 끼면 마우스 클릭이 _unhandled_input에 도달 못 해
#   클릭-부여가 깨진다. 이 불변식(=클릭이 _unhandled_input까지 도달)을 보존하기 위해 평상시 IGNORE.
# - 드래그 진행 중(NOTIFICATION_DRAG_BEGIN ~ END)만 STOP → drop을 확실히 수신.
#   드래그 종료 시 즉시 IGNORE 복귀. 드래그 중에는 어차피 DnD 시스템이 입력을 점유하므로 STOP이어도 안전.
#
# 드롭 좌표: drop 시점의 viewport 마우스 위치(screen space)를 CoordSpace로 world 변환 —
# InputRouter._emit_positional과 동일 SoT(CanvasLayer 변환 무관하게 정확).

const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

@export var toolbar_path: NodePath

var _toolbar: SkillToolbar = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toolbar = get_node_or_null(toolbar_path) as SkillToolbar
	if _toolbar == null:
		push_warning("[SkillDropZone] toolbar_path 미해결 — drop 비활성")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			mouse_filter = Control.MOUSE_FILTER_STOP
		NOTIFICATION_DRAG_END:
			mouse_filter = Control.MOUSE_FILTER_IGNORE


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("skill_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _toolbar == null or not (data is Dictionary):
		return
	var id: String = String((data as Dictionary).get("skill_id", ""))
	if id == "":
		return
	# drop 순간 실제 화면 마우스 위치 → world. _at_position(로컬)이 아니라 viewport 마우스를 쓰는
	# 이유: CanvasLayer 변환이 끼어도 InputRouter와 동일한 screen→world 경로를 보장하기 위함.
	var vp: Viewport = get_viewport()
	var screen_pos: Vector2 = vp.get_mouse_position() if vp != null else _at_position
	var world: Vector2 = CoordSpace.screen_to_world(screen_pos, vp)
	_toolbar.try_assign_dragged(id, world)
