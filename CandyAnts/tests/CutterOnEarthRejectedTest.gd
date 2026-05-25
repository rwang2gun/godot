extends Node

# Phase 19 — 메카닉 분리 검증 (Cutter→earth cross-kind block).
# Layout (dev_earth_plant_separation):
#   y=21 body row: earth wall (8,21)(9,21)(10,21), plant wall (14,21)(15,21)(16,21)
#   y=22 floor row: x=0~22 solid earth
# Driver: ant body_cell (7,21) (x=7*32+16=240, y=699), direction=+1.
# cutter 적용 → forward (8,21) earth → _cutter_forward_has_plant=false → _aborted → Walker 복귀.
#
# PASS (30s 내):
#  (1) cutter 직후 첫 2 tick(~0.36s 약 22 frame) 후 ant state == WalkerState
#  (2) earth wall cell 3개 (8,21)(9,21)(10,21) kind="earth" 유지
#  (3) earth cell 카운트(_static_occupancy + _static_bodies size) 사전/사후 무변동

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const LAYOUT: Resource = preload("res://data/stage_layouts/dev_earth_plant_separation_layout.tres")
const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")

const DEADLINE_FRAMES: int = 1800
const EARTH_WALL_CELLS: Array[Vector2i] = [
	Vector2i(8, 21), Vector2i(9, 21), Vector2i(10, 21)
]

var _ant: Ant = null
var _terrain: Terrain = null
var _frame: int = 0
var _result_emitted: bool = false
var _applied: bool = false
var _applied_frame: int = -1
var _pre_static_count: int = -1

func _ready() -> void:
	var world: Node2D = Node2D.new()
	world.name = "World"
	add_child(world)
	_terrain = Terrain.new()
	_terrain.set_script(TerrainScript)
	_terrain.name = "Terrain"
	world.add_child(_terrain)
	var builder: Node2D = Node2D.new()
	builder.set_script(StageLayoutBuilderScript)
	builder.name = "StageLayoutBuilder"
	builder.set("layout", LAYOUT)
	world.add_child(builder)
	await get_tree().process_frame
	_pre_static_count = _terrain_static_count()
	_ant = ANT_SCENE.instantiate()
	world.add_child(_ant)
	_ant.global_position = Vector2(7.0 * 32.0 + 16.0, 699.0)
	_ant.direction = 1
	print("[CutterOnEarthRejectedTest] driver ready pre_static=%d" % _pre_static_count)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_apply_when_ready()
	_poll_pass()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — applied=%s" % str(_applied))

func _apply_when_ready() -> void:
	if _applied or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if not _ant.is_on_floor():
		return
	var skill: CutterSkill = CutterSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	_applied_frame = _frame
	print("[CutterOnEarthRejectedTest] applied cutter frame=%d pos=%s" % [_frame, _ant.global_position])

func _poll_pass() -> void:
	if not _applied:
		return
	# 적용 후 22 frame(2 tick) 지나야 검증 (Walker 복귀 보장).
	if _frame - _applied_frame < 22:
		return
	var s: AntState = _ant.state_machine.current_state
	if not (s is WalkerState):
		# 아직 cutter 모드면 더 기다림. 60 frame 초과 시 stuck 처리.
		if _frame - _applied_frame > 60:
			_fail("ant still not Walker after %d frames — state=%s" % [_frame - _applied_frame, str(s)])
		return
	# (2) earth wall kind="earth" 유지.
	for c in EARTH_WALL_CELLS:
		var k: String = _terrain.get_cell_kind(c)
		if k != "earth":
			_fail("earth wall %s kind 변동 — kind=%s (cross-kind destruction 검출)" % [str(c), k])
			return
	# (3) static count 무변동.
	var post: int = _terrain_static_count()
	if post != _pre_static_count:
		_fail("static body 카운트 변동 — pre=%d post=%d" % [_pre_static_count, post])
		return
	print("[CutterOnEarthRejectedTest] PASS frame=%d ant_pos=%s static=%d" % [_frame, _ant.global_position, post])
	_result_emitted = true
	get_tree().quit(0)

func _terrain_static_count() -> int:
	var occ: Dictionary = _terrain.get("_static_occupancy") as Dictionary
	return occ.size()

func _fail(msg: String) -> void:
	push_error("[CutterOnEarthRejectedTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
