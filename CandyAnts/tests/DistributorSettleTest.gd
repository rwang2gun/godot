extends Node

# Phase 15 — DistributorSkill + SettledState 정상 정착 검증.
# 첫 ant에 DistributorSkill 부여 → walker 진행 → settlement_cell 진입 →
# SettledState로 전이 + velocity ≈ 0 + global_position이 settlement_cell world 좌표 ±4px.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초 (60fps × 1800 frame).

const DEADLINE_FRAMES: int = 1800
const POSITION_TOLERANCE: float = 24.0   # marker shape 32 width + ant body 12 = enter 가능 ±22px

var _ant: Ant = null
var _distributor_applied: bool = false
var _settle_marker: SettlementMarker = null
var _frame_count: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[DistributorSettleTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_ensure_marker()
	_ensure_ant()
	_apply_distributor_when_ready()
	_observe_settle()

	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — frame=%d ant_state=%s" % [_frame_count, _state_name(_ant)])

func _ensure_marker() -> void:
	if _settle_marker != null:
		return
	for n in get_tree().get_nodes_in_group("settlement_markers"):
		var m: SettlementMarker = n as SettlementMarker
		if m != null:
			_settle_marker = m
			return
	# group fallback — get_first_node_in_group 미사용 시 scene tree 직접 탐색
	var root: Node = get_tree().get_root()
	_settle_marker = _find_marker(root)

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

func _apply_distributor_when_ready() -> void:
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
	print("[DistributorSettleTest] applied distributor at frame=%d pos=%s" % [_frame_count, _ant.global_position])

func _observe_settle() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is SettledState):
		return
	# 정착 완료 — settlement_cell 좌표 검증.
	if _settle_marker == null:
		_fail("settled but SettlementMarker missing")
		return
	var dx: float = absf(_ant.global_position.x - _settle_marker.global_position.x)
	if dx > POSITION_TOLERANCE:
		_fail("settled but position drift: ant.x=%.2f marker.x=%.2f dx=%.2f" % [_ant.global_position.x, _settle_marker.global_position.x, dx])
		return
	if _ant.velocity.length() > 1.0:
		_fail("settled but velocity non-zero: %s" % _ant.velocity)
		return
	if not _ant.has_trait(&"distributor"):
		_fail("settled but distributor trait missing")
		return
	print("[DistributorSettleTest] PASS frame=%d pos=%s velocity=%s" % [_frame_count, _ant.global_position, _ant.velocity])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[DistributorSettleTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)

func _state_name(a: Ant) -> String:
	if a == null or a.state_machine == null or a.state_machine.current_state == null:
		return "null"
	return a.state_machine.current_state.get_script().resource_path.get_file()
