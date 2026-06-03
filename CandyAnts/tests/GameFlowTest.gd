extends Node

# Phase 6 통합 회귀 테스트.
# 시나리오 A: Stage01 자연 clear → Next → Stage02 도달 (+ Result Dictionary 8키 검증, freeze/unfreeze)
# 시나리오 B: SceneFlow.load_stage(5) → Stage05 clear(sand_mound 사다리+floater) → Next 비활성(last) + 강제 emit 시 go_to_menu fallback
# 시나리오 C: load_stage(1) → 강제 fail(no_more_ants) → Next 차단(disabled + signal reject) → Replay → stage1 reload
# 시나리오 D: A에서 freeze/unfreeze 인라인 확인.
# PASS: get_tree().quit(0). FAIL: 즉시 print + quit(1).

const SCENARIO_TIMEOUT_SECONDS: float = 90.0  # stage1 자연 clear는 spawn-cycle 동안 ant 10마리가 candy→home 왕복하므로 여유 필요
# S5 "막대과자 탑"(sand_mound 수직 사다리) — 첫 ant가 플랫폼(cols13~19) 아래 cols14~17(x∈[672,864))에 있을 때
# sand_mound 적용 → rung 기둥 + 레지 cap으로 플랫폼 등반. 사다리는 영구라 후속 ant는 LadderClimbState로 자동 등반.
const STAGE5_CAST_X_MIN: float = 672.0
const STAGE5_CAST_X_MAX: float = 864.0

var _main: Node = null
var _scene_flow: Node = null  # SceneFlow — class_name이 first-import에서 미인식되어 Node로 typed
var _current_stage_root: Node = null
var _overlay: Control = null  # StageDialog (phase 12: 구 StageResultOverlayStub 교체, 동일 API contract)

var _failed: bool = false
var _stage5_cast_applied: bool = false  # Scenario B — sand_mound 1회 시전 가드.

func _process(_delta: float) -> void:
	if _failed:
		return
	_apply_climber_if_ready()
	_apply_stage5_skills_if_ready()

func _apply_climber_if_ready() -> void:
	if _scene_flow == null or _scene_flow._current_stage_id != 1:
		return
	var runner: StageRunner = _find_current_stage_runner()
	if runner == null or runner._completed:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.direction != 1:
			continue
		if a.has_been_carrying:
			continue
		if a.has_trait(&"climber"):
			continue
		# stage01 재설계("첫 마실") — 분지 바닥(row11, y≈520)에서 x=336~528(분지 cols 7~10)인 개미에게 Climber 적용.
		# 부여 후 우측 col11 1칸 벽을 등반해 사탕으로, 귀가 시 같은 trait로 좌측 벽도 등반(영구 보유).
		if a.global_position.y > 490.0 and a.global_position.y < 560.0 and a.global_position.x >= 336.0 and a.global_position.x < 528.0:
			var climber: ClimberSkill = ClimberSkill.new()
			if not climber.can_apply(a):
				continue
			climber.apply(a)
			print("[GameFlowTest] applied Climber to ", a.name, " at x=", a.global_position.x)

# S5 "막대과자 탑" 드라이버 — Scenario B. 무리 전체에 floater 부여(안전 하강) + 첫 ant에 sand_mound 1회
# (플랫폼 아래 cols14~17). 사다리는 영구라 후속 ant는 LadderClimbState로 자동 등반 → candy 회수 → clear.
func _apply_stage5_skills_if_ready() -> void:
	if _scene_flow == null or _scene_flow._current_stage_id != 5:
		return
	var runner: StageRunner = _find_current_stage_runner()
	if runner == null or runner._completed:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		# 낙하산을 무리 전체에 분배 — 등반/시전에 무해, 하강 시에만 작동.
		if not a.has_trait(&"floater"):
			var floater: FloaterSkill = FloaterSkill.new()
			if floater.can_apply(a):
				floater.apply(a)
		# 첫 ant 1마리만 사다리 건설(플랫폼 아래 cols14~17, x∈[672,864)). 이후는 자동 등반.
		if not _stage5_cast_applied and a.direction == 1 and not a.has_been_carrying \
				and a.global_position.x >= STAGE5_CAST_X_MIN and a.global_position.x < STAGE5_CAST_X_MAX:
			var sm: SandMoundSkill = SandMoundSkill.new()
			if sm.can_apply(a):
				sm.apply(a)
				_stage5_cast_applied = true
				print("[GameFlowTest] B applied SandMound at x=", a.global_position.x)

