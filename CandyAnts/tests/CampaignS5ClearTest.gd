extends Node

# Campaign S5 "막대과자 탑" — sand_mound 사다리로 고립 플랫폼 등반 + 낙하산 분배자로 6칸 하강 안전화.
# (2026-06-03 F-3 재작성: floater 스킬이 '자기 강하'가 아니라 '적용 즉시 정착+분배'로 바뀌어,
#  선두 1마리를 spawn 경로에 분배자로 정착시키고 후속 개미가 마커를 통과해 floater를 받아 하강.)
# 플레이어 모사:
#   (1) 선두 grounded walker 1마리에 floater 부여 → spawn 경로(지면)에 정착(희생) → 지나는 개미에 floater 분배.
#   (2) 후속 개미가 플랫폼 아래(cols14~17)서 sand_mound 시전 → rung 사다리 → 등반(영구라 후속 자동).
#       candy 회수 후 플랫폼 가장자리(6칸)를 분배받은 floater로 기절 없이 안전 하강.
# candy_hp 4 → 4마리 회수+귀가. PASS: stage_cleared && saved>=4 && lost==0.
# FAIL: stage_failed / deadline / saved<4 / lost>0.

const DEADLINE_FRAMES: int = 18000
const CAST_X_MIN: float = 672.0   # col14 — 플랫폼(cols13~19) 아래.
const CAST_X_MAX: float = 864.0

var _distributor_id: int = 0
var _cast_applied: bool = false
var _cast_ant: Ant = null
var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS5ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	# 1) 분배자 미선정 → 선두 grounded walker에 floater 부여(spawn 경로에 정착). 마커 통과자에 floater 분배.
	if _distributor_id == 0:
		_apply_distributor()
		return
	# 2) 후속 개미가 플랫폼 아래 도달 시 sand_mound 시전(분배자 제외).
	if not _cast_applied:
		_apply_sand_mound()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — distributor=%d cast=%s picks=%d %s" % [_distributor_id, _cast_applied, _picks, _cast_ant_diag()])

func _apply_distributor() -> void:
	var front: Ant = null
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if not a.is_on_floor():
			continue
		if front == null or a.global_position.x > front.global_position.x:
			front = a
	if front != null:
		var f: FloaterSkill = FloaterSkill.new()
		if f.can_apply(front):
			f.apply(front)
			_distributor_id = front.get_instance_id()
			print("[CampaignS5ClearTest] floater-distributor → %s pos=%s frame=%d" % [front.name, front.global_position, _frame])

func _apply_sand_mound() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.get_instance_id() == _distributor_id:
			continue
		if a.direction != 1 or a.has_been_carrying:
			continue
		if a.global_position.x < CAST_X_MIN or a.global_position.x >= CAST_X_MAX:
			continue
		var skill: SandMoundSkill = SandMoundSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_cast_applied = true
		_cast_ant = a
		print("[CampaignS5ClearTest] sand_mound → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

func _cast_ant_diag() -> String:
	if _cast_ant == null or not is_instance_valid(_cast_ant):
		return "cast_ant=<none>"
	var st: String = "?"
	if _cast_ant.state_machine != null and _cast_ant.state_machine.current_state != null:
		var s: Object = _cast_ant.state_machine.current_state
		st = str(s.get_script().resource_path.get_file()) if s.get_script() != null else st
	return "cast_ant pos=%s state=%s has_candy=%s" % [_cast_ant.global_position, st, _cast_ant.has_candy]

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS5ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS5ClearTest] PASS stage_cleared saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS5ClearTest] FAIL cleared but saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d %s frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _cast_ant_diag(), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS5ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
