extends Node

# Phase 6 (input-mode-polish, 재조정) — 온보딩 레이어 실씬 E2E (codex impl R1-MEDIUM 대응).
# STAGE_GUIDE_PLAN §2.6.1 · §0.8.
#
# 실 Main.tscn → SceneFlow로 구동(모사 아님). _test_force_intro로 헤드리스 카드 스킵을 우회해
# [페이징 카드(가시 버튼) → dismiss → SceneFlow._on_intro_dismissed → begin(실 스폰) → 어포던스
#  적격 → 스킬 trait]을 한 경로로 묶고, 인트로 pause-block의 acquire/release까지 단언한다.
#
# 직접 호출(private) 대신 실 SceneFlow 배선 + 가시 PageRoot 버튼(NextBtn/StartBtnP)을 누른다.

const SPAWN_DEADLINE: int = 5000
const BEGIN_DEADLINE: int = 1500

const _NEXT_BTN := "CardWrapper/Card/Main/Margin/PageRoot/NavRow/RightZone/NextBtn"
const _START_BTN_P := "CardWrapper/Card/Main/Margin/PageRoot/NavRow/RightZone/StartBtnP"

var _failed: bool = false
var _main: Node = null
var _scene_flow: Node = null
var _stage_root: Node = null

func _ready() -> void:
	Engine.time_scale = 8.0
	_main = $Main
	_scene_flow = _main.get_node("SceneFlow")
	_stage_root = _main.get_node("CurrentStageRoot")
	if _scene_flow == null or _stage_root == null:
		return _fail("Main 노드 누락(SceneFlow/CurrentStageRoot)")
	await get_tree().process_frame  # SceneFlow._ready/_boot(→TITLE) 완료.

	# 1) 헤드리스에서도 카드 게이트 경로를 타도록 강제 + 실 SceneFlow로 stage 로드.
	_scene_flow._test_force_intro = true
	_scene_flow.load_stage(1)
	await get_tree().process_frame
	await get_tree().process_frame  # stage instantiation + StageRunner._ready + card.show_intro.

	if _scene_flow.current_screen != _scene_flow.ScreenState.STAGE:
		return _fail("load_stage(1) 후 STAGE 화면 아님")
	var runner: Node = _scene_flow._current_stage_node
	if runner == null or not runner.has_method("begin"):
		return _fail("current_stage_node 미해소")
	if runner.is_begun():
		return _fail("카드 게이트 실패 — begin 전인데 is_begun()")

	# 2) 실 카드 표시 + 인트로 pause-block acquire 단언.
	var card: StageIntroCard = _scene_flow._intro_card as StageIntroCard
	if card == null or not card.is_showing():
		return _fail("SceneFlow 인트로 카드 미표시(_test_force_intro 경로 깨짐)")
	if not InputRouter.are_pause_actions_blocked():
		return _fail("카드 표시 중 인트로 pause-block 미획득")
	if card.page_count() != 3:
		return _fail("S1 page_count %d != 3" % card.page_count())

	# 3) 가시 PageRoot 버튼으로 페이지 진행(NextBtn ×2 → 마지막 페이지).
	var next_btn: BaseButton = card.get_node(_NEXT_BTN) as BaseButton
	for step in range(2):
		if not next_btn.visible or next_btn.disabled:
			return _fail("page %d: NextBtn 비가시/비활성" % card.current_page())
		next_btn.pressed.emit()
		await get_tree().process_frame
		if card.current_page() != step + 1:
			return _fail("Next 후 current_page %d != %d" % [card.current_page(), step + 1])

	# 4) 마지막 페이지의 가시 StartBtnP로 dismiss → 실 SceneFlow가 begin.
	var start_btn: BaseButton = card.get_node(_START_BTN_P) as BaseButton
	if not start_btn.visible or start_btn.disabled:
		return _fail("마지막 페이지 StartBtnP 비가시/비활성")
	start_btn.pressed.emit()

	var waited: int = 0
	while not runner.is_begun() and waited < BEGIN_DEADLINE:
		await get_tree().process_frame
		waited += 1
	if not runner.is_begun():
		return _fail("dismiss 후 begin 안 됨(SceneFlow._on_intro_dismissed 배선 깨짐)")
	# 5) 인트로 pause-block release 단언(dismiss 후 모달 게이트 해제).
	if InputRouter.are_pause_actions_blocked():
		return _fail("begin 후에도 인트로 pause-block 미해제")
	if card.is_showing():
		return _fail("dismiss 후에도 카드 표시 중")

	# 6) 실 스폰 — 가속 후 walker-on-floor 출현 대기.
	runner._spawner.set_release_rate(99)
	var sframes: int = 0
	while _first_walker_on_floor() == null and sframes < SPAWN_DEADLINE:
		await get_tree().process_frame
		sframes += 1
	if _first_walker_on_floor() == null:
		return _fail("walker-on-floor 개미 미출현")

	# 7) 실씬 어포던스 — 컨트롤러 배선 해소 + climber 선택 시 글로우.
	var ctrl: AffordanceGlowController = _find_by_name(_stage_root, "AffordanceGlowController") as AffordanceGlowController
	var tb: SkillToolbar = _find_by_name(_stage_root, "SkillToolbar") as SkillToolbar
	if ctrl == null or tb == null:
		return _fail("AffordanceGlowController/SkillToolbar 미발견(씬 미배선)")
	if ctrl._toolbar == null or ctrl._terrain == null:
		return _fail("controller toolbar/terrain NodePath 미해소")

	tb._pending_skill_id = "climber"
	await _await_frames(4)
	var elig: Array = ctrl.eligible_ants("climber")
	if elig.size() <= 0:
		return _fail("climber 적격 개미 0")
	var glow_count: int = 0
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null:
			continue
		var s: Node = a.get_node_or_null("Sprite")
		if s != null and s.has_meta(Glow.META_KEY):
			glow_count += 1
	if glow_count <= 0:
		return _fail("climber 선택 후 글로우 개미 0(실씬 글로우 미작동)")

	# 8) 스킬 적용 → trait 획득(climber는 trait 기반) + 적격성 소멸.
	var target: Ant = _first_walker_on_floor()
	if target == null:
		return _fail("적용 대상 walker 소실")
	var skill := ClimberSkill.new()
	if not skill.can_apply(target):
		return _fail("적용 전 can_apply false(예상 true)")
	if target.has_trait(&"climber"):
		return _fail("적용 전 이미 climber trait")
	skill.apply(target)
	if not target.has_trait(&"climber"):
		return _fail("apply 후 climber trait 미획득")
	if ClimberSkill.new().can_apply(target):
		return _fail("apply 후에도 can_apply true(적격성 소멸 안 됨)")

	Engine.time_scale = 1.0
	print("[OnboardingIntegrationTest] PASS — SceneFlow card(pages=3)→btn dismiss→begin→glow=%d→trait" % glow_count)
	get_tree().quit(0)

func _first_walker_on_floor() -> Ant:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not a.is_alive():
			continue
		if a.state_machine != null and a.state_machine.current_state is WalkerState and a.is_on_floor():
			return a
	return null

func _find_by_name(n: Node, target: String) -> Node:
	if n == null:
		return null
	if n.name == target:
		return n
	for c in n.get_children():
		var found: Node = _find_by_name(c, target)
		if found != null:
			return found
	return null

func _await_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	Engine.time_scale = 1.0
	# 안전: 테스트 중단 시 잔존 게이트 해제(다음 테스트 오염 방지).
	InputRouter.set_intro_pause_blocked(false)
	push_error("OnboardingIntegrationTest FAIL " + msg)
	print("[OnboardingIntegrationTest] FAIL ", msg)
	get_tree().quit(1)