func _ready() -> void:
	# 헤드리스 wall clock 단축. 자연 진행은 유지하되 모든 시뮬을 8배 가속해
	# scenario A의 stage1 자연 cleared 대기 시간을 줄임.
	Engine.time_scale = 8.0
	print("[GameFlowTest] driver ready, time_scale=", Engine.time_scale)
	_main = $Main
	_scene_flow = _main.get_node("SceneFlow")
	_current_stage_root = _main.get_node("CurrentStageRoot")
	_overlay = _main.get_node("GlobalUI/StageDialog") as Control
	if _scene_flow == null or _current_stage_root == null or _overlay == null:
		_fail("missing nodes in Main")
		return
	await get_tree().process_frame  # SceneFlow._ready() / _boot() 완료 대기
	# Phase 13 Δ10: 기본 부트는 TITLE → load_stage(1)로 우회. boot_to_stage_id export는
	# SceneFlowBootBypassTest 전용 (add_child 전 설정 필요해서 본 테스트에서는 사용 X).
	if _scene_flow.current_screen != _scene_flow.ScreenState.STAGE:
		_scene_flow.load_stage(1)
		await get_tree().process_frame  # remove_child + queue_free
		await get_tree().process_frame  # Stage01 instantiation + StageRunner._ready
	await _run_scenarios()
	if not _failed:
		print("[GameFlowTest] PASS")
		get_tree().quit(0)

func _run_scenarios() -> void:
	await _scenario_a()
	if _failed: return
	await _scenario_b()
	if _failed: return
	await _scenario_c()

# -----------------------------------------------------------------------------
# 시나리오 A: Stage01 자연 clear → Next → Stage02 도달
# -----------------------------------------------------------------------------
func _scenario_a() -> void:
	print("[GameFlowTest] === Scenario A: Stage01 → clear → Next → Stage02 ===")
	# Stage01은 SceneFlow._ready에서 자동 로드됨
	if not _verify_current_stage_id(1, "A.start"):
		return

	var result: Dictionary = await _await_signal(EventBus.stage_cleared)
	if _failed: return
	if not _verify_result_dict(result, "A.cleared"):
		return
	if result["stage_id"] != 1 or not result["cleared"]:
		_fail("A.cleared expected stage_id=1 cleared=true got %s" % str(result))
		return

	# 시나리오 D 인라인: freeze 확인
	if _current_stage_root.process_mode != Node.PROCESS_MODE_DISABLED:
		_fail("A.freeze process_mode != DISABLED, got %d" % _current_stage_root.process_mode)
		return
	print("[GameFlowTest] A freeze OK")

	EventBus.request_next.emit()
	await get_tree().process_frame
	await get_tree().process_frame  # queue_free + add_child 정리

	# 시나리오 D 인라인: unfreeze 확인
	if _current_stage_root.process_mode != Node.PROCESS_MODE_INHERIT:
		_fail("A.unfreeze process_mode != INHERIT, got %d" % _current_stage_root.process_mode)
		return
	print("[GameFlowTest] A unfreeze OK")

	if not _verify_current_stage_id(2, "A.advance"):
		return
	print("[GameFlowTest] Scenario A PASS")

# -----------------------------------------------------------------------------
# 시나리오 B: load_stage(3) → clear → Next disabled → 강제 emit → go_to_menu fallback
# -----------------------------------------------------------------------------
func _scenario_b() -> void:
	print("[GameFlowTest] === Scenario B: Stage05 → clear → Next disabled → menu fallback ===")
	_stage5_cast_applied = false
	_scene_flow.load_stage(5)
	await get_tree().process_frame
	await get_tree().process_frame  # stage instantiation + StageRunner._ready
	if not _verify_current_stage_id(5, "B.start"):
		return

	# S5 "막대과자 탑": _apply_stage5_skills_if_ready(_process)가 무리에 floater 분배 + 첫 ant에 sand_mound 1회.
	# rung 기둥 영구 → 후속 ant는 LadderClimbState로 자동 등반 → candy 회수 → floater 안전 하강 → clear.
	# (구 Stage04 builder@last-stage 폐기 — LAST_STAGE_ID=5라 S5가 새 마지막 스테이지.)
	var result: Dictionary = await _await_signal(EventBus.stage_cleared)
	if _failed: return
	if result["stage_id"] != 5 or not result["cleared"]:
		_fail("B.cleared expected stage_id=5 cleared=true got %s" % str(result))
		return

	# Phase 12: Scenario B = Stage05 cleared + last-stage → visible=true + disabled=true (회색).
	# is_next_visible/is_next_disabled 두 inspector를 모두 assert (plan v6.1 §3.9, SH-1 가드).
	if not _overlay.is_next_visible():
		_fail("B.last_stage NextButton not visible (expected visible=true for last+cleared)")
		return
	if not _overlay.is_next_disabled():
		_fail("B.last_stage NextButton not disabled (expected disabled=true for last+cleared)")
		return
	print("[GameFlowTest] B NextButton visible+disabled OK")

	# Phase 13: last-stage Next emit → load_next_stage(next_id=6 미존재) → go_to_main_menu
	# (phase 6의 stage1 fallback 폐기, plan §3.5.4).
	EventBus.request_next.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if _scene_flow.current_screen != _scene_flow.ScreenState.MAIN_MENU:
		_fail("B.menu_fallback current_screen != MAIN_MENU, got %d" % _scene_flow.current_screen)
		return
	print("[GameFlowTest] Scenario B PASS (main menu after last-stage clear)")

