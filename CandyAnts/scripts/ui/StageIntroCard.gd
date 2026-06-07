class_name StageIntroCard
extends Control

# Phase 4 (intro-card-infra) — 스테이지 진입 인트로 카드. STAGE_GUIDE_PLAN §2.1~§2.3.
# Phase 5 (guide-data-copy) — placeholder → StageGuideData 바인딩(타이틀·목표·스킬칩·배지·해저드). §2.4·§4.
#
# StageDialog(결과 카드)의 검증된 race/pause 안전 패턴을 복제한다:
#   - PROCESS_MODE_ALWAYS: 게임이 멈춰도(또는 begin 게이트로 정지 상태여도) 카드 입력은 동작.
#   - _dismiss_token generation guard: fade_out 도중 재호출/하이드돼도 stale intro_dismissed emit 봉쇄.
# 카피는 100% Strings.gd(`guide.*`) — 씬 하드코딩 0. 스킬 칩 = 아이콘(SkillToolbar.ICONS) + 라벨
# (Strings.skill_label) + 입력모델 배지(SkillAffordance.category 파생, 어포던스와 동일 어휘).
# 외부 API: show_intro(stage_data) / hide_intro() / is_showing() / shown_skill_ids() + intro_dismissed 시그널.
# 검사 inspector(테스트): goal_text() / badge_labels() / skill_desc_texts() / hazard_texts().

signal intro_dismissed

const _ChipScene: PackedScene = preload("res://scenes/ui/atoms/Chip.tscn")

# 입력모델 배지 key — SkillAffordance.Category당 1(스킬 공유, STAGE_GUIDE_PLAN §0.8.6).
const _BADGE_KEYS := {
	SkillAffordance.Category.ANT_ARMED:  "guide.badge.ant_armed",
	SkillAffordance.Category.ANT_SETTLE: "guide.badge.ant_settle",
	SkillAffordance.Category.SIGN:       "guide.badge.sign",
	SkillAffordance.Category.DEVICE:     "guide.badge.device",
}

# 본문 폰트 — 라이트 유저 가독성 위해 전부 ≥20pt(사용자 요청 2026-06-07). 카드는 콘텐츠 폭에
# 맞춰 자동 확대되고(아래 _resize_to_content) 라벨은 autowrap을 꺼 한 줄로 렌더(줄바꿈 없음).
const _DESC_FONT_SIZE := 22
const _HAZARD_FONT_SIZE := 22
const _SKILL_NAME_FONT_SIZE := 24
# 콘텐츠 기반 카드 폭/높이 한계(px). 긴 설명 한 줄이 다 보이도록 넓게, 화면(>=1124) 안에서 캡.
const _MIN_CARD_W := 560.0
const _MAX_CARD_W := 1080.0
const _MIN_CARD_H := 320.0

# 페이징 카드(guide-card-ui-restructure) — 스크린샷 위 오버레이 제목/본문.
const _PAGE_TITLE_FONT := 32
const _PAGE_BODY_FONT := 24
const _DOT_SIZE := 16.0
# 이미지 영역 설계 크기(scenes/ui/StageIntroCard.tscn ImageWrap와 동기) — 정규화 좌표→px 변환 기준.
const _IMG_W := 640.0
const _IMG_H := 400.0
const _SCRIM_PAD_X := 18.0   # 스크림 좌우 안쪽 여백
const _SCRIM_PAD_TOP := 12.0
const _SCRIM_PAD_BOT := 14.0

