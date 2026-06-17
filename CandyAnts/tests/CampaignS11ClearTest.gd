extends Node

# Campaign scene_id 11 "물놀이 금지" — blocker×1 클리어 검증 (2026-06-18 재작성).
# (이전 드라이버는 옛 레벨 "담을 넘어"의 climber×5 가정 → 현재 "물놀이 금지"와 불일치로 실패했음.)
#
# 지형: 상단 표면(row9, col3-16) + col10 사다리(sand_mound) + 하단 표면(row12, col3-21) + 양끝 물.
#   home=상단 col6, candy=하단 col16(hp4), spawn=상단 col6, inventory={blocker:1}.
# 자연 동선(스킬 0, 관찰 드라이버 실증): 상단 우향 → col16 끝에서 하단(col18)으로 낙하
#   → candy(col16, 착지 왼쪽)를 지나쳐 하단 우향 → col22 물에 전멸(candy 미픽업, saved=0).
# 솔루션: 하단 물 직전(col20)에 blocker 1개 → 후속 개미 반전(좌향) → candy(col16) 픽업
#   → 운반 상태로 좌향 → col10 사다리 통행 → 상단 → home(col6) 귀환.
# PASS: stage_cleared && saved>=hp. FAIL: stage_failed / deadline.

const DEADLINE_FRAMES: int = 16000
const BLOCKER_X: float = 960.0   # col20 부근(하단 물 col22 직전)
const LOWER_Y: float = 520.0     # 하단 표면(y≈568) 식별 임계 — 상단(y≈424)과 분리

var _blocker_id: int = 0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS11ClearTest] driver ready blocker_x=", BLOCKER_X)

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
	# 하단(LOWER_Y 아래)에 내려온 최전방(가장 오른쪽) walker가 물 직전 도달 시 blocker.
	var front: Ant = null
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if a.global_position.y < LOWER_Y:
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
	print("[CampaignS11ClearTest] blocker → %s pos=%s frame=%d" % [front.name, front.global_position, _frame])

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
