extends Node

# 막대과자 사다리 후속 개미 통행 (LadderClimbState) 격리 검증 (2026-06-03).
# 시전 개미 1마리에게만 sand_mound 부여 → rung 기둥 건설. 그 뒤 **시전하지 않은** 후속 개미가
# rung 벽을 자동으로 타고 레지 위로 올라서는지(LadderClimbState) 검증한다.
#
# PASS: 레지 상단(걷는 면, y <= LEDGE_ROW*cs) 위에 도달한(on_floor) **서로 다른 개미 2마리 이상** 관측.
#   구(舊) 코어는 시전 개미 1마리만 등반 가능 → 1마리. follower 통행 추가 시 2마리+.
# dev_sand_mound_layout: 레지 row17(x=11..40), 바닥 row22, cell_size=32. 시전 col=13(TRIGGER_X 420).

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 420.0   # cell 13 — 레지(x>=11) 바로 아래에서 시전.
const LEDGE_ROW: int = 17

var _terrain: Terrain = null
var _cast_ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _on_ledge_ids: Dictionary = {}   # instance_id → true (레지 상단 도달 관측)

func _ready() -> void:
	print("[LadderFollowerClimbTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_observe_ledge()
	if _on_ledge_ids.size() >= 2:
		print("[LadderFollowerClimbTest] PASS — %d ants reached ledge top (caster + follower) frame=%d" % [_on_ledge_ids.size(), _frame])
		_result_emitted = true
		get_tree().quit(0)
		return
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — on_ledge=%d applied=%s tile_count=%d" % [_on_ledge_ids.size(), _applied, _tile_count()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../SandMoundStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _apply_when_ready() -> void:
	if _applied or _terrain == null:
		return
	# 첫 번째로 시전 조건(walker·on_floor·TRIGGER_X 도달)을 만족하는 개미에게만 부여.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if a.global_position.x < TRIGGER_X or not a.is_on_floor():
			continue
		var skill: SandMoundSkill = SandMoundSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_cast_ant = a
		_applied = true
		print("[LadderFollowerClimbTest] applied sand_mound to caster id=%d frame=%d pos=%s" % [a.get_instance_id(), _frame, a.global_position])
		return

func _observe_ledge() -> void:
	if _terrain == null:
		return
	var cs: int = _terrain.cell_size
	var ledge_top_y: float = float(LEDGE_ROW * cs)
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		# 레지 걷는 면(row17 상단) 이상으로 올라섰고 발판에 선 개미만 집계 — 바닥(row22) 보행 개미 제외.
		if a.global_position.y <= ledge_top_y + 8.0 and a.is_on_floor():
			_on_ledge_ids[a.get_instance_id()] = true

func _tile_count() -> int:
	return _terrain.tile_count() if _terrain != null else -1

func _fail(msg: String) -> void:
	print("[LadderFollowerClimbTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
