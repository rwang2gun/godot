extends Node

# Phase 19 — Cutter가 vine 끝(연속 plant 종료 cell) 도달 시 _cutter_forward_has_plant=false →
# _aborted → WalkerState 자연 복귀. chain reaction 없음(인접 cell 무영향).
#
# Layout (dev_cutter_edge_stop_layout):
#   y=21 body row: vine = (12,21), (13,21) plant
#   y=22 floor row: x=0~20 solid earth
# Ant body_cell (10,21) → walker → vine (12,21) 직면 → cutter → (12,21), (13,21) 제거 →
# forward (14,21) plant 없음(공기) → _aborted → Walker.
#
# PASS (30s 내):
#  (1) cutter 후 ant state == WalkerState
#  (2) vine cell 2개 (12,21),(13,21) 제거 (kind="")
#  (3) sample cell 5개 (11,21),(14,21),(15,21),(12,22),(13,22) 사전/사후 무변동

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const LAYOUT: Resource = preload("res://data/stage_layouts/dev_cutter_edge_stop_layout.tres")
const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")

const DEADLINE_FRAMES: int = 1800
const SAMPLE_CELLS: Array[Vector2i] = [
	Vector2i(11, 21),   # vine 좌측 (공기)
	Vector2i(14, 21),   # vine 우측 (공기)
	Vector2i(15, 21),   # vine 우측 +1 (공기)
	Vector2i(12, 22),   # vine 아래 floor (earth)
	Vector2i(13, 22),   # vine 아래 floor (earth)
]

var _ant: Ant = null
var _terrain: Terrain = null
var _frame: int = 0
var _result_emitted: bool = false
var _applied: bool = false
var _pre_kinds: Dictionary = {}

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
	for c in SAMPLE_CELLS:
		_pre_kinds[c] = _terrain.get_cell_kind(c)
	_ant = ANT_SCENE.instantiate()
	world.add_child(_ant)
	_ant.global_position = Vector2(336.0, 699.0)
	_ant.direction = 1
	print("[CutterEdgeStopTest] driver ready")

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
	if _ant.global_position.x < 11.0 * 32.0 + 16.0:
		return
	var skill: CutterSkill = CutterSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	print("[CutterEdgeStopTest] applied cutter at frame=%d pos=%s" % [_frame, _ant.global_position])

func _poll_pass() -> void:
	if not _applied:
		return
	var s: AntState = _ant.state_machine.current_state
	if not (s is WalkerState):
		return
	for x in [12, 13]:
		var cell: Vector2i = Vector2i(x, 21)
		if _terrain.get_cell_kind(cell) != "":
			_fail("vine cell %s 잔존 (kind=%s)" % [str(cell), _terrain.get_cell_kind(cell)])
			return
	for c in SAMPLE_CELLS:
		var pre: String = _pre_kinds[c]
		var post: String = _terrain.get_cell_kind(c)
		if pre != post:
			_fail("sample cell %s kind 변동 — pre=%s post=%s (chain reaction 검출)" % [str(c), pre, post])
			return
	print("[CutterEdgeStopTest] PASS frame=%d ant_pos=%s" % [_frame, _ant.global_position])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[CutterEdgeStopTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
