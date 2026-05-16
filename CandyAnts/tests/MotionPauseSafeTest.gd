extends Node

# UI_GUIDE §4 pause_safe 검증.
# pause_safe=true 시 SceneTree.paused 상태에서도 tween 진행, false 시 정지.

func _ready() -> void:
	var failures: Array[String] = []

	# Case 1: pause_safe=true → paused tree에서도 진행
	var n1 := ColorRect.new()
	n1.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(n1)
	n1.modulate.a = 0.0
	get_tree().paused = true
	Motion.fade_in(n1, 0.05, true)
	for i in 6:
		await get_tree().process_frame
	# 0.05s × 60fps = 3 frames, with 6 frames await tween should complete
	if abs(n1.modulate.a - 1.0) > 0.01:
		failures.append("pause_safe=true did not progress; alpha=" + str(n1.modulate.a))

	# Case 2: pause_safe=false → paused tree에서 정지
	var n2 := ColorRect.new()
	add_child(n2)
	n2.modulate.a = 0.0
	Motion.fade_in(n2, 0.05, false)
	for i in 6:
		await get_tree().process_frame
	if n2.modulate.a >= 0.99:
		failures.append("pause_safe=false unexpectedly progressed; alpha=" + str(n2.modulate.a))

	get_tree().paused = false

	if failures.size() > 0:
		push_error("MotionPauseSafeTest FAIL: " + str(failures))
		print("[MotionPauseSafeTest] FAIL")
		for f in failures:
			print("  ", f)
		get_tree().quit(1)
	else:
		print("[MotionPauseSafeTest] PASS")
		get_tree().quit(0)
