extends Node

# Phase 5 (guide-data-copy) — StageIntroCard가 StageGuideData로 올바른 칩/카피/배지를 렌더하는지 검증.
# STAGE_GUIDE_PLAN §2.7. 입력모델 전환점 3종을 커버:
#   S1 climber(③ ANT_ARMED, 해저드 0) / S5 sand_mound(① SIGN, 첫 푯말) / S8 cutter+leaf_jump(①+④, 끈끈이 해저드).
# 배지/카피는 하드코딩 리터럴이 아니라 Strings·SkillAffordance 파생과 대조(SoT 일치 보장).

const IntroCardScene := preload("res://scenes/ui/StageIntroCard.tscn")

var _failed: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	await _check_stage(1, ["climber"], 0)
	if _failed: return
	await _check_stage(5, ["sand_mound"], 0)
	if _failed: return
	await _check_stage(8, ["cutter", "leaf_jump"], 1)
	if _failed: return
	Engine.time_scale = 1.0
	print("[StageGuideDataRenderTest] PASS")
	get_tree().quit(0)

func _check_stage(n: int, expect_skills: Array, expect_hazards: int) -> void:
	var stage: StageData = ResourceLoader.load("res://data/stages/stage%02d.tres" % n) as StageData
	var guide: StageGuideData = ResourceLoader.load("res://data/guides/stage%02d_guide.tres" % n) as StageGuideData
	if stage == null or guide == null:
		_fail("S%d: stage/guide load failed" % n)
		return

	var card: StageIntroCard = IntroCardScene.instantiate()
	add_child(card)
	await get_tree().process_frame
	card.show_intro(stage)
	await get_tree().process_frame

	# 타이틀 = 스테이지 이름(스트링 시트 SoT, Strings.stage_name).
	var expect_title: String = Strings.stage_name(n)
	if card.get_node("CardWrapper/Card/Main/Margin/VBox/Title").text != expect_title:
		_fail("S%d: title mismatch got '%s' expected '%s'" % [n, card.get_node("CardWrapper/Card/Main/Margin/VBox/Title").text, expect_title])

	# shown_skill_ids.
	var shown: Array[String] = card.shown_skill_ids()
	if shown != (expect_skills as Array[String]):
		_fail("S%d: shown_skill_ids got %s expected %s" % [n, str(shown), str(expect_skills)])

	# 목표 카피 = Strings.t(goal_key).
	if card.goal_text() != Strings.t(guide.goal_key):
		_fail("S%d: goal_text got '%s' expected '%s'" % [n, card.goal_text(), Strings.t(guide.goal_key)])

	# 스킬 설명 카피 = Strings.t(skill_desc_keys[i]).
	var descs: Array[String] = card.skill_desc_texts()
	if descs.size() != expect_skills.size():
		_fail("S%d: skill_desc_texts size %d expected %d" % [n, descs.size(), expect_skills.size()])
	else:
		for i in expect_skills.size():
			if descs[i] != Strings.t(guide.skill_desc_keys[i]):
				_fail("S%d: desc[%d] got '%s'" % [n, i, descs[i]])

	# 배지 = SkillAffordance 카테고리 파생(어포던스와 동일 어휘).
	var badges: Array[String] = card.badge_labels()
	if badges.size() != expect_skills.size():
		_fail("S%d: badge_labels size %d expected %d" % [n, badges.size(), expect_skills.size()])
	else:
		for i in expect_skills.size():
			var id: String = expect_skills[i]
			var cat: int = SkillAffordance.category_of(id)
			var key: String = StageIntroCard._BADGE_KEYS[cat]
			if badges[i] != Strings.t(key):
				_fail("S%d: badge[%d] '%s' got '%s' expected '%s'" % [n, i, id, badges[i], Strings.t(key)])

	# 해저드 수.
	if card.hazard_texts().size() != expect_hazards:
		_fail("S%d: hazard count %d expected %d" % [n, card.hazard_texts().size(), expect_hazards])

	# 페이징 카드(pages 저작 스테이지)는 스킬 칩 대신 페이지 스택을 렌더 → 페이지 수로 검증.
	# 단일 카드 스테이지는 칩 노드가 실제로 SkillList에 렌더됐는지(빈 inspector ↔ 빈 UI 괴리 차단).
	if card.page_count() > 0:
		if guide.pages.size() != card.page_count():
			_fail("S%d: page_count %d expected %d" % [n, card.page_count(), guide.pages.size()])
	else:
		var skill_list: VBoxContainer = card.get_node("CardWrapper/Card/Main/Margin/VBox/SkillList")
		if skill_list.get_child_count() != expect_skills.size():
			_fail("S%d: SkillList child count %d expected %d" % [n, skill_list.get_child_count(), expect_skills.size()])

	card.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	Engine.time_scale = 1.0
	push_error("StageGuideDataRenderTest FAIL " + msg)
	print("[StageGuideDataRenderTest] FAIL ", msg)
	get_tree().quit(1)
