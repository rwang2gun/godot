extends Node

# campaign-50 Phase A — ChapterSelect 카드 상태 + 라우팅.
# 라이브 매니페스트(B1 이후 5챕터 [1,11,12,13,14,2][3,4,5][6,7][8][9,10]).
# 케이스: fresh=ch1 PLAYABLE·나머지 LOCKED / ch1 클리어 후 ch1 CLEARED·ch2 PLAYABLE /
#   playable 카드 선택 → request_stage_select(chapter) / locked 카드 → emit 없음 / Back → request_main_menu.

const ChapterSelectScene := preload("res://scenes/ui/ChapterSelect.tscn")
const TEST_PATH := "user://test_chapter_select_flow.cfg"
var _orig_path: String
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	await _case_states_fresh()
	if _failed: return
	await _case_states_after_ch1_clear()
	if _failed: return
	await _case_routing()
	if _failed: return
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[ChapterSelectFlowTest] PASS")
	get_tree().quit(0)

func _case_states_fresh() -> void:
	_reset()
	var cs: ChapterSelect = await _make()
	_expect(cs, 1, ChapterSelect.ChapterState.PLAYABLE, "ch1 PLAYABLE fresh")
	for c in [2, 3, 4, 5]:
		_expect(cs, c, ChapterSelect.ChapterState.LOCKED, "ch%d LOCKED fresh" % c)
	cs.queue_free()
	await get_tree().process_frame
	if not _failed:
		print("[ChapterSelectFlowTest] case fresh OK")

func _case_states_after_ch1_clear() -> void:
	_reset()
	# Ch1=[1,11,12,13,14,2] 전부 클리어 (B1에서 신규 11~14 삽입 — 챕터 CLEARED는 전 스테이지 요구)
	for sid in [1, 11, 12, 13, 14, 2]:
		SaveData.record_clear(sid, 10, 10)
	var cs: ChapterSelect = await _make()
	_expect(cs, 1, ChapterSelect.ChapterState.CLEARED, "ch1 CLEARED after all Ch1 cleared")
	_expect(cs, 2, ChapterSelect.ChapterState.PLAYABLE, "ch2 PLAYABLE after ch1 cleared")
	_expect(cs, 3, ChapterSelect.ChapterState.LOCKED, "ch3 LOCKED (ch2 not cleared)")
	cs.queue_free()
	await get_tree().process_frame
	if not _failed:
		print("[ChapterSelectFlowTest] case after-ch1-clear OK")

func _case_routing() -> void:
	_reset()
	SaveData.record_clear(1, 10, 10)
	SaveData.record_clear(2, 10, 10)  # ch2 PLAYABLE 되도록
	var cs: ChapterSelect = await _make()
	# (a) playable 카드(ch1) 선택 → request_stage_select(1)
	var got: Array = [-1]
	var cb := func(ch: int): got[0] = ch
	EventBus.request_stage_select.connect(cb)
	cs._cards[0].pressed.emit()  # ch1 카드
	await get_tree().process_frame
	EventBus.request_stage_select.disconnect(cb)
	if got[0] != 1:
		cs.queue_free()
		return _fail("ch1 card → request_stage_select(1) failed, got %d" % got[0])
	# (b) locked 카드(ch3) 선택 → request_stage_select emit 없음
	var locked_emit: Array = [false]
	var cb2 := func(_ch: int): locked_emit[0] = true
	EventBus.request_stage_select.connect(cb2)
	cs._cards[2].pressed.emit()  # ch3 카드(LOCKED)
	await get_tree().process_frame
	EventBus.request_stage_select.disconnect(cb2)
	if locked_emit[0]:
		cs.queue_free()
		return _fail("locked ch3 card should NOT emit request_stage_select")
	# (c) Back → request_main_menu
	var menu: Array = [false]
	var cb3 := func(): menu[0] = true
	EventBus.request_main_menu.connect(cb3)
	cs._back_btn.pressed.emit()
	await get_tree().process_frame
	EventBus.request_main_menu.disconnect(cb3)
	if not menu[0]:
		cs.queue_free()
		return _fail("Back → request_main_menu failed")
	cs.queue_free()
	await get_tree().process_frame
	if not _failed:
		print("[ChapterSelectFlowTest] case routing OK")

func _make() -> ChapterSelect:
	var cs: ChapterSelect = ChapterSelectScene.instantiate()
	add_child(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	return cs

func _expect(cs: ChapterSelect, chapter_num: int, expected: int, label: String) -> void:
	if _failed: return
	var actual: int = cs.chapter_state(chapter_num)
	if actual != expected:
		cs.queue_free()
		_fail("%s — expected state %d, got %d" % [label, expected, actual])

func _reset() -> void:
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[ChapterSelectFlowTest] FAIL ", msg)
	get_tree().quit(1)
