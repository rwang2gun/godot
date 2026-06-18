extends Node

# auto-solver Phase 1 — D7 자동 동기화 drift 가드.
# 솔버는 게임 지식을 하드코딩하지 않고 SkillRegistry라는 단일 권위 뷰에서 스킬을 generic 열거한다.
# 신규/변경 스킬이 솔버 메타를 빠뜨리거나 UI 카테고리와 어긋나면 엔진/UI/솔버 3자 간 silent desync가
# 난다. 이 테스트가 그걸 FAIL로 차단한다.
#
# 단언:
#   ① 솔버 열거 == 런타임 레지스트리: SkillRegistry.skill_ids() == 등록 스크립트(SKILL_SCRIPTS)의 ID 집합.
#   ② 메타 완전성: 등록된 모든 스킬 + 모든 스테이지 인벤토리에 나오는 스킬이 완전한 SOLVER_META를 가짐
#      (target ∈ {ant,cell}, category ∈ 4분류). all_solver_metas()가 등록 스킬 전부를 덮음.
#   ③ category 종속(단일 권위): SOLVER_META.category == SkillAffordance.SKILL_CATEGORY[id] (이름↔enum).
#      + target이 category와 정합(ANT_*→ant, SIGN/DEVICE→cell).
#   ④ capabilities.tres 로드 가능 + 필수 필드 존재.

const VALID_TARGETS := ["ant", "cell"]
const CATEGORY_NAME_TO_ENUM := {
	"ANT_ARMED": SkillAffordance.Category.ANT_ARMED,
	"ANT_SETTLE": SkillAffordance.Category.ANT_SETTLE,
	"SIGN": SkillAffordance.Category.SIGN,
	"DEVICE": SkillAffordance.Category.DEVICE,
}
const ANT_CATEGORIES := ["ANT_ARMED", "ANT_SETTLE"]
const CELL_CATEGORIES := ["SIGN", "DEVICE"]
const CAPABILITIES_PATH := "res://data/solver/capabilities.tres"

func _ready() -> void:
	var failures: Array[String] = []

	# 등록 스크립트의 ID 집합.
	var registered: Dictionary = {}
	for script: Script in SkillRegistry.SKILL_SCRIPTS:
		var consts: Dictionary = script.get_script_constant_map()
		registered[str(consts.get("ID", ""))] = true

	# --- ① 솔버 열거 == 런타임 레지스트리 ---
	var enumerated: Dictionary = {}
	for id: String in SkillRegistry.skill_ids():
		enumerated[id] = true
	for id: String in registered:
		if not enumerated.has(id):
			failures.append("① skill_ids() missing registered id '%s'" % id)
	for id: String in enumerated:
		if not registered.has(id):
			failures.append("① skill_ids() has stale id '%s' (미등록)" % id)

	# --- 메타 완전성 대상 = 등록 스킬 ∪ 모든 스테이지 인벤토리 스킬 ---
	var must_have_meta: Dictionary = registered.duplicate()
	for sid: String in _stage_inventory_skill_ids():
		must_have_meta[sid] = true

	var metas: Dictionary = SkillRegistry.all_solver_metas()
	for id: String in must_have_meta:
		# 스테이지 인벤토리에 등록 안 된 스킬이 있으면 그 자체가 결함.
		if not registered.has(id):
			failures.append("② stage inventory references unregistered skill '%s'" % id)
			continue
		# --- ② 메타 완전성 ---
		if not metas.has(id):
			failures.append("② skill '%s' missing SOLVER_META (self-describing 필수)" % id)
			continue
		var meta: Dictionary = metas[id]
		var target: String = str(meta.get("target", ""))
		var category: String = str(meta.get("category", ""))
		if not VALID_TARGETS.has(target):
			failures.append("② skill '%s' SOLVER_META.target invalid: %r" % [id, target])
		if not CATEGORY_NAME_TO_ENUM.has(category):
			failures.append("② skill '%s' SOLVER_META.category invalid: %r" % [id, category])
			continue
		# --- ③ category 종속(단일 권위 뷰): 솔버 메타 == UI 카테고리 ---
		if SkillAffordance.category_of(id) != CATEGORY_NAME_TO_ENUM[category]:
			failures.append("③ skill '%s' SOLVER_META.category(%s) != SkillAffordance.category_of" % [id, category])
		# target ↔ category 정합.
		if ANT_CATEGORIES.has(category) and target != "ant":
			failures.append("③ skill '%s' category %s requires target 'ant', got %r" % [id, category, target])
		if CELL_CATEGORIES.has(category) and target != "cell":
			failures.append("③ skill '%s' category %s requires target 'cell', got %r" % [id, category, target])

	# --- ④ 전역 능력 명세 로드 + 필수 필드 ---
	var caps: Resource = load(CAPABILITIES_PATH)
	if caps == null:
		failures.append("④ capabilities.tres load failed: %s" % CAPABILITIES_PATH)
	else:
		for field: String in ["has_pause", "has_slow_motion", "input_methods",
				"t_human_comfortable_s", "t_human_hard_s", "t_human_machine_only_s"]:
			if not (field in caps):
				failures.append("④ capabilities missing field '%s'" % field)

	# --- 결과 ---
	if failures.is_empty():
		print("[SkillMetadataDriftTest] PASS — %d skills enumerated, meta complete, category in sync, capabilities loaded" % SkillRegistry.skill_ids().size())
		get_tree().quit(0)
	else:
		push_error("SkillMetadataDriftTest FAIL: " + str(failures))
		print("[SkillMetadataDriftTest] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)

# 모든 스테이지(.tres)의 available_skills + skill_inventory에 등장하는 스킬 id 집합.
# (메타 완전성을 "실제 게임에서 쓰이는 스킬 전부"로 확장 — 솔버가 그 스킬을 열거해야 함.)
func _stage_inventory_skill_ids() -> Dictionary:
	var ids: Dictionary = {}
	var dir: DirAccess = DirAccess.open("res://data/stages")
	if dir == null:
		return ids
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res: Resource = load("res://data/stages/" + fname)
			if res != null:
				if "available_skills" in res:
					for sid in res.available_skills:
						ids[str(sid)] = true
				if "skill_inventory" in res:
					for sid in res.skill_inventory.keys():
						ids[str(sid)] = true
		fname = dir.get_next()
	dir.list_dir_end()
	return ids
