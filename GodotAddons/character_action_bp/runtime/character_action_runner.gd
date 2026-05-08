class_name CharacterActionRunner
extends Node

signal branch_executed(branch: CharacterActionBranch)

enum EvaluationMode {
	MANUAL,
	PHYSICS_PROCESS,
	PROCESS,
}

@export var actor_path: NodePath = ^".."
@export var state_machine_path: NodePath
@export var blueprint: CharacterActionBlueprint
@export var evaluation_mode: EvaluationMode = EvaluationMode.MANUAL:
	set(value):
		evaluation_mode = value
		_update_processing()
@export var context: Dictionary = {}

var actor: Node = null
var state_machine: Node = null

func _ready() -> void:
	_resolve_nodes()
	_update_processing()

func _process(_delta: float) -> void:
	if evaluation_mode == EvaluationMode.PROCESS:
		evaluate()

func _physics_process(_delta: float) -> void:
	if evaluation_mode == EvaluationMode.PHYSICS_PROCESS:
		evaluate()

func evaluate(extra_context: Dictionary = {}) -> bool:
	if blueprint == null:
		return false
	if actor == null or (actor_path != NodePath() and not is_instance_valid(actor)):
		_resolve_nodes()
	var merged_context := context.duplicate(true)
	for key: Variant in extra_context:
		merged_context[key] = extra_context[key]
	var state_name := blueprint._current_state_name(actor, state_machine)
	var branch := blueprint.find_branch(actor, state_name, merged_context)
	var did_execute := blueprint.execute(actor, state_machine, merged_context)
	if did_execute and branch != null:
		branch_executed.emit(branch)
	return did_execute

func _resolve_nodes() -> void:
	actor = get_node_or_null(actor_path)
	state_machine = get_node_or_null(state_machine_path)
	if state_machine == null and actor != null:
		var property_name := &"state_machine"
		if blueprint != null:
			property_name = blueprint.state_machine_property
		state_machine = actor.get(property_name) as Node

func _update_processing() -> void:
	if not is_inside_tree():
		return
	set_process(evaluation_mode == EvaluationMode.PROCESS)
	set_physics_process(evaluation_mode == EvaluationMode.PHYSICS_PROCESS)
