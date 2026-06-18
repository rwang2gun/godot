extends Node

# 계단 체인 건설 검증 (2026-06-04) — 계단 끝(낭떠러지)에서 무장한 후속 개미가 이어 건설하는가.
# builder_chain dev 스테이지: 좌측 평지(row22, cols0~12) + 한참 아래 catch 바닥(row30). 우측 단 없음 →
# 계단은 어떤 단에도 닿지 못하고 캡(5스텝)에서 멈춘다. 개미 2마리를 좌측 평지에서 builder 무장 →
# 첫 개미가 col12 낭떠러지에서 대각 계단 1세그먼트(≤5스텝) 건설 후 자기 계단 끝에서 낙하. 둘째 개미가 그
# 계단을 타고(StairClimbState) 꼭대기(낭떠러지)에 도달하면 try_build_armed_builder가 발화해 둘째 계단
# 세그먼트를 이어 건설해야 한다.
#
# 판정: WorkerState("builder")에 진입한 **서로 다른 개미 2마리 이상** 관측 → 체인 성립(둘째 개미가
#   첫 계단 끝에서 건설 세션 시작). 1마리만 관측되면 둘째가 계단 끝에서 못 짓고 낙하 = 체인 불가 = FAIL.

const DEADLINE_FRAMES: int = 3000
const ARM_X_MAX: float = 320.0   # col ~9 이하 좌측 평지 — 낭떠러지(col12) 전이라 무장(즉시 건설 X).
const UPPER_Y_MAX: float = 800.0 # 상단 평지(row22≈704)만, 하단 catch 바닥(row30≈960) 제외.
const ARM_COUNT: int = 2

var _armed_ids: Dictionary = {}
var _builder_session_ids: Dictionary = {}   # WorkerState("builder")에 진입한 개미 id 집합
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	print("[BuilderChainTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_arm_when_ready()
	_observe_builder_sessions()
	if _builder_session_ids.size() >= 2:
		print("[BuilderChainTest] PASS — %d distinct ants ran builder sessions (둘째가 첫 계단 끝에서 체인) frame=%d" % [
			_builder_session_ids.size(), _frame])
		_done = true
		get_tree().quit(0)
		return
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — builder_sessions=%d armed=%d" % [_builder_session_ids.size(), _armed_ids.size()])

func _arm_when_ready() -> void:
	if _armed_ids.size() >= ARM_COUNT:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if _armed_ids.has(a.get_instance_id()):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor() or a.direction != 1:
			continue
		if a.global_position.x >= ARM_X_MAX or a.global_position.y >= UPPER_Y_MAX:
			continue
		var builder: SlideRSkill = SlideRSkill.new()
		if not builder.can_apply(a):
			continue
		builder.apply(a)
		_armed_ids[a.get_instance_id()] = true
		print("[BuilderChainTest] armed builder → id=%d pos=%s frame=%d (total=%d)" % [
			a.get_instance_id(), a.global_position, _frame, _armed_ids.size()])
		if _armed_ids.size() >= ARM_COUNT:
			return

func _observe_builder_sessions() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var s: AntState = a.state_machine.current_state
		if s is WorkerState and (s as WorkerState)._work_type == "builder":
			_builder_session_ids[a.get_instance_id()] = true

func _fail(msg: String) -> void:
	print("[BuilderChainTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
