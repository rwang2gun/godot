class_name SceneFlow extends Node

# Phase 6 + 12 + 13. plan v2 §3.5 SoT.
# Screen state machine: TITLE / MAIN_MENU / STAGE_SELECT / STAGE.
# 모든 screen 전이는 _swap_screen / load_stage 경유 + _unload_current_screen
# 이 remove_child + queue_free 일괄 → stale emit 0 (plan Δ9 / codex Round 1 HIGH-1).

const GameAction := preload("res://scripts/input/GameAction.gd")

enum ScreenState { TITLE, MAIN_MENU, STAGE_SELECT, STAGE }

const STAGE_SCENES := {
	1: "res://scenes/stages/Stage01.tscn",
	2: "res://scenes/stages/Stage02.tscn",
	3: "res://scenes/stages/Stage03.tscn",
	4: "res://scenes/stages/Stage04.tscn",
	5: "res://scenes/stages/Stage05.tscn",
	6: "res://scenes/stages/Stage06.tscn",
	7: "res://scenes/stages/Stage07.tscn",
	8: "res://scenes/stages/Stage08.tscn",
	9: "res://scenes/stages/Stage09.tscn",
}
const LAST_STAGE_ID := 9

const TITLE_SCENE := "res://scenes/ui/TitleScene.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const STAGE_SELECT_SCENE := "res://scenes/ui/StageSelect.tscn"

@export var current_stage_root_path: NodePath
@export var overlay_path: NodePath
@export var virtual_cursor_path: NodePath
@export var cursor_targeting_resolver_path: NodePath
# Phase 13 — SceneFlowBootBypassTest 전용 (plan Δ10). production 부트는 0 → TITLE.
# add_child(main) 전에 export 설정해야 _ready에서 인식. 0이면 정상 title 부트.
@export var boot_to_stage_id: int = 0

var _current_stage_root: Node = null
var _overlay: Node = null
var _current_stage_id: int = 0
var _current_stage_node: Node = null
var _resolver: Node = null
var _last_result: Dictionary = {}

var current_screen: ScreenState = ScreenState.TITLE

func _ready() -> void:
	_current_stage_root = get_node(current_stage_root_path)
	_overlay = get_node(overlay_path)

	if not virtual_cursor_path.is_empty():
		var cursor: Control = get_node_or_null(virtual_cursor_path) as Control
		if cursor != null:
			InputRouter.set_virtual_cursor(cursor)
	if not cursor_targeting_resolver_path.is_empty():
		_resolver = get_node_or_null(cursor_targeting_resolver_path)

	EventBus.stage_cleared.connect(_on_stage_result)
	EventBus.stage_failed.connect(_on_stage_result)
	EventBus.request_replay.connect(_on_request_replay)
	EventBus.request_next.connect(_on_request_next)
	EventBus.request_menu.connect(_on_request_menu)
	EventBus.request_main_menu.connect(_on_request_main_menu)
	EventBus.request_stage_select.connect(_on_request_stage_select)
	EventBus.request_play_stage.connect(_on_request_play_stage)
	EventBus.request_title.connect(_on_request_title)
	EventBus.action_triggered.connect(_on_action_triggered)

	_boot()

func _boot() -> void:
	if boot_to_stage_id > 0 and STAGE_SCENES.has(boot_to_stage_id):
		load_stage(boot_to_stage_id)
	else:
		go_to_title()

# ─── screen 전이 (public) ────────────────────────────────────────
func start_game() -> void:
	# Legacy. phase 13에서 _boot()가 대체. 호환 보존.
	go_to_title()

func go_to_title() -> void:
	_swap_screen(load(TITLE_SCENE).instantiate(), ScreenState.TITLE)

func go_to_main_menu() -> void:
	_swap_screen(load(MAIN_MENU_SCENE).instantiate(), ScreenState.MAIN_MENU)

func go_to_stage_select() -> void:
	_swap_screen(load(STAGE_SELECT_SCENE).instantiate(), ScreenState.STAGE_SELECT)

func go_to_menu() -> void:
	# phase 6 legacy 시그니처 보존 — main menu alias.
	go_to_main_menu()

