extends Node

# Campaign S3 "사탕 호수" — bridge 평지 횡단 + water 클리어 가능성 검증 (레벨 재설계 rev2, 2026-06-02 세션 3).
# 플레이어 모사: 첫 ant가 호수 직전 마지막 지면 cell(col8, x∈[384,432))에 도달하면 BridgeSkill 적용 →
#   8칸 다리(cols9~16, row10)를 깔아 호수를 건넘.
# 수면 하강(2026-06-04): 물 표면이 지면(row10)보다 두 칸 낮은 row12(심부 row13~14)에 있어 다리(row10)는
#   물 위 두 칸 위를 가로지른다 → 다리 위를 걷는 개미는 물(row12+)에 닿지 않아 표류(AdriftState) 안 됨.
#   (구 메커니즘이던 per-tile deactivate는 row10에 물이 없어 no-op — 간격이 안전을 보장.) 다리는 영구 → 후속 ant 왕복.
# candy_hp 4 → 4 왕복이면 클리어. PASS: stage_cleared && saved==original_hp && lost==0.
#   - 다리 없이는 호수에서 전원 즉사(짝 테스트 CampaignS3NoBridgeTest) → bridge 필수성 입증.
# FAIL: stage_failed / deadline / saved<original / lost>0(개미가 다리 아래 물에 닿음 = 지오메트리 이상).

const DEADLINE_FRAMES: int = 16000
const BRIDGE_X_MIN: float = 384.0   # col8 시작 (마지막 좌측 지면 cell) — target=(col9,row10) gap 첫 셀.
const BRIDGE_X_MAX: float = 432.0   # col9 시작 (호수) 전까지.

var _bridge_applied: bool = false
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
	if not _bridge_applied:
		_apply_bridge()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — bridge_applied=%s" % _bridge_applied)

func _apply_bridge() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_been_carrying:
			continue
		if a.global_position.x < BRIDGE_X_MIN or a.global_position.x >= BRIDGE_X_MAX:
			continue
		var bridge: BridgeSkill = BridgeSkill.new()
		if not bridge.can_apply(a):
			continue
		bridge.apply(a)
		_bridge_applied = true
		print("[CampaignS3ClearTest] bridge → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

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
