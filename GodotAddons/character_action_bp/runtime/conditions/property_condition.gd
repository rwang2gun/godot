class_name CharacterPropertyCondition
extends CharacterActionCondition

enum Compare {
	EQUALS,
	NOT_EQUALS,
	GREATER_THAN,
	GREATER_OR_EQUAL,
	LESS_THAN,
	LESS_OR_EQUAL,
	IS_TRUE,
	IS_FALSE,
}

@export var property_path: NodePath
@export var compare: Compare = Compare.EQUALS
@export var expected: Variant = true

func evaluate(actor: Node, _context: Dictionary = {}) -> bool:
	if actor == null:
		return false
	var value: Variant = actor.get_indexed(property_path)
	match compare:
		Compare.EQUALS:
			return value == expected
		Compare.NOT_EQUALS:
			return value != expected
		Compare.GREATER_THAN:
			return value > expected
		Compare.GREATER_OR_EQUAL:
			return value >= expected
		Compare.LESS_THAN:
			return value < expected
		Compare.LESS_OR_EQUAL:
			return value <= expected
		Compare.IS_TRUE:
			return bool(value)
		Compare.IS_FALSE:
			return not bool(value)
	return false
