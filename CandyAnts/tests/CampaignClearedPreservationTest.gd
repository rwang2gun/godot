extends Node

# campaign-50 B1 가드 (plan M-1 / R2-MEDIUM-1) — 매니페스트 재배치(stage02: slot2→slot6) 후
# SaveData cleared 보존 + 언락 재계산을 실증 (ADR-014).
#   (a) 보존: id2 cleared 기록 → 라이브 매니페스트 [1,11,12,13,14,2] 하에서 id2는 여전히 cleared,
#       Ch1 slot6 = CLEARED (cleared가 unlock보다 우선 — _resolve_slot_state).
#   (b) 언락 재계산: id2 미클리어 + 직전(id14)만 cleared → slot6 = PLAYABLE
#       (언락 체인이 ±1 산술이 아니라 매니페스트 *순서*를 따름을 실증).

const StageSelectScene := preload("res://scenes/ui/StageSelect.tscn")
const TEST_PATH := "user://test_savedata_cleared_preservation.cfg"
const SLOT6_INDEX := 5

var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	await _case_preserved_cleared()
	if _failed: return
	await _case_unlock_recomputed()
	if _failed: return
	_cleanup()
	SaveData._test_reset(_orig_path)
	print("[CampaignClearedPreservationTest] PASS")
	get_tree().quit(0)

# (a) id2 cleared → 재배치 후에도 cleared 보존 + slot6=CLEARED.
func _case_preserved_cleared() -> void:
	_reset()
	SaveData.record_clear(2, 10, 10)
	if not bool(SaveData.get_stage_entry(2).get("cleared", false)):
		return _fail("(a) id2 cleared 기록이 SaveData에 보존되지 않음")
	var state: int = await _slot6_state()
	if _failed: return
	if state != StageSlotCard.SlotState.CLEARED:
		return _fail("(a) slot6 expected CLEARED(%d), got %d" % [StageSlotCard.SlotState.CLEARED, state])
	print("[CampaignClearedPreservationTest] case (a) preserved cleared OK")

# (b) id2 미클리어 + 직전 id14만 cleared → slot6=PLAYABLE.
func _case_unlock_recomputed() -> void:
	_reset()
	SaveData.record_clear(14, 10, 10)
	var state: int = await _slot6_state()
	if _failed: return
	if state != StageSlotCard.SlotState.PLAYABLE:
		return _fail("(b) slot6 expected PLAYABLE(%d), got %d" % [StageSlotCard.SlotState.PLAYABLE, state])
	print("[CampaignClearedPreservationTest] case (b) unlock recomputed OK")

func _slot6_state() -> int:
	var node: StageSelect = StageSelectScene.instantiate()
	node.current_chapter = 1
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: GridContainer = node.get_node("MarginContainer/VBox/SlotGrid")
	if grid.get_child_count() != 10:
		node.queue_free()
		_fail("chapter1 expected 10 slots, got %d" % grid.get_child_count())
		return -1
	var card: StageSlotCard = grid.get_child(SLOT6_INDEX) as StageSlotCard
	if card == null:
		node.queue_free()
		_fail("slot6 card null")
		return -1
	if card.stage_id != 2:
		node.queue_free()
		_fail("slot6 stage_id expected 2(재배치), got %d" % card.stage_id)
		return -1
	var state: int = card.slot_state
	node.queue_free()
	await get_tree().process_frame
	return state

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
	print("[CampaignClearedPreservationTest] FAIL ", msg)
	get_tree().quit(1)
