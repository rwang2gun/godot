extends Node

# 운반(CarryingState) 개미의 막대과자 사다리 통행 회귀 (2026-06-16).
# 사탕을 든 개미(has_candy=true, CarryingState)가 정적 사다리 rung 벽에 막혔을 때
# LadderClimbState로 수직 등반해 레지 위로 올라서는지 검증한다. 빈손 WalkerState에는 있던
# 사다리 게이트가 CarryingState에는 누락돼(2026-06-16 수정 이전) 운반 개미가 사다리 앞에서
# flip하던 버그의 회귀 — stage11 "추락 주의"의 사탕 회수 동선(낮은 지대→사다리→집)이 막히던 근본 원인.
#
# 토폴로지(StaticLadderStage, cell_size=32): 바닥 row22 + 사다리 col10 rows18~21 + 레지 row17.
# Home(2,21)에서 우향 스폰된 개미가 사다리에 닿기 전 CARRY_X에서 강제로 사탕 운반 상태가 된다.
#
# PASS: 운반 상태(has_candy 유지)로 레지 상단(y <= LEDGE_ROW*cs)에 on_floor로 선 개미 관측.
#   수정 전(게이트 누락)이면 운반 개미가 사다리 앞에서 flip → 레지 도달 0 → deadline FAIL.
#   has_candy 유지까지 단언 → 등반 종료 시 return_to_walking의 CarryingState 복원도 함께 입증.

const DEADLINE_FRAMES: int = 3000
const LEDGE_ROW: int = 17
const LEDGE_TOP_TOL: float = 8.0
const CARRY_X: float = 160.0   # 사다리(col10 = x320) 한참 전 — 바닥 보행 중 운반 상태 부여.

var _terrain: Terrain = null
var _carry_id: int = 0
var _done: bool = false
var _frame: int = 0

func _ready() -> void:
	print("[CarryingLadderClimbTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _terrain == null:
		var stage: Node = get_node_or_null("../StaticLadderStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain
	if _terrain == null:
		if _frame > DEADLINE_FRAMES:
			_fail("Terrain 노드를 찾지 못함")
		return

	_assign_carry()

	var cs: int = _terrain.cell_size
	var ledge_top_y: float = float(LEDGE_ROW * cs)
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.get_instance_id() != _carry_id:
			continue
		# 운반 상태(has_candy 유지)로 레지 위에 발 디딘 개미만 PASS — carry 복원까지 입증.
		if a.has_candy and a.global_position.y <= ledge_top_y + LEDGE_TOP_TOL and a.is_on_floor():
			print("[CarryingLadderClimbTest] PASS — carrying ant climbed static ladder to ledge (has_candy=%s) frame=%d" % [a.has_candy, _frame])
			_done = true
			get_tree().quit(0)
			return

	if _frame > DEADLINE_FRAMES:
		_fail("deadline — 운반 개미 레지 도달 실패(carry_id=%d). CarryingState 사다리 게이트 누락 회귀 추정" % _carry_id)

# 사다리에 닿기 전 바닥 보행 중인 첫 개미에게 사탕 운반 상태를 강제 부여 (1회).
func _assign_carry() -> void:
	if _carry_id != 0:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor() or a.global_position.x < CARRY_X:
			continue
		a.has_candy = true
		a.state_machine.change_state(CarryingState.new())
		_carry_id = a.get_instance_id()
		print("[CarryingLadderClimbTest] forced carry on ant id=%d pos=%s frame=%d" % [_carry_id, a.global_position, _frame])
		return

func _fail(msg: String) -> void:
	print("[CarryingLadderClimbTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
