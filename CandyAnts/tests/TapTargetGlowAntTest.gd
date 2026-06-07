extends Node

# Phase 2 — ANT 카테고리(②③) 글로우. climber(③)/blocker(②) 선택 시 적격 개미만 글로우, 타일 무글로우.
# 글로우 대상은 카테고리 SoT 파생 — 스킬 id 하드코딩 없음.
# 개미를 실제 바닥(layer 1, ant mask 3)에 착지시켜 is_on_floor()=true(blocker/floater can_apply 요건) 확보 후 물리 고정.

const AntScene := preload("res://scenes/entities/Ant.tscn")
const FLOOR_TOP_Y := 400.0

var _ants: Array[Ant] = []

func _ready() -> void:
	var failures: Array[String] = []

	_make_floor(FLOOR_TOP_Y)
	var tb := SkillToolbar.new()
	add_child(tb)
	var ctrl := AffordanceGlowController.new()
	add_child(ctrl)
	ctrl.set_process(false)
	ctrl._toolbar = tb

	var a1: Ant = _spawn_ant(400.0)
	var a2: Ant = _spawn_ant(520.0)
	# 착지 대기 → Walker on floor.
	for i in 40:
		await get_tree().physics_frame
	for a in _ants:
		if not a.is_on_floor():
			failures.append("%s did not land on floor" % a.name)
		a.set_physics_process(false)   # 상태 고정(이후 walk-off/fall 방지)

	# ③ ANT_ARMED: climber → 두 개미 모두 글로우, surface marker 미생성
	tb._pending_skill_id = "climber"
	ctrl.refresh(Vector2(500, 300))
	if not _ant_glowing(a1):
		failures.append("climber: a1 not glowing")
	if not _ant_glowing(a2):
		failures.append("climber: a2 not glowing")
	if ctrl._glowing_ants.size() != 2:
		failures.append("climber: glowing_ants size != 2 (%d)" % ctrl._glowing_ants.size())
	if ctrl._surface_marker != null:
		failures.append("climber (ANT category): surface marker should not be created")

	# ② ANT_SETTLE: blocker → 지면 위 적격 개미 글로우
	tb._pending_skill_id = "blocker"
	ctrl.refresh(Vector2(500, 300))
	if ctrl._glowing_ants.size() != 2:
		failures.append("blocker: glowing_ants size != 2 (%d)" % ctrl._glowing_ants.size())
	if not _ant_glowing(a1) or not _ant_glowing(a2):
		failures.append("blocker: walkers not glowing")

	# 해제: pending="" → 모든 글로우 clear
	tb._pending_skill_id = ""
	ctrl.refresh(Vector2(500, 300))
	if _ant_glowing(a1) or _ant_glowing(a2):
		failures.append("deselect: ant glow not cleared")
	if ctrl._glowing_ants.size() != 0:
		failures.append("deselect: glowing_ants not empty (%d)" % ctrl._glowing_ants.size())

	_finish("TapTargetGlowAntTest", failures)

func _make_floor(top_y: float) -> void:
	var fb := StaticBody2D.new()
	fb.collision_layer = 1   # ant collision_mask=3 (layers 1·2) → 충돌
	fb.collision_mask = 0
	var cshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 200)
	cshape.shape = rect
	cshape.position = Vector2(500, top_y + 100.0)   # top edge = top_y
	fb.add_child(cshape)
	add_child(fb)

func _spawn_ant(x: float) -> Ant:
	var a: Ant = AntScene.instantiate()
	add_child(a)
	a.global_position = Vector2(x, FLOOR_TOP_Y - 24.0)
	_ants.append(a)
	return a

func _ant_glowing(a: Ant) -> bool:
	var s: Node = a.get_node_or_null("Sprite")
	return s != null and s.has_meta(Glow.META_KEY)

func _finish(test_name: String, failures: Array) -> void:
	if failures.size() > 0:
		push_error(test_name + " FAIL: " + str(failures))
		print("[%s] FAIL" % test_name)
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[%s] PASS" % test_name)
		get_tree().quit(0)
