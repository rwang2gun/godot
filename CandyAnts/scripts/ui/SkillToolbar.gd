class_name SkillToolbar extends CanvasLayer

const GameAction := preload("res://scripts/input/GameAction.gd")
const CLICK_RADIUS: float = 32.0
const _SLOT_ACTIONS: Array[StringName] = GameAction.SKILL_SELECT_BY_SLOT

# 8 스킬 아이콘 preload — btn.icon + custom mouse cursor 양쪽에 재사용.
# SVG는 Godot 4가 ImageTexture로 자동 임포트 → Texture2D로 바로 사용.
const ICONS: Dictionary = {
	"blocker": preload("res://assets/icons/skills/blocker.svg"),
	"builder": preload("res://assets/icons/skills/builder.svg"),
	"climber": preload("res://assets/icons/skills/climber.svg"),
	"basher": preload("res://assets/icons/skills/basher.svg"),
	"digger": preload("res://assets/icons/skills/digger.svg"),
	"miner": preload("res://assets/icons/skills/miner.svg"),
	"floater": preload("res://assets/icons/skills/floater.svg"),
	"bomber": preload("res://assets/icons/skills/bomber.svg"),
}
# 커서 hotspot — 아이콘 중앙. SVG는 64×64로 임포트되지만 OS 마우스 커서로
# 다운스케일되어 표시. hotspot은 텍스처 좌표계 기준이므로 절반값 사용.
const CURSOR_HOTSPOT: Vector2 = Vector2(32, 32)

@export var stage_data: StageData = null
@export var hbox_path: NodePath

var _pending_skill_id: String = ""
var _inventory: Dictionary = {}     # id (String) → count (int)
var _buttons: Dictionary = {}       # id (String) → Button

# 슬롯 버튼 한정 stylebox — 글로벌 theme(theme/candyants.tres)은 본 phase에서 비편집
# (사용자가 art 자산을 별도 편집 중). 본 함수가 만든 stylebox는 add_theme_stylebox_override
# 로 버튼 단위 적용. normal/hover와 pressed의 시각 대비를 크게 잡아 토글 유지 상태가
# 한눈에 보이도록 함 (peach_500 → mint_500 contrast + 5px border).
func _make_normal_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Tokens.PEACH_500
	s.border_color = Tokens.INK_900
	s.set_border_width_all(3)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(4)
	return s

func _make_hover_style() -> StyleBoxFlat:
	var s := _make_normal_style()
	s.bg_color = Tokens.PEACH_300
	return s

func _make_pressed_style() -> StyleBoxFlat:
	# 선택된 슬롯 표시 — mint contrast + 굵은 border + ink_900 shadow 느낌으로 명확히.
	var s := StyleBoxFlat.new()
	s.bg_color = Tokens.MINT_500
	s.border_color = Tokens.INK_900
	s.set_border_width_all(5)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(4)
	return s

func _make_disabled_style() -> StyleBoxFlat:
	var s := _make_normal_style()
	s.bg_color = Tokens.CREAM_300
	return s

func _ready() -> void:
	if stage_data == null:
		push_warning("[SkillToolbar] stage_data null — toolbar empty")
		return
	_inventory = stage_data.skill_inventory.duplicate(true)
	var hbox: Node = get_node_or_null(hbox_path)
	if hbox == null:
		push_error("[SkillToolbar] hbox_path missing")
		return
	for id: String in stage_data.available_skills:
		var count: int = int(_inventory.get(id, 0))
		var btn: Button = Button.new()
		btn.icon = ICONS.get(id) as Texture2D
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(88, 88)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.text = "× %d" % count
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.disabled = count <= 0
		btn.toggle_mode = true
		btn.add_theme_stylebox_override("normal", _make_normal_style())
		btn.add_theme_stylebox_override("hover", _make_hover_style())
		btn.add_theme_stylebox_override("pressed", _make_pressed_style())
		btn.add_theme_stylebox_override("hover_pressed", _make_pressed_style())
		btn.add_theme_stylebox_override("disabled", _make_disabled_style())
		var captured_id: String = id
		btn.pressed.connect(func() -> void: _on_button_pressed(captured_id))
		hbox.add_child(btn)
		_buttons[id] = btn
	# 기존 _unhandled_input 분기 제거 — phase 5는 우클릭 → InputMap "skill_cancel" 액션 →
	# EventBus.action_triggered(SKILL_CANCEL) 경로로 대체. Esc는 phase 5 InputMap 미등록
	# (phase 12에서 game state 분기와 함께 추가).
	EventBus.action_triggered.connect(_on_action)

func _exit_tree() -> void:
	# Toolbar가 사라질 때(stage 전환, scene reload) OS 커서가 마지막 스킬 아이콘으로
	# 남는 것을 방지 — 멱등.
	Input.set_custom_mouse_cursor(null)