# -----------------------------------------------------------------------------
# 시나리오 C: stage1 강제 fail → no_more_ants → Next 차단 → Replay
# -----------------------------------------------------------------------------
func _scenario_c() -> void:
	print("[GameFlowTest] === Scenario C: stage1 forced fail → Next blocked → Replay ===")
	# Phase 13: B 끝에 main menu 진입 → 본 시나리오는 stage1을 직접 load.
	_scene_flow.load_stage(1)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _verify_current_stage_id(1, "C.start"):
		return

	var stage_runner: StageRunner = _find_current_stage_runner()
	if stage_runner == null:
		_fail("C stage_runner not found")
		return

	# StageRunner._spawner_finished가 true가 될 때까지 polling.
	# `await spawner.spawn_finished`는 이미 emit된 후면 영영 hang하므로 flag polling.
	var elapsed: float = 0.0
	while not stage_runner._spawner_finished and elapsed < SCENARIO_TIMEOUT_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not stage_runner._spawner_finished:
		_fail("C spawner_finished polling timeout (elapsed=%.1f)" % elapsed)
		return

	# Race 회피: signal callback을 force-fail 시점 *전에* connect. ants가 free되고
	# stage_runner._process가 가드 통과하면 stage_failed가 즉시 emit되므로 connect가
	# 늦으면 signal을 놓친다.
	var received: Array = [false, {}]
	var cb := func(payload: Dictionary) -> void:
		if not received[0]:
			received[0] = true
			received[1] = payload
	EventBus.stage_failed.connect(cb)

	# (a) candy_hp 양수 강제 — `cleared` 가드(candy_hp==0)가 통과하지 않게 차단,
	#     no_more_ants 가드(candy_hp>0)는 충족.
	var candy_node: Candy = stage_runner.get_node(stage_runner.candy_path) as Candy
	if candy_node != null:
		candy_node.hp = 5
	# (b) carrying ant queue_free 시 Ant._exit_tree가 candy_piece_lost를 emit하지 않아
	#     in_transit_pieces가 stuck될 수 있음. lost_pieces로 이동시켜 invariant 유지 +
	#     no_more_ants 가드(in_transit==0) 충족.
	var stuck_in_transit: int = stage_runner.score_system.in_transit_pieces
	stage_runner.score_system.lost_pieces += stuck_in_transit
	stage_runner.score_system.in_transit_pieces = 0
	print("[GameFlowTest] C protected candy.hp=5, moved in_transit=", stuck_in_transit, " to lost")
	# (c) 모든 living ants queue_free → ants==0 가드 충족 (await 2 frames로 정리 보장 — codex plan-review HIGH 대응)
	var freed: int = 0
	for n in get_tree().get_nodes_in_group("ants"):
		if is_instance_valid(n):
			n.queue_free()
			freed += 1
	print("[GameFlowTest] C freed ants=", freed)

	# polling — stage_runner._process가 가드 통과해 stage_failed emit하면 cb가 received 채움
	var fail_elapsed: float = 0.0
	while not received[0] and fail_elapsed < SCENARIO_TIMEOUT_SECONDS:
		await get_tree().process_frame
		fail_elapsed += get_process_delta_time()
	if EventBus.stage_failed.is_connected(cb):
		EventBus.stage_failed.disconnect(cb)
	if not received[0]:
		_fail("C stage_failed timeout (elapsed=%.1f)" % fail_elapsed)
		return
	var result: Dictionary = received[1]
	if _failed: return
	if result["stage_id"] != 1 or result["cleared"] or result["reason"] != "no_more_ants":
		_fail("C.failed expected stage_id=1 cleared=false reason=no_more_ants got %s" % str(result))
		return
	print("[GameFlowTest] C no_more_ants OK")

	# Phase 12: Scenario C = stage1 loss → visible=false (hidden, loss UX).
	# is_next_visible()==false expect (plan v6.1 §3.9, SH-1 가드 — hidden과 disabled를 다른 assertion으로 분리).
	if _overlay.is_next_visible():
		_fail("C.failed NextButton visible (expected visible=false for loss)")
		return
	print("[GameFlowTest] C NextButton hidden (loss) OK")

	# 강제 signal emit — SceneFlow._on_request_next가 cleared 가드로 reject
	EventBus.request_next.emit()
	await get_tree().process_frame
	if _scene_flow._current_stage_id != 1:
		_fail("C.next_blocked _current_stage_id changed to %d (expected 1)" % _scene_flow._current_stage_id)
		return
	# stage instance도 변경 안 됨 — request_next reject 후 같은 stage 유지
	# (단, request_next이 reject되었으므로 새 stage 로드 없음)
	print("[GameFlowTest] C request_next rejected (signal) OK")

	EventBus.request_replay.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _verify_current_stage_id(1, "C.replay"):
		return
	print("[GameFlowTest] Scenario C PASS")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _await_signal(sig: Signal) -> Dictionary:
	var elapsed: float = 0.0
	var received: Array = [false, {}]
	var cb := func(payload: Dictionary) -> void:
		received[0] = true
		received[1] = payload
	sig.connect(cb)
	while not received[0] and elapsed < SCENARIO_TIMEOUT_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	sig.disconnect(cb)
	if not received[0]:
		_fail("await_signal timeout")
		return {}
	return received[1]

