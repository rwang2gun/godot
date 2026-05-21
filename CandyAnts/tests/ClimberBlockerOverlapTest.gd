extends Node

# Phase 14 impl-stage Round 3 — codex Round 1 권고 잔여 regression.
# Round 1에서 codex가 권고한 "climber+blocker overlap regression" 명시 구현.
# 검증 대상 (impl-stage Round 1/2 HIGH fix):
#  (A) ClimberState 도중 ant.direction 이 blocker bounce 등으로 flip 되어도
#      _climb_direction (enter 시 snapshot)이 velocity/probe 를 driving — climb 진행
#      방향 유지. (Round 1 HIGH)
#  (B) ClimberState.exit() 가 모든 종료 경로(mantle 완료/ceiling/stall guard)에서
#      ant.direction 을 _climb_direction 으로 복원 — post-climb FallerState/WalkerState
#      가 원래 climb 방향으로 진행. (Round 2 HIGH)
#
# 시나리오:
#  - dev_trait_test 무대(no stall geometry mod) 상에서 climber 부여
#  - ant 가 ClimberState 진입(=수직 등반 시작) 시점 캡쳐
#  - 즉시 synthetic blocker._on_blocker_body_entered(climber) 직접 호출 → ant.direction flip
#  - 그 다음 매 frame 추적:
#    - is_on_wall 가 아니라 ant.global_position.y 가 *감소* (climbing up)으로 (A) 검증
#    - mantle phase 진입 후 ant.global_position.x 가 _climb_direction 방향으로 *증가*로 (A) 검증
#  - ClimberState 가 다른 state 로 전이되는 정확한 frame 에 ant.direction 캡쳐 → (B) 검증
#  - 종료: ant.direction == _climb_direction 이면 PASS
#
# direct synthetic blocker 호출 패턴은 BlockerOverlapTest 와 동일 — 물리 timing 의존
# 제거, ClimberState ↔ 블로커 bounce 논리만 격리.

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")

const DEADLINE_FRAMES: int = 1500
const CLIMBER_STATE_MAX_FRAMES: int = 500

var _ant: Ant = null
var _climber_applied: bool = false
var _bounce_applied: bool = false
var _climb_direction_snapshot: int = 0
var _climber_entered_frame: int = -1
var _exited_climber_at_frame: int = -1
var _exit_state_name: String = ""
var _exit_direction: int = 0
var _frame_count: int = 0
var _result_emitted: bool = false

# climb progress observation
var _climb_entry_y: float = NAN
var _min_y_observed: float = INF  # 가장 위(작은 y)
var _mantle_entry_x: float = NAN
var _max_mantle_x_in_climb_dir: float = -INF  # _climb_direction 양수일 때 가장 오른쪽

var _synthetic_blocker: Ant = null

