extends Node

# Phase 19 — Cutter 4-cell vine 통과 + candy 회수.
# 시나리오: home(5,21) → walker → vine(12,21..15,21) 직면 → cutter 적용 →
#          4 cell plant 제거 → walker 진행 → candy(25,21) → carrying → home → saved+1.
#
# PASS (30s 내):
#  (1) saved_pieces >= 1
#  (2) vine cell 4개 (12,21)..(15,21) 모두 get_cell_kind == "" (제거 확인)
#  (3) has_tile(cell) == false for each vine cell (dynamic _placed 영역 0)
#  (4) floor row (12,22)..(15,22) cell 무변동 (kind="earth" 유지)

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 11.0 * 32.0   # cell 11 left edge — vine 직전

var _ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null
var _stage: Node = null

func _ready() -> void:
	print("[CutterCutThroughVineTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_poll_pass()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — saved=%d applied=%s" % [_saved_pieces(), str(_applied)])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../CutterStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_ant = a
			return

func _apply_when_ready() -> void:
	if _applied or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	var skill: CutterSkill = CutterSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	print("[CutterCutThroughVineTest] applied cutter at frame=%d pos=%s" % [_frame, _ant.global_position])

func _poll_pass() -> void:
	if not _applied:
		return
	var saved: int = _saved_pieces()
	if saved < 1:
		return
	for x in range(12, 16):
		var cell: Vector2i = Vector2i(x, 21)
		var kind: String = _terrain.get_cell_kind(cell)
		if kind != "":
			_fail("vine cell %s 잔존 (kind=%s)" % [str(cell), kind])
			return
		if _terrain.has_tile(cell):
			_fail("vine cell %s has_tile=true" % str(cell))
			return
	for x in range(12, 16):
		var floor_cell: Vector2i = Vector2i(x, 22)
		var floor_kind: String = _terrain.get_cell_kind(floor_cell)
		if floor_kind != "earth":
			_fail("floor cell %s 변동 — kind=%s (cutter가 floor row 침범)" % [str(floor_cell), floor_kind])
			return
	print("[CutterCutThroughVineTest] PASS saved=%d frame=%d" % [saved, _frame])
	_result_emitted = true
	get_tree().quit(0)

func _saved_pieces() -> int:
	if _stage == null or _stage.get("score_system") == null:
		return -1
	return (_stage.score_system as ScoreSystem).saved_pieces

func _fail(msg: String) -> void:
	push_error("[CutterCutThroughVineTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
