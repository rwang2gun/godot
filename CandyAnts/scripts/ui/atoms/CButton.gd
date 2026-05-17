class_name CButton
extends Button

# Phase 10 atom — UI_GUIDE §3.1.
# PRIMARY는 Theme의 Button StyleBoxFlat(peach_500/peach_700) 그대로 사용.
# SECONDARY/GHOST는 atom-local StyleBoxFlat override.
# Sticker shadow는 자식 ShadowBG Panel (show_behind_parent=true)이 처리.

enum ButtonKind { PRIMARY, SECONDARY, GHOST }

@export var kind: ButtonKind = ButtonKind.PRIMARY:
	set(value):
		kind = value
		if is_inside_tree():
			_apply_kind()

var _boop_tween: Tween
var _boop_base: Vector2     # 첫 boop 시점의 안정 위치 — 연속 click 중 재사용 (R2-M1 drift 차단)

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_apply_kind()

# R1-M3 + R2-M1 fix: kill 후 stable base로 snap → Motion.boop이 그 base를 캡처 → drift 0.
func _on_pressed() -> void:
	if _boop_tween and _boop_tween.is_valid():
		_boop_tween.kill()
		position = _boop_base
	else:
		_boop_base = position
	_boop_tween = Motion.boop(self)
	_boop_tween.finished.connect(_on_boop_finished, CONNECT_ONE_SHOT)

func _on_boop_finished() -> void:
	_boop_tween = null
	# _boop_base는 다음 호출에서 if _boop_tween==null 경로로 재캡처됨.

func _apply_kind() -> void:
	# Phase 12 sweep 2: ShadowBG는 모든 kind에서 유지 (sticker shadow 일관성).
	# GHOST normal fill을 transparent → cream_100으로 정정.
	# 근거: GHOST normal이 transparent면 ShadowBG가 본체 위로 노출되어 ink_900 텍스트가
	# 검은 그림자 위에 invisible. cream fill로 본체가 ShadowBG를 가린다.
	# spec drift: GHOST가 SECONDARY와 fill 동일해짐 (variant 차이 미미). UI_GUIDE §3.1 sync.
	match kind:
		ButtonKind.PRIMARY:
			_clear_style_overrides()
		ButtonKind.SECONDARY:
			_apply_style_set(Tokens.CREAM_100, Tokens.CREAM_100, Tokens.CREAM_200, Tokens.CREAM_200)
		ButtonKind.GHOST:
			_apply_style_set(Tokens.CREAM_100, Tokens.CREAM_100, Tokens.CREAM_200, Tokens.CREAM_200)

func _clear_style_overrides() -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		if has_theme_stylebox_override(state):
			remove_theme_stylebox_override(state)

func _apply_style_set(c_normal: Color, c_hover: Color, c_pressed: Color, c_disabled: Color) -> void:
	add_theme_stylebox_override("normal", _make_box(c_normal))
	add_theme_stylebox_override("hover", _make_box(c_hover))
	add_theme_stylebox_override("pressed", _make_box(c_pressed))
	add_theme_stylebox_override("disabled", _make_box(c_disabled))

func _make_box(bg: Color) -> StyleBoxFlat:
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
	box.content_margin_left = 22
	box.content_margin_top = 10
	box.content_margin_right = 22
	box.content_margin_bottom = 10
	return box
