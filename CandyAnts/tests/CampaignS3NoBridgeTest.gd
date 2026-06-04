extends Node

# Campaign S3 "사탕 호수" — 음성 대조(identifiability): bridge가 *필수*임을 입증.
# 스킬을 전혀 부여하지 않으면 개미는 좌측 지면 끝(col8)에서 호수(cols9~16)로 걸어 들어가 Water에서 표류(AdriftState)
#   → candy(우측, col21)에 영영 도달 못 함 → candy_piece_picked 0건 → hp 0 불가 → 클리어 불가.
# PASS: 픽업 0건 + stage_failed(no_more_ants/time_out) 또는 deadline.
#   (표류 개미는 StageRunner._living_ant_count에서 제외 → 전원 표류 시 no_more_ants, 아니면 time_out으로 종료.)
# FAIL: candy_piece_picked 발화(무다리 개미가 호수를 건넘 = 퍼즐 붕괴) 또는 stage_cleared.
# 양성 테스트(CampaignS3ClearTest, bridge로 횡단 시 saved==4)와 짝을 이뤄 "bridge로만 통과" 입증.

const DEADLINE_FRAMES: int = 12000

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _deaths: int = 0

func _ready() -> void:
	EventBus.candy_piece_picked.connect(_on_picked)
	EventBus.ant_died.connect(_on_died)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS3NoBridgeTest] driver ready (no skills applied)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		# 픽업 0건으로 deadline 도달 → 무다리 개미가 끝내 호수를 못 건넌 것 → 의도대로 PASS.
		_pass("deadline reached with picks=0 (water blocked walkers, deaths=%d)" % _deaths)

func _on_picked(_remaining_hp: int) -> void:
	if _done:
		return
	_picks += 1
	_fail("candy picked without bridge (picks=%d) — water failed to block walkers" % _picks)

func _on_died(_ant: Node, _was_carrying: bool) -> void:
	_deaths += 1

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without bridge — puzzle broken")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	if _picks == 0:
		_pass("stage_failed reason=%s picks=0 deaths=%d (bridge required, as designed)" % [
			str(result.get("reason", "?")), _deaths])
	else:
		_fail("stage_failed but picks=%d occurred" % _picks)

func _pass(msg: String) -> void:
	print("[CampaignS3NoBridgeTest] PASS %s frame=%d" % [msg, _frame])
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[CampaignS3NoBridgeTest] FAIL %s frame=%d" % [msg, _frame])
	_done = true
	get_tree().quit(1)
