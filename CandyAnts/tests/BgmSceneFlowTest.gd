extends Node
## Phase 23 — BGM 실배선 검증. SceneFlow 실제 전이가 옳은 지점/track으로 bgm_request를 emit하고,
## BgmPlayer가 boot emit *이전에* 구독돼 있는지 확인한다. repo 스캔(BgmReceiverTest)이 못 잡는
## "전이 지점·순서·구독 타이밍"을 본다.
##
## 무음 경계 양립(plan review R2 HIGH): Main을 빈 _streams(Phase 23 무음) 상태로 구동하므로
## playback이 없다 → current_track 미갱신 + play_generation==0을 단언(무음 graceful). idempotent/
## play_generation 단언은 BgmReceiverTest가 주입 스트림으로 소유. 본 테스트는 emit 순서/매핑/구독만.
## (Phase 24에서 에셋 배치 후 이 단언은 asset-present 재생 단언으로 역전됨.)

const MainScene := preload("res://scenes/Main.tscn")
const TEST_PATH := "user://test_savedata_bgm_sceneflow.cfg"

var _emits: Array[StringName] = []
var _orig_path: String
var _failed: bool = false


func _ready() -> void:
	# boot emit 이전에 listener 구독(emit 유실 0). EventBus는 autoload라 main 인스턴스화 전 연결 가능.
	EventBus.bgm_request.connect(_collect)

	# (10) BgmPlayer(autoload)가 boot emit 이전에 이미 bgm_request에 구독돼 있어야 함.
	if not EventBus.bgm_request.is_connected(Callable(BgmPlayer, "_on_bgm_request")):
		_fail("BgmPlayer가 bgm_request에 미구독 — boot 'menu' emit 유실 위험 (autoload 순서)")
		return

	_orig_path = SaveData._save_path
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(TEST_PATH)

	var main: Node = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var sf = main.get_node("SceneFlow")

	# boot → TITLE → "menu" emit.
	if sf.current_screen != sf.ScreenState.TITLE:
		return _fail("boot이 TITLE 아님 (%d)" % sf.current_screen)
	var boot_expected: Array[StringName] = [&"menu"]
	if _emits != boot_expected:
		return _fail("boot emit 시퀀스 기대 [menu], 실제 %s" % str(_emits))

	# (10-b) BgmPlayer 핸들러가 boot emit을 실제로 받음(구독 입증).
	if BgmPlayer.last_requested != &"menu":
		return _fail("boot 후 BgmPlayer.last_requested='%s' (기대 menu) — 구독 타이밍 결함" % BgmPlayer.last_requested)

	# (11) 무음 경계 — 빈 _streams이므로 graceful, 재생 0.
	if not BgmPlayer._streams.is_empty():
		return _fail("(11) Phase 23인데 _streams 비어있지 않음 — 무음 경계 위반")
	if BgmPlayer.current_track != &"":
		return _fail("(11) 무음인데 current_track='%s' (기대 빈값)" % BgmPlayer.current_track)
	if BgmPlayer.play_generation != 0:
		return _fail("(11) 무음인데 play_generation=%d (기대 0)" % BgmPlayer.play_generation)

	# (12) 실전이 매핑/순서 — 메뉴 3종 → menu, load_stage(published) → gameplay.
	EventBus.request_main_menu.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.MAIN_MENU:
		return _fail("MAIN_MENU 전이 실패 (%d)" % sf.current_screen)

	EventBus.request_stage_select.emit()
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE_SELECT:
		return _fail("STAGE_SELECT 전이 실패 (%d)" % sf.current_screen)

	EventBus.request_play_stage.emit(1)
	await get_tree().process_frame
	await get_tree().process_frame
	if sf.current_screen != sf.ScreenState.STAGE:
		return _fail("STAGE 전이 실패 (%d)" % sf.current_screen)

	var expected: Array[StringName] = [&"menu", &"menu", &"menu", &"gameplay"]
	if _emits != expected:
		return _fail("emit 시퀀스 기대 %s, 실제 %s" % [str(expected), str(_emits)])
	print("[BgmSceneFlowTest] emit 시퀀스 OK: %s" % str(_emits))

	main.queue_free()
	await get_tree().process_frame
	SaveData._test_cleanup_files(TEST_PATH)
	SaveData._test_reset(_orig_path)
	print("[BgmSceneFlowTest] PASS")
	get_tree().quit(0)


func _collect(track: StringName) -> void:
	_emits.append(track)


func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	SaveData._test_cleanup_files(TEST_PATH)
	if _orig_path != "":
		SaveData._test_reset(_orig_path)
	print("[BgmSceneFlowTest] FAIL ", msg)
	get_tree().quit(1)
