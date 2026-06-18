class_name SlideRSkill extends SlideSkill

# 오른쪽 경사면 — 개미를 우향(+1)으로 돌려세운 뒤 오른쪽 위로 올라가는 대각 계단을 건설.
# 구 builder의 기본 방향(우향)을 그대로 계승한다(기존 stage04/10·dev fixture 전부 우향).
const ID: String = "slideR"

func _build_direction() -> int:
	return 1
