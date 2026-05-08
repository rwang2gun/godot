class_name SkillToolbar extends CanvasLayer

const CLICK_RADIUS: float = 32.0

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

func _on_button_pressed(id: String) -> void:
	var count: int = int(_inventory.get(id, 0))
	if count <= 0:
		return
	_pending_skill_id = id
	print("[SkillToolbar] pending=", id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_pending_skill_id = ""
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _pending_skill_id == "":
		return
	# screen → world 변환
	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	var world: Vector2 = canvas_xform.affine_inverse() * mb.position
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
