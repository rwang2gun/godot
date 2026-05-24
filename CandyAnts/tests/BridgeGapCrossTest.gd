extends Node

# Phase 16 — Bridge 4-cell 갭 가로지름 + 자연 종료 (_far_side_floor_reached 또는 add_tile rejection).
# PASS: 40초 내 saved_pieces >= 1 AND tile_count == 4 (갭 폭 정확)
# Stage_cleared 미대기 (다른 ant들 skill 미적용 → 부분 클리어 가능).

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 330.0   # cell 10 (320..351), 좌측 platform 끝

var _ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null
var _stage: Node = null

func _ready() -> void:
	EventBus.stage_failed.connect(_on_failed)
	print("[BridgeGapCrossTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_poll_saved()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — tile_count=%d saved=%d" % [_tile_count(), _saved_pieces()])

func _poll_saved() -> void:
	if not _applied:
		return
	var saved: int = _saved_pieces()
	var tc: int = _tile_count()
	if saved >= 1 and tc == 4:
		print("[BridgeGapCrossTest] PASS saved=%d tile_count=%d frame=%d" % [saved, tc, _frame])
		_result_emitted = true
		get_tree().quit(0)

func _saved_pieces() -> int:
	if _stage == null or _stage.get("score_system") == null:
		return -1
	return (_stage.score_system as ScoreSystem).saved_pieces

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../BridgeStage")
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
	var skill: BridgeSkill = BridgeSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	print("[BridgeGapCrossTest] applied bridge at frame=%d pos=%s" % [_frame, _ant.global_position])

func _on_failed(result: Dictionary) -> void:
	if _result_emitted:
		return
	var saved: int = _saved_pieces()
	var tc: int = _tile_count()
	if saved >= 1 and tc == 4:
		print("[BridgeGapCrossTest] PASS (post-failed signal) saved=%d tile_count=%d reason=%s" % [saved, tc, result["reason"]])
		_result_emitted = true
		get_tree().quit(0)
		return
	_fail("stage_failed reason=%s saved=%d tile_count=%d" % [result["reason"], saved, tc])

func _tile_count() -> int:
	if _terrain == null:
		return -1
	return _terrain.tile_count()

func _fail(msg: String) -> void:
	print("[BridgeGapCrossTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
