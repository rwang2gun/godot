extends Node

# 레벨툴(맵 에디터) 저장 라운드트립 검증 (2026-06-05).
# level_tool_dock.gd는 저장 시 available_skills/skill_inventory를 SKILL_IDS 기준으로 **재구성**한다
# (_apply_to_stage: 기존 값 clear → SKILL_IDS 각 id의 spin count>0이면 재등록). SKILL_IDS에 빠진
# 스킬은 에디터 저장 시 소리 없이 사라진다. leaf_jump가 SKILL_IDS에 포함돼 Stage08(끈끈이 스테이지)의
# 점프대 지급이 에디터에서 보이고(스핀박스) 저장 후에도 보존됨을 검증.
#
# 실제 dock 상수(SKILL_IDS)를 로드해 dock의 save 재구성 로직을 그대로 재현 → 회귀 시 즉시 깨진다.
# (dock 자체는 @tool/EditorInterface 의존이라 헤드리스 인스턴스화 대신 핵심 로직만 재현.)

const DOCK_PATH := "res://addons/candyants_level_tool/level_tool_dock.gd"
const STAGE08_PATH := "res://data/stages/stage08.tres"

func _ready() -> void:
	var dock_script: GDScript = load(DOCK_PATH) as GDScript
	if dock_script == null:
		_fail("dock script load 실패: %s" % DOCK_PATH)
		return
	var consts: Dictionary = dock_script.get_script_constant_map()
	if not consts.has("SKILL_IDS"):
		_fail("dock에 SKILL_IDS 상수 없음")
		return
	var skill_ids: Array = consts["SKILL_IDS"]
	if not skill_ids.has("leaf_jump"):
		_fail("SKILL_IDS에 leaf_jump 누락 → 에디터 저장 시 점프대 지급이 소멸한다. ids=%s" % str(skill_ids))
		return

	var stage: Resource = load(STAGE08_PATH)
	if stage == null:
		_fail("Stage08 load 실패")
		return
	var before_inv: Dictionary = stage.skill_inventory.duplicate(true)
	if int(before_inv.get("leaf_jump", 0)) != 3:
		_fail("사전조건 불일치: Stage08 leaf_jump 지급=%d (기대 3 — 왕복용 2개 추가)" % int(before_inv.get("leaf_jump", 0)))
		return

	# dock _apply_to_stage 저장 재구성 재현: 에디터 spin 값 = 로드 시 inventory.get(id,0).
	var rebuilt_available: Array[String] = []
	var rebuilt_inventory: Dictionary = {}
	for id: String in skill_ids:
		var count: int = int(before_inv.get(id, 0))   # 에디터가 로드 시 spin에 채우는 값
		if count > 0:
			rebuilt_available.append(id)
			rebuilt_inventory[id] = count

	# 검증: leaf_jump(1)·cutter(4) 모두 저장 후 보존.
	if not rebuilt_available.has("leaf_jump") or int(rebuilt_inventory.get("leaf_jump", 0)) != 3:
		_fail("저장 라운드트립 후 leaf_jump 소실/변형: available=%s inv=%s" % [
			str(rebuilt_available), str(rebuilt_inventory)])
		return
	if not rebuilt_available.has("cutter") or int(rebuilt_inventory.get("cutter", 0)) != 4:
		_fail("저장 라운드트립 후 cutter 소실/변형: available=%s inv=%s" % [
			str(rebuilt_available), str(rebuilt_inventory)])
		return

	print("[LeafJumpEditorRoundTripTest] PASS — SKILL_IDS에 leaf_jump 포함, 저장 후 보존 available=%s inv=%s" % [
		str(rebuilt_available), str(rebuilt_inventory)])
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[LeafJumpEditorRoundTripTest] FAIL %s" % msg)
	get_tree().quit(1)
