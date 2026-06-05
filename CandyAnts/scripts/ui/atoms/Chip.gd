class_name Chip
extends Control

# Phase 10 atom — UI_GUIDE §3.2.
# Pill-shaped 정보 태그. label + value 2-텍스트 슬롯, tint별 bg.
# Sticker shadow: sm (2,2 offset). 자식 ShadowBG가 처리.

const _RADIUS_PILL := 999
const _BORDER_WIDTH := 2
const _PADDING_H := 12
const _PADDING_V := 6
const _SHADOW_OFFSET := 2.0

@export var label: String = "":
	set(value):
		label = value
		if is_inside_tree():
			_apply_text()

@export var value: String = "":
	set(v):
		value = v
		if is_inside_tree():
			_apply_text()

@export var tint: Tokens.TintKind = Tokens.TintKind.PEACH:
	set(v):
		tint = v
		if is_inside_tree():
			_apply_tint()

@onready var _shadow: Panel = $ShadowBG
@onready var _main: PanelContainer = $MainPanel
@onready var _label_text: Label = $MainPanel/HBox/LabelText
@onready var _value_text: Label = $MainPanel/HBox/ValueText

func _ready() -> void:
	_apply_shadow_style()
	_apply_tint()
	_apply_text()

func set_label_value(p_label: String, p_value: String) -> void:
	label = p_label
	value = p_value

func _apply_shadow_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.INK_900
	box.corner_radius_top_left = _RADIUS_PILL
	box.corner_radius_top_right = _RADIUS_PILL
	box.corner_radius_bottom_left = _RADIUS_PILL
	box.corner_radius_bottom_right = _RADIUS_PILL
	_shadow.add_theme_stylebox_override("panel", box)

func _apply_tint() -> void:
	if not is_node_ready():
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.TINT_BG[tint]
	box.border_width_left = _BORDER_WIDTH
	box.border_width_top = _BORDER_WIDTH
	box.border_width_right = _BORDER_WIDTH
	box.border_width_bottom = _BORDER_WIDTH
	box.border_color = Tokens.TINT_BORDER[tint]
	box.corner_radius_top_left = _RADIUS_PILL
	box.corner_radius_top_right = _RADIUS_PILL
	box.corner_radius_bottom_left = _RADIUS_PILL
	box.corner_radius_bottom_right = _RADIUS_PILL
	box.content_margin_left = _PADDING_H
	box.content_margin_top = _PADDING_V
	box.content_margin_right = _PADDING_H
	box.content_margin_bottom = _PADDING_V
	_main.add_theme_stylebox_override("panel", box)

func _apply_text() -> void:
	if not is_node_ready():
		return
	_label_text.text = label
	_value_text.text = value
	_fit_to_content()

# 칩 Control을 내용(알약 배경 = MainPanel)의 최소 크기에 맞춰 키운다. 루트 Control은 기본적으로
# 자식 min을 반영하지 않아, 폰트를 키우면 MainPanel만 커져 알약이 Control 밖으로 흘러나오고(인접 칩
# 겹침) 세로로도 이웃 행을 침범한다. 내용 크기를 Control의 custom_minimum_size로 끌어와 컨테이너가
# 올바른 공간을 예약하게 한다. (기본 하한 80x28은 유지.)
func _fit_to_content() -> void:
	var content: Vector2 = _main.get_combined_minimum_size()
	custom_minimum_size = Vector2(maxf(content.x, 80.0), maxf(content.y, 28.0))
