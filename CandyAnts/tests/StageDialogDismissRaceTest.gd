extends Node

# Phase 12 — codex R3 HIGH 회귀: dismiss fade window 도중 show_result/hide_overlay interleaved.
# 시나리오 A: show_result(old) → Replay 클릭 → 0.15s 전에 show_result(new) → stale request_* emit 0회.
# 시나리오 B: show_result(old) → Replay 클릭 → 0.15s 전에 hide_overlay() → stale request_* emit 0회 + 다음 show_result 정상.

const StageDialogScene := preload("res://scenes/ui/StageDialog.tscn")

var _failed: bool = false
var _stale_count: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.request_replay.connect(_on_stale)
	EventBus.request_next.connect(_on_stale)
	EventBus.request_menu.connect(_on_stale)
	await _scenario_a()
	if _failed: return
	await _scenario_b()
	if _failed: return
	print("[StageDialogDismissRaceTest] PASS")
	get_tree().quit(0)

func _on_stale() -> void:
	_stale_count += 1

func _scenario_a() -> void:
	_stale_count = 0
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var result_old := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
	dlg.show_result(result_old, false)
	await get_tree().process_frame
	# Replay 클릭 → dismiss 시작.
	var replay_btn: CButton = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/ReplayBtn")
	replay_btn.pressed.emit()
	await get_tree().process_frame
	# fade 도중 새 show_result (token invalidate).
	var result_new := {"stage_id": 2, "cleared": true, "saved": 5, "lost": 5, "original_hp": 10, "score": 0.5, "time_left": 20.0, "reason": ""}
	dlg.show_result(result_new, false)
	# fade duration 만큼 충분히 대기 (time_scale=8, 0.15s × ~5배 margin).
	var elapsed := 0.0
	while elapsed < 1.5:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if _stale_count != 0:
		_fail("scenario A: stale request_* emit count=%d (expected 0)" % _stale_count)
		return
	# 새 dialog 정상 visible.
	if not dlg.visible:
		_fail("scenario A: new dialog should be visible after interleaved show_result")
		return
	if dlg.modulate.a < 0.99:
		_fail("scenario A: new dialog modulate.a=%.3f (expected ~1.0)" % dlg.modulate.a)
		return
	# plan §4.1 + §7 요구: Card.scale도 reset 검증 (codex impl R1 MED-3).
	var card_a: Control = dlg.get_node("CardWrapper/Card")
	if not card_a.scale.is_equal_approx(Vector2.ONE):
		_fail("scenario A: Card.scale=%s (expected Vector2.ONE after interleaved show_result)" % card_a.scale)
		return
	dlg.queue_free()
	await get_tree().process_frame

func _scenario_b() -> void:
	_stale_count = 0
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	var result := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
	dlg.show_result(result, false)
	await get_tree().process_frame
	var replay_btn: CButton = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/ReplayBtn")
	replay_btn.pressed.emit()
	await get_tree().process_frame
	# fade 도중 hide_overlay (SceneFlow simulation).
	dlg.hide_overlay()
	var elapsed := 0.0
	while elapsed < 1.5:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if _stale_count != 0:
		_fail("scenario B: stale request_* emit count=%d (expected 0)" % _stale_count)
		return
	# 다음 show_result 정상 표시.
	dlg.show_result(result, false)
	# caPop 완료까지 충분히 대기 (220ms × time_scale=8 = ~28ms, margin 0.5s).
	var settle_elapsed := 0.0
	while settle_elapsed < 0.5:
		await get_tree().process_frame
		settle_elapsed += get_process_delta_time()
	if not dlg.visible:
		_fail("scenario B: dialog should be visible after re-show_result post hide_overlay")
		return
	# Card.scale reset 검증 (codex impl R1 MED-3) — caPop settle 후 1.0.
	var card_b: Control = dlg.get_node("CardWrapper/Card")
	if not card_b.scale.is_equal_approx(Vector2.ONE):
		_fail("scenario B: Card.scale=%s (expected Vector2.ONE after hide_overlay + re-show_result + caPop settle)" % card_b.scale)
		return
	dlg.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[StageDialogDismissRaceTest] FAIL ", msg)
	get_tree().quit(1)
