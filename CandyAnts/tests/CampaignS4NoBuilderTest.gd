extends Node

# Campaign S4 "계단 공사" — 음성 대조(identifiability): builder가 *필수*임을 입증.
# 스킬을 전혀 부여하지 않으면 개미는 좌측 지면 끝(col8)에서 갭(cols9~11)으로 걸어 들어가 추락 →
#   바닥 없는 갭을 지나 플레이 영역 아래로 벗어나 LostState → 우측 높은 단(candy) 도달 불가 →
#   candy_piece_picked 0건 → hp 0 불가 → 클리어 불가.
# PASS: 픽업 0건 + stage_failed(no_more_ants/time_out) 또는 deadline.
# FAIL: candy_piece_picked 발화(무빌더 개미가 단을 오름 = 퍼즐 붕괴) 또는 stage_cleared.
# 양성 테스트(CampaignS4ClearTest, builder로 saved==4)와 짝을 이뤄 "builder로만 등반" 입증.

const DEADLINE_FRAMES: int = 12000

var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.candy_piece_picked.connect(_on_picked)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS4NoBuilderTest] driver ready (no skills applied)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		_pass("deadline reached with picks=0 (no ant climbed without builder)")

func _on_picked(_remaining_hp: int) -> void:
	if _done:
		return
	_picks += 1
	_fail("candy picked without builder (picks=%d) — staircase climbed without building" % _picks)

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without builder — puzzle broken")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	if _picks == 0:
		_pass("stage_failed reason=%s picks=0 (builder required, as designed)" % str(result.get("reason", "?")))
	else:
		_fail("stage_failed but picks=%d occurred" % _picks)

func _pass(msg: String) -> void:
	print("[CampaignS4NoBuilderTest] PASS %s frame=%d" % [msg, _frame])
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[CampaignS4NoBuilderTest] FAIL %s frame=%d" % [msg, _frame])
	_done = true
	get_tree().quit(1)
