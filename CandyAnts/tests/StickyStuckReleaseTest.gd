extends Node

# 끈끈이 감속 존 검증(2026-06-07 재설계). 첫 ant가 Sticky cell과 겹치면 is_slowed()==true +
# velocity.x가 평소(walk_speed)보다 느려짐(정지 아님). 끈끈이를 벗어나면 정상 속도 → candy 도달 → home 회수.
#
# PASS: quit(0). FAIL: quit(1).

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
			print("[Sticky.debug] frame=%d ant.pos=%s slowed=%s vel=%s state=%s" % [_frame_count, first.global_position, first.is_slowed(), first.velocity, first.state_machine.current_state.get_script().resource_path.get_file() if first.state_machine and first.state_machine.current_state else "null"])
	# 임의의 ant가 끈끈이로 감속 중인지 확인.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.is_slowed():
			if _stuck_first_frame < 0:
				_stuck_first_frame = _frame_count
				print("[StickyStuckReleaseTest] slowed observed at frame=%d vel.x=%.2f" % [_frame_count, a.velocity.x])
			_ever_stuck = true
			# 감속 중 |velocity.x| 가 평소(walk_speed)보다 느려짐 확인 — 정지가 아니라 느린 보행.
			# 슬로우 속도 = walk_speed * STICKY_SPEED_MULT (carry면 더 느림) → 상한에 여유 1.0px 추가.
			if absf(a.velocity.x) > a.walk_speed * Ant.STICKY_SPEED_MULT + 1.0:
				_fail("slowed ant velocity.x not reduced: %.2f (expected <= %.2f)" % [a.velocity.x, a.walk_speed * Ant.STICKY_SPEED_MULT + 1.0])
				return
	# saved 도달 시 PASS (적어도 1 ant가 감속 → 통과 → candy → home 완주 검증).
	if _ever_stuck and _score.saved_pieces >= 1:
		print("[StickyStuckReleaseTest] PASS frame=%d saved=%d lost=%d slowed_first=%d" % [_frame_count, _score.saved_pieces, _score.lost_pieces, _stuck_first_frame])
		_result_emitted = true
		get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[StickyStuckReleaseTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
