extends Node

# Phase 10 — UI atoms 헤드리스 검증.
# 4 atom 인스턴스화 + property 변경 + tween 생성 + Counter kill guard (H-1) + Chip API.

const _CBUTTON_SCENE := preload("res://scenes/ui/atoms/CButton.tscn")
const _CHIP_SCENE    := preload("res://scenes/ui/atoms/Chip.tscn")
const _COUNTER_SCENE := preload("res://scenes/ui/atoms/Counter.tscn")
const _SKILLSLOT_SCENE := preload("res://scenes/ui/atoms/SkillSlot.tscn")

func _ready() -> void:
	var failures: Array[String] = []

	# --- CButton ---
	var cb: CButton = _CBUTTON_SCENE.instantiate()
	add_child(cb)
	await get_tree().process_frame
	if not (cb is CButton):
		failures.append("CButton scene root is not CButton")
	# kind 전환 — PRIMARY default, SECONDARY/GHOST override 동작
	cb.kind = CButton.ButtonKind.SECONDARY
	await get_tree().process_frame
	if not cb.has_theme_stylebox_override("normal"):
		failures.append("CButton SECONDARY did not apply stylebox override")
	cb.kind = CButton.ButtonKind.PRIMARY
	await get_tree().process_frame
	if cb.has_theme_stylebox_override("normal"):
		failures.append("CButton PRIMARY did not clear stylebox override")
	# R1-M4 fix: pressed 시 _boop_tween 실제 valid 검증 (kill guard도 동작 확인)
	cb.emit_signal("pressed")
	await get_tree().process_frame
	var boop1: Tween = cb._boop_tween
	if boop1 == null or not boop1.is_valid():
		failures.append("CButton pressed did not create _boop_tween (got null or invalid)")
	cb.emit_signal("pressed")
	await get_tree().process_frame
	var boop2: Tween = cb._boop_tween
	if boop2 == boop1:
		failures.append("CButton boop tween not replaced on rapid press (kill guard FAILED)")
	if boop1 != null and boop1.is_valid():
		failures.append("CButton prior boop tween still valid after second press — kill guard FAILED")
	# R2-M1 fix: rapid-press final-position regression — drift 0 보장
	# 이전 boop 잔여 tween이 완료될 때까지 충분히 대기 후 baseline capture (mid-bounce 캡처 방지)
	for i in 20:
		await get_tree().process_frame
	var cb_base_pos: Vector2 = cb.position
	for i in 5:
		cb.emit_signal("pressed")
		await get_tree().process_frame
	# boop 완료까지 충분히 대기 (120ms tween + 여유)
	for i in 20:
		await get_tree().process_frame
	if not cb.position.is_equal_approx(cb_base_pos):
		failures.append("CButton position drifted after 5 rapid presses — got " + str(cb.position) + " vs base " + str(cb_base_pos))

	# --- Chip ---
	var chip: Chip = _CHIP_SCENE.instantiate()
	add_child(chip)
	await get_tree().process_frame
	chip.set_label_value("귀가", "8")
	await get_tree().process_frame
	if chip.label != "귀가" or chip.value != "8":
		failures.append("Chip.set_label_value did not update fields (label=%s, value=%s)" % [chip.label, chip.value])
	# tint 전환
	chip.tint = Tokens.TintKind.MINT
	await get_tree().process_frame
	# atom-local stylebox이 적용되어 있어야 함
	if not chip.get_node("MainPanel").has_theme_stylebox_override("panel"):
		failures.append("Chip MINT tint did not apply panel stylebox")

	# --- Counter (H-1 kill guard 검증) ---
	var ctr: Counter = _COUNTER_SCENE.instantiate()
	ctr.kind = Tokens.CounterKind.SAVED
	ctr.top_label_en = "saved"
	ctr.bottom_label_ko = "귀가"
	add_child(ctr)
	await get_tree().process_frame
	ctr.set_value(1)
	await get_tree().process_frame
	var first_tween: Tween = ctr._capop_tween
	if first_tween == null or not first_tween.is_valid():
		failures.append("Counter.set_value did not create caPop tween")
	# 연속 호출 — 이전 tween이 kill되고 새 tween이 들어가야 함
	ctr.set_value(2)
	await get_tree().process_frame
	var second_tween: Tween = ctr._capop_tween
	if second_tween == first_tween:
		failures.append("Counter.set_value did not replace tween on rapid call")
	if first_tween != null and first_tween.is_valid():
		failures.append("Counter prior caPop tween still valid after set_value(2) — kill guard FAILED")

	# --- SkillSlot ---
	var slot: SkillSlot = _SKILLSLOT_SCENE.instantiate()
	slot.skill_id = &"blocker"
	slot.hotkey = "1"
	slot.ko_label = "차단"
	add_child(slot)
	await get_tree().process_frame
	slot.set_count(3)
	await get_tree().process_frame
	if not slot.get_node("MainBG/CountBadge").visible:
		failures.append("SkillSlot CountBadge not visible after set_count(3)")
	# selected 토글
	slot.set_selected(true)
	await get_tree().process_frame
	var mainbg_box := slot.get_node("MainBG").get_theme_stylebox("panel") as StyleBoxFlat
	if mainbg_box == null or not mainbg_box.bg_color.is_equal_approx(Tokens.PEACH_300):
		failures.append("SkillSlot selected did not apply peach_300 bg")
	# R1-M2 fix: pressed-without-selected (transient button-down) 도 peach_300
	slot.set_selected(false)
	slot._on_button_down()
	await get_tree().process_frame
	var pressed_box := slot.get_node("MainBG").get_theme_stylebox("panel") as StyleBoxFlat
	if pressed_box == null or not pressed_box.bg_color.is_equal_approx(Tokens.PEACH_300):
		failures.append("SkillSlot pressed-without-selected did not apply peach_300 bg")
	slot._on_button_up()
	await get_tree().process_frame
	var released_box := slot.get_node("MainBG").get_theme_stylebox("panel") as StyleBoxFlat
	if released_box == null or not released_box.bg_color.is_equal_approx(Tokens.CREAM_100):
		failures.append("SkillSlot released-from-pressed did not revert to cream_100 (got bg=" + str(released_box.bg_color) + ")")
	# R2-M1 fix: SkillSlot/MainBG rapid-press final-position regression
	slot.set_count(5)
	# 이전 boop 잔여 tween 완료까지 대기 후 baseline capture
	for i in 20:
		await get_tree().process_frame
	var main_bg_base: Vector2 = slot._main_bg.position
	for i in 5:
		slot._on_button_down()
		await get_tree().process_frame
	slot._on_button_up()
	for i in 20:
		await get_tree().process_frame
	if not slot._main_bg.position.is_equal_approx(main_bg_base):
		failures.append("SkillSlot/MainBG position drifted after 5 rapid button_downs — got " + str(slot._main_bg.position) + " vs base " + str(main_bg_base))
	# empty 상태 (count=0) — clickable이지만 faded
	slot.set_selected(false)
	slot.set_count(0)
	await get_tree().process_frame
	if abs(slot.get_node("MainBG").self_modulate.a - 0.55) > 0.01:
		failures.append("SkillSlot empty (count=0) did not fade MainBG.self_modulate.a")
	if slot.disabled:
		failures.append("SkillSlot empty should be clickable (disabled=false), got disabled=true")
	if slot.get_node("MainBG/CountBadge").visible:
		failures.append("SkillSlot CountBadge should hide on count=0 (got visible=true)")

	# --- 결과 ---
	if failures.size() > 0:
		push_error("AtomShowcaseHeadless FAIL: " + str(failures))
		print("[AtomShowcaseHeadless] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[AtomShowcaseHeadless] PASS — 4 atoms instantiated, Counter kill guard works, Chip API works")
		get_tree().quit(0)
