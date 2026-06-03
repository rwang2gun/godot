extends Node2D
# codex 2026-06-03 MEDIUM 회귀 — 운반(Carrying) 중인 개미가 계단 STAIR 벽을 만나면 flip/정지가 아니라
# StairClimbState로 부드럽게 등반하고, 등반 내내 has_candy(운반)가 보존되는지 검증.
#
# 지형(cell 48): 지면 row8 cols0~5 + 계단 STAIR (6,7)(7,6). 운반 개미가 보행→두 계단 등반(body row5 도달).
# PASS: 등반 중 StairClimbState 진입 ✓ + body_row 5 도달(꼭대기) ✓ + has_candy 항상 true(운반 유지) ✓.
# FAIL: 등반 미진입(flip만) / 꼭대기 미도달 / has_candy 분실.

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const CS: int = 48
const DEADLINE: int = 500

var _ant: Ant = null
var _entered_climb: bool = false
var _reached_top: bool = false
var _candy_lost: bool = false
var _carry_made: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	var terrain: Terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.set_cell_size(CS)
	add_child(terrain)
	for c in range(0, 6):
		terrain.add_tile(Vector2i(c, 8), Terrain.DYNAMIC_TILE_BRIDGE)
	terrain.add_tile(Vector2i(6, 7), Terrain.DYNAMIC_TILE_STAIR, 1)
	terrain.add_tile(Vector2i(7, 6), Terrain.DYNAMIC_TILE_STAIR, 1)
	_ant = ANT_SCENE.instantiate() as Ant
	_ant.direction = 1
	_ant.global_position = Vector2(2 * CS + 24, 8 * CS - 8)
	add_child(_ant)
	print("[StairCarryClimbTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	# 첫 frame: 운반 상태로 전환 (사탕을 든 개미 모사).
	if not _carry_made:
		_ant.has_candy = true
		_ant.state_machine.change_state(CarryingState.new())
		_carry_made = true
		return
	# has_candy 분실 감시 (운반 시작 후).
	if not _ant.has_candy:
		_candy_lost = true
	var s: Object = _ant.state_machine.current_state
	if s is StairClimbState:
		_entered_climb = true
	var row: int = int(floor((_ant.global_position.y - 2.0) / CS))
	if row <= 5:
		_reached_top = true
	if _entered_climb and _reached_top:
		_finish()
	if _frame > DEADLINE:
		_finish()

func _finish() -> void:
	_done = true
	if _candy_lost:
		print("[StairCarryClimbTest] FAIL has_candy lost during climb")
		get_tree().quit(1)
		return
	if not _entered_climb:
		print("[StairCarryClimbTest] FAIL carrying ant never entered StairClimbState (flip/stall instead)")
		get_tree().quit(1)
		return
	if not _reached_top:
		print("[StairCarryClimbTest] FAIL carrying ant did not climb to top (row5)")
		get_tree().quit(1)
		return
	print("[StairCarryClimbTest] PASS carrying ant climbed stairs (StairClimbState) with candy preserved")
	get_tree().quit(0)
