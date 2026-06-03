extends Node

func _ready() -> void:
	var layout: MenuLayout = load("res://data/menu_layout.tres") as MenuLayout
	if layout == null:
		return _fail("menu_layout.tres load failed")
	if not layout.is_valid():
		return _fail("MenuLayout.is_valid() returned false")
	if layout.slots.size() != 10:
		return _fail("expected 10 slots, got %d" % layout.slots.size())
	for i in 10:
		var s: Dictionary = layout.slots[i]
		if int(s["stage_id"]) != i + 1:
			return _fail("slot[%d].stage_id expected %d, got %s" % [i, i + 1, str(s["stage_id"])])
		var expected_available: bool = i < 7
		if bool(s["available"]) != expected_available:
			return _fail("slot[%d].available expected %s" % [i, expected_available])
	print("[MenuLayoutResourceTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[MenuLayoutResourceTest] FAIL ", msg)
	get_tree().quit(1)
