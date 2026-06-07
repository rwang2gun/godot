extends Node

# Campaign S9 음성 짝 ② — sand_mound만 빼고 bridge+basher는 시전(blocker도 미시전). 게이트1 호수(다리)와
# 게이트2 좌 기둥(basher 통로)은 통과해 중앙 빈 방(cols16-20)에 진입하지만, 지붕(row6) 위 candy(15,5)로
# 오를 유일 수단인 sand_mound 사다리가 없어 방 안에서 좌우 기둥 사이를 왕복할 뿐 → candy 도달 불가 →
# picks==0. (basher 통로는 row9 수평이라 지붕으로 올려주지 못한다 — 수직 등반은 sand_mound 전담.)
# 이로써 sand_mound가 3관문 중 독립적으로 필수임을 입증(클리어 짝 CampaignS9ClearTest와 대비).
# (2026-06-07 재저작: 구 게이트3 builder 계단 → sand_mound 수직 사다리로 교체됨. 옛 CampaignS9NoBuilderTest 대체.)
# PASS: stage_failed && picks==0 && reached_room. FAIL: stage_cleared (sand_mound 없이 클리어 = 게이트3 무력) / deadline.

const DEADLINE_FRAMES: int = 30000
const CELL_SIZE: int = 48
const BRIDGE_X_MIN: float = 384.0
const BRIDGE_X_MAX: float = 432.0

# col16 좌측 끝(x∈[768,816)) = basher 통로(cols14-15)를 빠져나와 중앙 빈 방에 진입한 증거. 기둥을 뚫는
# basher 통로 없이는 이 x에 닿을 수 없다 → 게이트1·2를 물리적으로 통과한 증거(apply() 호출만이 아님).
const ROOM_APPROACH_X: float = 768.0

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _bridge_applied: bool = false
var _bashes: int = 0
var _reached_room: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS9NoSandMoundTest] driver ready (bridge+basher only, no sand_mound)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_terrain()
	if not _bridge_applied:
		_apply_bridge()
	_drive_basher()
	_track_room_approach()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d bridge=%s bashes=%d reached_room=%s (음성 테스트는 stage_failed로 종료돼야 함)" % [
			_picks, _bridge_applied, _bashes, _reached_room])

func _ensure_terrain() -> void:
	if _terrain != null and is_instance_valid(_terrain):
		return
	var stage: Node = get_node_or_null("../CampaignStage")
	if stage != null:
		_terrain = stage.get_node_or_null("World/Terrain") as Terrain

# 어떤 개미가 방 진입 col16(x>=768)에 실제 도달 = 호수(다리)+좌 기둥(basher 통로)을 물리적으로 통과한 증거.
func _track_room_approach() -> void:
	if _reached_room:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.global_position.x >= ROOM_APPROACH_X:
			_reached_room = true
			return

func _apply_bridge() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_candy:
			continue
		if a.global_position.x < BRIDGE_X_MIN or a.global_position.x >= BRIDGE_X_MAX:
			continue
		if not a.cliff_ahead():
			continue
		var bridge: BridgeSkill = BridgeSkill.new()
		if not bridge.can_apply(a):
			continue
		bridge.apply(a)
		_bridge_applied = true
		return

func _drive_basher() -> void:
	if _terrain == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.has_candy or a.direction != 1:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor():
			continue
		var body_cell: Vector2i = Vector2i(
			int(floor(a.global_position.x / CELL_SIZE)),
			int(floor((a.global_position.y - 2.0) / CELL_SIZE))
		)
		if body_cell.x != 13:
			continue
		if _terrain.get_cell_kind(body_cell + Vector2i(1, 0)) != "earth":
			continue
		var basher: BasherSkill = BasherSkill.new()
		if basher.can_apply(a):
			basher.apply(a)
			_bashes += 1

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without sand_mound — 지붕 위 candy를 사다리 없이 도달 = 게이트3 무력")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	# 개미가 호수(다리)+좌 기둥(통로)을 지나 방(col16)까지 실제 도달(_reached_room)했는데 게이트3(sand_mound
	# 부재)에서 막혀 picks==0이어야 sand_mound의 독립 필수성이 증명된다. apply() 호출(_bashes>0)만으론
	# 부족 — basher가 통로를 완성 못 해도 WorkerState 진입만으로 증가하므로, 실제 방 도달 위치를 단언한다.
	if _picks == 0 and _reached_room:
		print("[CampaignS9NoSandMoundTest] PASS stage_failed reason=%s picks=0 reached_room=true bridge=%s bashes=%d (sand_mound 필수성 입증) frame=%d" % [
			str(result.get("reason", "?")), _bridge_applied, _bashes, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS9NoSandMoundTest] FAIL stage_failed picks=%d reached_room=%s bridge=%s bashes=%d (선행 게이트 미통과 or candy 도달?) frame=%d" % [
			_picks, _reached_room, _bridge_applied, _bashes, _frame])
		get_tree().quit(1)

func _fail(msg: String) -> void:
	print("[CampaignS9NoSandMoundTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
