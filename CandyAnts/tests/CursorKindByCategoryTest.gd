extends Node

# Phase 3 — 커서 = 결과물 모양. cursor_kind 카테고리 파생 소스 선택 단언.
# ICON(③)=per-skill 아이콘 / DEVICE(④)=점프대 / SIGN(①)=표지판 보드 합성 / SETTLE_FORM(②)=아이콘 fallback(Phase7).

func _ready() -> void:
	var failures: Array[String] = []
	var tb := SkillToolbar.new()
	add_child(tb)

	# ICON (③) — per-skill cursor 아이콘 그대로.
	if tb._cursor_source("climber") != tb.CURSOR_ICONS["climber"]:
		failures.append("climber(ICON) cursor != per-skill cursor icon")
	if tb._cursor_source("bridge") != tb.CURSOR_ICONS["bridge"]:
		failures.append("bridge(ICON) cursor != per-skill cursor icon")

	# DEVICE (④) — 점프대 텍스처.
	if tb._cursor_source("leaf_jump") != tb.LEAF_PAD_TEXTURE:
		failures.append("leaf_jump(DEVICE) cursor != leaf pad texture")

	# SIGN (①) — 표지판 보드 합성(아이콘과 다름, 보드 폭과 동일).
	var sign_cur: Texture2D = tb._cursor_source("basher")
	if sign_cur == tb.ICONS["basher"]:
		failures.append("basher(SIGN) cursor should be a board composite, not the plain icon")
	if not (sign_cur is ImageTexture):
		failures.append("basher(SIGN) cursor not an ImageTexture composite")
	elif sign_cur.get_width() != SkillSign.SIGN_BOARD_TEXTURE.get_width():
		failures.append("basher(SIGN) composite width %d != board width %d" % [sign_cur.get_width(), SkillSign.SIGN_BOARD_TEXTURE.get_width()])
	# SIGN 합성은 1회 생성 후 캐시 — 같은 인스턴스 반환.
	if tb._cursor_source("basher") != sign_cur:
		failures.append("basher(SIGN) composite not cached (new instance each call)")

	# SETTLE_FORM (②) — 정착폼 아트는 Phase 7, 현재 per-skill 아이콘 fallback.
	if tb._cursor_source("blocker") != tb.CURSOR_ICONS["blocker"]:
		failures.append("blocker(SETTLE_FORM) cursor != icon fallback")
	if tb._cursor_source("floater") != tb.CURSOR_ICONS["floater"]:
		failures.append("floater(SETTLE_FORM) cursor != icon fallback")

	if failures.size() > 0:
		push_error("CursorKindByCategoryTest FAIL: " + str(failures))
		print("[CursorKindByCategoryTest] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[CursorKindByCategoryTest] PASS")
		get_tree().quit(0)
