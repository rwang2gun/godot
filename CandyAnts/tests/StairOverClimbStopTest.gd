extends Node2D
# codex 2026-06-03 HIGH 회귀 — 계단 꼭대기가 허공으로 끝날 때 StairClimbState가 한 칸 더 글라이드해
# 허공으로 over-climb하지 않는지 검증. 게이트가 "전방 셀 점유 필수"라 꼭대기(전방=허공)에서 멈춰야 한다.
#
# 지형(cell 48): 지면 row8 cols0~5 + 계단 STAIR (6,7)(7,6) → 그 위는 평지/레지 없이 **허공**.
# ant가 보행→(6,7) 등반(body row6)→(7,6) 등반(body row5=꼭대기 발판) 후, 전방(8,5)=허공이라 게이트 불충족 →
# 보행 복귀→가장자리 낙하. **정상=min body_row==5**(꼭대기 발판). over-climb면 (8,4)로 한 칸 더 올라 row4 도달=FAIL.

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const CS: int = 48
const DEADLINE: int = 400

var _terrain: Terrain = null
var _ant: Ant = null
var _min_row: int = 99
var _reached_top: bool = false   # body_row 5 도달(계단 등반 성공)
var _over_climbed: bool = false  # body_row <= 4 도달(허공 over-climb)
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	_terrain = Terrain.new()
	_terrain.name = "Terrain"
	_terrain.set_cell_size(CS)
	add_child(_terrain)
	for c in range(0, 6):
		_terrain.add_tile(Vector2i(c, 8), Terrain.DYNAMIC_TILE_BRIDGE)   # 지면 (시각용 floor)
	_terrain.add_tile(Vector2i(6, 7), Terrain.DYNAMIC_TILE_STAIR, 1)
	_terrain.add_tile(Vector2i(7, 6), Terrain.DYNAMIC_TILE_STAIR, 1)
	# 꼭대기 위는 비워둠(허공) — over-climb 유도 조건.
	_ant = ANT_SCENE.instantiate() as Ant
	_ant.direction = 1
	_ant.global_position = Vector2(2 * CS + 24, 8 * CS - 8)
	add_child(_ant)
	print("[StairOverClimbStopTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _ant == null or not is_instance_valid(_ant):
		return
	var row: int = int(floor((_ant.global_position.y - 2.0) / CS))
	_min_row = min(_min_row, row)
	if row == 5:
		_reached_top = true
	if row <= 4:
		_over_climbed = true
	# 꼭대기 도달 후 충분히 진행(낙하 시작)하면 판정.
	if _reached_top and row >= 7:
		_finish()
	if _frame > DEADLINE:
		_finish()

func _finish() -> void:
	_done = true
	if _over_climbed or _min_row <= 4:
		print("[StairOverClimbStopTest] FAIL over-climbed into void — min_row=%d (꼭대기 row5 초과 상승)" % _min_row)
		get_tree().quit(1)
		return
	if not _reached_top:
		print("[StairOverClimbStopTest] FAIL ant did not climb to top — min_row=%d (계단 등반 실패)" % _min_row)
		get_tree().quit(1)
		return
	print("[StairOverClimbStopTest] PASS climbed to top (row5) without void over-climb, min_row=%d" % _min_row)
	get_tree().quit(0)
