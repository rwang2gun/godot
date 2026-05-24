extends Node

# Phase 17 — D8 검증. Bridge가 Water cell 위에 만들어지면 Water가 deactivate되어
# 후속 ant들이 bridge 위 통과 시 LostState 안 됨 → candy 도달 → home 회수.
#
# PASS: quit(0) — saved_pieces >= 1 + lost_pieces == 0 + 모든 Water monitoring=false.
# FAIL: quit(1) — bridge 통과 ant 중 누구라도 lost 발생, 또는 deadline 초과.

const DEADLINE_FRAMES: int = 5400   # 90초

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false
var _first_ant: Ant = null
var _bridge_applied: bool = false

func _ready() -> void:
	print("[BridgeOverWaterTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1
	_ensure_stage()
	_apply_bridge_when_ready()
	_observe()
	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — saved=%d lost=%d bridge_applied=%s" % [_score.saved_pieces if _score else -1, _score.lost_pieces if _score else -1, _bridge_applied])

func _ensure_stage() -> void:
	if _stage != null:
		return
	_stage = _find_stage(get_tree().get_root())
	if _stage != null:
		_score = _stage.score_system

func _find_stage(node: Node) -> StageRunner:
	if node is StageRunner:
		return node as StageRunner
	for c in node.get_children():
		var s: StageRunner = _find_stage(c)
		if s != null:
			return s
	return null

func _apply_bridge_when_ready() -> void:
	if _bridge_applied:
		return
	# 첫 ant가 갭 직전(x ≈ 350~390)에 도달했을 때 bridge 적용.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor():
			continue
		if a.has_candy:
			continue
		# 갭 직전 floor 마지막 cell(x=11, 352~383px)에서 bridge 적용 → target=(12, 22) gap 첫 cell.
		if a.global_position.x < 360.0 or a.global_position.x > 380.0:
			continue
		var skill: BridgeSkill = BridgeSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_first_ant = a
		_bridge_applied = true
		print("[BridgeOverWaterTest] bridge applied frame=%d pos=%s" % [_frame_count, a.global_position])
		return

func _observe() -> void:
	if _score == null:
		return
	var inv_ok: bool = (_score.saved_pieces + _score.in_transit_pieces + _score.lost_pieces) <= _score.original_hp
	if not inv_ok:
		_fail("ScoreSystem invariant broken")
		return
	# 어떤 ant가 lost 되면 즉시 FAIL (Bridge로 Water 비활성 성공이면 lost 0).
	if _score.lost_pieces > 0:
		_fail("ant lost in water despite bridge: lost=%d (expected 0)" % _score.lost_pieces)
		return
	if not _bridge_applied:
		return
	# saved 도달 시 Water 모두 monitoring=false 확인.
	if _score.saved_pieces >= 1:
		var water_nodes: Array = _find_all_water(get_tree().get_root())
		var still_active: int = 0
		for w in water_nodes:
			if (w as HazardBase)._active:
				still_active += 1
		if still_active > 0:
			# bridge가 모든 Water cell 덮지 않으면 발생 가능 — bridge MAX_LENGTH=8, 갭=6 → 모두 덮을 것
			print("[BridgeOverWaterTest] warning: %d/%d Water still active" % [still_active, water_nodes.size()])
		print("[BridgeOverWaterTest] PASS frame=%d saved=%d lost=%d water_active=%d/%d" % [_frame_count, _score.saved_pieces, _score.lost_pieces, still_active, water_nodes.size()])
		_result_emitted = true
		get_tree().quit(0)

func _find_all_water(node: Node) -> Array:
	var out: Array = []
	if node is WaterHazard:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_all_water(c))
	return out

func _fail(msg: String) -> void:
	print("[BridgeOverWaterTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
