extends Node

# Campaign scene_id 12 "낭떠러지 끝" — 음성 대조(identifiability): blocker가 *필수*임을 입증.
# 스킬 0 부여 → spawn(col9) 우향 무리는 candy(좌측 col5)를 등진 채 전원 절벽(cols18+ water)으로
# 행진해 익사 → 픽업 0, 귀가 0.
# 공통 계약 §필수성 negative (pickup-전 hazard형): 빈손 익사는 candy_piece_lost를 emit하지 않으므로
#   lost는 단언하지 않는다. PASS: picks==0 AND saved==0 (blocker 없이는 단 한 조각도 못 구한다).
#   짝 양성(CampaignS12ClearTest, blocker 반전 시 saved=4/4)이 맵 가용성을 보장 →
#   "맵 버그로 사탕에 못 간 것"을 필수성으로 오인하지 않는다.
# FAIL: picks>0(무보정 무리가 사탕 도달 — blocker 불필요) 또는 saved>0(귀가 발생).

const DEADLINE_FRAMES: int = 14000

var _picks: int = 0
var _saved_pieces: int = 0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.candy_piece_picked.connect(_on_picked)
	EventBus.ant_saved.connect(_on_saved)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	print("[CampaignS12NoBlockerTest] driver ready (no skills)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE_FRAMES:
		_evaluate("deadline")

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_saved(_ant: Node, with_candy: bool) -> void:
	if with_candy:
		_saved_pieces += 1

func _on_cleared(result: Dictionary) -> void:
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
	if _picks != 0:
		fails.append("picks=%d — blocker 없이 무리가 사탕에 도달(필수성 붕괴)" % _picks)
	if _saved_pieces != 0:
		fails.append("saved=%d — blocker 없이 조각이 귀가함" % _saved_pieces)
	if fails.is_empty():
		print("[CampaignS12NoBlockerTest] PASS via=%s picks=0 saved=0 frame=%d" % [via, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS12NoBlockerTest] FAIL via=%s picks=%d saved=%d frame=%d\n  %s" % [
			via, _picks, _saved_pieces, _frame, "\n  ".join(fails)])
		get_tree().quit(1)
