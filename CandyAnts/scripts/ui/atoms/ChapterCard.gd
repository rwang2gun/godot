class_name ChapterCard
extends Button

# campaign-50 — ChapterSelect 카드 아톰. StageSlotCard와 동형(섀도+패널+포커스 헤일로).
# 3 state: PLAYABLE / CLEARED / LOCKED. 챕터별 테마색 패널 + 별점 텍스트 + 잠금 배지.
# Pressed signal만 emit (라우팅은 ChapterSelect.gd 책임).

# 정수값을 ChapterSelect.ChapterState와 일치시킨다(LOCKED=0/PLAYABLE=1/CLEARED=2) — setup()에
# 그 enum 값을 그대로 전달받으므로 순서가 곧 계약.
enum CardState { LOCKED, PLAYABLE, CLEARED }

const ICON_LOCK := preload("res://assets/icons/ui/lock.svg")

var chapter_num: int = 1
var _state: int = CardState.PLAYABLE
var _stars: int = 0
var _star_cap: int = 0

@onready var _shadow: Panel = $ShadowBG
@onready var _main: PanelContainer = $MainPanel
@onready var _num_label: Label = $MainPanel/VBox/NumLabel
@onready var _title_label: Label = $MainPanel/VBox/TitleLabel
@onready var _star_label: Label = $MainPanel/VBox/StarLabel
@onready var _badge: TextureRect = $MainPanel/StateBadge
@onready var _focus_halo: Panel = $FocusHalo

func _ready() -> void:
	custom_minimum_size = Vector2(240, 170)
	_apply_shadow_style()
	_apply_focus_halo_style()
	_render()
	focus_entered.connect(func(): _focus_halo.visible = true)
	focus_exited.connect(func(): _focus_halo.visible = false)
	_focus_halo.visible = has_focus()

# ChapterSelect._populate가 add_child 후 호출. stars/cap은 Campaign 파생값.
func setup(num: int, state: int, stars: int, star_cap: int) -> void:
	chapter_num = num
	_state = state
	_stars = stars
	_star_cap = star_cap
	if is_inside_tree():
		_render()

func _render() -> void:
	if _main == null:
		return
	_num_label.text = "챕터 %d" % chapter_num
	_title_label.text = Campaign.chapter_title(chapter_num)
	var locked: bool = _state == CardState.LOCKED
	_star_label.visible = not locked
	_star_label.text = "★ %d / %d" % [_stars, _star_cap]
	# 만점(보라별) / 부분·0 색 분기 — StageSlotCard의 GRAPE_700 퍼펙트 컨벤션과 동일 어휘.
	var perfect: bool = _star_cap > 0 and _stars >= _star_cap
	_star_label.add_theme_color_override("font_color", Tokens.GRAPE_700 if perfect else Tokens.INK_700)
	_badge.visible = locked
	if locked:
		_badge.texture = ICON_LOCK
	_apply_panel_style(locked)
	modulate.a = 0.6 if locked else 1.0

# 챕터(1-based) → 테마색. 잠금이면 회색 폴백. (const 배열 대신 런타임 match — autoload 무관 안전.)
func _chapter_color(num: int) -> Color:
	match num:
		1: return Tokens.MINT_300    # 기초
		2: return Tokens.LEMON_300   # 건설
		3: return Tokens.BERRY_300   # 파괴
		4: return Tokens.GRAPE_300   # 장치·숙련
		5: return Tokens.PEACH_300   # 종합
		_: return Tokens.CREAM_100

func _apply_panel_style(locked: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Tokens.CREAM_300 if locked else _chapter_color(chapter_num)
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = Tokens.INK_900
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	box.content_margin_left = 14
	box.content_margin_top = 12
	box.content_margin_right = 14
	box.content_margin_bottom = 12
	_main.add_theme_stylebox_override("panel", box)

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

func _apply_focus_halo_style() -> void:
	if _focus_halo == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
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