@onready var _backdrop: ColorRect = $Backdrop
@onready var _card: Control = $CardWrapper/Card
@onready var _main: PanelContainer = $CardWrapper/Card/Main
@onready var _vbox: VBoxContainer = $CardWrapper/Card/Main/Margin/VBox
@onready var _title: Label = $CardWrapper/Card/Main/Margin/VBox/Title
@onready var _goal: Label = $CardWrapper/Card/Main/Margin/VBox/Goal
@onready var _skill_list: VBoxContainer = $CardWrapper/Card/Main/Margin/VBox/SkillList
@onready var _hazard_list: VBoxContainer = $CardWrapper/Card/Main/Margin/VBox/HazardList
@onready var _start_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/ButtonRow/StartBtn
@onready var _skip_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/ButtonRow/SkipBtn
# 페이징 서브트리.
@onready var _page_root: VBoxContainer = $CardWrapper/Card/Main/Margin/PageRoot
@onready var _image_wrap: Control = $CardWrapper/Card/Main/Margin/PageRoot/ImageWrap
@onready var _dots: HBoxContainer = $CardWrapper/Card/Main/Margin/PageRoot/NavRow/Dots
@onready var _prev_btn: CButton = $CardWrapper/Card/Main/Margin/PageRoot/NavRow/LeftZone/PrevBtn
@onready var _next_btn: CButton = $CardWrapper/Card/Main/Margin/PageRoot/NavRow/RightZone/NextBtn
@onready var _start_btn_p: CButton = $CardWrapper/Card/Main/Margin/PageRoot/NavRow/RightZone/StartBtnP
@onready var _skip_btn_p: CButton = $CardWrapper/Card/Main/Margin/PageRoot/NavRow/RightZone/SkipBtnP

var _dismissing: bool = false
var _dismiss_tween: Tween = null
var _capop_tween: Tween = null
var _dismiss_token: int = 0
# 카드가 광고하는 신규 스킬 id(드리프트 가드 inspector). 가이드 new_skill_ids 미러.
var _shown_skill_ids: Array[String] = []
# 검사 inspector 캐시(렌더 검증 테스트). 칩과 1:1 평행. 화면 표시는 문장 단위 줄바꿈을 적용하지만
# inspector는 항상 raw Strings 카피를 반환(테스트가 Strings.t와 직접 대조).
var _goal_raw: String = ""
var _badge_labels: Array[String] = []
var _skill_desc_texts: Array[String] = []
var _hazard_texts: Array[String] = []

# 페이징 상태(guide.pages 비어있지 않을 때). 비어있으면 기존 단일 카드 경로.
var _pages: Array[GuidePage] = []
var _page_index: int = 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_start_btn.pressed.connect(_on_dismiss_pressed)
	_skip_btn.pressed.connect(_on_dismiss_pressed)
	# 페이징 NavRow: 시작/건너뛰기는 dismiss, 이전/다음은 페이지 이동.
	_start_btn_p.pressed.connect(_on_dismiss_pressed)
	_skip_btn_p.pressed.connect(_on_dismiss_pressed)
	_prev_btn.pressed.connect(_on_prev_pressed)
	_next_btn.pressed.connect(_on_next_pressed)

# 카드를 노출한다. stage_data.id로 data/guides/stageNN_guide.tres를 조회해 내용 바인딩.
# 가이드 없으면(S9·로드 실패) 타이틀+fallback 본문만(카드 생략 톤). stage_data null도 안전.
func show_intro(stage_data: StageData) -> void:
	# prior tween cleanup + generation token bump (StageDialog.show_result 패턴).
	_dismiss_token += 1
	if _dismiss_tween and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
	_dismiss_tween = null
	if _capop_tween and _capop_tween.is_valid():
		_capop_tween.kill()
	_capop_tween = null
	_dismissing = false
	modulate.a = 1.0
	_card.scale = Vector2.ONE

	_bind_content(stage_data)

	_start_btn.disabled = false
	_skip_btn.disabled = false
	_start_btn_p.disabled = false
	_skip_btn_p.disabled = false
	_prev_btn.disabled = false
	_next_btn.disabled = false
	visible = true
	Motion.fade_in(_backdrop, 0.18, true)
	_capop_tween = Motion.caPop(_card)
	EventBus.sfx_request.emit(&"dialog_open")

	# 카드를 콘텐츠(가장 긴 줄) 폭/높이에 맞춰 자동 확대 — 컨테이너 min size가 한 프레임 뒤 정착하므로
	# 다음 process_frame에 측정. 순수 시각 처리(inspector는 _bind_content에서 이미 동기 확정)라 테스트 무영향.
	if is_inside_tree():
		await get_tree().process_frame
		if visible and is_node_ready():
			_resize_to_content()

