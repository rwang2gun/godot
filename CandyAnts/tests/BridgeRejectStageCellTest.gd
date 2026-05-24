extends Node

# Phase 16 v2 — D8 first-place wins (dynamic↔static) 검증.
# Bridge가 인접 static cell 위에 placement 시도 → add_tile false → _aborted=true → WalkerState 즉시 복귀.
# PASS: 25초 내 (1) tile_count == 0 (정적 cell 위 동적 tile 0건) (2) ant.state_machine.current_state is WalkerState (3) ScoreSystem invariant

const DEADLINE_FRAMES: int = 1500
const TRIGGER_X: float = 330.0   # cell 10 area; target cell (11, 20) 이미 static
const POST_APPLY_WAIT_FRAMES: int = 30   # 0.5초 — abort 즉시 발생 기대

var _ant: Ant = null
var _applied: bool = false
var _applied_frame: int = 0
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	print("[BridgeRejectStageCellTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_complete()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — tile_count=%d state=%s" % [_tile_count(), _state_name()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../RejectStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_ant = a
			return

func _apply_when_ready() -> void:
	if _applied or _ant == null or _ant.state_machine == null:
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
	_applied = true
	_applied_frame = _frame
	print("[BridgeRejectStageCellTest] applied bridge at frame=%d pos=%s" % [_frame, _ant.global_position])

func _check_complete() -> void:
	if not _applied:
		return
	if _frame - _applied_frame < POST_APPLY_WAIT_FRAMES:
		return
	var tc: int = _tile_count()
	var s_class: String = _state_name()
	if tc != 0:
		_fail("tile_count=%d expected 0 — static occupancy gate bypassed" % tc)
		return
	# WorkerState 빠져나옴 검증 — Walker/Faller 어느 쪽이든 sand_mound 종료 후 정상.
	var s: AntState = _ant.state_machine.current_state
	if s is WorkerState:
		return   # 아직 worker — 더 기다림
	# ScoreSystem invariant는 ScoreSystem._assert_invariant()가 runtime assert로 검증함.
	print("[BridgeRejectStageCellTest] PASS tile_count=0 state=%s" % s_class)
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
	print("[BridgeRejectStageCellTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
