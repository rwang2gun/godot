extends Node

# Phase 7 — CursorTargeting.find_next_ant 순수 계산 단위 테스트.
# 거리 정렬 / 방향 / last_target 회전 / alive 필터(호출자 책임) / empty 케이스 검증.

const CursorTargetingScript := preload("res://scripts/input/CursorTargeting.gd")


class FakeAnt extends Node2D:
	pass


func _ready() -> void:
	if not _case_distance_sort():
		_fail("case_distance_sort"); return
	if not _case_direction_next_prev():
		_fail("case_direction_next_prev"); return
	if not _case_last_target_rotation():
		_fail("case_last_target_rotation"); return
	if not _case_empty_input():
		_fail("case_empty_input"); return
	if not _case_last_target_missing():
		_fail("case_last_target_missing"); return
	print("[CursorTargetingTest] PASS")
	get_tree().quit(0)


func _make_ants(positions: Array) -> Array:
	var arr: Array = []
	for p in positions:
		var a: FakeAnt = FakeAnt.new()
		a.global_position = p
		add_child(a)
		arr.append(a)
	return arr


func _case_distance_sort() -> bool:
	# from=(0,0). ants at (10,0), (5,0), (20,0). next from null → 가장 가까운 (5,0).
	var ants: Array = _make_ants([Vector2(10, 0), Vector2(5, 0), Vector2(20, 0)])
	var t: Object = CursorTargetingScript.find_next_ant(Vector2.ZERO, ants, 1, null)
	if t == null:
		push_error("distance_sort: target null"); return false
	var ok: bool = (t as Node2D).global_position == Vector2(5, 0)
	for a in ants: a.queue_free()
	return ok


func _case_direction_next_prev() -> bool:
	# from=(0,0). ants 3개. last_target=ants[0] sorted index 0 → next는 idx 1, prev는 idx -1(=last).
	var ants: Array = _make_ants([Vector2(10, 0), Vector2(20, 0), Vector2(5, 0)])
	# sorted by distance asc: (5,0), (10,0), (20,0)
	var first: Object = CursorTargetingScript.find_next_ant(Vector2.ZERO, ants, 1, null)
	if (first as Node2D).global_position != Vector2(5, 0):
		push_error("direction: first should be (5,0)"); for a in ants: a.queue_free(); return false
	var second: Object = CursorTargetingScript.find_next_ant(Vector2.ZERO, ants, 1, first)
	if (second as Node2D).global_position != Vector2(10, 0):
		push_error("direction: second next should be (10,0)"); for a in ants: a.queue_free(); return false
	var prev: Object = CursorTargetingScript.find_next_ant(Vector2.ZERO, ants, -1, second)
	if (prev as Node2D).global_position != Vector2(5, 0):
		push_error("direction: prev from (10,0) should be (5,0)"); for a in ants: a.queue_free(); return false
	for a in ants: a.queue_free()
	return true


func _case_last_target_rotation() -> bool:
	# 끝에서 next 누르면 처음으로 wrap.
	var ants: Array = _make_ants([Vector2(5, 0), Vector2(10, 0), Vector2(15, 0)])
	# sorted: (5,0)->idx0, (10,0)->idx1, (15,0)->idx2
	var last_in_list: Object = ants[2]  # (15,0)
	# from (5,0)에서 본다고 가정. 그러나 from으로 (5,0)을 주면 (5,0) 자체가 idx0. last_target=(15,0)가 idx2.
	# next from idx2 → posmod(3,3)=0 → (5,0)
	var wrapped: Object = CursorTargetingScript.find_next_ant(Vector2(0, 0), ants, 1, last_in_list)
	var ok: bool = (wrapped as Node2D).global_position == Vector2(5, 0)
	for a in ants: a.queue_free()
	return ok


func _case_empty_input() -> bool:
	var t: Object = CursorTargetingScript.find_next_ant(Vector2.ZERO, [], 1, null)
	return t == null


func _case_last_target_missing() -> bool:
	# last_target이 후보에서 사라지면 첫 후보(direction=+1) 또는 마지막(direction=-1) 반환.
	var ants: Array = _make_ants([Vector2(10, 0), Vector2(20, 0)])
	var phantom: FakeAnt = FakeAnt.new()  # 후보에 없는 dangling reference
	add_child(phantom)
	var t1: Object = CursorTargetingScript.find_next_ant(Vector2.ZERO, ants, 1, phantom)
	var t2: Object = CursorTargetingScript.find_next_ant(Vector2.ZERO, ants, -1, phantom)
	var ok: bool = (t1 as Node2D).global_position == Vector2(10, 0) and (t2 as Node2D).global_position == Vector2(20, 0)
	phantom.queue_free()
	for a in ants: a.queue_free()
	return ok


func _fail(msg: String) -> void:
	push_error("[CursorTargetingTest] FAIL %s" % msg)
	get_tree().quit(1)