# 타이틀/목표/스킬칩/해저드를 가이드 데이터로 채운다(또는 fallback).
func _bind_content(stage_data: StageData) -> void:
	_shown_skill_ids = []
	_goal_raw = ""
	_badge_labels = []
	_skill_desc_texts = []
	_hazard_texts = []
	_clear_children(_skill_list)
	_clear_children(_hazard_list)

	# 타이틀 = display_name(없으면 fallback).
	var title_text: String = Strings.t("guide.intro_title")
	if stage_data != null and stage_data.display_name != "":
		title_text = stage_data.display_name
	_title.text = title_text

	var guide: StageGuideData = _load_guide(stage_data)
	if guide == null:
		# 가이드 없음 — 목표 라벨에 fallback 본문, 스킬/해저드 빈 채로(카드 생략 톤).
		# CRITICAL(codex impl R4): 같은 카드 인스턴스가 직전에 페이징 가이드(예: S8)를 보였다가
		# 무가이드 스테이지(예: S9 allowlist)로 재사용되면, 페이징 상태를 리셋하지 않으면 _page_root에
		# stale 페이지(직전 스크린샷)가 남아 노출된다. 단일카드 경로로 되돌리고 페이징 잔재를 비운다.
		_use_single_card()
		_clear_children(_image_wrap)
		_clear_children(_dots)
		_goal_raw = Strings.t("guide.intro_body_placeholder")
		_goal.text = _goal_raw
		_skill_list.visible = false
		_hazard_list.visible = false
		return

	_goal_raw = Strings.t(guide.goal_key)
	_goal.text = _goal_raw

	# 인스펙터/드리프트 가드용 데이터는 페이징 여부와 무관하게 항상 채운다(기존 테스트 의존).
	for i in guide.new_skill_ids.size():
		var sid: String = guide.new_skill_ids[i]
		var sdesc_key: String = guide.skill_desc_keys[i] if i < guide.skill_desc_keys.size() else ""
		_shown_skill_ids.append(sid)
		_badge_labels.append(_badge_label_of(sid))
		_skill_desc_texts.append(Strings.t(sdesc_key) if sdesc_key != "" else "")
	for hk0: String in guide.hazard_keys:
		_hazard_texts.append(Strings.t(hk0))

	# 페이징 카드(스테이지가 pages를 저작했을 때) — 단일 카드 대신 항목별 스크린샷 페이지.
	if not guide.pages.is_empty():
		_bind_pages(guide)
		return

	# 이하 기존 단일 카드 경로(S2~S8) — 스킬 칩 + 해저드.
	_use_single_card()

	# 스킬 칩 — 신규 스킬마다 [아이콘+라벨+배지] 헤더 + 설명 1~2줄. (인스펙터 배열은 위에서 이미 채움.)
	# skill_desc_keys가 new_skill_ids보다 짧으면 빈 설명으로 안전 진행(드리프트 가드가 별도로 불일치를 잡음).
	for i in guide.new_skill_ids.size():
		var id: String = guide.new_skill_ids[i]
		var desc_key: String = guide.skill_desc_keys[i] if i < guide.skill_desc_keys.size() else ""
		var desc_text: String = Strings.t(desc_key) if desc_key != "" else ""
		_skill_list.add_child(_build_skill_row(id, _badge_label_of(id), desc_text))
	_skill_list.visible = not guide.new_skill_ids.is_empty()

	# 해저드 경고 — ⚠ 프리픽스 포함 카피(Strings).
	for hk: String in guide.hazard_keys:
		_hazard_list.add_child(_build_hazard_label(Strings.t(hk)))
	_hazard_list.visible = not guide.hazard_keys.is_empty()

