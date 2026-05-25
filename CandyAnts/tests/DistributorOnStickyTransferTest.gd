extends Node

# Phase 20 — D-5 회귀 가드. 분배자가 sticky 위에서 stuck → SettlementMarker.body_entered 발화 →
# 정착(SettledState) → 후속 walker 진입 시 trait 전이.
# StickySettleTest.tscn 사용 (id=914, sticky + settlement marker 인접 배치).

const DEADLINE_FRAMES: int = 3600   # 60초

var _distributor: Ant = null
var _distributor_skill_applied: bool = false
var _floater_skill_applied: bool = false
var _transfer_verified: bool = false
var _result_emitted: bool = false
var _frame_count: int = 0

func _ready() -> void:
	print("[DistributorOnStickyTransferTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1
	_acquire_distributor()
	_apply_skills()
	_observe_transfer()
	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — settled=%s transfer_verified=%s" % [str(_is_settled()), str(_transfer_verified)])

func _acquire_distributor() -> void:
	if _distributor != null and is_instance_valid(_distributor):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null and is_instance_valid(a):
			_distributor = a
			return

func _apply_skills() -> void:
	if _distributor == null or not is_instance_valid(_distributor):
		return
	if _distributor.state_machine == null:
		return
	if not (_distributor.state_machine.current_state is WalkerState):
		return
	if not _distributor_skill_applied:
		var d: DistributorSkill = DistributorSkill.new()
		if d.can_apply(_distributor):
			d.apply(_distributor)
			_distributor_skill_applied = true
			print("[DistributorOnStickyTransferTest] distributor applied frame=%d" % _frame_count)
	if not _floater_skill_applied:
		var f: FloaterSkill = FloaterSkill.new()
		if f.can_apply(_distributor):
			f.apply(_distributor)
			_floater_skill_applied = true
			print("[DistributorOnStickyTransferTest] floater applied frame=%d" % _frame_count)

func _is_settled() -> bool:
	if _distributor == null or not is_instance_valid(_distributor):
		return false
	if _distributor.state_machine == null:
		return false
	return _distributor.state_machine.current_state is SettledState

func _observe_transfer() -> void:
	if _transfer_verified:
		return
	if not _is_settled():
		return
	# 분배자 정착 완료. 후속 walker가 has_trait(&"floater")로 전이됐는지 확인.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a == _distributor:
			continue
		if a.has_trait(&"floater"):
			print("[DistributorOnStickyTransferTest] PASS frame=%d receiver=%d sticky stuck → settled → transfer OK" % [
				_frame_count, a.get_instance_id(),
			])
			_transfer_verified = true
			_result_emitted = true
			get_tree().quit(0)
			return

func _fail(msg: String) -> void:
	if _result_emitted: return
	print("[DistributorOnStickyTransferTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
