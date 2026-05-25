extends Node

# Phase 20 — D-1 회귀 가드. carrying ant가 Water 진입 시 `lost_pieces += 1` +
# `in_transit -= 1` + `candy_piece_lost` emit + `sfx_request(&"candy_lost")` emit 검증.
# WaterAfterCandyTest.tscn 사용 — spawn 위치가 candy 우측에 있어 ants는 빈손으로 candy 도달,
# pick + flip 후 LEFT 방향으로 돌아오는 길에 Water hit.

const DEADLINE_FRAMES: int = 5400   # 90초

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false
var _candy_lost_emits: int = 0
var _sfx_lost_emits: int = 0

func _ready() -> void:
	print("[WaterHazardLossCarryingTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)
	EventBus.candy_piece_lost.connect(_on_candy_lost)
	EventBus.sfx_request.connect(_on_sfx)

func _on_candy_lost(_by_ant: Node) -> void:
	_candy_lost_emits += 1

func _on_sfx(id: StringName) -> void:
	if id == &"candy_lost":
		_sfx_lost_emits += 1

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1
	_ensure_stage()
	_observe()
	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — saved=%d lost=%d candy_lost_emits=%d sfx_lost=%d" % [
			_score.saved_pieces if _score else -1,
			_score.lost_pieces if _score else -1,
			_candy_lost_emits, _sfx_lost_emits,
		])

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

func _observe() -> void:
	if _score == null:
		return
	# ScoreSystem invariant.
	var inv_ok: bool = (_score.saved_pieces + _score.in_transit_pieces + _score.lost_pieces) <= _score.original_hp
	if not inv_ok:
		_fail("ScoreSystem invariant broken: saved=%d in_transit=%d lost=%d original=%d" % [
			_score.saved_pieces, _score.in_transit_pieces, _score.lost_pieces, _score.original_hp,
		])
		return
	# 모든 candy 처리 완료 + in_transit==0 + lost>=1 시 PASS.
	if _score.lost_pieces >= 1 and _score.in_transit_pieces == 0 and _frame_count > 120:
		# 추가 검증: candy_piece_lost emit 횟수와 lost_pieces 일치 + sfx candy_lost emit 동일.
		if _candy_lost_emits != _score.lost_pieces:
			_fail("candy_piece_lost emit count(%d) != lost_pieces(%d)" % [_candy_lost_emits, _score.lost_pieces])
			return
		if _sfx_lost_emits != _score.lost_pieces:
			_fail("sfx_request(candy_lost) count(%d) != lost_pieces(%d)" % [_sfx_lost_emits, _score.lost_pieces])
			return
		print("[WaterHazardLossCarryingTest] PASS frame=%d saved=%d lost=%d in_transit=%d original=%d" % [
			_frame_count, _score.saved_pieces, _score.lost_pieces,
			_score.in_transit_pieces, _score.original_hp,
		])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	if _result_emitted: return
	print("[WaterHazardLossCarryingTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
