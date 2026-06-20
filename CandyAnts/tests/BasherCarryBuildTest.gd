extends Node

# basher(옆파기) carry 검증 (2026-06-20) — 운반(사탕) 개미가 흙벽을 뚫고 운반을 이어가는지.
# 구 동작: SandMound와 동일하게 can_apply가 Walker만 + has_candy 거부 → 운반 개미 사용 불가.
# 신 동작: Walker/Carrying 허용. WorkerState("basher")는 has_candy를 보존하고 종료 시
#   return_to_walking()이 CarryingState로 복원 → 운반 개미가 통로를 뚫고 운반을 이어간다.
# 호스트: dev_stages/basher_wall (BasherTunnelThroughWallTest와 동일). 벽 직전에서 개미를 강제
#   운반 상태로 만든 뒤 basher 적용 → 벽 4칸 제거 + CarryingState 복원(has_candy 유지) 확인.

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 11.0 * 32.0

var _ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _done: bool = false
var _terrain: Terrain = null
var _stage: Node = null
var _cleared_frame: int = -1

func _ready() -> void:
	Engine.time_scale = 8.0
	print("[BasherCarryBuildTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_done()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline frame=%d applied=%s" % [_frame, str(_applied)])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../BasherStage")
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
	var skill: BasherSkill = BasherSkill.new()
	if not skill.can_apply(_ant):
		_fail("can_apply==false on CARRYING ant — 운반 중 옆파기 불가(수정 미적용)")
		return
	skill.apply(_ant)
	_applied = true
	print("[BasherCarryBuildTest] applied basher on CARRYING ant frame=%d" % _frame)

func _wall_cleared() -> bool:
	if _terrain == null:
		return false
	for x in range(12, 16):
		var cell: Vector2i = Vector2i(x, 21)
		if _terrain.get_cell_kind(cell) != "" or _terrain.has_tile(cell):
			return false
	return true

func _check_done() -> void:
	if not _applied:
		return
	if _cleared_frame < 0:
		if _wall_cleared():
			_cleared_frame = _frame   # 벽 4칸 제거 완료
		return
	if _frame < _cleared_frame + 12:  # 작업 종료 → return_to_walking 복원 여유
		return
	if not is_instance_valid(_ant) or _ant.state_machine == null:
		_fail("ant invalid after work")
		return
	if not _ant.has_candy:
		_fail("작업 후 has_candy 소실 — 운반 미복원")
		return
	if not (_ant.state_machine.current_state is CarryingState):
		_fail("작업 후 CarryingState 미복원 (current=%s)" % str(_ant.state_machine.current_state))
		return
	print("[BasherCarryBuildTest] PASS — 운반 개미 흙벽 4칸 통과 + 운반 복원 frame=%d" % _frame)
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _done:
		return
	print("[BasherCarryBuildTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
