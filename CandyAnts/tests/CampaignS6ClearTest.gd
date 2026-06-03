extends Node

# Campaign S6 "땅굴" — digger로 흙 캡을 뚫고 깊은 공동을 강하 → 쿠키 챔버 candy 회수 → 귀가.
# (2026-06-03 F-3 재작성: floater 스킬이 '자기 강하'가 아니라 '적용 즉시 정착+분배'로 바뀌어,
#  선두 1마리를 메사 top spawn 경로에 분배자로 정착시키고 후속 개미가 마커를 통과해 floater를 받아 강하.)
# 플레이어 모사:
#   (1) 선두 grounded walker 1마리에 floater 부여 → 메사 top에 정착(희생) → 지나는 개미에 floater 분배.
#   (2) 후속 개미(메사 top 보행)에 digger 시전 → 흙 캡 수직 굴착 → 공동 강하. 개척자는 굴착 낙하라 무-floater 안전,
#       공유 갱도로 떨어지는 후속은 분배받은 floater로 7칸 공동을 안전 강하 → 챔버(쿠키) 도달.
# candy_hp 4 → 4마리 회수+귀가. PASS: stage_cleared && saved>=4 && lost==0.
# FAIL: stage_failed / deadline / saved<4 / lost>0.

const DEADLINE_FRAMES: int = 18000
const MESA_Y_MAX: float = 200.0   # 메사 top 영역(흙 캡 표면 y≈96). 챔버 개미(y≈600)는 제외.

var _distributor_id: int = 0
var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _digs: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS6ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	# 1) 분배자 미선정 → 메사 top 선두 grounded walker에 floater 부여(정착). 마커 통과자에 floater 분배.
	if _distributor_id == 0:
		_apply_distributor()
		return
	# 2) 메사 top 보행 중(미운반)인 비분배자 개미에 digger — 흙 캡 수직 굴착.
	_drive_digger()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — distributor=%d picks=%d digs=%d" % [_distributor_id, _picks, _digs])

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
		if a.global_position.y >= MESA_Y_MAX:
			continue
		if front == null or a.global_position.x > front.global_position.x:
			front = a
	if front != null:
		var f: FloaterSkill = FloaterSkill.new()
		if f.can_apply(front):
			f.apply(front)
			_distributor_id = front.get_instance_id()
			print("[CampaignS6ClearTest] floater-distributor → %s pos=%s frame=%d" % [front.name, front.global_position, _frame])

func _drive_digger() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.get_instance_id() == _distributor_id:
			continue
		if a.has_been_carrying or a.direction != 1:
			continue
		if a.global_position.y >= MESA_Y_MAX:
			continue
		var digger: DiggerSkill = DiggerSkill.new()
		if digger.can_apply(a):
			digger.apply(a)
			_digs += 1
			print("[CampaignS6ClearTest] digger → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS6ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS6ClearTest] PASS stage_cleared saved=%d/%d lost=%d digs=%d frame=%d" % [saved, orig, lost, _digs, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS6ClearTest] FAIL cleared but saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d digs=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _digs, _frame])

func _fail(msg: String) -> void:
	print("[CampaignS6ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
