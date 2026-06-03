extends Node2D
# codex 2026-06-03 MEDIUM 회귀 — 무장 스킬(bridge/builder)은 상호 배타. 한 ant에 둘 다 무장되면
# 낭떠러지에서 bridge가 먼저 발화해 builder를 그림자 처리하므로, can_apply가 교차 차단해야 한다.
#
# 검증: 평지 WalkerState ant에 대해 (1) 둘 다 미무장 → 둘 다 can_apply true (2) bridge_armed → bridge·builder
# 둘 다 can_apply false (3) builder_armed → builder·bridge 둘 다 can_apply false.

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const CS: int = 48

var _ant: Ant = null
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	var terrain: Terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.set_cell_size(CS)
	add_child(terrain)
	for c in range(0, 6):
		terrain.add_tile(Vector2i(c, 8), Terrain.DYNAMIC_TILE_BRIDGE)
	_ant = ANT_SCENE.instantiate() as Ant
	_ant.direction = 1
	_ant.global_position = Vector2(2 * CS + 24, 8 * CS - 8)
	add_child(_ant)
	print("[ArmedSkillMutexTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	# 평지 floor 위 WalkerState 안착 대기.
	if not (_ant.state_machine.current_state is WalkerState and _ant.is_on_floor()):
		if _frame > 180:
			_fail("ant never reached WalkerState on floor (frame=%d)" % _frame)
		return
	_run_assertions()

func _run_assertions() -> void:
	var bridge: BridgeSkill = BridgeSkill.new()
	var builder: BuilderSkill = BuilderSkill.new()

	# (1) 둘 다 미무장 → 둘 다 부여 가능.
	_ant.bridge_armed = false
	_ant.builder_armed = false
	if not bridge.can_apply(_ant):
		return _fail("sanity: bridge.can_apply false on unarmed walker")
	if not builder.can_apply(_ant):
		return _fail("sanity: builder.can_apply false on unarmed walker")

	# (2) bridge 무장 → bridge(재무장)·builder(교차) 둘 다 차단.
	_ant.bridge_armed = true
	_ant.builder_armed = false
	if bridge.can_apply(_ant):
		return _fail("bridge re-arm not blocked while bridge_armed")
	if builder.can_apply(_ant):
		return _fail("builder not blocked while bridge_armed (그림자 처리 위험)")

	# (3) builder 무장 → builder(재무장)·bridge(교차) 둘 다 차단.
	_ant.bridge_armed = false
	_ant.builder_armed = true
	if builder.can_apply(_ant):
		return _fail("builder re-arm not blocked while builder_armed")
	if bridge.can_apply(_ant):
		return _fail("bridge not blocked while builder_armed")

	_ant.builder_armed = false
	print("[ArmedSkillMutexTest] PASS bridge/builder armed mutual exclusion enforced")
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[ArmedSkillMutexTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
