extends Node

# Phase 14 impl-stage codex Round 3 MEDIUM follow-up — exit-path coverage.
# ClimberBlockerOverlapTest 가 mantle-complete 경로(ClimberState.gd:90 의 change_state)에서
# exit() direction 복원을 검증한다면, 본 테스트는 stall-guard fall 경로(ClimberState.gd:77)
# 에서도 exit() direction 복원이 동일하게 작동함을 검증.
#
# AntStateMachine.change_state 는 항상 current_state.exit() 를 호출 (AntStateMachine.gd:7-8)
# 하므로 exit() 발화는 transition 호출 지점과 무관하게 동일. 본 테스트는 그 invariant 가
# stall-guard 발화 경로에서도 유지됨을 명시.
#
# 시나리오:
#  - ClimberStallTest 와 동일한 stall ceiling geometry ((16,15)(17,15)(18,15))
#  - climber 부여 → ClimberState 진입 직후 synthetic blocker bounce 로 ant.direction flip
#  - mantle 도중 stall guard 발화 → FallerState 로 fall-through
#  - exit 시점 ant.direction 이 _climb_direction_snapshot 으로 복원되었는지 확인

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

# stall verification
var _mantle_entered: bool = false
var _max_stall_frames_observed: int = 0
var _last_mantle_offset: float = -1.0
var _last_mantle_distance: float = 0.0

var _synthetic_blocker: Ant = null

func _ready() -> void:
	print("[ClimberBlockerOverlapStallTest] driver ready, deadline=%d frames" % DEADLINE_FRAMES)
	_synthetic_blocker = ANT_SCENE.instantiate()
	add_child(_synthetic_blocker)
	_synthetic_blocker.global_position = Vector2(-10000, -10000)
	_synthetic_blocker.set_blocker_active(true)
	_build_stall_geometry()

func _build_stall_geometry() -> void:
	# ClimberStallTest 와 동일한 ceiling geometry — mantle 도중 dx==0 stall 유도.
	var world: Node2D = get_node_or_null("../TraitStage/World") as Node2D
	if world == null:
		push_error("[ClimberBlockerOverlapStallTest] failed to find ../TraitStage/World")
		return
	_add_solid_block(world, Vector2(528, 496), Vector2(32, 32))  # cell (16,15)
	_add_solid_block(world, Vector2(560, 496), Vector2(32, 32))  # cell (17,15)
	_add_solid_block(world, Vector2(592, 496), Vector2(32, 32))  # cell (18,15)

func _add_solid_block(parent: Node, center: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	parent.add_child(body)

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
		if a == null:
			continue
		_ant = a
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
	print("[ClimberBlockerOverlapStallTest] applied climber at frame=%d pos=%s" % [_frame_count, _ant.global_position])

func _observe() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state
	if s is ClimberState:
		var climber: ClimberState = s as ClimberState
		if _climber_entered_frame < 0:
			_climber_entered_frame = _frame_count
			_climb_direction_snapshot = _ant.direction
			_last_mantle_distance = _ant.mantle_distance
			print("[ClimberBlockerOverlapStallTest] entered ClimberState at frame=%d direction=%d mantle_distance=%.2f" % [_frame_count, _climb_direction_snapshot, _last_mantle_distance])
		# bounce 즉시 적용 — climbing phase 도중 flip.
		if not _bounce_applied:
			_synthetic_blocker._on_blocker_body_entered(_ant)
			_bounce_applied = true
			print("[ClimberBlockerOverlapStallTest] applied synthetic blocker bounce at frame=%d ant.direction=%d (was %d)" % [_frame_count, _ant.direction, _climb_direction_snapshot])
			if _ant.direction != -_climb_direction_snapshot:
				_fail("synthetic bounce did not flip direction")
				return
		# stall frame count 추적.
		if climber.is_mantling():
			if not _mantle_entered:
				_mantle_entered = true
				print("[ClimberBlockerOverlapStallTest] mantle entered at frame=%d" % _frame_count)
			var sf: int = climber.mantle_stall_frame_count()
			if sf > _max_stall_frames_observed:
				_max_stall_frames_observed = sf
			_last_mantle_offset = climber.mantle_offset()
		var elapsed: int = _frame_count - _climber_entered_frame
		if elapsed > CLIMBER_STATE_MAX_FRAMES:
			_fail("ClimberState > %d frames (stuck — possible direction lock regression)" % CLIMBER_STATE_MAX_FRAMES)
		return

	if _climber_entered_frame >= 0 and _exited_climber_at_frame < 0:
		_exited_climber_at_frame = _frame_count
		_exit_state_name = s.get_script().resource_path.get_file() if s != null else "null"
		_exit_direction = _ant.direction
		var elapsed: int = _exited_climber_at_frame - _climber_entered_frame
		print("[ClimberBlockerOverlapStallTest] exited ClimberState at frame=%d elapsed=%d exit_state=%s exit_direction=%d climb_dir_snapshot=%d mantle_entered=%s max_stall=%d last_offset=%.2f mantle_distance=%.2f bounce_applied=%s" % [_frame_count, elapsed, _exit_state_name, _exit_direction, _climb_direction_snapshot, _mantle_entered, _max_stall_frames_observed, _last_mantle_offset, _last_mantle_distance, _bounce_applied])
		_verify_and_finish()

func _verify_and_finish() -> void:
	if not _bounce_applied:
		_fail("never applied blocker bounce")
		return
	if not _mantle_entered:
		_fail("mantle never entered (stall geometry may have blocked climb itself, or _climb_direction lock regressed)")
		return
	# stall guard 발화 검증 — ClimberStallTest 와 동일.
	if _max_stall_frames_observed < 5:
		_fail("mantle stall not observed — max_stall=%d (stall geometry failed despite bounce)" % _max_stall_frames_observed)
		return
	if _last_mantle_offset >= _last_mantle_distance:
		_fail("mantle completed normally — stall geometry did not block mantle after bounce")
		return
	if not (_exit_state_name == "FallerState.gd"):
		_fail("expected FallerState exit via stall-guard fall, got %s" % _exit_state_name)
		return
	# 핵심: stall-guard fall 경로에서도 exit() 가 direction 복원.
	if _exit_direction != _climb_direction_snapshot:
		_fail("ant.direction not restored at stall-guard ClimberState exit — expected %d got %d" % [_climb_direction_snapshot, _exit_direction])
		return
	_pass()

func _pass() -> void:
	print("[ClimberBlockerOverlapStallTest] PASS — bounce flipped direction to %d during ClimberState; stall guard fired (max_stall=%d last_offset=%.2f<distance=%.2f); exit restored direction to %d on stall-guard fall path" % [-_climb_direction_snapshot, _max_stall_frames_observed, _last_mantle_offset, _last_mantle_distance, _exit_direction])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ClimberBlockerOverlapStallTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
