extends Node

# 드래그앤드롭 스킬 부여 회귀 가드.
# GUI 드래그 제스처 자체(viewport DnD)는 헤드리스에서 결정론적으로 재현이 어려우므로,
# 기존 test_SkillToolbar 스텁 철학("진짜 coverage는 UI 우회 직접 적용")을 따라 *로직*을 검증한다:
#   A. SkillToolbar.try_assign_dragged → 인벤토리 차감 + ant trait 적용
#   B. SkillSlot._make_drag_payload / _get_drag_data → count/disabled 게이트
#   C. SkillDropZone._can_drop_data → 데이터 shape 검증
#   D. SkillDropZone._drop_data → toolbar.try_assign_dragged로 라우팅(드롭 후 인벤토리 차감)

const STAGE_DATA_SCRIPT: GDScript = preload("res://scripts/core/StageData.gd")
const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const SLOT_SCENE: PackedScene = preload("res://scenes/ui/atoms/SkillSlot.tscn")
const CoordSpace := preload("res://scripts/input/CoordSpace.gd")


func _ready() -> void:
	var failures: Array[String] = []

	# --- 공통: climber 1개 인벤토리 toolbar ---
	var stage_data: StageData = STAGE_DATA_SCRIPT.new()
	stage_data.available_skills = ["climber"]
	stage_data.skill_inventory = {"climber": 1}
	var toolbar := SkillToolbar.new()
	toolbar.stage_data = stage_data
	var hbox: Control = HBoxContainer.new()
	hbox.name = "HBox"
	toolbar.add_child(hbox)
	toolbar.hbox_path = NodePath("HBox")
	add_child(toolbar)
	await get_tree().process_frame  # toolbar._ready → 슬롯 생성

	# fresh ant는 _ready에서 WalkerState 진입 → ClimberSkill.can_apply 통과.
	var ant: Ant = ANT_SCENE.instantiate()
	ant.global_position = Vector2(40, 40)
	add_child(ant)
	await get_tree().process_frame

	# === A. try_assign_dragged 직접 호출 → 부여 + 인벤토리 차감 ===
	toolbar.try_assign_dragged("climber", Vector2(40, 40))
	await get_tree().process_frame
	if int(toolbar._inventory.get("climber", -1)) != 0:
		failures.append("A: climber 인벤토리 1→0 기대, got %d" % int(toolbar._inventory.get("climber", -1)))
	if not ant.has_trait(&"climber"):
		failures.append("A: ant에 climber trait 미적용")

	# A-2. 인벤토리 0이면 추가 드롭은 noop (재고 없음 가드)
	var ant2: Ant = ANT_SCENE.instantiate()
	ant2.global_position = Vector2(40, 40)
	add_child(ant2)
	await get_tree().process_frame
	toolbar.try_assign_dragged("climber", Vector2(40, 40))
	await get_tree().process_frame
	if int(toolbar._inventory.get("climber", -1)) != 0:
		failures.append("A-2: 재고 0에서 인벤토리 음수로 내려감: %d" % int(toolbar._inventory.get("climber", -1)))
	if ant2.has_trait(&"climber"):
		failures.append("A-2: 재고 0인데 ant2에 trait 적용됨")

	# === B. SkillSlot drag payload 게이트 ===
	var slot: SkillSlot = SLOT_SCENE.instantiate()
	slot.skill_id = &"climber"
	add_child(slot)
	await get_tree().process_frame
	slot.set_count(2)
	await get_tree().process_frame
	var payload: Variant = slot._make_drag_payload()
	if not (payload is Dictionary) or String((payload as Dictionary).get("skill_id", "")) != "climber":
		failures.append("B: count>0 payload skill_id=climber 기대, got %s" % str(payload))
	# count 0 → null
	slot.set_count(0)
	await get_tree().process_frame
	if slot._make_drag_payload() != null or slot._get_drag_data(Vector2.ZERO) != null:
		failures.append("B: count<=0인데 drag 허용됨")
	# disabled → null
	slot.set_count(2)
	slot.set_disabled_state(true)
	await get_tree().process_frame
	if slot._make_drag_payload() != null or slot._get_drag_data(Vector2.ZERO) != null:
		failures.append("B: disabled인데 drag 허용됨")

	# === C. SkillDropZone._can_drop_data shape 검증 ===
	var zone := SkillDropZone.new()
	zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone.toolbar_path = NodePath("..")  # toolbar — add_child 전에 설정해 _ready 1회 해결.
	toolbar.add_child(zone)
	await get_tree().process_frame
	if not zone._can_drop_data(Vector2.ZERO, {"skill_id": "climber"}):
		failures.append("C: 유효 데이터 _can_drop_data=false")
	if zone._can_drop_data(Vector2.ZERO, {"foo": 1}):
		failures.append("C: skill_id 없는 dict _can_drop_data=true")
	if zone._can_drop_data(Vector2.ZERO, "string"):
		failures.append("C: 비-dict _can_drop_data=true")

	# === D. _drop_data → try_assign_dragged 라우팅 ===
	# 재고 보충 후, 현재 viewport 마우스 위치가 매핑되는 world에 새 ant 배치 → 드롭 시 부여돼야 함.
	toolbar._inventory["climber"] = 1
	var vp: Viewport = get_viewport()
	var drop_world: Vector2 = CoordSpace.screen_to_world(vp.get_mouse_position(), vp)
	var ant3: Ant = ANT_SCENE.instantiate()
	ant3.global_position = drop_world
	add_child(ant3)
	await get_tree().process_frame
	zone._drop_data(Vector2.ZERO, {"skill_id": "climber"})
	await get_tree().process_frame
	if int(toolbar._inventory.get("climber", -1)) != 0:
		failures.append("D: _drop_data 후 인벤토리 1→0 기대, got %d" % int(toolbar._inventory.get("climber", -1)))
	if not ant3.has_trait(&"climber"):
		failures.append("D: _drop_data가 가장 가까운 ant에 trait 미적용 (drop_world=%s)" % str(drop_world))

	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.size() > 0:
		push_error("[SkillDropAssignTest] FAIL — %d" % failures.size())
		for f in failures:
			print("  FAIL: ", f)
		get_tree().quit(1)
	else:
		print("[SkillDropAssignTest] PASS")
		get_tree().quit(0)
