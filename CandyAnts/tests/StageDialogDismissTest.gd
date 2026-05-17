extends Node

# Phase 12 — show_result → 버튼 클릭 → fade_out 진행 → request_* emit 검증.
# 첫 클릭 후 즉시 모든 버튼 disabled (재진입 가드).

const StageDialogScene := preload("res://scenes/ui/StageDialog.tscn")

var _failed: bool = false
var _replay_emitted: bool = false
var _next_emitted: bool = false
var _menu_emitted: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.request_replay.connect(func(): _replay_emitted = true)
	EventBus.request_next.connect(func(): _next_emitted = true)
	EventBus.request_menu.connect(func(): _menu_emitted = true)
	await _case("replay")
	if _failed: return
	await _case("next")
	if _failed: return
	await _case("menu")
	if _failed: return
	print("[StageDialogDismissTest] PASS")
	get_tree().quit(0)

func _case(button: String) -> void:
	_replay_emitted = false
	_next_emitted = false
	_menu_emitted = false
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var result := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
	dlg.show_result(result, false)
	await get_tree().process_frame
	var btn: CButton
	var expected_var := "_replay_emitted"
	match button:
		"replay":
			btn = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/ReplayBtn")
			expected_var = "_replay_emitted"
		"next":
			btn = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/NextBtn")
			expected_var = "_next_emitted"
		"menu":
			btn = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/MenuBtn")
			expected_var = "_menu_emitted"
	btn.pressed.emit()
	# 첫 클릭 후 즉시 모든 버튼 disabled (재진입 가드).
	await get_tree().process_frame
	var replay_btn: CButton = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/ReplayBtn")
	var menu_btn: CButton = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/MenuBtn")
	if not replay_btn.disabled or not menu_btn.disabled:
		_fail("%s: Replay/Menu not disabled immediately after click" % button)
		return
	# fade_out 0.15s × time_scale=8 → ~20ms wall + 추가 frame margin.
	var elapsed := 0.0
	while elapsed < 1.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if get(expected_var):
			break
	if not get(expected_var):
		_fail("%s: expected emit not received" % button)
		return
	# 다른 두 signal은 emit되면 안 됨.
	var other_emitted := false
	if button != "replay" and _replay_emitted: other_emitted = true
	if button != "next" and _next_emitted: other_emitted = true
	if button != "menu" and _menu_emitted: other_emitted = true
	if other_emitted:
		_fail("%s: stray emit on other signal" % button)
		return
	dlg.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[StageDialogDismissTest] FAIL ", msg)
	get_tree().quit(1)
