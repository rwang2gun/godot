extends Node

# Phase 6 (input-mode-polish, 재조정) — 단일카드 legacy 경로 도달불가 보장 + 안전 degraded 잠금.
# STAGE_GUIDE_PLAN §2.6.1 (단일카드 렌더 = legacy·non-user-facing).
#
# (a) 출하 가드(핵심): published guide(.tres)가 pages non-empty(단일카드 경로 도달불가) + 각 GuidePage의
#     title/body 카피가 등록·non-empty·모드 중립(§2.6.1 카드 본문 권위 카피). allowlist만 guide 부재 허용.
# (b) user-facing degraded: guide==null → placeholder 본문(스킬/배지 카피 0) — 유일한 사용자 fallback.
# (c) legacy 렌더 shape(non-user-facing): _build_skill_row/_badge_label_of가 깨지지 않고 모드 중립.

const IntroCardScene := preload("res://scenes/ui/StageIntroCard.tscn")
const _MODE_VERBS: Array[String] = ["클릭", "탭", "A 버튼", "버튼"]

var _failed: bool = false

func _ready() -> void:
	_check_all_campaign_guides_have_pages()
	if _failed: return
	await _check_guide_null_placeholder()
	if _failed: return
	await _check_legacy_render_shape()
	if _failed: return
	await _check_paged_to_null_reset()
	if _failed: return
	print("[StageIntroCardFallbackTest] PASS")
	get_tree().quit(0)

# 의도적으로 인트로 가이드가 없는 published 스테이지(placeholder 렌더). REVISION §3 — S9 피날레
# 인트로 카드는 "선택·1차 미포함". 새 무가이드 스테이지가 생기면 여기 명시 추가(누락=실수로 간주).
# S10 "보물찾기!" — 맵 에디터 저작 스테이지(2026-06-08 정식 발행), 가이드 미저작 → placeholder 렌더.
const _GUIDELESS_ALLOWLIST: Array[int] = [9, 10]

# (a) published 캠페인 스테이지(SceneFlow SoT)별 불변식(codex impl R2-M2):
#     - allowlist 스테이지: guide 부재여야(의도된 placeholder). (b)가 guide-null→카피-free placeholder를 입증.
#     - 그 외 published: guide 존재 + 로드 가능 + pages non-empty 필수. **guide 누락도 fail**(실수 차단).
#     하드코딩 1..9 대신 PUBLISHED_STAGE_IDS 파생 → 신규 published 스테이지가 guide를 빠뜨리거나 pages
#     빈 guide를 출하하면 자동 fail.
func _check_all_campaign_guides_have_pages() -> void:
	SceneFlow.ensure_stage_scan()
	var ids: Array = SceneFlow.PUBLISHED_STAGE_IDS.keys()
	if ids.is_empty():
		_fail("PUBLISHED_STAGE_IDS 비어있음 — 캠페인 SoT 스캔 실패")
		return
	var with_guide: int = 0
	for n in ids:
		var sid: int = int(n)
		var path: String = "res://data/guides/stage%02d_guide.tres" % sid
		var exists: bool = ResourceLoader.exists(path)
		if sid in _GUIDELESS_ALLOWLIST:
			# 의도된 무가이드 — placeholder 렌더((b)가 안전 입증). guide가 생겼으면 allowlist 갱신 필요.
			if exists:
				_fail("S%d: allowlist(무가이드) 스테이지에 guide 존재 — 의도면 _GUIDELESS_ALLOWLIST에서 제거" % sid)
				return
			continue
		# 비-allowlist published: guide 필수(누락도 fail) + pages non-empty.
		if not exists:
			_fail("S%d: published 스테이지에 guide 누락 — 의도된 placeholder면 _GUIDELESS_ALLOWLIST에 추가" % sid)
			return
		var guide: StageGuideData = ResourceLoader.load(path) as StageGuideData
		if guide == null:
			_fail("S%d: guide 로드 실패 %s" % [sid, path])
			return
		if guide.pages.is_empty():
			_fail("S%d: published 스테이지 guide의 pages 비어있음 — 단일카드 legacy 경로가 사용자에게 노출됨" % sid)
			return
		# 페이징 카드 본문(GuidePage title/body)이 이제 권위 있는 사용자 카피(§2.6.1). pages non-empty만으론
		# 빈/미등록/모드 동사 카피를 못 잡는다(codex impl R3-M). 각 페이지의 title_key·body_key가
		# 등록된 Strings 키 + 해석 텍스트 non-empty + 모드 동사 미포함(모드 중립)임을 강제한다.
		for pi in guide.pages.size():
			var page: GuidePage = guide.pages[pi]
			if not _check_page_copy(sid, pi, page.title_key, "title"):
				return
			if not _check_page_copy(sid, pi, page.body_key, "body"):
				return
		with_guide += 1
	if with_guide == 0:
		_fail("published 스테이지 중 guide 보유 0개 — 경로/SoT 오류 의심")

# 페이지 카피 키 1개 검증: 비어있지 않음 + 등록(Strings.t가 키 자체를 반환하지 않음) + 해석 non-empty +
# 모드 중립(은퇴 동사 미포함). 실패 시 _fail 호출 후 false 반환.
func _check_page_copy(sid: int, page_index: int, key: String, kind: String) -> bool:
	if key == "":
		_fail("S%d page%d: %s_key 비어있음(§2.6.1 — 카드 본문 카피 필수)" % [sid, page_index, kind])
		return false
	var text: String = Strings.t(key)
	if text == key or text == "":
		_fail("S%d page%d: %s_key '%s' 미등록/빈 카피" % [sid, page_index, kind, key])
		return false
	for verb: String in _MODE_VERBS:
		if text.contains(verb):
			_fail("S%d page%d: %s 카피 '%s'에 모드 동사 '%s'(§2.6.1 모드 중립 위반)" % [sid, page_index, kind, text, verb])
			return false
	return true

