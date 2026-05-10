extends Node

# Phase 4 통합 회귀 테스트.
# §D-1 첫 4개 ant direction 패턴 [+1,-1,+1,-1] (Codex MEDIUM 대응)
# §D-2 carrying ant에 BlockerSkill.can_apply false 보장 (Codex HIGH 대응)
# §D-3 첫 +1 ant 우측 cliff 직전에 BlockerSkill.apply → stage_cleared score >= 0.85
# PASS: get_tree().quit(0). FAIL: quit(1).

const TRIGGER_X: float = 1750.0   # 첫 +1 ant가 도달하면 Blocker 적용 (cliff x=1820 직전 안전구간)
const PASS_SCORE: float = 0.85
const ALTERNATE_PATTERN: Array[int] = [1, -1, 1, -1]

var _seen_ants: Array[Ant] = []
var _captured_directions: Array[int] = []
var _direction_check_done: bool = false
var _blocker_applied: bool = false
var _carrying_check_done: bool = false
var _result_emitted: bool = false

func _ready() -> void:
	print("[Phase4Test] driver ready, trigger_x=", TRIGGER_X, " pass_score=", PASS_SCORE)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)

func _process(_delta: float) -> void:
	if _result_emitted:
		return
	_capture_new_ants()
	_check_alternation_once()
	_apply_blocker_if_ready()
	_check_carrying_rejection_once()

func _capture_new_ants() -> void:
	if _direction_check_done:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or a in _seen_ants:
			continue
		_seen_ants.append(a)
		if _captured_directions.size() < ALTERNATE_PATTERN.size():
			_captured_directions.append(a.direction)
			print("[Phase4Test] captured ant #", _seen_ants.size() - 1,
				" direction=", a.direction, " pos=", a.global_position)

func _check_alternation_once() -> void:
	if _direction_check_done:
		return
	if _captured_directions.size() < ALTERNATE_PATTERN.size():
		return
	_direction_check_done = true
	if _captured_directions != ALTERNATE_PATTERN:
		print("[Phase4Test] FAIL §D-1 alternation expected=",
			ALTERNATE_PATTERN, " got=", _captured_directions)
		_result_emitted = true
		get_tree().quit(1)
		return
	print("[Phase4Test] PASS §D-1 alternation=", _captured_directions)

func _apply_blocker_if_ready() -> void:
	if _blocker_applied:
		return
	for a in _seen_ants:
		if a == null or not is_instance_valid(a):
			continue
		if a.direction != 1:
			continue
		if a.has_been_carrying:
			continue
		if a.global_position.x < TRIGGER_X:
			continue
		var blocker: BlockerSkill = BlockerSkill.new()
		if not blocker.can_apply(a):
			continue
		blocker.apply(a)
		_blocker_applied = true
		print("[Phase4Test] applied Blocker to ", a.name, " at x=", a.global_position.x)
		return

func _check_carrying_rejection_once() -> void:
	if _carrying_check_done:
		return
	for a in _seen_ants:
		if a == null or not is_instance_valid(a):
			continue
		if not a.has_candy:
			continue
		var blocker: BlockerSkill = BlockerSkill.new()
		var allowed: bool = blocker.can_apply(a)
		_carrying_check_done = true
		if allowed:
			print("[Phase4Test] FAIL §D-2 carrying ant accepted by BlockerSkill — has_candy=",
				a.has_candy, " state=", a.state_machine.current_state)
			_result_emitted = true
			get_tree().quit(1)
			return
		print("[Phase4Test] PASS §D-2 carrying ant rejected by BlockerSkill")
		return

func _on_cleared(result: Dictionary) -> void:
	if _result_emitted:
		return
	_result_emitted = true
	var score: float = result["score"]
	print("[Phase4Test] cleared score=", score)
	if not _direction_check_done:
		print("[Phase4Test] FAIL §D-1 not completed before clear")
		get_tree().quit(1)
		return
	if not _carrying_check_done:
		print("[Phase4Test] FAIL §D-2 not completed before clear")
		get_tree().quit(1)
		return
	if score >= PASS_SCORE:
		print("[Phase4Test] PASS")
		get_tree().quit(0)
	else:
		print("[Phase4Test] FAIL low_score=", score, " < ", PASS_SCORE)
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _result_emitted:
		return
	_result_emitted = true
	var reason: String = result["reason"]
	print("[Phase4Test] failed reason=", reason)
	print("[Phase4Test] FAIL")
	get_tree().quit(1)
