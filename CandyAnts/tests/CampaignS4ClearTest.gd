extends Node

# Campaign S4 "계단 공사" — builder 대각 계단으로 높은 단(우측) 등반 → candy 회수 클리어 검증.
# 플레이어 모사: 첫 ant가 갭 직전 마지막 지면 cell(col8, x∈[384,432))에 도달하면 BuilderSkill 적용 →
#   up-first 대각 계단(8,9)(9,8)(10,7)(11,6) — 첫 타일은 절벽 끝 위(col8)에 수직, 이후 대각 — 을 쌓아
#   단(col12, 표면 row6)에 flush하게 올라선다. 계단은 영구라 후속 ant도 등반.
# candy_hp 4 → 4마리가 단 위 candy를 회수해 귀가하면 클리어. PASS: stage_cleared && saved>=4 && lost==0.
# FAIL: stage_failed / deadline / saved<4.
#
# 진단: deadline 시 candy_piece_picked 수 + builder ant의 최종 위치/state를 출력 —
#   계단 등반/단 진입이 walker step-up 부재로 막히는지(picks=0) 정밀 식별.

const DEADLINE_FRAMES: int = 18000
const BUILDER_X_MIN: float = 384.0   # col8 시작 (마지막 좌측 지면 cell). up-first 첫 계단=(8,9) 절벽 위.
const BUILDER_X_MAX: float = 432.0   # col9(갭) 전까지.

var _builder_applied: bool = false
var _builder_ant: Ant = null
var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS4ClearTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if not _builder_applied:
		_apply_builder()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — builder_applied=%s picks=%d %s" % [
			_builder_applied, _picks, _builder_ant_diag()])

func _apply_builder() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_been_carrying:
			continue
		if a.global_position.x < BUILDER_X_MIN or a.global_position.x >= BUILDER_X_MAX:
			continue
		var builder: BuilderSkill = BuilderSkill.new()
		if not builder.can_apply(a):
			continue
		builder.apply(a)
		_builder_applied = true
		_builder_ant = a
		print("[CampaignS4ClearTest] builder → %s pos=%s frame=%d" % [a.name, a.global_position, _frame])
		return

func _builder_ant_diag() -> String:
	if _builder_ant == null or not is_instance_valid(_builder_ant):
		return "builder_ant=<freed>"
	var st: String = "?"
	if _builder_ant.state_machine != null and _builder_ant.state_machine.current_state != null:
		st = _builder_ant.state_machine.current_state.get_class()
		var s: Object = _builder_ant.state_machine.current_state
		st = str(s.get_script().resource_path.get_file()) if s.get_script() != null else st
	return "builder_ant pos=%s state=%s has_candy=%s" % [
		_builder_ant.global_position, st, _builder_ant.has_candy]

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1
	print("[CampaignS4ClearTest] candy_piece_picked #%d remaining_hp=%d frame=%d" % [_picks, _remaining_hp, _frame])

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	var saved: int = int(result.get("saved", -1))
	var orig: int = int(result.get("original_hp", -1))
	var lost: int = int(result.get("lost", -1))
	if orig > 0 and saved >= orig and lost == 0:
		print("[CampaignS4ClearTest] PASS stage_cleared saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS4ClearTest] FAIL cleared but saved=%d/%d lost=%d frame=%d" % [saved, orig, lost, _frame])
		get_tree().quit(1)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_failed reason=%s saved=%d picks=%d %s frame=%d" % [
		str(result.get("reason", "?")), int(result.get("saved", -1)), _picks, _builder_ant_diag(), _frame])

func _fail(msg: String) -> void:
	print("[CampaignS4ClearTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
