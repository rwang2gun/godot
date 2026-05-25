class_name StageDialog
extends Control

# Phase 12 — UI_GUIDE §4 (Motion) + §5.3 (Scoring). plan v6.1 §3.2/§3.3 SoT.
# 외부 API: show_result(result, is_last_stage) + hide_overlay() — 구 StageResultOverlayStub과 1:1 호환 (SceneFlow 무변경).
# 내부 race 차단: _dismiss_token generation guard로 stale request_* emit 봉쇄.

static var _STAR_POLYGON: PackedVector2Array = PackedVector2Array([
	Vector2(0, -22),
	Vector2(5, -7),
	Vector2(21, -7),
	Vector2(8, 3),
	Vector2(13, 18),
	Vector2(0, 9),
	Vector2(-13, 18),
	Vector2(-8, 3),
	Vector2(-21, -7),
	Vector2(-5, -7),
])

@onready var _backdrop: ColorRect = $Backdrop
@onready var _card: Control = $CardWrapper/Card
@onready var _title: Label = $CardWrapper/Card/Main/Margin/VBox/Title
@onready var _subtitle: Label = $CardWrapper/Card/Main/Margin/VBox/Subtitle
@onready var _hero_score: Label = $CardWrapper/Card/Main/Margin/VBox/HeroScore
@onready var _star1: Polygon2D = $CardWrapper/Card/Main/Margin/VBox/StarRow/Star1/Poly
@onready var _star2: Polygon2D = $CardWrapper/Card/Main/Margin/VBox/StarRow/Star2/Poly
@onready var _star3: Polygon2D = $CardWrapper/Card/Main/Margin/VBox/StarRow/Star3/Poly
@onready var _chip_saved: Chip = $CardWrapper/Card/Main/Margin/VBox/StatChips/ChipSaved
@onready var _chip_lost: Chip = $CardWrapper/Card/Main/Margin/VBox/StatChips/ChipLost
@onready var _chip_time: Chip = $CardWrapper/Card/Main/Margin/VBox/StatChips/ChipTime
@onready var _replay_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/ButtonRow/ReplayBtn
@onready var _next_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/ButtonRow/NextBtn
@onready var _menu_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/ButtonRow/MenuBtn

var _dismissing: bool = false
var _dismiss_tween: Tween = null
var _capop_tween: Tween = null
var _dismiss_token: int = 0
var _next_should_be_disabled: bool = true

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	for poly in [_star1, _star2, _star3]:
		poly.polygon = _STAR_POLYGON
		poly.color = Tokens.CREAM_200
	_replay_btn.pressed.connect(_on_replay_pressed)
	_next_btn.pressed.connect(_on_next_pressed)
	_menu_btn.pressed.connect(_on_menu_pressed)

