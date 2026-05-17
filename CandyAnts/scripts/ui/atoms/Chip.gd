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
