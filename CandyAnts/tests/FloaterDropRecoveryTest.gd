extends Node

# 2026-06-03 — 낙하산 분배자 사탕 드롭 + 재획득 경로 검증 (Stage02 호스트, 화이트박스).
#   1) 운반 중인 개미에 floater 적용 → has_candy 해제 + 바닥에 DroppedCandy 노드 생성 + 정착.
#   2) 지나가는 비운반 walker가 DroppedCandy에 닿으면 → candy_piece_recovered 발화 + CarryingState 진입.
# 회계 수치 정합은 ScoreRecoveryAccountingTest가 별도 검증 — 본 테스트는 노드/상태 전이 행동만.
# PASS: drop_ok && recovered_ok.

const DEADLINE_FRAMES: int = 16000

var _carrier: Ant = null
var _drop_ok: bool = false
var _recovered_ok: bool = false
var _recovered_id: int = 0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.candy_piece_recovered.connect(_on_recovered)
	print("[FloaterDropRecoveryTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_drive_drop()
	_verify_drop()
	if _drop_ok and _recovered_ok:
		_pass()
		return
	if _frame > DEADLINE_FRAMES:
		_fail("deadline drop=%s recovered=%s" % [str(_drop_ok), str(_recovered_ok)])

func _drive_drop() -> void:
	if _carrier != null:
		return
	# 지면 위 front walker를 강제 운반 상태로 만든 뒤 floater 적용 → 드롭 유발(화이트박스).
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
	var f: FloaterSkill = FloaterSkill.new()
	if not f.can_apply(front):
		return
	f.apply(front)
	_carrier = front
	print("[FloaterDropRecoveryTest] floater on carrier %s pos=%s frame=%d" % [
		front.name, front.global_position, _frame])

func _verify_drop() -> void:
	if _carrier == null or not is_instance_valid(_carrier) or _drop_ok:
		return
	if _carrier.has_candy:
		_fail("carrier still has_candy after floater (no drop)")
		return
	if not (_carrier.state_machine.current_state is SettledState):
		return  # 정착 진입 대기
	# 부모 트리에서 DroppedCandy 노드 1개 이상 확인.
	var parent: Node = _carrier.get_parent()
	if parent == null:
		return
	for c in parent.get_children():
		if c is DroppedCandy:
			_drop_ok = true
			print("[FloaterDropRecoveryTest] drop verified — DroppedCandy spawned + carrier settled frame=%d" % _frame)
			return

func _on_recovered(by_ant: Node) -> void:
	if _recovered_ok:
		return
	var a: Ant = by_ant as Ant
	if a == null or not is_instance_valid(a):
		return
	if a == _carrier:
		_fail("recovered by the settled carrier itself")
		return
	_recovered_id = a.get_instance_id()
	# 재획득한 개미는 운반 상태여야 함.
	if not a.has_candy:
		_fail("recoverer has_candy false after recovery")
		return
	_recovered_ok = true
	print("[FloaterDropRecoveryTest] recovery verified → %s carrying=%s frame=%d" % [a.name, str(a.has_candy), _frame])

func _pass() -> void:
	_done = true
	print("[FloaterDropRecoveryTest] PASS drop+recovery frame=%d" % _frame)
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _done:
		return
	_done = true
	print("[FloaterDropRecoveryTest] FAIL %s" % msg)
	get_tree().quit(1)
