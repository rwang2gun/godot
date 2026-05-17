extends Node

# Phase 12 — EventBus.sfx_request id 4종 emit 검증.
# (a) show_result(cleared+8/10=2 stars) → dialog_open 1 + dialog_stats_pop 1 + star_fill 2.
# (b) show_result(loss, 0 star) → dialog_open 1 + dialog_stats_pop 1 + star_fill 0 (boundary SL-1).
# (c) dismiss (Replay/Next/Menu) → dialog_btn_press 1회 (request_* 직전).

const StageDialogScene := preload("res://scenes/ui/StageDialog.tscn")

var _failed: bool = false
var _sfx_log: Array[StringName] = []
var _request_log: Array[StringName] = []   # codex impl R1 LOW-2: dialog_btn_press vs request_* ordering 검증

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.sfx_request.connect(_on_sfx)
	EventBus.request_replay.connect(func(): _request_log.append(&"request_replay"))
	EventBus.request_next.connect(func(): _request_log.append(&"request_next"))
	EventBus.request_menu.connect(func(): _request_log.append(&"request_menu"))
	await _case_a_cleared_2stars()
	if _failed: return
	await _case_b_loss_0stars()
	if _failed: return
	await _case_c_dismiss()
	if _failed: return
	print("[StageDialogSfxTest] PASS")
	get_tree().quit(0)

func _on_sfx(id: StringName) -> void:
	_sfx_log.append(id)

func _case_a_cleared_2stars() -> void:
	_sfx_log.clear()
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var result := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
	dlg.show_result(result, false)
	await get_tree().process_frame
	var expected_open := _count(_sfx_log, &"dialog_open")
	var expected_stats := _count(_sfx_log, &"dialog_stats_pop")
	var expected_stars := _count(_sfx_log, &"star_fill")
	if expected_open != 1 or expected_stats != 1 or expected_stars != 2:
		_fail("case A: expected open=1 stats=1 star_fill=2 got open=%d stats=%d star_fill=%d log=%s" % [expected_open, expected_stats, expected_stars, str(_sfx_log)])
		return
	dlg.queue_free()
	await get_tree().process_frame

func _case_b_loss_0stars() -> void:
	_sfx_log.clear()
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var result := {"stage_id": 1, "cleared": false, "saved": 0, "lost": 10, "original_hp": 10, "score": 0.0, "time_left": 0.0, "reason": "no_more_ants"}
	dlg.show_result(result, false)
	await get_tree().process_frame
	var stars := _count(_sfx_log, &"star_fill")
	if stars != 0:
		_fail("case B: expected star_fill=0 (boundary 0-star), got %d log=%s" % [stars, str(_sfx_log)])
		return
	if _count(_sfx_log, &"dialog_open") != 1 or _count(_sfx_log, &"dialog_stats_pop") != 1:
		_fail("case B: open/stats not emitted exactly once log=%s" % str(_sfx_log))
		return
	dlg.queue_free()
	await get_tree().process_frame

func _case_c_dismiss() -> void:
	for button in ["replay", "next", "menu"]:
		_sfx_log.clear()
		_request_log.clear()
		var dlg: StageDialog = StageDialogScene.instantiate()
		add_child(dlg)
		await get_tree().process_frame
		var result := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
		dlg.show_result(result, false)
		await get_tree().process_frame
		_sfx_log.clear()  # show_result emits 후 dismiss emits만 캡처.
		_request_log.clear()
		var btn: CButton
		var expected_request: StringName = &""
		match button:
			"replay":
				btn = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/ReplayBtn")
				expected_request = &"request_replay"
			"next":
				btn = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/NextBtn")
				expected_request = &"request_next"
			"menu":
				btn = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/MenuBtn")
				expected_request = &"request_menu"
		btn.pressed.emit()
		# **Temporal ordering tight assert (codex R2 L-1)**: btn.pressed.emit 직후 (await 전) sfx_request emit은 synchronous.
		# StageDialog._dismiss_then_emit이 sfx_request(dialog_btn_press) emit 후 fade_out 시작.
		# 같은 micro-task 내 호출이라 await get_tree().process_frame 전에 _sfx_log에 기록됨.
		# request_* emit은 fade_out finished callback (별도 frame). 따라서 button press 직후엔 request_log empty.
		var press_count := _count(_sfx_log, &"dialog_btn_press")
		if press_count != 1:
			_fail("case C %s: expected dialog_btn_press=1 (synchronous emit) got %d log=%s" % [button, press_count, str(_sfx_log)])
			return
		if not _request_log.is_empty():
			_fail("case C %s: request_* emitted before fade_out completed — ordering violation. request_log=%s" % [button, str(_request_log)])
			return
		await get_tree().process_frame
		# fade_out (0.15s × time_scale=8) 완료까지 대기 → request_* emit.
		var elapsed := 0.0
		while elapsed < 1.0 and _request_log.is_empty():
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		# 최종: _request_log은 expected_request 1개.
		if _request_log.size() != 1 or _request_log[0] != expected_request:
			_fail("case C %s: expected request_log=[%s] got %s" % [button, expected_request, str(_request_log)])
			return
		dlg.queue_free()
		await get_tree().process_frame

func _count(arr: Array, id: StringName) -> int:
	var n := 0
	for x in arr:
		if x == id:
			n += 1
	return n

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[StageDialogSfxTest] FAIL ", msg)
	get_tree().quit(1)
