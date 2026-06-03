extends Node

# Campaign S9 음성 짝 ③ — builder만 빼고 bridge+basher는 시전. 게이트3 높은 단(surface row6) 앞 갭(cols18-20)을
# 계단 없이 넘으려다 추락 → 단·candy 도달 불가 → picks==0. (bridge로 호수, basher로 흙 벽은 통과하지만 갭에서 멈춤.)
# floater도 미시전이라 갭 추락은 그대로 lost → no_more_ants. builder가 3관문 중 독립적으로 필수임을 입증.
# PASS: stage_failed && picks==0. FAIL: stage_cleared (builder 없이 클리어 = 게이트3 무력) / deadline.

const DEADLINE_FRAMES: int = 30000
const CELL_SIZE: int = 48
const BRIDGE_X_MIN: float = 384.0
const BRIDGE_X_MAX: float = 432.0
const GAP_APPROACH_X: float = 816.0  # col17 — 호수+흙 벽 통로를 지나 게이트3 갭 직전에 실제 도달한 증거.

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _bridge_applied: bool = false
var _bashes: int = 0
var _reached_gap: bool = false  # 어떤 개미가 호수+흙 벽을 지나 갭 앞(col17)까지 실제 도달했는가(게이트1·2 통과 증거).
var _terrain: Terrain = null

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS9NoBuilderTest] driver ready (bridge+basher only, no builder)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_terrain()
	if not _bridge_applied:
		_apply_bridge()
	_drive_basher()
	_track_gap_approach()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d bridge=%s bashes=%d (음성 테스트는 stage_failed로 종료돼야 함)" % [
			_picks, _bridge_applied, _bashes])

func _ensure_terrain() -> void:
	if _terrain != null and is_instance_valid(_terrain):
		return
	var stage: Node = get_node_or_null("../CampaignStage")
	if stage != null:
		_terrain = stage.get_node_or_null("World/Terrain") as Terrain

# 어떤 개미가 갭 직전 col17(x>=816)에 실제 도달 = 호수(다리)+흙 벽(basher 통로)을 물리적으로 통과한 증거.
# (흙 벽 cols15-16은 통로가 뚫려야만 col17에 닿을 수 있다 — apply() 호출만이 아닌 실제 통과를 보증.)
func _track_gap_approach() -> void:
	if _reached_gap:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.global_position.x >= GAP_APPROACH_X:
			_reached_gap = true
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
		if body_cell.x >= 15:
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
	_fail("stage_cleared without builder — 높은 단을 계단 없이 도달 = 게이트3 무력")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	# 개미가 호수(다리)+흙 벽(통로)을 지나 갭 앞(col17)까지 실제 도달(_reached_gap)했는데 게이트3(builder 부재)에서
	# 막혀 picks==0이어야 builder의 독립 필수성이 증명된다. apply() 호출(_bashes>0)만으론 부족 — basher가 통로를
	# 완성 못 해도 WorkerState 진입만으로 증가하므로, 실제 갭 도달 위치를 단언한다(codex R2 MEDIUM).
	if _picks == 0 and _reached_gap:
		print("[CampaignS9NoBuilderTest] PASS stage_failed reason=%s picks=0 reached_gap=true bridge=%s bashes=%d (builder 필수성 입증) frame=%d" % [
			str(result.get("reason", "?")), _bridge_applied, _bashes, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS9NoBuilderTest] FAIL stage_failed picks=%d reached_gap=%s bridge=%s bashes=%d (선행 게이트 미통과 or candy 도달?) frame=%d" % [
			_picks, _reached_gap, _bridge_applied, _bashes, _frame])
		get_tree().quit(1)

func _fail(msg: String) -> void:
	print("[CampaignS9NoBuilderTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
