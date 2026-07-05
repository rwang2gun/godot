extends Node

# carrying(사탕 운반) 개미가 sand_mound(사다리)를 건설하고 운반 상태로 복원되는지 검증 (2026-06-20).
# 구 동작: SandMoundSkill.can_apply가 Walker만 허용 + has_candy 거부 → 운반 개미 건설 불가.
# 신 동작: bridge/slide와 동일하게 Walker/Carrying 허용. WorkerState("sand_mound")는 has_candy를
#   보존하고(가드), 종료 시 return_to_walking()이 has_candy면 CarryingState로 복원 → 운반 개미가
#   사다리를 짓고 운반을 이어간다(in_transit 영구 잔존 위험 없음).
# 호스트: dev_stages/sand_mound (SandMoundClimbTest와 동일). 첫 개미를 TRIGGER_X에서 강제 운반
#   상태로 만든 뒤 sand_mound 적용 → 5칸 건설 → CarryingState 복원(has_candy 유지) 확인.

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 330.0

var _ant: Ant = null
var _applied: bool = false
var _built_frame: int = -1
var _frame: int = 0
var _done: bool = false
var _terrain: Terrain = null
var _stage: Node = null

func _ready() -> void:
	Engine.time_scale = 8.0
	print("[SandMoundCarryBuildTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_built_and_restored()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline frame=%d applied=%s tile_count=%d" % [_frame, str(_applied), _tile_count()])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../SandMoundStage")
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
	# 사탕 픽업 시뮬레이션 — 운반 상태로 강제 전이(has_candy=true + CarryingState).
	_ant.has_candy = true
	_ant.state_machine.change_state(CarryingState.new())
	# carrying 개미에 sand_mound 적용 — 구 동작은 can_apply==false라 여기서 막혔다(수정 핵심).
	var skill: SandMoundSkill = SandMoundSkill.new()
	if not skill.can_apply(_ant):
		_fail("can_apply==false on CARRYING ant — 운반 중 사다리 건설 불가(수정 미적용)")
		return
	skill.apply(_ant)
	_applied = true
	if not (_ant.state_machine.current_state is WorkerState):
		_fail("apply 후 WorkerState 미전이 (current=%s)" % str(_ant.state_machine.current_state))
		return
	print("[SandMoundCarryBuildTest] applied sand_mound on CARRYING ant frame=%d pos=%s" % [_frame, _ant.global_position])

func _check_built_and_restored() -> void:
	if not _applied:
		return
	if _built_frame < 0:
		if _tile_count() >= 5:
			_built_frame = _frame   # 5칸 건설 완료 시점
		return
	if _frame < _built_frame + 8:    # WorkerState 종료 → return_to_walking 복원 여유
		return
	if not is_instance_valid(_ant) or _ant.state_machine == null:
		_fail("ant freed/invalid after build")
		return
	# 핵심: 운반 개미가 사다리를 짓고도 has_candy 유지 + CarryingState 복원(운반 이어감).
	if not _ant.has_candy:
		_fail("건설 후 has_candy 소실 — 운반 상태 미복원")
		return
	if not (_ant.state_machine.current_state is CarryingState):
		_fail("건설 후 CarryingState 미복원 (current=%s)" % str(_ant.state_machine.current_state))
		return
	print("[SandMoundCarryBuildTest] PASS — 운반 개미 사다리 5칸 건설 + 운반 복원 frame=%d tile_count=%d" % [_frame, _tile_count()])
	_done = true
	get_tree().quit(0)

func _tile_count() -> int:
	if _terrain == null:
		return -1
	return _terrain.tile_count()

func _fail(msg: String) -> void:
	if _done:
		return
	print("[SandMoundCarryBuildTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