func _ready() -> void:
	print("[ClimberBlockerOverlapTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)
	_synthetic_blocker = ANT_SCENE.instantiate()
	add_child(_synthetic_blocker)
	# 격리 — physics 와 무관, 그저 _on_blocker_body_entered 호출 vehicle.
	# global_position 은 임의(real ant 와 멀리), 충돌 발생 안함.
	_synthetic_blocker.global_position = Vector2(-10000, -10000)
	_synthetic_blocker.set_blocker_active(true)

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_ensure_ant()
	_apply_climber_when_ready()
	_observe()

	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — climber_entered=%d exited=%d bounce_applied=%s" % [_climber_entered_frame, _exited_climber_at_frame, _bounce_applied])

func _ensure_ant() -> void:
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == _synthetic_blocker:
			continue
		var ant: Ant = a as Ant
		if ant == null:
			continue
		_ant = ant
		return

func _apply_climber_when_ready() -> void:
	if _climber_applied or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	var skill: ClimberSkill = ClimberSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_climber_applied = true
	print("[ClimberBlockerOverlapTest] applied climber at frame=%d pos=%s" % [_frame_count, _ant.global_position])

func _observe() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state
	if s is ClimberState:
		var climber: ClimberState = s as ClimberState
		if _climber_entered_frame < 0:
			_climber_entered_frame = _frame_count
			_climb_direction_snapshot = _ant.direction
			_climb_entry_y = _ant.global_position.y
			_min_y_observed = _climb_entry_y
			print("[ClimberBlockerOverlapTest] entered ClimberState at frame=%d pos=%s direction=%d" % [_frame_count, _ant.global_position, _climb_direction_snapshot])
		# 진입 다음 frame 에 즉시 blocker bounce 적용 — climbing phase 도중 flip.
		if not _bounce_applied:
			_apply_synthetic_blocker_bounce()
		# climb 방향 진행 추적: y 가 감소(climbing up)해야 함.
		if _ant.global_position.y < _min_y_observed:
			_min_y_observed = _ant.global_position.y
		# mantle 진입 후 x 진행 추적.
		if climber.is_mantling():
			if is_nan(_mantle_entry_x):
				_mantle_entry_x = _ant.global_position.x
				_max_mantle_x_in_climb_dir = _mantle_entry_x
			# _climb_direction_snapshot 방향으로의 max x.
			if _climb_direction_snapshot >= 0:
				if _ant.global_position.x > _max_mantle_x_in_climb_dir:
					_max_mantle_x_in_climb_dir = _ant.global_position.x
			else:
				if _ant.global_position.x < _max_mantle_x_in_climb_dir:
					_max_mantle_x_in_climb_dir = _ant.global_position.x
		var elapsed: int = _frame_count - _climber_entered_frame
		if elapsed > CLIMBER_STATE_MAX_FRAMES:
			_fail("ClimberState > %d frames (infinite stuck — possible direction lock regression)" % CLIMBER_STATE_MAX_FRAMES)
		return

	# transition out of ClimberState — capture exit direction immediately.
	if _climber_entered_frame >= 0 and _exited_climber_at_frame < 0:
		_exited_climber_at_frame = _frame_count
		_exit_state_name = s.get_script().resource_path.get_file() if s != null else "null"
		_exit_direction = _ant.direction
		var elapsed: int = _exited_climber_at_frame - _climber_entered_frame
		print("[ClimberBlockerOverlapTest] exited ClimberState at frame=%d elapsed=%d exit_state=%s exit_direction=%d climb_dir_snapshot=%d min_y=%.2f climb_entry_y=%.2f mantle_entered=%s mantle_entry_x=%.2f max_x=%.2f bounce_applied=%s" % [_frame_count, elapsed, _exit_state_name, _exit_direction, _climb_direction_snapshot, _min_y_observed, _climb_entry_y, not is_nan(_mantle_entry_x), _mantle_entry_x if not is_nan(_mantle_entry_x) else -1.0, _max_mantle_x_in_climb_dir, _bounce_applied])
		_verify_and_finish()

func _apply_synthetic_blocker_bounce() -> void:
	# direct call — BlockerOverlapTest 와 동일 패턴. body == self 가드 통과를 위해 다른
	# ant 객체에서 호출.
	_synthetic_blocker._on_blocker_body_entered(_ant)
	_bounce_applied = true
	print("[ClimberBlockerOverlapTest] applied synthetic blocker bounce at frame=%d ant.direction=%d (was %d before bounce)" % [_frame_count, _ant.direction, _climb_direction_snapshot])
	# bounce 가 ant.direction 을 실제로 flip 했는지 sanity check.
	if _ant.direction != -_climb_direction_snapshot:
		_fail("synthetic blocker bounce did not flip ant.direction: expected %d, got %d" % [-_climb_direction_snapshot, _ant.direction])

func _verify_and_finish() -> void:
	if not _bounce_applied:
		_fail("never applied blocker bounce (climber never reached climbing state)")
		return
	# (A) climb 진행: y 가 진입 시점보다 적어도 8px 감소했어야 (벽 등반 진행 증거).
	#     bounce 가 _climb_direction 을 깼다면 ant 는 벽에서 떨어져 climb 진행 불가.
	if _min_y_observed >= _climb_entry_y - 8.0:
		_fail("(A) climb did not progress upward after bounce — entry_y=%.2f min_y=%.2f (need < entry-8)" % [_climb_entry_y, _min_y_observed])
		return
	# (A) mantle 진입 MANDATORY — TraitTest 무대는 ant 가 벽 끝까지 climb 후 반드시 mantle 진입.
	#     mantle 미진입은 climb 진행 자체가 멈춘 회귀 신호 (codex Round 3 MEDIUM 대응).
	if is_nan(_mantle_entry_x):
		_fail("(A) mantle never entered — _climb_direction lock may have been broken pre-mantle (regression in climbing phase)")
		return
	var x_delta: float = _max_mantle_x_in_climb_dir - _mantle_entry_x
	var expected_sign: int = _climb_direction_snapshot
	if (expected_sign > 0 and x_delta < 4.0) or (expected_sign < 0 and x_delta > -4.0):
		_fail("(A) mantle did not progress in _climb_direction=%d after bounce — entry_x=%.2f max_x=%.2f delta=%.2f" % [_climb_direction_snapshot, _mantle_entry_x, _max_mantle_x_in_climb_dir, x_delta])
		return
	# (B) exit 시점 ant.direction 이 _climb_direction 으로 복원되었는지.
	#     ClimberState 의 모든 exit 경로(mantle 완료/ceiling-fall/stall-guard fall)는 모두
	#     AntStateMachine.change_state(new_state) 를 호출하고, change_state 는 항상
	#     current_state.exit() 를 먼저 호출하므로 exit() 발화는 모든 경로에서 동일하게 보장됨.
	#     본 테스트(mantle-complete 경로) + ClimberBlockerOverlapStallTest(stall-fall 경로) 으로
	#     동일한 exit() 메커니즘이 서로 다른 transition 호출 지점에서 모두 발화함을 검증.
	if _exit_direction != _climb_direction_snapshot:
		_fail("(B) ant.direction not restored at ClimberState exit — expected %d got %d (exit_state=%s)" % [_climb_direction_snapshot, _exit_direction, _exit_state_name])
		return
	_pass()

func _pass() -> void:
	print("[ClimberBlockerOverlapTest] PASS — bounce flipped direction to %d during ClimberState; climb progressed (min_y=%.2f<entry=%.2f); exit restored direction to %d" % [-_climb_direction_snapshot, _min_y_observed, _climb_entry_y, _exit_direction])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ClimberBlockerOverlapTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
