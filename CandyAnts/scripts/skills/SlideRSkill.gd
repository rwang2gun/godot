class_name SlideRSkill extends SlideSkill

# 오른쪽 경사면 — 개미를 우향(+1)으로 돌려세운 뒤 오른쪽 위로 올라가는 대각 계단을 건설.
# 구 builder의 기본 방향(우향)을 그대로 계승한다(기존 stage04/10·dev fixture 전부 우향).
const ID: String = "slideR"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
# 구 BuilderSkill 메타 계승(계단=ANT_ARMED·routing=up). slideR/slideL은 건설 방향만 다르고 효과는 동일.
const SOLVER_META := {
	"target": "ant",
	"category": "ANT_ARMED",
	"routing": "up",
	"purpose": "오른쪽 낭떠러지에 계단을 놓아 개미를 위층으로 올린다",
	"hints": {"effect": "build_stair", "arms_until": "cliff"},
}

func _build_direction() -> int:
	return 1