# (b) guide==null(미저작 stage) → placeholder 본문 + 스킬/해저드 숨김 + 배지/칩 0.
func _check_guide_null_placeholder() -> void:
	var card: StageIntroCard = IntroCardScene.instantiate()
	add_child(card)
	await get_tree().process_frame
	var sd := StageData.new()
	sd.id = 0  # id<=0 → _load_guide null.
	card.show_intro(sd)
	await get_tree().process_frame

	if card.goal_text() != Strings.t("guide.intro_body_placeholder"):
		_fail("guide-null: goal_text '%s' != placeholder" % card.goal_text())
		card.queue_free(); return
	if not card.shown_skill_ids().is_empty():
		_fail("guide-null: shown_skill_ids 비어있지 않음 %s" % str(card.shown_skill_ids()))
		card.queue_free(); return
	if not card.badge_labels().is_empty():
		_fail("guide-null: badge_labels 비어있지 않음 %s" % str(card.badge_labels()))
		card.queue_free(); return
	var skill_list: Control = card.get_node("CardWrapper/Card/Main/Margin/VBox/SkillList")
	var hazard_list: Control = card.get_node("CardWrapper/Card/Main/Margin/VBox/HazardList")
	if skill_list.visible or hazard_list.visible:
		_fail("guide-null: SkillList/HazardList 가시(스킬 카피 노출 위험)")
		card.queue_free(); return
	card.queue_free()
	await get_tree().process_frame

# (c) legacy 단일카드 빌딩 블록(_build_skill_row / _badge_label_of)이 동작 + 배지 모드 중립.
func _check_legacy_render_shape() -> void:
	var card: StageIntroCard = IntroCardScene.instantiate()
	add_child(card)
	await get_tree().process_frame

	# 4 카테고리 대표 스킬의 배지가 모드 중립.
	for id: String in ["climber", "blocker", "basher", "leaf_jump"]:
		var badge: String = card._badge_label_of(id)
		if badge == "":
			_fail("_badge_label_of('%s') 빈 문자열" % id)
			card.queue_free(); return
		for verb: String in _MODE_VERBS:
			if badge.contains(verb):
				_fail("배지 '%s'='%s'에 모드 동사 '%s'(모드 중립 위반)" % [id, badge, verb])
				card.queue_free(); return

	# 단일카드 행 빌더가 살아있음(렌더 shape regression 가드).
	var row: Control = card._build_skill_row("climber", card._badge_label_of("climber"), "테스트 설명")
	if row == null or row.get_child_count() == 0:
		_fail("_build_skill_row가 빈 노드 반환(legacy 렌더 깨짐)")
		card.queue_free(); return
	row.queue_free()
	card.queue_free()
	await get_tree().process_frame

# (d) stateful 재사용(codex impl R4): 같은 카드가 페이징 가이드(S1) → 무가이드(id=0) 재표시 시
#     페이징 상태가 리셋돼 stale 페이지가 노출되지 않음을 단언(실 SceneFlow는 카드 1개를 재사용).
func _check_paged_to_null_reset() -> void:
	var card: StageIntroCard = IntroCardScene.instantiate()
	add_child(card)
	await get_tree().process_frame
	var page_root: Control = card.get_node("CardWrapper/Card/Main/Margin/PageRoot")
	var vbox: Control = card.get_node("CardWrapper/Card/Main/Margin/VBox")

	# 1) 페이징 가이드(S1 = 3페이지) 표시.
	var s1: StageData = ResourceLoader.load("res://data/stages/stage01.tres") as StageData
	if s1 == null:
		_fail("reuse: stage01.tres 로드 실패"); card.queue_free(); return
	card.show_intro(s1)
	await get_tree().process_frame
	if card.page_count() != 3 or not page_root.visible:
		_fail("reuse: S1 표시 후 page_count=%d page_root.visible=%s (페이징 미진입)" % [card.page_count(), str(page_root.visible)])
		card.queue_free(); return

	# 2) 같은 카드에 무가이드(id=0) 재표시 → 페이징 리셋 + placeholder.
	var sd := StageData.new()
	sd.id = 0
	card.show_intro(sd)
	await get_tree().process_frame
	if card.page_count() != 0:
		_fail("reuse: 무가이드 재표시 후 page_count %d != 0 (stale 페이지 잔존)" % card.page_count())
		card.queue_free(); return
	if page_root.visible:
		_fail("reuse: 무가이드 재표시 후에도 PageRoot 가시 — stale 페이징 카드 노출(버그)")
		card.queue_free(); return
	if not vbox.visible:
		_fail("reuse: 무가이드 재표시 후 VBox 비가시 — placeholder 안 보임")
		card.queue_free(); return
	if card.goal_text() != Strings.t("guide.intro_body_placeholder"):
		_fail("reuse: 무가이드 재표시 goal '%s' != placeholder" % card.goal_text())
		card.queue_free(); return
	card.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	push_error("StageIntroCardFallbackTest FAIL " + msg)
	print("[StageIntroCardFallbackTest] FAIL ", msg)
	get_tree().quit(1)
