extends Node

# Phase 19 unit-style — SkillRegistry의 cutter 등록 + validate_stage 검증.
# §10 strict acceptance §6 SkillRegistry-part enforce.
#
# PASS criteria (5):
#  (1) SkillRegistry.get_skill("cutter") non-null + script.ID == "cutter"
#  (2) SkillRegistry._skills.has("cutter") == true
#  (3) validate_stage(dev_cutter_vine_test) → errors 빈 배열
#  (4) validate_stage(임시 stage with available_skills=["unknown_xyz"]) → errors 1건 이상
#  (5) get_skill("unknown_xyz") == null

const CUTTER_STAGE: Resource = preload("res://dev_stages/cutter_vine/cutter_vine_test.tres")

func _ready() -> void:
	# (1) get_skill("cutter").
	var cutter_script: Script = SkillRegistry.get_skill("cutter")
	if cutter_script == null:
		_fail("(1a) get_skill('cutter') == null")
		return
	if cutter_script.ID != "cutter":
		_fail("(1b) cutter script.ID != 'cutter' (got=%s)" % cutter_script.ID)
		return
	print("[SkillRegistryCutterValidateTest] PASS (1) get_skill('cutter') + ID")

	# (2) _skills.has.
	var skills: Dictionary = SkillRegistry._skills
	if not skills.has("cutter"):
		_fail("(2) _skills.has('cutter') == false")
		return
	print("[SkillRegistryCutterValidateTest] PASS (2) _skills membership")

	# (3) validate_stage(cutter_vine_test) errors 빈.
	var errs: Array = SkillRegistry.validate_stage(CUTTER_STAGE)
	if errs.size() > 0:
		_fail("(3) validate_stage(cutter_vine_test) errors=%s (빈 배열 기대)" % str(errs))
		return
	print("[SkillRegistryCutterValidateTest] PASS (3) validate_stage clean")

	# (4) 임시 unknown stage.
	var bad: StageData = StageData.new()
	bad.id = 999
	bad.display_name = "bad-stage"
	var skills_arr: Array[String] = ["unknown_xyz"]
	bad.available_skills = skills_arr
	bad.skill_inventory = {"unknown_xyz": 1}
	var bad_errs: Array = SkillRegistry.validate_stage(bad)
	if bad_errs.size() < 1:
		_fail("(4) validate_stage(unknown_xyz) errors size=0 (1+ 기대)")
		return
	print("[SkillRegistryCutterValidateTest] PASS (4) unknown id detection (%d errors)" % bad_errs.size())

	# (5) get_skill unknown.
	if SkillRegistry.get_skill("unknown_xyz") != null:
		_fail("(5) get_skill('unknown_xyz') non-null")
		return
	print("[SkillRegistryCutterValidateTest] PASS (5) get_skill unknown null")

	print("[SkillRegistryCutterValidateTest] PASS")
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("[SkillRegistryCutterValidateTest] FAIL: " + reason)
	get_tree().quit(1)
