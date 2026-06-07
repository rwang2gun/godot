extends Node

# Campaign S6 "땅굴" — digger로 row9 흙 선반(shelf)을 뚫어 공동(cavern)으로 강하 → 쿠키 챔버 candy 회수 → 귀가.
# (2026-06-07 재작성: 구 floater-distributor 설계 폐기. 현 stage06 = digger:1 + climber:5, total5/hp5.)
#
# 지형(cell 48, +Y 아래): 좌 흙 기둥 cols1-4 rows5-12(Home top=row5 surface) · row9 흙 선반 cols1-22(1칸 두께,
#   cols14-18 아래는 공동 air rows10-12) · candy(18,12) 쿠키 챔버 바닥(row13) 위.
# 모든 낙하는 4칸(< 5칸 기절 임계)이라 floater 불필요.
#
# 플레이어 모사:
#   (1) 모든 grounded walker/carrier에 climber 부여(귀환 시 공동→기둥 top 등반 필요, climber:5 = 1마리당 1개).
#   (2) 선두 1마리가 공동 위 선반(col16 부근, x∈[768,816))에 도달하면 digger 시전 → row9 구멍 → 4칸 강하(안전).
#       구멍은 영구 → 후속 개미도 같은 구멍으로 4칸 강하 → candy 회수 후 climber로 귀환.
# PASS: stage_cleared && saved>=original_hp && lost==0. FAIL: stage_failed / deadline / saved<original / lost>0.

const DEADLINE_FRAMES: int = 24000
const DIG_X_MIN: float = 672.0    # col14 — 공동(cols14-18) 서쪽 끝, col13 벽 인접.
const DIG_X_MAX: float = 720.0    # 벽 인접 칼럼에 구멍을 뚫어야 귀환 시 col13 벽 등반 천장(shelf row9)이 구멍으로 뚫림.

var _climbed: Dictionary = {}     # instance_id → true (climber 1회 부여 추적, 인벤토리 소모)
var _dig_done: bool = false
var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _digs: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS6ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_grant_climbers()
	if not _dig_done:
		_dig_done = _cast_digger()
	if _frame % 150 == 0:
		_dump_state()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — dig=%s picks=%d digs=%d" % [_dig_done, _picks, _digs])

# 모든 grounded WalkerState/CarryingState 개미에 climber 1회 부여(인벤토리 5 = 개미 5마리분).
func _grant_climbers() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var id: int = a.get_instance_id()
		if _climbed.has(id):
			continue
		if a.has_trait(&"climber"):
			_climbed[id] = true
			continue
		var c: ClimberSkill = ClimberSkill.new()
		if c.can_apply(a):
			c.apply(a)
			_climbed[id] = true

# 공동 위 선반(DIG_X window) 위 grounded walker(미운반)에 digger 시전. 성공 시 true(1회).
func _cast_digger() -> bool:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if a.has_been_carrying or a.has_candy:
			continue
		if a.global_position.x < DIG_X_MIN or a.global_position.x >= DIG_X_MAX:
			continue
		var digger: DiggerSkill = DiggerSkill.new()
		if not digger.can_apply(a):
			continue
		digger.apply(a)
		_digs += 1
		print("[CampaignS6ClearTest] digger → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return true
	return false

func _dump_state() -> void:
	var lines: Array[String] = []
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var st: String = "?"
		var s: Object = a.state_machine.current_state
		if s != null and s.get_script() != null:
			st = str(s.get_script().resource_path.get_file())
		lines.append("%s pos=(%.0f,%.0f) dir=%d st=%s carry=%s wasCarry=%s climb=%s" % [
			a.name, a.global_position.x, a.global_position.y, a.direction, st,
			a.has_candy, a.has_been_carrying, a.has_trait(&"climber")])
	print("[CampaignS6ClearTest] f=%d picks=%d digs=%d\n  %s" % [_frame, _picks, _digs, "\n  ".join(lines)])

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
