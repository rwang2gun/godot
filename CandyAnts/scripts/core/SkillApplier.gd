class_name SkillApplier
extends RefCounted

# 스킬 적용 **순수 규칙 단일 출처** (auto-solver Phase 1, D7·CRITICAL-1).
# SkillToolbar의 UI/SFX/terrain 탐색 결합에서 "인벤토리 차감 + can_apply + 설치 유효성" 규칙만 분리.
#   - SkillToolbar: SkillApplier에 위임 + 슬롯 카운트 갱신·SFX·커서만 덧붙임(프레젠테이션).
#   - PlanRunner(헤드리스 솔버 하니스): SkillApplier만 사용 → 규칙 SoT 1곳, 드라이버·주석은 ground truth 아님.
# 인벤토리는 Dictionary(참조형)를 받아 성공 시에만 in-place 차감한다. 실패 시 부수효과 없음.
#
# 대상 방식(스킬 self-describing SOLVER_META.target):
#   - "ant"  → apply_to_ant: 개미에 직접 스킬 적용(②③ ANT_SETTLE/ANT_ARMED).
#   - "cell" → place_on_cell: 표면 셀에 표지판(①SIGN)/장치(④DEVICE) 설치. 도착한 적격 개미가 발동.

# 설치형/장치 인스턴스 (SkillToolbar와 동일 preload — class_name 캐시 비의존, 헤드리스 안정).
const SkillSignScript := preload("res://scripts/world/SkillSign.gd")
const LeafJumpPadScript := preload("res://scripts/world/LeafJumpPad.gd")

# 개미 대상 스킬 적용 — 인벤토리>0 + can_apply 통과 시 apply + 차감 후 true. 그 외 false(부수효과 없음).
static func apply_to_ant(id: String, ant: Ant, inventory: Dictionary) -> bool:
	if id == "" or ant == null:
		return false
	if int(inventory.get(id, 0)) <= 0:
		return false
	var script: Script = SkillRegistry.get_skill(id)
	if script == null:
		return false
	var skill: Skill = script.new() as Skill
	if skill == null or not skill.can_apply(ant):
		return false
	skill.apply(ant)
	inventory[id] = int(inventory[id]) - 1
	return true

# 표면 셀 설치(SIGN/DEVICE) — 인벤토리>0 + SignPlacement 유효 셀이면 표지판/점프대 인스턴스화 + 차감.
# world_or_cell: world 좌표(Vector2) 또는 셀(Vector2i). parent = 설치 노드의 부모(보통 terrain.get_parent()).
# 반환: { placed: bool, cell: Vector2i, reason: String }.  reason ∈ {ok,no_id,no_inventory,no_terrain,
#   no_parent,not_cell_target,no_ground,pad_exists,...(SignPlacement)}.
static func place_on_cell(id: String, terrain: Terrain, world_or_cell, parent: Node, inventory: Dictionary) -> Dictionary:
	if id == "":
		return {"placed": false, "cell": Vector2i.MAX, "reason": "no_id"}
	if int(inventory.get(id, 0)) <= 0:
		return {"placed": false, "cell": Vector2i.MAX, "reason": "no_inventory"}
	if terrain == null:
		return {"placed": false, "cell": Vector2i.MAX, "reason": "no_terrain"}
	if parent == null:
		return {"placed": false, "cell": Vector2i.MAX, "reason": "no_parent"}
	var res: Dictionary = SignPlacement.resolve_surface_install_cell(terrain, id, world_or_cell, parent)
	if not res.get("valid", false):
		return {"placed": false, "cell": res.get("cell", Vector2i.MAX), "reason": str(res.get("reason", "invalid"))}
	var cell: Vector2i = res["cell"]
	match SkillAffordance.category_of(id):
		SkillAffordance.Category.DEVICE:
			var pad: LeafJumpPad = LeafJumpPadScript.new() as LeafJumpPad
			pad.setup(cell, terrain)
			parent.add_child(pad)
		SkillAffordance.Category.SIGN:
			# setup을 add_child 앞에 — _ready()/_build_visual()이 skill_id·cell·terrain을 사용(toolbar 관행).
			var sign: SkillSign = SkillSignScript.new() as SkillSign
			sign.setup(id, cell, terrain)
			parent.add_child(sign)
		_:
			return {"placed": false, "cell": cell, "reason": "not_cell_target"}
	inventory[id] = int(inventory[id]) - 1
	return {"placed": true, "cell": cell, "reason": "ok"}
