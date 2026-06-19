extends Node

# Phase 13 — plan Δ15. SlotState priority + 4 state.
# campaign-50 Phase A — StageSelect 챕터 컨텍스트화. menu_layout 고정 10슬롯 폐기 →
#   current_chapter 주입 후 Campaign.stage_ids_in_chapter로 가변 슬롯 생성. 슬롯 상태는
#   Campaign(매니페스트 순서) 언락 기반.
# campaign-50 B1 — 라이브 매니페스트 Ch1=[1,11,12,13,14,2,15,16,17,18] · Ch2=[3,4,5,19,20,21,22,23,24,25](19~25 등록 2026-06-19).

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

# Ch1=[1,11,12,13,14,2,15,16,17,18]: stage1 cleared → slot1=CLEARED, slot2(id11)=PLAYABLE(prev=1 cleared),
# slot3~10(id12,13,14,2,15,16,17,18)=LOCKED (15~18 등록 2026-06-17으로 10칸 꽉 참 — placeholder 없음).
func _case_chapter1_initial() -> void:
	_reset()
	SaveData.record_clear(1, 6, 10)
	var node: StageSelect = StageSelectScene.instantiate()
	node.current_chapter = 1
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	# campaign-50: 챕터당 10칸 고정(SLOTS_PER_CHAPTER). Ch1=10 실제(placeholder 없음).
	var grid: GridContainer = node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 10:
		node.queue_free()
		return _fail("chapter1 expected 10 slots, got %d" % grid.get_child_count())
	# 실제 6칸 상태 + 나머지 4칸은 COMING_SOON placeholder.
	var expected := [
		StageSlotCard.SlotState.CLEARED,   # id1 (cleared)
		StageSlotCard.SlotState.PLAYABLE,  # id11 (prev=1 cleared)
		StageSlotCard.SlotState.LOCKED,    # id12
		StageSlotCard.SlotState.LOCKED,    # id13
		StageSlotCard.SlotState.LOCKED,    # id14
		StageSlotCard.SlotState.LOCKED,    # id2 (slot6 재배치 — prev=14 미클리어)
		StageSlotCard.SlotState.LOCKED,    # id15
		StageSlotCard.SlotState.LOCKED,    # id16
		StageSlotCard.SlotState.LOCKED,    # id17
		StageSlotCard.SlotState.LOCKED,    # id18
	]
	for i in 10:
		var card: StageSlotCard = grid.get_child(i) as StageSlotCard
		var want: int = expected[i] if i < expected.size() else StageSlotCard.SlotState.COMING_SOON
		if card.slot_state != want:
			node.queue_free()
			return _fail("ch1 slot[%d] state expected %d, got %d" % [i, want, card.slot_state])
		# LOW-2: placeholder는 상태뿐 아니라 stage_id==0(미등재 sentinel)까지 단언.
		if i >= expected.size() and card.stage_id != 0:
			node.queue_free()
			return _fail("ch1 placeholder slot[%d] stage_id expected 0, got %d" % [i, card.stage_id])
	# total_stars label 포맷 유지
	var label: Label = node.get_node("MarginContainer/VBox/Footer/TotalStarsLabel")
	if not label.text.begins_with("수확한 별 ★"):
		node.queue_free()
		return _fail("total stars label format wrong: %s" % label.text)
	node.queue_free()
	await get_tree().process_frame
	print("[StageSelectUnlockTest] case chapter1 initial OK")

# Ch2=[3,4,5,19,20,21,22,23,24,25]: stage18(Ch1 마지막) cleared → slot1=stage3 PLAYABLE(prev=18),
# slot2~10=LOCKED. 19~25 등재(2026-06-19)로 건설 챕터 10칸 꽉 참 → placeholder 0.
func _case_chapter2_gating() -> void:
	_reset()
	SaveData.record_clear(18, 10, 10)
	var node: StageSelect = StageSelectScene.instantiate()
	node.current_chapter = 2
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	# Ch2=[3,4,5,19,20,21,22,23,24,25] → 실제 10칸 + placeholder 0칸 = 10.
	var grid: GridContainer = node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 10:
		node.queue_free()
		return _fail("chapter2 expected 10 slots, got %d" % grid.get_child_count())
	# stage18 cleared → 첫 칸(stage3) PLAYABLE, 나머지(stage4,5,19~25)는 직전 미클리어로 LOCKED.
	var expected := [
		StageSlotCard.SlotState.PLAYABLE,  # stage3 (prev=18 cleared)
		StageSlotCard.SlotState.LOCKED,    # stage4
		StageSlotCard.SlotState.LOCKED,    # stage5
		StageSlotCard.SlotState.LOCKED,    # stage19
		StageSlotCard.SlotState.LOCKED,    # stage20
		StageSlotCard.SlotState.LOCKED,    # stage21
		StageSlotCard.SlotState.LOCKED,    # stage22
		StageSlotCard.SlotState.LOCKED,    # stage23
		StageSlotCard.SlotState.LOCKED,    # stage24
		StageSlotCard.SlotState.LOCKED,    # stage25
	]
	for i in 10:
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
