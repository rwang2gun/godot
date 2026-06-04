extends Node

# 막대과자 사다리(LadderClimbState) 등반 모션 검증 (2026-06-04).
# 모래(sand_mound) 스킬로 깐 rung 기둥을 후속 개미가 LadderClimbState로 오를 때, 스프라이트가
# 등반 모션("climb")을 재생해야 한다(구: 매핑 누락 → 기본값 "idle"로 떨어짐). ClimberState와 동일 정책.
#
# 셋업은 LadderFollowerClimbTest와 동일(SandMoundTest.tscn 재사용) — 시전 개미 1마리에 sand_mound
# 부여 후 rung 기둥 건설, 후속 walker가 자동 등반.
# 판정: LadderClimbState인 개미를 폴링해 _sprite.animation 관측.
#   - "climb" 관측 → PASS (등반 모션 정상).
#   - "idle" 관측 → FAIL (매핑 누락 회귀 — 등반인데 idle 모션).
#   - 그 외(walk/전이 프레임)는 계속 폴링(다음 frame이면 climb로 안정화).

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 420.0   # cell 13 — LadderFollowerClimbTest와 동일 시전 위치.

var _terrain: Terrain = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[LadderClimbMotionTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_climb_motion()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — LadderClimbState climb 모션 미관측 applied=%s" % _applied)

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
		print("[LadderClimbMotionTest] applied sand_mound to caster id=%d frame=%d" % [a.get_instance_id(), _frame])
		return

func _check_climb_motion() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is LadderClimbState):
			continue
		var sprite: AnimatedSprite2D = a.get_node_or_null("Sprite") as AnimatedSprite2D
		if sprite == null:
			continue
		var anim: String = sprite.animation
		if anim == "climb":
			print("[LadderClimbMotionTest] PASS — LadderClimbState ant plays 'climb' frame=%d id=%d" % [_frame, a.get_instance_id()])
			_result_emitted = true
			get_tree().quit(0)
			return
		elif anim == "idle":
			_fail("LadderClimbState 개미가 'idle' 모션 재생 — 등반 모션 매핑 누락 회귀 (id=%d frame=%d)" % [a.get_instance_id(), _frame])
			return

func _fail(msg: String) -> void:
	if _result_emitted:
		return
	print("[LadderClimbMotionTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
