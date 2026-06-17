extends Node

# 2026-06-17 — StageSlotCard 내부 콘텐츠가 Button 클릭을 가로채지 않는지 검증(prove-it).
# 카드는 Button이고 시각 노드(별 Star1~3·라벨·VBox·패널)는 그 자식이다. 자식 Control의 기본
# mouse_filter는 STOP이라, 그 영역 클릭을 자식이 흡수하고 부모 Button으로 넘기지 않는다 →
# "별 부분 클릭 시 선택 안 됨 / 여러 번 눌러야 가끔 됨". 카드 어디를 눌러도 Button이 받으려면
# 모든 후손 Control이 IGNORE여야 한다(시각 전용이므로). self(Button)만 STOP 유지.
# PASS: 후손 Control 전부 mouse_filter == IGNORE.

const CARD := preload("res://scenes/ui/atoms/StageSlotCard.tscn")

func _ready() -> void:
	var card: StageSlotCard = CARD.instantiate() as StageSlotCard
	add_child(card)
	await get_tree().process_frame
	# self(Button)는 STOP이어야 클릭을 받는다 — 회귀로 함께 단언.
	if card.mouse_filter != Control.MOUSE_FILTER_STOP:
		print("[StageSlotCardClickThroughTest] FAIL — root Button must be STOP, got %d" % card.mouse_filter)
		get_tree().quit(1)
		return
	var blockers: Array[String] = []
	_collect_blockers(card, card, blockers)
	card.queue_free()
	if blockers.is_empty():
		print("[StageSlotCardClickThroughTest] PASS — 모든 후손 Control이 IGNORE (클릭이 Button으로 통과)")
		get_tree().quit(0)
	else:
		print("[StageSlotCardClickThroughTest] FAIL — 클릭을 가로채는 후손 Control(mouse_filter != IGNORE): %s" % str(blockers))
		get_tree().quit(1)

func _collect_blockers(node: Node, root: Node, out: Array[String]) -> void:
	for child in node.get_children():
		if child is Control and child != root:
			var c: Control = child as Control
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				out.append("%s(filter=%d)" % [c.name, c.mouse_filter])
		_collect_blockers(child, root, out)
