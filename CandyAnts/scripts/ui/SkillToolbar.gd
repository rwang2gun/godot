class_name SkillToolbar extends CanvasLayer

const GameAction := preload("res://scripts/input/GameAction.gd")
const CLICK_RADIUS: float = 32.0
const _SLOT_ACTIONS: Array[StringName] = GameAction.SKILL_SELECT_BY_SLOT

@export var stage_data: StageData = null
@export var hbox_path: NodePath

var _pending_skill_id: String = ""
var _inventory: Dictionary = {}     # id (String) → count (int)
var _buttons: Dictionary = {}       # id (String) → Button

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
		btn.text = "%s × %d" % [id, count]
		btn.disabled = count <= 0
		var captured_id: String = id
		btn.pressed.connect(func() -> void: _on_button_pressed(captured_id))
		hbox.add_child(btn)
		_buttons[id] = btn
	# 기존 _unhandled_input 분기 제거 — phase 5는 우클릭 → InputMap "skill_cancel" 액션 →
	# EventBus.action_triggered(SKILL_CANCEL) 경로로 대체. Esc는 phase 5 InputMap 미등록
	# (phase 12에서 game state 분기와 함께 추가).
	EventBus.action_triggered.connect(_on_action)

func _on_action(name: StringName, payload: Dictionary) -> void:
	match name:
		GameAction.SKILL_ASSIGN:
			if not payload.get("position_valid", false):
				return
			_try_assign(payload.get("world_pos", Vector2.ZERO))
		GameAction.SKILL_CANCEL:
			_pending_skill_id = ""
		GameAction.SKILL_CYCLE_NEXT:
			_cycle(+1)
		GameAction.SKILL_CYCLE_PREV:
			_cycle(-1)
		_:
			var slot_idx: int = _SLOT_ACTIONS.find(name)
			if slot_idx >= 0:
				_select_by_slot(slot_idx)

func _on_button_pressed(id: String) -> void:
	var count: int = int(_inventory.get(id, 0))
	if count <= 0:
		return
	_pending_skill_id = id
	print("[SkillToolbar] pending=", id)

func _try_assign(world: Vector2) -> void:
	if _pending_skill_id == "":
		return
	var ant: Ant = _find_closest_ant(world)
	if ant == null:
		return
	var skill_script: Script = SkillRegistry.get_skill(_pending_skill_id)
	if skill_script == null:
		_pending_skill_id = ""
		return
	var skill: Skill = skill_script.new() as Skill
	if skill == null or not skill.can_apply(ant):
		# 인벤토리는 차감하지 않음 (Codex review 권고: failed can_apply)
		_pending_skill_id = ""
		return
	skill.apply(ant)
	_inventory[_pending_skill_id] = int(_inventory[_pending_skill_id]) - 1
	_refresh_button(_pending_skill_id)
	print("[SkillToolbar] applied=", _pending_skill_id, " to=", ant.name, " remaining=", _inventory[_pending_skill_id])
	_pending_skill_id = ""

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
	btn.text = "%s × %d" % [id, count]
	btn.disabled = count <= 0
