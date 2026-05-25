extends Node

# Phase 19 — D4 same-cell overlap (plant + hazard) essential 가드.
# Layout (dev_cutter_over_hazard, body-row primary v3):
#   y=21 body row: plant cell (10,21)
#   y=22 floor row: x=0~13 solid earth
# 추가 hazard: Sticky.tscn instance at cell_to_world((10,21)) — 같은 cell 점유.
# Driver: ant body_cell (9,21) (x=304, y=699), direction=+1.
# cutter 적용 → 첫 tick(~0.18s) forward (10,21) plant destroy → ant.x += 32 (= 336)
# → 같은 frame 또는 다음 frame body_entered → ant.apply_sticky(3.0) → is_stuck()==true.
#
# PASS (30s 내):
#  (1) cutter destroy 성공 후 terrain.get_cell_kind((10,21)) == "" + has_tile((10,21)) == false
#  (2) hazard 노드 monitoring == true 유지 (kind erase가 hazard registry 영향 0)
#  (3) ant 통과 시 is_stuck() == true (Sticky 자연 발화)

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const STICKY_SCENE: PackedScene = preload("res://scenes/entities/hazards/Sticky.tscn")
const LAYOUT: Resource = preload("res://data/stage_layouts/dev_cutter_over_hazard_layout.tres")
const StageLayoutBuilderScript: Script = preload("res://scripts/world/StageLayoutBuilder.gd")
const TerrainScript: Script = preload("res://scripts/world/Terrain.gd")

const DEADLINE_FRAMES: int = 1800
const PLANT_CELL: Vector2i = Vector2i(10, 21)

var _ant: Ant = null
var _terrain: Terrain = null
var _sticky: StickyHazard = null
var _world: Node2D = null
var _frame: int = 0
var _result_emitted: bool = false
var _applied: bool = false
var _destroy_seen: bool = false

func _ready() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_terrain = Terrain.new()
	_terrain.set_script(TerrainScript)
	_terrain.name = "Terrain"
	_world.add_child(_terrain)
	var builder: Node2D = Node2D.new()
	builder.set_script(StageLayoutBuilderScript)
	builder.name = "StageLayoutBuilder"
	builder.set("layout", LAYOUT)
	_world.add_child(builder)
	# 두 frame 대기 — builder.build() 완료 후 hazard._ready await physics_frame까지.
	await get_tree().process_frame
	# Sticky hazard instantiate — plant cell과 동일 좌표.
	_sticky = STICKY_SCENE.instantiate() as StickyHazard
	_sticky.name = "PlantOverlapSticky"
	# cell_to_world((10,21)) — layout 자체에 cell_to_world() 존재.
	var sticky_pos: Vector2 = (LAYOUT as StageLayoutData).cell_to_world(PLANT_CELL)
	_world.add_child(_sticky)
	_sticky.global_position = sticky_pos
	# hazard._ready가 physics_frame await 후 register_hazard_at_cell → 한 physics frame 대기.
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Ant 인스턴스화 — (9,21) body row.
	_ant = ANT_SCENE.instantiate()
	_world.add_child(_ant)
	_ant.global_position = Vector2(9.0 * 32.0 + 16.0, 699.0)
	_ant.direction = 1
	print("[CutterOverHazardCellTest] driver ready sticky_pos=%s" % sticky_pos)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_apply_when_ready()
	_poll_pass()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — applied=%s destroy=%s stuck=%s" % [
			str(_applied), str(_destroy_seen), str(_ant.is_stuck() if _ant != null else false)
		])

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
	print("[CutterOverHazardCellTest] applied cutter frame=%d pos=%s" % [_frame, _ant.global_position])

func _poll_pass() -> void:
	if not _applied:
		return
	if not _destroy_seen:
		var kind: String = _terrain.get_cell_kind(PLANT_CELL)
		if kind == "" and not _terrain.has_tile(PLANT_CELL):
			_destroy_seen = true
			print("[CutterOverHazardCellTest] destroy seen frame=%d" % _frame)
		else:
			return
	# (2) hazard monitoring true 유지.
	if not is_instance_valid(_sticky):
		_fail("(2) sticky hazard 노드 free됨 — Cutter destroy가 hazard registry 침범")
		return
	if not _sticky.monitoring:
		_fail("(2) sticky.monitoring=false — kind erase가 hazard registry 영향 (D4 invariant 위반)")
		return
	# (3) ant 통과 후 is_stuck() true.
	if _ant.is_stuck():
		print("[CutterOverHazardCellTest] PASS frame=%d ant_pos=%s sticky_remaining=%f" % [
			_frame, _ant.global_position, _ant._sticky_remaining
		])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[CutterOverHazardCellTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
