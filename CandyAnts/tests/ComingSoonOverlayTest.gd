extends Node

const OverlayScene := preload("res://scenes/ui/ComingSoonOverlay.tscn")

func _ready() -> void:
	Engine.time_scale = 4.0
	# Sweep 1 (phase 13): type annotation 제거 — class_name ComingSoonOverlay cold-parse
	# 미해결 방지 + codex sweep 1 R1 P1 수용 (untyped → dynamic dispatch).
	# OverlayScene preload로 ComingSoonOverlay 인스턴스 type은 보장됨.
	var overlay = OverlayScene.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	if overlay.visible:
		return _fail("default state should be hidden")
	overlay.show_overlay()
	await get_tree().process_frame
	if not overlay.visible:
		return _fail("show() should set visible=true")
	# CloseBtn 클릭 → hide
	var close_btn: Button = overlay.get_node("CardWrapper/Card/VBox/CloseBtn")
	close_btn.pressed.emit()
	# fade_out 0.15s × time_scale=4 = 40ms wall + margin
	var elapsed := 0.0
	while overlay.visible and elapsed < 1.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if overlay.visible:
		return _fail("close button should hide overlay within 1s wall")
	# ESC → hide (재진입)
	overlay.show_overlay()
	await get_tree().process_frame
	if not overlay.visible:
		return _fail("show() #2 failed")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	get_viewport().push_input(ev)
	elapsed = 0.0
	while overlay.visible and elapsed < 1.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if overlay.visible:
		return _fail("ESC should hide overlay")
	Engine.time_scale = 1.0
	print("[ComingSoonOverlayTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	Engine.time_scale = 1.0
	print("[ComingSoonOverlayTest] FAIL ", msg)
	get_tree().quit(1)
