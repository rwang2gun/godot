extends Node

# Phase 4 (intro-card-infra) — StageIntroCard 표시/dismiss 검증. StageDialog 패턴 복제.
#   Case 1: show_intro → is_showing true → "시작" 버튼 → intro_dismissed 1회 → is_showing false.
#   Case 2: show_intro → Esc → intro_dismissed 1회 → is_showing false.

const IntroCardScene := preload("res://scenes/ui/StageIntroCard.tscn")

var _failed: bool = false
var _dismiss_count: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	await _case_start_button()
	if _failed: return
	await _case_esc()
	if _failed: return
	Engine.time_scale = 1.0
	print("[StageIntroCardShowTest] PASS")
	get_tree().quit(0)

func _make_card() -> StageIntroCard:
	var card: StageIntroCard = IntroCardScene.instantiate()
	add_child(card)
	await get_tree().process_frame
	return card

func _make_stage_data() -> StageData:
	var sd := StageData.new()
	sd.id = 1
	sd.display_name = "첫 마실"
	sd.available_skills = ["climber"] as Array[String]
	return sd

func _case_start_button() -> void:
	_dismiss_count = 0
	var card := await _make_card()
	card.intro_dismissed.connect(func() -> void: _dismiss_count += 1)
	if card.is_showing():
		_fail("start-case: card should start hidden")
		return
	card.show_intro(_make_stage_data())
	await get_tree().process_frame
	if not card.is_showing():
		_fail("start-case: card not showing after show_intro")
		return
	if card.shown_skill_ids() != (["climber"] as Array[String]):
		_fail("start-case: shown_skill_ids mismatch got %s" % str(card.shown_skill_ids()))
		return
	var btn := card.get_node("CardWrapper/Card/Main/Margin/VBox/ButtonRow/StartBtn") as CButton
	btn.pressed.emit()
	await _await_dismiss()
	if _dismiss_count != 1:
		_fail("start-case: intro_dismissed expected 1, got %d" % _dismiss_count)
		return
	if card.is_showing():
		_fail("start-case: card still showing after dismiss")
		return
	card.queue_free()
	await get_tree().process_frame

func _case_esc() -> void:
	_dismiss_count = 0
	var card := await _make_card()
	card.intro_dismissed.connect(func() -> void: _dismiss_count += 1)
	card.show_intro(_make_stage_data())
	await get_tree().process_frame
	_inject_esc()
	await _await_dismiss()
	if _dismiss_count != 1:
		_fail("esc-case: intro_dismissed expected 1, got %d" % _dismiss_count)
		return
	if card.is_showing():
		_fail("esc-case: card still showing after Esc")
		return
	card.queue_free()
	await get_tree().process_frame

func _await_dismiss() -> void:
	# fade_out 0.15s × time_scale 8 → ~0.02s sim. 안전 budget로 대기.
	var elapsed: float = 0.0
	while elapsed < 2.0 and _dismiss_count == 0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _inject_esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	var rel := InputEventKey.new()
	rel.keycode = KEY_ESCAPE
	rel.pressed = false
	Input.parse_input_event(rel)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	Engine.time_scale = 1.0
	print("[StageIntroCardShowTest] FAIL ", msg)
	get_tree().quit(1)
