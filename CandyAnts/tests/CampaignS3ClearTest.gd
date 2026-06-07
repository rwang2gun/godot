extends Node

# Campaign S3 "사탕 호수" — bridge 2개로 이중 갭(호수) 횡단 + water 클리어 검증 (2026-06-07 맵에디터 재저작 반영).
# 지형(cell 48): 좌 지면 cols0-6 · 갭A cols7-10(4칸) · 섬 cols11-13 · 갭B cols14-16(3칸) · 우 지면 cols17-23.
#   home(2,9) candy(21,9). 갭 아래는 water(즉사). 다리는 영구 → 1번 건설하면 전원 왕복.
# 플레이어 모사(즉시 건설 = 낭떠러지에서 cast): 선두 1마리가
#   (1) 갭A 직전 col6(x∈[288,336))에서 bridge cast → 즉시 다리A(cols7-10, 섬 col11 도달) 건설·횡단.
#   (2) 섬을 건너 갭B 직전 col13(x∈[624,672))에서 bridge cast → 즉시 다리B(cols14-16, 우 col17 도달) 건설.
#   같은 선두 개미가 2번 cast(bridge:2 인벤토리). 무장 모델의 "다리A 건설 후 갭B에서 무장 소진" 문제를 회피하려고
#   각 낭떠러지에서 즉시 건설한다(armed가 아닌 cliff cast). total5/hp5 — 다리 개미도 그대로 배달(희생 없음).
# PASS: stage_cleared && saved>=original_hp && lost==0. FAIL: stage_failed / deadline / saved<original / lost>0.

const DEADLINE_FRAMES: int = 20000
const GAP_A_X_MIN: float = 288.0   # col6 (갭A 직전 마지막 좌측 지면) — 즉시 다리A 건설.
const GAP_A_X_MAX: float = 336.0
const GAP_B_X_MIN: float = 624.0   # col13 (갭B 직전 섬 우측 끝) — 즉시 다리B 건설.
const GAP_B_X_MAX: float = 672.0

var _bridge_a_done: bool = false
var _bridge_b_done: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS3ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if not _bridge_a_done:
		_bridge_a_done = _cast_at(GAP_A_X_MIN, GAP_A_X_MAX, "A")
	elif not _bridge_b_done:
		# 다리A 완성 후에만 갭B cast 시도 — 선두 개미가 섬을 건너 col13 낭떠러지에 도달할 때.
		_bridge_b_done = _cast_at(GAP_B_X_MIN, GAP_B_X_MAX, "B")
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — bridgeA=%s bridgeB=%s" % [_bridge_a_done, _bridge_b_done])

# 지정 x-window 안의 우향 보행 개미 중 낭떠러지(cliff_ahead) 도달자에게 bridge cast(즉시 건설). 성공 시 true.
func _cast_at(x_min: float, x_max: float, tag: String) -> bool:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1:
			continue
		if a.global_position.x < x_min or a.global_position.x >= x_max:
			continue
		if not a.cliff_ahead():
			continue
		var bridge: BridgeSkill = BridgeSkill.new()
		if not bridge.can_apply(a):
			continue
		bridge.apply(a)
		print("[CampaignS3ClearTest] bridge %s → %s pos=%s frame=%d" % [tag, a.name, a.global_position, _frame])
		return true
	return false

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS3ClearTest] PASS stage_cleared saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS3ClearTest] FAIL cleared but saved=%d/%d lost=%d (다리/water 회계 이상?) frame=%d" % [
			saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS3ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
