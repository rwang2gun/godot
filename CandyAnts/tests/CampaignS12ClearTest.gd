extends Node

# Campaign scene_id 12 "낭떠러지 끝" (Ch1 slot3) — blocker 도입(NEW) 클리어 가능성 검증.
# 지면 cols0-17, 우측 끝은 water 절벽(cols18+ 바다). spawn(col9)은 home(col2)·candy(col5)의
# *오른쪽*(spawn≠home) → 우향 행진은 무보정 시 candy를 등진 채 전원 절벽 익사.
# 플레이어 모사: 최전방 walker가 절벽 직전 col14.5(x>=696) 도달 시 BlockerSkill 1개 적용(인벤토리 전량)
#   → 후속 무리 반전 → 좌향 candy(col5) 픽업(픽업 시 자동 반전=우향) → blocker에 다시 튕겨 좌향
#   → home(col2) 귀가. blocker가 진입(반전)과 귀환(재반전) 양쪽에서 필수.
#   공통 계약 §왕복 동선: Home·Candy 둘 다 blocker 왼쪽 + Home이 좌측 끝 → 빈손 좌향 개미는
#   candy를 먼저 만나고(Home.gd의 좌향 빈손 흡수보다 앞) 운반자는 home에서 종착.
# PASS: stage_cleared && saved>=original_hp (blocker 반전 경로가 실제 동작함을 입증).
# FAIL: stage_failed / deadline.

const DEADLINE_FRAMES: int = 16000
const BLOCKER_X: float = 696.0

var _blocker_id: int = 0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS12ClearTest] driver ready blocker_x=", BLOCKER_X)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_apply_blocker()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — blocker_placed=%s" % str(_blocker_id != 0))

func _apply_blocker() -> void:
	if _blocker_id != 0:
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
	if front == null or front.global_position.x < BLOCKER_X:
		return
	var skill: BlockerSkill = BlockerSkill.new()
	if not skill.can_apply(front):
		return
	skill.apply(front)
	_blocker_id = front.get_instance_id()
	print("[CampaignS12ClearTest] blocker → %s pos=%s frame=%d" % [front.name, front.global_position, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	var saved: int = int(result.get("saved", -1))
	var hp: int = int(result.get("original_hp", -1))
	if saved < hp:
		_fail("cleared but saved=%d < hp=%d" % [saved, hp])
		return
	print("[CampaignS12ClearTest] PASS stage_cleared saved=%d/%d frame=%d" % [saved, hp, _frame])
	_done = true
	get_tree().quit(0)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS12ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
