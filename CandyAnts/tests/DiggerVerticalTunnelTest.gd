extends Node

# Phase 18 — Digger 수직 굴착 + 자유 낙하 + lower floor 안착 + candy 회수.
#
# Layout deviation (plan v10 §6.2): 물리적 정합을 위해 shaft를 12 cell(column 5, y=22~33)로
# 확장하고 lower floor y=34 전체 solid + home/candy를 lower level에 배치. 이유: 5-cell shaft +
# lower floor (5,27) 가정은 (5,27) 자체가 "earth" 라 digger가 자연 abort 못함(landing 후 다음
# tick에 destroy). 12-cell shaft는 _remaining=0 자연 종료 + lower floor (5,34)에서 ant 안착 →
# Walker 재개. 5 cell 검증 대상은 plan §6.2의 (5,22)~(5,26) 유지.
#
# PASS (30s 내):
#  (1) saved_pieces >= 1
#  (2) shaft cell 5개 (5,22)..(5,26) 모두 get_cell_kind == "" + has_tile == false
#  (3) ant LostState 진입 0건 (hazard 없음)

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 5.0 * 32.0 + 8.0   # cell 5 진입 직후

var _ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null
var _stage: Node = null
var _lost_seen: bool = false

func _ready() -> void:
	print("[DiggerVerticalTunnelTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_lost()
	_poll_pass()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — saved=%d applied=%s" % [_saved_pieces(), str(_applied)])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../DiggerStage")
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
	var skill: DiggerSkill = DiggerSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	print("[DiggerVerticalTunnelTest] applied digger at frame=%d pos=%s" % [_frame, _ant.global_position])

func _check_lost() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state
	if s is LostState:
		_lost_seen = true

func _poll_pass() -> void:
	if not _applied:
		return
	if _lost_seen:
		_fail("ant entered LostState (hazard 없음 — 회귀)")
		return
	var saved: int = _saved_pieces()
	if saved < 1:
		return
	# (2) shaft cell 5개 검증.
	for y in range(22, 27):
		var cell: Vector2i = Vector2i(5, y)
		var kind: String = _terrain.get_cell_kind(cell)
		if kind != "":
			_fail("shaft cell %s 잔존 (kind=%s)" % [str(cell), kind])
			return
		if _terrain.has_tile(cell):
			_fail("shaft cell %s has_tile=true" % str(cell))
			return
	print("[DiggerVerticalTunnelTest] PASS saved=%d frame=%d" % [saved, _frame])
	_result_emitted = true
	get_tree().quit(0)

func _saved_pieces() -> int:
	if _stage == null or _stage.get("score_system") == null:
		return -1
	return (_stage.score_system as ScoreSystem).saved_pieces

func _fail(msg: String) -> void:
	push_error("[DiggerVerticalTunnelTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