# 단일 카드 경로: VBox 보이고 페이징 숨김.
func _use_single_card() -> void:
	_pages = []
	_page_index = 0
	_vbox.visible = true
	_page_root.visible = false

# ── 페이징 카드 ─────────────────────────────────────────────────────────────
# guide.pages를 페이지 스택으로 렌더한다(스크린샷 + 오버레이 제목/본문 + 점 인디케이터 + 이전/다음/시작).
func _bind_pages(guide: StageGuideData) -> void:
	_pages = guide.pages.duplicate()
	_page_index = 0
	_vbox.visible = false
	_page_root.visible = true
	_render_page()

# 현재 페이지의 이미지+오버레이 + 점 + 내비 버튼 가시성을 갱신.
func _render_page() -> void:
	_clear_children(_image_wrap)
	_clear_children(_dots)
	if _page_index < 0 or _page_index >= _pages.size():
		return
	var page: GuidePage = _pages[_page_index]

	# 배경 스크린샷(이미지 없으면 텍스트만, 크림 배경 유지). 줌/이동(크롭)은 중심 기준 scale + position.
	if page.image_path != "" and ResourceLoader.exists(page.image_path):
		var tex := load(page.image_path) as Texture2D
		if tex != null:
			var img := TextureRect.new()
			img.texture = tex
			img.set_anchors_preset(Control.PRESET_FULL_RECT)
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			img.pivot_offset = Vector2(_IMG_W, _IMG_H) * 0.5
			img.scale = Vector2.ONE * maxf(0.1, page.image_zoom)
			img.position = Vector2(page.image_pan_x * _IMG_W * 0.5, page.image_pan_y * _IMG_H * 0.5)
			_image_wrap.add_child(img)

	# 오버레이 — 스크린샷 위 반투명 패널(스크림) + 제목 / 구분선 / 본문. 위치·폭·정렬·스크림은 페이지 데이터.
	var halign: int = HORIZONTAL_ALIGNMENT_LEFT
	match page.text_align:
		"center": halign = HORIZONTAL_ALIGNMENT_CENTER
		"right": halign = HORIZONTAL_ALIGNMENT_RIGHT

	var w_px: float = clampf(page.text_width, 0.05, 1.0) * _IMG_W
	var x_px: float = clampf(page.text_x, 0.0, 1.0) * _IMG_W
	var y_px: float = clampf(page.text_y, 0.0, 1.0) * _IMG_H
	var inner_w: float = maxf(40.0, w_px - 2.0 * _SCRIM_PAD_X)

	var scrim := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var sc: Color = page.scrim_color
	sb.bg_color = Color(sc.r, sc.g, sc.b, page.scrim_opacity if page.scrim_enabled else 0.0)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = _SCRIM_PAD_X
	sb.content_margin_right = _SCRIM_PAD_X
	sb.content_margin_top = _SCRIM_PAD_TOP
	sb.content_margin_bottom = _SCRIM_PAD_BOT
	scrim.add_theme_stylebox_override("panel", sb)

	var tb := VBoxContainer.new()
	tb.add_theme_constant_override("separation", 8)
	scrim.add_child(tb)

	var title_text: String = Strings.t(page.title_key) if page.title_key != "" else ""
	var body_text: String = Strings.t(page.body_key) if page.body_key != "" else ""

	if title_text != "":
		var title := Label.new()
		title.text = title_text
		title.autowrap_mode = TextServer.AUTOWRAP_WORD
		title.horizontal_alignment = halign
		title.custom_minimum_size.x = inner_w
		title.add_theme_font_size_override("font_size", _PAGE_TITLE_FONT)
		title.add_theme_color_override("font_color", Tokens.CREAM_50)
		tb.add_child(title)

	# 제목·본문이 둘 다 있을 때만 가로 구분선.
	if title_text != "" and body_text != "":
		var div := ColorRect.new()
		div.color = Color(Tokens.CREAM_50.r, Tokens.CREAM_50.g, Tokens.CREAM_50.b, 0.55)
		div.custom_minimum_size = Vector2(inner_w, 2)
		tb.add_child(div)

	if body_text != "":
		var body := Label.new()
		body.text = body_text
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.horizontal_alignment = halign
		body.custom_minimum_size.x = inner_w
		body.add_theme_font_size_override("font_size", _PAGE_BODY_FONT)
		body.add_theme_color_override("font_color", Tokens.CREAM_50)
		tb.add_child(body)

	_image_wrap.add_child(scrim)
	scrim.position = Vector2(x_px, y_px)
	scrim.size = Vector2(w_px, scrim.get_combined_minimum_size().y)

	# 점 인디케이터.
	for i in _pages.size():
		_dots.add_child(_make_dot(i == _page_index))

	# 내비 버튼 가시성 — 첫/끝 페이지에 맞춰.
	var last: bool = _page_index >= _pages.size() - 1
	_prev_btn.visible = _page_index > 0
	_next_btn.visible = not last
	_start_btn_p.visible = last
	_skip_btn_p.visible = not last

