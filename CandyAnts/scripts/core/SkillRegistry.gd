extends Node

const SKILL_SCRIPTS: Array[Script] = []

var _skills: Dictionary = {}

func _ready() -> void:
	for script: Script in SKILL_SCRIPTS:
		var id: String = script.ID
		assert(id != "_base_", "Skill must override ID")
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
