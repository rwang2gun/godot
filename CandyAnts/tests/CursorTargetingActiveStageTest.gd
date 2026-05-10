extends Node

# Phase 7 — CursorTargetingResolver가 active-stage subtree에 있는 ant만 후보로 인정.
# 이전 stage queued ants(같은 frame stale) + queued_for_deletion + 다른 root 자손은 모두 제외.

const GameAction := preload("res://scripts/input/GameAction.gd")


class FakeAnt extends Node2D:
	var alive: bool = true
	func is_alive() -> bool:
		return alive


func _ready() -> void:
	var main: Node = $Main
	var scene_flow: Node = main.get_node("SceneFlow")
	var current_root: Node = main.get_node("CurrentStageRoot")
	var resolver: Node = main.get_node("CursorTargetingResolver")
	await get_tree().process_frame
	await get_tree().process_frame

	# active stage가 들어와 있어야.
	var active: Node = scene_flow.get_active_stage_node()
	if active == null:
		_fail("active stage missing on Main start"); return

	# === 시나리오 1: active stage 자손 ant + 외부 stale ant 동시 존재 → active 자손만 candidate ===
	var inner: FakeAnt = FakeAnt.new()
	inner.global_position = Vector2(50, 0)
	inner.add_to_group("ants")
	active.add_child(inner)

	var stale_outside: FakeAnt = FakeAnt.new()
	stale_outside.global_position = Vector2(10, 0)  # 거리상 더 가까움 — filter 없으면 잘못 잡힘
	stale_outside.add_to_group("ants")
	current_root.add_child(stale_outside)  # active stage가 아니라 root 자체에 붙임

	await get_tree().process_frame

	# CursorTargetingResolver가 InputRouter.request_cursor_jump 호출하는지 추적.
	# request_cursor_jump → _emit_cursor_move → CURSOR_MOVE emit → screen_pos = inner의 screen.
	var seen: Array = []
	var conn := func(name: StringName, payload: Dictionary) -> void:
		if name == GameAction.CURSOR_MOVE:
			seen.append(payload)
	EventBus.action_triggered.connect(conn)

	# TARGET_NEXT_ANT 발화 — payload.from_world_pos = 가까운 stale 위치(10,0). 필터 없으면 stale 잡힘.
	EventBus.action_triggered.emit(GameAction.TARGET_NEXT_ANT, {
		"position_valid": true,
		"screen_pos": Vector2.ZERO,
		"from_world_pos": Vector2.ZERO,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	# inner.global_position(50,0)과 stale_outside.global_position(10,0) 중
	# 필터 통과는 inner만. find_next_ant가 inner를 반환해야.
	# CURSOR_MOVE emit이 한 번이라도 있어야(jump 호출됨) → 그 payload.world_pos는
	# inner의 위치를 screen→world 변환한 값과 동일해야.
	if seen.is_empty():
		_fail("CURSOR_MOVE not emitted — resolver may have skipped (active stage filter blocked everyone?)"); return

	# 마지막 emit의 world_pos가 inner.global_position과 일치해야.
	# (request_cursor_jump가 inner의 screen → cursor.position 설정 → _emit_cursor_move에서
	#  world_pos = canvas_xform.inverse() * screen. 본 테스트는 Main.tscn 기준 default camera라
	#  screen ≈ world. 결과적으로 emit world_pos ≈ inner.global_position 또는 그 transform 결과.)
	var last_world: Vector2 = seen[-1]["world_pos"]
	# stale ants 위치(10,0)이 잡혔다면 last_world ≈ (10, 0). inner이면 ≈ (50, 0).
	# 정확한 좌표 변환은 viewport stretch 영향이 있으므로 "stale_outside보다 inner에 더 가까운지"로 판정.
	var dist_to_inner: float = (last_world - Vector2(50, 0)).length()
	var dist_to_stale: float = (last_world - Vector2(10, 0)).length()
	if dist_to_stale < dist_to_inner:
		_fail("resolver targeted stale_outside (dist_stale=%.1f < dist_inner=%.1f) — active-stage filter broken" % [dist_to_stale, dist_to_inner])
		return

	# === 시나리오 2: stale ant queued_for_deletion → 자동 제외 ===
	var inner2: FakeAnt = FakeAnt.new()
	inner2.global_position = Vector2(100, 0)
	inner2.add_to_group("ants")
	active.add_child(inner2)
	# inner를 queue_free → group에는 잠시 남지만 is_queued_for_deletion=true.
	inner.queue_free()
	# 같은 frame 안에서 D-Pad 발화 — inner은 후보에서 제외, inner2가 잡혀야.
	seen.clear()
	# throttle 회피용 100ms 대기.
	await get_tree().create_timer(0.15).timeout
	EventBus.action_triggered.emit(GameAction.TARGET_NEXT_ANT, {
		"position_valid": true,
		"screen_pos": Vector2.ZERO,
		"from_world_pos": Vector2.ZERO,
	})
	await get_tree().process_frame
	await get_tree().process_frame
	if seen.is_empty():
		_fail("scenario 2: CURSOR_MOVE not emitted (inner2 should be candidate)"); return
	var s2_world: Vector2 = seen[-1]["world_pos"]
	if (s2_world - Vector2(100, 0)).length() > (s2_world - Vector2(50, 0)).length():
		_fail("scenario 2: targeted queued_for_deletion ant instead of inner2"); return

	stale_outside.queue_free()

	print("[CursorTargetingActiveStageTest] PASS")
	get_tree().quit(0)


func _fail(msg: String) -> void:
	push_error("[CursorTargetingActiveStageTest] FAIL %s" % msg)
	get_tree().quit(1)
