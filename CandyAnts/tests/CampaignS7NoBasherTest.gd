extends Node

# Campaign S7 음성 — basher 미시전 → 흙 벽(cols9-12)을 통과 못 함 → candy 회수 불가 → 클리어 불가.
# basher 필수성 입증: 무리는 row9를 우향 보행하다 col9 흙 벽에 막혀 flip(WalkerState 벽 반응) → 왕복만 하다
# candy(col20)에 영영 도달 못 한다. picks==0 유지.
# PASS: (not cleared) && picks==0 — deadline 또는 stage_failed(no_more_ants). FAIL: stage_cleared 또는 picks>0.

const DEADLINE_FRAMES: int = 12000

var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS7NoBasherTest] driver ready")

func _physics_process(_delta: float) -> void:
	# basher를 절대 시전하지 않는다 — 흙 벽 통과 수단 부재 = 클리어 불가 입증.
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		if _picks == 0:
			print("[CampaignS7NoBasherTest] PASS (deadline, not cleared, picks=0) frame=%d" % _frame)
			_done = true
			get_tree().quit(0)
		else:
			_fail("deadline but picks=%d (>0 — 벽 통과 안 됐어야 함)" % _picks)

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without basher (saved=%d picks=%d)" % [int(result.get("saved", -1)), _picks])

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	if _picks == 0:
		print("[CampaignS7NoBasherTest] PASS stage_failed reason=%s picks=0 (basher 필수) frame=%d" % [
			str(result.get("reason", "?")), _frame])
		get_tree().quit(0)
	else:
		_fail("stage_failed but picks=%d (>0)" % _picks)

func _fail(msg: String) -> void:
	print("[CampaignS7NoBasherTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
