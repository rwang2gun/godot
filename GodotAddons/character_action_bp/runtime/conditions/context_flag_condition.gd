class_name CharacterContextFlagCondition
extends CharacterActionCondition

@export var key: StringName
@export var expected: Variant = true

func evaluate(_actor: Node, context: Dictionary = {}) -> bool:
	if not context.has(key):
		return false
	return context[key] == expected
