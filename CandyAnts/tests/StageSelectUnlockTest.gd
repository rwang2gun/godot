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
	await _case_all_cleared_slot10_playable()
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[StageSelectUnlockTest] PASS")
	get_tree().quit(0)

func _case_initial() -> void:
	# stage1 cleared → slot1=CLEARED, slot2=PLAYABLE, slot3~10=LOCKED(available but prior 미클리어).
	# (S1~S10 캠페인 = menu_layout slots1~10 모두 available=true; Stage10 "보물찾기!" 정식 발행 2026-06-08.)
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
		StageSlotCard.SlotState.LOCKED,
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

func _case_all_cleared_slot10_playable() -> void:
	# Stage10 정식 발행(2026-06-08): slot10이 available=true가 되며 더 이상 COMING_SOON 슬롯이 없다.
	# stage1~9를 모두 cleared하면 slot10(available + prior(=9) cleared)은 PLAYABLE로 해금돼야 한다 —
	# 정식 발행이 실제로 마지막 스테이지를 진입 가능하게 만드는지 검증(구 Δ15 COMING_SOON 우선순위
	# 케이스를 대체; 캠페인에 available=false 슬롯이 없어 그 규칙은 더 이상 실증 대상이 없다).
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
	if slot10.slot_state != StageSlotCard.SlotState.PLAYABLE:
		select_node.queue_free()
		return _fail("slot10 expected PLAYABLE after 1~9 cleared, got %d (published last stage must unlock)" % slot10.slot_state)
	select_node.queue_free()
	await get_tree().process_frame
	print("[StageSelectUnlockTest] case all-cleared slot10 PLAYABLE OK")

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[StageSelectUnlockTest] FAIL ", msg)
	get_tree().quit(1)
