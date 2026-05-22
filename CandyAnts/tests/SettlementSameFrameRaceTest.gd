extends Node

# Phase 15 v2 F2 — Candy + SettlementMarker 동일 frame 진입 race 가드.
# layout: home(22,22), candy(28,22) + settlement_cell(28,22) 같은 cell.
# 분배자 spawn → walker → cell (28,22) 도달 → Candy.body_entered + SettlementMarker.body_entered
# 동일 frame 발화 가능. SettlementMarker는 await physics_frame 후 has_candy 재검사하므로
# Candy가 먼저 처리되어 has_candy=true 갱신했다면 정착 무시.
#
# 본 테스트는 carrying priority(D8)도 동시 cover — 분배자가 has_candy=true인 상태에서
# settlement marker enter 시 정착 무시.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초 (1800 frame).

const DEADLINE_FRAMES: int = 1800

var _ant: Ant = null
var _distributor_applied: bool = false
var _settle_marker: SettlementMarker = null
var _frame_count: int = 0
var _result_emitted: bool = false
var _saw_carrying: bool = false

func _ready() -> void:
	print("[SettlementSameFrameRaceTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_ensure_marker()
	_ensure_ant()
	_apply_distributor()
	_observe()

	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — saw_carrying=%s marker_distributor=%s" % [str(_saw_carrying), str(_settle_marker._distributor if _settle_marker != null else null)])

func _ensure_marker() -> void:
	if _settle_marker != null:
		return
	_settle_marker = _find_marker(get_tree().get_root())

func _find_marker(node: Node) -> SettlementMarker:
	if node is SettlementMarker:
		return node as SettlementMarker
	for c in node.get_children():
		var m: SettlementMarker = _find_marker(c)
		if m != null:
			return m
	return null

func _ensure_ant() -> void:
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null:
			continue
		_ant = a
		return

func _apply_distributor() -> void:
	if _distributor_applied or _ant == null:
		return
	if _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	var skill: DistributorSkill = DistributorSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_distributor_applied = true
	print("[SettlementSameFrameRaceTest] applied distributor at frame=%d" % _frame_count)

func _observe() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state
	# 분배자가 SettledState 진입했다면 carrying priority 실패 (D8 위반).
	if s is SettledState:
		_fail("ant entered SettledState — carrying priority violated (D8)")
		return
	# Carrying 진입 확인 — candy 픽업 성공.
	if s is CarryingState and _ant.has_candy:
		_saw_carrying = true
	# Carrying 후 settlement marker가 _distributor 점유 안 했는지 확인.
	if _saw_carrying:
		if _settle_marker == null:
			_fail("SettlementMarker missing during evaluation")
			return
		if _settle_marker._distributor != null:
			_fail("SettlementMarker._distributor set during carrying — race violation")
			return
		# Carrying 상태에서 5 frame 안정 확인 (settle 안 됨 + has_candy 유지).
		# 충분히 진행한 시점(carrying 진입 후 60 frame = 1초)에서 PASS 판정.
		if _frame_count > 0:
			_check_stable_carrying()

var _carrying_stable_frames: int = 0
func _check_stable_carrying() -> void:
	if _ant == null or _ant.state_machine == null:
		return
	# CarryingState 또는 WalkerState(귀환 중) 유지 + has_candy=true 또는 Carrying 후 home 도착하면 saved.
	# 본 테스트는 carrying 진입 직후 settlement 무시 확인이 목적 — 60 frame 안정 시 PASS.
	var s: AntState = _ant.state_machine.current_state
	if s is CarryingState or s is WalkerState:
		_carrying_stable_frames += 1
	else:
		# Faller 등 다른 상태로 빠지면 카운터 reset (절벽 fall 등 — race layout은 평지라 발생 안함).
		_carrying_stable_frames = 0
	if _carrying_stable_frames >= 60:
		print("[SettlementSameFrameRaceTest] PASS frame=%d saw_carrying=true marker_distributor=null stable=%d" % [_frame_count, _carrying_stable_frames])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SettlementSameFrameRaceTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
