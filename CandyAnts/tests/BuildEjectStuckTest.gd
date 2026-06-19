extends Node

# prove-it: 건설 타일에 끼인 개미를 진행방향 반대 1칸 밀어내고 떨어뜨림 — direction 유지 + floater 보존(소모 X).
# (2026-06-20 사용자 요청 + 3차 정정: 반전 금지 / 낙하산 아닌 떨어지는 모션 / 낙하산 소모 X.)
#
# dev_sand_mound fixture(cell_size=32)에서 builder 개미가 사다리(sand_mound)를 쌓는 동안, victim 개미에
# floater 트레잇을 주고 builder가 rung을 놓을 셀(body_cell)에 매 프레임 고정시켜 끼임을 유도한다. 건설 tick의
# _eject_stuck_ants가 victim을 밀어내면:
#   ① victim이 FallerState로 전환되고 direction이 보존(반전 X)되는지
#   ② 착지(walker 복귀) 후에도 floater 트레잇이 보존(낙하산 소모 X)되는지
# 를 단언한다. PASS=둘 다 충족. FAIL=direction 반전 / floater 소모 / deadline.

const CS: int = 32
const DEADLINE: int = 2400

var _stage: Node = null
var _terrain: Terrain = null
var _builder: Ant = null
var _victim: Ant = null
var _applied: bool = false
var _floater_set: bool = false
var _victim_dir: int = 999
var _ejected: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_failed.connect(_on_failed)
	print("[BuildEjectStuckTest] ready")

func _physics_process(_d: float) -> void:
	if _done:
		return
	_frame += 1
	_refs()
	_run()
	if _frame > DEADLINE:
		_fail("deadline applied=%s ejected=%s" % [str(_applied), str(_ejected)])

func _refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../SandMoundStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	if _builder == null or _victim == null:
		var ants: Array = []
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a != null and is_instance_valid(a):
				ants.append(a)
		if ants.size() >= 2:
			_builder = ants[0]
			_victim = ants[1]

func _run() -> void:
	if _builder == null or _victim == null or _terrain == null:
		return
	if not is_instance_valid(_builder) or not is_instance_valid(_victim):
		return
	# 1) builder에 sand_mound 적용 (walker + on_floor일 때).
	if not _applied:
		if (_builder.state_machine.current_state is WalkerState) and _builder.is_on_floor():
			var sk: SandMoundSkill = SandMoundSkill.new()
			if sk.can_apply(_builder):
				sk.apply(_builder)
				_applied = true
				print("[BuildEjectStuckTest] sand_mound applied frame=%d" % _frame)
		return
	# victim에 floater 부여 (소모 보존 검증용).
	if not _floater_set:
		_victim.set_trait(&"floater")
		_floater_set = true
	# 2) eject 전: victim을 builder body_cell에 매 프레임 고정해 끼임 유도.
	if not _ejected:
		if _victim.state_machine.current_state is FallerState:
			_ejected = true
			if _victim.direction != _victim_dir:
				_fail("direction 반전! before=%d after=%d" % [_victim_dir, _victim.direction])
				return
			print("[BuildEjectStuckTest] victim ejected → FallerState, direction 유지(%d) frame=%d" % [_victim.direction, _frame])
			return
		# victim을 builder와 정확히 같은 위치(같은 발판)에 고정 → 같은 body_cell. builder가 그 셀에 rung을
		# 놓는 tick에 _eject_stuck_ants가 victim(시전 개미 아님)을 밀어낸다. 셀 중심으로 두면 공중이라
		# victim이 자연 낙하(eject_fall=false)해 끼임이 아니라 일반 낙하로 오인된다.
		_victim.global_position = _builder.global_position
		_victim.velocity = Vector2.ZERO
		_victim_dir = _victim.direction
		return
	# 3) eject 후: victim 착지(walker 복귀) → floater 보존 단언.
	if _victim.state_machine.current_state is WalkerState:
		if _victim.has_trait(&"floater"):
			print("[BuildEjectStuckTest] PASS — 밀림 + direction 유지(%d) + floater 보존(착지 후)" % _victim.direction)
			_done = true
			get_tree().quit(0)
		else:
			_fail("floater 소모됨 — 착지 후 사라짐(보존돼야 함)")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s" % str(result.get("reason", "?")))

func _fail(msg: String) -> void:
	print("[BuildEjectStuckTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
