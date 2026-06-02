extends Node

# Campaign S1 "첫 마실" — climber 1칸 분지 클리어 가능성 검증 (레벨 재설계 rev2, 2026-06-02).
# 플레이어를 모사해 최대 MAX_CLIMBERS(=인벤토리 6)마리에 climber를 부여 → 분지(1칸)를 건너
# 사탕 5개를 모두 회수해 귀가해야 stage_cleared(candy_hp==0 AND in_transit==0).
# 6 부여 중 5 왕복이면 클리어(여유 1마리).
#   - 무스킬이었다면 분지 1칸 벽(48px > 개미 15px 본체)에 is_on_wall로 막혀 영영 못 건넘
#     → hp가 0에 닿지 못함 → 클리어 불가. 즉 PASS는 climber 등반 경로가 실제로 동작함을 입증한다.
# PASS: EventBus.stage_cleared. FAIL: stage_failed(time_out/no_more_ants) 또는 deadline.

const DEADLINE_FRAMES: int = 16000
const MAX_CLIMBERS: int = 6

var _applied_ids: Dictionary = {}   # instance_id → true (중복 부여 방지)
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS1ClearTest] driver ready max_climbers=", MAX_CLIMBERS)

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
		if a == null or not is_instance_valid(a):
			continue
		var id: int = a.get_instance_id()
		if _applied_ids.has(id):
			continue
		if a.state_machine == null or not (a.state_machine.current_state is WalkerState):
			continue
		var skill: ClimberSkill = ClimberSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_applied_ids[id] = true
		print("[CampaignS1ClearTest] climber #%d → %s pos=%s frame=%d" % [_applied_ids.size(), a.name, a.global_position, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	print("[CampaignS1ClearTest] PASS stage_cleared saved=%d/%d frame=%d" % [
		int(result.get("saved", -1)), int(result.get("original_hp", -1)), _frame])
	_done = true
	get_tree().quit(0)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS1ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
