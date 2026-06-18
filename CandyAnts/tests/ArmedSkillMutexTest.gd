extends Node2D
# codex 2026-06-03 MEDIUM 회귀 — 무장 스킬(bridge/builder/basher/cutter)은 상호 배타. 한 ant에 둘 이상
# 무장되면 벽/낭떠러지에서 먼저 발화하는 스킬이 나머지를 그림자 처리하므로, can_apply가 교차 차단해야 한다.
# (2026-06-05 basher/cutter도 armed 패턴으로 전환되며 4종 상호 배타로 확장.)
#
# 검증: 평지 WalkerState ant에 대해 (1) 모두 미무장 → 4종 모두 can_apply true (2) bridge_armed → 4종 모두 false
# (3) builder_armed → 4종 모두 false (4) basher_armed → 4종 모두 false (5) cutter_armed → 4종 모두 false.

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
	# (1) 모두 미무장 → 4종 모두 부여 가능.
	_clear_armed()
	if not _all_can_apply():
		return _fail("sanity: 미무장 walker에서 4종 중 can_apply false 발생")

	# (2)~(5) 각 무장 플래그 1개만 set → 4종 모두 차단되어야 함(재무장 + 교차 그림자 처리 위험).
	for armed_flag: String in ["bridge_armed", "builder_armed", "basher_armed", "cutter_armed"]:
		_clear_armed()
		_ant.set(armed_flag, true)
		var blocked: String = _first_unblocked()
		if blocked != "":
			return _fail("%s 무장 중인데 %s.can_apply true (상호 배타 위반)" % [armed_flag, blocked])

	_clear_armed()
	print("[ArmedSkillMutexTest] PASS bridge/builder/basher/cutter armed 4-way mutual exclusion enforced")
	_done = true
	get_tree().quit(0)

func _clear_armed() -> void:
	_ant.bridge_armed = false
	_ant.builder_armed = false
	_ant.basher_armed = false
	_ant.cutter_armed = false

func _all_can_apply() -> bool:
	return BridgeSkill.new().can_apply(_ant) and SlideRSkill.new().can_apply(_ant) \
		and BasherSkill.new().can_apply(_ant) and CutterSkill.new().can_apply(_ant)

# 무장 상태에서 차단 안 된(can_apply true) 첫 스킬 이름 반환. 모두 차단되면 "".
func _first_unblocked() -> String:
	if BridgeSkill.new().can_apply(_ant): return "bridge"
	if SlideRSkill.new().can_apply(_ant): return "slideR"
	if BasherSkill.new().can_apply(_ant): return "basher"
	if CutterSkill.new().can_apply(_ant): return "cutter"
	return ""

func _fail(msg: String) -> void:
	print("[ArmedSkillMutexTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
