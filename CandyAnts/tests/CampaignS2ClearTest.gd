extends Node

# Campaign S2 "오르막" — 낙하산 분배자(단일 스킬) 클리어 가능성 검증 (레벨 재설계 rev2, 2026-06-02 세션 3
#   + 2026-06-03 floater=분배자 통합).
# 플레이어 모사:
#   1) 최전방(frontmost) 개미 1마리에 floater **단독** 부여 → floater는 distributor 트레잇을 함께 부여하므로
#      col11 SettlementMarker에 정착 → 이후 지나가는 모든 개미에게 floater 전이("낙하산 분배자").
#   2) 후속 개미들엔 climber 부여 → 5칸 메사 등반. 사탕 픽업 후 복귀 시 5칸 낙하지만,
#      분배자에게서 받은 floater로 안전 착지(기절·lost 없음).
# climber 6 중 5 왕복이면 클리어(candy_hp 5). PASS: stage_cleared && saved==original_hp.
#   - floater를 후속 개미에 개별 부여하지 않았는데 saved==5면 → 분배자 floater 전이 경로가 실제로 동작함을 입증.
# FAIL: stage_failed / deadline / saved<original(전이 누락으로 조각 손실).
# 짝 테스트 CampaignS2NoFloaterTest(floater 부재 시 조각 손실)와 함께 "floater 필수"를 입증.

const DEADLINE_FRAMES: int = 16000
const MAX_CLIMBERS: int = 6

var _distributor_id: int = 0
var _climber_ids: Dictionary = {}   # instance_id → true
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS2ClearTest] driver ready max_climbers=", MAX_CLIMBERS)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_drive()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — distributor=%d climbers=%d" % [_distributor_id, _climber_ids.size()])

func _drive() -> void:
	# 1) 분배자 미선정 → 최전방 walker에 floater **단독** 부여. floater가 distributor 트레잇을 함께
	#    부여하므로 마커(col11) 도달 시 정착 → 낙하산 분배자가 됨. 마커 도달 전 선정 보장.
	if _distributor_id == 0:
		var front: Ant = null
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a == null or not is_instance_valid(a) or a.state_machine == null:
				continue
			if not (a.state_machine.current_state is WalkerState):
				continue
			if front == null or a.global_position.x > front.global_position.x:
				front = a
		if front != null:
			var fl: FloaterSkill = FloaterSkill.new()
			if fl.can_apply(front):
				fl.apply(front)
				_distributor_id = front.get_instance_id()
				print("[CampaignS2ClearTest] floater-distributor → %s pos=%s frame=%d" % [
					front.name, front.global_position, _frame])
		return
	# 2) 후속 개미 → climber (등반용). 분배자 본인엔 부여 금지(정착해야 함).
	if _climber_ids.size() >= MAX_CLIMBERS:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		if _climber_ids.size() >= MAX_CLIMBERS:
			return
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var id: int = a.get_instance_id()
		if id == _distributor_id or _climber_ids.has(id):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		var cl: ClimberSkill = ClimberSkill.new()
		if not cl.can_apply(a):
			continue
		cl.apply(a)
		_climber_ids[id] = true
		print("[CampaignS2ClearTest] climber #%d → %s frame=%d" % [_climber_ids.size(), a.name, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	if orig > 0 and saved >= orig:
		print("[CampaignS2ClearTest] PASS stage_cleared saved=%d/%d frame=%d" % [saved, orig, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS2ClearTest] FAIL cleared but saved=%d/%d (floater 전이 누락?) frame=%d" % [
			saved, orig, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS2ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
