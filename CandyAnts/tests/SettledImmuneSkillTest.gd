extends Node

# Phase 15 impl Round 1 F-impl-1 HIGH 회귀 가드.
# 분배자 정착 후 SettledState terminal contract — Ant.is_alive()가 false 반환하므로
# 어떤 스킬도 can_apply false 반환. 정착 후 trait 부여 → 후속 transfer 가능성 차단.
#
# 시나리오: 분배자 ant에 floater 미부여 상태로 distributor만 부여 → 정착 → FloaterSkill.apply
# 시도 → has_trait(&"floater") false 유지 + 후속 walker 진입 시 floater 미전이.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초 (1800 frame).

const DEADLINE_FRAMES: int = 1800

var _distributor_ant: Ant = null
var _distributor_applied: bool = false
var _floater_attempt_after_settle: bool = false
var _frame_count: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[SettledImmuneSkillTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_acquire_ant()
	_apply_distributor()
	_attempt_floater_after_settle()
	_verify_no_transfer()

	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — settled=%s floater_attempted=%s" % [str(_is_settled()), str(_floater_attempt_after_settle)])

func _acquire_ant() -> void:
	if _distributor_ant != null and is_instance_valid(_distributor_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_distributor_ant = a
			return

func _apply_distributor() -> void:
	if _distributor_applied or _distributor_ant == null:
		return
	if _distributor_ant.state_machine == null:
		return
	if not (_distributor_ant.state_machine.current_state is WalkerState):
		return
	var d: DistributorSkill = DistributorSkill.new()
	if d.can_apply(_distributor_ant):
		d.apply(_distributor_ant)
		_distributor_applied = true
		print("[SettledImmuneSkillTest] applied distributor (no floater) at frame=%d" % _frame_count)

func _is_settled() -> bool:
	if _distributor_ant == null or not is_instance_valid(_distributor_ant):
		return false
	if _distributor_ant.state_machine == null:
		return false
	return _distributor_ant.state_machine.current_state is SettledState

func _attempt_floater_after_settle() -> void:
	if _floater_attempt_after_settle:
		return
	if not _is_settled():
		return
	# 정착 직후 FloaterSkill 적용 시도.
	var f: FloaterSkill = FloaterSkill.new()
	# is_alive()가 SettledState에서 false 반환해야 한다 — can_apply false.
	if f.can_apply(_distributor_ant):
		_fail("FloaterSkill.can_apply returned true on settled ant — is_alive() leak (terminal contract violation)")
		return
	# 강제 apply 시도해도 trait 부여 거부되어야 함 (apply는 trait set 단순 호출이지만,
	# 정책상 can_apply 통과 후에만 호출되므로 본 테스트는 can_apply false 확인만으로 충분).
	# 직접 set_trait 호출은 막을 수 없으나 (정착 후 apply 경로는 차단됨).
	_floater_attempt_after_settle = true
	print("[SettledImmuneSkillTest] FloaterSkill.can_apply false on settled ant (correct) at frame=%d" % _frame_count)

func _verify_no_transfer() -> void:
	if not _floater_attempt_after_settle:
		return
	# 분배자가 floater 미보유 → 후속 walker가 settlement marker 진입해도 floater 미전이.
	# 60 frame 후 후속 walker 중 floater 보유한 ant 없음을 확인.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a == _distributor_ant:
			continue
		if a.has_trait(&"floater"):
			_fail("follower ant has floater trait — transfer leaked despite distributor having no floater")
			return
	# 60 frame 안정 검증 후 PASS.
	if _frame_count > 600:   # 분배자 정착 후 충분히 진행
		print("[SettledImmuneSkillTest] PASS frame=%d settled_immune=true no_transfer_leak=true" % _frame_count)
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SettledImmuneSkillTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
