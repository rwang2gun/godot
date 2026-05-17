extends Node

# Phase 11 — PauseBtn paused polling → icon swap (plan v2 §5.1).
# super._ready 호출이 CButton boop 연결을 정상 살리는지도 함께 검증.

const _PAUSE_ICON := preload("res://assets/icons/ui/pause.svg")
const _PLAY_ICON := preload("res://assets/icons/ui/play.svg")

func _ready() -> void:
	var failures: Array[String] = []
	var btn: PauseBtn = PauseBtn.new()
	add_child(btn)
	await get_tree().process_frame
	await get_tree().process_frame

	# 초기 = play 모드 X (paused false), pause icon 표시
	var icon_rect: TextureRect = btn._icon_rect
	if icon_rect == null:
		failures.append("PauseBtn._icon_rect null after _ready")
	elif icon_rect.texture != _PAUSE_ICON:
		failures.append("initial icon expected pause got %s" % str(icon_rect.texture))

	# paused = true → 1 frame 후 play icon
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	if icon_rect.texture != _PLAY_ICON:
		failures.append("paused=true icon expected play got %s" % str(icon_rect.texture))

	# paused = false → 1 frame 후 pause icon
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	if icon_rect.texture != _PAUSE_ICON:
		failures.append("paused=false icon expected pause got %s" % str(icon_rect.texture))

	# super._ready 보존: CButton boop tween 생성 검증
	btn.emit_signal("pressed")
	await get_tree().process_frame
	if btn._boop_tween == null or not btn._boop_tween.is_valid():
		failures.append("super._ready missing: CButton boop wiring lost")

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	get_tree().paused = false
	if failures.size() > 0:
		push_error("PauseBtnIconSwapTest FAIL — %d" % failures.size())
		for f in failures: print("  ", f)
		get_tree().quit(1)
	else:
		print("[PauseBtnIconSwapTest] PASS")
		get_tree().quit(0)
