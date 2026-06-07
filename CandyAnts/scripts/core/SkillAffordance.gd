class_name SkillAffordance
extends RefCounted

# 어포던스 카테고리 단일 SoT (STAGE_GUIDE_PLAN §0.8.5, DOMAIN_MAP §2.1 미러).
# 글로우 대상·커서 모양·입력 라우팅은 스킬별 하드코딩이 아니라 "입력모델 카테고리"에서 파생한다.
# CRITICAL: 신규 스킬 = SkillRegistry preload 1줄 + 여기 SKILL_CATEGORY 1줄.
#   (확장 가드: tests/SkillAffordanceCategoryTest 가 등록 스킬 전체의 카테고리 존재를 강제)

# DOMAIN_MAP §2.1 입력모델 ③②①④ = 아래 enum 순서.
enum Category { ANT_ARMED, ANT_SETTLE, SIGN, DEVICE }

# 글로우(반짝임)가 붙는 탭 대상. 개미(②③) ↔ 표면 타일(①④).
enum GlowTarget { ANT, SURFACE }

# 커서 = "결과물 모양" (STAGE_GUIDE_PLAN §0.8.1).
enum CursorKind { ICON, SETTLE_FORM, SIGN, DEVICE }

# 스킬 id → 카테고리 (10종 전부). 신규 스킬은 여기 1줄 추가.
const SKILL_CATEGORY := {
	"climber":    Category.ANT_ARMED,   # ③ 무장·자동발동
	"bridge":     Category.ANT_ARMED,
	"builder":    Category.ANT_ARMED,
	"blocker":    Category.ANT_SETTLE,  # ② 정착·이탈
	"floater":    Category.ANT_SETTLE,
	"sand_mound": Category.SIGN,        # ① 푯말 설치
	"basher":     Category.SIGN,
	"cutter":     Category.SIGN,
	"digger":     Category.SIGN,
	"leaf_jump":  Category.DEVICE,      # ④ 장치 설치
}

# 카테고리 → 어포던스 (글로우 대상 + 커서 모양). §0.8.2 매핑.
const CATEGORY_AFFORDANCE := {
	Category.ANT_ARMED:  { "glow_target": GlowTarget.ANT,     "cursor_kind": CursorKind.ICON },
	Category.ANT_SETTLE: { "glow_target": GlowTarget.ANT,     "cursor_kind": CursorKind.SETTLE_FORM },
	Category.SIGN:       { "glow_target": GlowTarget.SURFACE, "cursor_kind": CursorKind.SIGN },
	Category.DEVICE:     { "glow_target": GlowTarget.SURFACE, "cursor_kind": CursorKind.DEVICE },
}

# --- 조회 헬퍼 (카테고리 SoT 파생) ---

static func category_of(id: String) -> Category:
	assert(SKILL_CATEGORY.has(id), "Skill '%s' missing from SKILL_CATEGORY (신규 스킬은 카테고리 1줄 추가)" % id)
	return SKILL_CATEGORY[id]

static func glow_target_of(id: String) -> GlowTarget:
	return CATEGORY_AFFORDANCE[category_of(id)]["glow_target"]

static func cursor_kind_of(id: String) -> CursorKind:
	return CATEGORY_AFFORDANCE[category_of(id)]["cursor_kind"]
