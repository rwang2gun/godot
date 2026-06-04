extends Node

# 다리 체인 건설 검증 (2026-06-04) — 다리 끝(낭떠러지)에서 무장한 후속 개미가 이어 건설하는가.
# 갭 12칸(cols 11~22) > 다리 캡 5칸이라 한 다리로는 못 건넌다. 좌측 평지에서 개미 2마리를 bridge 무장 →
# 첫 개미가 col10 낭떠러지에서 5칸 다리(cols11~15) 건설 → 둘째 개미가 그 다리 위를 걸어 col15 끝(낭떠러지)에
# 도달하면 try_build_armed_bridge가 발화해 cols16~20을 이어 건설해야 한다.
#
# PASS: tile_count > 5 (둘째 다리 세그먼트가 캡 5칸을 넘어 추가됨 = 체인 성립).
# FAIL: deadline까지 tile_count <= 5 (둘째 개미가 다리 끝에서 건설 못 하고 낙하 = 체인 불가).

const DEADLINE_FRAMES: int = 2400
const ARM_X_MAX: float = 300.0   # col ~9 이하 좌측 평지 — 낭떠러지(col10) 전이라 무장(즉시 건설 X).
const UPPER_Y_MAX: float = 720.0 # 상단 평지(row20≈640)만, 하단 바닥(row25≈800) 제외.
const ARM_COUNT: int = 2

var _terrain: Terrain = null
var _armed_ids: Dictionary = {}
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	print("[BridgeChainTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_arm_when_ready()
	_check_chain()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — tile_count=%d armed=%d" % [_tile_count(), _armed_ids.size()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../BridgeTooLongStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _arm_when_ready() -> void:
	if _armed_ids.size() >= ARM_COUNT:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if _armed_ids.has(a.get_instance_id()):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor() or a.direction != 1:
			continue
		if a.global_position.x >= ARM_X_MAX or a.global_position.y >= UPPER_Y_MAX:
			continue
		var bridge: BridgeSkill = BridgeSkill.new()
		if not bridge.can_apply(a):
			continue
		bridge.apply(a)
		_armed_ids[a.get_instance_id()] = true
		print("[BridgeChainTest] armed bridge → id=%d pos=%s frame=%d (total=%d)" % [
			a.get_instance_id(), a.global_position, _frame, _armed_ids.size()])
		if _armed_ids.size() >= ARM_COUNT:
			return

func _check_chain() -> void:
	var tc: int = _tile_count()
	if tc > 5:
		print("[BridgeChainTest] PASS — chained bridge tile_count=%d (>5, 둘째 세그먼트 건설됨) frame=%d" % [tc, _frame])
		_done = true
		get_tree().quit(0)

func _tile_count() -> int:
	return _terrain.tile_count() if _terrain != null else -1

func _fail(msg: String) -> void:
	print("[BridgeChainTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
