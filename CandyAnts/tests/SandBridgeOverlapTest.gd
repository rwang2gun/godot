extends Node

# Phase 16 — D8 first-place wins (dynamic↔dynamic) 검증.
# 2 ants 같은 cell에서 sand_mound 동시 적용 → 한 쪽 진행, 다른 쪽 즉시 abort.
# PASS: 60초 내 (1) tile_count >= 1 (2) 두 ant 모두 WorkerState에 영구 stuck 아님 (3) ScoreSystem invariant

const DEADLINE_FRAMES: int = 3600
const TRIGGER_X: float = 330.0

var _ants: Array[Ant] = []
var _applied: bool = false
var _applied_frame: int = 0
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	print("[SandBridgeOverlapTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_complete()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — tile_count=%d states=%s" % [_tile_count(), _states_str()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../OverlapStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain
	_ants.clear()
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null and is_instance_valid(a):
			_ants.append(a)

func _apply_when_ready() -> void:
	if _applied:
		return
	if _ants.size() < 2:
		return
	# 두 ant 모두 Walker + on_floor + 첫 ant.x >= TRIGGER_X 도달 시 진행.
	var a1: Ant = _ants[0]
	var a2: Ant = _ants[1]
	if a1.state_machine == null or a2.state_machine == null:
		return
	if not (a1.state_machine.current_state is WalkerState):
		return
	if not (a2.state_machine.current_state is WalkerState):
		return
	if a1.global_position.x < TRIGGER_X:
		return
	if not a1.is_on_floor() or not a2.is_on_floor():
		return
	# 강제 동일 위치 — D8 race를 결정론적으로 트리거.
	a2.global_position = a1.global_position
	var skill: SandMoundSkill = SandMoundSkill.new()
	if not skill.can_apply(a1) or not skill.can_apply(a2):
		return
	skill.apply(a1)
	skill.apply(a2)
	_applied = true
	_applied_frame = _frame
	print("[SandBridgeOverlapTest] applied to both at frame=%d pos=%s" % [_frame, a1.global_position])

func _check_complete() -> void:
	if not _applied:
		return
	# 5 sand_mound 완료 또는 abort까지 충분한 시간 — 90 frame은 1.5s = 1 ant 5-stack 시간.
	# 두 ant 합 ≤ 2 ants × 90 frame buffer.
	if _frame - _applied_frame < 150:
		return
	var tc: int = _tile_count()
	var worker_stuck: int = 0
	for a in _ants:
		if not is_instance_valid(a):
			continue
		if a.state_machine != null and a.state_machine.current_state is WorkerState:
			worker_stuck += 1
	if tc >= 1 and worker_stuck == 0:
		# ScoreSystem invariant는 ScoreSystem._assert_invariant()가 runtime assert로 검증함.
		# 여기 도달 = invariant 위반 없이 두 ant 모두 worker에서 빠짐.
		_pass()
	# else: keep waiting — 둘 다 worker에서 빠지길 기다림

func _tile_count() -> int:
	if _terrain == null:
		return -1
	return _terrain.tile_count()

func _states_str() -> String:
	var parts: Array[String] = []
	for a in _ants:
		if not is_instance_valid(a) or a.state_machine == null or a.state_machine.current_state == null:
			parts.append("null")
		else:
			parts.append(a.state_machine.current_state.get_class())
	return ",".join(parts)

func _pass() -> void:
	print("[SandBridgeOverlapTest] PASS tile_count=%d states=%s" % [_tile_count(), _states_str()])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SandBridgeOverlapTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
