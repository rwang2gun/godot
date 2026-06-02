extends Node

# Campaign S3 — "무장 다리(armed bridge)" 지연 건설 검증 (2026-06-02 다리 규칙 개편).
# 다리 스킬을 갭에서 멀리 떨어진 평지(좌측 cols3~5)에서 부여하면 *즉시 건설하지 않고* 무장(bridge_armed)만
# 한 채 개미가 보행 → 낭떠러지(col8)에 도달하면 그 자리(지표면 높이 row10)에서 자동 건설 → 호수 횡단.
# PASS: (A) 부여 직후 WalkerState 유지 + bridge_armed==true + tile_count==0 (즉시 건설 안 함 = 지연 입증)
#       (B) 무장 보행 중 꼬리 BridgeBadge.visible==true (다른 스킬 아이콘처럼 부착 — 시각 표식 입증)
#       (C) 이후 stage_cleared && saved==original_hp && lost==0 (낭떠러지 자동 건설로 클리어)
# FAIL: 부여 직후 WorkerState/tile>0(즉시 건설=지연 실패) / 배지 미표시 / stage_failed / deadline / saved<orig / lost>0.
# (즉시-건설 경로는 짝 테스트 CampaignS3ClearTest가 col8 시전으로 커버 — 둘이 하이브리드 양 분기를 입증.)

const DEADLINE_FRAMES: int = 16000
const APPLY_X_MIN: float = 150.0   # 갭(col9 시작 x=432)에서 충분히 좌측 — cols3~5 평지(낭떠러지 아님).
const APPLY_X_MAX: float = 280.0

var _ant: Ant = null
var _applied: bool = false
var _defer_verified: bool = false
var _badge_verified: bool = false
var _frame: int = 0
var _done: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS3ArmedBridgeTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_terrain()
	if not _applied:
		_apply_armed()
	elif not _badge_verified:
		_verify_badge()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%s defer_verified=%s badge_verified=%s" % [
			_applied, _defer_verified, _badge_verified])

func _ensure_terrain() -> void:
	if _terrain != null:
		return
	var stage: Node = get_node_or_null("../CampaignStage")
	if stage != null:
		_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _apply_armed() -> void:
	if _terrain == null:
		return   # terrain 미해결 — tile_count 단언 신뢰 위해 해결될 때까지 대기.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_been_carrying:
			continue
		if a.global_position.x < APPLY_X_MIN or a.global_position.x >= APPLY_X_MAX:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		var bridge: BridgeSkill = BridgeSkill.new()
		if not bridge.can_apply(a):
			continue
		bridge.apply(a)
		_ant = a
		_applied = true
		# (A) 지연 입증 — 평지 시전이므로 즉시 건설(WorkerState/tile)하지 않고 무장만 해야 한다.
		var tc: int = _terrain.tile_count()
		var building: bool = a.state_machine.current_state is WorkerState
		if building or tc > 0 or not a.bridge_armed:
			_fail("immediate build on flat ground — building=%s tile_count=%d armed=%s (지연 실패)" % [
				building, tc, a.bridge_armed])
			return
		_defer_verified = true
		print("[CampaignS3ArmedBridgeTest] armed (deferred) at x=%.1f armed=%s tile=%d frame=%d" % [
			a.global_position.x, a.bridge_armed, tc, _frame])
		return

# (B) 무장 보행 중 BridgeBadge가 표시되는지 — 다른 스킬 아이콘과 동일하게 부착됐는지 입증.
# _update_trait_badges()는 ant._physics_process 끝(state update 이후)에 갱신되므로 부여 다음 frame부터 visible.
# 검증 창 = 무장(bridge_armed) 동안(부여~낭떠러지 도달, S3는 col3→col8 ~160 frame). 그 안에 한 번만 확인.
func _verify_badge() -> void:
	if _ant == null or not is_instance_valid(_ant):
		return
	if not _ant.bridge_armed:
		return   # 이미 낭떠러지 도달해 건설 진입 — 다음 frame에 다시 시도(무장 동안 창이 넓어 정상은 도달 전 통과).
	var badge: Sprite2D = _ant.get_node_or_null("TailBadges/BridgeBadge") as Sprite2D
	if badge == null:
		_fail("TailBadges/BridgeBadge 노드 없음 — Ant.tscn 갱신 필요")
		return
	if badge.visible:
		_badge_verified = true
		print("[CampaignS3ArmedBridgeTest] BridgeBadge visible while armed ✓ frame=%d" % _frame)

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if _defer_verified and _badge_verified and orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS3ArmedBridgeTest] PASS deferred-then-autobuild saved=%d/%d lost=%d frame=%d" % [
			saved, orig, lost, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS3ArmedBridgeTest] FAIL cleared but defer_verified=%s badge_verified=%s saved=%d/%d lost=%d frame=%d" % [
			_defer_verified, _badge_verified, saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS3ArmedBridgeTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
