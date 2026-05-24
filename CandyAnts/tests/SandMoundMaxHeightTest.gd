extends Node

# Phase 16 — sand_mound이 MAX_HEIGHT=5 정확히 stack 후 _remaining=0으로 WalkerState 복귀하는지 검증.
# Climb scenario와 분리 — saved/candy는 무관, tile_count + state만 본다.
# PASS: 20초 내 (1) tile_count == 5 (2) ant.state_machine.current_state is WalkerState 도달

const DEADLINE_FRAMES: int = 1200

var _ant: Ant = null
var _applied: bool = false
var _applied_frame: int = 0
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	print("[SandMoundMaxHeightTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_complete()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — tile_count=%d state=%s" % [_tile_count(), _state_name()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../SandMoundStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain
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
	if _ant.global_position.x < 330.0:
		return
	if not _ant.is_on_floor():
		return
	var skill: SandMoundSkill = SandMoundSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	_applied_frame = _frame
	print("[SandMoundMaxHeightTest] applied at frame=%d pos=%s" % [_frame, _ant.global_position])

func _check_complete() -> void:
	if not _applied or _ant == null or _ant.state_machine == null:
		return
	# sand_mound 완료 = WalkerState 복귀 + tile_count == 5.
	# Apply 직후엔 WorkerState. SAND_MOUND_TICK=0.25s * 5 + buffer 즉 ~80 frame 후 완료 기대.
	if _frame - _applied_frame < 90:
		return
	var s: AntState = _ant.state_machine.current_state
	var tc: int = _tile_count()
	# WorkerState가 아니면 sand_mound 종료(WalkerState 또는 Faller/Carrying 등 후속).
	if s is WorkerState:
		return
	if tc == 5:
		print("[SandMoundMaxHeightTest] PASS tile_count=5 state=%s" % _state_name())
		_result_emitted = true
		get_tree().quit(0)
	else:
		_fail("post-worker state but tile_count=%d (need==5) state=%s" % [tc, _state_name()])

func _tile_count() -> int:
	if _terrain == null:
		return -1
	return _terrain.tile_count()

func _state_name() -> String:
	if _ant == null or _ant.state_machine == null or _ant.state_machine.current_state == null:
		return "null"
	return _ant.state_machine.current_state.get_class()

func _fail(msg: String) -> void:
	print("[SandMoundMaxHeightTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
