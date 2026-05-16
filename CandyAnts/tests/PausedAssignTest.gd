extends Node

# Phase 8 — pause=true 중 스킬 부여가 결정적으로 동작하는지 검증.
#
# case-A: EventBus.action_triggered(SKILL_ASSIGN) 경로 — paused에서도 ant state 전이
# case-B: paused 상태에서 SkillToolbar 내부 Button.pressed 신호로 slot 선택 (process_mode propagation 검증)
# case-C: unpause 후 한 physics tick → blocker hitbox monitoring=true (실효 발현)

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const SKILL_TOOLBAR_SCENE: PackedScene = preload("res://scenes/ui/SkillToolbar.tscn")
const GameAction := preload("res://scripts/input/GameAction.gd")

var _floor: StaticBody2D = null
var _ant: Ant = null
var _toolbar: SkillToolbar = null


func _ready() -> void:
	# Floor — Ant.is_on_floor() 보장
	_floor = StaticBody2D.new()
	_floor.collision_layer = 1
	_floor.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(400, 40)
	col.shape = shape
	_floor.add_child(col)
	_floor.global_position = Vector2(0, 100)
	add_child(_floor)

	# Ant — floor 위에 배치
	_ant = ANT_SCENE.instantiate() as Ant
	add_child(_ant)
	_ant.global_position = Vector2(0, 60)
	# spawn grace를 우회하기 위해 즉시 짧게 setting (BlockerSkill.can_apply는 grace 안 봄)

	# StageData fixture — blocker 1개 인벤토리
	var stage_data: StageData = StageData.new()
	stage_data.available_skills = ["blocker"] as Array[String]
	stage_data.skill_inventory = {"blocker": 1}

	_toolbar = SKILL_TOOLBAR_SCENE.instantiate() as SkillToolbar
	_toolbar.stage_data = stage_data
	add_child(_toolbar)

	# Physics 여러 사이클 — ant가 fall + floor 접지 (gravity 900 → ~15px/frame).
	for _i in range(20):
		await get_tree().physics_frame
		if _ant.is_on_floor():
			break
	await get_tree().process_frame

	if not _ant.is_on_floor():
		_fail("baseline: ant.is_on_floor() == false after 20 physics frames"); return

	# --- case-A: paused 중 EventBus SKILL_SELECT → SKILL_ASSIGN 경로 ---
	get_tree().paused = true
	await get_tree().process_frame

	# slot 0 = "blocker" 선택
	EventBus.action_triggered.emit(GameAction.SKILL_SELECT_1, {"slot": 0})
	# assign — payload에 ant 위치 동봉
	var payload := {
		"position_valid": true,
		"screen_pos": Vector2.ZERO,  # 본 테스트는 world_pos만 사용
		"world_pos": _ant.global_position,
	}
	EventBus.action_triggered.emit(GameAction.SKILL_ASSIGN, payload)
	# signal callbacks은 pause 무관 동기 실행 — state 전이가 즉시 이루어져야 함.

	if not (_ant.state_machine.current_state is WorkerState):
		_fail("case-A: paused 중 SKILL_ASSIGN 후 state != Worker (got %s)" % _ant.state_machine.current_state); return

	# --- case-B: paused 상태에서 Button이 input 가능한 상태인지 + signal 경로 동작 검증 ---
	# (paused 상태 그대로 유지)
	# MEDIUM-1 (codex impl-review Round 1) 대응: process_mode=ALWAYS propagation을 직접 확인.
	# - SkillToolbar (CanvasLayer)의 process_mode=ALWAYS 명시가 자식 Button까지 inherit되는지
	#   `can_process()` 엔진 직접 readout으로 검증. 헤드리스에서 viewport mouse dispatch는
	#   불안정하므로 invariant + signal 경로를 분리해서 검증.
	if not _toolbar._pending_skill_id == "":
		_fail("case-B baseline: _pending_skill_id != \"\" after first assign"); return
	_toolbar._inventory["blocker"] = 1
	var btn: Button = _toolbar._buttons.get("blocker") as Button
	if btn == null:
		_fail("case-B: blocker Button 미생성"); return
	# (B-1) 엔진 readout — paused 상태에서도 Button.can_process() == true 여야 ALWAYS propagation 정상.
	if not get_tree().paused:
		_fail("case-B baseline: tree.paused != true"); return
	if not btn.can_process():
		_fail("case-B (process_mode propagation 회귀): Button.can_process() == false during paused"); return
	if not _toolbar.can_process():
		_fail("case-B: SkillToolbar.can_process() == false during paused (process_mode 회귀)"); return
	# (B-2) signal 경로 — Button.pressed → SkillToolbar._on_button_pressed → pending=id
	_toolbar.call("_refresh_button", "blocker")
	btn.disabled = false
	btn.pressed.emit()
	if _toolbar._pending_skill_id != "blocker":
		_fail("case-B: Button.pressed 후 _pending_skill_id != 'blocker' (got '%s')" % _toolbar._pending_skill_id); return

	# --- case-C: unpause 후 physics frame → blocker hitbox monitoring=true ---
	get_tree().paused = false
	await get_tree().physics_frame
	await get_tree().process_frame
	# BlockerHitbox는 Ant 내부에 있고 monitoring은 set_blocker_active(true)로 켜짐.
	var hitbox: Area2D = _ant.get_node_or_null("BlockerHitbox") as Area2D
	if hitbox == null:
		_fail("case-C: BlockerHitbox 노드 없음"); return
	if not hitbox.monitoring:
		_fail("case-C: unpause 후 blocker hitbox monitoring != true"); return

	print("[PausedAssignTest] PASS")
	get_tree().quit(0)


func _fail(label: String) -> void:
	push_error("[PausedAssignTest] FAIL %s" % label)
	print("[PausedAssignTest] FAIL %s" % label)
	get_tree().quit(1)
