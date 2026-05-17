extends Node

# Phase 12 TDD stub — StageDialog API ping (show_result/hide_overlay/is_next_*/star_filled_count).
# 자세한 시각/race/sfx 검증은 별도 헤드리스 테스트가 담당.

const StageDialogScene := preload("res://scenes/ui/StageDialog.tscn")

func _ready() -> void:
	var dlg: StageDialog = StageDialogScene.instantiate()
	add_child(dlg)
	await get_tree().process_frame
	assert(dlg.has_method("show_result"), "show_result method present")
	assert(dlg.has_method("hide_overlay"), "hide_overlay method present")
	assert(dlg.has_method("is_next_visible"), "is_next_visible method present")
	assert(dlg.has_method("is_next_disabled"), "is_next_disabled method present")
	assert(dlg.has_method("star_filled_count"), "star_filled_count method present")
	assert(dlg.visible == false, "starts hidden")
	print("[test_StageDialog] PASS")
	get_tree().quit(0)
