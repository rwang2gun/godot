class_name CharacterActionBranch
extends Resource

@export var name: String = "Branch"
@export var source_state: StringName = &""
@export var conditions: Array[CharacterActionCondition] = []
@export var action_script: GDScript = null
@export var action_method: StringName = &""
@export var target_state_script: GDScript = null
@export var target_state_name: StringName = &""
@export var action_arguments: Dictionary = {}
@export var enabled: bool = true
@export_group("Integration")
@export var state_machine_property: StringName = &"state_machine"
@export var state_change_method: StringName = &"change_state"
@export var state_change_by_name_method: StringName = &"change_state_by_name"

func matches(actor: Node, state_name: StringName, context: Dictionary = {}) -> bool:
	if not enabled:
		return false
	if source_state != &"" and source_state != state_name:
		return false
	for condition: CharacterActionCondition in conditions:
		if condition != null and not condition.evaluate(actor, context):
			return false
	return true

func execute(actor: Node, state_machine: Node = null, context: Dictionary = {}) -> bool:
	var did_execute := false
	if action_script != null:
		var action := action_script.new()
		if action.has_method("set_arguments"):
			action.call("set_arguments", action_arguments)
		if action.has_method("apply"):
			action.call("apply", actor)
			did_execute = true
		elif action.has_method("execute"):
			action.call("execute", actor, state_machine, context)
			did_execute = true
		else:
			push_warning("[CharacterActionBP] Action script has no apply(actor) or execute(actor, state_machine, context).")
	if action_method != &"" and actor != null and actor.has_method(action_method):
		actor.callv(action_method, action_arguments.get("args", []))
		did_execute = true
	if target_state_script != null:
		var machine := state_machine
		if machine == null and actor != null:
			machine = actor.get(state_machine_property) as Node
		if machine != null and state_change_method != &"" and machine.has_method(state_change_method):
			machine.call(state_change_method, target_state_script.new())
			did_execute = true
	if target_state_name != &"":
		var machine := state_machine
		if machine == null and actor != null:
			machine = actor.get(state_machine_property) as Node
		if machine != null and state_change_by_name_method != &"" and machine.has_method(state_change_by_name_method):
			machine.call(state_change_by_name_method, target_state_name)
			did_execute = true
		elif actor != null and state_change_by_name_method != &"" and actor.has_method(state_change_by_name_method):
			actor.call(state_change_by_name_method, target_state_name)
			did_execute = true
	return did_execute
