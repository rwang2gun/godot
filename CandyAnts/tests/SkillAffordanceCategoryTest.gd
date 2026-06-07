extends Node

# Phase 1 (new-user-onboarding) — 카테고리 SoT 확장 가드.
# ① SkillRegistry 등록 스킬 전부가 SkillAffordance.SKILL_CATEGORY에 존재(누락=fail).
# ② 4 카테고리가 CATEGORY_AFFORDANCE에 완전 매핑.
# ③ DOMAIN_MAP §2.1 4분류와 카테고리 정합 + glow_target/cursor_kind 매핑 단언.

func _ready() -> void:
	var failures: Array[String] = []

	# --- ① 확장 가드: 등록 스킬 전부 카테고리 존재 ---
	for script: Script in SkillRegistry.SKILL_SCRIPTS:
		var id: String = script.ID
		if not SkillAffordance.SKILL_CATEGORY.has(id):
			failures.append("Skill '%s' missing from SKILL_CATEGORY (신규 스킬은 카테고리 1줄 추가)" % id)

	# 역방향: SKILL_CATEGORY에 죽은(미등록) 항목이 없는지
	var registered := {}
	for script: Script in SkillRegistry.SKILL_SCRIPTS:
		registered[script.ID] = true
	for id: String in SkillAffordance.SKILL_CATEGORY.keys():
		if not registered.has(id):
			failures.append("SKILL_CATEGORY has stale id '%s' (SkillRegistry 미등록)" % id)

	# --- ② 카테고리 → 어포던스 완전 매핑 ---
	for cat: int in SkillAffordance.Category.values():
		if not SkillAffordance.CATEGORY_AFFORDANCE.has(cat):
			failures.append("Category %d missing from CATEGORY_AFFORDANCE" % cat)
			continue
		var entry: Dictionary = SkillAffordance.CATEGORY_AFFORDANCE[cat]
		if not entry.has("glow_target") or not entry.has("cursor_kind"):
			failures.append("Category %d affordance entry incomplete" % cat)

	# --- ③ DOMAIN_MAP §2.1 정합: 스킬별 카테고리 단언 ---
	var expected_cat := {
		"climber":    SkillAffordance.Category.ANT_ARMED,
		"bridge":     SkillAffordance.Category.ANT_ARMED,
		"builder":    SkillAffordance.Category.ANT_ARMED,
		"blocker":    SkillAffordance.Category.ANT_SETTLE,
		"floater":    SkillAffordance.Category.ANT_SETTLE,
		"sand_mound": SkillAffordance.Category.SIGN,
		"basher":     SkillAffordance.Category.SIGN,
		"cutter":     SkillAffordance.Category.SIGN,
		"digger":     SkillAffordance.Category.SIGN,
		"leaf_jump":  SkillAffordance.Category.DEVICE,
	}
	for id: String in expected_cat:
		if SkillAffordance.category_of(id) != expected_cat[id]:
			failures.append("category_of('%s') != expected (%d)" % [id, expected_cat[id]])

	# --- glow_target: 개미(②③) vs 표면(①④) ---
	if SkillAffordance.glow_target_of("climber") != SkillAffordance.GlowTarget.ANT:
		failures.append("ANT_ARMED glow_target should be ANT")
	if SkillAffordance.glow_target_of("blocker") != SkillAffordance.GlowTarget.ANT:
		failures.append("ANT_SETTLE glow_target should be ANT")
	if SkillAffordance.glow_target_of("basher") != SkillAffordance.GlowTarget.SURFACE:
		failures.append("SIGN glow_target should be SURFACE")
	if SkillAffordance.glow_target_of("leaf_jump") != SkillAffordance.GlowTarget.SURFACE:
		failures.append("DEVICE glow_target should be SURFACE")

	# --- cursor_kind: 카테고리별 결과물 모양 ---
	if SkillAffordance.cursor_kind_of("bridge") != SkillAffordance.CursorKind.ICON:
		failures.append("ANT_ARMED cursor should be ICON")
	if SkillAffordance.cursor_kind_of("floater") != SkillAffordance.CursorKind.SETTLE_FORM:
		failures.append("ANT_SETTLE cursor should be SETTLE_FORM")
	if SkillAffordance.cursor_kind_of("digger") != SkillAffordance.CursorKind.SIGN:
		failures.append("SIGN cursor should be SIGN")
	if SkillAffordance.cursor_kind_of("leaf_jump") != SkillAffordance.CursorKind.DEVICE:
		failures.append("DEVICE cursor should be DEVICE")

	# --- 결과 ---
	if failures.size() > 0:
		push_error("SkillAffordanceCategoryTest FAIL: " + str(failures))
		print("[SkillAffordanceCategoryTest] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[SkillAffordanceCategoryTest] PASS — %d skills categorized, 4 categories mapped" % SkillRegistry.SKILL_SCRIPTS.size())
		get_tree().quit(0)
