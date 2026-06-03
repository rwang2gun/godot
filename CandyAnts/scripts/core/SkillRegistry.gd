extends Node

const SKILL_SCRIPTS: Array[Script] = [
	preload("res://scripts/skills/BuilderSkill.gd"),
	preload("res://scripts/skills/BlockerSkill.gd"),
	preload("res://scripts/skills/ClimberSkill.gd"),
	preload("res://scripts/skills/FloaterSkill.gd"),
	preload("res://scripts/skills/SandMoundSkill.gd"),
	preload("res://scripts/skills/BridgeSkill.gd"),
	preload("res://scripts/skills/BasherSkill.gd"),
	preload("res://scripts/skills/DiggerSkill.gd"),
	preload("res://scripts/skills/CutterSkill.gd"),
]

var _skills: Dictionary = {}

func _ready() -> void:
	for script: Script in SKILL_SCRIPTS:
		var id: String = script.ID
		assert(id != "", "Skill subclass must define const ID")
		assert(not _skills.has(id), "Duplicate skill ID: %s" % id)
		_skills[id] = script

func get_skill(id: String) -> Script:
	return _skills.get(id)

func validate_stage(stage: Resource) -> Array[String]:
	var errors: Array[String] = []
	if stage == null:
		return errors
	if "available_skills" in stage:
		for id: String in stage.available_skills:
			if not _skills.has(id):
				errors.append("Unknown skill in available_skills: %s" % id)
	if "skill_inventory" in stage:
		for id: String in stage.skill_inventory.keys():
			if not _skills.has(id):
				errors.append("Unknown skill in skill_inventory: %s" % id)
	return errors
