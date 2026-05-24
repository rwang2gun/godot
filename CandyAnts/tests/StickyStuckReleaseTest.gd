extends Node

# Phase 17 — StickyHazard stuck + 시간 경과 자동 해방 검증.
# 첫 ant가 Sticky cell 진입 → is_stuck()==true + velocity.x≈0 약 3초.
# 3.5초 후 is_stuck()==false → candy 도달 → home 회수.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초.

const DEADLINE_FRAMES: int = 5000   # 약 83초 — ant 왕복 시 sticky cell 2회 stuck 시간 포함

var _stage: StageRunner = null
var _score: ScoreSystem = null
var _frame_count: int = 0
var _result_emitted: bool = false
var _stuck_first_frame: int = -1
var _ever_stuck: bool = false

func _ready() -> void:
	print("[StickyStuckReleaseTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1
	_ensure_stage()
	_observe()
	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — saved=%d ever_stuck=%s" % [_score.saved_pieces if _score else -1, _ever_stuck])

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
	# 매 1초마다 첫 ant 상태 디버그.
	if _frame_count % 60 == 0:
		var first: Ant = null
		for n in get_tree().get_nodes_in_group("ants"):
			first = n as Ant
			if first != null:
				break
		if first != null:
			print("[Sticky.debug] frame=%d ant.pos=%s stuck=%s remaining=%.2f vel=%s state=%s" % [_frame_count, first.global_position, first.is_stuck(), first._sticky_remaining, first.velocity, first.state_machine.current_state.get_script().resource_path.get_file() if first.state_machine and first.state_machine.current_state else "null"])
	# 임의의 ant가 stuck 상태인지 확인.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.is_stuck():
			if _stuck_first_frame < 0:
				_stuck_first_frame = _frame_count
				print("[StickyStuckReleaseTest] stuck observed at frame=%d _sticky_remaining=%.2f" % [_frame_count, a._sticky_remaining])
			_ever_stuck = true
			# stuck 중 velocity.x ≈ 0 확인 (느슨 — 중력 가속도로 y는 변동).
			if absf(a.velocity.x) > 1.0:
				_fail("stuck ant velocity.x non-zero: %.2f" % a.velocity.x)
				return
	# saved 도달 시 PASS (적어도 1 ant가 stuck → 해방 → candy → home 완주 검증).
	if _ever_stuck and _score.saved_pieces >= 1:
		print("[StickyStuckReleaseTest] PASS frame=%d saved=%d lost=%d stuck_first=%d" % [_frame_count, _score.saved_pieces, _score.lost_pieces, _stuck_first_frame])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[StickyStuckReleaseTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
