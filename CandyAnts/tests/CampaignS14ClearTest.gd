extends Node

# Campaign scene_id 14 "높은 곳에서" (Ch1 slot5) — floater(낙하산 분배자, NEW) 도입 클리어 가능성 검증.
# 고원(cols10-23, 표면 row4) 위에 spawn(col12)+candy(col22), 저지대(표면 row10)에 home(col2).
# 귀환은 고원 좌단(col10)에서 6칸 낙하(288px >= 기절 임계 240px) — 무보정 시 착지 기절+조각 손실.
# 플레이어 모사: 최전방 walker가 col13(x>=624) 도달 시 FloaterSkill 1개 적용 → 그 자리 정착(분배자)
#   → 이후 지나가는 모든 개미에게 floater 전이 → 운반 개미가 낙하 구간을 slow-fall로 안전 강하
#   → 저지대 home 귀가. PASS: stage_cleared && saved>=original_hp. FAIL: stage_failed / deadline.

const DEADLINE_FRAMES: int = 16000
const DISTRIBUTOR_X: float = 624.0

var _distributor_id: int = 0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS14ClearTest] driver ready distributor_x=", DISTRIBUTOR_X)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_apply_distributor()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — distributor_placed=%s" % str(_distributor_id != 0))

func _apply_distributor() -> void:
	if _distributor_id != 0:
		return
	var front: Ant = null
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if front == null or a.global_position.x > front.global_position.x:
			front = a
	if front == null or front.global_position.x < DISTRIBUTOR_X:
		return
	var fl: FloaterSkill = FloaterSkill.new()
	if not fl.can_apply(front):
		return
	fl.apply(front)
	_distributor_id = front.get_instance_id()
	print("[CampaignS14ClearTest] floater-distributor → %s pos=%s frame=%d" % [
		front.name, front.global_position, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	var saved: int = int(result.get("saved", -1))
	var hp: int = int(result.get("original_hp", -1))
	if saved < hp:
		_fail("cleared but saved=%d < hp=%d" % [saved, hp])
		return
	print("[CampaignS14ClearTest] PASS stage_cleared saved=%d/%d frame=%d" % [saved, hp, _frame])
	_done = true
	get_tree().quit(0)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS14ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
