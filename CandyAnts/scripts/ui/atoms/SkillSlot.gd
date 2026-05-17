class_name SkillSlot
extends Button

# Phase 10 atom — UI_GUIDE §3.4.
# 88×88. 8 state matrix (armed / selected / hover / pressed / empty / disabled).
# Button을 transparent stylebox로 비워두고 MainBG/ShadowBG/Icon/Pill/Badge/Label/FocusHalo로 시각 구성.
# focus halo는 패드 모드 검증 (mouse 모드에서는 has_focus()가 거의 안 잡힘).

const _SIZE := Vector2(88, 88)
const _RADIUS := 16
const _BORDER_WIDTH := 3
const _SHADOW_OFFSET_NORMAL := Vector2(4, 4)
const _SHADOW_OFFSET_PRESSED := Vector2(2, 2)
const _HOVER_TRANSLATE_Y := -2.0
const _FADED_ALPHA := 0.55
const _FOCUS_INSET := 4.0

@export var skill_id: StringName = &"":
	set(v):
		skill_id = v

@export var hotkey: String = "":
	set(v):
		hotkey = v
		if is_inside_tree():
			_apply_hotkey()

@export var ko_label: String = "":
	set(v):
		ko_label = v
		if is_inside_tree():
			_apply_ko_label()

@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		if is_inside_tree():
			_apply_icon()

@onready var _shadow: Panel = $ShadowBG
@onready var _main_bg: Panel = $MainBG
@onready var _icon_rect: TextureRect = $MainBG/Icon
@onready var _hotkey_pill: PanelContainer = $MainBG/HotkeyPill
@onready var _hotkey_label: Label = $MainBG/HotkeyPill/Label
@onready var _count_pill: PanelContainer = $MainBG/CountBadge
@onready var _count_label: Label = $MainBG/CountBadge/Label
@onready var _ko_label_node: Label = $MainBG/KoLabel
@onready var _focus_halo: Panel = $FocusHalo

var _count: int = 1
var _selected: bool = false
var _is_pressed: bool = false
var _boop_tween: Tween
var _boop_base: Vector2     # MainBG 첫 boop 시점의 안정 위치 (R2-M1 drift 차단)

# StyleBoxFlat 캐싱 (L-1 fix) — _update_visual()이 매번 new를 호출하지 않도록 2개 box를 _ready에서 1회 생성.
var _box_armed: StyleBoxFlat
var _box_selected: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = _SIZE
	focus_mode = Control.FOCUS_ALL
	_clear_button_styles()
	_apply_shadow_style()
	_apply_focus_halo_style()
	_apply_hotkey_pill_style()
	_apply_count_badge_style()
	_box_armed = _make_main_box(Tokens.CREAM_100)
	_box_selected = _make_main_box(Tokens.PEACH_300)
	_focus_halo.visible = false
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)
	_apply_hotkey()
	_apply_ko_label()
	_apply_icon()
	_update_visual()

func set_count(n: int) -> void:
	_count = n
	if is_inside_tree():
		_apply_count()
		_update_visual()

func set_selected(b: bool) -> void:
	_selected = b
	if is_inside_tree():
		_update_visual()

func _clear_button_styles() -> void:
	# Button의 Theme stylebox를 transparent로 override — MainBG/ShadowBG가 시각 담당.
	var transparent := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, transparent)

func _apply_shadow_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.INK_900
	box.corner_radius_top_left = _RADIUS
	box.corner_radius_top_right = _RADIUS
	box.corner_radius_bottom_left = _RADIUS
	box.corner_radius_bottom_right = _RADIUS
	_shadow.add_theme_stylebox_override("panel", box)
	_shadow.position = _SHADOW_OFFSET_NORMAL

func _apply_focus_halo_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = Tokens.MINT_500
	var r := _RADIUS + int(_FOCUS_INSET)
	box.corner_radius_top_left = r
	box.corner_radius_top_right = r
	box.corner_radius_bottom_left = r
	box.corner_radius_bottom_right = r
	_focus_halo.add_theme_stylebox_override("panel", box)

