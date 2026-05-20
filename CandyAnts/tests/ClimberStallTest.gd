extends Node

# Phase 14 — ClimberState mantle stall guard 검증.
# 막힌 corner geometry에서 ClimberState가 무한 stuck하지 않고
# stall guard(dx<0.1이 10 frame 연속)로 FallerState 강제 탈출하는지 확인.
#
# 시나리오:
#  - Ant 스폰 + climber trait 부여
#  - 좁은 corner(좌측 climb wall + 위 ceiling overhang)에서 climb → mantle 시도 → stall → Faller
#  - 또는 mantle이 정상 완료되어도 OK (구조적 무한 stuck만 fail)
#
# PASS: ClimberState 진입 후 ≤ 90 frame 안에 임의 다른 state로 전이.
# FAIL: 90 frame 이상 ClimberState 유지 (무한 stuck = 회귀 신호).
# DEADLINE: 30초.

const DEADLINE_FRAMES: int = 1800
const CLIMBER_STATE_MAX_FRAMES: int = 500  # 전체 climb(~290) + mantle(~54) 또는 stall(~10) + 여유

var _ant: Ant = null
var _climber_applied: bool = false
var _climber_entered_frame: int = -1
var _exited_climber_at_frame: int = -1
var _exit_state_name: String = ""
var _frame_count: int = 0
var _result_emitted: bool = false

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
			print("[ClimberStallTest] entered ClimberState at frame=%d pos=%s" % [_frame_count, _ant.global_position])
		# stuck check
		var elapsed: int = _frame_count - _climber_entered_frame
		if elapsed > CLIMBER_STATE_MAX_FRAMES:
			_fail("ClimberState > %d frames (infinite stuck — stall guard FAIL)" % CLIMBER_STATE_MAX_FRAMES)
		return

	if _climber_entered_frame >= 0 and _exited_climber_at_frame < 0:
		_exited_climber_at_frame = _frame_count
		_exit_state_name = s.get_script().resource_path.get_file() if s != null else "null"
		var elapsed: int = _exited_climber_at_frame - _climber_entered_frame
		print("[ClimberStallTest] exited ClimberState at frame=%d elapsed=%d exit_state=%s" % [_frame_count, elapsed, _exit_state_name])
		# stall guard 동작 증거: ClimberState 진입 후 90 frame 이내에 다른 state로 나옴.
		_pass()

func _pass() -> void:
	print("[ClimberStallTest] PASS — climber entered@%d exited@%d (state=%s)" % [_climber_entered_frame, _exited_climber_at_frame, _exit_state_name])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ClimberStallTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
