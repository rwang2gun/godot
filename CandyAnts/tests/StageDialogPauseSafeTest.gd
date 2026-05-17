extends Node

# Phase 12 — paused tree에서 show_result → fade_in(pause_safe) + caPop이 진행되는지 검증.
# modulate.a → 1.0 + Card.scale → Vector2.ONE 근처. Replay 누르면 fade_out + request_replay emit.

const StageDialogScene := preload("res://scenes/ui/StageDialog.tscn")

var _failed: bool = false
var _replay_emitted: bool = false

func _ready() -> void:
	EventBus.request_replay.connect(func(): _replay_emitted = true)
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	get_tree().paused = true
	var result := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
	dlg.show_result(result, false)
	# 200ms wait — paused 무관 process_frame 진행.
	var elapsed := 0.0
	while elapsed < 0.3:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not dlg.visible:
		_fail("paused: dialog not visible")
		return
	if dlg.modulate.a < 0.99:
		_fail("paused: modulate.a=%.3f (expected ~1.0 via Motion.fade_in pause_safe)" % dlg.modulate.a)
		return
	var card: Control = dlg.get_node("CardWrapper/Card")
	# caPop end scale = (1.0, 1.0). 진행 안 되면 0.8 근처 stuck.
	# 정확도: is_equal_approx 대신 axes 둘 다 [0.97, 1.10] 범위 (caPop 1.08 overshoot 후 1.0 settle, 200ms 후 settle phase).
	if card.scale.x < 0.97 or card.scale.x > 1.10 or card.scale.y < 0.97 or card.scale.y > 1.10:
		_fail("paused: Card.scale=%s out of caPop settle range [0.97, 1.10] (caPop did not progress to 1.0)" % card.scale)
		return
	# Replay 누름 → fade_out + request_replay emit (paused 무관).
	var replay_btn: CButton = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/ReplayBtn")
	replay_btn.pressed.emit()
	elapsed = 0.0
	while elapsed < 1.0 and not _replay_emitted:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not _replay_emitted:
		_fail("paused: request_replay not emitted after Replay click")
		return
	get_tree().paused = false
	print("[StageDialogPauseSafeTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	get_tree().paused = false
	print("[StageDialogPauseSafeTest] FAIL ", msg)
	get_tree().quit(1)
