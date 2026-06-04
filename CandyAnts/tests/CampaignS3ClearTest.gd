extends Node

# Campaign S3 "사탕 호수" — bridge 체인 횡단 + water 클리어 검증 (레벨 재설계 rev2, 2026-06-04 다리 캡 5칸 체인 개정).
# 플레이어 모사: 호수(갭 8칸 cols9~16) > 다리 캡 5칸이라 다리 1개로는 못 건넌다. 호수 직전 마지막 지면 cell
#   (col8, x∈[384,432))에서 개미 2마리를 BridgeSkill 무장 → 첫 개미가 즉시 다리1(cols9~13) 건설(자기 다리 끝에서
#   표류) → 둘째 개미가 다리1을 건너 col13 끝(낭떠러지)에서 다리2(cols14~16, 반대편 col17 도달)를 이어 건설(체인).
#   다리는 영구 → 완성 후 후속 ant들이 candy 회수 왕복. (인벤토리 bridge:5라 2개 충분.)
# 수면 하강(2026-06-04): 물 표면이 지면(row10)보다 두 칸 낮은 row12라 다리(row10)는 물 위 두 칸 위를 가로지른다.
# candy_hp 4 + total 6 → 다리 개미 1~2마리가 빈손 표류해도 나머지로 4개 회수 가능. PASS: stage_cleared &&
#   saved==original_hp && lost==0. (다리 없이는 전원 즉사 = 짝 테스트 CampaignS3NoBridgeTest로 필수성 입증.)
# FAIL: stage_failed / deadline / saved<original / lost>0.

const DEADLINE_FRAMES: int = 20000
const BRIDGE_X_MIN: float = 384.0   # col8 시작 (마지막 좌측 지면 cell) — target=(col9,row10) gap 첫 셀.
const BRIDGE_X_MAX: float = 432.0   # col9 시작 (호수) 전까지.
const ARM_COUNT: int = 2            # 체인 — 첫 개미 즉시건설 + 둘째 개미 다리 끝 이어건설.

var _armed_ids: Dictionary = {}
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
	_apply_bridge()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — armed=%d" % _armed_ids.size())

func _apply_bridge() -> void:
	# col8에서 2마리 무장. 첫 개미는 낭떠러지(col9 빈칸)라 즉시 다리1 건설. 둘째 개미가 도달할 즈음엔 col9에
	# 다리 타일이 있어 cliff_ahead=false → 무장(bridge_armed)만 → 다리1을 건너 끝(col13)에서 다리2 자동 체인.
	if _armed_ids.size() >= ARM_COUNT:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if _armed_ids.has(a.get_instance_id()):
			continue
		if a.direction != 1 or a.has_been_carrying:
			continue
		if a.global_position.x < BRIDGE_X_MIN or a.global_position.x >= BRIDGE_X_MAX:
			continue
		var bridge: BridgeSkill = BridgeSkill.new()
		if not bridge.can_apply(a):
			continue
		bridge.apply(a)
		_armed_ids[a.get_instance_id()] = true
		print("[CampaignS3ClearTest] bridge → %s pos=%s frame=%d (total=%d)" % [
			a.name, a.global_position, _frame, _armed_ids.size()])
		if _armed_ids.size() >= ARM_COUNT:
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