func _make_dot(active: bool) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(_DOT_SIZE, _DOT_SIZE)
	# HBox 세로 채움으로 막대가 되지 않도록 고정 크기 + 중앙 정렬.
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tokens.INK_700 if active else Tokens.CREAM_300
	sb.set_corner_radius_all(int(_DOT_SIZE / 2.0))
	dot.add_theme_stylebox_override("panel", sb)
	return dot

func _on_prev_pressed() -> void:
	if _page_index <= 0:
		return
	_page_index -= 1
	EventBus.sfx_request.emit(&"dialog_btn_press")
	_render_page()

func _on_next_pressed() -> void:
	if _page_index >= _pages.size() - 1:
		return
	_page_index += 1
	EventBus.sfx_request.emit(&"dialog_btn_press")
	_render_page()

# stage_data.id → data/guides/stageNN_guide.tres. 없으면 null(graceful).
func _load_guide(stage_data: StageData) -> StageGuideData:
	if stage_data == null or stage_data.id <= 0:
		return null
	var path: String = "res://data/guides/stage%02d_guide.tres" % stage_data.id
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	return res as StageGuideData

# 입력모델 배지 텍스트 = SkillAffordance 카테고리 파생(어포던스/커서와 동일 SoT).
func _badge_label_of(id: String) -> String:
	var cat: int = SkillAffordance.category_of(id)
	var key: String = _BADGE_KEYS.get(cat, "")
	return Strings.t(key) if key != "" else ""

# 스킬 칩 1행: [아이콘 | 라벨 | 배지] 헤더 + 설명 라벨.
func _build_skill_row(id: String, badge_text: String, desc_text: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := TextureRect.new()
	icon.texture = SkillToolbar.ICONS.get(id) as Texture2D
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = Strings.skill_label(id)
	name_label.add_theme_font_size_override("font_size", _SKILL_NAME_FONT_SIZE)
	header.add_child(name_label)

	var badge := _ChipScene.instantiate() as Chip
	badge.value = badge_text
	badge.tint = Tokens.TintKind.GRAPE
	header.add_child(badge)

	row.add_child(header)

	if desc_text != "":
		var desc := Label.new()
		# autowrap OFF — 한 줄로 렌더(줄바꿈 없음, 사용자 요청). 카드는 _resize_to_content가 이 줄 폭에 맞춰 확대.
		desc.text = desc_text
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", _DESC_FONT_SIZE)
		row.add_child(desc)

	return row

func _build_hazard_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _HAZARD_FONT_SIZE)
	label.add_theme_color_override("font_color", Tokens.BERRY_500)
	return label

