extends Node

# Campaign scene_id 12 "사다리 오르기" — blocker 클리어 검증 (2026-06-18 재작성).
# (이전 드라이버는 옛 레벨 가정 blocker@x696 1개 → 현재 구조와 불일치로 미발동·실패.)
#
# 구조(spawn_direction=-1, 좌향): 4층 수직.
#   하단 row13(col0-18, spawn/home col6) →[col12 사다리 row11-12]→ 중간2 row10(col4-18)
#   →[col8 사다리 row8-9]→ 중간1 row7(col5-18) →[col13 사다리 row5-6]→ 상단 row4(col6-18, candy col16).
#   양옆 물(col<0, col>18).
# 자연 동선(스킬0): 하단서 좌향 → col<0 물에 전멸(관찰 실증).
# 솔루션: 하단 spawn 왼쪽(col5)에 blocker로 좌향 차단 → 우향 → col12 사다리부터 3단 등반
#   → candy(상단 col16) 픽업 → 역경로 귀환. inventory blocker:3.
# 우선 좌향 차단 blocker 1개로 시도(부족 시 상단 층 유도 blocker 추가).
# PASS: stage_cleared && saved>=hp. FAIL: stage_failed / deadline.

const DEADLINE_FRAMES: int = 16000
const LEFT_BLOCK_X: float = 264.0   # col5 — 하단 spawn(col6) 좌향 차단점

var _left_blocker_id: int = 0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS12ClearTest] driver ready left_block_x=", LEFT_BLOCK_X)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_apply_left_blocker()
	if _frame % 120 == 0:
		_trace()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — left_blocker=%s" % str(_left_blocker_id != 0))

func _apply_left_blocker() -> void:
	if _left_blocker_id != 0:
		return
	# 하단(y>560)에서 좌향 선두(가장 왼쪽) walker가 차단점 도달 시 blocker.
	var lead: Ant = null
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if a.global_position.y < 560.0:
			continue
		if lead == null or a.global_position.x < lead.global_position.x:
			lead = a
	if lead == null or lead.global_position.x > LEFT_BLOCK_X:
		return
	var skill: BlockerSkill = BlockerSkill.new()
	if not skill.can_apply(lead):
		return
	skill.apply(lead)
	_left_blocker_id = lead.get_instance_id()
	print("[CampaignS12ClearTest] left blocker → %s pos=%s frame=%d" % [lead.name, lead.global_position, _frame])

func _trace() -> void:
	var parts: Array[String] = []
	for n in get_tree().get_nodes_in_group("ants"):
		var a := n as Node2D
		if a == null or not is_instance_valid(a):
			continue
		parts.append("(%d,%d)" % [int(a.global_position.x), int(a.global_position.y)])
	print("[CampaignS12ClearTest] trace f=%d n=%d %s" % [_frame, parts.size(), " ".join(parts)])

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
