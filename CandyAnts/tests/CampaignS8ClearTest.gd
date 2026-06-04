extends Node

# Campaign S8 "박하 덤불" — cutter로 식물 벽(cols12-14 rows5-9)을 통째로 베어 Home↔Candy 횡단.
# 경로 중간 sticky(cols5-7 row9)는 개미를 잠시 정지시키지만 죽이지 않는다(lost==0 불변).
# 플레이어 모사:
#   우향 보행 중(미운반)인 개미의 **전방 body cell이 plant**일 때 CutterSkill 적용 → WorkerState("cutter")가
#   전방 덩쿨과 연결된 plant 클러스터 전체를 flood-fill로 1회 제거(Terrain.shatter_connected_plants) → walker 복귀.
#   덩쿨이 통째로 사라져 길이 영구히 열리므로 후속·귀가 개미가 같은 길로 통행(시전 1회로 충분, forward-plant 게이트라 재시전 없음).
# candy_hp 4 → 4마리가 candy를 회수해 귀가하면 클리어. PASS: stage_cleared && saved>=4 && lost==0.
# FAIL: stage_failed / deadline / saved<4 / lost>0.

const DEADLINE_FRAMES: int = 18000
const CELL_SIZE: int = 48

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _cuts: int = 0
var _terrain: Terrain = null

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS8ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_terrain()
	_drive_cutter()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d cuts=%d" % [_picks, _cuts])

func _ensure_terrain() -> void:
	if _terrain != null and is_instance_valid(_terrain):
		return
	var stage: Node = get_node_or_null("../CampaignStage")
	if stage != null:
		_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _drive_cutter() -> void:
	if _terrain == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		# 우향 보행·미운반·바닥 위 개미만 — 전방 body cell이 plant(식물 벽)일 때만 시전.
		# forward-plant 게이트라 통로가 절단된 뒤엔(전방=공기) 누구도 재시전하지 않는다.
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
		if _terrain.get_cell_kind(body_cell + Vector2i(1, 0)) != "plant":
			continue
		var cutter: CutterSkill = CutterSkill.new()
		if cutter.can_apply(a):
			cutter.apply(a)
			_cuts += 1
			print("[CampaignS8ClearTest] cutter → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS8ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS8ClearTest] PASS stage_cleared saved=%d/%d lost=%d cuts=%d frame=%d" % [saved, orig, lost, _cuts, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS8ClearTest] FAIL cleared but saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d cuts=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _cuts, _frame])

func _fail(msg: String) -> void:
	print("[CampaignS8ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
