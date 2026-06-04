extends Node

# Phase 19 (2026-06-04 개정) — Cutter 세로 덩쿨 flood-fill 일괄 절단 검증.
# 구 동작(수평 1 row만 제거 = Basher 동형)에서는 body row(21)만 잘리고 위 행(18~20)은 남았다.
# 새 동작: 전방 plant와 4-방향 연결된 덩쿨 클러스터 전체를 한 번에 제거한다.
#
# Layout (dev_cutter_shatter_vine):
#   y=22 floor row: x=0~20 solid earth
#   vine: cols 12~13 × rows 18~21 (2×4 = 8 plant cell), 바닥 위에 매달린 세로 덩쿨
# Driver: ant body_cell (10,21) (x=336, y=699), direction=+1.
# x >= 11*32+16(=368)에서 cutter 적용 → forward (12,21) plant → 연결 8 cell 전부 제거 → Walker 복귀.
#
# PASS (30s 내):
#  (1) cutter 후 ant state == WalkerState
#  (2) vine 8 cell 전부 제거 (kind="" + has_tile=false) — 특히 body row 위 행(18~20)도 제거됐는지(핵심)
#  (3) floor (12,22),(13,22) kind="earth" 유지 (cutter가 floor 미침범)
#  (4) 비-vine 인접 sample cell 무변동 (전파 경계 정확)

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const LAYOUT: Resource = preload("res://data/stage_layouts/dev_cutter_shatter_vine_layout.tres")
const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")

const DEADLINE_FRAMES: int = 1800
const VINE_CELLS: Array[Vector2i] = [
	Vector2i(12, 21), Vector2i(13, 21),
	Vector2i(12, 20), Vector2i(13, 20),
	Vector2i(12, 19), Vector2i(13, 19),
	Vector2i(12, 18), Vector2i(13, 18),
]
const SAMPLE_CELLS: Array[Vector2i] = [
	Vector2i(11, 21),   # vine 좌측 (공기)
	Vector2i(14, 21),   # vine 우측 (공기)
	Vector2i(11, 22),   # vine 좌하 floor (earth)
	Vector2i(14, 22),   # vine 우하 floor (earth)
	Vector2i(12, 22),   # vine 바로 아래 floor (earth)
	Vector2i(13, 22),   # vine 바로 아래 floor (earth)
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
	print("[CutterShatterVineTest] driver ready")

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
	print("[CutterShatterVineTest] applied cutter at frame=%d pos=%s" % [_frame, _ant.global_position])

func _poll_pass() -> void:
	if not _applied:
		return
	var s: AntState = _ant.state_machine.current_state
	if not (s is WalkerState):
		return
	# (2) vine 8 cell 전부 제거 — body row 위 행 포함.
	for cell in VINE_CELLS:
		if _terrain.get_cell_kind(cell) != "":
			_fail("vine cell %s 잔존 (kind=%s) — flood-fill 미완" % [str(cell), _terrain.get_cell_kind(cell)])
			return
		if _terrain.has_tile(cell):
			_fail("vine cell %s has_tile=true" % str(cell))
			return
		if _terrain.is_cell_occupied(cell):
			_fail("vine cell %s is_cell_occupied=true (디브리/잔존 점유)" % str(cell))
			return
	# (3)(4) sample cell 무변동.
	for c in SAMPLE_CELLS:
		var pre: String = _pre_kinds[c]
		var post: String = _terrain.get_cell_kind(c)
		if pre != post:
			_fail("sample cell %s kind 변동 — pre=%s post=%s (전파 경계 위반)" % [str(c), pre, post])
			return
	print("[CutterShatterVineTest] PASS frame=%d ant_pos=%s" % [_frame, _ant.global_position])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[CutterShatterVineTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
