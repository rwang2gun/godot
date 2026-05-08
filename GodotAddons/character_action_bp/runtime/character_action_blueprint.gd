class_name CharacterActionBlueprint
extends Resource

@export var branches: Array[CharacterActionBranch] = []
@export var default_action_script: GDScript = null
@export var default_action_method: StringName = &""
@export var default_target_state_script: GDScript = null
@export var default_target_state_name: StringName = &""
@export_group("State Resolution")
@export var actor_state_method: StringName = &"get_state_name"
@export var actor_state_property: NodePath
@export var state_machine_property: StringName = &"state_machine"
@export var state_machine_current_state_property: StringName = &"current_state"
@export var state_object_name_property: StringName = &"state_name"
@export_group("State Transition")
@export var state_change_method: StringName = &"change_state"
@export var state_change_by_name_method: StringName = &"change_state_by_name"

func find_branch(actor: Node, state_name: StringName, context: Dictionary = {}) -> CharacterActionBranch:
	for branch: CharacterActionBranch in branches:
		if branch != null and branch.matches(actor, state_name, context):
			return branch
	return null

func execute(actor: Node, state_machine: Node = null, context: Dictionary = {}) -> bool:
	var current_state_name := _current_state_name(actor, state_machine)
	var branch := find_branch(actor, current_state_name, context)
	if branch != null:
		return branch.execute(actor, state_machine, context)
	if default_action_script != null:
		_run_script(default_action_script, actor, state_machine, context)
		return true
	if default_action_method != &"" and actor != null and actor.has_method(default_action_method):
		actor.call(default_action_method)
		return true
	if default_target_state_script != null:
		_change_state(default_target_state_script, actor, state_machine)
		return true
	if default_target_state_name != &"":
		return _change_state_by_name(default_target_state_name, actor, state_machine)
	return false

func _current_state_name(actor: Node, state_machine: Node) -> StringName:
	if actor != null:
		if actor_state_property != NodePath():
			var actor_state_value: Variant = actor.get_indexed(actor_state_property)
			if actor_state_value != null:
				return StringName(str(actor_state_value))
		if actor_state_method != &"" and actor.has_method(actor_state_method):
			return StringName(str(actor.call(actor_state_method)))
	var machine := state_machine
	if machine == null and actor != null:
		machine = actor.get(state_machine_property) as Node
	if machine != null:
		var current_state: Variant = machine.get(state_machine_current_state_property)
		if current_state != null:
			if not current_state is Object:
				return StringName(str(current_state))
			var named_state: Variant = current_state.get(state_object_name_property)
			if named_state != null:
				return StringName(str(named_state))
			var script: Script = current_state.get_script()
			if script != null:
				var global_name: String = script.get_global_name()
				if global_name != "":
					return StringName(global_name)
			return StringName(current_state.get_class())
	return &""

func _run_script(script: GDScript, actor: Node, state_machine: Node, context: Dictionary) -> void:
	var action := script.new()
	if action.has_method("apply"):
		action.call("apply", actor)
	elif action.has_method("execute"):
		action.call("execute", actor, state_machine, context)

func _change_state(script: GDScript, actor: Node, state_machine: Node) -> void:
	var machine := state_machine
	if machine == null and actor != null:
		machine = actor.get(state_machine_property) as Node
	if machine != null and state_change_method != &"" and machine.has_method(state_change_method):
		var state := script.new()
		machine.call(state_change_method, state)

func _change_state_by_name(state_name: StringName, actor: Node, state_machine: Node) -> bool:
	var machine := state_machine
	if machine == null and actor != null:
		machine = actor.get(state_machine_property) as Node
	if machine != null and state_change_by_name_method != &"" and machine.has_method(state_change_by_name_method):
		machine.call(state_change_by_name_method, state_name)
		return true
	if actor != null and state_change_by_name_method != &"" and actor.has_method(state_change_by_name_method):
		actor.call(state_change_by_name_method, state_name)
		return true
	return false
