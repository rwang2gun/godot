extends Node

# Phase 15 — 능력 전이 검증. 분배자가 floater 트레잇 보유 + 정착 → 후속 walker가
# SettlementMarker 진입 → has_trait(&"floater") true.
# 후속 walker의 faller gravity scale은 phase 14 FloaterTraitTest이 별도 검증 — 본 테스트는
# 전이 자체 + 화이트리스트 정책(distributor trait는 미전이 확인) 검증.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초 (1800 frame).

const DEADLINE_FRAMES: int = 1800

var _distributor_ant: Ant = null
var _distributor_applied: bool = false
var _floater_applied: bool = false
var _frame_count: int = 0
var _result_emitted: bool = false
var _transfer_verified: bool = false

func _ready() -> void:
	print("[SettlementTraitTransferTest] driver ready")

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
	if _distributor_ant != null and is_instance_valid(_distributor_ant):
		return
	# 첫 번째 ant를 distributor로 지정.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_distributor_ant = a
			return

func _apply_skills() -> void:
	if _distributor_ant == null or not is_instance_valid(_distributor_ant):
		return
	if _distributor_ant.state_machine == null:
		return
	if not (_distributor_ant.state_machine.current_state is WalkerState):
		return
	if not _distributor_applied:
		var d: DistributorSkill = DistributorSkill.new()
		if d.can_apply(_distributor_ant):
			d.apply(_distributor_ant)
			_distributor_applied = true
			print("[SettlementTraitTransferTest] applied distributor at frame=%d" % _frame_count)
	if not _floater_applied:
		var f: FloaterSkill = FloaterSkill.new()
		if f.can_apply(_distributor_ant):
			f.apply(_distributor_ant)
			_floater_applied = true
			print("[SettlementTraitTransferTest] applied floater at frame=%d" % _frame_count)

func _is_settled() -> bool:
	if _distributor_ant == null or not is_instance_valid(_distributor_ant):
		return false
	if _distributor_ant.state_machine == null:
		return false
	return _distributor_ant.state_machine.current_state is SettledState

func _observe_transfer() -> void:
	if _transfer_verified:
		return
	if not _is_settled():
		return
	# 분배자 정착 완료. 후속 walker 중 has_trait(&"floater")가 true인 ant 검색.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a == _distributor_ant:
			continue
		if a.has_trait(&"floater"):
			# 화이트리스트 정책 확인 — distributor trait는 미전이.
			if a.has_trait(&"distributor"):
				_fail("transferred distributor trait — whitelist violation (only floater allowed)")
				return
			print("[SettlementTraitTransferTest] PASS frame=%d receiver=%d has_floater=true has_distributor=false" % [_frame_count, a.get_instance_id()])
			_transfer_verified = true
			_result_emitted = true
			get_tree().quit(0)
			return

func _fail(msg: String) -> void:
	print("[SettlementTraitTransferTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
