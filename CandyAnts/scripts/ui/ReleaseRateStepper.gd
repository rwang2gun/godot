class_name ReleaseRateStepper
extends HBoxContainer

# Phase 11 atom-like wrapper (plan v2 §5.2).
# − CButton + Value Label + + CButton. ± click → action_triggered(RELEASE_RATE_UP/DOWN).
# EventBus.release_rate_changed 구독해서 Label 동기. 초기값은 StageRunner._ready의
# spawner.set_release_rate(stage_data.release_rate_initial) emit이 첫 frame에 채움.
# atom-like wrapper로 분류 — theme override gate 면제.

const GameAction := preload("res://scripts/input/GameAction.gd")

@onready var _btn_minus: CButton = $BtnMinus
@onready var _value_label: Label = $Value
@onready var _btn_plus: CButton = $BtnPlus

func _ready() -> void:
	if not _btn_minus.pressed.is_connected(_emit_down):
		_btn_minus.pressed.connect(_emit_down)
	if not _btn_plus.pressed.is_connected(_emit_up):
		_btn_plus.pressed.connect(_emit_up)
	if not EventBus.release_rate_changed.is_connected(_on_rate_changed):
		EventBus.release_rate_changed.connect(_on_rate_changed)

func _exit_tree() -> void:
	if EventBus.release_rate_changed.is_connected(_on_rate_changed):
		EventBus.release_rate_changed.disconnect(_on_rate_changed)

func _emit_down() -> void:
	EventBus.action_triggered.emit(GameAction.RELEASE_RATE_DOWN, {})

func _emit_up() -> void:
	EventBus.action_triggered.emit(GameAction.RELEASE_RATE_UP, {})

func _on_rate_changed(new_rate: int) -> void:
	_value_label.text = str(new_rate)
