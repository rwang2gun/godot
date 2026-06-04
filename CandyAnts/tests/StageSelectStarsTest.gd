extends Node

# 진단/회귀 — StageSelect가 SaveData의 클리어 기록(별점)을 슬롯 카드 별 폴리곤 색으로 반영하는지.
# record_clear로 stage1(3성)·stage2(1성) 기록 후 StageSelect를 띄워 각 카드의 Star Poly 색을 검증한다.

const STAGE_SELECT := preload("res://scenes/ui/StageSelect.tscn")
const TEMP_PATH := "user://test_stageselect_stars.cfg"

func _ready() -> void:
	var fails: Array[String] = []
	SaveData._test_cleanup_files(TEMP_PATH)
	SaveData._test_reset(TEMP_PATH)

	# stage1: 5/5 (thresholds 0.6/0.8/1.0) → 3성. stage2: 3/5 (0.5/0.75/1.0) → 1성.
	SaveData.record_clear(1, 5, 5, [0.6, 0.8, 1.0])
	SaveData.record_clear(2, 3, 5, [0.5, 0.75, 1.0])

	var e1 := SaveData.get_stage_entry(1)
	var e2 := SaveData.get_stage_entry(2)
	print("[StageSelectStarsTest] entry1=%s entry2=%s" % [str(e1), str(e2)])
	if int(e1.get("stars", -1)) != 3:
		fails.append("SaveData stage1 stars=%s (expected 3)" % str(e1.get("stars")))
	if int(e2.get("stars", -1)) != 1:
		fails.append("SaveData stage2 stars=%s (expected 1)" % str(e2.get("stars")))

	var sel: Control = STAGE_SELECT.instantiate()
	add_child(sel)
	await get_tree().process_frame
	await get_tree().process_frame

	var grid := sel.get_node("MarginContainer/VBox/SlotGrid")
	var filled1 := _count_filled(grid, 1)
	var filled2 := _count_filled(grid, 2)
	print("[StageSelectStarsTest] rendered filled stars: stage1=%d stage2=%d" % [filled1, filled2])
	if filled1 != 3:
		fails.append("stage1 card filled stars=%d (expected 3)" % filled1)
	if filled2 != 1:
		fails.append("stage2 card filled stars=%d (expected 1)" % filled2)

	sel.queue_free()
	SaveData._test_cleanup_files(TEMP_PATH)

	if fails.is_empty():
		print("[StageSelectStarsTest] PASS")
		get_tree().quit(0)
	else:
		print("[StageSelectStarsTest] FAIL")
		for f in fails:
			print("  ", f)
		get_tree().quit(1)

func _count_filled(grid: Node, stage_id: int) -> int:
	for card in grid.get_children():
		if int(card.get("stage_id")) != stage_id:
			continue
		var row := card.get_node_or_null("MainPanel/VBox/StarRow")
		if row == null:
			return -1
		var n := 0
		for star in row.get_children():
			var poly: Polygon2D = star.get_node_or_null("Poly") as Polygon2D
			if poly != null and poly.color.is_equal_approx(Tokens.LEMON_500):
				n += 1
		return n
	return -2
