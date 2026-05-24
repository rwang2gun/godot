extends Node

# Phase 16 v6 (v7 범위 축소) — bridge tile 1개 이상 배치 후 강제 lift → mid-work abort 검증.
# PASS: 30초 내 (1) lift 시점 tile_count_at_lift 캡쳐 → 5 frame 후 tile_count == tile_count_at_lift (가드 후 추가 0건)
#                (2) ant state != WorkerState
#                (3) ScoreSystem invariant 유지

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 330.0
const POST_APPLY_WAIT_FRAMES: int = 20   # apply 후 0.33s, BRIDGE_TICK=0.20 × 1+ tile 배치 보장
const POST_LIFT_MONITOR_FRAMES: int = 5

var _ant: Ant = null
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null
var _applied_frame: int = -1
var _lifted_frame: int = -1
var _tile_count_at_lift: int = -1

func _ready() -> void:
	print("[BridgeFallAbortTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	if _applied_frame < 0:
		_try_apply()
	elif _lifted_frame < 0:
		_try_lift()
	else:
		_monitor_after_lift()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — applied=%d lifted=%d tile_count=%d" % [_applied_frame, _lifted_frame, _tile_count()])

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

func _try_apply() -> void:
	if _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	var skill: BridgeSkill = BridgeSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied_frame = _frame
	print("[BridgeFallAbortTest] applied bridge at frame=%d pos=%s" % [_frame, _ant.global_position])

func _try_lift() -> void:
	# Wait POST_APPLY_WAIT_FRAMES then verify >= 1 tile placed and lift.
	if _frame - _applied_frame < POST_APPLY_WAIT_FRAMES:
		return
	var tc: int = _tile_count()
	if tc < 1:
		_fail("after %d frames, no tile placed — bridge stuck (tile_count=%d)" % [POST_APPLY_WAIT_FRAMES, tc])
		return
	_tile_count_at_lift = tc
	_ant.global_position.y -= 200.0
	_lifted_frame = _frame
	print("[BridgeFallAbortTest] lifted at frame=%d tile_count_at_lift=%d" % [_frame, tc])

func _monitor_after_lift() -> void:
	# tile_count must not grow.
	var tc: int = _tile_count()
	if tc > _tile_count_at_lift:
		_fail("tile_count=%d after lift (>%d at_lift) — mid-work guard did not fire" % [tc, _tile_count_at_lift])
		return
	if _frame - _lifted_frame < POST_LIFT_MONITOR_FRAMES:
		return
	if _ant == null or _ant.state_machine == null:
		_fail("ant gone after lift")
		return
	var s: AntState = _ant.state_machine.current_state
	if s is WorkerState:
		_fail("ant still in WorkerState %d frames after lift — abort not triggered" % POST_LIFT_MONITOR_FRAMES)
		return
	# ScoreSystem invariant는 ScoreSystem._assert_invariant()가 runtime assert로 검증함.
	print("[BridgeFallAbortTest] PASS tile_count_at_lift=%d final=%d state=%s" % [_tile_count_at_lift, tc, _state_name()])
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
	print("[BridgeFallAbortTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
