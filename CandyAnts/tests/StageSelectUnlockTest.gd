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
	# campaign-50: 챕터당 10칸 고정(SLOTS_PER_CHAPTER). Ch1=[1,2] → 실제 2칸 + placeholder 8칸.
	var grid: GridContainer = node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 10:
		node.queue_free()
		return _fail("chapter1 expected 10 slots, got %d" % grid.get_child_count())
	# 실제 2칸 상태 + 나머지 8칸은 COMING_SOON placeholder.
	var expected := [StageSlotCard.SlotState.CLEARED, StageSlotCard.SlotState.PLAYABLE]
	for i in 10:
		var card: StageSlotCard = grid.get_child(i) as StageSlotCard
		var want: int = expected[i] if i < expected.size() else StageSlotCard.SlotState.COMING_SOON
		if card.slot_state != want:
			node.queue_free()
			return _fail("ch1 slot[%d] state expected %d, got %d" % [i, want, card.slot_state])
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
	# Ch2=[3,4,5] → 실제 3칸 + placeholder 7칸 = 10.
	var grid: GridContainer = node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 10:
		node.queue_free()
		return _fail("chapter2 expected 10 slots, got %d" % grid.get_child_count())
	var expected := [
		StageSlotCard.SlotState.PLAYABLE,  # stage3 (prev=2 cleared)
		StageSlotCard.SlotState.LOCKED,    # stage4 (prev=3 not cleared)
		StageSlotCard.SlotState.LOCKED,    # stage5
	]
	for i in 10:
		var card: StageSlotCard = grid.get_child(i) as StageSlotCard
		var want: int = expected[i] if i < expected.size() else StageSlotCard.SlotState.COMING_SOON
		if card.slot_state != want:
			node.queue_free()
			return _fail("ch2 slot[%d] state expected %d, got %d" % [i, want, card.slot_state])
	# placeholder(슬롯3=첫 빈칸) 라벨이 "임시"로 갱신됐는지 — set_state만으로 텍스트 미갱신되던 회귀 차단.
	var ph_label: Label = grid.get_child(3).get_node("MainPanel/VBox/StageLabel") as Label
	if ph_label.text != Strings.t("stage.coming_soon"):
		node.queue_free()
		return _fail("placeholder label expected '%s', got '%s'" % [Strings.t("stage.coming_soon"), ph_label.text])
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
