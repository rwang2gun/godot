class_name PauseMenu
extends Control

# 일시정지 메뉴 — STAGE 화면에서 PAUSE_TOGGLE 발생 시 표시.
# 외부 API: 없음 (EventBus + action_triggered만 구독). StageDialog와 동일하게 GlobalUI 캔버스
# 레이어에 상주하고 process_mode=ALWAYS로 paused 중에도 동작.
#
# 동작:
# - PAUSE_TOGGLE 액션을 받으면 _menu_shown 토글 (단, STAGE 화면 + StageDialog 비표시일 때만).
# - 계속하기: PAUSE_TOGGLE 재발화 → StepFrame이 tree.paused=false, 본 메뉴는 토글로 hide.
# - 다시하기: tree.paused 해제 + request_replay 발화. SceneFlow가 stage 재로드.
# - 메인 메뉴로: tree.paused 해제 + request_main_menu 발화. SceneFlow가 메인 메뉴로 전환.
# - 화면 전환/스테이지 결과 시 자동 hide (request_*/stage_cleared/failed).
#
# StepFrame stepping window 중에는 InputRouter._pause_actions_blocked가 true라서
# action_triggered가 emit되지 않으므로 본 핸들러도 호출되지 않음 (자연 가드).

const GameAction := preload("res://scripts/input/GameAction.gd")

@export var scene_flow_path: NodePath
@export var stage_dialog_path: NodePath

@onready var _backdrop: ColorRect = $Backdrop
@onready var _continue_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/Buttons/ContinueBtn
@onready var _restart_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/Buttons/RestartBtn
@onready var _title_btn: CButton = $CardWrapper/Card/Main/Margin/VBox/Buttons/TitleBtn

var _scene_flow: Node = null
var _stage_dialog: Node = null
var _menu_shown: bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false

	if not scene_flow_path.is_empty():
		_scene_flow = get_node_or_null(scene_flow_path)
	if not stage_dialog_path.is_empty():
		_stage_dialog = get_node_or_null(stage_dialog_path)

	_continue_btn.pressed.connect(_on_continue_pressed)
	_restart_btn.pressed.connect(_on_restart_pressed)
	_title_btn.pressed.connect(_on_title_pressed)

	EventBus.action_triggered.connect(_on_action)
	# 화면 전환/스테이지 결과 시 메뉴를 강제로 닫는다. user가 메뉴 열고 그대로 화면이
	# 바뀌면 새 화면 위에 메뉴가 떠 있는 잔존을 차단.
	EventBus.stage_cleared.connect(_on_stage_end)
	EventBus.stage_failed.connect(_on_stage_end)
	EventBus.request_replay.connect(_force_hide)
	EventBus.request_main_menu.connect(_force_hide)
	EventBus.request_stage_select.connect(_force_hide)
	EventBus.request_play_stage.connect(_force_hide)
	EventBus.request_title.connect(_force_hide)
	EventBus.request_menu.connect(_force_hide)

func _on_action(name: StringName, _payload: Dictionary) -> void:
	if name != GameAction.PAUSE_TOGGLE:
		return
	# STAGE 화면이 아니면 일시정지 메뉴 표시 안 함.
	if not _is_on_stage():
		# 메뉴가 떠 있는 채 화면이 바뀐 edge case 보호.
		if _menu_shown:
			_force_hide()
		return
	# 스테이지 결과 dialog가 이미 떠 있으면 일시정지 메뉴를 추가 표시하지 않는다.
	if _stage_dialog != null and _stage_dialog.visible:
		if _menu_shown:
			_force_hide()
		return
	_menu_shown = not _menu_shown
	visible = _menu_shown

func _on_continue_pressed() -> void:
	# PAUSE_TOGGLE 재발화 → StepFrame이 tree.paused=false 처리 + 본 핸들러가 _menu_shown
	# 토글로 hide. tree.paused는 직접 건드리지 않는다(단일 소비자 StepFrame 일관성 유지).
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})

func _on_restart_pressed() -> void:
	_unpause_tree()
	_force_hide()
	EventBus.request_replay.emit()

func _on_title_pressed() -> void:
	# "메인 메뉴로 돌아가기" — 타이틀이 아니라 메인 메뉴로 진입.
	_unpause_tree()
	_force_hide()
	EventBus.request_main_menu.emit()

func _unpause_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.paused:
		tree.paused = false

func _force_hide() -> void:
	_menu_shown = false
	visible = false

func _on_stage_end(_result: Dictionary) -> void:
	_force_hide()

func _is_on_stage() -> bool:
	if _scene_flow == null:
		# scene_flow_path 미설정 시(헤드리스 테스트 등) 가드 없이 통과.
		return true
	if not "current_screen" in _scene_flow:
		return true
	return _scene_flow.current_screen == SceneFlow.ScreenState.STAGE

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_continue_pressed()
