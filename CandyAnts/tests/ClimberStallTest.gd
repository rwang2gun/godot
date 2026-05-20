extends Node

# Phase 14 — ClimberState mantle stall guard 검증 (impl-stage Round 1 MEDIUM 대응).
# 막힌 corner geometry(ceiling overhang)에서 mantle phase의 dx==0 stall이 발생하고,
# stall guard(MANTLE_STALL_LIMIT=10 frame 연속 dx<0.1)가 동작해 FallerState로 강제 전이.
#
# PASS 조건:
#  1. ClimberState 진입 확인
#  2. mantle 진입 후 dx accumulation 정체(stall) 관찰 — ant.global_position.x 변화량이 거의 0
#  3. ClimberState → FallerState 전이 (Walker/Carrying이 아닌 FallerState)
#  4. 위 전이가 CLIMBER_STATE_MAX_FRAMES 안에 발생
#
# FAIL:
#  - ClimberState > MAX frames 유지 (무한 stuck = 회귀 신호)
#  - mantle이 정상 완료되어 Walker/Carrying으로 exit (geometry가 stall을 트리거 못함)

const DEADLINE_FRAMES: int = 1800
const CLIMBER_STATE_MAX_FRAMES: int = 500  # 전체 climb(~290) + mantle(~54) 또는 stall(~10) + 여유
const STALL_OBSERVATION_FRAMES: int = 12  # MANTLE_STALL_LIMIT(10) + 여유 2
const STALL_DX_THRESHOLD: float = 0.5  # 관찰자 입장에서 dx 정체 판단 (관용 마진)

var _ant: Ant = null
var _climber_applied: bool = false
var _climber_entered_frame: int = -1
var _exited_climber_at_frame: int = -1
var _exit_state_name: String = ""
var _frame_count: int = 0
var _result_emitted: bool = false

# stall observation
var _prev_x: float = NAN
var _consecutive_low_dx_frames: int = 0
var _observed_stall: bool = false

func _ready() -> void:
	print("[ClimberStallTest] driver ready, deadline=%d frames, climber_state_max=%d" % [DEADLINE_FRAMES, CLIMBER_STATE_MAX_FRAMES])
	_build_stall_geometry()

func _build_stall_geometry() -> void:
	# dev_trait_test_layout의 cliff(x=15, 절벽 top=cell (15,16))의 mantle 진행 경로에 천장 추가.
	# 천장 cell (16, 15) → world center (528, 496). 이는 ant가 mantle phase 진입 후
	# horizontal push 도중 ceiling과 충돌하여 dx==0 stall 유도.
	var world: Node2D = get_node_or_null("../StallStage/World") as Node2D
	if world == null:
		push_error("[ClimberStallTest] failed to find ../StallStage/World")
		return
	# ceiling cell (16, 15): world center (16*32+16, 15*32+16) = (528, 496), size 32x32.
	_add_solid_block(world, Vector2(528, 496), Vector2(32, 32))
	# 추가 ceiling cells (17, 15), (18, 15) — mantle 경로 전체를 덮어 stall 확실히 유도.
	_add_solid_block(world, Vector2(560, 496), Vector2(32, 32))
	_add_solid_block(world, Vector2(592, 496), Vector2(32, 32))

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
		_fail("deadline exceeded — climber_entered=%d exited=%d" % [_climber_entered_frame, _exited_climber_at_frame])

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
	if _climber_applied or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	var skill: ClimberSkill = ClimberSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_climber_applied = true
	print("[ClimberStallTest] applied climber at frame=%d pos=%s" % [_frame_count, _ant.global_position])

func _observe() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state
	if s is ClimberState:
		if _climber_entered_frame < 0:
			_climber_entered_frame = _frame_count
			_prev_x = _ant.global_position.x
			print("[ClimberStallTest] entered ClimberState at frame=%d pos=%s" % [_frame_count, _ant.global_position])
		else:
			# mantle phase 진입 후 dx 정체 관찰. _prev_x 대비 변화량 < STALL_DX_THRESHOLD가
			# 10 frame 이상 누적되면 stall 발생 증거.
			var dx: float = absf(_ant.global_position.x - _prev_x)
			_prev_x = _ant.global_position.x
			if dx < STALL_DX_THRESHOLD:
				_consecutive_low_dx_frames += 1
				if _consecutive_low_dx_frames >= STALL_OBSERVATION_FRAMES and not _observed_stall:
					_observed_stall = true
					print("[ClimberStallTest] observed stall: %d consecutive low-dx frames at frame=%d pos=%s" % [_consecutive_low_dx_frames, _frame_count, _ant.global_position])
			else:
				_consecutive_low_dx_frames = 0
		# stuck check
		var elapsed: int = _frame_count - _climber_entered_frame
		if elapsed > CLIMBER_STATE_MAX_FRAMES:
			_fail("ClimberState > %d frames (infinite stuck — stall guard FAIL)" % CLIMBER_STATE_MAX_FRAMES)
		return

	if _climber_entered_frame >= 0 and _exited_climber_at_frame < 0:
		_exited_climber_at_frame = _frame_count
		_exit_state_name = s.get_script().resource_path.get_file() if s != null else "null"
		var elapsed: int = _exited_climber_at_frame - _climber_entered_frame
		print("[ClimberStallTest] exited ClimberState at frame=%d elapsed=%d exit_state=%s observed_stall=%s" % [_frame_count, elapsed, _exit_state_name, _observed_stall])
		# PASS 조건: stall 관찰됨 + FallerState exit
		if not _observed_stall:
			_fail("did not observe stall (no consecutive low-dx frames during mantling — geometry failed to trigger stall guard)")
			return
		if not (s is FallerState):
			_fail("expected FallerState exit (stall guard), got %s" % _exit_state_name)
			return
		_pass()

func _pass() -> void:
	print("[ClimberStallTest] PASS — climber entered@%d exited@%d (state=%s)" % [_climber_entered_frame, _exited_climber_at_frame, _exit_state_name])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ClimberStallTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
