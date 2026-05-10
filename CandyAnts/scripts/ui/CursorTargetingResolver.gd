extends Node

# Phase 7 — TARGET_NEXT_ANT/TARGET_PREV_ANT 액션 수신자.
# - Main.tscn 자식(persistent across stages).
# - SceneFlow에서 active_stage_root 주입받아 stale-stage ants 차단.
# - 결과 ant.global_position을 screen으로 변환해 InputRouter.request_cursor_jump 호출.
# - cursor 위치 갱신은 InputRouter 단일 SoT — resolver가 _virtual_cursor.position 직접 안 씀.

const GameAction := preload("res://scripts/input/GameAction.gd")
const CursorTargetingScript := preload("res://scripts/input/CursorTargeting.gd")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")

var _active_stage_root: Node = null
var _last_target: Object = null


func _ready() -> void:
	EventBus.action_triggered.connect(_on_action)


func set_active_stage_root(node: Node) -> void:
	# SceneFlow가 stage load/unload 시점에 호출. null이면 noop 모드.
	if _active_stage_root != node:
		_active_stage_root = node
		_last_target = null  # stage 바뀌면 회전 cursor 리셋


func _on_action(name: StringName, payload: Dictionary) -> void:
	var direction: int = 0
	if name == GameAction.TARGET_NEXT_ANT:
		direction = 1
	elif name == GameAction.TARGET_PREV_ANT:
		direction = -1
	else:
		return
	if not payload.get("position_valid", false):
		return
	if _active_stage_root == null:
		return
	var from_world: Vector2 = payload.get("from_world_pos", Vector2.ZERO)
	var candidates: Array = _gather_candidates()
	if candidates.is_empty():
		return
	# Stale _last_target 가드 — queue_free 또는 스테이지 전환으로 free된 reference 차단.
	var safe_last: Object = _last_target if (_last_target != null and is_instance_valid(_last_target)) else null
	var target: Object = CursorTargetingScript.find_next_ant(from_world, candidates, direction, safe_last)
	if target == null:
		return
	_last_target = target
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	# Ant.global_position(world) → screen 변환 + InputRouter cursor jump.
	var target_world: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
	var screen: Vector2 = CoordSpace.world_to_screen(target_world, vp)
	InputRouter.request_cursor_jump(screen)


func _gather_candidates() -> Array:
	var raw: Array = get_tree().get_nodes_in_group("ants")
	var out: Array = []
	for n in raw:
		if not is_instance_valid(n):
			continue
		if n.is_queued_for_deletion():
			continue
		if not _active_stage_root.is_ancestor_of(n):
			# Stale ants from previous stage instance — Phase 7 invariant.
			continue
		# alive 필터: Ant.is_alive() 헬퍼 사용. 헬퍼 부재 시 모두 통과(보수적).
		if n.has_method("is_alive") and not n.is_alive():
			continue
		out.append(n)
	return out
