extends Node

# digger(땅파기) carry 검증 (2026-06-20) — 운반(사탕) 개미가 수직 갱도를 파고 내려가
#   운반을 이어가는지(자유낙하 후 안착 → 운반 복원).
# 구 동작: can_apply가 Walker만 + has_candy 거부 → 운반 개미 사용 불가.
# 신 동작: Walker/Carrying 허용. WorkerState("digger")는 has_candy를 보존하고, 수직 굴착 중
#   자유낙하는 FallerState로 이양되며 착지 시 운반이 복원된다(일반 carry-fall 경로).
# 호스트: dev_stages/digger_pillar (DiggerVerticalTunnelTest와 동일). 개미를 강제 운반 상태로 만든
#   뒤 digger 적용 → shaft 5칸 제거 + 낙하 안착 후 CarryingState 복원(has_candy 유지, 기절 금지) 확인.

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 5.0 * 32.0 + 8.0

var _ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _done: bool = false
var _terrain: Terrain = null
var _stage: Node = null
var _shaft_done: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	print("[DiggerCarryBuildTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_done()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline frame=%d applied=%s shaft_done=%s" % [_frame, str(_applied), str(_shaft_done)])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../DiggerStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_ant = a
			return

func _apply_when_ready() -> void:
	if _applied or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	# 사탕 픽업 시뮬레이션 — 운반 상태로 강제 전이.
	_ant.has_candy = true
	_ant.state_machine.change_state(CarryingState.new())
	var skill: DiggerSkill = DiggerSkill.new()
	if not skill.can_apply(_ant):
		_fail("can_apply==false on CARRYING ant — 운반 중 땅파기 불가(수정 미적용)")
		return
	skill.apply(_ant)
	_applied = true
	print("[DiggerCarryBuildTest] applied digger on CARRYING ant frame=%d" % _frame)

func _shaft_cleared() -> bool:
	if _terrain == null:
		return false
	for y in range(22, 27):
		var cell: Vector2i = Vector2i(5, y)
		if _terrain.get_cell_kind(cell) != "" or _terrain.has_tile(cell):
			return false
	return true

func _check_done() -> void:
	if not _applied:
		return
	if not _shaft_done:
		if _shaft_cleared():
			_shaft_done = true   # shaft 5칸 굴착 완료. 이후 낙하/안착 → 운반 복원 폴링.
		return
	if not is_instance_valid(_ant) or _ant.state_machine == null:
		_fail("ant invalid after dig")
		return
	var s: AntState = _ant.state_machine.current_state
	# 운반 개미가 갱도 낙하로 기절/소실되면 안 된다(이 레이아웃은 안전 낙하 — walker 테스트 lost 0 검증).
	if s is DeadState or s is LostState:
		_fail("운반 개미 낙하 기절/소실 (state=%s)" % str(s))
		return
	# 안착 전(WorkerState/FallerState)에는 계속 폴링. CarryingState 복원 + has_candy 유지면 PASS.
	if not (s is CarryingState):
		return
	if not _ant.has_candy:
		_fail("안착 후 has_candy 소실 — 운반 미복원")
		return
	print("[DiggerCarryBuildTest] PASS — 운반 개미 갱도 5칸 굴착 + 낙하 안착 + 운반 복원 frame=%d" % _frame)
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _done:
		return
	print("[DiggerCarryBuildTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