# 카드를 콘텐츠(가장 긴 한 줄) 폭/높이에 맞춰 확대. autowrap OFF라 Main의 combined min size가
# 가장 긴 라벨 폭을 반영 → Card에 반영하고 pivot을 중심으로 갱신(caPop 스케일 기준). [_MIN..MAX] 캡.
func _resize_to_content() -> void:
	if _main == null or _card == null:
		return
	var content: Vector2 = _main.get_combined_minimum_size()
	var w: float = clampf(content.x, _MIN_CARD_W, _MAX_CARD_W)
	var h: float = maxf(content.y, _MIN_CARD_H)
	_card.custom_minimum_size = Vector2(w, h)
	_card.pivot_offset = Vector2(w, h) * 0.5

func _clear_children(container: Node) -> void:
	for c in container.get_children():
		c.queue_free()
		container.remove_child(c)

# SceneFlow가 카드 표시 중 화면 전환(replay/menu) 시 강제로 즉시 숨김. intro_dismissed emit 안 함.
# SceneFlow._boot()는 이 카드의 _ready보다 먼저 _reset_intro_card→hide_intro를 호출할 수 있으므로
# (@onready _card 등이 아직 null) ready 전이면 no-op. 부트 시점엔 어차피 숨김 상태라 안전.
func hide_intro() -> void:
	if not is_node_ready():
		return
	_dismiss_token += 1
	if _dismiss_tween and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
	_dismiss_tween = null
	if _capop_tween and _capop_tween.is_valid():
		_capop_tween.kill()
	_capop_tween = null
	visible = false
	modulate.a = 1.0
	_card.scale = Vector2.ONE
	_dismissing = false

func is_showing() -> bool:
	return visible

# 드리프트 가드용 inspector — 카드가 광고하는 신규 스킬 id (가이드 new_skill_ids 미러).
func shown_skill_ids() -> Array[String]:
	return _shown_skill_ids.duplicate()

# 렌더 검증 inspector(테스트) — 칩과 1:1 평행.
func goal_text() -> String:
	return _goal_raw

func badge_labels() -> Array[String]:
	return _badge_labels.duplicate()

func skill_desc_texts() -> Array[String]:
	return _skill_desc_texts.duplicate()

func hazard_texts() -> Array[String]:
	return _hazard_texts.duplicate()

# 페이징 inspector(테스트) — pages 저작 스테이지에서만 비어있지 않음.
func page_count() -> int:
	return _pages.size()

func current_page() -> int:
	return _page_index

func page_titles() -> Array[String]:
	var out: Array[String] = []
	for p: GuidePage in _pages:
		out.append(Strings.t(p.title_key) if p.title_key != "" else "")
	return out

func page_bodies() -> Array[String]:
	var out: Array[String] = []
	for p: GuidePage in _pages:
		out.append(Strings.t(p.body_key) if p.body_key != "" else "")
	return out

func _on_dismiss_pressed() -> void:
	_dismiss()

# "시작"/"건너뛰기"/Esc 모두 동일 — 카드를 닫고 intro_dismissed emit(스테이지 begin).
func _dismiss() -> void:
	if _dismissing or not visible:
		return
	_dismissing = true
	_dismiss_token += 1
	var token: int = _dismiss_token
	_start_btn.disabled = true
	_skip_btn.disabled = true
	_start_btn_p.disabled = true
	_skip_btn_p.disabled = true
	_prev_btn.disabled = true
	_next_btn.disabled = true
	EventBus.sfx_request.emit(&"dialog_btn_press")
	_dismiss_tween = Motion.fade_out(self, 0.15, true)
	_dismiss_tween.finished.connect(func() -> void:
		# Generation guard: stale captured token이면 reject (hide_intro/재show 도중 봉쇄).
		if token != _dismiss_token:
			return
		if not _dismissing:
			return
		visible = false
		modulate.a = 1.0
		_dismissing = false
		_dismiss_tween = null
		intro_dismissed.emit()
	, CONNECT_ONE_SHOT)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _dismissing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_dismiss()
