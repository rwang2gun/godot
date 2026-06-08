extends Node

# PauseMenu 회귀 테스트 — request_play_stage(stage_id) 시그널 연결 인자수 일치 검증.
#
# 버그: PauseMenu가 1-인자 시그널 request_play_stage를 0-인자 _force_hide에 직접
# connect 하면, 스테이지 진입 시 "Method expected 0 argument(s), but called with 1"
# 런타임 에러가 나고 _force_hide가 호출되지 않아 메뉴가 닫히지 않는다.
# 수정 후에는 request_play_stage(1) 발화 시 메뉴가 정상적으로 hide 되어야 한다.

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
	# STAGE 진입 후 일시정지 메뉴 표시.
	if _scene_flow.current_screen != _scene_flow.ScreenState.STAGE:
		_scene_flow.load_stage(1)
		await get_tree().process_frame
		await get_tree().process_frame
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})
	await get_tree().process_frame
	if not _pause_menu.visible:
		_fail("PauseMenu not visible after PAUSE_TOGGLE (precondition)")
		return
	# request_play_stage(stage_id) 발화 → 메뉴 강제 hide 되어야 함.
	# 버그 상태에서는 인자수 불일치 에러로 _force_hide 미호출 → visible 유지 → FAIL.
	EventBus.request_play_stage.emit(1)
	await get_tree().process_frame
	if _pause_menu.visible:
		_fail("PauseMenu still visible after request_play_stage(1) — 1-arg signal not hiding menu")
		return
	print("[test_PauseMenu] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[test_PauseMenu] FAIL ", msg)
	get_tree().quit(1)
