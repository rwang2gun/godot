@tool
extends EditorPlugin

const LevelToolDock := preload("res://addons/candyants_level_tool/level_tool_dock.gd")
const MENU_ITEM := "CandyAnts Level Tool"

var _dock: Control = null
var _bottom_button: Button = null

func _enter_tree() -> void:
	_dock = LevelToolDock.new()
	_dock.editor_interface = get_editor_interface()
	_dock.dirty_changed.connect(_on_dock_dirty_changed)
	_bottom_button = add_control_to_bottom_panel(_dock, "CandyAnts Level")
	add_tool_menu_item(MENU_ITEM, _show_level_tool)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
	_bottom_button = null

func _show_level_tool() -> void:
	if _dock != null:
		make_bottom_panel_item_visible(_dock)

func _on_dock_dirty_changed(is_dirty: bool) -> void:
	if _bottom_button != null:
		_bottom_button.text = "CandyAnts Level *" if is_dirty else "CandyAnts Level"
