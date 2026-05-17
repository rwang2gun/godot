class_name SkillToolbar extends CanvasLayer

# Phase 11 rewrite (plan v2 §4.1). 동적 Button.new() + stylebox override 제거 →
# SkillSlot atom 인스턴스화 + atom 메서드(set_count/set_selected/set_disabled_state) 호출.
# EventBus.action_triggered 구독 + 커스텀 마우스 커서 + _try_assign + _find_closest_ant는 무변경.
# group("skill_toolbars") 등록 폐기 (codex v1 HIGH-2: StageRunner direct ref로 라우팅).
# EventBus connect/disconnect lifecycle guard 추가 (codex v1 MED-3).

const GameAction := preload("res://scripts/input/GameAction.gd")
const SkillSlotScene: PackedScene = preload("res://scenes/ui/atoms/SkillSlot.tscn")
const CLICK_RADIUS: float = 32.0

# 8 스킬 아이콘 preload — SkillSlot.icon_texture + custom mouse cursor 양쪽에 재사용.
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
const KO_LABELS: Dictionary = {
	"climber": "등반",
	"floater": "낙하산",
	"bomber": "폭탄",
	"blocker": "차단",
	"builder": "계단",
	"basher": "굴착",
	"miner": "채굴",
	"digger": "땅파기",
}
const CURSOR_HOTSPOT: Vector2 = Vector2(32, 32)

@export var stage_data: StageData = null
@export var hbox_path: NodePath

var _pending_skill_id: String = ""
var _inventory: Dictionary = {}     # id (String) → count (int)
var _slots: Dictionary = {}         # id (String) → SkillSlot
var _all_disabled: bool = false

func _ready() -> void:
	if stage_data == null:
		push_warning("[SkillToolbar] stage_data null — toolbar empty")
		return
	_inventory = stage_data.skill_inventory.duplicate(true)
	var hbox: Node = get_node_or_null(hbox_path)
	if hbox == null:
		push_error("[SkillToolbar] hbox_path missing")
		return
	var i: int = 0
	for id: String in stage_data.available_skills:
		var slot: SkillSlot = SkillSlotScene.instantiate()
		slot.skill_id = StringName(id)
		slot.hotkey = str(i + 1)
		slot.ko_label = KO_LABELS.get(id, id)
		slot.icon_texture = ICONS.get(id) as Texture2D
		hbox.add_child(slot)
		slot.set_count(int(_inventory.get(id, 0)))
		var captured_id: String = id
		slot.pressed.connect(func() -> void: _on_slot_pressed(captured_id))
		_slots[id] = slot
		i += 1
	if not EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.connect(_on_action)

func _exit_tree() -> void:
	# Toolbar 해제 시 OS 커서가 마지막 스킬 아이콘으로 남는 것 방지 — 멱등.
	Input.set_custom_mouse_cursor(null)
	if EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.disconnect(_on_action)

# StageRunner._disable_toolbar가 직접 호출 (group lookup 폐기, codex v1 HIGH-2).
# SkillSlot.set_disabled_state 사용 — Button.disabled 직접 대입 금지 (alpha 0.55 visual refresh 보장).
func set_all_disabled(b: bool) -> void:
	_all_disabled = b
	for id: String in _slots:
		(_slots[id] as SkillSlot).set_disabled_state(b)
	if b:
		_clear_selection()

func _on_action(name: StringName, payload: Dictionary) -> void:
	if _all_disabled:
		return
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
			var slot_idx: int = GameAction.SKILL_SELECT_BY_SLOT.find(name)
			if slot_idx >= 0:
				_select_by_slot(slot_idx)

func _on_slot_pressed(id: String) -> void:
	var count: int = int(_inventory.get(id, 0))
	if count <= 0:
		# Phase 21(sound) sound hook 자리 — 현 phase 11에서는 noop.
		return
	if _pending_skill_id == id:
		_clear_selection()
		return
	_select(id)

func _select(id: String) -> void:
	# 다른 슬롯 selected off → 새 슬롯 selected on → 커스텀 커서 교체. _pending_skill_id 단일 SoT.
	if _pending_skill_id != "" and _slots.has(_pending_skill_id):
		(_slots[_pending_skill_id] as SkillSlot).set_selected(false)
	_pending_skill_id = id
	if _slots.has(id):
		(_slots[id] as SkillSlot).set_selected(true)
	var icon: Texture2D = ICONS.get(id) as Texture2D
	if icon != null:
		Input.set_custom_mouse_cursor(icon, Input.CURSOR_ARROW, CURSOR_HOTSPOT)
	print("[SkillToolbar] pending=", id)

func _clear_selection() -> void:
	if _pending_skill_id != "" and _slots.has(_pending_skill_id):
		(_slots[_pending_skill_id] as SkillSlot).set_selected(false)
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
		_clear_selection()
		return
	var applied_id: String = _pending_skill_id
	skill.apply(ant)
	_inventory[applied_id] = int(_inventory[applied_id]) - 1
	(_slots[applied_id] as SkillSlot).set_count(int(_inventory[applied_id]))
	print("[SkillToolbar] applied=", applied_id, " to=", ant.name, " remaining=", _inventory[applied_id])
	_clear_selection()

func _select_by_slot(slot_idx: int) -> void:
	if stage_data == null:
		return
	if slot_idx < 0 or slot_idx >= stage_data.available_skills.size():
		return
	_on_slot_pressed(stage_data.available_skills[slot_idx])

func _cycle(step: int) -> void:
	if stage_data == null or stage_data.available_skills.is_empty():
		return
	var ids: Array = stage_data.available_skills
	var cur: int = ids.find(_pending_skill_id) if _pending_skill_id != "" else -1
	var next_idx: int = posmod(cur + step, ids.size())
	_on_slot_pressed(ids[next_idx])

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
