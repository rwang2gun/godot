class_name SceneFlow extends Node

const STAGE_SCENES := {
	1: "res://scenes/stages/Stage01.tscn",
	2: "res://scenes/stages/Stage02.tscn",
	3: "res://scenes/stages/Stage03.tscn",
}
const LAST_STAGE_ID := 3

@export var current_stage_root_path: NodePath
@export var overlay_path: NodePath

var _current_stage_root: Node = null
var _overlay: Node = null  # StageResultOverlayStub
var _current_stage_id: int = 0
var _last_result: Dictionary = {}  # 가장 최근 stage 결과; load_stage에서 reset. Next 가드용 (codex plan-review HIGH 2026-05-10 R2)

func _ready() -> void:
	_current_stage_root = get_node(current_stage_root_path)
	_overlay = get_node(overlay_path)

	EventBus.stage_cleared.connect(_on_stage_result)
	EventBus.stage_failed.connect(_on_stage_result)
	EventBus.request_replay.connect(_on_request_replay)
	EventBus.request_next.connect(_on_request_next)
	EventBus.request_menu.connect(_on_request_menu)

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
	_current_stage_id = stage_id

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

func _unload_current_stage() -> void:
	for child in _current_stage_root.get_children():
		child.queue_free()

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
