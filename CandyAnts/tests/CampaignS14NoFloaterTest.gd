extends Node

# Campaign scene_id 14 "높은 곳에서" — 음성 대조(identifiability): floater가 *필수*임을 입증.
# 스킬 0 부여 → 고원 위 무리는 candy(col22)에 도달해 픽업(picks>0)하지만, 귀환 시 고원 좌단(col10)
# 6칸 낙하(288px >= 기절 임계 240px=5×cell) → 착지 기절(DeadState) → candy_piece_lost.
# 공통 계약 §필수성 negative (carrier-death형): 운반 중 기절이므로 lost가 실제로 카운트된다.
# PASS: picks>0 (무보정으로 사탕 도달 — 낙하는 귀환 경로에만 있음) AND lost>0 (낙하 기절로
#   조각 손실) AND saved==0 (floater 없이는 단 한 조각도 귀가 못 함).
# FAIL: picks==0(사탕 미도달=맵 버그) / lost==0(기절 임계 미발동) / saved>0(조각 귀가).
# 짝 양성(CampaignS14ClearTest, 분배자 floater 전이 시 saved=4/4)이 맵 가용성을 보장.

const DEADLINE_FRAMES: int = 14000

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
	print("[CampaignS14NoFloaterTest] driver ready (no skills)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		_evaluate("deadline")

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_lost(_by_ant: Node) -> void:
	_lost += 1

func _on_saved(_ant: Node, with_candy: bool) -> void:
	if with_candy:
		_saved_pieces += 1

func _on_cleared(result: Dictionary) -> void:
	# 모든 조각이 손실되면 hp0+in_transit0 → cleared(saved=0)로 종료될 수 있음.
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
		fails.append("picks=0 — 무보정으로도 사탕 미도달(맵 버그)")
	if _lost <= 0:
		fails.append("lost=0 — 귀환 6칸 낙하가 기절을 안 일으킴(임계 미발동)")
	if _saved_pieces != 0:
		fails.append("saved=%d — floater 없이 조각이 귀가함(낙하 기절 누락)" % _saved_pieces)
	if fails.is_empty():
		print("[CampaignS14NoFloaterTest] PASS via=%s picks=%d lost=%d saved=0 frame=%d" % [
			via, _picks, _lost, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS14NoFloaterTest] FAIL via=%s picks=%d lost=%d saved=%d frame=%d\n  %s" % [
			via, _picks, _lost, _saved_pieces, _frame, "\n  ".join(fails)])
		get_tree().quit(1)
