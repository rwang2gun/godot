extends Node

# Phase 17 — codex R1-H1 회귀 가드. 같은 cell에 Water+Sticky overlap. Bridge가 두 hazard 모두
# deactivate해야 함 (Terrain._hazards_by_cell이 Array 저장). registration 순서 무관 robust.
#
# PASS: quit(0) — saved_pieces >= 1 + lost_pieces == 0 + 모든 overlap cell의 Water/Sticky 둘 다 _active=false.
# FAIL: quit(1) — bridge 통과 ant 중 lost 발생, 또는 어떤 hazard라도 _active=true 잔존, deadline 초과.

const DEADLINE_FRAMES: int = 5400   # 90초

# 갭 6칸 > 다리 캡 5칸이라 다리 1개로는 끝 col17을 못 덮는다. 개미 2마리를 무장 → 다리1(cols12~16) + 체인
# 다리2(col17)로 갭 6칸 전체를 덮어 Water+Sticky 12개 hazard 모두 비활성화한다.
const ARM_COUNT: int = 2

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false
var _armed_ids: Dictionary = {}

func _ready() -> void:
	print("[BridgeOverWaterStickyOverlapTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

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
	# 갭 직전 floor 마지막 cell(x=11, 352~383px)에서 개미 2마리 무장(첫 즉시건설 + 둘째 체인).
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
		if a.is_stuck():
			continue
		if a.global_position.x < 360.0 or a.global_position.x > 380.0:
			continue
		var skill: BridgeSkill = BridgeSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_armed_ids[a.get_instance_id()] = true
		print("[BridgeOverWaterStickyOverlapTest] bridge → frame=%d pos=%s (total=%d)" % [_frame_count, a.global_position, _armed_ids.size()])
		if _armed_ids.size() >= ARM_COUNT:
			return

func _observe() -> void:
	if _score == null:
		return
	var inv_ok: bool = (_score.saved_pieces + _score.in_transit_pieces + _score.lost_pieces) <= _score.original_hp
	if not inv_ok:
		_fail("ScoreSystem invariant broken")
		return
	if _score.lost_pieces > 0:
		_fail("ant lost despite bridge over overlap: lost=%d" % _score.lost_pieces)
		return
	if _armed_ids.is_empty():
		return
	if _score.saved_pieces >= 1:
		# 모든 overlap cell의 Water + Sticky monitoring=false 확인 (R1-H1 회귀 가드 핵심).
		var hazards: Array = _find_all_hazards(get_tree().get_root())
		var water_active: int = 0
		var sticky_active: int = 0
		for h in hazards:
			var hb: HazardBase = h as HazardBase
			if hb == null:
				continue
			if not hb._active:
				continue
			if hb is WaterHazard:
				water_active += 1
			elif hb is StickyHazard:
				sticky_active += 1
		# 갭 6 cells의 12개 hazard (Water 6 + Sticky 6) 모두 비활성이어야 함.
		# 단 ant 진로에 모든 cell이 닿는지에 의존 — 다리 2개 체인(5+1칸)이 갭 6칸 전체에 placement → 12개 hazard 모두 deactivate.
		if water_active > 0 or sticky_active > 0:
			_fail("R1-H1 regression: water_active=%d sticky_active=%d (expected 0/0)" % [water_active, sticky_active])
			return
		print("[BridgeOverWaterStickyOverlapTest] PASS frame=%d saved=%d lost=%d water/sticky all deactivated" % [_frame_count, _score.saved_pieces, _score.lost_pieces])
		_result_emitted = true
		get_tree().quit(0)

func _find_all_hazards(node: Node) -> Array:
	var out: Array = []
	if node is HazardBase:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_all_hazards(c))
	return out

func _fail(msg: String) -> void:
	print("[BridgeOverWaterStickyOverlapTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
