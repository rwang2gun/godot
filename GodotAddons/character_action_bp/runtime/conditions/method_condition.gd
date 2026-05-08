class_name CharacterMethodCondition
extends CharacterActionCondition

@export var method_name: StringName
@export var expected: Variant = true
@export var arguments: Array = []

func evaluate(actor: Node, _context: Dictionary = {}) -> bool:
	if actor == null or method_name == &"" or not actor.has_method(method_name):
		return false
	return actor.callv(method_name, arguments) == expected
