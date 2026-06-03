class_name TitleScene
extends Control

# Phase 13 — plan §3.6.1. Title 화면: 인트로 영상 → 로고 → 메인 메뉴.
#
# 인트로 시퀀스 (사용자 결정 2026-06-03):
#   0s          영상(VideoPlayer) 1회 재생 시작. 로고/힌트는 alpha 0.
#   LOGO_DELAY  로고 팝인(scale) + 플로팅 시작 (영상은 계속 재생).
#   영상 끝     마지막 프레임에서 정지 + 힌트 표시 → resting state(_intro_finished).
# 입력 처리 (2-step):
#   - 인트로 진행 중 첫 입력 → 즉시 스킵: 영상 끝 프레임 + 로고/힌트 표시 (메뉴 진입 X).
#   - resting state에서의 입력 → request_main_menu emit (1회).
# ESC는 항상 무시 (plan Δ11 dialog-local).
#
# 로고(LogoPanel): 영상에 이미 캐릭터가 있어 show_mascot=false(마스코트 숨김),
# scale 1.5 base + 등장 시 팝인 + 무한 플로팅(상하 부유)으로 "움직이는 로고".

const TITLE_VIDEO: VideoStream = preload("res://assets/video/title_video.ogv")
const LOGO_DELAY := 8.0          # 영상 재생 후 로고 등장까지(초).
const LOGO_BASE_SCALE := Vector2(2.25, 2.25)
const POP_IN_TIME := 0.55
const FLOAT_AMPLITUDE := 14.0    # 로고 상하 부유 폭(px).
const FLOAT_HALF_PERIOD := 1.1   # 반주기(초).

@onready var _video: VideoStreamPlayer = $VideoPlayer
@onready var _logo_panel: Control = $LogoPanel
@onready var _hint_label: Label = $HintLabel
@onready var _focus_anchor: Control = $FocusAnchor

var _intro_finished: bool = false  # true면 다음 입력이 메뉴로 진입
var _menu_requested: bool = false  # double-fire 차단
var _logo_revealed: bool = false
var _reveal_tween: Tween = null
var _float_tween: Tween = null

func _ready() -> void:
	process_mode = PROCESS_MODE_INHERIT
	_focus_anchor.grab_focus()
	_update_hint(_current_mode())
	if not EventBus.input_mode_changed.is_connected(_on_mode_changed):
		EventBus.input_mode_changed.connect(_on_mode_changed)

	# 인트로 영상 시작.
	if _video != null:
		_video.stream = TITLE_VIDEO
		if not _video.finished.is_connected(_on_video_finished):
			_video.finished.connect(_on_video_finished)
		_video.play()

	# LOGO_DELAY 후 로고 등장 (스킵/완료 시 _show_logo가 자체 가드).
	get_tree().create_timer(LOGO_DELAY).timeout.connect(_show_logo)

func _exit_tree() -> void:
	if EventBus.input_mode_changed.is_connected(_on_mode_changed):
		EventBus.input_mode_changed.disconnect(_on_mode_changed)

func _unhandled_input(event: InputEvent) -> void:
	# ESC 명시 무시 — title은 아무 키나 받지만 esc만 예외.
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		return
	# Key / MouseButton / JoypadButton + pressed + !echo만 진입.
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if not event.pressed:
		return
	if event is InputEventKey and event.echo:
		return
	get_viewport().set_input_as_handled()
	if not _intro_finished:
		# 첫 입력: 인트로 스킵 → 로고 + 영상 끝 프레임. (메뉴 진입 X)
		_finish_intro(true)
		return
	# resting state: 추가 입력 → 메인 메뉴.
	if _menu_requested:
		return
	_menu_requested = true
	EventBus.request_main_menu.emit()

func _show_logo() -> void:
	# LOGO_DELAY 타이머 콜백. 이미 스킵/완료됐으면 _reveal_logo가 자체 가드.
	if not is_inside_tree():
		return
	_reveal_logo(true)

func _on_video_finished() -> void:
	# 영상 1회 재생 자연 종료 → 마지막 프레임 유지 + resting state 진입.
	_finish_intro(false)

func _finish_intro(skip: bool) -> void:
	if _intro_finished:
		return
	_intro_finished = true
	if skip and _video != null:
		# 영상 끝 프레임으로 시킹 후 정지.
		var length: float = _video.get_stream_length()
		if length > 0.0:
			_video.stream_position = maxf(0.0, length - 0.05)
		_video.paused = true
	# 스킵이면 즉시 표시, 자연 종료면 이미 8s에 등장했으므로 no-op.
	_reveal_logo(not skip)
	_show_hint()

func _reveal_logo(animate: bool) -> void:
	if _logo_revealed:
		return
	_logo_revealed = true
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	if animate:
		_logo_panel.scale = LOGO_BASE_SCALE * 0.6
		_reveal_tween = create_tween().set_parallel(true)
		_reveal_tween.tween_property(_logo_panel, "modulate:a", 1.0, 0.5)
		_reveal_tween.tween_property(_logo_panel, "scale", LOGO_BASE_SCALE, POP_IN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_reveal_tween.chain().tween_callback(_start_logo_float)
	else:
		_logo_panel.modulate.a = 1.0
		_logo_panel.scale = LOGO_BASE_SCALE
		_start_logo_float()

func _start_logo_float() -> void:
	if not is_inside_tree() or _logo_panel == null:
		return
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	var base_y: float = _logo_panel.position.y
	_float_tween = create_tween().set_loops() \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(_logo_panel, "position:y", base_y - FLOAT_AMPLITUDE, FLOAT_HALF_PERIOD)
	_float_tween.tween_property(_logo_panel, "position:y", base_y, FLOAT_HALF_PERIOD)

func _show_hint() -> void:
	if _hint_label == null:
		return
	create_tween().tween_property(_hint_label, "modulate:a", 1.0, 0.4)

func _current_mode() -> StringName:
	# InputModeTracker의 mode는 private `_mode` + public `get_mode()` (phase 8 산출).
	# `.mode` 직접 접근은 invalid — get_mode() 사용 (테스트 R1 fix).
	return InputModeTracker.get_mode() if InputModeTracker != null else &"keyboard"

func _update_hint(mode: StringName) -> void:
	if _hint_label == null:
		return
	_hint_label.text = Strings.t("title.hint_pad") if mode == &"pad" else Strings.t("title.hint_key")

func _on_mode_changed(mode: StringName) -> void:
	_update_hint(mode)