func load_stage(stage_id: int) -> void:
	# Codex R6 HIGH fix: 잘못된 stage_id에 대해 _unload_current_screen()를 먼저 호출하면
	# blank screen + 복구 경로 없음. 검증을 unload 전에 옮기고, 미존재 stage는 fallback.
	if not STAGE_SCENES.has(stage_id):
		push_error("[SceneFlow] unknown stage_id %d — falling back to main menu" % stage_id)
		# blank 회피 — 현재 screen이 STAGE면 main menu로, 그 외엔 그대로 유지.
		if current_screen == ScreenState.STAGE:
			go_to_main_menu()
		return
	# Codex(세션 8) — 등록된 stage_id라도 그 .tscn/.tres가 누락(미커밋·export 제외)이면 load()가 null 반환 →
	# instantiate() 크래시. **_unload_current_screen() 전에** load+검증해(codex 재리뷰 MEDIUM) 실패 시 현재 화면을
	# 파괴하지 않고 보존 — unknown stage_id 가드와 동일 정책(STAGE면 main menu, 그 외엔 유지).
	var scene: PackedScene = load(STAGE_SCENES[stage_id])
	if scene == null:
		push_error("[SceneFlow] stage %d 리소스 load 실패(%s) — 현재 화면 보존(STAGE면 main menu)" % [stage_id, STAGE_SCENES[stage_id]])
		if current_screen == ScreenState.STAGE:
			go_to_main_menu()
		return
	_unload_current_screen()
	_last_result = {}
	var stage_node: Node = scene.instantiate()
	_current_stage_root.add_child(stage_node)
	_current_stage_node = stage_node
	_current_stage_id = stage_id
	current_screen = ScreenState.STAGE
	if _resolver != null and _resolver.has_method("set_active_stage_root"):
		_resolver.set_active_stage_root(stage_node)

func load_next_stage() -> void:
	var next_id: int = _current_stage_id + 1
	if not STAGE_SCENES.has(next_id):
		# last-stage clear → main menu 복귀 (phase 6 stage1 fallback 폐기, plan §3.5.4)
		go_to_main_menu()
		return
	load_stage(next_id)

func replay_stage() -> void:
	load_stage(_current_stage_id)

func get_active_stage_node() -> Node:
	if _current_stage_node == null:
		return null
	if not is_instance_valid(_current_stage_node):
		_current_stage_node = null
		return null
	return _current_stage_node

# ─── 내부 헬퍼 ──────────────────────────────────────────────────
# plan Δ9 (codex HIGH-1): remove_child + queue_free 일괄.
# queue_free 단독 사용 시 deferred deletion이라 다음 frame까지 tree에 남음 →
# 그 사이 _process가 깨어나 stale stage_cleared/failed emit 가능.
# remove_child로 즉시 tree에서 분리 후 queue_free → _process 중단 보장.
# CurrentStageRoot 자체 process_mode를 INHERIT으로 복귀하면서 메뉴 진입 후 frozen
# 잔존 차단 (frozen된 채 메뉴 _process가 안 도는 버그 차단).
func _unload_current_screen() -> void:
	var children: Array = _current_stage_root.get_children()
	for child in children:
		_current_stage_root.remove_child(child)
		child.queue_free()
	_current_stage_node = null
	_current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
	if _resolver != null and _resolver.has_method("set_active_stage_root"):
		_resolver.set_active_stage_root(null)

func _swap_screen(new_node: Node, new_state: ScreenState) -> void:
	_unload_current_screen()
	_current_stage_node = null
	_current_stage_id = 0
	_last_result = {}
	_current_stage_root.add_child(new_node)
	current_screen = new_state

func _freeze_current_stage() -> void:
	# phase 12 산출. StageDialog 표시 중 stage 정지.
	_current_stage_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_current_stage() -> void:
	_current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT

# ─── EventBus 핸들러 ───────────────────────────────────────────
func _on_stage_result(result: Dictionary) -> void:
	_last_result = result
	_freeze_current_stage()
	# Phase 20 — `>=` → `==` 등치 변경 (R1-H4). 미래 STAGE_SCENES 확장 시 last-stage 오인 회피.
	# dev stage(910~)는 STAGE_SCENES 미등록 → SceneFlow 경유 안 함 (자연 분기 유지).
	_overlay.show_result(result, result["stage_id"] == LAST_STAGE_ID)

func _on_request_replay() -> void:
	_overlay.hide_overlay()
	if current_screen != ScreenState.STAGE or _current_stage_id <= 0:
		return
	_unfreeze_current_stage()
	replay_stage()

func _on_request_next() -> void:
	# Next는 cleared 결과에서만 (phase 6 산출, plan §3.5.4)
	if not _last_result.get("cleared", false):
		return
	_overlay.hide_overlay()
	_unfreeze_current_stage()
	load_next_stage()

func _on_request_menu() -> void:
	# Δ14 legacy alias — StageDialog Menu 버튼만 emit. main menu 복귀로 매핑.
	_on_request_main_menu()

func _on_request_main_menu() -> void:
	_overlay.hide_overlay()
	go_to_main_menu()

func _on_request_stage_select() -> void:
	_overlay.hide_overlay()
	go_to_stage_select()

func _on_request_play_stage(stage_id: int) -> void:
	_overlay.hide_overlay()
	load_stage(stage_id)

func _on_request_title() -> void:
	_overlay.hide_overlay()
	go_to_title()

func _on_action_triggered(name: StringName, _payload: Dictionary) -> void:
	if name != GameAction.RESTART_STAGE:
		return
	# 메뉴에서 Ctrl+R/pad B-hold 무시 (plan §3.5.5)
	if current_screen != ScreenState.STAGE:
		return
	if InputRouter != null and InputRouter.has_method("are_pause_actions_blocked") \
			and InputRouter.are_pause_actions_blocked():
		return
	EventBus.request_replay.emit()
