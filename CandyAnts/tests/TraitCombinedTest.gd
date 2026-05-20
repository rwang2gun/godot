extends Node

# Phase 14 — Climber + Floater 동시 보유 통합 테스트.
# 첫 ant에 ClimberSkill + FloaterSkill 둘 다 부여 → 등반 후 추락 시 느린 낙하 검증.
#
# PASS: ClimberState 진입 확인 + 이후 FallerState에서 vy delta < threshold.
# DEADLINE: 30초.

const DEADLINE_FRAMES: int = 1800
const FLOATER_THRESHOLD: float = 0.4
const SAMPLE_FRAMES: int = 5

var _ant: Ant = null
var _climber_applied: bool = false
var _floater_applied: bool = false
var _seen_climber_state: bool = false
var _seen_faller_after_climber: bool = false
var _vy_samples: Array[float] = []
var _last_vy: float = 0.0
var _frame_count: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[TraitCombinedTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_ensure_ant()
	_apply_traits_when_ready()
	_observe()

	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — saw_climber=%s saw_faller=%s samples=%d" % [_seen_climber_state, _seen_faller_after_climber, _vy_samples.size()])

func _ensure_ant() -> void:
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null:
			continue
		_ant = a
		return

func _apply_traits_when_ready() -> void:
	if _ant == null or _ant.state_machine == null:
		return
	if not _climber_applied and _ant.state_machine.current_state is WalkerState:
		var c: ClimberSkill = ClimberSkill.new()
		if c.can_apply(_ant):
			c.apply(_ant)
			_climber_applied = true
			print("[TraitCombinedTest] applied climber at frame=%d" % _frame_count)
	if not _floater_applied and _climber_applied:
		var f: FloaterSkill = FloaterSkill.new()
		if f.can_apply(_ant):
			f.apply(_ant)
			_floater_applied = true
			print("[TraitCombinedTest] applied floater at frame=%d" % _frame_count)

var _prev_state_was_faller: bool = false

func _observe() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state
	# 비-Faller 상태일 때 _last_vy를 계속 갱신해서 다음 Faller 진입 시점의 baseline 정확하게 유지.
	# Walker→Faller 전이 시점의 Walker 마지막 frame gravity가 첫 Faller 샘플에 섞이는 것 방지.
	if not (s is FallerState):
		_last_vy = _ant.velocity.y
		_prev_state_was_faller = false
	if not _climber_applied or not _floater_applied:
		return
	if not (_ant.has_trait(&"climber") and _ant.has_trait(&"floater")):
		_fail("trait state lost: climber=%s floater=%s" % [_ant.has_trait(&"climber"), _ant.has_trait(&"floater")])
		return

	if s is ClimberState:
		_seen_climber_state = true
		_last_vy = _ant.velocity.y
		return

	if _seen_climber_state and s is FallerState:
		if not _prev_state_was_faller:
			_prev_state_was_faller = true
			# Faller 진입 frame의 vy는 직전 Walker.update가 추가한 gravity가 섞여 있으므로
			# 여기서 _last_vy를 현재 vy로 설정. 다음 frame Faller.update 증가량만 dy로 측정.
			_last_vy = _ant.velocity.y
			if not _seen_faller_after_climber:
				_seen_faller_after_climber = true
				print("[TraitCombinedTest] entered FallerState after climb at frame=%d" % _frame_count)
			return
		var dy: float = _ant.velocity.y - _last_vy
		_last_vy = _ant.velocity.y
		if dy > 0.0:
			_vy_samples.append(dy)
		if _vy_samples.size() >= SAMPLE_FRAMES:
			_evaluate()

func _evaluate() -> void:
	var sum: float = 0.0
	for v in _vy_samples:
		sum += v
	var mean: float = sum / float(_vy_samples.size())
	var threshold: float = _ant.gravity * (1.0 / 60.0) * FLOATER_THRESHOLD
	if mean > threshold:
		_fail("mean dvy %.2f > threshold %.2f" % [mean, threshold])
		return
	print("[TraitCombinedTest] PASS mean_dvy=%.2f threshold=%.2f" % [mean, threshold])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[TraitCombinedTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
