class_name StageGuideData extends Resource

# Phase 5 (guide-data-copy) — 인트로 카드 문안 메타. STAGE_GUIDE_PLAN §2.4 B안.
# "어떤 카피 key를 보여줄지"의 메타만 담는다. 카피 문자열 자체는 Strings.gd(`guide.sN.*`) 중앙화(프로젝트 규칙).
# 스킬 칩 라벨/아이콘/입력모델 배지는 런타임에 파생:
#   - 라벨  = Strings.skill_label(id)
#   - 아이콘 = SkillToolbar.ICONS[id]
#   - 배지  = SkillAffordance.category_of(id) → guide.badge.<category>
# 따라서 칩 텍스트를 여기 중복 정의하지 않는다.
#
# 드리프트 가드(GuideSkillSubsetDriftGuardTest): new_skill_ids ⊆ stageNN.tres.available_skills.
# 레벨이 개정돼 available_skills가 바뀌면 카드가 광고하는 신규 스킬이 자동 검증된다(§1 재발 방지).

# 이 가이드가 속한 스테이지 id (드리프트 가드가 stageNN.tres와 교차 확인).
@export var stage_id: int = 0

# 목표 한 줄 카피 key (Strings).
@export var goal_key: String = ""

# 이 스테이지에서 "처음 등장"해 카드가 강조할 스킬 id (카드 칩으로 렌더). 0~2개.
@export var new_skill_ids: Array[String] = []

# new_skill_ids와 1:1 평행 — 각 스킬 설명 카피 key (Strings).
@export var skill_desc_keys: Array[String] = []

# 해저드 경고 카피 key 목록 (Strings). 0~n개. 카피는 ⚠ 프리픽스 포함.
@export var hazard_keys: Array[String] = []
