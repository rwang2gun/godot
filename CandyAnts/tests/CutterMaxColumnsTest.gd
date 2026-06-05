extends Node

# Cutter 전방 열 절단 "1열씩 최대 5열" 캡 검증 (2026-06-05).
# 구 동작(flood-fill 연결 클러스터 전체 제거)이라면 7열 덤불이 한 번에 통째로 사라진다. 새 동작(Basher
# 동형 march, CUTTER_MAX_COLUMNS=5)은 전방으로 1열씩 5열만 잘라 앞 5열을 열고, 뒤 2열은 남긴다.
#
# Layout (dev_cutter_wide_vine): cols 12~18 × rows 20~21 (7열 × 2행 = 14 plant), floor row 22 (x=0~24).
# Driver: ant body (10,21)→walker, x>=11*32+16(=368)에서 cutter 1회 적용 → forward (12,21) plant.
#   march: 12,13,14,15,16 (앞 5열 × 2행 = 10 cell) 제거 + 1 cell씩 전진, _remaining=0 → Walker. 17,18열은 잔존.
#
# PASS (30s 내):
#  (1) cutter 후 ant state == WalkerState
#  (2) 앞 5열(12~16) × 2행 = 10 cell 전부 제거 (kind="" + 미점유)
#  (3) 뒤 2열(17~18) × 2행 = 4 cell 전부 plant 잔존 (5열 캡 + march 전방성 증명)

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const LAYOUT: Resource = preload("res://data/stage_layouts/dev_cutter_wide_vine_layout.tres")
const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")

const DEADLINE_FRAMES: int = 1800
const REMOVED_CELLS: Array[Vector2i] = [
	Vector2i(12, 21), Vector2i(12, 20),
	Vector2i(13, 21), Vector2i(13, 20),
	Vector2i(14, 21), Vector2i(14, 20),
	Vector2i(15, 21), Vector2i(15, 20),
	Vector2i(16, 21), Vector2i(16, 20),
]
const REMAINING_CELLS: Array[Vector2i] = [
	Vector2i(17, 21), Vector2i(17, 20),
	Vector2i(18, 21), Vector2i(18, 20),
]

var _ant: Ant = null
var _terrain: Terrain = null
var _frame: int = 0
var _applied: bool = false
var _result_emitted: bool = false

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
	_ant = ANT_SCENE.instantiate()
	world.add_child(_ant)
	_ant.global_position = Vector2(336.0, 699.0)
	_ant.direction = 1
	print("[CutterMaxColumnsTest] driver ready")

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
	if not (_ant.state_machine.current_state is WalkerState) or not _ant.is_on_floor():
		return
	if _ant.global_position.x < 11.0 * 32.0 + 16.0:
		return
	var skill: CutterSkill = CutterSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	print("[CutterMaxColumnsTest] applied cutter at frame=%d pos=%s" % [_frame, _ant.global_position])

func _poll_pass() -> void:
	if not _applied:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	# (2) 앞 5열(10 cell) 제거.
	for cell in REMOVED_CELLS:
		if _terrain.get_cell_kind(cell) != "" or _terrain.is_cell_occupied(cell):
			_fail("앞 5열 cell %s 잔존 (kind=%s occ=%s) — march 미완" % [
				str(cell), _terrain.get_cell_kind(cell), str(_terrain.is_cell_occupied(cell))])
			return
	# (3) 뒤 2열(4 cell) plant 잔존 — 5열 캡 + 전방 march 증명.
	for cell in REMAINING_CELLS:
		if _terrain.get_cell_kind(cell) != "plant":
			_fail("뒤 2열 cell %s 가 제거됨 (kind=%s) — 5열 캡 위반(flood-fill 회귀?)" % [
				str(cell), _terrain.get_cell_kind(cell)])
			return
	print("[CutterMaxColumnsTest] PASS frame=%d ant_pos=%s — 앞5열 제거·뒤2열 잔존" % [_frame, _ant.global_position])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[CutterMaxColumnsTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
