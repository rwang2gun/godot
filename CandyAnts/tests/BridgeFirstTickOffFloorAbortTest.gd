extends Node

# Phase 16 v7 — R3-H1 회귀 가드. Bridge 첫 placement tick 전 off-floor → 1-frame grace → 그래도 off-floor → abort.
# tile_count는 절대 증가하면 안 됨 (placement skip 검증).
#
# Sequence (8-step, R4-M1 명세):
# (1) walker ant + on_floor 대기
# (2) BridgeSkill.can_apply == true assert
# (3) BridgeSkill.apply
# (4) immediately ant.state_machine.current_state is WorkerState assert (fixture 정상)
# (5) capture tile_count_before_lift (== 0 기대)
# (6) ant.global_position.y -= 200.0
# (7) frame 1: _update_bridge → off_floor + grace not used → return. tile_count == 0 검증
# (8) frame 2+: 여전히 off_floor → _aborted=true → state 전이. tile_count == 0 검증

const DEADLINE_FRAMES: int = 1500
const TRIGGER_X: float = 330.0
const POST_LIFT_MONITOR_FRAMES: int = 5

var _ant: Ant = null
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null
var _lifted_frame: int = -1
var _tile_count_before_lift: int = -1

func _ready() -> void:
	print("[BridgeFirstTickOffFloorAbortTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	if _lifted_frame < 0:
		_try_apply_and_lift()
	else:
		_monitor_after_lift()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — lifted_frame=%d tile_count=%d" % [_lifted_frame, _tile_count()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../BridgeStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_ant = a
			return

func _try_apply_and_lift() -> void:
	if _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	# (2) can_apply assert
	var skill: BridgeSkill = BridgeSkill.new()
	if not skill.can_apply(_ant):
		_fail("can_apply == false at expected trigger point — fixture mismatch")
		return
	# (3) apply
	skill.apply(_ant)
	# (4) WorkerState assert (fixture sanity)
	if not (_ant.state_machine.current_state is WorkerState):
		_fail("post-apply state is %s — expected WorkerState (hollow test)" % _state_name())
		return
	# (5) capture tile_count
	_tile_count_before_lift = _tile_count()
	if _tile_count_before_lift != 0:
		_fail("tile_count_before_lift=%d expected 0 — bridge placed tiles before lift" % _tile_count_before_lift)
		return
	# (6) lift
	_ant.global_position.y -= 200.0
	_lifted_frame = _frame
	print("[BridgeFirstTickOffFloorAbortTest] applied+lifted at frame=%d pos=%s" % [_frame, _ant.global_position])

func _monitor_after_lift() -> void:
	# Continuously verify tile_count == 0 and watch for state transition out of WorkerState.
	var tc: int = _tile_count()
	if tc != 0:
		_fail("tile_count=%d after lift (frame=%d, lift_frame=%d) — grace/abort did not prevent placement" % [tc, _frame, _lifted_frame])
		return
	# Wait POST_LIFT_MONITOR_FRAMES frames after lift, then check state transitioned out of WorkerState.
	if _frame - _lifted_frame < POST_LIFT_MONITOR_FRAMES:
		return
	if _ant == null or _ant.state_machine == null:
		_fail("ant gone after lift")
		return
	var s: AntState = _ant.state_machine.current_state
	if s is WorkerState:
		# Still WorkerState 5 frames after lift = abort never fired.
		_fail("ant still in WorkerState %d frames after lift — abort not triggered" % POST_LIFT_MONITOR_FRAMES)
		return
	# ScoreSystem invariant는 ScoreSystem._assert_invariant()가 runtime assert로 검증함.
	print("[BridgeFirstTickOffFloorAbortTest] PASS tile_count=0 state=%s frames_post_lift=%d" % [_state_name(), _frame - _lifted_frame])
	_result_emitted = true
	get_tree().quit(0)

func _tile_count() -> int:
	if _terrain == null:
		return -1
	return _terrain.tile_count()

func _state_name() -> String:
	if _ant == null or _ant.state_machine == null or _ant.state_machine.current_state == null:
		return "null"
	return _ant.state_machine.current_state.get_class()

func _fail(msg: String) -> void:
	print("[BridgeFirstTickOffFloorAbortTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
