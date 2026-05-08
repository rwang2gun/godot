@tool
extends EditorPlugin

const DockScene := preload("res://addons/character_action_bp/editor/character_action_bp_dock.gd")

var _dock: Control = null

func _enter_tree() -> void:
	_dock = DockScene.new()
	_dock.plugin = self
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	add_custom_type(
		"CharacterActionRunner",
		"Node",
		preload("res://addons/character_action_bp/runtime/character_action_runner.gd"),
		null
	)

func _exit_tree() -> void:
	remove_custom_type("CharacterActionRunner")
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
