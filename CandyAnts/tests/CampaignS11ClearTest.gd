extends Node

# Campaign scene_id 11 "담을 넘어" (Ch1 slot2) — climber 심화 클리어 가능성 검증.
# 평지 직선 경로 중앙의 3칸 벽(cols11-12)을 climber로 넘어 candy(col20) 도달·귀환해야 한다.
# 플레이어 모사: WalkerState/CarryingState 개미 최대 MAX_CLIMBERS(=인벤토리 5)에 climber 부여.
# Ch1 고정 지침(설계 §2.2, 2026-06-10): candy_hp=5 + total=5(소비 설치물 0 → 여분 0).
#   - 무스킬이면 벽(48px*3 > 개미 15px)에 is_on_wall로 막혀 flip → candy 미도달 → 클리어 불가.
#     즉 PASS는 climber 등반-over 경로가 실제로 동작함을 입증한다.
# PASS: stage_cleared (saved>=candy_hp). FAIL: stage_failed / deadline.

const DEADLINE_FRAMES: int = 16000
const MAX_CLIMBERS: int = 5

var _applied_ids: Dictionary = {}
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS11ClearTest] driver ready max_climbers=", MAX_CLIMBERS)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_apply_climbers()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%d" % _applied_ids.size())

func _apply_climbers() -> void:
	if _applied_ids.size() >= MAX_CLIMBERS:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		if _applied_ids.size() >= MAX_CLIMBERS:
			return
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var id: int = a.get_instance_id()
		if _applied_ids.has(id):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		var skill: ClimberSkill = ClimberSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_applied_ids[id] = true
		print("[CampaignS11ClearTest] climber #%d → %s pos=%s frame=%d" % [_applied_ids.size(), a.name, a.global_position, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	var saved: int = int(result.get("saved", -1))
	var hp: int = int(result.get("original_hp", -1))
	if saved < hp:
		_fail("cleared but saved=%d < hp=%d" % [saved, hp])
		return
	print("[CampaignS11ClearTest] PASS stage_cleared saved=%d/%d frame=%d" % [saved, hp, _frame])
	_done = true
	get_tree().quit(0)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS11ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
