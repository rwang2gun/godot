extends Node

# Phase 8 — InputHintLabel mode 별 텍스트 매핑 + tracker absent fallback.


func _ready() -> void:
	await get_tree().process_frame

	var Label_Script: Script = load("res://scripts/ui/InputHintLabel.gd")

	# case-A: tracker 존재(autoload) — 현재 mode로 초기 텍스트 설정.
	var label_a: Label = Label.new()
	label_a.set_script(Label_Script)
	add_child(label_a)
	await get_tree().process_frame
	if label_a.text == "":
		_fail("case-A: tracker 존재 시 초기 텍스트가 비어있음"); return

	# case-B: input_mode_changed emit 시 텍스트 갱신.
	# Sweep 2 (phase 13): commit 6bf5faf로 한국어 i18n 됨 — 기대값 한국어 substring으로 갱신.
	EventBus.input_mode_changed.emit(&"pad")
	if not String(label_a.text).contains("A: 적용"):
		_fail("case-B: pad 텍스트 미적용 → %s" % label_a.text); return
	EventBus.input_mode_changed.emit(&"touch")
	if not String(label_a.text).contains("탭"):
		_fail("case-B: touch 텍스트 미적용 → %s" % label_a.text); return
	EventBus.input_mode_changed.emit(&"mouse")
	if not String(label_a.text).contains("클릭"):
		_fail("case-B: mouse 텍스트 미적용 → %s" % label_a.text); return

	label_a.queue_free()

	# case-C: unknown mode → 빈 텍스트로 fallback.
	var label_c: Label = Label.new()
	label_c.set_script(Label_Script)
	add_child(label_c)
	await get_tree().process_frame
	EventBus.input_mode_changed.emit(&"alien")
	if label_c.text != "":
		_fail("case-C: unknown mode가 빈 텍스트로 떨어지지 않음 → %s" % label_c.text); return

	print("[InputHintLabelTest] PASS")
	get_tree().quit(0)


func _fail(label: String) -> void:
	push_error("[InputHintLabelTest] FAIL %s" % label)
	print("[InputHintLabelTest] FAIL %s" % label)
	get_tree().quit(1)
