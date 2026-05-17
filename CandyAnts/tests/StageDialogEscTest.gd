extends Node

# Phase 12 — dialog-local Esc → request_menu 검증 (Main.tscn 전체 시나리오로 InputRouter chain 활성).
# visible=false 시 Esc 무시 (idempotency) + InputRouter/SkillToolbar가 ESC를 double-consume 안 함.

const MainScene := preload("res://scenes/Main.tscn")

var _failed: bool = false
var _menu_count: int = 0
var _replay_count: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.request_menu.connect(func(): _menu_count += 1)
	EventBus.request_replay.connect(func(): _replay_count += 1)
	var main: Node = MainScene.instantiate()
	add_child(main)
	# SceneFlow._ready + start_game(1) 완료 대기.
	await get_tree().process_frame
	await get_tree().process_frame
	var node = main.get_node_or_null("GlobalUI/StageDialog")
	if node == null:
		_fail("StageDialog path 'GlobalUI/StageDialog' missing under Main")
		return
	var dlg: StageDialog = node as StageDialog
	if dlg == null:
		_fail("StageDialog cast failed — node class=%s script=%s" % [node.get_class(), str(node.get_script())])
		return
	# Case 1: visible=false 상태에서 Esc 무시 (idempotency).
	if dlg.visible:
		_fail("dialog should start hidden")
		return
	_inject_esc()
	await get_tree().process_frame
	if _menu_count != 0:
		_fail("Case 1: Esc on hidden dialog leaked request_menu emit count=%d" % _menu_count)
		return
	# Case 2: show_result(loss) → Esc → request_menu 1회.
	var result := {"stage_id": 1, "cleared": false, "saved": 0, "lost": 10, "original_hp": 10, "score": 0.0, "time_left": 0.0, "reason": "no_more_ants"}
	dlg.show_result(result, false)
	await get_tree().process_frame
	_inject_esc()
	# fade_out 0.15s × time_scale=8 → margin 포함 1s.
	var elapsed := 0.0
	while elapsed < 1.0 and _menu_count == 0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if _menu_count != 1:
		_fail("Case 2: Esc on visible dialog expected request_menu emit 1, got %d" % _menu_count)
		return
	if _replay_count != 0:
		_fail("Case 2: stray request_replay emit count=%d (expected 0, no double-consume)" % _replay_count)
		return
	print("[StageDialogEscTest] PASS")
	get_tree().quit(0)

func _inject_esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	# Release event도 보내 InputMap stuck 회피.
	var rel := InputEventKey.new()
	rel.keycode = KEY_ESCAPE
	rel.pressed = false
	Input.parse_input_event(rel)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[StageDialogEscTest] FAIL ", msg)
	get_tree().quit(1)
