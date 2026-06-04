class_name StageSlotCard
extends Button

# Phase 13 atom — UI_GUIDE §3.6 + plan §3.6.3.
# 200×140 카드. 4 state: PLAYABLE / CLEARED / LOCKED / COMING_SOON.
# Pressed signal만 emit (외부 라우팅은 StageSelect.gd 책임).

enum SlotState { PLAYABLE, CLEARED, LOCKED, COMING_SOON }

const ICON_LOCK := preload("res://assets/icons/ui/lock.svg")

@export var stage_id: int = 1:
	set(value):
		stage_id = value
		if is_inside_tree():
			_apply_text()

# menu_layout.tres slot의 display_name. 비어 있으면 "스테이지 N" 폴백.
@export var display_name: String = "":
	set(value):
		display_name = value
		if is_inside_tree():
			_apply_text()

@export var slot_state: SlotState = SlotState.PLAYABLE:
	set(value):
		slot_state = value
		if is_inside_tree():
			_apply_state()

var _progress: Dictionary = {}

@onready var _shadow: Panel = $ShadowBG
@onready var _main: PanelContainer = $MainPanel
@onready var _stage_label: Label = $MainPanel/VBox/StageLabel
@onready var _stars: HBoxContainer = $MainPanel/VBox/StarRow
@onready var _star_polys: Array = [$MainPanel/VBox/StarRow/Star1, $MainPanel/VBox/StarRow/Star2, $MainPanel/VBox/StarRow/Star3]
@onready var _score_label: Label = $MainPanel/VBox/ScoreLabel
@onready var _state_badge: TextureRect = $MainPanel/StateBadge
@onready var _coming_soon_label: Label = $MainPanel/VBox/ComingSoonLabel
@onready var _focus_halo: Panel = $FocusHalo

func _ready() -> void:
	custom_minimum_size = Vector2(200, 140)
	_apply_shadow_style()
	_apply_focus_halo_style()
	_apply_state()
	_apply_text()
	focus_entered.connect(func(): _focus_halo.visible = true)
	focus_exited.connect(func(): _focus_halo.visible = false)
	_focus_halo.visible = has_focus()

func set_state(s: SlotState) -> void:
	slot_state = s

func set_progress(entry: Dictionary) -> void:
	_progress = entry.duplicate()
	if is_inside_tree():
		_apply_state()
		_apply_text()

func _apply_text() -> void:
	if _stage_label == null:
		return
	_stage_label.text = display_name if not display_name.is_empty() else Strings.t("stage_card.title", [stage_id])
	var stars: int = int(_progress.get("stars", 0))
	for i in _star_polys.size():
		var poly: Polygon2D = _star_polys[i].get_node("Poly") as Polygon2D
		if poly == null:
			continue
		poly.color = Tokens.LEMON_500 if i < stars else Tokens.CREAM_200
	if _progress.get("cleared", false):
		var saved: int = int(_progress.get("best_saved", 0))
		_score_label.text = Strings.t("stage_card.best", [saved])
	else:
		_score_label.text = ""

func _apply_state() -> void:
	if _main == null:
		return
	var bg: Color = Tokens.CREAM_100
	var disabled_visual: bool = false
	var lock_visible: bool = false
	var coming_soon_visible: bool = false
	var stars_visible: bool = true
	match slot_state:
		SlotState.PLAYABLE:
			bg = Tokens.CREAM_100
		SlotState.CLEARED:
			bg = Tokens.CREAM_100
		SlotState.LOCKED:
			bg = Tokens.CREAM_300
			disabled_visual = true
			lock_visible = true
			stars_visible = false
		SlotState.COMING_SOON:
			bg = Tokens.CREAM_300
			disabled_visual = true
			coming_soon_visible = true
			stars_visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = Tokens.INK_900
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	box.content_margin_left = 12
	box.content_margin_top = 10
	box.content_margin_right = 12
	box.content_margin_bottom = 10
	_main.add_theme_stylebox_override("panel", box)
	if _state_badge != null:
		_state_badge.visible = lock_visible
		if lock_visible:
			_state_badge.texture = ICON_LOCK
	if _coming_soon_label != null:
		_coming_soon_label.visible = coming_soon_visible
	if _stars != null:
		_stars.visible = stars_visible
	modulate.a = 0.6 if disabled_visual else 1.0

func _apply_shadow_style() -> void:
	if _shadow == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.INK_900
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	_shadow.add_theme_stylebox_override("panel", box)

# Self-Review R1 MED-S2: focus halo는 mint_500 3px outline + transparent fill (UI_GUIDE §1.7 focus halo spec).
func _apply_focus_halo_style() -> void:
	if _focus_halo == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)   # transparent fill
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = Tokens.MINT_500
	box.corner_radius_top_left = 20
	box.corner_radius_top_right = 20
	box.corner_radius_bottom_left = 20
	box.corner_radius_bottom_right = 20
	_focus_halo.add_theme_stylebox_override("panel", box)
