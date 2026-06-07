extends Node

# Campaign S9 "종합 과자점" — 마지막 스테이지. bridge + basher + sand_mound 복합 3관문을 한 선두 개미가
# 순서대로 통과해 영구 구조물(다리/통로/사다리)을 남기면 후속·귀가 개미가 그대로 재사용해 candy 회수.
# (2026-06-07 재저작 반영: 구 builder 게이트3 → sand_mound 수직 사다리 등반으로 교체. 인벤토리에서
#  builder 제거, sand_mound 추가. blocker는 보험 도구로 인벤토리에만 존재, 드라이버 미사용.)
# 지형(cell 48, +Y 아래):
#   · 좌 지면 cols0-8 (보행면 row10 상단 y=480, body row9). home(1,9).
#   · 소다 호수 갭 cols9-11 (3칸, 아래 water 즉사).
#   · 우 구조 cols12-23: base rows10~. 좌 기둥 cols14-15 rows6-9 + 우 기둥 cols21-23 rows6-9 +
#     중앙 빈 방 cols16-20 rows7-9(바닥 row10) + 지붕/플랫폼 row6 cols14-23. candy(15,5) 지붕 위 col15.
#   ① 게이트1 소다 호수: col8(x∈[384,432)) 낭떠러지서 bridge → cols9-11 다리 → 우 base col12 도달.
#   ② 게이트2 좌 기둥: base 보행 중 전방 body cell(col14)이 earth일 때(col13) basher → cols14-15 2칸 통로
#      → 중앙 빈 방 col16 진입.
#   ③ 게이트3 지붕 등반: 빈 방 col16~ row9서 sand_mound → 수직 rung 사다리가 지붕(row6) 아래에서 cap →
#      개미가 지붕 위(row5)로 올라섬 → 좌향 보행해 candy(15,5) 회수.
#   ④ 보조 blocker: 지붕 위로 cap한 개미가 candy 반대(우측)로 걸어 우 끝서 추락하는 것을 막도록 col18에
#      blocker 1마리 정착 → 후속 개미가 좌향 반전해 candy로 향함. total6 중 1마리 희생, 5마리가 hp5 배달.
#   귀가: 지붕(row6)→base(row10) 4칸 안전 하강 → 통로 → 다리 → home (floater 불요, 4칸<5칸 기절 임계).
# candy_hp 5 → 5마리 회수+귀가. PASS: stage_cleared && saved>=original_hp && lost==0.
# 게이트 발동 단언(bridge/basher/sand_mound/blocker 모두) — 한 게이트라도 불필요해지는 기하 회귀 차단.

const DEADLINE_FRAMES: int = 30000
const CELL_SIZE: int = 48
const DIAG: bool = false

# 게이트1 — 호수 직전 col8(x∈[384,432)) 낭떠러지서 즉시 다리 건설.
const BRIDGE_X_MIN: float = 384.0
const BRIDGE_X_MAX: float = 432.0

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _bashes: int = 0
var _bridge_applied: bool = false
var _sand_mound_applied: bool = false
var _blocker_applied: bool = false
var _terrain: Terrain = null
var _diag_last: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
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
	if not _sand_mound_applied:
		_apply_sand_mound()
	if not _blocker_applied:
		_apply_blocker()
	if DIAG and _frame - _diag_last >= 60:
		_diag_last = _frame
		_dump_ants()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d bashes=%d bridge=%s sand_mound=%s" % [
			_picks, _bashes, _bridge_applied, _sand_mound_applied])

func _ensure_terrain() -> void:
	if _terrain != null and is_instance_valid(_terrain):
		return
	var stage: Node = get_node_or_null("../CampaignStage")
	if stage != null:
		_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _dump_ants() -> void:
	var parts: Array[String] = []
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		var st: String = "?"
		if a.state_machine != null and a.state_machine.current_state != null:
			var s: Object = a.state_machine.current_state
			st = str(s.get_script().resource_path.get_file()) if s.get_script() != null else st
		parts.append("[%s d=%d x=%.0f y=%.0f %s c=%s]" % [a.name, a.direction, a.global_position.x, a.global_position.y, st, a.has_candy])
	print("[S9 f=%d] %s" % [_frame, " ".join(parts)])

