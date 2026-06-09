extends Node

# Phase 13 — plan Δ15. SlotState priority + 4 state.
# campaign-50 Phase A — StageSelect 챕터 컨텍스트화. menu_layout 고정 10슬롯 폐기 →
#   current_chapter 주입 후 Campaign.stage_ids_in_chapter로 가변 슬롯 생성. 슬롯 상태는
#   Campaign(매니페스트 순서) 언락 기반. 라이브 매니페스트 Ch1=[1,2] · Ch2=[3,4,5].

const StageSelectScene := preload("res://scenes/ui/StageSelect.tscn")
const TEST_PATH := "user://test_savedata_select_unlock.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	await _case_chapter1_initial()
	if _failed: return
	await _case_chapter2_gating()
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[StageSelectUnlockTest] PASS")
	get_tree().quit(0)

# Ch1=[1,2]: stage1 cleared → slot1=CLEARED, slot2=PLAYABLE(prev=1 cleared).
func _case_chapter1_initial() -> void:
	_reset()
	SaveData.record_clear(1, 6, 10)
	var node: StageSelect = StageSelectScene.instantiate()
	node.current_chapter = 1
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: GridContainer = node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 2:
		node.queue_free()
		return _fail("chapter1 expected 2 slots, got %d" % grid.get_child_count())
	var expected := [StageSlotCard.SlotState.CLEARED, StageSlotCard.SlotState.PLAYABLE]
	for i in 2:
		var card: StageSlotCard = grid.get_child(i) as StageSlotCard
		if card.slot_state != expected[i]:
			node.queue_free()
			return _fail("ch1 slot[%d] state expected %d, got %d" % [i, expected[i], card.slot_state])
	# total_stars label 포맷 유지
	var label: Label = node.get_node("MarginContainer/VBox/Footer/TotalStarsLabel")
	if not label.text.begins_with("수확한 별 ★"):
		node.queue_free()
		return _fail("total stars label format wrong: %s" % label.text)
	node.queue_free()
	await get_tree().process_frame
	print("[StageSelectUnlockTest] case chapter1 initial OK")

# Ch2=[3,4,5]: stage1,2 cleared → slot3=PLAYABLE(prev=2 cleared), slot4·5=LOCKED.
func _case_chapter2_gating() -> void:
	_reset()
	SaveData.record_clear(1, 10, 10)
	SaveData.record_clear(2, 10, 10)
	var node: StageSelect = StageSelectScene.instantiate()
	node.current_chapter = 2
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: GridContainer = node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 3:
		node.queue_free()
		return _fail("chapter2 expected 3 slots, got %d" % grid.get_child_count())
	var expected := [
		StageSlotCard.SlotState.PLAYABLE,  # stage3 (prev=2 cleared)
		StageSlotCard.SlotState.LOCKED,    # stage4 (prev=3 not cleared)
		StageSlotCard.SlotState.LOCKED,    # stage5
	]
	for i in 3:
		var card: StageSlotCard = grid.get_child(i) as StageSlotCard
		if card.slot_state != expected[i]:
			node.queue_free()
			return _fail("ch2 slot[%d] state expected %d, got %d" % [i, expected[i], card.slot_state])
	node.queue_free()
	await get_tree().process_frame
	print("[StageSelectUnlockTest] case chapter2 gating OK")

func _reset() -> void:
	_cleanup()
	SaveData._test_reset(TEST_PATH)

func _cleanup() -> void:
	SaveData._test_cleanup_files(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[StageSelectUnlockTest] FAIL ", msg)
	get_tree().quit(1)
