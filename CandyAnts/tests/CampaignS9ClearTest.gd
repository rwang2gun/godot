extends Node

# Campaign S9 "종합 과자점" — 마지막 스테이지. bridge + basher + builder 복합 3관문을 한 선두 개미가
# 순서대로 통과해 영구 구조물(다리/통로/계단)을 남기면 후속·귀가 개미가 그대로 재사용해 candy 회수.
#   ① 게이트1 소다 호수(cols9-12): col8(x∈[384,432))서 bridge → row10 평지 다리 4칸 → 호수 횡단.
#   ② 게이트2 흙 벽(cols15-16 rows5-9): 중앙 지면서 전방 body cell이 earth일 때 basher → 2칸 수평 통로.
#   ③ 게이트3 높은 단(cols21-23 surface row6): col17(x∈[816,864))서 builder → 대각 계단 → 단 등반.
# bridge/builder는 무장 상호 배타(코어)라 서로 다른 cliff(게이트1·게이트3)에서 *즉시 건설*로 적용 —
#   각 cliff_ahead 위치에서 apply하면 bridge가 소비된 뒤 builder가 적용되어 상호 배타 위반이 없다.
#   basher는 비-무장(forward-earth 게이트)이라 벽 앞에서 독립 시전.
# candy_hp 5 → 5마리가 candy를 회수해 귀가하면 클리어. floater는 인벤토리 보험(드라이버 미사용).
# PASS: stage_cleared && saved>=original_hp && lost==0. FAIL: stage_failed / deadline / saved<5 / lost>0.

const DEADLINE_FRAMES: int = 30000
const CELL_SIZE: int = 48
const BRIDGE_X_MIN: float = 384.0    # col8 시작 (호수 직전 마지막 좌측 지면) — cliff_ahead → 즉시 다리 건설.
const BRIDGE_X_MAX: float = 432.0    # col9 (호수) 전까지.
const BUILDER_X_MIN: float = 816.0   # col17 시작 (게이트3 갭 직전, basher 통로 출구) — cliff_ahead → 즉시 계단.
const BUILDER_X_MAX: float = 864.0   # col18 (갭) 전까지.

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _bashes: int = 0
var _bridge_applied: bool = false
var _builder_applied: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS9ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_terrain()
	if not _bridge_applied:
		_apply_bridge()
	_drive_basher()
	if not _builder_applied:
		_apply_builder()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d bashes=%d bridge=%s builder=%s" % [
			_picks, _bashes, _bridge_applied, _builder_applied])

func _ensure_terrain() -> void:
	if _terrain != null and is_instance_valid(_terrain):
		return
	var stage: Node = get_node_or_null("../CampaignStage")
	if stage != null:
		_terrain = stage.get_node_or_null("World/Terrain") as Terrain

# 게이트1 — 호수 직전 col8에서 bridge. cliff_ahead라 apply가 즉시 WorkerState("bridge")로 건설.
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
		print("[CampaignS9ClearTest] bridge → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

# 게이트2 — 흙 벽 앞(전방 body cell == earth)에서 basher. forward-earth 게이트라 통로가 뚫린 뒤엔 재시전 없음.
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
		# 흙 벽(cols15-16) 직전 col14에서만 시전. 게이트3 builder 첫 계단 (17,9)는 동적 STAIR라 kind="earth"인데,
		# 후속 개미가 col16에서 그 계단을 "전방 흙"으로 오인해 부수면 계단 바닥이 사라져 등반·귀가가 막힌다.
		# 실제 플레이어도 벽만 시전하므로 벽 직전 col로 제한(body_cell.x >= 15 차단).
		if body_cell.x >= 15:
			continue
		if _terrain.get_cell_kind(body_cell + Vector2i(1, 0)) != "earth":
			continue
		var basher: BasherSkill = BasherSkill.new()
		if basher.can_apply(a):
			basher.apply(a)
			_bashes += 1
			print("[CampaignS9ClearTest] basher → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])

# 게이트3 — 단 직전 col17에서 builder. bridge가 게이트1에서 이미 소비돼 무장 상호 배타에 안 걸린다.
# cliff_ahead라 apply가 즉시 WorkerState("builder")로 대각 계단 건설.
func _apply_builder() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_candy:
			continue
		if a.global_position.x < BUILDER_X_MIN or a.global_position.x >= BUILDER_X_MAX:
			continue
		var builder: BuilderSkill = BuilderSkill.new()
		if not builder.can_apply(a):
			continue
		builder.apply(a)
		_builder_applied = true
		print("[CampaignS9ClearTest] builder → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS9ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	# 회계뿐 아니라 3개 게이트가 실제로 발동했는지 단언한다(codex MEDIUM) — bridge/basher/builder 중 하나라도
	# 불필요해지는 기하 회귀가 "saved/lost만 맞으면" 통과해 3관문 설계가 무너지는 것을 차단. 게이트별 독립
	# 필수성은 NoBasher/NoBuilder 음성 짝이 추가로 보증한다.
	var gates_ok: bool = _bridge_applied and _builder_applied and _bashes > 0
	if orig > 0 and saved >= orig and lost == 0 and gates_ok:
		print("[CampaignS9ClearTest] PASS stage_cleared saved=%d/%d lost=%d bashes=%d bridge=%s builder=%s frame=%d" % [
			saved, orig, lost, _bashes, _bridge_applied, _builder_applied, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS9ClearTest] FAIL cleared but saved=%d/%d lost=%d bridge=%s builder=%s bashes=%d (3게이트 미충족?) frame=%d" % [
			saved, orig, lost, _bridge_applied, _builder_applied, _bashes, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d bashes=%d bridge=%s builder=%s frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _bashes,
		_bridge_applied, _builder_applied, _frame])

func _fail(msg: String) -> void:
	print("[CampaignS9ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
