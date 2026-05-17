class_name PauseBtn
extends CButton

# Phase 11 atom-like wrapper (UI_GUIDE §0.5 운영 모델 + plan v2 §5.1).
# GHOST CButton + paused polling + icon swap + action_triggered(PAUSE_TOGGLE) emit.
# atom-like wrapper로 분류 — 본 파일은 theme override grep gate 면제 (plan v2 §7.2).

const PAUSE_ICON: Texture2D = preload("res://assets/icons/ui/pause.svg")
const PLAY_ICON: Texture2D = preload("res://assets/icons/ui/play.svg")
const GameAction := preload("res://scripts/input/GameAction.gd")

var _last_paused: bool = false
var _icon_rect: TextureRect

func _ready() -> void:
	kind = ButtonKind.GHOST
	custom_minimum_size = Vector2(56, 56)
	process_mode = PROCESS_MODE_ALWAYS
	super._ready()
	_icon_rect = TextureRect.new()
	_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_icon_rect.custom_minimum_size = Vector2(24, 24)
	_icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
	_icon_rect.anchor_left = 0.5
	_icon_rect.anchor_top = 0.5
	_icon_rect.anchor_right = 0.5
	_icon_rect.anchor_bottom = 0.5
	_icon_rect.offset_left = -12
	_icon_rect.offset_top = -12
	_icon_rect.offset_right = 12
	_icon_rect.offset_bottom = 12
	add_child(_icon_rect)
	if not pressed.is_connected(_on_pressed_emit):
		pressed.connect(_on_pressed_emit)
	_refresh_icon()

func _process(_delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.paused != _last_paused:
		_last_paused = tree.paused
		_refresh_icon()

func _on_pressed_emit() -> void:
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})

func _refresh_icon() -> void:
	if _icon_rect == null:
		return
	_icon_rect.texture = PLAY_ICON if _last_paused else PAUSE_ICON
