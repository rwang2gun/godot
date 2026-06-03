extends Node

# Campaign S6 음성 — floater 미부여(digger만, "개척자 1 + 무리 공유" 전략) → 클리어 불가 (공유 갱도 floater 필수성).
# 핵심: digger 개미는 **굴착(WorkerState) 상태로 낙하**하므로 깊이 무관 안전 → 개척자 1마리는 floater 없이 자력
# 하강·귀가(saved 1). 그러나 그 개척자가 판 수직 갱도로 **떨어지는 후속 개미는 FallerState 자유낙하 → 7칸 → 기절**
# → 회수 실패. 따라서 무리가 개척자 갱도를 공유하는 전략은 floater 없이는 candy_hp(4)를 못 채운다.
# (cf. 각 개미가 *개별* 굴착하면 floater 없이도 안전 — 그건 별도 해법이고 본 테스트 범위 밖. inventory가 지원.)
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
	# digger만 — 메사 top에서 우향 보행 개미에 굴착. floater는 절대 부여하지 않는다.
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
		print("[CampaignS6NoFloaterTest] PASS stage_failed reason=%s saved=%d/%d picks=%d digs=%d (shared-shaft needs floater) frame=%d" % [
			str(result.get("reason", "?")), saved, orig, _picks, _digs, _frame])
		get_tree().quit(0)
	else:
		_fail("stage_failed but saved=%d/%d (expected < orig)" % [saved, orig])

func _fail(msg: String) -> void:
	print("[CampaignS6NoFloaterTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
