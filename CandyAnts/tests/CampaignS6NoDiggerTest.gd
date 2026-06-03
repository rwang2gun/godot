extends Node

# Campaign S6 음성 — digger 미부여(floater만) → 흙 캡(지붕)을 못 뚫어 챔버 candy에 도달 불가 (digger 필수성).
# 메사는 벽으로 enclosed이고 흙 캡은 정적 지형이라 walker는 좌우 pacing만 → 하강 경로 없음 → picks==0.
# floater를 줘도 떨어질 곳이 없어 무의미(= digger가 빠진 조각임을 격리).
# PASS: deadline/stage_failed && picks==0. FAIL: stage_cleared / picks>0.

const DEADLINE_FRAMES: int = 8000

var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS6NoDiggerTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	# floater만 분배(digger 없음) — digger 부재가 유일한 차이임을 보장.
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if not a.has_trait(&"floater"):
			var floater: FloaterSkill = FloaterSkill.new()
			if floater.can_apply(a):
				floater.apply(a)
	if _frame > DEADLINE_FRAMES:
		if _picks == 0:
			print("[CampaignS6NoDiggerTest] PASS (deadline, no candy reached) picks=0 frame=%d" % _frame)
			_done = true
			get_tree().quit(0)
		else:
			_fail("deadline with picks=%d (candy reached without digger)" % _picks)

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without digger (picks=%d)" % _picks)

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	if _picks == 0:
		print("[CampaignS6NoDiggerTest] PASS stage_failed reason=%s picks=0 (digger required) frame=%d" % [
			str(result.get("reason", "?")), _frame])
		get_tree().quit(0)
	else:
		_fail("stage_failed but picks=%d > 0" % _picks)

func _fail(msg: String) -> void:
	print("[CampaignS6NoDiggerTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
