class_name StageIntroCard
extends Control

# Phase 4 (intro-card-infra) — 스테이지 진입 인트로 카드. STAGE_GUIDE_PLAN §2.1~§2.3.
# StageDialog(결과 카드)의 검증된 race/pause 안전 패턴을 복제한다:
#   - PROCESS_MODE_ALWAYS: 게임이 멈춰도(또는 begin 게이트로 정지 상태여도) 카드 입력은 동작.
#   - _dismiss_token generation guard: fade_out 도중 재호출/하이드돼도 stale intro_dismissed emit 봉쇄.
# Phase 4 범위 = 인프라만. 내용(타이틀/스킬 칩/카피)은 placeholder이며 Phase 5에서 StageGuideData로 바인딩.
# 외부 API: show_intro(stage_data) / hide_intro() / is_showing() / shown_skill_ids() + intro_dismissed 시그널.

signal intro_dismissed

@onready var _backdrop: ColorRect = $Backdrop
@onready var _card: Control = $CardWrapper/Card
@onready var _title: Label = $CardWrapper/Card/Main/Margin/VBox/Title
@onready var _body: Label = $CardWrapper/Card/Main/Margin/VBox/Body
@onready var _start_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/ButtonRow/StartBtn
@onready var _skip_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/ButtonRow/SkipBtn

var _dismissing: bool = false
var _dismiss_tween: Tween = null
var _capop_tween: Tween = null
var _dismiss_token: int = 0
# Phase 5에서 채워질 가이드 스킬 id 목록. Phase 4 placeholder는 stage_data.available_skills를 그대로 노출
# (드리프트 가드 테스트가 Phase 5에서 stage.available_skills의 부분집합인지 검사).
var _shown_skill_ids: Array[String] = []

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_start_btn.pressed.connect(_on_dismiss_pressed)
	_skip_btn.pressed.connect(_on_dismiss_pressed)

# 카드를 노출한다. Phase 4 — 내용은 placeholder(타이틀만 display_name 반영). stage_data null도 안전.
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

	_shown_skill_ids = []
	var title_text: String = Strings.t("guide.intro_title")
	if stage_data != null:
		if stage_data.display_name != "":
			title_text = stage_data.display_name
		# Phase 5에서 가이드 리소스로 교체. 현재는 stage available_skills를 그대로 보존(드리프트 가드용).
		_shown_skill_ids = stage_data.available_skills.duplicate()
	_title.text = title_text
	_body.text = Strings.t("guide.intro_body_placeholder")

	_start_btn.disabled = false
	_skip_btn.disabled = false
	visible = true
	Motion.fade_in(_backdrop, 0.18, true)
	_capop_tween = Motion.caPop(_card)
	EventBus.sfx_request.emit(&"dialog_open")

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

# Phase 5 드리프트 가드용 inspector — 카드가 광고하는 스킬 id (현재는 stage.available_skills 미러).
func shown_skill_ids() -> Array[String]:
	return _shown_skill_ids

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
