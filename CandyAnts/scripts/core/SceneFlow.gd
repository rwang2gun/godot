class_name SceneFlow extends Node

const GameAction := preload("res://scripts/input/GameAction.gd")

const STAGE_SCENES := {
	1: "res://scenes/stages/Stage01.tscn",
	2: "res://scenes/stages/Stage02.tscn",
	3: "res://scenes/stages/Stage03.tscn",
}
const LAST_STAGE_ID := 3

@export var current_stage_root_path: NodePath
@export var overlay_path: NodePath
@export var virtual_cursor_path: NodePath  # Phase 7 — VirtualCursor/Cursor (Control)
@export var cursor_targeting_resolver_path: NodePath  # Phase 7 — CursorTargetingResolver

var _current_stage_root: Node = null
var _overlay: Node = null  # StageResultOverlayStub
var _current_stage_id: int = 0
var _current_stage_node: Node = null  # Phase 7 — active stage instance (load 시 저장, unload 시 null)
var _resolver: Node = null
var _last_result: Dictionary = {}  # 가장 최근 stage 결과; load_stage에서 reset. Next 가드용 (codex plan-review HIGH 2026-05-10 R2)

func _ready() -> void:
	_current_stage_root = get_node(current_stage_root_path)
	_overlay = get_node(overlay_path)

	# Phase 7 — VirtualCursor/Resolver 주입.
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
	# Phase 7 — RESTART_STAGE 액션 라우터(Pad B-hold / Ctrl+R 모두 합류).
	EventBus.action_triggered.connect(_on_action_triggered)

	start_game()

func start_game() -> void:
	load_stage(1)

func load_stage(stage_id: int) -> void:
	_unload_current_stage()
	_last_result = {}  # 새 stage 진입 시 이전 결과 무효화 (Next 가드 reset)
	if not STAGE_SCENES.has(stage_id):
		push_error("[SceneFlow] unknown stage_id %d" % stage_id)
		return
	var scene: PackedScene = load(STAGE_SCENES[stage_id])
	var stage_node: Node = scene.instantiate()
	_current_stage_root.add_child(stage_node)
	_current_stage_node = stage_node
	_current_stage_id = stage_id
	# Phase 7 — resolver에 active stage 알림 (D-Pad targeting scoping).
	if _resolver != null and _resolver.has_method("set_active_stage_root"):
		_resolver.set_active_stage_root(stage_node)

func load_next_stage() -> void:
	var next_id: int = _current_stage_id + 1
	if not STAGE_SCENES.has(next_id):
		go_to_menu()
		return
	load_stage(next_id)

func replay_stage() -> void:
	load_stage(_current_stage_id)

func go_to_menu() -> void:
	# Phase 6: Stage01 reload fallback. Phase 13에서 실제 menu scene으로 교체.
	load_stage(1)

func get_active_stage_node() -> Node:
	# Phase 7 — CursorTargetingResolver가 active-stage subtree를 단일 SoT로 받기 위함.
	# unload 직후/reload 사이에는 null 반환 (resolver는 noop으로 처리).
	if _current_stage_node == null:
		return null
	if not is_instance_valid(_current_stage_node):
		_current_stage_node = null
		return null
	return _current_stage_node

func _unload_current_stage() -> void:
	for child in _current_stage_root.get_children():
		child.queue_free()
	_current_stage_node = null
	# Phase 7 — resolver의 stale reference 즉시 invalidate.
	if _resolver != null and _resolver.has_method("set_active_stage_root"):
		_resolver.set_active_stage_root(null)

func _freeze_current_stage() -> void:
	_current_stage_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_current_stage() -> void:
	_current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT

func _on_stage_result(result: Dictionary) -> void:
	_last_result = result
	_freeze_current_stage()
	_overlay.show_result(result, result["stage_id"] >= LAST_STAGE_ID)

func _on_request_replay() -> void:
	_overlay.hide_overlay()
	_unfreeze_current_stage()
	replay_stage()

func _on_request_next() -> void:
	# Next는 cleared 결과에서만 허용 — 실패 stage 우회 차단 (codex plan-review HIGH 2026-05-10 R2).
	# overlay disable이 1차 방어, 여기가 직접 signal emit (테스트/추후 input router)에 대한 2차 방어.
	if not _last_result.get("cleared", false):
		return
	_overlay.hide_overlay()
	_unfreeze_current_stage()
	load_next_stage()

func _on_request_menu() -> void:
	_overlay.hide_overlay()
	_unfreeze_current_stage()
	go_to_menu()

func _on_action_triggered(name: StringName, _payload: Dictionary) -> void:
	# Phase 7 — RESTART_STAGE만 소비. 그 외 액션은 SkillToolbar/InputRouter 등 다른 수신자.
	# request_replay 경유로 단일 replay 경로 재사용 (overlay hide + unfreeze + load_stage 동일).
	if name != GameAction.RESTART_STAGE:
		return
	# Phase 8 — StepFrame await 중에 direct EventBus emit이 들어와도 stage reload를 막는다.
	# (InputRouter gate가 1차, 본 가드는 테스트/외부 emit에 대한 2차 방어.)
	if InputRouter != null and InputRouter.has_method("are_pause_actions_blocked") \
			and InputRouter.are_pause_actions_blocked():
		return
	EventBus.request_replay.emit()