# UI_GUIDE §3.4: HotkeyPill = top-left, 10px JetBrains Mono (placeholder Jua), white α0.7 pill.
func _apply_hotkey_pill_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.7)
	box.corner_radius_top_left = 999
	box.corner_radius_top_right = 999
	box.corner_radius_bottom_left = 999
	box.corner_radius_bottom_right = 999
	box.content_margin_left = 4
	box.content_margin_top = 1
	box.content_margin_right = 4
	box.content_margin_bottom = 1
	_hotkey_pill.add_theme_stylebox_override("panel", box)
	_hotkey_label.add_theme_color_override("font_color", Tokens.INK_900)

# UI_GUIDE §3.4: CountBadge = top-right, 13px Jua, ink fill, white text, pill, 2px cream border.
func _apply_count_badge_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.INK_900
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Tokens.CREAM_100
	box.corner_radius_top_left = 999
	box.corner_radius_top_right = 999
	box.corner_radius_bottom_left = 999
	box.corner_radius_bottom_right = 999
	box.content_margin_left = 6
	box.content_margin_top = 1
	box.content_margin_right = 6
	box.content_margin_bottom = 1
	_count_pill.add_theme_stylebox_override("panel", box)
	_count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _make_main_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = _BORDER_WIDTH
	box.border_width_top = _BORDER_WIDTH
	box.border_width_right = _BORDER_WIDTH
	box.border_width_bottom = _BORDER_WIDTH
	box.border_color = Tokens.INK_900
	box.corner_radius_top_left = _RADIUS
	box.corner_radius_top_right = _RADIUS
	box.corner_radius_bottom_left = _RADIUS
	box.corner_radius_bottom_right = _RADIUS
	return box

func _update_visual() -> void:
	if not is_node_ready():
		return
	var is_empty := _count <= 0
	var faded := is_empty or disabled
	# UI_GUIDE §3.4 state table: selected OR pressed → peach_300, else cream_100.
	# pressed-without-selected (transient button-down) 도 peach_300 (R1-M2 fix).
	var box: StyleBoxFlat = _box_selected if (_selected or _is_pressed) else _box_armed
	_main_bg.add_theme_stylebox_override("panel", box)
	_main_bg.self_modulate.a = _FADED_ALPHA if faded else 1.0
	_shadow.self_modulate.a = _FADED_ALPHA if faded else 1.0

func _apply_hotkey() -> void:
	if not is_node_ready():
		return
	_hotkey_label.text = hotkey
	_hotkey_pill.visible = hotkey != ""

func _apply_ko_label() -> void:
	if not is_node_ready():
		return
	_ko_label_node.text = ko_label

func _apply_icon() -> void:
	if not is_node_ready():
		return
	_icon_rect.texture = icon_texture

func _apply_count() -> void:
	if not is_node_ready():
		return
	_count_label.text = str(_count)
	_count_pill.visible = _count > 0

# --- 인터랙션 핸들러 ---

func _on_mouse_entered() -> void:
	if disabled or _count <= 0:
		return
	_main_bg.position.y = _HOVER_TRANSLATE_Y

func _on_mouse_exited() -> void:
	_main_bg.position.y = 0.0

func _on_button_down() -> void:
	if disabled or _count <= 0:
		return
	_is_pressed = true
	_shadow.position = _SHADOW_OFFSET_PRESSED
	# R1-M3 + R2-M1 fix: kill 후 stable base로 snap 후 boop 재생성 → drift 0.
	if _boop_tween and _boop_tween.is_valid():
		_boop_tween.kill()
		_main_bg.position = _boop_base
	else:
		_boop_base = _main_bg.position
	_boop_tween = Motion.boop(_main_bg)
	_boop_tween.finished.connect(_on_boop_finished, CONNECT_ONE_SHOT)
	_update_visual()

func _on_button_up() -> void:
	_is_pressed = false
	_shadow.position = _SHADOW_OFFSET_NORMAL
	_update_visual()

func _on_boop_finished() -> void:
	_boop_tween = null

func _on_focus_entered() -> void:
	_focus_halo.visible = true

func _on_focus_exited() -> void:
	_focus_halo.visible = false
