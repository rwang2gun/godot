extends Node

# campaign-50 Phase A — SceneFlow 챕터 라우팅 + 매니페스트 순서 Next.
# 케이스: LAST_STAGE_ID == manifest last(==10) / request_chapter_select → CHAPTER_SELECT /
#   request_stage_select(chapter) → STAGE_SELECT(현재 챕터 주입) / load_next_stage가 매니페스트 순서 추종 /
#   마지막 스테이지 다음 → MAIN_MENU.

const TEST_PATH := "user://test_sceneflow_chapter_flow.cfg"
var _orig_path: String
var _main: Node = null
var _scene_flow: Node = null
var _failed: bool = false

func _ready() -> void:
	_orig_path = SaveData._save_path
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)
	_main = $Main
	_scene_flow = _main.get_node("SceneFlow")
	if _scene_flow == null:
		return _fail("SceneFlow node missing in Main")
	await get_tree().process_frame  # boot 완료

	# (1) 엔드포인트 수렴: SceneFlow.LAST_STAGE_ID == manifest last == 10.
	var manifest: CampaignManifest = Campaign.manifest()
	if manifest == null:
		return _fail("Campaign.manifest() null")
	_eq(manifest.last_stage_id(), 10, "manifest last_stage_id == 10")
	_eq(_scene_flow.LAST_STAGE_ID, manifest.last_stage_id(), "SceneFlow.LAST_STAGE_ID == manifest last")
	if _failed: return

	# (2) request_chapter_select → CHAPTER_SELECT
	EventBus.request_chapter_select.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(_scene_flow.current_screen, _scene_flow.ScreenState.CHAPTER_SELECT, "request_chapter_select → CHAPTER_SELECT")
	if _failed: return

	# (3) request_stage_select(2) → STAGE_SELECT + 챕터 컨텍스트 주입
	EventBus.request_stage_select.emit(2)
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(_scene_flow.current_screen, _scene_flow.ScreenState.STAGE_SELECT, "request_stage_select(2) → STAGE_SELECT")
	var sel: StageSelect = _find_stage_select()
	if sel == null:
		return _fail("StageSelect node not found under CurrentStageRoot")
	_eq(sel.current_chapter, 2, "StageSelect.current_chapter == 2 (injected)")
	if _failed: return

	# (4) load_next_stage가 매니페스트 순서 추종 — stage 8 다음은 9(전역 순서), ±1 우연 일치가 아니라
	#     Campaign.next_stage_id(8)을 통과함을 확인(8은 Ch4 단독, 9는 Ch5 첫째).
	_scene_flow.load_stage(8)
	await get_tree().process_frame
	await get_tree().process_frame
	_scene_flow.load_next_stage()
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(_scene_flow._current_stage_id, 9, "load_next from 8 → 9 (manifest order)")
	if _failed: return

	# (5) 마지막 스테이지(10) 다음 → MAIN_MENU (next=0)
	_scene_flow.load_stage(10)
	await get_tree().process_frame
	await get_tree().process_frame
	_scene_flow.load_next_stage()
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(_scene_flow.current_screen, _scene_flow.ScreenState.MAIN_MENU, "after last stage(10) next → MAIN_MENU")
	if _failed: return

	# (6) 스캔 *이후* 매니페스트 재배치가 published/LAST/next에 반영 — 단일 SoT 가드(codex impl R1 MED).
	#     ensure_stage_scan은 이미 (1)에서 완료됨. Campaign._test_set_manifest가 SceneFlow 캐시를 무효화하므로
	#     재배치된 순서([2,1])가 LAST_STAGE_ID·load_next_stage에 즉시 반영돼야 한다(stale 스냅샷 split-brain 없음).
	var reordered := CampaignManifest.new()
	reordered.chapters = [{"title": "R", "theme": "t", "stage_ids": [2, 1]}]  # 순서 뒤집기, 둘 다 씬 존재
	if not reordered.is_valid():
		return _fail("reordered test manifest invalid")
	Campaign._test_set_manifest(reordered)  # invalidate_stage_scan 자동 호출
	_scene_flow.load_stage(2)
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(_scene_flow.LAST_STAGE_ID, 1, "LAST_STAGE_ID follows reordered manifest (order [2,1] → last=1)")
	if _failed:
		Campaign._load_manifest()
		return
	_scene_flow.load_next_stage()
	await get_tree().process_frame
	await get_tree().process_frame
	_eq(_scene_flow._current_stage_id, 1, "load_next from 2 → 1 (reordered order, not stale +1/published)")
	Campaign._load_manifest()  # 라이브 매니페스트 복원
	if _failed: return

	_main.queue_free()
	await get_tree().process_frame
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[SceneFlowChapterFlowTest] PASS")
	get_tree().quit(0)

func _find_stage_select() -> StageSelect:
	for child in _main.get_node("CurrentStageRoot").get_children():
		if child is StageSelect:
			return child
	return null

func _eq(actual: int, expected: int, label: String) -> void:
	if _failed: return
	if actual != expected:
		_fail("%s — expected %d, got %d" % [label, expected, actual])

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[SceneFlowChapterFlowTest] FAIL ", msg)
	get_tree().quit(1)
