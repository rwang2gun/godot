extends Node

# 사다리 우선순위 회귀 (2026-06-17) — climber trait을 든 개미가 사다리 rung 벽에 막히면
# ClimberState가 아니라 LadderClimbState로 전이해 사다리로 올라서는지 검증한다.
# WalkerState/CarryingState의 is_on_wall 분기에서 ladder_climb_ahead가 climber보다 **우선**이다.
# 수정 전(climber 우선)이면 climber 개미가 ClimberState로 벽을 타 LadderClimbState를 거치지 않아 FAIL.
#
# 토폴로지(StaticLadderStage, cs=32): 바닥 row22 + 사다리 col10 rows18~21 + 레지 row17.
# Home(2,21)에서 우향 스폰된 개미가 사다리에 닿기 전 CLIMBER_X에서 climber trait을 강제로 받는다.
#
# PASS: climber 보유 개미가 (1) LadderClimbState를 거치고 (2) 레지 상단에 on_floor로 도달.
#   climber가 사다리보다 우선되면 LadderClimbState를 한 번도 거치지 않아 deadline FAIL.

const DEADLINE_FRAMES: int = 3000
const LEDGE_ROW: int = 17
const LEDGE_TOP_TOL: float = 8.0
const CLIMBER_X: float = 160.0   # 사다리(col10 = x320) 한참 전 — 바닥 보행 중 climber 부여.

var _terrain: Terrain = null
var _climber_id: int = 0
var _saw_ladder_climb: bool = false
var _done: bool = false
var _frame: int = 0

func _ready() -> void:
	print("[ClimberLadderPriorityTest] driver ready")

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

	_assign_climber()

	var cs: int = _terrain.cell_size
	var ledge_top_y: float = float(LEDGE_ROW * cs)
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.get_instance_id() != _climber_id:
			continue
		if a.state_machine != null and a.state_machine.current_state is LadderClimbState:
			_saw_ladder_climb = true
		# climber를 든 개미가 사다리(LadderClimbState)를 거쳐 레지에 발 디뎌야 PASS — climber 우선이면 미관측.
		if _saw_ladder_climb and a.global_position.y <= ledge_top_y + LEDGE_TOP_TOL and a.is_on_floor():
			print("[ClimberLadderPriorityTest] PASS — climber ant climbed via LadderClimbState to ledge frame=%d" % _frame)
			_done = true
			get_tree().quit(0)
			return

	if _frame > DEADLINE_FRAMES:
		_fail("deadline — saw_ladder_climb=%s (climber가 ladder보다 우선되면 LadderClimbState 미관측)" % str(_saw_ladder_climb))

# 사다리에 닿기 전 바닥 보행 중인 첫 개미에게 climber trait을 강제 부여 (1회).
func _assign_climber() -> void:
	if _climber_id != 0:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor() or a.global_position.x < CLIMBER_X:
			continue
		a.set_trait(&"climber")
		_climber_id = a.get_instance_id()
		print("[ClimberLadderPriorityTest] forced climber on ant id=%d pos=%s frame=%d" % [_climber_id, a.global_position, _frame])
		return

func _fail(msg: String) -> void:
	print("[ClimberLadderPriorityTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
