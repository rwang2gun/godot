extends Node

# Phase 20 — P-D6 회귀 가드. StageDialog.show_result Title.text 3 분기 검증.
#   (1) cleared && is_last_stage → "마지막 단계 클리어!"
#   (2) cleared && !is_last_stage → "사탕을 무사히 옮겼어요!"
#   (3) !cleared → "사탕이 부족했어요"

const StageDialogScene := preload("res://scenes/ui/StageDialog.tscn")

var _failed: bool = false

func _ready() -> void:
	await _case_last_cleared()
	if _failed: return
	await _case_mid_cleared()
	if _failed: return
	await _case_failed()
	if _failed: return
	print("[StageDialogLastStageTitleTest] PASS")
	get_tree().quit(0)

func _make_dialog() -> StageDialog:
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	return dlg

func _case_last_cleared() -> void:
	var dlg: StageDialog = await _make_dialog()
	var result := {
		"stage_id": 3, "cleared": true, "saved": 10, "lost": 0, "original_hp": 10,
		"score": 1.0, "time_left": 30.0, "reason": "",
	}
	dlg.show_result(result, true)
	await get_tree().process_frame
	var title: Label = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/Title") as Label
	if title.text != "마지막 단계 클리어!":
		_fail("last+cleared: Title.text expected '마지막 단계 클리어!' got '%s'" % title.text)
		return
	dlg.queue_free()
	await get_tree().process_frame

func _case_mid_cleared() -> void:
	var dlg: StageDialog = await _make_dialog()
	var result := {
		"stage_id": 1, "cleared": true, "saved": 8, "lost": 2, "original_hp": 10,
		"score": 0.8, "time_left": 30.0, "reason": "",
	}
	dlg.show_result(result, false)
	await get_tree().process_frame
	var title: Label = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/Title") as Label
	if title.text != "사탕을 무사히 옮겼어요!":
		_fail("mid+cleared: Title.text expected '사탕을 무사히 옮겼어요!' got '%s'" % title.text)
		return
	dlg.queue_free()
	await get_tree().process_frame

func _case_failed() -> void:
	var dlg: StageDialog = await _make_dialog()
	var result := {
		"stage_id": 1, "cleared": false, "saved": 0, "lost": 10, "original_hp": 10,
		"score": 0.0, "time_left": 0.0, "reason": "no_more_ants",
	}
	dlg.show_result(result, false)
	await get_tree().process_frame
	var title: Label = dlg.get_node("CardWrapper/Card/Main/Margin/VBox/Title") as Label
	if title.text != "사탕이 부족했어요":
		_fail("failed: Title.text expected '사탕이 부족했어요' got '%s'" % title.text)
		return
	dlg.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[StageDialogLastStageTitleTest] FAIL ", msg)
	get_tree().quit(1)
