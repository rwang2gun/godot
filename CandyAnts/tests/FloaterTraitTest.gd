extends Node

# Phase 14 — Floater trait 통합 회귀 테스트.
# 첫 ant에 FloaterSkill 부여 → 절벽 가장자리에서 FallerState 진입 → velocity.y 증가율 ≤ gravity*delta*0.4 5 frame 평균.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초.

const DEADLINE_FRAMES: int = 1800
const FLOATER_THRESHOLD: float = 0.4  # FLOATER_GRAVITY_SCALE 0.3 + margin 0.1
const SAMPLE_FRAMES: int = 5

var _ant: Ant = null
var _floater_applied: bool = false
var _faller_entered_frame: int = -1
var _vy_samples: Array[float] = []
var _last_vy: float = 0.0
var _frame_count: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[FloaterTraitTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_ensure_ant()
	_apply_floater_when_ready()
	_observe_fall()

	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded")

func _ensure_ant() -> void:
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null:
			continue
		_ant = a
		return

func _apply_floater_when_ready() -> void:
	if _floater_applied or _ant == null:
		return
	if _ant.state_machine == null or _ant.state_machine.current_state == null:
		return
	# is_alive() 통과면 즉시 부여 (Walker든 Faller든 OK).
	var skill: FloaterSkill = FloaterSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_floater_applied = true
	print("[FloaterTraitTest] applied floater at frame=%d" % _frame_count)

func _observe_fall() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is FallerState):
		_last_vy = _ant.velocity.y
		return

	if _faller_entered_frame < 0:
		_faller_entered_frame = _frame_count
		_last_vy = _ant.velocity.y
		print("[FloaterTraitTest] entered FallerState at frame=%d vy=%.2f" % [_frame_count, _ant.velocity.y])
		return

	# Faller 진입 후 다음 frame부터 vy delta 샘플링.
	var dy: float = _ant.velocity.y - _last_vy
	_last_vy = _ant.velocity.y
	if dy > 0.0:
		_vy_samples.append(dy)

	if _vy_samples.size() >= SAMPLE_FRAMES:
		_evaluate_success()

func _evaluate_success() -> void:
	var sum: float = 0.0
	for v in _vy_samples:
		sum += v
	var mean: float = sum / float(_vy_samples.size())
	var threshold: float = _ant.gravity * (1.0 / 60.0) * FLOATER_THRESHOLD
	if mean > threshold:
		_fail("mean dvy %.2f > threshold %.2f (samples=%s)" % [mean, threshold, str(_vy_samples)])
		return
	print("[FloaterTraitTest] PASS mean_dvy=%.2f threshold=%.2f samples=%s" % [mean, threshold, str(_vy_samples)])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[FloaterTraitTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
