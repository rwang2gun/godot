extends Node

# Phase 4 (intro-card-infra) — SceneFlow 인트로 카드 게이트 통합. Main.tscn 경유.
#   Case A (헤드리스 기본): load_stage → 카드 스킵 → 즉시 begin(스폰 시작). 기존 회귀 보존의 핵심.
#   Case B (_test_force_intro): 카드 표시 → begin 게이트(스폰 보류) → dismiss → begin(스폰 시작).

const MainScene := preload("res://scenes/Main.tscn")

var _failed: bool = false

func _ready() -> void:
	Engine.time_scale = 12.0
	await _case_headless_skip()
	if _failed: return
	await _case_force_intro_gate()
	if _failed: return
	Engine.time_scale = 1.0
	print("[StageIntroCardHeadlessSkipTest] PASS")
	get_tree().quit(0)

func _case_headless_skip() -> void:
	var main: Node = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var sf = main.get_node("SceneFlow")
	sf.load_stage(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var card = main.get_node("GlobalUI/StageIntroCard")
	if card.is_showing():
		main.queue_free()
		return _fail("headless-skip: card should NOT show in headless")
	var stage = sf._current_stage_node
	if stage == null or not stage.is_begun():
		main.queue_free()
		return _fail("headless-skip: stage not begun (immediate begin expected)")
	if not await _wait_ants(main, 1):
		main.queue_free()
		return _fail("headless-skip: no ants spawned after skip")
	main.queue_free()
	await get_tree().process_frame

func _case_force_intro_gate() -> void:
	var main: Node = MainScene.instantiate()
	var sf = main.get_node("SceneFlow")
	add_child(main)
	await get_tree().process_frame
	sf._test_force_intro = true
	sf.load_stage(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var card = main.get_node("GlobalUI/StageIntroCard")
	if not card.is_showing():
		main.queue_free()
		return _fail("force-intro: card should show")
	var stage = sf._current_stage_node
	if stage.is_begun():
		main.queue_free()
		return _fail("force-intro: stage begun while card up (gate broken)")
	if _count_ants(main) != 0:
		main.queue_free()
		return _fail("force-intro: ants spawned while card up")
	# codex R1 MEDIUM — 카드 표시 중 pause/step/restart 게이트가 닫혀 있어야 한다(모달 스택 차단).
	if InputRouter != null and not InputRouter.are_pause_actions_blocked():
		main.queue_free()
		return _fail("force-intro: pause actions NOT blocked while card up")
	if get_tree().paused:
		main.queue_free()
		return _fail("force-intro: tree paused while card up")
	var pause_menu = main.get_node_or_null("GlobalUI/PauseMenu")
	if pause_menu != null and pause_menu.visible:
		main.queue_free()
		return _fail("force-intro: PauseMenu visible while card up")
	# "시작" 버튼 → dismiss → begin
	var btn = card.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/StartBtn")
	btn.pressed.emit()
	var waited: float = 0.0
	while waited < 3.0 and not stage.is_begun():
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not stage.is_begun():
		main.queue_free()
		return _fail("force-intro: stage not begun after dismiss")
	# dismiss 후 pause 게이트는 해제되어야 한다(정상 플레이 복귀).
	if InputRouter != null and InputRouter.are_pause_actions_blocked():
		main.queue_free()
		return _fail("force-intro: pause actions still blocked after dismiss")
	if not await _wait_ants(main, 1):
		main.queue_free()
		return _fail("force-intro: no ants after dismiss begin")
	main.queue_free()
	await get_tree().process_frame

func _count_ants(main: Node) -> int:
	var n: int = 0
	for a in get_tree().get_nodes_in_group("ants"):
		if is_instance_valid(a) and main.is_ancestor_of(a):
			n += 1
	return n

func _wait_ants(main: Node, target: int) -> bool:
	var waited: float = 0.0
	while waited < 6.0:
		if _count_ants(main) >= target:
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return false

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	Engine.time_scale = 1.0
	print("[StageIntroCardHeadlessSkipTest] FAIL ", msg)
	get_tree().quit(1)