func show_result(result: Dictionary, is_last_stage: bool) -> void:
	# Step 0: prior tween cleanup + generation token bump (plan §3.2/§3.3).
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
	# Step 1: parse result (defensive defaults for missing keys).
	var cleared: bool = result.get("cleared", false)
	var saved: int = int(result.get("saved", 0))
	var lost: int = int(result.get("lost", 0))
	var original_hp: int = int(result.get("original_hp", 0))
	var time_left: float = float(result.get("time_left", 0.0))
	# Step 2: text 갱신. Phase 20 — last-stage cleared variant 분기 (P-D6).
	if cleared and is_last_stage:
		_title.text = "마지막 단계 클리어!"
		_subtitle.text = "Stage cleared"
	elif cleared:
		_title.text = "사탕을 무사히 옮겼어요!"
		_subtitle.text = "Stage cleared"
	else:
		_title.text = "사탕이 부족했어요"
		_subtitle.text = "Stage failed"
	_hero_score.text = "%d / %d 조각" % [saved, original_hp]
	# Step 3: stat chips.
	_chip_saved.set_label_value("귀가", str(saved))
	_chip_lost.set_label_value("잃음", str(lost))
	_chip_time.set_label_value("남은 시간", "%ds" % int(time_left))
	# Step 4: star fill + sfx_request(star_fill) per filled star.
	# Phase 20 — stage별 star_thresholds override 전달. 빈 배열이면 글로벌 fall-back.
	var thresholds: Array = result.get("star_thresholds", [])
	var stars := Scoring.compute_stars(saved, original_hp, thresholds)
	var star_polys := [_star1, _star2, _star3]
	for i in star_polys.size():
		var filled := i < stars
		star_polys[i].color = Tokens.LEMON_500 if filled else Tokens.CREAM_200
		if filled:
			EventBus.sfx_request.emit(&"star_fill")
	# Step 5: NextBtn 분기 + _next_should_be_disabled 갱신.
	if cleared and not is_last_stage:
		_next_btn.visible = true
		_next_should_be_disabled = false
	elif cleared and is_last_stage:
		_next_btn.visible = true
		_next_should_be_disabled = true
	else:
		_next_btn.visible = false
		_next_should_be_disabled = true
	# Step 6: enable Replay/Menu, Next preserves _next_should_be_disabled contract.
	_enable_all_buttons()
	# Step 7: visible + motion.
	visible = true
	Motion.fade_in(_backdrop, 0.18, true)
	_capop_tween = Motion.caPop(_card)
	# Step 8: dialog sfx emits.
	EventBus.sfx_request.emit(&"dialog_open")
	EventBus.sfx_request.emit(&"dialog_stats_pop")

func hide_overlay() -> void:
	# SceneFlow가 _on_request_replay/next/menu에서 호출 (구 stub과 동일 contract).
	# fade 없이 즉시 reset. dismiss fade window 도중 호출돼도 stuck 안 됨 (plan v6.1 §3.2).
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
	_enable_all_buttons()

func is_next_disabled() -> bool:
	return _next_btn.disabled

func is_next_visible() -> bool:
	return _next_btn.visible

# 별 채움 상태 검증 inspector (plan v6.1 §3.2 L-1 주의: 단순 color compare).
func star_filled_count() -> int:
	var n := 0
	for poly in [_star1, _star2, _star3]:
		if poly.color.is_equal_approx(Tokens.LEMON_500):
			n += 1
	return n

func _on_replay_pressed() -> void:
	_dismiss_then_emit(EventBus.request_replay)

func _on_next_pressed() -> void:
	_dismiss_then_emit(EventBus.request_next)

func _on_menu_pressed() -> void:
	_dismiss_then_emit(EventBus.request_menu)

func _dismiss_then_emit(signal_ref: Signal) -> void:
	if _dismissing:
		return
	_dismissing = true
	_dismiss_token += 1
	var token: int = _dismiss_token
	_disable_all_buttons()
	# dialog_btn_press emit 직전에 1회 (plan §3.7).
	EventBus.sfx_request.emit(&"dialog_btn_press")
	_dismiss_tween = Motion.fade_out(self, 0.15, true)
	_dismiss_tween.finished.connect(func() -> void:
		# Generation guard: stale captured token이면 reject (plan §3.3).
		if token != _dismiss_token:
			return
		if not _dismissing:
			return
		visible = false
		modulate.a = 1.0
		_dismissing = false
		_dismiss_tween = null
		signal_ref.emit()
	, CONNECT_ONE_SHOT)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _dismissing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_dismiss_then_emit(EventBus.request_menu)

func _set_buttons_disabled(disabled: bool) -> void:
	_replay_btn.disabled = disabled
	_menu_btn.disabled = disabled
	# Next preserves contract — dismiss disables; otherwise restored to _next_should_be_disabled.
	_next_btn.disabled = disabled or _next_should_be_disabled

func _disable_all_buttons() -> void:
	_set_buttons_disabled(true)

func _enable_all_buttons() -> void:
	_set_buttons_disabled(false)
