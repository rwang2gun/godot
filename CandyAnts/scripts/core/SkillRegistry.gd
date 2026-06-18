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
	preload("res://scripts/skills/LeafJumpSkill.gd"),
]

var _skills: Dictionary = {}
# auto-solver Phase 1 (D7): 스킬 self-describing 메타(SOLVER_META)를 등록 시점에 수집한 캐시.
# 솔버는 이 단일 권위 뷰(SkillRegistry)에서 generic 열거 → 스킬별 하드코딩 없이 행동공간 구성.
var _metas: Dictionary = {}     # id (String) → SOLVER_META (Dictionary), 미선언 시 키 부재

func _ready() -> void:
	for script: Script in SKILL_SCRIPTS:
		var consts: Dictionary = script.get_script_constant_map()
		var id: String = str(consts.get("ID", ""))
		assert(id != "", "Skill subclass must define const ID")
		assert(not _skills.has(id), "Duplicate skill ID: %s" % id)
		_skills[id] = script
		# SOLVER_META 미선언 스킬은 키를 두지 않는다 — SkillMetadataDriftTest가 완전성을 FAIL로 잡는다
		# (등록은 막지 않아 게임/UI는 메타와 독립적으로 동작; 가드 테스트가 솔버 동기화를 강제).
		if consts.has("SOLVER_META"):
			_metas[id] = consts["SOLVER_META"]

func get_skill(id: String) -> Script:
	return _skills.get(id)

# 솔버 generic 열거 — 등록된 스킬 id를 결정론 순서(id 정렬)로 반환. 솔버가 행동공간을 구성하는 진입점.
func skill_ids() -> Array:
	var ids: Array = _skills.keys()
	ids.sort()
	return ids

# 스킬 self-describing 메타(SOLVER_META) 조회. 미선언 시 빈 Dictionary.
# (Object.get_meta와 충돌 회피 위해 solver_meta로 명명.)
func solver_meta(id: String) -> Dictionary:
	return _metas.get(id, {})

# 메타가 선언된 스킬만 id→메타로 반환(드리프트 가드·솔버 열거용).
func all_solver_metas() -> Dictionary:
	return _metas.duplicate(true)

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
