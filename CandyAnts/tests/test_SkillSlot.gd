extends Node

# Phase 11 — SkillSlot.set_disabled_state(b) atom freeze 확장 회귀.
# UI_GUIDE §3.4: 외부 호출자는 Button.disabled 직접 대입 금지. set_disabled_state만 사용.

const _SLOT_SCENE := preload("res://scenes/ui/atoms/SkillSlot.tscn")

func _ready() -> void:
	var failures: Array[String] = []
	var slot: SkillSlot = _SLOT_SCENE.instantiate()
	slot.skill_id = &"slideR"
	slot.hotkey = "1"
	slot.ko_label = "계단"
	add_child(slot)
	await get_tree().process_frame
	slot.set_count(3)
	await get_tree().process_frame

	# 초기: enabled, alpha 1.0
	if slot.disabled:
		failures.append("initial slot.disabled expected false")
	var main_bg: Panel = slot.get_node("MainBG")
	if abs(main_bg.self_modulate.a - 1.0) > 0.01:
		failures.append("initial MainBG.alpha expected 1.0 got %s" % str(main_bg.self_modulate.a))

	# set_disabled_state(true) → disabled + alpha 0.55
	slot.set_disabled_state(true)
	if not slot.disabled:
		failures.append("after set_disabled_state(true), slot.disabled expected true")
	if abs(main_bg.self_modulate.a - 0.55) > 0.01:
		failures.append("disabled MainBG.alpha expected 0.55 got %s" % str(main_bg.self_modulate.a))

	# set_disabled_state(false) → enabled + alpha 1.0
	slot.set_disabled_state(false)
	if slot.disabled:
		failures.append("after set_disabled_state(false), slot.disabled expected false")
	if abs(main_bg.self_modulate.a - 1.0) > 0.01:
		failures.append("re-enabled MainBG.alpha expected 1.0 got %s" % str(main_bg.self_modulate.a))

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.size() > 0:
		push_error("test_SkillSlot FAIL — %d" % failures.size())
		for f in failures: print("  ", f)
		get_tree().quit(1)
	else:
		print("[test_SkillSlot] PASS")
		get_tree().quit(0)
