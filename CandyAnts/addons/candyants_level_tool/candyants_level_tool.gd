@tool
extends EditorPlugin

const LevelToolDock := preload("res://addons/candyants_level_tool/level_tool_dock.gd")
const MENU_ITEM := "CandyAnts Level Tool"

var _dock: Control = null          # 패널에 붙는 ScrollContainer (긴 폼이 잘리지 않도록)
var _tool: Control = null          # 실제 레벨 툴 VBox
var _bottom_button: Button = null

func _enter_tree() -> void:
	_tool = LevelToolDock.new()
	_tool.editor_interface = get_editor_interface()
	_tool.dirty_changed.connect(_on_dock_dirty_changed)
	_tool.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 폼이 패널 높이보다 길어도 세로 스크롤로 전부 접근 가능하게 감싼다.
	_dock = ScrollContainer.new()
	_dock.name = "CandyAnts Level"
	_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dock.add_child(_tool)

	_bottom_button = add_control_to_bottom_panel(_dock, "CandyAnts Level")
	add_tool_menu_item(MENU_ITEM, _show_level_tool)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
	_tool = null
	_bottom_button = null

func _show_level_tool() -> void:
	if _dock != null:
		make_bottom_panel_item_visible(_dock)

func _on_dock_dirty_changed(is_dirty: bool) -> void:
	if _bottom_button != null:
		_bottom_button.text = "CandyAnts Level *" if is_dirty else "CandyAnts Level"
