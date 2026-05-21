extends Node

# Phase 14 — ClimberState mantle stall guard 검증 (impl-stage codex Round 1 MEDIUM +
# Round 2 MEDIUM 대응). 막힌 corner geometry(ceiling overhang)에서 mantle phase의
# dx==0 stall이 발생하고 stall guard(MANTLE_STALL_LIMIT 연속 dx<STALL_DX_THRESHOLD)가
# 동작해 FallerState로 강제 전이하는지 결정론적으로 확인.
#
# 검증 전략 (Round 3 재설계):
#  - ClimberState.is_mantling() 으로 mantle phase에 gate (climbing phase의 자연스러운
#    low-dx 와 구분 — Round 2 codex MEDIUM 대응).
#  - ClimberState.mantle_stall_frame_count() / mantle_offset() getter로 내부 상태
#    노출 → guard 임계값에 가까이 도달했는지 결정론적으로 확인.
#  - PASS 조건:
#    1. ClimberState 진입
#    2. is_mantling() true 도달 (실제 mantle 시작)
#    3. mantle 도중 mantle_stall_frame_count() >= STALL_OBSERVATION_THRESHOLD 도달
#       (guard 임계값 MANTLE_STALL_LIMIT보다 작아야 — 그래야 guard 발화 전 관찰 보장)
#    4. ClimberState → FallerState 전이
#    5. exit 시점 _last_mantle_offset < mantle_distance — guard 발화로 incomplete mantle
#       (mantle 정상 완료가 아니라 stall fall-through 임을 증명)
#  - FAIL:
#    - mantle 시작 없이 다른 state로 exit
#    - mantle_offset이 mantle_distance에 도달 후 exit (정상 완료 → 회귀)
#    - ClimberState > CLIMBER_STATE_MAX_FRAMES (무한 stuck)
#    - DEADLINE 초과

const DEADLINE_FRAMES: int = 1800
const CLIMBER_STATE_MAX_FRAMES: int = 500  # 전체 climb(~290) + mantle(~54) 또는 stall(~10) + 여유
# guard MANTLE_STALL_LIMIT 보다 작은 값 — guard 발화 전 관찰을 보장.
# 5는 자연 noise(연속 1~2 frame low-dx)와 분리되면서 guard 임계값(10)에 안전 margin.
const STALL_OBSERVATION_THRESHOLD: int = 5

var _ant: Ant = null
var _climber_applied: bool = false
var _climber_entered_frame: int = -1
var _exited_climber_at_frame: int = -1
var _exit_state_name: String = ""
var _frame_count: int = 0
var _result_emitted: bool = false

# mantle phase observation
var _observed_mantle_entry: bool = false
var _max_stall_frames_observed: int = 0
var _last_mantle_offset: float = -1.0
var _last_mantle_distance: float = 0.0

func _ready() -> void:
	print("[ClimberStallTest] driver ready, deadline=%d frames, climber_state_max=%d, stall_obs_threshold=%d" % [DEADLINE_FRAMES, CLIMBER_STATE_MAX_FRAMES, STALL_OBSERVATION_THRESHOLD])
	_build_stall_geometry()

func _build_stall_geometry() -> void:
	# dev_trait_test_layout 의 cliff(x=15, top at cell (15,16))의 mantle 진행 경로에 천장 추가.
	# 천장 cell (16,15) 은 platform top(y=512) 바로 위 [y 480..512]를 차지하여 mantle 도중
	# ant 바디(약 y∈[502,512])와 horizontal 충돌 → dx==0 stall 유도.
	# (16,15)(17,15)(18,15) 세 cell로 mantle_distance(36px) 전 구간 cover.
	var world: Node2D = get_node_or_null("../StallStage/World") as Node2D
	if world == null:
		push_error("[ClimberStallTest] failed to find ../StallStage/World")
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
			_last_mantle_distance = _ant.mantle_distance
			print("[ClimberStallTest] entered ClimberState at frame=%d pos=%s mantle_distance=%.2f" % [_frame_count, _ant.global_position, _last_mantle_distance])
		# mantle 도중 stall_frame_count + offset 추적. is_mantling() gate 로 climbing phase 와 분리.
		# (Round 2 codex MEDIUM 대응 — climbing phase 의 자연 low-dx 와 stall guard 발화를 구분)
		var climber: ClimberState = s as ClimberState
		if climber != null and climber.is_mantling():
			if not _observed_mantle_entry:
				_observed_mantle_entry = true
				print("[ClimberStallTest] mantle entry observed at frame=%d pos=%s" % [_frame_count, _ant.global_position])
			var sf: int = climber.mantle_stall_frame_count()
			if sf > _max_stall_frames_observed:
				_max_stall_frames_observed = sf
			_last_mantle_offset = climber.mantle_offset()
		# stuck check
		var elapsed: int = _frame_count - _climber_entered_frame
		if elapsed > CLIMBER_STATE_MAX_FRAMES:
			_fail("ClimberState > %d frames (infinite stuck — stall guard FAIL)" % CLIMBER_STATE_MAX_FRAMES)
		return

	if _climber_entered_frame >= 0 and _exited_climber_at_frame < 0:
		_exited_climber_at_frame = _frame_count
		_exit_state_name = s.get_script().resource_path.get_file() if s != null else "null"
		var elapsed: int = _exited_climber_at_frame - _climber_entered_frame
		print("[ClimberStallTest] exited ClimberState at frame=%d elapsed=%d exit_state=%s mantle_entered=%s max_stall_frames=%d last_offset=%.2f mantle_distance=%.2f" % [_frame_count, elapsed, _exit_state_name, _observed_mantle_entry, _max_stall_frames_observed, _last_mantle_offset, _last_mantle_distance])
		# PASS 조건 검증 (위 docstring 참조).
		if not _observed_mantle_entry:
			_fail("mantle never entered — climber exited before mantle phase")
			return
		if _max_stall_frames_observed < STALL_OBSERVATION_THRESHOLD:
			_fail("mantle stall not observed — max_stall_frames=%d < threshold=%d (geometry failed to block mantle)" % [_max_stall_frames_observed, STALL_OBSERVATION_THRESHOLD])
			return
		if _last_mantle_offset >= _last_mantle_distance:
			_fail("mantle completed normally — last_offset=%.2f >= mantle_distance=%.2f (stall geometry did not stop mantle)" % [_last_mantle_offset, _last_mantle_distance])
			return
		if not (s is FallerState):
			_fail("expected FallerState exit (stall guard fall-through), got %s" % _exit_state_name)
			return
		_pass()

func _pass() -> void:
	print("[ClimberStallTest] PASS — climber entered@%d exited@%d (state=%s max_stall=%d last_offset=%.2f<mantle_distance=%.2f)" % [_climber_entered_frame, _exited_climber_at_frame, _exit_state_name, _max_stall_frames_observed, _last_mantle_offset, _last_mantle_distance])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ClimberStallTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
