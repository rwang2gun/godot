class_name Counter
extends Control

# Phase 10 atom — UI_GUIDE §3.3.
# HUD 카운터 카드 (110×84). ColorDot + TopLabel(EN) / BigNumber / KoLabel 3-라인.
# set_value(n) 호출 시 caPop tween 발화. H-1 fix: 이전 tween을 atom-local kill guard로 정리.

const _SIZE := Vector2(110, 84)
const _RADIUS := 16
const _BORDER_WIDTH := 3
const _SHADOW_OFFSET := 4.0
const _PADDING := 8

@export var kind: Tokens.CounterKind = Tokens.CounterKind.CANDY_HP:
	set(v):
		kind = v
		if is_inside_tree():
			_apply_kind()

@export var top_label_en: String = "":
	set(v):
		top_label_en = v
		if is_inside_tree():
			_apply_text()

@export var bottom_label_ko: String = "":
	set(v):
		bottom_label_ko = v
		if is_inside_tree():
			_apply_text()

@onready var _shadow: Panel = $ShadowBG
@onready var _main: PanelContainer = $MainPanel
@onready var _color_dot: ColorRect = $MainPanel/VBox/HBox/ColorDot
@onready var _top_label: Label = $MainPanel/VBox/HBox/TopLabel
@onready var _big_number: Label = $MainPanel/VBox/BigNumber
@onready var _ko_label: Label = $MainPanel/VBox/KoLabel

var _capop_tween: Tween
# Sweep 2 (phase 13): set_value()를 tree 진입 전 호출한 caller(AtomShowcaseTest 등)는
# `_big_number` @onready 미평가 → null crash. pending 패턴으로 _ready 후 일괄 적용.
var _pending_value: int = 0
var _has_pending_value: bool = false

func _ready() -> void:
	custom_minimum_size = _SIZE
	_apply_shadow_style()
	_apply_main_style()
	_apply_kind()
	_apply_text()
	if _has_pending_value:
		_apply_value(_pending_value)
		_has_pending_value = false

# H-1 fix (atom-local kill guard) — caPop의 prior tween을 죽이고 새 tween 생성.
# pivot은 글자 변경마다 dynamic 계산 (Jua tabular 미보장 + text width 가변).
func set_value(n: int) -> void:
	if not is_node_ready():
		_pending_value = n
		_has_pending_value = true
		return
	_apply_value(n)

func _apply_value(n: int) -> void:
	_big_number.text = str(n)
	var sz: Vector2 = _big_number.get_minimum_size()
	_big_number.pivot_offset = sz * 0.5
	if _capop_tween and _capop_tween.is_valid():
		_capop_tween.kill()
	_capop_tween = Motion.caPop(_big_number)

func _apply_shadow_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.INK_900
	box.corner_radius_top_left = _RADIUS
	box.corner_radius_top_right = _RADIUS
	box.corner_radius_bottom_left = _RADIUS
	box.corner_radius_bottom_right = _RADIUS
	_shadow.add_theme_stylebox_override("panel", box)

func _apply_main_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.CREAM_100
	box.border_width_left = _BORDER_WIDTH
	box.border_width_top = _BORDER_WIDTH
	box.border_width_right = _BORDER_WIDTH
	box.border_width_bottom = _BORDER_WIDTH
	box.border_color = Tokens.INK_900
	box.corner_radius_top_left = _RADIUS
	box.corner_radius_top_right = _RADIUS
	box.corner_radius_bottom_left = _RADIUS
	box.corner_radius_bottom_right = _RADIUS
	box.content_margin_left = _PADDING
	box.content_margin_top = _PADDING - 2
	box.content_margin_right = _PADDING
	box.content_margin_bottom = _PADDING - 2
	_main.add_theme_stylebox_override("panel", box)

func _apply_kind() -> void:
	if not is_node_ready():
		return
	var col: Color = Tokens.COUNTER_COLOR[kind]
	_color_dot.color = col
	_big_number.add_theme_color_override("font_color", col)

func _apply_text() -> void:
	if not is_node_ready():
		return
	_top_label.text = top_label_en.to_upper()
	_ko_label.text = bottom_label_ko