func _on_action(name: StringName, payload: Dictionary) -> void:
	match name:
		GameAction.SKILL_ASSIGN:
			if not payload.get("position_valid", false):
				return
			_try_assign(payload.get("world_pos", Vector2.ZERO))
		GameAction.SKILL_CANCEL:
			_clear_selection()
		GameAction.SKILL_CYCLE_NEXT:
			_cycle(+1)
		GameAction.SKILL_CYCLE_PREV:
			_cycle(-1)
		_:
			var slot_idx: int = _SLOT_ACTIONS.find(name)
			if slot_idx >= 0:
				_select_by_slot(slot_idx)

func _on_button_pressed(id: String) -> void:
	# Button.toggle_mode → click 시 button_pressed가 자동 토글된 뒤 pressed signal 발화.
	# 본 핸들러는 toggle 결과와 무관하게 _pending_skill_id 기준으로 최종 상태를 명시 결정
	# (slot select / cycle / SKILL_CANCEL 경로와 통일된 toggle 로직).
	var count: int = int(_inventory.get(id, 0))
	if count <= 0:
		# disabled 버튼이 클릭됐을 때(disabled=true는 클릭 차단하지만, count 0인데
		# 활성 상태로 남은 race condition 대비) — 토글 상태 원복.
		_buttons[id].set_pressed_no_signal(false)
		return
	if _pending_skill_id == id:
		_clear_selection()
		return
	_select(id)

func _select(id: String) -> void:
	# 다른 슬롯 토글 해제 → 새 슬롯 토글 → 커서 교체. _pending_skill_id는 항상 단일 source.
	if _pending_skill_id != "" and _buttons.has(_pending_skill_id):
		_buttons[_pending_skill_id].set_pressed_no_signal(false)
	_pending_skill_id = id
	if _buttons.has(id):
		_buttons[id].set_pressed_no_signal(true)
	var icon: Texture2D = ICONS.get(id) as Texture2D
	if icon != null:
		Input.set_custom_mouse_cursor(icon, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
	print("[SkillToolbar] pending=", id)

func _clear_selection() -> void:
	# pending 해제 + 모든 버튼 토글 off + OS 커서 복원. 멱등.
	if _pending_skill_id != "" and _buttons.has(_pending_skill_id):
		_buttons[_pending_skill_id].set_pressed_no_signal(false)
	_pending_skill_id = ""
	Input.set_custom_mouse_cursor(null)

func _try_assign(world: Vector2) -> void:
	if _pending_skill_id == "":
		return
	var ant: Ant = _find_closest_ant(world)
	if ant == null:
		return
	var skill_script: Script = SkillRegistry.get_skill(_pending_skill_id)
	if skill_script == null:
		_clear_selection()
		return
	var skill: Skill = skill_script.new() as Skill
	if skill == null or not skill.can_apply(ant):
		# 인벤토리는 차감하지 않음 (Codex review 권고: failed can_apply)
		_clear_selection()
		return
	var applied_id: String = _pending_skill_id
	skill.apply(ant)
	_inventory[applied_id] = int(_inventory[applied_id]) - 1
	_refresh_button(applied_id)
	print("[SkillToolbar] applied=", applied_id, " to=", ant.name, " remaining=", _inventory[applied_id])
	_clear_selection()

func _select_by_slot(slot_idx: int) -> void:
	if stage_data == null:
		return
	if slot_idx < 0 or slot_idx >= stage_data.available_skills.size():
		return  # 슬롯 부재 → noop (소리/UI 거절은 phase 10 폴리싱)
	var id: String = stage_data.available_skills[slot_idx]
	_on_button_pressed(id)

func _cycle(step: int) -> void:
	if stage_data == null or stage_data.available_skills.is_empty():
		return
	var ids: Array = stage_data.available_skills
	var cur: int = ids.find(_pending_skill_id) if _pending_skill_id != "" else -1
	var next_idx: int = posmod(cur + step, ids.size())
	_on_button_pressed(ids[next_idx])

func _find_closest_ant(world: Vector2) -> Ant:
	var ants: Array = get_tree().get_nodes_in_group("ants")
	var closest: Ant = null
	var best: float = CLICK_RADIUS
	for n in ants:
		var a: Ant = n as Ant
		if a == null:
			continue
		var d: float = a.global_position.distance_to(world)
		if d < best:
			best = d
			closest = a
	return closest

func _refresh_button(id: String) -> void:
	var btn: Button = _buttons.get(id) as Button
	if btn == null:
		return
	var count: int = int(_inventory.get(id, 0))
	btn.text = "× %d" % count
	btn.disabled = count <= 0
