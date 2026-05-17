extends Node

# Phase 12 sweep 2 regression — 모든 CButton kind는 ShadowBG 유지 (sticker shadow 일관성).
# GHOST normal fill은 cream_100 (SECONDARY와 동일). transparent fill 회귀 차단.
# 회귀 근거: phase 12 dialog MenuBtn(GHOST)이 transparent normal + ShadowBG → 검은 박스 + 텍스트 invisible.

const _CBUTTON := preload("res://scenes/ui/atoms/CButton.tscn")

func _ready() -> void:
	var primary: CButton = _CBUTTON.instantiate()
	primary.kind = CButton.ButtonKind.PRIMARY
	add_child(primary)
	var secondary: CButton = _CBUTTON.instantiate()
	secondary.kind = CButton.ButtonKind.SECONDARY
	add_child(secondary)
	var ghost: CButton = _CBUTTON.instantiate()
	ghost.kind = CButton.ButtonKind.GHOST
	add_child(ghost)

	await get_tree().process_frame

	_assert_shadow_visible(primary, "PRIMARY")
	_assert_shadow_visible(secondary, "SECONDARY")
	_assert_shadow_visible(ghost, "GHOST")

	# GHOST normal fill은 cream_100 (transparent가 아닌). PRIMARY는 theme default 사용.
	_assert_ghost_normal_opaque(ghost)

	print("[CButtonGhostShadowTest] PASS")
	get_tree().quit()

func _assert_shadow_visible(btn: CButton, label: String) -> void:
	var shadow := btn.get_node_or_null("ShadowBG") as CanvasItem
	if shadow == null:
		push_error("[CButtonGhostShadowTest] FAIL %s — ShadowBG node missing" % label)
		get_tree().quit(1)
		return
	if not shadow.visible:
		push_error("[CButtonGhostShadowTest] FAIL %s — ShadowBG.visible=false expected true" % label)
		get_tree().quit(1)

func _assert_ghost_normal_opaque(btn: CButton) -> void:
	var box := btn.get_theme_stylebox("normal") as StyleBoxFlat
	if box == null:
		push_error("[CButtonGhostShadowTest] FAIL GHOST normal stylebox missing")
		get_tree().quit(1)
		return
	# Transparent fill 회귀 가드 — bg_color.a > 0.9 보장.
	if box.bg_color.a < 0.9:
		push_error("[CButtonGhostShadowTest] FAIL GHOST normal bg_color alpha=%s (expected >= 0.9, transparent fill 회귀)" % box.bg_color.a)
		get_tree().quit(1)
	# bg_color가 cream_100 근사인지 확인 (RGB 비교).
	if not box.bg_color.is_equal_approx(Tokens.CREAM_100):
		push_error("[CButtonGhostShadowTest] FAIL GHOST normal bg_color=%s (expected CREAM_100=%s)" % [box.bg_color, Tokens.CREAM_100])
		get_tree().quit(1)
