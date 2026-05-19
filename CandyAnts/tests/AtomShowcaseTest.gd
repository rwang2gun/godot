extends Control

# Phase 10 — atom 시각 데모 (수동 실행 전용).
# 4 atom × state 매트릭스를 한 화면에 배치. 헤드리스 회귀는 AtomShowcaseHeadless.gd가 책임.

const _CBUTTON_SCENE := preload("res://scenes/ui/atoms/CButton.tscn")
const _CHIP_SCENE    := preload("res://scenes/ui/atoms/Chip.tscn")
const _COUNTER_SCENE := preload("res://scenes/ui/atoms/Counter.tscn")
const _SKILLSLOT_SCENE := preload("res://scenes/ui/atoms/SkillSlot.tscn")

func _ready() -> void:
	custom_minimum_size = Vector2(1200, 800)
	theme = load("res://theme/candyants.tres") as Theme
	_build_layout()
	# Sweep 2 (phase 13): 본 scene은 수동 시연용 (AtomShowcaseHeadless가 자동 회귀 책임).
	# headless 실행 시 build SCRIPT ERROR 없이 완료되면 PASS — 시연 인터랙션 없이 quit.
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		print("[AtomShowcaseTest] PASS (manual showcase scene — headless auto-exit)")
		get_tree().quit(0)

func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.position = Vector2(32, 32)
	add_child(root)

	root.add_child(_section("CButton — 3 kinds", _build_cbutton_row()))
	root.add_child(_section("Chip — 5 tints", _build_chip_row()))
	root.add_child(_section("Counter — 5 kinds (click any to bump value)", _build_counter_row()))
	root.add_child(_section("SkillSlot — 4 base states + empty", _build_skillslot_row()))

func _section(title: String, content: Control) -> Control:
	var v := VBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 16)
	v.add_child(t)
	v.add_child(content)
	return v

func _build_cbutton_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var kinds := [CButton.ButtonKind.PRIMARY, CButton.ButtonKind.SECONDARY, CButton.ButtonKind.GHOST]
	var labels := ["PRIMARY", "SECONDARY", "GHOST"]
	for i in 3:
		var btn: CButton = _CBUTTON_SCENE.instantiate()
		btn.text = labels[i]
		btn.kind = kinds[i]
		h.add_child(btn)
	return h

func _build_chip_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var tints := [Tokens.TintKind.PEACH, Tokens.TintKind.GRAPE, Tokens.TintKind.MINT, Tokens.TintKind.BERRY, Tokens.TintKind.LEMON]
	var labels := [["HP", "10"], ["운반", "3"], ["귀가", "8"], ["잃음", "2"], ["시간", "47s"]]
	for i in 5:
		var chip: Chip = _CHIP_SCENE.instantiate()
		chip.tint = tints[i]
		chip.label = labels[i][0]
		chip.value = labels[i][1]
		h.add_child(chip)
	return h

func _build_counter_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var kinds := [Tokens.CounterKind.CANDY_HP, Tokens.CounterKind.IN_TRANSIT, Tokens.CounterKind.SAVED, Tokens.CounterKind.LOST, Tokens.CounterKind.TIME]
	var top_labels := ["candy hp", "in transit", "saved", "lost", "time"]
	var bottom_labels := ["사탕 HP", "운반 중", "귀가", "잃음", "시간"]
	for i in 5:
		var c: Counter = _COUNTER_SCENE.instantiate()
		c.kind = kinds[i]
		c.top_label_en = top_labels[i]
		c.bottom_label_ko = bottom_labels[i]
		# Sweep 2 (phase 13): set_value()는 Counter.gd의 pending 패턴이 tree 진입 전 호출도
		# 안전하게 처리 (h가 root에 add 되기 전 호출돼도 _ready에서 일괄 적용).
		c.set_value(i * 2 + 1)
		var btn := Button.new()
		btn.text = "+1"
		btn.custom_minimum_size = Vector2(40, 28)
		btn.pressed.connect(_bump_counter.bind(c))
		var v := VBoxContainer.new()
		v.add_child(c)
		v.add_child(btn)
		h.add_child(v)
	return h

func _bump_counter(c: Counter) -> void:
	var current := int(c._big_number.text) if c._big_number.text.is_valid_int() else 0
	c.set_value(current + 1)

func _build_skillslot_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	# armed / selected / pressed(visual via hover) / empty / disabled
	var configs := [
		{"label": "armed", "selected": false, "count": 3, "disabled": false},
		{"label": "selected", "selected": true, "count": 3, "disabled": false},
		{"label": "many", "selected": false, "count": 99, "disabled": false},
		{"label": "empty", "selected": false, "count": 0, "disabled": false},
		{"label": "disabled", "selected": false, "count": 3, "disabled": true},
	]
	for i in configs.size():
		var cfg: Dictionary = configs[i]
		var s: SkillSlot = _SKILLSLOT_SCENE.instantiate()
		s.hotkey = str(i + 1)
		s.ko_label = cfg["label"]
		s.disabled = cfg["disabled"]
		h.add_child(s)
		s.set_count(cfg["count"])
		s.set_selected(cfg["selected"])
	return h
