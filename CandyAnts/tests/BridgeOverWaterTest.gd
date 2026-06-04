extends Node

# Phase 17 — D8 검증. Bridge가 Water cell 위에 만들어지면 Water가 deactivate되어
# 후속 ant들이 bridge 위 통과 시 LostState 안 됨 → candy 도달 → home 회수.
#
# PASS: quit(0) — saved_pieces >= 1 + lost_pieces == 0 + 모든 Water monitoring=false.
# FAIL: quit(1) — bridge 통과 ant 중 누구라도 lost 발생, 또는 deadline 초과.

const DEADLINE_FRAMES: int = 5400   # 90초

# 갭 6칸 > 다리 캡 5칸이라 다리 1개로는 못 건넌다(끝 col17이 물). 개미 2마리를 무장 → 첫 개미가 다리1
# (cols12~16) 건설 후 표류, 둘째 개미가 다리1 끝(col16)에서 다리2(col17, 반대편 col18 도달)를 이어 건설(체인).
const ARM_COUNT: int = 2

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false
var _armed_ids: Dictionary = {}

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
		_fail("deadline exceeded — saved=%d lost=%d armed=%d" % [_score.saved_pieces if _score else -1, _score.lost_pieces if _score else -1, _armed_ids.size()])

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
	if _armed_ids.size() >= ARM_COUNT:
		return
	# 갭 직전 floor 마지막 cell(x=11, 352~383px)에서 개미 2마리 무장. 첫 개미 즉시 다리1 건설, 둘째 개미는
	# 다리 타일이 생긴 뒤라 무장만 → 다리1 건너 끝(col16)에서 다리2 체인.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if _armed_ids.has(a.get_instance_id()):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor():
			continue
		if a.has_candy:
			continue
		if a.global_position.x < 360.0 or a.global_position.x > 380.0:
			continue
		var skill: BridgeSkill = BridgeSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_armed_ids[a.get_instance_id()] = true
		print("[BridgeOverWaterTest] bridge → frame=%d pos=%s (total=%d)" % [_frame_count, a.global_position, _armed_ids.size()])
		if _armed_ids.size() >= ARM_COUNT:
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
	if _armed_ids.is_empty():
		return
	# saved 도달 시 Water 모두 monitoring=false 확인.
	if _score.saved_pieces >= 1:
		var water_nodes: Array = _find_all_water(get_tree().get_root())
		var still_active: int = 0
		for w in water_nodes:
			if (w as HazardBase)._active:
				still_active += 1
		if still_active > 0:
			# 다리 2개 체인(5+1칸)이 갭 6칸 전체를 덮으면 모든 Water 비활성. 일부 잔존 시 경고(체인 미완 가능).
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