func _verify_result_dict(result: Dictionary, label: String) -> bool:
	var required_keys := ["stage_id", "cleared", "saved", "lost", "original_hp", "score", "time_left", "reason"]
	for k in required_keys:
		if not result.has(k):
			_fail("%s missing key %s" % [label, k])
			return false
	if typeof(result["stage_id"]) != TYPE_INT:
		_fail("%s stage_id not int" % label); return false
	if typeof(result["cleared"]) != TYPE_BOOL:
		_fail("%s cleared not bool" % label); return false
	if typeof(result["saved"]) != TYPE_INT:
		_fail("%s saved not int" % label); return false
	if typeof(result["lost"]) != TYPE_INT:
		_fail("%s lost not int" % label); return false
	if typeof(result["original_hp"]) != TYPE_INT:
		_fail("%s original_hp not int" % label); return false
	if typeof(result["score"]) != TYPE_FLOAT:
		_fail("%s score not float" % label); return false
	if typeof(result["time_left"]) != TYPE_FLOAT:
		_fail("%s time_left not float" % label); return false
	if typeof(result["reason"]) != TYPE_STRING:
		_fail("%s reason not String" % label); return false
	return true

func _verify_current_stage_id(expected: int, label: String) -> bool:
	var runner: StageRunner = _find_current_stage_runner()
	if runner == null:
		_fail("%s no StageRunner under CurrentStageRoot" % label)
		return false
	if runner.stage_data == null or runner.stage_data.id != expected:
		var actual: int = -1 if runner.stage_data == null else runner.stage_data.id
		_fail("%s stage_id expected=%d got=%d" % [label, expected, actual])
		return false
	return true

func _find_current_stage_runner() -> StageRunner:
	for child in _current_stage_root.get_children():
		var r: StageRunner = child as StageRunner
		if r != null:
			return r
		# stage scene root가 StageRunner인 경우 자식이 직접 StageRunner
		# stage scene root가 다른 Node여서 StageRunner가 더 깊은 경우 — recursion
		var deep: StageRunner = _find_runner_in(child)
		if deep != null:
			return deep
	return null

func _find_runner_in(node: Node) -> StageRunner:
	for c in node.get_children():
		var r: StageRunner = c as StageRunner
		if r != null:
			return r
		var deep: StageRunner = _find_runner_in(c)
		if deep != null:
			return deep
	return null

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[GameFlowTest] FAIL ", msg)
	get_tree().quit(1)
