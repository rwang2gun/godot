extends Node

# Phase 16 — Bridge가 12-cell 갭에서 MAX_LENGTH=8 도달 시 미완성 종료 + D7 잔재 유지 검증.
# PASS: 50초 내 tile_count == 8 AND saved_pieces == 0

const DEADLINE_FRAMES: int = 3000
const TRIGGER_X: float = 330.0
const POST_APPLY_WAIT_FRAMES: int = 600   # 10초 (apply 후 bridge MAX_LENGTH 소진까지 약 1.6초)

var _ant: Ant = null
var _applied: bool = false
var _applied_frame: int = 0
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	print("[BridgeGapTooLongTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_complete()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — tile_count=%d" % _tile_count())

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../BridgeTooLongStage")
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
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	var skill: BridgeSkill = BridgeSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	_applied_frame = _frame
	print("[BridgeGapTooLongTest] applied bridge at frame=%d pos=%s" % [_frame, _ant.global_position])

func _check_complete() -> void:
	if not _applied:
		return
	if _frame - _applied_frame < POST_APPLY_WAIT_FRAMES:
		return
	# After MAX_LENGTH soak, ant fell from bridge end → eventually walker → faller.
	# We don't wait for stage_cleared/failed; we just check tile_count and saved_pieces.
	var tc: int = _tile_count()
	var stage: Node = get_node_or_null("../BridgeTooLongStage")
	var saved: int = -1
	if stage != null and stage.get("score_system") != null:
		saved = (stage.score_system as ScoreSystem).saved_pieces
	print("[BridgeGapTooLongTest] post-soak tile_count=%d saved=%d" % [tc, saved])
	if tc == 8 and saved == 0:
		_pass()
	else:
		_fail("tile_count=%d (need==8) saved=%d (need==0)" % [tc, saved])

func _tile_count() -> int:
	if _terrain == null:
		return -1
	return _terrain.tile_count()

func _pass() -> void:
	print("[BridgeGapTooLongTest] PASS")
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[BridgeGapTooLongTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
