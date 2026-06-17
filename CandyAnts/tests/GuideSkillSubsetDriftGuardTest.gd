extends Node

# Phase 5 (guide-data-copy) — CRITICAL 드리프트 가드. STAGE_GUIDE_PLAN §2.7·§1.
# 양방향 정합을 단언한다(codex impl R1 MEDIUM — 단방향 subset은 "첫 등장 스킬 누락"을 못 잡았음):
#   (A) new_skill_ids ⊆ stageNN.available_skills   — 카드가 라이브에 없는 스킬을 광고하지 않음(서술↔라이브 드리프트).
#   (B) first_introduced(N) ⊆ new_skill_ids         — 그 스테이지에서 처음 쓸 수 있게 된 스킬은 반드시 카드가 가르침
#       (first_introduced(N) = available(N) − ∪ available(1..N-1)). 누락 = 초등학생이 처음 쓰는 스킬을 설명 없이 만남.
# 레벨이 개정돼 available_skills가 바뀌어도(§1) 두 방향이 카드 레벨에서 자동 검증된다.
#
# 추가 정합 검사:
#   - guide.stage_id == NN (파일명/내용 일치)
#   - skill_desc_keys.size() == new_skill_ids.size() (1:1 평행)
#   - goal_key / skill_desc_keys / hazard_keys 가 모두 Strings 테이블에 존재
#   - new_skill_id 가 SkillAffordance.SKILL_CATEGORY 에 존재(배지 파생 가능)

# S1~S8 + S11(blocker 재배치 2026-06-17) 가이드 구간. S9·S10·S12~S14는 가이드 파일 없음(카드 생략).
# 주의: 가드는 stage 번호 순으로 first-use를 누적한다 — blocker는 S1~S8에 없고(stage02는 floater-only로 이관)
# S11에서 처음 available이라 S11에서 first-introduced로 잡혀 정합이 성립한다(climber는 S1 등장 → 복습이라 미카드).
const GUIDE_STAGES := [1, 2, 3, 4, 5, 6, 7, 8, 11]

func _ready() -> void:
	var failures: Array[String] = []
	var seen_skills: Dictionary = {}   # 이전 스테이지까지 등장한 스킬 union (first-use 판정용).

	for n in GUIDE_STAGES:
		var stage_path: String = "res://data/stages/stage%02d.tres" % n
		var guide_path: String = "res://data/guides/stage%02d_guide.tres" % n

		var stage: StageData = ResourceLoader.load(stage_path) as StageData
		if stage == null:
			failures.append("S%d: stage tres load failed (%s)" % [n, stage_path])
			continue
		var guide: StageGuideData = ResourceLoader.load(guide_path) as StageGuideData
		if guide == null:
			failures.append("S%d: guide tres load failed (%s)" % [n, guide_path])
			continue

		# stage_id 일치.
		if guide.stage_id != n:
			failures.append("S%d: guide.stage_id=%d (expected %d)" % [n, guide.stage_id, n])

		# 1:1 평행.
		if guide.skill_desc_keys.size() != guide.new_skill_ids.size():
			failures.append("S%d: skill_desc_keys(%d) != new_skill_ids(%d)" % [
				n, guide.skill_desc_keys.size(), guide.new_skill_ids.size()])

		# (A) 부분집합 + 카테고리 존재 — 카드가 라이브에 없는 스킬을 광고하지 않음.
		for id: String in guide.new_skill_ids:
			if not stage.available_skills.has(id):
				failures.append("S%d: new skill '%s' NOT in available_skills %s (드리프트!)" % [
					n, id, str(stage.available_skills)])
			if not SkillAffordance.SKILL_CATEGORY.has(id):
				failures.append("S%d: new skill '%s' missing from SkillAffordance.SKILL_CATEGORY" % [n, id])

		# 첫 등장 집합 = available(N) − seen(1..N-1).
		var first_introduced: Dictionary = {}
		for id: String in stage.available_skills:
			if not seen_skills.has(id):
				first_introduced[id] = true

		# (B) 첫 등장 완전성 — 처음 쓸 수 있게 된 스킬은 카드가 반드시 가르쳐야 함(설명 없는 첫 사용=튜토리얼 구멍).
		for id: String in first_introduced:
			if not guide.new_skill_ids.has(id):
				failures.append("S%d: '%s' first available here but NOT carded (new_skill_ids=%s) — 첫 등장 스킬 누락!" % [
					n, id, str(guide.new_skill_ids)])

		# (C) "신규만" 계약(§5.1, StageGuideData 계약) — 복습 스킬을 신규 칩으로 광고 금지.
		#     (B)+(C) = new_skill_ids 집합 == first_introduced 집합. 단방향만으론 climber 재카드를 못 잡았음(codex impl R2).
		for id: String in guide.new_skill_ids:
			if not first_introduced.has(id):
				var reason: String = "이미 등장(복습)" if seen_skills.has(id) else "available에 없음"
				failures.append("S%d: carded '%s' is NOT first-introduced (%s) — '신규만' 계약 위반!" % [n, id, reason])

		# 다음 스테이지의 first-use 판정을 위해 이 스테이지 스킬을 union에 누적.
		for id: String in stage.available_skills:
			seen_skills[id] = true

		# 카피 key 존재(Strings).
		if not Strings.has_key(guide.goal_key):
			failures.append("S%d: goal_key '%s' missing from Strings" % [n, guide.goal_key])
		for k: String in guide.skill_desc_keys:
			if not Strings.has_key(k):
				failures.append("S%d: skill_desc_key '%s' missing from Strings" % [n, k])
		for k: String in guide.hazard_keys:
			if not Strings.has_key(k):
				failures.append("S%d: hazard_key '%s' missing from Strings" % [n, k])

	if failures.size() > 0:
		push_error("GuideSkillSubsetDriftGuardTest FAIL\n" + "\n".join(failures))
		print("[GuideSkillSubsetDriftGuardTest] FAIL\n", "\n".join(failures))
		get_tree().quit(1)
	else:
		print("[GuideSkillSubsetDriftGuardTest] PASS - %d guide stages verified" % GUIDE_STAGES.size())
		get_tree().quit(0)