# 게이트1 — 호수 직전 col8서 bridge. cliff_ahead라 apply가 즉시 WorkerState("bridge")로 건설.
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
		print("[CampaignS9ClearTest] bridge → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

# 게이트2 — 좌 기둥(col14) 직전 col13에서 basher. 전방 body cell == earth일 때만 시전.
# 통로가 뚫린 뒤(col16 진입 가능)엔 forward-earth 게이트가 false라 재시전 없음.
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
		# 좌 기둥(cols14-15) 직전 col13에서만. (귀가/등반 개미가 다른 흙을 오인 시전하지 않도록 col13으로 제한.)
		if body_cell.x != 13:
			continue
		if _terrain.get_cell_kind(body_cell + Vector2i(1, 0)) != "earth":
			continue
		var basher: BasherSkill = BasherSkill.new()
		if basher.can_apply(a):
			basher.apply(a)
			_bashes += 1
			print("[CampaignS9ClearTest] basher → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])

# 게이트3 — 중앙 빈 방(col16~) row9서 sand_mound. 수직 rung 사다리가 지붕(row6) 아래서 cap → 지붕 등반.
func _apply_sand_mound() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_candy:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor():
			continue
		var body_cell: Vector2i = Vector2i(
			int(floor(a.global_position.x / CELL_SIZE)),
			int(floor((a.global_position.y - 2.0) / CELL_SIZE))
		)
		# 빈 방 col16에서 시전 (통로를 빠져나와 우 기둥 col21 전). 지붕(row6) 바로 아래라 cap 등반.
		if body_cell.x != 16 or body_cell.y != 9:
			continue
		var skill: SandMoundSkill = SandMoundSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_sand_mound_applied = true
		print("[CampaignS9ClearTest] sand_mound → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

# 게이트3 보조 — 지붕(row6) 위로 cap한 개미가 우향(candy 반대)으로 걸어 우 끝(col23)서 추락하는 것을 막는
# blocker. cap 지점(col16) 우측 col18 지붕에 blocker 1마리 정착 → 후속 개미가 좌향 반전해 candy(col15)로 향함.
# (blocker는 candy 미운반 = 회계 무관. total6 중 1마리 희생, 나머지 5마리가 hp5 배달 = saved5.)
func _apply_blocker() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_candy:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor():
			continue
		var body_cell: Vector2i = Vector2i(
			int(floor(a.global_position.x / CELL_SIZE)),
			int(floor((a.global_position.y - 2.0) / CELL_SIZE))
		)
		# 지붕(row5 body, 지붕 표면 row6 top) col18에서 정착 — cap(col16) 우측, candy(col15) 반대편.
		if body_cell.y != 5 or body_cell.x != 18:
			continue
		var blocker: BlockerSkill = BlockerSkill.new()
		if not blocker.can_apply(a):
			continue
		blocker.apply(a)
		_blocker_applied = true
		print("[CampaignS9ClearTest] blocker → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
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
	# 3개 게이트가 실제로 발동했는지 단언 — bridge/basher/sand_mound 중 하나라도 불필요해지는 기하 회귀가
	# "saved/lost만 맞으면" 통과해 3관문 설계가 무너지는 것을 차단. 게이트별 독립 필수성은 음성 짝이 보증한다.
	var gates_ok: bool = _bridge_applied and _sand_mound_applied and _blocker_applied and _bashes > 0
	if orig > 0 and saved >= orig and lost == 0 and gates_ok:
		print("[CampaignS9ClearTest] PASS stage_cleared saved=%d/%d lost=%d bashes=%d bridge=%s sand_mound=%s blocker=%s frame=%d" % [
			saved, orig, lost, _bashes, _bridge_applied, _sand_mound_applied, _blocker_applied, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS9ClearTest] FAIL cleared but saved=%d/%d lost=%d bridge=%s sand_mound=%s blocker=%s bashes=%d (게이트 미충족?) frame=%d" % [
			saved, orig, lost, _bridge_applied, _sand_mound_applied, _blocker_applied, _bashes, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d bashes=%d bridge=%s sand_mound=%s blocker=%s frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _bashes,
		_bridge_applied, _sand_mound_applied, _blocker_applied, _frame])

func _fail(msg: String) -> void:
	print("[CampaignS9ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
