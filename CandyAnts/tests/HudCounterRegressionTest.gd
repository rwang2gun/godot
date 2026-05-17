extends Node

# Phase 11 — HUD atom counter wiring (plan v2 §7.1).
# EventBus signal → Counter.set_value 경로 검증. caPop tween 자체는 phase 9에서 검증됨.

const _HUD_SCENE := preload("res://scenes/ui/HUD.tscn")

func _ready() -> void:
	var failures: Array[String] = []
	var hud: HUD = _HUD_SCENE.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	# CANDY_HP + IN_TRANSIT 트리거
	EventBus.candy_piece_picked.emit(7)
	await get_tree().process_frame
	var candy_label: Label = hud.get_node("Root/TopLeft/CounterCandyHp/MainPanel/VBox/BigNumber")
	if candy_label == null:
		failures.append("CounterCandyHp BigNumber node not found")
	elif candy_label.text != "7":
		failures.append("CANDY_HP text expected '7' got '%s'" % candy_label.text)
	var in_transit_label: Label = hud.get_node("Root/TopLeft/CounterInTransit/MainPanel/VBox/BigNumber")
	if in_transit_label == null or in_transit_label.text != "1":
		failures.append("IN_TRANSIT text expected '1' got '%s'" % (in_transit_label.text if in_transit_label else "null"))

	# SAVED 트리거 (with_candy=true → in_transit -1)
	EventBus.ant_saved.emit(self, true)
	await get_tree().process_frame
	var saved_label: Label = hud.get_node("Root/TopLeft/CounterSaved/MainPanel/VBox/BigNumber")
	if saved_label.text != "1":
		failures.append("SAVED text expected '1' got '%s'" % saved_label.text)
	if in_transit_label.text != "0":
		failures.append("IN_TRANSIT after save expected '0' got '%s'" % in_transit_label.text)

	# LOST 트리거
	EventBus.candy_piece_picked.emit(6)   # IN_TRANSIT 1
	await get_tree().process_frame
	EventBus.candy_piece_lost.emit(self)  # LOST 1, IN_TRANSIT 0
	await get_tree().process_frame
	var lost_label: Label = hud.get_node("Root/TopLeft/CounterLost/MainPanel/VBox/BigNumber")
	if lost_label.text != "1":
		failures.append("LOST text expected '1' got '%s'" % lost_label.text)
	if in_transit_label.text != "0":
		failures.append("IN_TRANSIT after lost expected '0' got '%s'" % in_transit_label.text)

	# update_time per-second clamp
	hud.update_time(47.3)
	await get_tree().process_frame
	var time_label: Label = hud.get_node("Root/TopRight/CounterTime/MainPanel/VBox/BigNumber")
	if time_label.text != "48":
		failures.append("TIME ceil expected '48' got '%s'" % time_label.text)
	hud.update_time(47.6)   # 같은 정수 → noop
	await get_tree().process_frame
	if time_label.text != "48":
		failures.append("TIME idempotent expected '48' got '%s'" % time_label.text)
	hud.update_time(46.9)
	await get_tree().process_frame
	if time_label.text != "47":
		failures.append("TIME decrement expected '47' got '%s'" % time_label.text)

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.size() > 0:
		push_error("HudCounterRegressionTest FAIL — %d" % failures.size())
		for f in failures: print("  ", f)
		get_tree().quit(1)
	else:
		print("[HudCounterRegressionTest] PASS")
		get_tree().quit(0)
