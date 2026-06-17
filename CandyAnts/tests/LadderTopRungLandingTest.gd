extends Node

# 사다리 꼭대기 무낙하 회귀 (prove-it, 2026-06-17).
# 후속 개미가 LadderClimbState로 막대과자 사다리를 오른 뒤 레지/꼭대기에 **보행 안착**해야 한다.
# 버그: LadderClimbState._land_at이 개미를 셀 **정중앙**(row*cs + cs/2)에 스냅했다. 정상 보행 안착 중심
#   y는 (발밑셀 top - 개미 half-height)이라, 셀 중앙은 그보다 (cs/2 - half_h)=48px셀 기준 16.5px 위로
#   떠 있다 → 보행 복귀 직후 is_on_floor()=false → FallerState로 "맨 윗 칸에서 툭" 떨어진다.
#   기존 LadderFollowerClimbTest는 **최종** 안착(is_on_floor + y)만 봐서, 짧게 떨어졌다 재안착하는 이
#   글리치를 통과시켰다(못 잡음). 이 테스트가 그 빈틈을 메운다.
#
# 셋업은 LadderFollowerClimbTest와 동일(SandMoundTest.tscn 재사용) — 시전 개미 1마리에 sand_mound
# 부여 후 rung 기둥 건설, 후속 walker가 자동 등반.
# 판정: LadderClimbState를 막 떠난 개미가
#   - 그 직후(<= DROP_GRACE frame) FallerState로 전이 → FAIL (꼭대기 낙하 = 안착 실패).
#   - FallerState 없이 STABLE_FRAMES 동안 보행 유지 → PASS (즉시 보행 안착).

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 420.0   # cell 13 — LadderFollowerClimbTest와 동일 시전 위치.
const DROP_GRACE: int = 12       # 착지 후 이 프레임 내 FallerState = 안착 실패(부양 후 낙하).
const STABLE_FRAMES: int = 30    # 이만큼 무낙하 보행 = 안착 성공.

var _terrain: Terrain = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _was_climbing: Dictionary = {}   # id → true (직전까지 LadderClimbState 관측)
var _post_climb: Dictionary = {}     # id → 등반 종료 후 경과 frame

func _ready() -> void:
	print("[LadderTopRungLandingTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_track_landings()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — 등반 후 안착 관측 못함 applied=%s" % _applied)

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../SandMoundStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _apply_when_ready() -> void:
	if _applied or _terrain == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if a.global_position.x < TRIGGER_X or not a.is_on_floor():
			continue
		var skill: SandMoundSkill = SandMoundSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_applied = true
		print("[LadderTopRungLandingTest] applied sand_mound caster id=%d frame=%d" % [a.get_instance_id(), _frame])
		return

func _track_landings() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var id: int = a.get_instance_id()
		var st: AntState = a.state_machine.current_state
		if st is LadderClimbState:
			# 등반 중(또는 재등반) — 종료 후 추적을 위해 플래그만 세우고 카운터는 리셋.
			_was_climbing[id] = true
			_post_climb.erase(id)
			continue
		if not _was_climbing.get(id, false):
			continue   # 사다리를 탄 적 없는 개미(바닥 보행)는 무시.
		# LadderClimbState를 막 떠난 개미 — 안착/낙하 판정.
		if not _post_climb.has(id):
			_post_climb[id] = 0
		_post_climb[id] = int(_post_climb[id]) + 1
		var elapsed: int = int(_post_climb[id])
		if st is FallerState and elapsed <= DROP_GRACE:
			_fail("top-rung drop — 개미 %d 가 사다리 등반 %d frame 후 FallerState 진입(y=%.1f). 꼭대기에서 안착 못하고 낙하." % [id, elapsed, a.global_position.y])
			return
		if st is WalkerState and elapsed >= STABLE_FRAMES:
			print("[LadderTopRungLandingTest] PASS — 개미 %d 가 낙하 없이 %d frame 보행 안착(y=%.1f frame=%d)" % [id, elapsed, a.global_position.y, _frame])
			_result_emitted = true
			get_tree().quit(0)
			return

func _fail(msg: String) -> void:
	if _result_emitted:
		return
	print("[LadderTopRungLandingTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
