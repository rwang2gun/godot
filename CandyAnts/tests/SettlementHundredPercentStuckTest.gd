extends Node

# Phase 15 v2 F1 — stuck-until-timeout contract 회귀 가드.
# SettleStuckTest.tscn(time_limit=12, total_ants=3) 사용.
# 3 ants 모두 DistributorSkill 부여 → 첫 ant 정착 + 나머지 walker가 절벽 fall + 무한 cycle.
# 12초까지: stage_cleared 미발화 + stage_failed("no_more_ants") 미발화.
# 12초 직후: stage_failed("time_out") 정확히 1회 발화.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 15초 (60fps × 900 frame). time_limit=12 + 3초 buffer.

const DEADLINE_FRAMES: int = 900
const PRE_TIMEOUT_DEADLINE_FRAMES: int = 720   # 12초

var _ants: Array[Ant] = []
var _distributor_applied: Dictionary = {}   # InstanceID → true
var _frame_count: int = 0
var _result_emitted: bool = false
var _stage_cleared_count: int = 0
var _stage_failed_results: Array[Dictionary] = []

func _ready() -> void:
	print("[SettlementHundredPercentStuckTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)
	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.stage_failed.connect(_on_stage_failed)

func _on_stage_cleared(result: Dictionary) -> void:
	_stage_cleared_count += 1
	print("[SettlementHundredPercentStuckTest] stage_cleared at frame=%d result=%s" % [_frame_count, result])

func _on_stage_failed(result: Dictionary) -> void:
	_stage_failed_results.append(result)
	print("[SettlementHundredPercentStuckTest] stage_failed at frame=%d result=%s" % [_frame_count, result])

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_ensure_ants()
	_apply_distributor()

	# 12초까지: cleared/no_more_ants 발화 없어야 함.
	if _frame_count <= PRE_TIMEOUT_DEADLINE_FRAMES:
		if _stage_cleared_count > 0:
			_fail("premature stage_cleared at frame=%d (before timeout)" % _frame_count)
			return
		for r in _stage_failed_results:
			if r.get("reason", "") != "time_out":
				_fail("unexpected stage_failed reason=%s before timeout at frame=%d" % [r.get("reason", ""), _frame_count])
				return

	if _frame_count > DEADLINE_FRAMES:
		_evaluate_final()

func _ensure_ants() -> void:
	# 이미 추적 중인 ant는 skip, 새 ant 추가.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if not _ants.has(a):
			_ants.append(a)

func _apply_distributor() -> void:
	for a in _ants:
		if not is_instance_valid(a):
			continue
		var id: int = a.get_instance_id()
		if _distributor_applied.get(id, false):
			continue
		if a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		var skill: DistributorSkill = DistributorSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_distributor_applied[id] = true
		print("[SettlementHundredPercentStuckTest] applied distributor to ant id=%d at frame=%d" % [id, _frame_count])

func _evaluate_final() -> void:
	# DEADLINE 도달 — timeout fail 정확히 1회 발화 + cleared 0회 확인.
	if _stage_cleared_count > 0:
		_fail("stage_cleared fired %d times — expected 0" % _stage_cleared_count)
		return
	var timeout_count: int = 0
	for r in _stage_failed_results:
		if r.get("reason", "") == "time_out":
			timeout_count += 1
		else:
			_fail("unexpected stage_failed reason=%s (expected only time_out)" % r.get("reason", ""))
			return
	if timeout_count != 1:
		_fail("stage_failed(time_out) fired %d times — expected exactly 1" % timeout_count)
		return
	print("[SettlementHundredPercentStuckTest] PASS frame=%d timeout_fired=%d cleared=%d" % [_frame_count, timeout_count, _stage_cleared_count])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SettlementHundredPercentStuckTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
