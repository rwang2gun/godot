extends Node

# Phase 11 — ReleaseRateStepper signal contract (plan v2 §5.2).

const _STEPPER_SCENE := preload("res://scenes/ui/ReleaseRateStepper.tscn")

var _last_action_name: StringName = &""

func _ready() -> void:
	var failures: Array[String] = []
	var stepper: ReleaseRateStepper = _STEPPER_SCENE.instantiate()
	add_child(stepper)
	await get_tree().process_frame

	EventBus.action_triggered.connect(_capture_action)

	# BtnMinus pressed → RELEASE_RATE_DOWN
	stepper.get_node("BtnMinus").emit_signal("pressed")
	await get_tree().process_frame
	if _last_action_name != &"release_rate_down":
		failures.append("BtnMinus expected release_rate_down got %s" % _last_action_name)

	# BtnPlus pressed → RELEASE_RATE_UP
	stepper.get_node("BtnPlus").emit_signal("pressed")
	await get_tree().process_frame
	if _last_action_name != &"release_rate_up":
		failures.append("BtnPlus expected release_rate_up got %s" % _last_action_name)

	# EventBus.release_rate_changed → Value Label sync
	EventBus.release_rate_changed.emit(42)
	await get_tree().process_frame
	var value_label: Label = stepper.get_node("Value")
	if value_label.text != "42":
		failures.append("Value Label expected '42' got '%s'" % value_label.text)

	EventBus.action_triggered.disconnect(_capture_action)
	_finish(failures)

func _capture_action(name: StringName, _payload: Dictionary) -> void:
	_last_action_name = name

func _finish(failures: Array[String]) -> void:
	if failures.size() > 0:
		push_error("ReleaseRateStepperTest FAIL — %d" % failures.size())
		for f in failures: print("  ", f)
		get_tree().quit(1)
	else:
		print("[ReleaseRateStepperTest] PASS")
		get_tree().quit(0)
