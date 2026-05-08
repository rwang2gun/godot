@tool
extends VBoxContainer

const BlueprintScript := preload("res://addons/character_action_bp/runtime/character_action_blueprint.gd")
const BranchScript := preload("res://addons/character_action_bp/runtime/character_action_branch.gd")

var plugin: EditorPlugin = null
var blueprint: CharacterActionBlueprint = null

var _path_edit: LineEdit
var _branch_list: ItemList
var _state_edit: LineEdit
var _name_edit: LineEdit
var _action_method_edit: LineEdit
var _target_state_name_edit: LineEdit
var _enabled_check: CheckBox
var _action_picker: EditorResourcePicker
var _state_picker: EditorResourcePicker
var _selected_index: int = -1

func _init() -> void:
	name = "Character BP"
	custom_minimum_size = Vector2(320, 360)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "Character Action BP"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var path_row := HBoxContainer.new()
	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "res://data/action_bp/player.tres"
	_path_edit.text = "res://data/action_bp/player.tres"
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(_path_edit)
	var new_button := Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_on_new_pressed)
	path_row.add_child(new_button)
	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_on_load_pressed)
	path_row.add_child(load_button)
	add_child(path_row)

	var save_button := Button.new()
	save_button.text = "Save Blueprint"
	save_button.pressed.connect(_on_save_pressed)
	add_child(save_button)

	_branch_list = ItemList.new()
	_branch_list.custom_minimum_size = Vector2(0, 120)
	_branch_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_branch_list.item_selected.connect(_on_branch_selected)
	add_child(_branch_list)

	var branch_buttons := HBoxContainer.new()
	var add_button := Button.new()
	add_button.text = "Add Branch"
	add_button.pressed.connect(_on_add_branch_pressed)
	branch_buttons.add_child(add_button)
	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_on_remove_branch_pressed)
	branch_buttons.add_child(remove_button)
	add_child(branch_buttons)

	_name_edit = _make_line("Name")
	_name_edit.text_changed.connect(_on_branch_field_changed)
	_state_edit = _make_line("State")
	_state_edit.placeholder_text = "Idle"
	_state_edit.text_changed.connect(_on_branch_field_changed)
	_enabled_check = CheckBox.new()
	_enabled_check.text = "Enabled"
	_enabled_check.toggled.connect(_on_enabled_toggled)
	add_child(_enabled_check)

	_action_method_edit = _make_line("Actor Method")
	_action_method_edit.placeholder_text = "jump"
	_action_method_edit.text_changed.connect(_on_branch_field_changed)

	_target_state_name_edit = _make_line("Target State Name")
	_target_state_name_edit.placeholder_text = "Running"
	_target_state_name_edit.text_changed.connect(_on_branch_field_changed)

	add_child(_make_label("Action Script"))
	_action_picker = EditorResourcePicker.new()
	_action_picker.base_type = "GDScript"
	_action_picker.resource_changed.connect(_on_action_changed)
	add_child(_action_picker)

	add_child(_make_label("Target State Script"))
	_state_picker = EditorResourcePicker.new()
	_state_picker.base_type = "GDScript"
	_state_picker.resource_changed.connect(_on_target_state_changed)
	add_child(_state_picker)

	var hint := RichTextLabel.new()
	hint.bbcode_enabled = true
	hint.fit_content = true
	hint.text = "[i]Branches run top to bottom. Use Resource Inspector to add conditions or action arguments.[/i]"
	add_child(hint)
	_refresh()

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _make_line(label_text: String) -> LineEdit:
	add_child(_make_label(label_text))
	var line := LineEdit.new()
	add_child(line)
	return line

func _on_new_pressed() -> void:
	blueprint = BlueprintScript.new()
	_selected_index = -1
	_refresh()

func _on_load_pressed() -> void:
	var path := _path_edit.text.strip_edges()
	if path == "":
		return
	var loaded := ResourceLoader.load(path)
	if loaded is CharacterActionBlueprint:
		blueprint = loaded
		_selected_index = -1
		_refresh()
	else:
		push_warning("[CharacterActionBP] Not a CharacterActionBlueprint: %s" % path)

