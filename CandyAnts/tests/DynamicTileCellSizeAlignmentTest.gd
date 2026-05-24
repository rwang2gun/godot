extends Node

# Phase 16 v3 — layout cell_size=32 stage에서 동적 tile world position이 정적 stage grid와 정렬되는지 검증.
# F-R1-H2 회귀 가드: cell_size unification 후 add_tile이 16px grid에 어긋나면 FAIL.
# PASS: (1) terrain.cell_size == 32 (2) 동적 tile global_position이 32px grid 중심 (3) 정적 cell도 동일 grid

const DEADLINE_FRAMES: int = 120
const EMPTY_CELL: Vector2i = Vector2i(15, 21)   # dev_bridge_layout에서 비어있는 cell
const STATIC_CELL: Vector2i = Vector2i(15, 20)  # 우측 platform 정적 cell (확실히 등록)

var _frame: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[DynamicTileCellSizeAlignmentTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	# 첫 1-2 frame은 StageLayoutBuilder._ready()/build() 완료 대기.
	if _frame < 5:
		return
	var stage: Node = get_node_or_null("../BridgeStage")
	if stage == null:
		_fail("BridgeStage instance not found")
		return
	var terrain: Terrain = stage.get_node_or_null("World/Terrain") as Terrain
	if terrain == null:
		_fail("Terrain node not found")
		return
	if terrain.cell_size != 32:
		_fail("terrain.cell_size=%d expected 32" % terrain.cell_size)
		return
	# (1) 동적 tile 검증.
	var ok: bool = terrain.add_tile(EMPTY_CELL)
	if not ok:
		_fail("add_tile(%s) returned false — cell unexpectedly occupied" % str(EMPTY_CELL))
		return
	var body: StaticBody2D = terrain._placed[EMPTY_CELL]
	if body == null:
		_fail("_placed dict missing body for %s" % str(EMPTY_CELL))
		return
	var expected_dynamic: Vector2 = Vector2(float(EMPTY_CELL.x) * 32.0 + 16.0, float(EMPTY_CELL.y) * 32.0 + 16.0)
	if not body.global_position.is_equal_approx(expected_dynamic):
		_fail("dynamic tile pos=%s expected=%s" % [body.global_position, expected_dynamic])
		return
	# (2) 정적 cell 위치 검증 — StageLayoutBuilder의 Cell_x_y child 확인.
	var slb: Node = stage.get_node_or_null("World/StageLayoutBuilder")
	if slb == null:
		_fail("StageLayoutBuilder not found")
		return
	var static_body: Node2D = slb.get_node_or_null("Cell_%d_%d" % [STATIC_CELL.x, STATIC_CELL.y]) as Node2D
	if static_body == null:
		_fail("Static cell node Cell_%d_%d not found" % [STATIC_CELL.x, STATIC_CELL.y])
		return
	var expected_static: Vector2 = Vector2(float(STATIC_CELL.x) * 32.0 + 16.0, float(STATIC_CELL.y) * 32.0 + 16.0)
	if not static_body.global_position.is_equal_approx(expected_static):
		_fail("static cell pos=%s expected=%s" % [static_body.global_position, expected_static])
		return
	# (3) static_occupancy 등록 확인.
	if not terrain._static_occupancy.has(STATIC_CELL):
		_fail("terrain._static_occupancy missing %s — StageLayoutBuilder.register_static_cell skipped" % str(STATIC_CELL))
		return
	# (4) D8 dynamic↔static gate 직접 검증 — 이미 static인 cell에 add_tile은 false 반환.
	#     BridgeRejectStageCellTest는 _far_side_floor_reached가 먼저 발화해 이 경로를 안 거치므로
	#     본 테스트가 add_tile rejection 자체를 명시 검증.
	var tile_count_before: int = terrain.tile_count()
	var reject_ok: bool = terrain.add_tile(STATIC_CELL)
	if reject_ok:
		_fail("add_tile on static cell %s returned true — _static_occupancy gate bypassed" % str(STATIC_CELL))
		return
	if terrain.tile_count() != tile_count_before:
		_fail("tile_count changed after rejected add_tile — partial side effect")
		return
	print("[DynamicTileCellSizeAlignmentTest] PASS cell_size=32 dynamic=%s static=%s reject_ok" % [body.global_position, static_body.global_position])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[DynamicTileCellSizeAlignmentTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
