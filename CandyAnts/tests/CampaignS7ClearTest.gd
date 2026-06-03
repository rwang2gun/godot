extends Node

# Campaign S7 "옆파기" — basher로 흙 벽(cols9-12 rows5-9)에 2칸 높이 수평 통로를 뚫어 Home↔Candy 횡단.
# 플레이어 모사:
#   우향 보행 중(미운반)인 개미의 **전방 body cell이 earth**일 때 BasherSkill 적용 → WorkerState("basher")가
#   body row + 위 row를 BASHER_MAX_CELLS까지 뚫고 벽 끝(공기)에서 자연 종료 → walker 복귀 → candy로 진행.
#   통로는 영구라 후속 개미·귀가 개미가 같은 통로로 통행(시전 1회로 충분, forward-earth 게이트라 재시전 없음).
# candy_hp 4 → 4마리가 candy를 회수해 귀가하면 클리어. PASS: stage_cleared && saved>=4 && lost==0.
# FAIL: stage_failed / deadline / saved<4 / lost>0.

const DEADLINE_FRAMES: int = 18000
const CELL_SIZE: int = 48

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _bashes: int = 0
var _terrain: Terrain = null

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS7ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_terrain()
	_drive_basher()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d bashes=%d" % [_picks, _bashes])

func _ensure_terrain() -> void:
	if _terrain != null and is_instance_valid(_terrain):
		return
	var stage: Node = get_node_or_null("../CampaignStage")
	if stage != null:
		_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _drive_basher() -> void:
	if _terrain == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		# 우향 보행·미운반·바닥 위 개미만 — 전방 body cell이 earth(흙 벽)일 때만 시전.
		# forward-earth 게이트라 통로가 뚫린 뒤엔(전방=공기) 누구도 재시전하지 않는다.
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
		if _terrain.get_cell_kind(body_cell + Vector2i(1, 0)) != "earth":
			continue
		var basher: BasherSkill = BasherSkill.new()
		if basher.can_apply(a):
			basher.apply(a)
			_bashes += 1
			print("[CampaignS7ClearTest] basher → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS7ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS7ClearTest] PASS stage_cleared saved=%d/%d lost=%d bashes=%d frame=%d" % [saved, orig, lost, _bashes, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS7ClearTest] FAIL cleared but saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d bashes=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _bashes, _frame])

func _fail(msg: String) -> void:
	print("[CampaignS7ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