func _on_save_pressed() -> void:
	if blueprint == null:
		blueprint = BlueprintScript.new()
	var path := _path_edit.text.strip_edges()
	if path == "":
		push_warning("[CharacterActionBP] Enter a res:// path before saving.")
		return
	_ensure_resource_dir(path)
	var err := ResourceSaver.save(blueprint, path)
	if err != OK:
		push_error("[CharacterActionBP] Save failed: %s" % error_string(err))
	elif plugin != null:
		plugin.get_editor_interface().get_resource_filesystem().scan()

func _ensure_resource_dir(path: String) -> void:
	if not path.begins_with("res://"):
		return
	var directory := path.get_base_dir()
	if directory == "" or DirAccess.dir_exists_absolute(directory):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))

func _on_add_branch_pressed() -> void:
	if blueprint == null:
		blueprint = BlueprintScript.new()
	var branch := BranchScript.new()
	branch.name = "Branch %d" % (blueprint.branches.size() + 1)
	blueprint.branches.append(branch)
	_selected_index = blueprint.branches.size() - 1
	_refresh()

func _on_remove_branch_pressed() -> void:
	if blueprint == null or _selected_index < 0 or _selected_index >= blueprint.branches.size():
		return
	blueprint.branches.remove_at(_selected_index)
	_selected_index = min(_selected_index, blueprint.branches.size() - 1)
	_refresh()

func _on_branch_selected(index: int) -> void:
	_selected_index = index
	_refresh_fields()

func _on_branch_field_changed(_text: String) -> void:
	var branch := _selected_branch()
	if branch == null:
		return
	branch.name = _name_edit.text
	branch.source_state = StringName(_state_edit.text)
	branch.action_method = StringName(_action_method_edit.text)
	branch.target_state_name = StringName(_target_state_name_edit.text)
	_refresh_list_labels()

func _on_enabled_toggled(value: bool) -> void:
	var branch := _selected_branch()
	if branch != null:
		branch.enabled = value
		_refresh_list_labels()

func _on_action_changed(resource: Resource) -> void:
	var branch := _selected_branch()
	if branch != null:
		branch.action_script = resource as GDScript

func _on_target_state_changed(resource: Resource) -> void:
	var branch := _selected_branch()
	if branch != null:
		branch.target_state_script = resource as GDScript

func _selected_branch() -> CharacterActionBranch:
	if blueprint == null or _selected_index < 0 or _selected_index >= blueprint.branches.size():
		return null
	return blueprint.branches[_selected_index]

func _refresh() -> void:
	_refresh_list_labels()
	_refresh_fields()

func _refresh_list_labels() -> void:
	if _branch_list == null:
		return
	_branch_list.clear()
	if blueprint == null:
		return
	for index in blueprint.branches.size():
		var branch := blueprint.branches[index]
		var state_label := "*" if branch.source_state == &"" else str(branch.source_state)
		var enabled_label := "" if branch.enabled else " (disabled)"
		_branch_list.add_item("%s -> %s%s" % [state_label, branch.name, enabled_label])
	if _selected_index >= 0 and _selected_index < _branch_list.item_count:
		_branch_list.select(_selected_index)

func _refresh_fields() -> void:
	var branch := _selected_branch()
	var has_branch := branch != null
	_name_edit.editable = has_branch
	_state_edit.editable = has_branch
	_action_method_edit.editable = has_branch
	_target_state_name_edit.editable = has_branch
	_enabled_check.disabled = not has_branch
	_action_picker.editable = has_branch
	_state_picker.editable = has_branch
	if not has_branch:
		_name_edit.text = ""
		_state_edit.text = ""
		_action_method_edit.text = ""
		_target_state_name_edit.text = ""
		_enabled_check.button_pressed = false
		_action_picker.edited_resource = null
		_state_picker.edited_resource = null
		return
	_name_edit.text = branch.name
	_state_edit.text = str(branch.source_state)
	_action_method_edit.text = str(branch.action_method)
	_target_state_name_edit.text = str(branch.target_state_name)
	_enabled_check.button_pressed = branch.enabled
	_action_picker.edited_resource = branch.action_script
	_state_picker.edited_resource = branch.target_state_script
