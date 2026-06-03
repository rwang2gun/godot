extends Node

# 2026-06-03 — 낙하산 분배자(in-place) 코어 동작 검증 (Stage02 호스트).
# 새 메커니즘의 still-live 행동을 한 테스트로 커버 (구 정착/분배자 테스트 스위트 은퇴 대체):
#   A) 지면 게이트: FallerState 개미에겐 FloaterSkill.can_apply == false (낙하 중 부여 불가).
#   B) 적용 즉시 정착: 지면 위 walker에 floater 적용 → SettledState 즉시 진입.
#   C) 정착 면역: 정착한 분배자에 재적용 시 can_apply == false (terminal).
#   D) 전이: 분배자 지나가는 다른 walker가 floater 트레잇 획득(분배자 trait는 미전이=화이트리스트).
# PASS: 4항 모두 충족. FAIL: deadline 또는 게이트/면역/전이 위반.

const DEADLINE_FRAMES: int = 16000

var _distributor: Ant = null
var _settle_ok: bool = false
var _idle_ok: bool = false
var _immune_ok: bool = false
var _transfer_ok: bool = false
var _ground_gate_ok: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	print("[FloaterDistributorTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_check_ground_gate()
	_drive_settle()
	_apply_climbers()
	_check_immunity_and_transfer()
	if _settle_ok and _idle_ok and _immune_ok and _transfer_ok and _ground_gate_ok:
		_pass()
		return
	if _frame > DEADLINE_FRAMES:
		_fail("deadline gate=%s settle=%s idle=%s immune=%s transfer=%s" % [
			str(_ground_gate_ok), str(_settle_ok), str(_idle_ok), str(_immune_ok), str(_transfer_ok)])

func _check_ground_gate() -> void:
	if _ground_gate_ok:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a == _distributor:
			continue
		if a.state_machine.current_state is FallerState:
			var f: FloaterSkill = FloaterSkill.new()
			if f.can_apply(a):
				_fail("ground gate violated — can_apply true on FallerState ant")
				return
			_ground_gate_ok = true
			return

func _drive_settle() -> void:
	if _distributor != null:
		return
	var front: Ant = null
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor():
			continue
		if front == null or a.global_position.x > front.global_position.x:
			front = a
	if front != null:
		var f: FloaterSkill = FloaterSkill.new()
		if f.can_apply(front):
			f.apply(front)
			_distributor = front
			print("[FloaterDistributorTest] applied floater(distributor) → %s pos=%s frame=%d" % [
				front.name, front.global_position, _frame])

func _apply_climbers() -> void:
	# 분배자 외 walker에 climber 부여 → 메사 등반 후 가장자리에서 낙하(FallerState 생성) →
	# 지면 게이트(A) 검증 재료 + 전이(D) 통행 유도.
	if _distributor == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a == _distributor:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if a.has_trait(&"climber"):
			continue
		var cl: ClimberSkill = ClimberSkill.new()
		if cl.can_apply(a):
			cl.apply(a)

func _check_immunity_and_transfer() -> void:
	if _distributor == null or not is_instance_valid(_distributor) or _distributor.state_machine == null:
		return
	if not _settle_ok:
		if _distributor.state_machine.current_state is SettledState:
			_settle_ok = true
			print("[FloaterDistributorTest] distributor settled at frame=%d" % _frame)
	if _settle_ok and not _idle_ok:
		# 분배(정착) 중인 캐릭터는 idle 애니메이션이어야 함.
		var spr: AnimatedSprite2D = _distributor.get_node_or_null("Sprite") as AnimatedSprite2D
		if spr != null and spr.animation == &"idle":
			_idle_ok = true
			print("[FloaterDistributorTest] settled distributor plays idle at frame=%d" % _frame)
	if _settle_ok and not _immune_ok:
		var f: FloaterSkill = FloaterSkill.new()
		if f.can_apply(_distributor):
			_fail("immunity violated — can_apply true on settled distributor")
			return
		_immune_ok = true
	if _settle_ok and not _transfer_ok:
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a == null or not is_instance_valid(a):
				continue
			if a == _distributor:
				continue
			if a.has_trait(&"floater"):
				if a.has_trait(&"distributor"):
					_fail("transfer leaked distributor trait (whitelist violation)")
					return
				# 분배 받은 개미는 작은 우산 배지 표시 / 분배자는 배지 숨김(간판으로 대체).
				var rb: Sprite2D = a.get_node_or_null("TailBadges/FloaterBadge") as Sprite2D
				var db: Sprite2D = _distributor.get_node_or_null("TailBadges/FloaterBadge") as Sprite2D
				if rb == null or not rb.visible:
					_fail("receiver floater badge not visible")
					return
				if db != null and db.visible:
					_fail("distributor should not show floater badge (uses behind sign)")
					return
				_transfer_ok = true
				print("[FloaterDistributorTest] transfer + badge(receiver on/distributor off) verified → %s frame=%d" % [a.name, _frame])
				break

func _pass() -> void:
	_done = true
	print("[FloaterDistributorTest] PASS gate+settle+immune+transfer frame=%d" % _frame)
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _done:
		return
	_done = true
	print("[FloaterDistributorTest] FAIL %s" % msg)
	get_tree().quit(1)
