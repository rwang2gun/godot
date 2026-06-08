extends Node
## Phase 23 — BGM 실배선 검증. SceneFlow 실제 전이가 옳은 지점/track으로 bgm_request를 emit하고,
## BgmPlayer가 boot emit *이전에* 구독돼 있는지 확인한다. repo 스캔(BgmReceiverTest)이 못 잡는
## "전이 지점·순서·구독 타이밍"을 본다.
##
## Phase 24(에셋 배치 후): 실제 ogg가 로드되므로 menu 진입 "menu" emit이 실제 재생된다 →
## current_track=="menu" + play_generation≥1 + STAGE 진입 시 "gameplay" 전환을 단언(asset-present).
## (Phase 23에선 빈 _streams 무음 경계 — current_track=="" + play_generation==0 — 였고 R2에서 역전.)
##
## **타이틀 무음 정책(2026-06-08)**: 타이틀 인트로 영상은 영상 자체에 사운드가 있어 boot→TITLE에선
## BGM을 깔지 않고 bgm_stop을 emit한다. menu BGM은 MAIN_MENU 진입부터. 따라서 boot 직후
## current_track=="" (무음), play_generation==0. 핵심은 SceneFlow 실전이가 옳은 지점/track으로
## emit하고 BgmPlayer가 boot emit 이전 구독돼 있는지.

const MainScene := preload("res://scenes/Main.tscn")
const TEST_PATH := "user://test_savedata_bgm_sceneflow.cfg"

var _emits: Array[StringName] = []
var _stops: int = 0
var _orig_path: String
var _failed: bool = false


func _ready() -> void:
	# boot emit 이전에 listener 구독(emit 유실 0). EventBus는 autoload라 main 인스턴스화 전 연결 가능.
	EventBus.bgm_request.connect(_collect)
	EventBus.bgm_stop.connect(_collect_stop)

	# (10) BgmPlayer(autoload)가 boot emit 이전에 이미 bgm_request/bgm_stop에 구독돼 있어야 함.
	if not EventBus.bgm_request.is_connected(Callable(BgmPlayer, "_on_bgm_request")):
		_fail("BgmPlayer가 bgm_request에 미구독 — emit 유실 위험 (autoload 순서)")
		return
	if not EventBus.bgm_stop.is_connected(Callable(BgmPlayer, "_on_bgm_stop")):
		_fail("BgmPlayer가 bgm_stop에 미구독 — TITLE 무음 정지 유실 위험 (autoload 순서)")
		return

	_orig_path = SaveData._save_path
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)

	var main: Node = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var sf = main.get_node("SceneFlow")

	# boot → TITLE → bgm_stop emit (타이틀 영상 자체 사운드 — BGM 무음). bgm_request는 0건.
	if sf.current_screen != sf.ScreenState.TITLE:
		return _fail("boot이 TITLE 아님 (%d)" % sf.current_screen)
	if not _emits.is_empty():
		return _fail("boot TITLE은 bgm_request 0건이어야 함, 실제 %s" % str(_emits))
	if _stops < 1:
		return _fail("boot TITLE에서 bgm_stop 미emit (기대 ≥1)")

	# (11) asset-present — Phase 24: 실제 ogg 로드됨. 단 TITLE은 무음이어야 함(current_track 비고 재생 0).
	if BgmPlayer._streams.is_empty():
		return _fail("(11) Phase 24인데 _streams 비어있음 — 에셋 로드 실패")
	if BgmPlayer.current_track != &"":
		return _fail("(11) boot TITLE인데 current_track='%s' (기대 무음 '')" % BgmPlayer.current_track)
	if BgmPlayer.play_generation != 0:
		return _fail("(11) boot TITLE 무음인데 play_generation=%d (기대 0)" % BgmPlayer.play_generation)

	# (12) 실전이 매핑/순서 — MAIN_MENU/STAGE_SELECT → menu, load_stage(published) → gameplay.
	EventBus.request_main_menu.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.MAIN_MENU:
		return _fail("MAIN_MENU 전이 실패 (%d)" % sf.current_screen)
	# MAIN_MENU 진입부터 menu BGM 실제 재생(무음 역전).
	if BgmPlayer.current_track != &"menu":
		return _fail("(12) MAIN_MENU 후 current_track='%s' (기대 menu, 실제 재생)" % BgmPlayer.current_track)
	if BgmPlayer.play_generation < 1:
		return _fail("(12) MAIN_MENU 재생인데 play_generation=%d (기대 ≥1)" % BgmPlayer.play_generation)

	EventBus.request_stage_select.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE_SELECT:
		return _fail("STAGE_SELECT 전이 실패 (%d)" % sf.current_screen)

	EventBus.request_play_stage.emit(1)
	await get_tree().process_frame
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE:
		return _fail("STAGE 전이 실패 (%d)" % sf.current_screen)
	# Phase 24 asset-present — STAGE 진입 시 gameplay로 실제 전환 재생.
	if BgmPlayer.current_track != &"gameplay":
		return _fail("STAGE 진입 후 current_track='%s' (기대 gameplay)" % BgmPlayer.current_track)

	# TITLE은 bgm_request 없음 → 메뉴2 + gameplay1. (boot의 bgm_stop은 _stops로 별도 집계.)
	var expected: Array[StringName] = [&"menu", &"menu", &"gameplay"]
	if _emits != expected:
		return _fail("bgm_request 시퀀스 기대 %s, 실제 %s" % [str(expected), str(_emits)])
	print("[BgmSceneFlowTest] emit 시퀀스 OK: req=%s stops=%d" % [str(_emits), _stops])

	main.queue_free()
	await get_tree().process_frame
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[BgmSceneFlowTest] PASS")
	get_tree().quit(0)


func _collect(track: StringName) -> void:
	_emits.append(track)


func _collect_stop() -> void:
	_stops += 1


func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	SaveData._test_cleanup_files(TEST_PATH)
	if _orig_path != "":
		SaveData._test_reset(_orig_path)
	print("[BgmSceneFlowTest] FAIL ", msg)
	get_tree().quit(1)
