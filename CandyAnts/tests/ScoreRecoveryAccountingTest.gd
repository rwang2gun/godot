extends Node

# 2026-06-03 — 낙하산 분배자 사탕 드롭/재획득 회계 검증 (순수 ScoreSystem 단위).
# 드롭 즉시 lost 처리 + 재획득 시 lost→in_transit 보정이 4-카운터 불변식을 깨지 않는지 확인.
# 시나리오: 픽업 → 드롭(lost) → 재획득(recovered) → 귀가(saved). 최종 saved=1, lost=0, in_transit=0.
# 짝: 드롭 후 미회수 시 lost 유지(클리어 차단 안 함)도 확인.

func _ready() -> void:
	var fails: Array[String] = []

	var ss := ScoreSystem.new()
	ss.start(3)

	# 1) 픽업 → in_transit=1
	EventBus.candy_piece_picked.emit(2)
	if ss.in_transit_pieces != 1 or ss.lost_pieces != 0 or ss.saved_pieces != 0:
		fails.append("after pick: it=%d lost=%d saved=%d (want 1/0/0)" % [ss.in_transit_pieces, ss.lost_pieces, ss.saved_pieces])

	# 2) 드롭 → lost=1, in_transit=0 (즉시 lost 처리)
	EventBus.candy_piece_lost.emit(self)
	if ss.in_transit_pieces != 0 or ss.lost_pieces != 1:
		fails.append("after drop: it=%d lost=%d (want 0/1)" % [ss.in_transit_pieces, ss.lost_pieces])

	# 3) 재획득 → lost=0, in_transit=1 (보정)
	EventBus.candy_piece_recovered.emit(self)
	if ss.in_transit_pieces != 1 or ss.lost_pieces != 0:
		fails.append("after recover: it=%d lost=%d (want 1/0)" % [ss.in_transit_pieces, ss.lost_pieces])

	# 4) 귀가 → saved=1, in_transit=0. 같은 조각이 lost+saved 이중계산 안 됨.
	EventBus.ant_saved.emit(self, true)
	if ss.saved_pieces != 1 or ss.in_transit_pieces != 0 or ss.lost_pieces != 0:
		fails.append("after save: saved=%d it=%d lost=%d (want 1/0/0)" % [ss.saved_pieces, ss.in_transit_pieces, ss.lost_pieces])

	# 불변식: saved+in_transit+lost <= original
	if ss.saved_pieces + ss.in_transit_pieces + ss.lost_pieces > ss.original_hp:
		fails.append("invariant broken: %d+%d+%d > %d" % [ss.saved_pieces, ss.in_transit_pieces, ss.lost_pieces, ss.original_hp])

	# 5) 짝: 두 번째 조각 픽업 → 드롭 후 미회수 → lost 유지, 클리어 차단 위해 in_transit 0.
	EventBus.candy_piece_picked.emit(1)
	EventBus.candy_piece_lost.emit(self)
	if ss.lost_pieces != 1 or ss.in_transit_pieces != 0:
		fails.append("after unrecovered drop: lost=%d it=%d (want 1/0)" % [ss.lost_pieces, ss.in_transit_pieces])
	# candy_hp=0 가정 시 클리어 가능해야 함(미회수 드롭은 lost로 계산되어 차단 안 함).
	if not ss.is_cleared(0):
		fails.append("is_cleared(0) false despite in_transit=0 (unrecovered drop blocks clear)")

	ss.stop()

	if fails.is_empty():
		print("[ScoreRecoveryAccountingTest] PASS - drop/recover accounting consistent")
		get_tree().quit(0)
	else:
		print("[ScoreRecoveryAccountingTest] FAIL\n  ", "\n  ".join(fails))
		get_tree().quit(1)
