extends Node

# Phase 18 — Basher가 wall 끝(연속 earth 종료 cell) 도달 시 _basher_forward_has_earth=false →
# _aborted → WalkerState 자연 복귀. chain reaction 없음(인접 cell 무영향).
#
# Layout (dev_basher_edge_stop_layout):
#   y=21 body row: wall = (12,21), (13,21)
#   y=22 floor row: x=8~17 solid
# Ant body_cell (10,21) → walker → wall (12,21) 직면 → basher → (12,21), (13,21) 제거 →
# forward (14,21) earth 없음(공기) → _aborted → Walker.
#
# PASS (30s 내):
#  (1) basher 후 ant state == WalkerState
#  (2) wall cell 2개 (12,21),(13,21) 제거 (kind="")
#  (3) sample cell 5개 (11,21),(14,21),(15,21),(12,22),(13,22) 사전/사후 무변동

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const LAYOUT: Resource = preload("res://data/stage_layouts/dev_basher_edge_stop_layout.tres")
const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")

const DEADLINE_FRAMES: int = 1800
const SAMPLE_CELLS: Array[Vector2i] = [
	Vector2i(11, 21),   # wall 좌측 (공기)
	Vector2i(14, 21),   # wall 우측 (공기)
	Vector2i(15, 21),   # wall 우측 +1 (공기)
	Vector2i(12, 22),   # wall 아래 floor
	Vector2i(13, 22),   # wall 아래 floor
]

var _ant: Ant = null
var _terrain: Terrain = null
var _frame: int = 0
var _result_emitted: bool = false
var _applied: bool = false
var _pre_kinds: Dictionary = {}   # Vector2i → String

func _ready() -> void:
	# 1. 최소 stage setup — World/Terrain + StageLayoutBuilder, no StageRunner/Spawner.
	# Terrain을 builder보다 먼저 add_child → builder._ready의 build()가 sibling Terrain 발견 가능.
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
	# Wait for builder.build() to run via _ready() of the builder. builder._ready calls build().
	await get_tree().process_frame
	# 2. sample cells 사전 kind snapshot.
	for c in SAMPLE_CELLS:
		_pre_kinds[c] = _terrain.get_cell_kind(c)
	# 3. Ant 인스턴스화 + body_cell (10,21) 위치.
	_ant = ANT_SCENE.instantiate()
	world.add_child(_ant)
	# body_cell (10,21) → ant.x = 10*32+16=336, ant.y = (21*32) + 27 ≈ 699
	_ant.global_position = Vector2(336.0, 699.0)
	_ant.direction = 1
	# Ant.tscn 의 _ready가 WalkerState 진입. 한 frame 대기 후 적용.
	print("[BasherEdgeStopTest] driver ready")

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
	# direction=1 보장 — body_cell (10,21) → forward (11,21) air → wall (12,21)에 부딪힐 때까지
	# 진행. wall 도달 직전 적용.
	# x=10*32=320 부터 12*32=384까지 walker로 진행 (64px = ~1초).
	if _ant.global_position.x < 11.0 * 32.0 + 16.0:   # cell 11 center 도달
		return
	var skill: BasherSkill = BasherSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	print("[BasherEdgeStopTest] applied basher at frame=%d pos=%s" % [_frame, _ant.global_position])

func _poll_pass() -> void:
	if not _applied:
		return
	# Basher가 끝나면 WalkerState 복귀. tick_interval=0.18s × 2 cell + abort frame = ~0.4s 후 종료.
	var s: AntState = _ant.state_machine.current_state
	if not (s is WalkerState):
		return
	# (1) Walker 복귀 확인.
	# (2) wall cell 2개 제거 확인.
	for x in [12, 13]:
		var cell: Vector2i = Vector2i(x, 21)
		if _terrain.get_cell_kind(cell) != "":
			_fail("wall cell %s 잔존 (kind=%s)" % [str(cell), _terrain.get_cell_kind(cell)])
			return
	# (3) sample cell 무변동 — chain reaction 없음.
	for c in SAMPLE_CELLS:
		var pre: String = _pre_kinds[c]
		var post: String = _terrain.get_cell_kind(c)
		if pre != post:
			_fail("sample cell %s kind 변동 — pre=%s post=%s (chain reaction 검출)" % [str(c), pre, post])
			return
	print("[BasherEdgeStopTest] PASS frame=%d ant_pos=%s" % [_frame, _ant.global_position])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[BasherEdgeStopTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
