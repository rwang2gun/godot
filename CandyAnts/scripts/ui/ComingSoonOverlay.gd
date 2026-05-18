class_name ComingSoonOverlay
extends Control

# Phase 13 — plan §3.7. Settings/Credits/COMING_SOON 슬롯 클릭 시 표시.
# Dialog-local Esc 처리 (plan Δ11).

@onready var _backdrop: ColorRect = $Backdrop
@onready var _card: Control = $CardWrapper/Card
@onready var _close_btn: CButton = $CardWrapper/Card/VBox/CloseBtn

var _fade_tween: Tween = null
var _hiding: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	_close_btn.pressed.connect(_on_close_pressed)

# 테스트 R1 fix: Godot 4의 show()/hide()는 CanvasItem 가상 메서드와 충돌(parse error).
# show_overlay()/hide_overlay()로 rename — StageDialog와 동일 패턴.
func show_overlay() -> void:
	# Self-Review R1 HIGH-S1: visible 가드 제거 — hide_overlay() 진행 중 재호출에도 정상 normalize.
	# 옛 fade tween을 kill하고 visible/modulate를 다시 활성화 상태로 reset.
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	_hiding = false
	visible = true
	modulate.a = 1.0
	Motion.fade_in(_backdrop, 0.18, true)
	Motion.caPop(_card)
	await get_tree().process_frame
	if visible and _close_btn.is_inside_tree():
		_close_btn.grab_focus()

func hide_overlay() -> void:
	if not visible or _hiding:
		return
	_hiding = true
	_fade_tween = Motion.fade_out(self, 0.15, true)
	_fade_tween.finished.connect(func() -> void:
		visible = false
		modulate.a = 1.0
		_hiding = false
		_fade_tween = null
	, CONNECT_ONE_SHOT)

func _on_close_pressed() -> void:
	hide_overlay()

func _unhandled_input(event: InputEvent) -> void:
	# Codex R7 MED fix: visible 상태에서 ESC가 fade_out 진행 중 (`_hiding=true`)에 한 번 더 눌리면
	# StageSelect._unhandled_input으로 fall-through되어 request_main_menu가 발화한다.
	# overlay가 보이는 동안 (애니메이션 진행 포함) 모든 ESC를 무조건 소비, 단 hide 애니메이션 재시작은 안 함.
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if not _hiding:
			hide_overlay()
