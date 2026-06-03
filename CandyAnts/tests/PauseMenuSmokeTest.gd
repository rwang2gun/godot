extends Node

# PauseMenu 스모크 테스트.
# 1) Main.tscn이 PauseMenu 포함해 파싱/인스턴스 OK
# 2) STAGE 진입 후 PAUSE_TOGGLE 발화 → PauseMenu.visible == true
# 3) 한 번 더 PAUSE_TOGGLE → visible == false
# 4) 메인 메뉴로 버튼(request_main_menu) → 자동 hide

const GameAction := preload("res://scripts/input/GameAction.gd")

var _main: Node = null
var _scene_flow: Node = null
var _pause_menu: Control = null
var _failed: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	_main = $Main
	_scene_flow = _main.get_node("SceneFlow")
	_pause_menu = _main.get_node("GlobalUI/PauseMenu") as Control
	if _scene_flow == null or _pause_menu == null:
		_fail("missing Main subnodes (SceneFlow=%s, PauseMenu=%s)" % [_scene_flow, _pause_menu])
		return
	await get_tree().process_frame
	# STAGE 진입
	if _scene_flow.current_screen != _scene_flow.ScreenState.STAGE:
		_scene_flow.load_stage(1)
		await get_tree().process_frame
		await get_tree().process_frame
	if _pause_menu.visible:
		_fail("PauseMenu visible at startup")
		return
	# 1) PAUSE_TOGGLE → show
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})
	await get_tree().process_frame
	if not _pause_menu.visible:
		_fail("PauseMenu not visible after first PAUSE_TOGGLE")
		return
	if not get_tree().paused:
		_fail("tree.paused not true after first PAUSE_TOGGLE")
		return
	# 2) PAUSE_TOGGLE → hide
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})
	await get_tree().process_frame
	if _pause_menu.visible:
		_fail("PauseMenu still visible after second PAUSE_TOGGLE")
		return
	if get_tree().paused:
		_fail("tree.paused not false after second PAUSE_TOGGLE")
		return
	# 3) show 다시 → 메인 메뉴로 버튼(request_main_menu) → hide + paused 해제
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})
	await get_tree().process_frame
	if not _pause_menu.visible:
		_fail("PauseMenu not visible after third PAUSE_TOGGLE")
		return
	_pause_menu._on_title_pressed()
	await get_tree().process_frame
	if _pause_menu.visible:
		_fail("PauseMenu still visible after Title button")
		return
	if get_tree().paused:
		_fail("tree.paused not false after Title button")
		return
	print("[PauseMenuSmokeTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[PauseMenuSmokeTest] FAIL ", msg)
	get_tree().quit(1)
