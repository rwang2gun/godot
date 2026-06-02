extends Node

# Campaign S2 "오르막" — 음성 대조(identifiability): floater가 *필수*임을 입증.
# climber만 부여(분배자·floater 없음) → 개미는 메사를 등반해 사탕을 픽업(picks>0)하지만,
# 복귀 시 5칸 낙하 → 기절(DeadState) → candy_piece_lost. floater가 없으면 단 한 조각도 귀가 못 함.
# PASS: picks>0 (climber로 사탕 도달) AND lost>0 (복귀 낙하가 기절로 조각 손실) AND saved==0 (무귀가).
#   → "climber만으로는 사탕에 닿을 수 있어도 floater 없이는 조각을 집에 못 가져온다"를 입증.
#   양성 테스트(CampaignS2ClearTest, 분배자 floater 전이 시 saved==5)와 짝을 이뤄 floater 필수성 확립.
#   (경계값 검증 겸함: 정확히 5칸 낙하가 기절 임계 `>= 5×cell_size`를 실제로 트리거하는지. lost==0이면 미트리거.)
# FAIL: saved>0(낙하가 기절을 안 일으킴/조각 귀가) 또는 picks==0(climber로도 사탕 미도달).

const DEADLINE_FRAMES: int = 14000
const MAX_CLIMBERS: int = 6

var _climber_ids: Dictionary = {}
var _picks: int = 0
var _lost: int = 0
var _saved_pieces: int = 0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.candy_piece_picked.connect(_on_picked)
	EventBus.candy_piece_lost.connect(_on_lost)
	EventBus.ant_saved.connect(_on_saved)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS2NoFloaterTest] driver ready (climber only, no floater/distributor)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_apply_climbers()
	if _frame > DEADLINE_FRAMES:
		_evaluate("deadline")

func _apply_climbers() -> void:
	if _climber_ids.size() >= MAX_CLIMBERS:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		if _climber_ids.size() >= MAX_CLIMBERS:
			return
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var id: int = a.get_instance_id()
		if _climber_ids.has(id):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		var cl: ClimberSkill = ClimberSkill.new()
		if not cl.can_apply(a):
			continue
		cl.apply(a)
		_climber_ids[id] = true

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_lost(_by_ant: Node) -> void:
	_lost += 1

func _on_saved(_ant: Node, with_candy: bool) -> void:
	if with_candy:
		_saved_pieces += 1

func _on_cleared(result: Dictionary) -> void:
	# 무귀가라도 모든 조각이 손실되면 hp0+in_transit0 → cleared(saved=0)로 종료될 수 있음.
	_saved_pieces = int(result.get("saved", _saved_pieces))
	_evaluate("stage_cleared")

func _on_failed(result: Dictionary) -> void:
	_saved_pieces = int(result.get("saved", _saved_pieces))
	_evaluate("stage_failed reason=%s" % str(result.get("reason", "?")))

func _evaluate(via: String) -> void:
	if _done:
		return
	_done = true
	var fails: Array[String] = []
	if _picks <= 0:
		fails.append("picks=0 — climber로도 사탕 미도달(등반 경로 붕괴)")
	if _lost <= 0:
		fails.append("lost=0 — 복귀 5칸 낙하가 기절을 안 일으킴(임계 미트리거)")
	if _saved_pieces != 0:
		fails.append("saved=%d — floater 없이 조각이 귀가함(낙하 기절 누락)" % _saved_pieces)
	if fails.is_empty():
		print("[CampaignS2NoFloaterTest] PASS via=%s picks=%d lost=%d saved=0 frame=%d" % [
			via, _picks, _lost, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS2NoFloaterTest] FAIL via=%s picks=%d lost=%d saved=%d frame=%d\n  %s" % [
			via, _picks, _lost, _saved_pieces, _frame, "\n  ".join(fails)])
		get_tree().quit(1)
