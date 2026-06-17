extends Node

# Campaign scene_id 13 "방향 전환" (Ch1 slot4) — blocker+climber 콤보 클리어 가능성 검증.
# 좌측 고원(cols0-8, 표면 row6) 위에 home(col1)+candy(col4), spawn은 평지 col10(spawn≠home),
# 평지 우측 끝은 water 절벽(cols18+ 바다).
# 플레이어 모사:
#   1) 최전방 walker가 절벽 직전 col14.5(x>=696) 도달 시 BlockerSkill 적용 → 무리 반전.
#   2) 이후 나머지 walker 전원에 ClimberSkill(최대 5) → 좌향 무리가 고원 동벽(col8, 4칸)을 등반
#      → 고원 위 candy 픽업(자동 반전=우향) → 동쪽 모서리에서 4칸 낙하(안전) → blocker에 튕겨 좌향
#      → 동벽 재등반(trait 영구) → candy 통과(has_been_carrying 재픽업 차단) → home(col1) → saved.
# PASS: stage_cleared && saved>=original_hp (반전+등반 콤보 경로 입증). FAIL: stage_failed / deadline.

const DEADLINE_FRAMES: int = 16000
const BLOCKER_X: float = 696.0
const MAX_CLIMBERS: int = 5

var _blocker_id: int = 0
var _climber_ids: Dictionary = {}
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS13ClearTest] driver ready blocker_x=%s max_climbers=%d" % [BLOCKER_X, MAX_CLIMBERS])

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_drive()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — blocker=%s climbers=%d" % [str(_blocker_id != 0), _climber_ids.size()])

func _drive() -> void:
	# 1) blocker 미배치 → 최전방 walker가 갭 직전 도달 시 배치. 배치 전엔 다른 스킬 부여 없음
	#    (최전방=blocker 후보를 climber로 오염시키지 않기 위해 순서 고정).
	if _blocker_id == 0:
		var front: Ant = null
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a == null or not is_instance_valid(a) or a.state_machine == null:
				continue
			if not (a.state_machine.current_state is WalkerState):
				continue
			if front == null or a.global_position.x > front.global_position.x:
				front = a
		if front == null or front.global_position.x < BLOCKER_X:
			return
		var bl: BlockerSkill = BlockerSkill.new()
		if not bl.can_apply(front):
			return
		bl.apply(front)
		_blocker_id = front.get_instance_id()
		print("[CampaignS13ClearTest] blocker → %s pos=%s frame=%d" % [front.name, front.global_position, _frame])
		return
	# 2) 후속 walker 전원에 climber (blocker 본인은 WorkerState라 자동 제외).
	if _climber_ids.size() >= MAX_CLIMBERS:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		if _climber_ids.size() >= MAX_CLIMBERS:
			return
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var id: int = a.get_instance_id()
		if id == _blocker_id or _climber_ids.has(id):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		var cl: ClimberSkill = ClimberSkill.new()
		if not cl.can_apply(a):
			continue
		cl.apply(a)
		_climber_ids[id] = true
		print("[CampaignS13ClearTest] climber #%d → %s frame=%d" % [_climber_ids.size(), a.name, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	var saved: int = int(result.get("saved", -1))
	var hp: int = int(result.get("original_hp", -1))
	if saved < hp:
		_fail("cleared but saved=%d < hp=%d" % [saved, hp])
		return
	print("[CampaignS13ClearTest] PASS stage_cleared saved=%d/%d frame=%d" % [saved, hp, _frame])
	_done = true
	get_tree().quit(0)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS13ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
