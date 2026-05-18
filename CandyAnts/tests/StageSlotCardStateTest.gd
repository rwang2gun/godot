extends Node

const SlotScene := preload("res://scenes/ui/atoms/StageSlotCard.tscn")

func _ready() -> void:
	var states := [
		StageSlotCard.SlotState.PLAYABLE,
		StageSlotCard.SlotState.CLEARED,
		StageSlotCard.SlotState.LOCKED,
		StageSlotCard.SlotState.COMING_SOON,
	]
	for state in states:
		var card: StageSlotCard = SlotScene.instantiate()
		card.stage_id = 1
		card.slot_state = state
		add_child(card)
		await get_tree().process_frame
		if not _verify(card, state):
			card.queue_free()
			return
		card.queue_free()
		await get_tree().process_frame
	print("[StageSlotCardStateTest] PASS")
	get_tree().quit(0)

func _verify(card: StageSlotCard, state: int) -> bool:
	# 자물쇠 visibility
	var state_badge: TextureRect = card.get_node("MainPanel/StateBadge")
	var coming_soon_label: Label = card.get_node("MainPanel/VBox/ComingSoonLabel")
	var stars: HBoxContainer = card.get_node("MainPanel/VBox/StarRow")
	match state:
		StageSlotCard.SlotState.PLAYABLE, StageSlotCard.SlotState.CLEARED:
			if state_badge.visible:
				return _fail("state %d: lock should hidden" % state)
			if coming_soon_label.visible:
				return _fail("state %d: coming_soon label should hidden" % state)
			if not stars.visible:
				return _fail("state %d: stars should visible" % state)
		StageSlotCard.SlotState.LOCKED:
			if not state_badge.visible:
				return _fail("state LOCKED: lock should be visible")
			if coming_soon_label.visible:
				return _fail("state LOCKED: coming_soon should hidden")
		StageSlotCard.SlotState.COMING_SOON:
			if state_badge.visible:
				return _fail("state COMING_SOON: lock should hidden")
			if not coming_soon_label.visible:
				return _fail("state COMING_SOON: coming_soon label should visible")
	return true

func _fail(msg: String) -> bool:
	print("[StageSlotCardStateTest] FAIL ", msg)
	get_tree().quit(1)
	return false
