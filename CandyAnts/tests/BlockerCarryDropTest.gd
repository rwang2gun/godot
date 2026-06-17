extends Node

# 2026-06-17 — 운반 중 개미 blocker 적용: 사탕 드롭 + 정지 검증 (Stage02 호스트, 화이트박스).
# 운반 중(CarryingState/has_candy)인 개미에 blocker를 적용하면 (낙하산 분배자와 동일 패턴):
#   1) BlockerSkill.can_apply == true — 구버전은 has_candy를 거부(운반자 Blocker화 시 in_transit
#      영구 잔존 데드락 우려)했으나, 드롭으로 in_transit→lost 즉시 정산되어 그 사유가 해소된다.
#   2) has_candy 해제 + 바닥에 재획득 가능한 DroppedCandy 생성 + candy_piece_lost 발화.
#   3) WorkerState("blocker")로 정지(길막기).
# 떨어진 사탕의 회수 경로는 DroppedCandy 공용 메커니즘(FloaterDropRecoveryTest가 커버)이라 범위 외.
# PASS: can_apply_ok && dropped_ok && blocking_ok && lost_emitted.

const DEADLINE_FRAMES: int = 4000

var _carrier: Ant = null
var _can_apply_ok: bool = false
var _lost_emitted: bool = false
var _dropped_ok: bool = false
var _blocking_ok: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.candy_piece_lost.connect(_on_lost)
	print("[BlockerCarryDropTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_drive()
	_verify()
	if _can_apply_ok and _dropped_ok and _blocking_ok and _lost_emitted:
		_pass()
		return
	if _frame > DEADLINE_FRAMES:
		_fail("deadline can_apply=%s dropped=%s blocking=%s lost=%s" % [
			str(_can_apply_ok), str(_dropped_ok), str(_blocking_ok), str(_lost_emitted)])

func _drive() -> void:
	if _carrier != null:
		return
	# 지면 위 front walker를 강제 운반 상태로 만든 뒤 blocker 적용 → 드롭 유발(화이트박스).
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
	if front == null:
		return
	front.state_machine.change_state(CarryingState.new())   # has_candy=true
	var b: BlockerSkill = BlockerSkill.new()
	_can_apply_ok = b.can_apply(front)   # 핵심: 운반 중 blocker 허용.
	if not _can_apply_ok:
		_fail("BlockerSkill.can_apply==false for carrying ant — 운반 중 blocker 거부")
		return
	# lost 옵저버가 carrier를 식별하도록 apply **전에** 바인딩(apply 내부에서 candy_piece_lost 발화).
	_carrier = front
	b.apply(front)
	print("[BlockerCarryDropTest] blocker on carrier %s pos=%s frame=%d" % [
		front.name, front.global_position, _frame])

func _on_lost(by_ant: Node) -> void:
	if _carrier != null and by_ant == _carrier:
		_lost_emitted = true

func _verify() -> void:
	if _carrier == null or not is_instance_valid(_carrier):
		return
	if _carrier.has_candy:
		_fail("carrier still has_candy after blocker (no drop)")
		return
	# 정지(blocker)는 WorkerState — _enter_blocker가 set_blocker_active(true).
	if _carrier.state_machine.current_state is WorkerState:
		_blocking_ok = true
	# 부모 트리에서 DroppedCandy 노드 확인.
	if not _dropped_ok:
		var parent: Node = _carrier.get_parent()
		if parent != null:
			for c in parent.get_children():
				if c is DroppedCandy:
					_dropped_ok = true
					break

func _pass() -> void:
	_done = true
	print("[BlockerCarryDropTest] PASS — 운반 개미 blocker: 드롭+정지+lost 정산 frame=%d" % _frame)
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _done:
		return
	_done = true
	print("[BlockerCarryDropTest] FAIL %s" % msg)
	get_tree().quit(1)
