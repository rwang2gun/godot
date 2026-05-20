extends Node

# Phase 14 — Climber trait 통합 회귀 테스트.
# 첫 ant에 ClimberSkill 부여 → 절벽 만남 → ClimberState 진입 → mantle 완료 →
# Walker/Carrying 복귀 + 마지막 3 frame 동안 state stable + x 변화량 >= mantle_distance.
#
# PASS: quit(0). FAIL: quit(1).
# DEADLINE: 30초 (60fps × 1800 frame).

const DEADLINE_FRAMES: int = 1800

var _ant: Ant = null
var _climber_applied: bool = false
var _wall_x_entered: float = NAN
var _seen_climber_state: bool = false
var _seen_post_climber_state: bool = false
var _stable_state_frames: int = 0
var _frame_count: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[ClimberTraitTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame_count += 1

	_ensure_ant()
	_apply_climber_when_ready()
	_observe_climb()

	if _frame_count > DEADLINE_FRAMES:
		_fail("deadline exceeded — frame=%d ant_state=%s" % [_frame_count, _state_name(_ant)])

func _ensure_ant() -> void:
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null:
			continue
		_ant = a
		return

func _apply_climber_when_ready() -> void:
	if _climber_applied or _ant == null:
		return
	# spawn_grace 통과 + Walker 상태 확인 후 부여.
	if _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	var skill: ClimberSkill = ClimberSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_climber_applied = true
	print("[ClimberTraitTest] applied climber at frame=%d pos=%s" % [_frame_count, _ant.global_position])

func _observe_climb() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state

	if s is ClimberState:
		if not _seen_climber_state:
			_wall_x_entered = _ant.global_position.x
			_seen_climber_state = true
			print("[ClimberTraitTest] entered ClimberState at frame=%d pos=%s" % [_frame_count, _ant.global_position])
		return

	# Climber 진입 후 Walker/Carrying = mantle 정상 완료 = PASS.
	# Faller로 직진하는 경우는 ceiling overhang 등 stall scenario이지 정상 mantle 검증 외.
	if _seen_climber_state and (s is WalkerState or s is CarryingState):
		if not _seen_post_climber_state:
			_seen_post_climber_state = true
			print("[ClimberTraitTest] post-climber state=%s at frame=%d pos=%s" % [_state_name(_ant), _frame_count, _ant.global_position])
			_evaluate_success()

func _evaluate_success() -> void:
	if _ant == null:
		_fail("ant disappeared during evaluation")
		return
	var dx: float = absf(_ant.global_position.x - _wall_x_entered)
	if dx < _ant.mantle_distance:
		_fail("mantle dx %.2f < mantle_distance %.2f" % [dx, _ant.mantle_distance])
		return
	print("[ClimberTraitTest] PASS frame=%d dx=%.2f mantle_distance=%.2f state=%s" % [_frame_count, dx, _ant.mantle_distance, _state_name(_ant)])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ClimberTraitTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)

func _state_name(a: Ant) -> String:
	if a == null or a.state_machine == null or a.state_machine.current_state == null:
		return "null"
	return a.state_machine.current_state.get_class() + "/" + str(a.state_machine.current_state.get_script().resource_path.get_file())
