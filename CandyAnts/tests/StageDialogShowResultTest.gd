extends Node

# Phase 12 — StageDialog.show_result 3 분기 검증.
# cleared+!last → visible+enabled, cleared+last → visible+disabled, !cleared → hidden+disabled.

const StageDialogScene := preload("res://scenes/ui/StageDialog.tscn")

var _failed: bool = false

func _ready() -> void:
	await _case_cleared_not_last()
	if _failed: return
	await _case_cleared_last()
	if _failed: return
	await _case_loss()
	if _failed: return
	print("[StageDialogShowResultTest] PASS")
	get_tree().quit(0)

func _make_dialog() -> StageDialog:
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	return dlg

func _case_cleared_not_last() -> void:
	var dlg := await _make_dialog()
	var result := {"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10, "score": 0.8, "time_left": 30.0, "reason": ""}
	dlg.show_result(result, false)
	await get_tree().process_frame
	if not dlg.visible:
		_fail("cleared+!last: dialog not visible")
		return
	if dlg.star_filled_count() != 2:
		_fail("cleared+!last: star_filled_count expected 2 got %d" % dlg.star_filled_count())
		return
	if not dlg.is_next_visible():
		_fail("cleared+!last: NextBtn not visible")
		return
	if dlg.is_next_disabled():
		_fail("cleared+!last: NextBtn disabled (expected enabled)")
		return
	dlg.queue_free()
	await get_tree().process_frame

func _case_cleared_last() -> void:
	var dlg := await _make_dialog()
	var result := {"stage_id": 3, "cleared": true, "saved": 10, "lost": 0, "original_hp": 10, "score": 1.0, "time_left": 47.0, "reason": ""}
	dlg.show_result(result, true)
	await get_tree().process_frame
	if not dlg.visible:
		_fail("cleared+last: dialog not visible")
		return
	if dlg.star_filled_count() != 3:
		_fail("cleared+last: star_filled_count expected 3 got %d" % dlg.star_filled_count())
		return
	if not dlg.is_next_visible():
		_fail("cleared+last: NextBtn not visible (expected visible+disabled grey)")
		return
	if not dlg.is_next_disabled():
		_fail("cleared+last: NextBtn not disabled (expected grey)")
		return
	dlg.queue_free()
	await get_tree().process_frame

func _case_loss() -> void:
	var dlg := await _make_dialog()
	var result := {"stage_id": 1, "cleared": false, "saved": 0, "lost": 10, "original_hp": 10, "score": 0.0, "time_left": 0.0, "reason": "no_more_ants"}
	dlg.show_result(result, false)
	await get_tree().process_frame
	if not dlg.visible:
		_fail("loss: dialog not visible")
		return
	if dlg.star_filled_count() != 0:
		_fail("loss: star_filled_count expected 0 got %d" % dlg.star_filled_count())
		return
	if dlg.is_next_visible():
		_fail("loss: NextBtn visible (expected hidden)")
		return
	if not dlg.is_next_disabled():
		_fail("loss: NextBtn not disabled (expected disabled even when hidden)")
		return
	dlg.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[StageDialogShowResultTest] FAIL ", msg)
	get_tree().quit(1)
