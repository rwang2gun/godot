extends Node

# Phase 13 — plan §3.6.1 + Δ11.

const TitleSceneScene := preload("res://scenes/ui/TitleScene.tscn")

var _emit_count: int = 0

func _ready() -> void:
	EventBus.request_main_menu.connect(func(): _emit_count += 1)
	var title: Control = TitleSceneScene.instantiate()
	add_child(title)
	await get_tree().process_frame
	# Mouse motion: emit 0
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50, 50)
	get_viewport().push_input(motion)
	await get_tree().process_frame
	if _emit_count != 0:
		return _fail("mouse motion should not emit, got %d" % _emit_count)
	# ESC: emit 0 (Δ11)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc)
	await get_tree().process_frame
	if _emit_count != 0:
		return _fail("ESC should not emit, got %d" % _emit_count)
	# Key press (space): emit 1
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	get_viewport().push_input(space)
	await get_tree().process_frame
	if _emit_count != 1:
		return _fail("space press expected emit 1, got %d" % _emit_count)
	# 두 번째 키 입력: emit 1 유지 (double-fire 차단)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	get_viewport().push_input(enter)
	await get_tree().process_frame
	if _emit_count != 1:
		return _fail("second press leaked emit, count=%d" % _emit_count)
	print("[TitleSceneInputTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[TitleSceneInputTest] FAIL ", msg)
	get_tree().quit(1)
