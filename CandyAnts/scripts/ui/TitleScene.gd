class_name TitleScene
extends Control

# Phase 13 — plan §3.6.1. Title 화면: LogoPanel + hint label.
# 임의 키/마우스 버튼/조이패드 버튼 1회 입력 → request_main_menu emit.
# ESC는 무시 (plan Δ11 dialog-local — 어차피 아무 키나 진입).

@onready var _hint_label: Label = $Center/VBox/HintLabel
@onready var _focus_anchor: Control = $FocusAnchor

var _input_consumed: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_INHERIT
	_focus_anchor.grab_focus()
	_update_hint(_current_mode())
	if not EventBus.input_mode_changed.is_connected(_on_mode_changed):
		EventBus.input_mode_changed.connect(_on_mode_changed)

func _exit_tree() -> void:
	if EventBus.input_mode_changed.is_connected(_on_mode_changed):
		EventBus.input_mode_changed.disconnect(_on_mode_changed)

func _unhandled_input(event: InputEvent) -> void:
	if _input_consumed:
		return
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
	_input_consumed = true
	get_viewport().set_input_as_handled()
	EventBus.request_main_menu.emit()

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
