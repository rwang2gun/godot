extends Node

# Phase 6 (input-mode-polish, 재조정) — 살아있는 입력 모드 분기 + 어포던스 시각 어휘 고정.
# STAGE_GUIDE_PLAN §2.6 / §2.6.1 / §0.8.1~§0.8.4.
#
# 페이지네이션 개편 후 입력모델 교육 권위(§2.6.1):
#   - 조작 동사 모드 분기(클릭/탭/A버튼)는 인게임 InputHintLabel(hint.*)이 단독 담당 → (a) 검증.
#   - 글로우/커서 시각 어휘는 SkillAffordance 카테고리 SoT + Tokens 파생(하드코딩 아님) → (b) 검증.
#   - 카드 입력모델 배지는 은퇴(inspector·legacy 잔존)·모드 중립 유지 → (c) 검증.

const HintLabelScript := preload("res://scripts/ui/InputHintLabel.gd")

# 모드 동사(이 어휘가 배지에 박히면 안 됨 — 배지는 모드 중립이어야).
const _MODE_VERBS: Array[String] = ["클릭", "탭", "A 버튼", "버튼"]

var _failed: bool = false

func _ready() -> void:
	await get_tree().process_frame
	await _check_hint_mode_branching()
	if _failed: return
	_check_affordance_vocabulary()
	if _failed: return
	_check_badges_neutral_and_mapped()
	if _failed: return
	print("[GuideInputModeCopyTest] PASS")
	get_tree().quit(0)

# (a) InputHintLabel이 mouse/pad/touch emit에 맞춰 hint.* 카피로 분기 + 3 카피 상호 상이.
func _check_hint_mode_branching() -> void:
	var lbl: Label = HintLabelScript.new()
	add_child(lbl)
	await get_tree().process_frame  # _ready → EventBus 구독 + 초기 모드 반영.

	var seen: Dictionary = {}
	for mode: String in ["mouse", "pad", "touch"]:
		EventBus.input_mode_changed.emit(StringName(mode))
		await get_tree().process_frame
		var expect: String = Strings.t("hint.%s" % mode)
		if lbl.text != expect:
			_fail("hint[%s] got '%s' expected '%s'" % [mode, lbl.text, expect])
			lbl.queue_free()
			return
		seen[expect] = mode
	# 3 모드 카피가 서로 달라야(분기가 실재).
	if seen.size() != 3:
		_fail("hint 카피가 모드별로 구별되지 않음 — 고유 %d개 (expected 3)" % seen.size())
	lbl.queue_free()

# (b) 글로우 색 = Tokens 파생(하드코딩 회귀 가드) + 글로우 타깃 = 카테고리 SoT 파생.
func _check_affordance_vocabulary() -> void:
	if AffordanceGlowController.ANT_GLOW_COLOR != Tokens.GRAPE_700:
		_fail("ANT_GLOW_COLOR != Tokens.GRAPE_700 (하드코딩 색 드리프트)")
		return
	if AffordanceGlowController.SURFACE_GLOW_COLOR != Tokens.MINT_500:
		_fail("SURFACE_GLOW_COLOR != Tokens.MINT_500 (하드코딩 색 드리프트)")
		return
	# 4 카테고리 대표 스킬의 글로우 타깃이 SkillAffordance 카테고리 매핑과 일치(개미 ②③ / 표면 ①④).
	var expect_target := {
		"climber":   SkillAffordance.GlowTarget.ANT,      # ③ ANT_ARMED
		"blocker":   SkillAffordance.GlowTarget.ANT,      # ② ANT_SETTLE
		"basher":    SkillAffordance.GlowTarget.SURFACE,  # ① SIGN
		"leaf_jump": SkillAffordance.GlowTarget.SURFACE,  # ④ DEVICE
	}
	for id: String in expect_target:
		if SkillAffordance.glow_target_of(id) != expect_target[id]:
			_fail("glow_target_of('%s') != expected (카테고리 SoT 파생 드리프트)" % id)
			return

# (c) 배지 4종이 카테고리 매핑과 1:1 존재 + 모드 동사 미포함(모드 중립).
func _check_badges_neutral_and_mapped() -> void:
	var cats: Array[int] = [
		SkillAffordance.Category.ANT_ARMED,
		SkillAffordance.Category.ANT_SETTLE,
		SkillAffordance.Category.SIGN,
		SkillAffordance.Category.DEVICE,
	]
	for cat: int in cats:
		if not StageIntroCard._BADGE_KEYS.has(cat):
			_fail("_BADGE_KEYS에 카테고리 %d 누락" % cat)
			return
		var key: String = StageIntroCard._BADGE_KEYS[cat]
		var text: String = Strings.t(key)
		# 미등록 키면 t()가 key 자체를 반환.
		if text == "" or text == key:
			_fail("배지 키 '%s' 미등록/빈 카피" % key)
			return
		for verb: String in _MODE_VERBS:
			if text.contains(verb):
				_fail("배지 '%s' = '%s'에 모드 동사 '%s' 포함(모드 중립 위반)" % [key, text, verb])
				return

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	push_error("GuideInputModeCopyTest FAIL " + msg)
	print("[GuideInputModeCopyTest] FAIL ", msg)
	get_tree().quit(1)
