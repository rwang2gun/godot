extends Node

# Campaign S6 음성 — digger 미부여(climber만) → row9 흙 선반을 못 뚫어 공동 candy 도달 불가 (digger 필수성).
# (2026-06-07 재작성: 구 floater-distributor 설계 폐기. 현 stage06 = digger:1 + climber:5, 모든 낙하 4칸=안전.)
# 클리어 테스트와 동일하게 모든 개미에 climber를 부여하되 digger만 빼면, 개미는 선반 위(row9)에서 좌우
# pacing만 할 뿐 candy(공동 안)로 내려갈 구멍을 못 뚫어 picks==0 → digger가 빠진 유일한 조각임을 격리한다.
# PASS: deadline/stage_failed && picks==0. FAIL: stage_cleared / picks>0.

const DEADLINE_FRAMES: int = 8000

var _climbed: Dictionary = {}
var _frame: int = 0
var _done: bool = false
var _picks: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS6NoDiggerTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	# climber만 부여(digger 절대 금지) — digger 부재가 유일한 차이임을 보장.
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
