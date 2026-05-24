extends Node

# Phase 17 — WaterHazard 빈손 ant 진입 검증.
# 4 ants 모두 home→candy 도중 Water entry → LostState → queue_free.
# 빈손이라 candy_piece_lost emit 안 됨 → lost_pieces 변화 0, saved_pieces 0, ant 모두 사라짐.
# ScoreSystem invariant 유지.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초 (60fps × 1800 frame).

const DEADLINE_FRAMES: int = 1800

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[WaterHazardLossEmptyHandTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

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
	for n in get_tree().get_nodes_in_group(""):
		pass
	# StageRunner는 root 하위 첫 자식.
	var root: Node = get_tree().get_root()
	_stage = _find_stage(root)
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
	if _stage == null or _score == null:
		return
	# ScoreSystem invariant 매 frame 검증.
	var inv_ok: bool = (_score.saved_pieces + _score.in_transit_pieces + _score.lost_pieces) <= _score.original_hp
	if not inv_ok:
		_fail("ScoreSystem invariant broken: saved=%d in_transit=%d lost=%d original=%d" % [_score.saved_pieces, _score.in_transit_pieces, _score.lost_pieces, _score.original_hp])
		return
	# 모든 ant가 LostState로 queue_free 완료 + AntSpawner._remaining 다 소비됨.
	# spawn 완료 + ants_alive==0 이면 모두 Water entry 처리.
	var alive: int = _living_ant_count()
	if alive == 0 and _frame_count > 120:
		# 빈손 진입이므로 lost_pieces == 0 + saved == 0 검증.
		if _score.saved_pieces != 0:
			_fail("expected saved=0 (no ant reached candy) but saved=%d" % _score.saved_pieces)
			return
		if _score.lost_pieces != 0:
			_fail("expected lost=0 (empty-hand entry emits no candy_piece_lost) but lost=%d" % _score.lost_pieces)
			return
		print("[WaterHazardLossEmptyHandTest] PASS frame=%d saved=%d lost=%d original=%d" % [_frame_count, _score.saved_pieces, _score.lost_pieces, _score.original_hp])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[WaterHazardLossEmptyHandTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
