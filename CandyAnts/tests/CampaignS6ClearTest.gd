extends Node

# Campaign S6 "땅굴" — digger로 흙 지붕(캡)을 뚫고 → 깊은 공동을 floater로 안전 강하 → 불괴 쿠키 챔버의
# candy 회수 → 귀가 클리어.
# 플레이어 모사:
#   (1) 무리 전체에 FloaterSkill 부여 — 깊은 공동(7칸) 낙하를 기절 없이 안전 강하. trait이라 보행/굴착에 무해.
#   (2) 메사 top(y<200)에서 보행 중인 개미에 DiggerSkill 적용 → 흙 캡(rows2-5) 수직 굴착 → 공동에서 abort →
#       floater 강하 → 챔버 바닥(row13, cookie). 캡 구멍은 영구라 후속 개미는 그 구멍으로 안전 낙하(또는 개별 굴착).
# candy_hp 4 → 4마리가 챔버 candy를 회수해 귀가하면 클리어. PASS: stage_cleared && saved>=4 && lost==0.
# FAIL: stage_failed / deadline / saved<4 / lost>0.
#
# 진단: deadline 시 picks 수 + dig 적용 횟수 출력.

const DEADLINE_FRAMES: int = 18000
const MESA_Y_MAX: float = 200.0   # 메사 top 영역(흙 캡 표면 y≈96). 챔버 개미(y≈600)는 제외.

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _digs: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS6ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_drive_skills()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d digs=%d" % [_picks, _digs])

func _drive_skills() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		# (1) 낙하산 분배 — 미보유 개미에 즉시 부여.
		if not a.has_trait(&"floater"):
			var floater: FloaterSkill = FloaterSkill.new()
			if floater.can_apply(a):
				floater.apply(a)
		# (2) 메사 top에서 우향 보행 중(미운반)인 개미에 digger — 흙 캡 수직 굴착.
		if a.has_been_carrying or a.direction != 1:
			continue
		if a.global_position.y >= MESA_Y_MAX:
			continue
		var digger: DiggerSkill = DiggerSkill.new()
		if digger.can_apply(a):
			digger.apply(a)
			_digs += 1
			print("[CampaignS6ClearTest] digger → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS6ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS6ClearTest] PASS stage_cleared saved=%d/%d lost=%d digs=%d frame=%d" % [saved, orig, lost, _digs, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS6ClearTest] FAIL cleared but saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d digs=%d frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _digs, _frame])

func _fail(msg: String) -> void:
	print("[CampaignS6ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
