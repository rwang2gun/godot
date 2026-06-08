extends Node

# 회귀 — digger 컬럼 경계 걸침 버그 (2026-06-08).
# 증상: 개미(본체 18px)가 48px 셀 경계에 걸쳐 선 채 digger를 적용하면 1칸만 파고 멈춤.
# 원인: digger는 body 컬럼 1칸 제거 후 중력 낙하로 다음 칸 안착을 기대하는데, 경계 걸침 시
#   인접 컬럼의 같은 행 타일이 개미를 받쳐 낙하 못함 → 다음 tick에 비운 아래 칸 재검사 → abort.
# 수정: _enter_digger가 개미를 자기 컬럼 정중앙으로 스냅 → 단일 컬럼 안에서 곧장 낙하.
#
# 검증: stage10의 깊은 흙 컬럼(col 15, rows 8~16) 위 col14/15 경계(x=15*48)에 개미를 놓고
#   digger 적용 → 흙이 ≥4칸 제거되면 PASS(1칸에서 안 멈춤). ≤1이면 FAIL(버그 재현).

const STAGE: String = "res://scenes/stages/Stage10.tscn"
const COL: int = 15
const BOUNDARY_X: float = COL * 48.0   # col14/15 경계 — 개미가 두 컬럼에 걸침
const SURFACE_Y: float = 376.5         # (col,8) 표면 위 안착 y
const DEADLINE: int = 600

var _stage: Node = null
var _terrain: Terrain = null
var _ant: Ant = null
var _phase: int = 0
var _frame: int = 0
var _applied_frame: int = -1

func _ready() -> void:
	print("[DiggerColumnBoundaryTest] driver ready")

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame > DEADLINE:
		_fail("deadline exceeded (phase=%d)" % _phase)
		return
	match _phase:
		0:
			_stage = load(STAGE).instantiate()
			add_child(_stage)
			_terrain = _stage.get_node("World/Terrain") as Terrain
			_phase = 1
		1:
			_grab_ant()
		2:
			# 경계에 걸친 채 on_floor 되는 즉시 digger 적용 (걸어서 재정렬되기 전).
			if _ant != null and is_instance_valid(_ant) and _ant.is_on_floor():
				_apply()
		3:
			# 굴착 진행 관찰 — 적용 후 충분히 대기 후 판정.
			if _frame - _applied_frame > 180:
				_judge()

func _grab_ant() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null and _stage.is_ancestor_of(a):
			_ant = a
			break
	if _ant == null:
		return
	_ant.global_position = Vector2(BOUNDARY_X, SURFACE_Y)
	_ant.velocity = Vector2.ZERO
	_ant.state_machine.change_state(WalkerState.new())
	_phase = 2

func _apply() -> void:
	var sk: DiggerSkill = DiggerSkill.new()
	if not sk.can_apply(_ant):
		return   # 아직 안착 전 — 다음 frame 재시도
	sk.apply(_ant)
	_applied_frame = _frame
	_phase = 3
	print("[DiggerColumnBoundaryTest] digger applied frame=%d x=%.1f body_col=%d" % [
		_frame, _ant.global_position.x, int(floor(_ant.global_position.x / 48.0))])

func _judge() -> void:
	# 스냅된 실제 굴착 컬럼 — 적용 후 개미가 정중앙 스냅되므로 그 컬럼을 확인.
	var dug_col: int = int(floor(_ant.global_position.x / 48.0)) if (_ant != null and is_instance_valid(_ant)) else COL
	var dug: int = 0
	for y in range(8, 17):
		var cell: Vector2i = Vector2i(dug_col, y)
		if _terrain.get_cell_kind(cell) == "" and not _terrain.has_tile(cell):
			dug += 1
	if dug >= 4:
		print("[DiggerColumnBoundaryTest] PASS dug=%d col=%d frame=%d" % [dug, dug_col, _frame])
		get_tree().quit(0)
	else:
		_fail("digger dug only %d cells (col=%d) — 경계 걸침 1칸 멈춤 버그" % [dug, dug_col])

func _fail(msg: String) -> void:
	push_error("[DiggerColumnBoundaryTest] FAIL: " + msg)
	get_tree().quit(1)
