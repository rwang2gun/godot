extends Node

# Phase 12 sweep regression — GHOST kind은 ShadowBG hide.
# 근거: GHOST normal fill이 Color(0,0,0,0) transparent.
# ShadowBG가 4px shifted ink_900 fill로 노출되면 ink_900 텍스트가
# 검은 ShadowBG 위에 invisible → ghost variant 자체가 망가짐.

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

	_assert_visible(primary, true, "PRIMARY ShadowBG.visible")
	_assert_visible(secondary, true, "SECONDARY ShadowBG.visible")
	_assert_visible(ghost, false, "GHOST ShadowBG.visible=false")

	# Kind 토글 시 ShadowBG visibility 즉시 갱신 검증.
	ghost.kind = CButton.ButtonKind.PRIMARY
	await get_tree().process_frame
	_assert_visible(ghost, true, "GHOST→PRIMARY toggle ShadowBG.visible")

	ghost.kind = CButton.ButtonKind.GHOST
	await get_tree().process_frame
	_assert_visible(ghost, false, "PRIMARY→GHOST toggle ShadowBG.visible=false")

	print("[CButtonGhostShadowTest] PASS")
	get_tree().quit()

func _assert_visible(btn: CButton, expected: bool, msg: String) -> void:
	var shadow := btn.get_node_or_null("ShadowBG") as CanvasItem
	if shadow == null:
		push_error("[CButtonGhostShadowTest] FAIL %s — ShadowBG node missing" % msg)
		get_tree().quit(1)
	if shadow.visible != expected:
		push_error("[CButtonGhostShadowTest] FAIL %s — expected=%s actual=%s" % [msg, expected, shadow.visible])
		get_tree().quit(1)
