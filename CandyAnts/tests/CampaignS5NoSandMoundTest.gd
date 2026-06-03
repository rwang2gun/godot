extends Node

# Campaign S5 음성 — 어떤 스킬도 부여하지 않으면 candy(고립 플랫폼 위)에 도달 불가 검증 (sand_mound 필수성).
# 정적 벽/플랫폼은 ladder 셀이 아니라 walker가 flip만 한다(climber 없음) → 등반 불가 → candy 미회수.
# PASS: stage_failed && picks==0. FAIL: stage_cleared / picks>0 / deadline.

const DEADLINE_FRAMES: int = 8000

var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS5NoSandMoundTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		# no_more_ants/time_out 신호가 늦으면 picks==0만으로도 sand_mound 필수성은 입증됨.
		if _picks == 0:
			print("[CampaignS5NoSandMoundTest] PASS (deadline, no candy reached) picks=0 frame=%d" % _frame)
			_done = true
			get_tree().quit(0)
		else:
			_fail("deadline with picks=%d (candy reached without sand_mound)" % _picks)

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without sand_mound (picks=%d)" % _picks)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	if _picks == 0:
		print("[CampaignS5NoSandMoundTest] PASS stage_failed reason=%s picks=0 (sand_mound required) frame=%d" % [
			str(result.get("reason", "?")), _frame])
		get_tree().quit(0)
	else:
		_fail("stage_failed but picks=%d > 0" % _picks)

func _fail(msg: String) -> void:
	print("[CampaignS5NoSandMoundTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
