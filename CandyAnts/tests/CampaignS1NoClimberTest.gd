extends Node

# Campaign S1 "첫 마실" — 음성 대조(identifiability): climber가 *필수*임을 입증.
# 스킬을 전혀 부여하지 않으면 개미는 분지 반대편 1칸 벽(is_on_wall)에 막혀 사탕에 도달 못 함
#   → candy_piece_picked가 한 번도 발화하지 않고 → hp 0 불가 → 클리어 불가(시간 초과 실패).
# PASS: 픽업 0건인 채 stage_failed(time_out) 또는 deadline 도달.
# FAIL: candy_piece_picked 발화(무스킬 개미가 분지를 건넘 = 퍼즐 붕괴) 또는 stage_cleared.
# 양성 테스트(CampaignS1ClearTest, climber 부여 시 클리어)와 짝을 이뤄 "climber로만 통과" 입증.

const DEADLINE_FRAMES: int = 12000

var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.candy_piece_picked.connect(_on_picked)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS1NoClimberTest] driver ready (no skills applied)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		# 픽업 0건으로 deadline 도달 → 무스킬 개미가 끝내 분지를 못 건넌 것 → 의도대로 PASS.
		_pass("deadline reached with picks=0 (basin blocked walkers)")

func _on_picked(_remaining_hp: int) -> void:
	if _done:
		return
	_picks += 1
	_fail("candy picked without climber (picks=%d) — basin failed to block walkers" % _picks)

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without climber — puzzle broken")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	if _picks == 0:
		_pass("stage_failed reason=%s picks=0 (climber required, as designed)" % str(result.get("reason", "?")))
	else:
		_fail("stage_failed but picks=%d occurred" % _picks)

func _pass(msg: String) -> void:
	print("[CampaignS1NoClimberTest] PASS %s frame=%d" % [msg, _frame])
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[CampaignS1NoClimberTest] FAIL %s frame=%d" % [msg, _frame])
	_done = true
	get_tree().quit(1)
