extends Node

# Campaign S5 "막대과자 탑" — sand_mound 수직 사다리로 고립 오버행 플랫폼(candy) 등반 → floater 안전 하강 클리어.
# 플레이어 모사:
#   (1) 첫 ant가 플랫폼 아래(cols14~17, x∈[672,864))서 SandMoundSkill 적용 → rung 기둥 건설 + 레지 cap →
#       플랫폼(row5) 위로 올라섬. 사다리는 영구라 후속 ant는 LadderClimbState로 자동 등반(시전 1회로 충분).
#   (2) 모든 ant에 FloaterSkill 부여 → candy 회수 후 플랫폼 가장자리(6칸 낙하)를 기절 없이 안전 하강.
# candy_hp 4 → 4마리가 플랫폼 candy를 회수해 귀가하면 클리어. PASS: stage_cleared && saved>=4 && lost==0.
# FAIL: stage_failed / deadline / saved<4 / lost>0.
#
# 진단: deadline 시 candy_piece_picked 수 + sand_mound ant 위치/state 출력 — 후속 등반(LadderClimbState)이
#   막히면 picks<4로 식별.

const DEADLINE_FRAMES: int = 18000
const CAST_X_MIN: float = 672.0   # col14 — 플랫폼(cols13~19) 아래 시작.
const CAST_X_MAX: float = 864.0   # col18 전까지(시전 기둥이 플랫폼 폭 안).

var _cast_applied: bool = false
var _cast_ant: Ant = null
var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS5ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_grant_floater_to_all()
	if not _cast_applied:
		_apply_sand_mound()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — cast_applied=%s picks=%d %s" % [_cast_applied, _picks, _cast_ant_diag()])

# 플레이어가 무리 전체에 낙하산을 나눠주는 것을 모사 — floater 미보유 ant에 즉시 부여.
# floater는 trait이라 등반(LadderClimbState)/시전(WorkerState)에 무해, 하강 시 FallerState에서만 작동.
func _grant_floater_to_all() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.has_trait(&"floater"):
			continue
		var floater: FloaterSkill = FloaterSkill.new()
		if floater.can_apply(a):
			floater.apply(a)

func _apply_sand_mound() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_been_carrying:
			continue
		if a.global_position.x < CAST_X_MIN or a.global_position.x >= CAST_X_MAX:
			continue
		var skill: SandMoundSkill = SandMoundSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_cast_applied = true
		_cast_ant = a
		print("[CampaignS5ClearTest] sand_mound → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

func _cast_ant_diag() -> String:
	if _cast_ant == null or not is_instance_valid(_cast_ant):
		return "cast_ant=<freed>"
	var st: String = "?"
	if _cast_ant.state_machine != null and _cast_ant.state_machine.current_state != null:
		var s: Object = _cast_ant.state_machine.current_state
		st = str(s.get_script().resource_path.get_file()) if s.get_script() != null else st
	return "cast_ant pos=%s state=%s has_candy=%s" % [_cast_ant.global_position, st, _cast_ant.has_candy]

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS5ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS5ClearTest] PASS stage_cleared saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS5ClearTest] FAIL cleared but saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d %s frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _cast_ant_diag(), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS5ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
