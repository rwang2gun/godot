extends Node

# Campaign S9 "종합 과자점" 음성 짝 — 스킬을 하나도 시전하지 않으면 첫 관문(소다 호수)을 못 넘는다.
# 개미는 col8 끝에서 호수(cols9-12)로 추락 → row12 water에서 표류(AdriftState) → 결국 no_more_ants로 stage_failed.
# (표류 개미는 StageRunner._living_ant_count에서 제외 → 정상 종료를 막지 않음.)
# candy는 호수+흙 벽+갭+높은 단 너머라 bridge/basher/builder 없이는 도달 불가 → picks==0 불변.
# 이로써 3개 스킬의 필수성을 입증(클리어 짝 CampaignS9ClearTest와 대비).
# PASS: stage_failed && picks==0. FAIL: stage_cleared (스킬 없이 클리어 = 지오메트리 이상) / deadline.

const DEADLINE_FRAMES: int = 30000

var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS9NoSkillTest] driver ready (no skills applied)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d (음성 테스트는 stage_failed로 종료돼야 함)" % _picks)

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without any skill — 호수/벽/단을 스킬 없이 통과 = 지오메트리 이상")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	if _picks == 0:
		print("[CampaignS9NoSkillTest] PASS stage_failed reason=%s picks=0 (스킬 필수성 입증) frame=%d" % [
			str(result.get("reason", "?")), _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS9NoSkillTest] FAIL stage_failed but picks=%d>0 (스킬 없이 candy 도달?) frame=%d" % [_picks, _frame])
		get_tree().quit(1)

func _fail(msg: String) -> void:
	print("[CampaignS9NoSkillTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
