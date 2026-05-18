extends Node

const LogoScene := preload("res://scenes/ui/atoms/LogoPanel.tscn")

func _ready() -> void:
	var logo: LogoPanel = LogoScene.instantiate()
	logo.bob_enabled = true
	add_child(logo)
	await get_tree().process_frame
	var t: Tween = logo.get_bob_tween()
	if t == null:
		return _fail("bob tween is null")
	if not t.is_valid():
		return _fail("bob tween invalid")
	# loops_left == -1 for infinite loop (Godot Tween.set_loops without arg)
	# 단, Godot 4의 Tween은 loops_left 직접 노출 X. 대신 is_running으로 활성 확인.
	if not t.is_running():
		return _fail("bob tween not running")
	# bob_enabled=false 인스턴스는 tween이 없음
	var logo2: LogoPanel = LogoScene.instantiate()
	logo2.bob_enabled = false
	add_child(logo2)
	await get_tree().process_frame
	if logo2.get_bob_tween() != null:
		return _fail("bob_enabled=false should not create tween")
	print("[LogoPanelBobTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[LogoPanelBobTest] FAIL ", msg)
	get_tree().quit(1)
