extends Node

# 정적 막대과자 사다리 E2E — 스킬 시전 없이, 레이아웃(.tres)에 sand_mound로 깔린 사다리를
# 개미가 자동으로 타고 레지 위로 오르는지 검증한다. StaticLadderTileTest(등록 계약 단위)와 달리
# 여기서는 직렬화(.tres) → StageLayoutBuilder 빌드 → 실제 개미 물리 등반(LadderClimbState)까지
# 전 경로를 한 번에 증명한다.
#
# 토폴로지(dev_static_ladder_layout, cell_size=32): 바닥 row22 + 사다리 기둥 col10 rows18~21 +
# 레지 row17(cols8~16). Home(2,21)에서 우향 스폰된 개미가 col10 사다리에 막혀 LadderClimbState로
# 등반 → 레지 위(row16)로 올라섬.
#
# PASS: 레지 상단(y <= LEDGE_ROW*cs + tol)에 on_floor로 선 개미 1마리 이상 관측.
#   정적 사다리 등반이 안 되면(벽 취급 flip / 추락) 아무도 레지에 못 올라 deadline FAIL.

const DEADLINE_FRAMES: int = 3000
const LEDGE_ROW: int = 17
const LEDGE_TOP_TOL: float = 8.0

var _terrain: Terrain = null
var _reached_ids: Dictionary = {}
var _done: bool = false
var _frame: int = 0

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

	var cs: int = _terrain.cell_size
	var ledge_top_y: float = float(LEDGE_ROW * cs)
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		# 레지 걷는 면(row17 상단) 이상으로 올라섰고 발판에 선 개미만 집계 — 바닥(row22) 보행 개미 제외.
		if a.global_position.y <= ledge_top_y + LEDGE_TOP_TOL and a.is_on_floor():
			_reached_ids[a.get_instance_id()] = true

	if _reached_ids.size() >= 1:
		print("PASS StaticLadderClimbTest — %d ant(s) climbed static ladder to ledge frame=%d" % [_reached_ids.size(), _frame])
		_done = true
		get_tree().quit(0)
		return
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — 레지 도달 개미 0 (정적 사다리 등반 실패 추정)")

func _fail(msg: String) -> void:
	print("FAIL StaticLadderClimbTest %s" % msg)
	_done = true
	get_tree().quit(1)
