extends Node

# Phase 13 — plan Δ15. SlotState priority + 4 state.

const StageSelectScene := preload("res://scenes/ui/StageSelect.tscn")
const TEST_PATH := "user://test_savedata_select_unlock.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	await _case_initial()
	if _failed: return
	await _case_priority_coming_soon()
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[StageSelectUnlockTest] PASS")
	get_tree().quit(0)

func _case_initial() -> void:
	# stage1 cleared → slot1=CLEARED, slot2=PLAYABLE, slot3~9=LOCKED(available but prior 미클리어), slot10=COMING_SOON.
	# (S1~S9 캠페인 = menu_layout slots1~9 available=true; S9 "종합 과자점" 추가로 slot9 해금. slot10만 available=false.)
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	EventBus.stage_cleared.emit({"stage_id": 1, "cleared": true, "saved": 6, "original_hp": 10})
	await get_tree().process_frame
	var select_node: Control = StageSelectScene.instantiate()
	add_child(select_node)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: GridContainer = select_node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 10:
		select_node.queue_free()
		return _fail("expected 10 slots, got %d" % grid.get_child_count())
	var expected := [
		StageSlotCard.SlotState.CLEARED,
		StageSlotCard.SlotState.PLAYABLE,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.COMING_SOON,
	]
	for i in 10:
		var card: StageSlotCard = grid.get_child(i) as StageSlotCard
		if card.slot_state != expected[i]:
			select_node.queue_free()
			return _fail("slot[%d] state expected %d, got %d" % [i, expected[i], card.slot_state])
	# total_stars label
	var label: Label = select_node.get_node("MarginContainer/VBox/Footer/TotalStarsLabel")
	if not label.text.begins_with("수확한 별 ★"):
		select_node.queue_free()
		return _fail("total stars label format wrong: %s" % label.text)
	select_node.queue_free()
	await get_tree().process_frame
	print("[StageSelectUnlockTest] case initial OK")

func _case_priority_coming_soon() -> void:
	# Δ15: COMING_SOON(available=false) 우선순위가 unlock(playable)보다 높다 — stage1~9 모두 cleared여도
	# slot10(available=false)은 PLAYABLE로 승격되지 않고 COMING_SOON 유지. (S9 추가로 첫 available=false 슬롯이
	# slot9→slot10으로 이동 → 검증 대상 retarget.)
	_cleanup()
	SaveData._test_reset(TEST_PATH)
	for sid in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
		EventBus.stage_cleared.emit({"stage_id": sid, "cleared": true, "saved": 10, "original_hp": 10})
		await get_tree().process_frame
	var select_node: Control = StageSelectScene.instantiate()
	add_child(select_node)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: GridContainer = select_node.get_node("MarginContainer/VBox/SlotGrid")
	var slot10: StageSlotCard = grid.get_child(9) as StageSlotCard
	if slot10.slot_state != StageSlotCard.SlotState.COMING_SOON:
		select_node.queue_free()
		return _fail("Δ15: slot10 expected COMING_SOON, got %d (cleared+playable should not fallback)" % slot10.slot_state)
	select_node.queue_free()
	await get_tree().process_frame
	print("[StageSelectUnlockTest] case priority OK (Δ15)")

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[StageSelectUnlockTest] FAIL ", msg)
	get_tree().quit(1)
