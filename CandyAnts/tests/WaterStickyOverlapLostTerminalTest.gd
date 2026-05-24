extends Node

# Phase 17 — codex R1-H2 회귀 가드. 같은 cell의 Water + Sticky 진입 시 Godot signal queue
# 순서는 비결정이지만 terminal=Lost는 결정론. _sticky_remaining 값은 검증 안 함.
#
# PASS: quit(0) — 모든 ant queue_free 완료 (is_alive false) + lost_pieces 변화량이 carrying 여부와 일치
#                 (본 테스트는 빈손이므로 lost==0) + ScoreSystem invariant.
# FAIL: quit(1) — ant 영구 생존 (timer 만료 후 Water 진입 못함), 또는 invariant 위반, deadline 초과.

const DEADLINE_FRAMES: int = 1800

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[WaterStickyOverlapLostTerminalTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1
	_ensure_stage()
	_observe()
	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — ants_alive=%d saved=%d lost=%d" % [_living_ant_count(), _score.saved_pieces if _score else -1, _score.lost_pieces if _score else -1])

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

func _living_ant_count() -> int:
	var count: int = 0
	for n in get_tree().get_nodes_in_group("ants"):
		if n != null and is_instance_valid(n):
			count += 1
	return count

func _observe() -> void:
	if _score == null:
		return
	var inv_ok: bool = (_score.saved_pieces + _score.in_transit_pieces + _score.lost_pieces) <= _score.original_hp
	if not inv_ok:
		_fail("ScoreSystem invariant broken")
		return
	# 모든 ant가 LostState로 queue_free 완료.
	var alive: int = _living_ant_count()
	if alive == 0 and _frame_count > 120:
		# 빈손 진입이므로 lost_pieces == 0 + saved == 0.
		if _score.saved_pieces != 0:
			_fail("expected saved=0 (no ant reached candy) but saved=%d" % _score.saved_pieces)
			return
		if _score.lost_pieces != 0:
			_fail("expected lost=0 (empty-hand entry) but lost=%d" % _score.lost_pieces)
			return
		print("[WaterStickyOverlapLostTerminalTest] PASS frame=%d saved=%d lost=%d (terminal Lost reached deterministically)" % [_frame_count, _score.saved_pieces, _score.lost_pieces])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[WaterStickyOverlapLostTerminalTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
