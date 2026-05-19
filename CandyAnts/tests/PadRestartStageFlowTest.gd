extends Node

# Phase 7 — RESTART_STAGE 액션 emit → SceneFlow가 active stage instance 실제 reload.
# Main.tscn 인스턴스화하고 Stage01 instance를 캡처 → action emit → 새 instance와 다른지 검증.

const GameAction := preload("res://scripts/input/GameAction.gd")


const MainScene := preload("res://scenes/Main.tscn")

func _ready() -> void:
	# Sweep 2 (phase 13): Main 부트가 TITLE-first로 바뀌어 $Main 직접 instance만으로는 stage 없음 →
	# RESTART_STAGE가 current_screen!=STAGE 가드로 silent return. boot_to_stage_id=1로 STAGE 직행.
	var main: Node = MainScene.instantiate()
	var scene_flow: Node = main.get_node("SceneFlow")
	scene_flow.boot_to_stage_id = 1
	add_child(main)
	var current_root: Node = main.get_node("CurrentStageRoot")
	if scene_flow == null or current_root == null:
		_fail("missing nodes in Main"); return
	await get_tree().process_frame  # SceneFlow._ready / boot 완료
	await get_tree().process_frame
	if current_root.get_child_count() == 0:
		_fail("Stage1 not loaded after SceneFlow._ready"); return
	var first_stage: Node = current_root.get_child(0)
	var first_id: int = first_stage.get_instance_id()

	# === RESTART_STAGE 액션 emit ===
	EventBus.action_triggered.emit(GameAction.RESTART_STAGE, {})
	# SceneFlow → request_replay → _on_request_replay → unload + load_stage(1).
	# load_stage 직후 동일 frame에 새 instance가 children에 추가됨.
	await get_tree().process_frame
	await get_tree().process_frame

	if current_root.get_child_count() == 0:
		_fail("active stage missing after RESTART_STAGE emit"); return
	var new_stage: Node = null
	for c in current_root.get_children():
		if not c.is_queued_for_deletion():
			new_stage = c
			break
	if new_stage == null:
		_fail("no live stage child after RESTART_STAGE"); return
	if new_stage.get_instance_id() == first_id:
		_fail("stage instance not replaced — RESTART_STAGE silent no-op"); return

	# active stage provider getter 검증.
	if scene_flow.has_method("get_active_stage_node"):
		var provided: Node = scene_flow.get_active_stage_node()
		if provided != new_stage:
			_fail("get_active_stage_node should return current loaded stage"); return

	print("[PadRestartStageFlowTest] PASS first_id=%d new_id=%d" % [first_id, new_stage.get_instance_id()])
	get_tree().quit(0)


func _fail(msg: String) -> void:
	push_error("[PadRestartStageFlowTest] FAIL %s" % msg)
	get_tree().quit(1)
