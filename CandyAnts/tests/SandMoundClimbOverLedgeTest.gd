extends Node

# Sand-mound climb-over 회귀 — 윗단 솔리드 레지(dev_sand_mound_layout: row 17 solid, x=11..40) 바로 아래에서
# 모래 더미를 쌓을 때, 개미가 레지 솔리드 셀 안에 끼지 않고 그 위로 타고 넘어 레지 위에 올라서는지 검증한다.
# 기존 SandMoundClimbTest는 레지 왼쪽(cell 10)에서 쌓아 이 경로를 타지 않았다 — 본 테스트가 그 공백을 메운다.
#
# 수정 전(버그): row18 배치 후 개미가 row17(solid)로 올라가 끼고, 다음 tick add_tile(row17) 거부 → abort.
#   결과: tile_count=4, 개미가 레지 아래(y > ledge_top)에 박힘.
# 수정 후: row17을 한 번에 타고 넘어 레지 위(y <= ledge_top)에 올라섬, tile_count=5, WorkerState 종료.
#
# PASS: apply 후 WorkerState 종료 시 (1) on_floor (2) y <= 레지 상단(걷는 면) (3) tile_count == 5

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 420.0   # cell 13 — 레지(x>=11) 바로 아래
const LEDGE_ROW: int = 17        # dev_sand_mound_layout의 윗단 솔리드 row

var _ant: Ant = null
var _applied: bool = false
var _applied_frame: int = 0
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	print("[SandMoundClimbOverLedgeTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_complete()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%s tile_count=%d state=%s y=%.1f" % [_applied, _tile_count(), _state_name(), _ant_y()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../SandMoundStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain
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
	var skill: SandMoundSkill = SandMoundSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	_applied_frame = _frame
	print("[SandMoundClimbOverLedgeTest] applied at frame=%d pos=%s" % [_frame, _ant.global_position])

func _check_complete() -> void:
	if not _applied or _ant == null or _ant.state_machine == null:
		return
	# 5 tile * 0.25s ≈ 75 frame 후 완료. buffer 포함 90 frame 대기.
	if _frame - _applied_frame < 90:
		return
	var s: AntState = _ant.state_machine.current_state
	if s is WorkerState:
		return   # 아직 쌓는 중
	if _terrain == null:
		_fail("terrain missing for climb-over check")
		return
	var cs: int = _terrain.cell_size
	var ledge_top_y: float = float(LEDGE_ROW * cs)   # 레지 솔리드 상단 = 개미가 올라서야 할 걷는 면
	var tc: int = _tile_count()
	var y: float = _ant.global_position.y
	if not _ant.is_on_floor():
		_fail("not on floor after build — y=%.1f state=%s tile_count=%d" % [y, _state_name(), tc])
		return
	if y > ledge_top_y + 8.0:
		# 레지 아래에 박힘 = climb-over 실패(수정 전 버그 시그니처).
		_fail("ant stuck below ledge — y=%.1f > ledge_top=%.1f tile_count=%d" % [y, ledge_top_y, tc])
		return
	if tc != 5:
		_fail("tile_count=%d expected 5 (climb-over는 솔리드 row를 건너뛰고 5개 배치)" % tc)
		return
	print("[SandMoundClimbOverLedgeTest] PASS y=%.1f <= ledge_top=%.1f tile_count=%d" % [y, ledge_top_y, tc])
	_result_emitted = true
	get_tree().quit(0)

func _tile_count() -> int:
	return _terrain.tile_count() if _terrain != null else -1

func _ant_y() -> float:
	return _ant.global_position.y if (_ant != null and is_instance_valid(_ant)) else -1.0

func _state_name() -> String:
	if _ant == null or _ant.state_machine == null or _ant.state_machine.current_state == null:
		return "null"
	return _ant.state_machine.current_state.get_class()

func _fail(msg: String) -> void:
	print("[SandMoundClimbOverLedgeTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
