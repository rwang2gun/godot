extends Node

# Phase 20 — D-2 회귀 가드. carrying ant가 Sticky 진입 시:
#   (a) has_candy=true 유지 (LostState 안 됨 — 끈끈이는 hazard 아닌 delay)
#   (b) in_transit_pieces 변화 없음 (stuck 중 transit 안 끝남)
#   (c) lost_pieces 변화 없음 (사탕 손실 없음)
#   (d) timer 만료 후 carry 정상 재개 → home 도달 → saved
#
# StickyTest.tscn 사용 — ants는 home→candy 도중 sticky stuck 1차, 그 후 candy 픽업, 돌아오는 길에 sticky stuck 2차(carrying).
# 2차 stuck 시점 sample 캡처 + saved >= 1 시 PASS.

const DEADLINE_FRAMES: int = 7200   # 120초 — 왕복 sticky 2회 + 여유

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false
var _stuck_carrying_seen: bool = false
var _sfx_sticky_glue_count: int = 0

func _ready() -> void:
	print("[StickyCarryingPreservedTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)
	EventBus.sfx_request.connect(_on_sfx)

func _on_sfx(id: StringName) -> void:
	if id == &"sticky_glue":
		_sfx_sticky_glue_count += 1

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1
	_ensure_stage()
	_observe()
	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — saved=%d lost=%d carrying_stuck_seen=%s" % [
			_score.saved_pieces if _score else -1,
			_score.lost_pieces if _score else -1,
			_stuck_carrying_seen,
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
	var inv_ok: bool = (_score.saved_pieces + _score.in_transit_pieces + _score.lost_pieces) <= _score.original_hp
	if not inv_ok:
		_fail("ScoreSystem invariant broken")
		return
	# carrying 감속 시점 캡처: has_candy=true && is_slowed=true.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.has_candy and a.is_slowed():
			if not _stuck_carrying_seen:
				print("[StickyCarryingPreservedTest] carrying slowed observed frame=%d ant=%s in_transit=%d" % [
					_frame_count, a.name, _score.in_transit_pieces,
				])
			_stuck_carrying_seen = true
			# carrying 감속 중 in_transit_pieces == 1 이상 + lost_pieces 무변.
			if _score.in_transit_pieces < 1:
				_fail("carrying slowed observed but in_transit_pieces=%d (expected >=1)" % _score.in_transit_pieces)
				return
	# PASS: 1+ carrying stuck 관찰 + saved >= 1 (carry 정상 재개 + home 도달).
	if _stuck_carrying_seen and _score.saved_pieces >= 1:
		if _score.lost_pieces != 0:
			_fail("expected lost_pieces=0 (sticky는 delay뿐) but got %d" % _score.lost_pieces)
			return
		if _sfx_sticky_glue_count < 1:
			_fail("expected sfx_request(sticky_glue) >= 1 but got %d" % _sfx_sticky_glue_count)
			return
		print("[StickyCarryingPreservedTest] PASS frame=%d saved=%d lost=%d sfx_glue=%d" % [
			_frame_count, _score.saved_pieces, _score.lost_pieces, _sfx_sticky_glue_count,
		])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	if _result_emitted: return
	print("[StickyCarryingPreservedTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
