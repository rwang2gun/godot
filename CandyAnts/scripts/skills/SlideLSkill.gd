class_name SlideLSkill extends SlideSkill

# 왼쪽 경사면 — 개미를 좌향(-1)으로 돌려세운 뒤 왼쪽 위로 올라가는 대각 계단을 건설.
# slideR의 좌우 반전. WorkerState._place_one_tile은 a.direction 기반이라 코어 변경 없이 미러된다.
const ID: String = "slideL"

func _build_direction() -> int:
	return -1
