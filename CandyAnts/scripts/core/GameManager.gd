extends Node

func _ready() -> void:
	print("[GameManager] ready")
	print("[GameManager] EventBus=", EventBus, " SkillRegistry=", SkillRegistry)
	var errors: Array[String] = SkillRegistry.validate_stage(null)
	assert(errors.is_empty(), "validate_stage(null) must return []")
	print("[GameManager] SkillRegistry.validate_stage(null) OK")
