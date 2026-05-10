class_name CursorTargeting
extends RefCounted

# Phase 7 — 다음/이전 ant 스냅 후보 계산기 (순수 계산, tree lookup 안 함).
# 호출자가 active-stage 필터링 + alive 필터까지 끝내고 ants 배열을 넘긴다.
#
# 정렬: from_world 기준 distance asc, tiebreaker get_instance_id() asc.
# direction +1 = next, -1 = prev. 같은 위치 연속 호출 시 last_target 다음 후보로 회전.


static func find_next_ant(from_world: Vector2, ants: Array, direction: int, last_target: Object) -> Object:
	if ants.is_empty():
		return null
	var sorted: Array = ants.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		var da: float = (a.global_position - from_world).length_squared()
		var db: float = (b.global_position - from_world).length_squared()
		if not is_equal_approx(da, db):
			return da < db
		return a.get_instance_id() < b.get_instance_id()
	)
	if last_target == null or not (last_target in sorted):
		# 최초 호출 또는 last_target이 후보에서 사라진 경우
		if direction >= 0:
			return sorted[0]
		return sorted[sorted.size() - 1]
	var idx: int = sorted.find(last_target)
	var step: int = 1 if direction >= 0 else -1
	var next_idx: int = posmod(idx + step, sorted.size())
	return sorted[next_idx]
