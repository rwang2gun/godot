extends Node

# Phase 13 — plan §3.6.1 + Δ11.
# 2026-06-03 인트로 영상 추가로 입력 2-step化:
#   인트로 중 첫 입력 → 스킵(로고+끝프레임, emit 0) / resting state 추가 입력 → menu emit 1.

const TitleSceneScene := preload("res://scenes/ui/TitleScene.tscn")

var _emit_count: int = 0

func _ready() -> void:
	EventBus.request_main_menu.connect(func(): _emit_count += 1)
	var title: Control = TitleSceneScene.instantiate()
	add_child(title)
	await get_tree().process_frame
	var logo: Control = title.get_node("LogoPanel")
	# Mouse motion: emit 0 (인트로 스킵도 안 됨 — motion은 무시)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50, 50)
	get_viewport().push_input(motion)
	await get_tree().process_frame
	if _emit_count != 0:
		return _fail("mouse motion should not emit, got %d" % _emit_count)
	# ESC: emit 0 (Δ11) — 스킵도 안 됨
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc)
	await get_tree().process_frame
	if _emit_count != 0:
		return _fail("ESC should not emit, got %d" % _emit_count)
	# 첫 키 입력(space): 인트로 스킵 → 로고 표시, emit 0 유지
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	get_viewport().push_input(space)
	await get_tree().process_frame
	if _emit_count != 0:
		return _fail("first key should skip intro, not emit; got %d" % _emit_count)
	if not is_equal_approx(logo.modulate.a, 1.0):
		return _fail("logo should be visible after skip, alpha=%f" % logo.modulate.a)
	# 두 번째 키 입력(enter): resting state → 메뉴 emit 1
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	get_viewport().push_input(enter)
	await get_tree().process_frame
	if _emit_count != 1:
		return _fail("second key expected menu emit 1, got %d" % _emit_count)
	# 세 번째 키 입력: emit 1 유지 (double-fire 차단)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	await get_tree().process_frame
	if _emit_count != 1:
		return _fail("third press leaked emit, count=%d" % _emit_count)
	print("[TitleSceneInputTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[TitleSceneInputTest] FAIL ", msg)
	get_tree().quit(1)
