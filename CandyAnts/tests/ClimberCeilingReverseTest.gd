extends Node

# 2026-06 — ClimberState 천정 충돌 시 방향 반전 검증.
# 등반(climbing phase) 중 머리 위가 막혀 is_on_ceiling이 되면 FallerState로 전이하는데,
# 이때 이전 진행 방향의 **반대**로 떨어져 걷도록(벽으로 되돌아가 재등반하는 루프 차단) 수정했다.
# 본 테스트는 cliff(column 15) 등반 컬럼 바로 위(row15)에 천장 캡을 추가해 climbing phase에서
# is_on_ceiling을 강제하고, 낙하 착지 후 ant.direction이 등반 진입 방향의 반대인지 단언한다.
#
# PASS: ClimberState 진입(방향 +1) → is_on_ceiling 경로로 FallerState → 착지 후 Walker/Carrying에서
#       direction == -1 (반전).
# FAIL: 천정 경로 미발생(mantle 완료/stall) / 착지 후 direction이 반전 안 됨(+1 유지) / deadline.

const DEADLINE_FRAMES: int = 2400

var _ant: Ant = null
var _climber_applied: bool = false
var _climb_dir_at_enter: int = 0
var _entered_climber: bool = false
var _saw_faller: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	print("[ClimberCeilingReverseTest] driver ready")
	_build_ceiling_cap()

func _build_ceiling_cap() -> void:
	# 등반 컬럼(좌측 면, x≈470) 바로 위 **낮은** row20(y≈656)를 막아 climbing 시작 직후 머리 충돌을 유도.
	# 낮게 캡해야 낙하 거리가 기절 임계(5*32=160px) 미만 → 착지 후 보행까지 관찰 가능.
	# (13,20)+(14,20) 두 셀로 head(x≈471, col14) 통과 구간을 덮는다. cell_size=32.
	var world: Node2D = get_node_or_null("../CeilStage/World") as Node2D
	if world == null:
		push_error("[ClimberCeilingReverseTest] failed to find ../CeilStage/World")
		return
	_add_solid_block(world, Vector2(432, 656), Vector2(32, 32))  # cell (13,20)
	_add_solid_block(world, Vector2(464, 656), Vector2(32, 32))  # cell (14,20)

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
	if _done:
		return
	_frame += 1
	_ensure_ant()
	_apply_climber_when_ready()
	_observe()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — entered_climber=%s saw_faller=%s dir=%s" % [
			_entered_climber, _saw_faller, _dir_str()])

func _ensure_ant() -> void:
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		_ant = n as Ant
		if _ant != null:
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
	print("[ClimberCeilingReverseTest] climber applied frame=%d pos=%s dir=%d" % [_frame, _ant.global_position, _ant.direction])

func _observe() -> void:
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	var s: AntState = _ant.state_machine.current_state
	if s is ClimberState:
		if not _entered_climber:
			_entered_climber = true
			_climb_dir_at_enter = _ant.direction
			print("[ClimberCeilingReverseTest] ClimberState enter frame=%d dir=%d pos=%s" % [_frame, _ant.direction, _ant.global_position])
		return
	if s is FallerState:
		if _entered_climber and not _saw_faller:
			_saw_faller = true
			print("[ClimberCeilingReverseTest] FallerState frame=%d dir=%d pos=%s" % [_frame, _ant.direction, _ant.global_position])
		return
	# 착지 후 보행/운반 — 천정 경로를 거쳤다면 방향이 반전돼 있어야 한다.
	if _saw_faller and (s is WalkerState or s is CarryingState):
		if _ant.is_on_floor():
			var landed_dir: int = _ant.direction
			print("[ClimberCeilingReverseTest] landed frame=%d state=%s enter_dir=%d landed_dir=%d pos=%s" % [
				_frame, s.get_script().resource_path.get_file(), _climb_dir_at_enter, landed_dir, _ant.global_position])
			if landed_dir == -_climb_dir_at_enter and _climb_dir_at_enter != 0:
				_pass("ceiling reversed direction %d → %d" % [_climb_dir_at_enter, landed_dir])
			else:
				_fail("direction NOT reversed: enter=%d landed=%d (expected %d)" % [
					_climb_dir_at_enter, landed_dir, -_climb_dir_at_enter])

func _dir_str() -> String:
	return str(_ant.direction) if (_ant != null and is_instance_valid(_ant)) else "<none>"

func _pass(msg: String) -> void:
	print("[ClimberCeilingReverseTest] PASS — %s frame=%d" % [msg, _frame])
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ClimberCeilingReverseTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
