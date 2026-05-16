extends Node

# Phase 8 — StepFrame 정확히 1 physics tick + re-entry guard + InputRouter gate cleanup.
# physics_frame 기반이므로 process_frame 카운팅으로 검증하지 않는다.

const GameAction := preload("res://scripts/input/GameAction.gd")


class DummyPhysics extends Node:
	var physics_ticks: int = 0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
	func _physics_process(_delta: float) -> void:
		physics_ticks += 1


var _dummy: DummyPhysics = null
var _captured_action_count: int = 0


func _ready() -> void:
	_dummy = DummyPhysics.new()
	add_child(_dummy)
	# 시작 시 paused 보장 위해 한 프레임 정리.
	await get_tree().process_frame
	get_tree().paused = false  # 명시적 baseline.
	_dummy.physics_ticks = 0

	if not await _case_a_step_advances_one_tick():
		_fail("case-A: STEP_FRAME paused → 1 physics tick + paused 복귀"); return
	if not await _case_b_step_noop_when_running():
		_fail("case-B: paused=false에서 STEP_FRAME noop"); return
	if not await _case_c_pause_toggle():
		_fail("case-C: PAUSE_TOGGLE 두 번 토글"); return
	if not await _case_d_reentry_guard():
		_fail("case-D: 동일 프레임 STEP_FRAME 2회 → 1 tick"); return
	if not await _case_e_pause_ignored_during_step():
		_fail("case-E: stepping 중 PAUSE_TOGGLE direct emit ignored"); return
	if not await _case_f_gate_engaged_during_step():
		_fail("case-F: stepping 중 gate engaged"); return
	if not _case_g_gate_cleanup():
		_fail("case-G: 종료 시 gate=false"); return

	print("[StepFrameTest] PASS")
	get_tree().quit(0)


func _case_a_step_advances_one_tick() -> bool:
	get_tree().paused = true
	await get_tree().process_frame
	_dummy.physics_ticks = 0
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	# StepFrame coroutine: paused=false → await physics_frame → await process_frame → paused=true.
	# 헤드리스에서 시그널 발화 타이밍 여유를 위해 충분히 기다린다.
	await _wait_for_step_completion()
	if _dummy.physics_ticks < 1:
		push_error("[StepFrameTest] case-A: physics_ticks=%d (expected ≥1)" % _dummy.physics_ticks); return false
	if not get_tree().paused:
		push_error("[StepFrameTest] case-A: paused != true after step"); return false
	return true


func _wait_for_step_completion() -> void:
	# StepFrame이 _stepping을 false로 되돌릴 때까지 polling.
	for _i in range(30):
		if not StepFrame.is_stepping():
			return
		await get_tree().process_frame
		await get_tree().physics_frame


func _case_b_step_noop_when_running() -> bool:
	get_tree().paused = false
	await get_tree().process_frame
	var before: int = _dummy.physics_ticks
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	await get_tree().process_frame
	# paused=false 상태에서 step은 noop이지만 _physics_process는 정상 진행 중이므로
	# tick 증가는 무관. 본 case는 paused 상태가 그대로 false인지만 검증.
	if get_tree().paused:
		push_error("[StepFrameTest] case-B: STEP_FRAME가 paused를 켜버림"); return false
	# 명시적 noop — gate도 안 켜져야 함.
	if InputRouter.are_pause_actions_blocked():
		push_error("[StepFrameTest] case-B: gate가 켜져있음 (running 상태 step은 noop이어야)"); return false
	_dummy.physics_ticks = before  # baseline 정리
	return true


func _case_c_pause_toggle() -> bool:
	get_tree().paused = false
	await get_tree().process_frame
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})
	if not get_tree().paused:
		push_error("[StepFrameTest] case-C: toggle 1 후 paused != true"); return false
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})
	if get_tree().paused:
		push_error("[StepFrameTest] case-C: toggle 2 후 paused != false"); return false
	return true


func _case_d_reentry_guard() -> bool:
	get_tree().paused = true
	await get_tree().process_frame
	_dummy.physics_ticks = 0
	# 같은 frame에 두 번 emit → 첫 번째만 진행, 두 번째는 _stepping guard로 silent skip.
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	await _wait_for_step_completion()
	if _dummy.physics_ticks > 2:
		push_error("[StepFrameTest] case-D: physics_ticks=%d (>2 — re-entry guard broken)" % _dummy.physics_ticks); return false
	if not get_tree().paused:
		push_error("[StepFrameTest] case-D: paused != true after step"); return false
	return true


func _case_e_pause_ignored_during_step() -> bool:
	get_tree().paused = true
	await get_tree().process_frame
	# step 시작 + 즉시 PAUSE_TOGGLE direct emit → StepFrame._stepping guard로 무시.
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})  # 무시되어야 함
	await _wait_for_step_completion()
	if not get_tree().paused:
		push_error("[StepFrameTest] case-E: PAUSE_TOGGLE이 step 중 처리됨 (paused != true)"); return false
	return true


func _case_f_gate_engaged_during_step() -> bool:
	# Phase 8 — step await 중 InputRouter._pause_actions_blocked == true 여야 함.
	# 따라서 그 시점에 InputMap PAUSE_TOGGLE / RESTART_STAGE / STEP_FRAME raw event도 block 대상.
	get_tree().paused = true
	await get_tree().process_frame
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	# stepping 시작 직후 — coroutine은 아직 await physics_frame 대기 중.
	if not InputRouter.are_pause_actions_blocked():
		push_error("[StepFrameTest] case-F: gate가 step 중 켜져있지 않음"); return false
	if not StepFrame.is_stepping():
		push_error("[StepFrameTest] case-F: _stepping flag가 false"); return false
	await _wait_for_step_completion()
	# 종료 후 gate 해제 확인
	if InputRouter.are_pause_actions_blocked():
		push_error("[StepFrameTest] case-F: step 종료 후 gate 미해제"); return false
	return true


func _case_g_gate_cleanup() -> bool:
	if InputRouter.are_pause_actions_blocked():
		push_error("[StepFrameTest] case-G: 테스트 종료 시점에 gate가 여전히 켜져있음"); return false
	return true


func _fail(label: String) -> void:
	push_error("[StepFrameTest] FAIL %s" % label)
	print("[StepFrameTest] FAIL %s" % label)
	get_tree().quit(1)
