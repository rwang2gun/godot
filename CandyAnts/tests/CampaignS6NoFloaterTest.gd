extends Node

# Campaign S6 음성 — digger만 부여(floater 미부여) → 클리어 불가 (깊은 강하 floater 필수성).
# 핵심(2026-06-06 digger 자유낙하 기절 수정 = Design B 재설계): digger는 흙 캡(천장)을 뚫는 역할일 뿐,
# 캡을 뚫은 개미는 그 아래 **깊은 공동(7칸)을 자유낙하** → FallerState → 기절(DeadState)한다. 굴착 모션 낙하
# 면역이 폐기되어 개척자도 floater 없이는 공동 강하에서 살아남지 못한다(구 "개척자 자력 안전강하" 폐기).
# 따라서 digger로 캡을 열어도 floater 없이는 아무도 챔버에 안착·회수하지 못한다(saved 0).
# floater/distributor는 절대 두지 않는다 → 캡을 뚫은 개미는 전원 공동에서 기절.
# PASS: (stage_failed && saved < candy_hp) 또는 deadline(미클리어). FAIL: stage_cleared.

const DEADLINE_FRAMES: int = 12000
const MESA_Y_MAX: float = 200.0

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _digs: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS6NoFloaterTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	# digger만 — 메사 top에서 우향 보행 개미에 굴착(캡 천장 뚫기). floater는 절대 부여하지 않는다.
	# 캡을 뚫은 개미는 깊은 공동을 자유낙하 → 전원 기절(floater 부재). 전원 굴착해도 saved 0.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.has_been_carrying or a.direction != 1 or a.global_position.y >= MESA_Y_MAX:
			continue
		var digger: DiggerSkill = DiggerSkill.new()
		if digger.can_apply(a):
			digger.apply(a)
			_digs += 1
	if _frame > DEADLINE_FRAMES:
		# 미클리어로 deadline 도달 = 공유 갱도 전략이 floater 없이 클리어 못 함(후속 기절). 필수성 입증.
		print("[CampaignS6NoFloaterTest] PASS (deadline, not cleared) picks=%d digs=%d frame=%d" % [_picks, _digs, _frame])
		_done = true
		get_tree().quit(0)

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without floater (saved=%d picks=%d)" % [int(result.get("saved", -1)), _picks])

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	if saved < orig:
		print("[CampaignS6NoFloaterTest] PASS stage_failed reason=%s saved=%d/%d picks=%d digs=%d (deep drop needs floater) frame=%d" % [
			str(result.get("reason", "?")), saved, orig, _picks, _digs, _frame])
		get_tree().quit(0)
	else:
		_fail("stage_failed but saved=%d/%d (expected < orig)" % [saved, orig])

func _fail(msg: String) -> void:
	print("[CampaignS6NoFloaterTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
