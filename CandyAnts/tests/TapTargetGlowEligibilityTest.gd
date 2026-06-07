extends Node

# Phase 2 — can_apply 적격 게이팅. 무장(부적격·생존) / 사망(is_alive false) 개미는 글로우 제외.
# "왜 안 되지"를 시각으로 답함(§0.8.3-1). bridge(③)로 검증 — 무장 상호배타 게이트 활용.
# 개미를 실제 바닥에 착지(is_on_floor true = bridge 요건) 후 물리 고정.

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

	var elig: Ant = _spawn_ant(400.0)
	var armed: Ant = _spawn_ant(520.0)
	var dead: Ant = _spawn_ant(640.0)
	for i in 40:
		await get_tree().physics_frame
	for a in _ants:
		if not a.is_on_floor():
			failures.append("%s did not land" % a.name)
		a.set_physics_process(false)
	armed.bridge_armed = true                            # 무장 → bridge.can_apply false (생존 유지)
	dead.state_machine.change_state(DeadState.new())     # is_alive() false

	tb._pending_skill_id = "bridge"
	var e: Array = ctrl.eligible_ants("bridge")
	if e.size() != 1 or (e.size() == 1 and e[0] != elig):
		failures.append("eligible_ants should be [elig] only, got size=%d" % e.size())

	ctrl.refresh(Vector2(500, 300))
	if not _glowing(elig):
		failures.append("eligible walker not glowing")
	if _glowing(armed):
		failures.append("armed (ineligible) ant should NOT glow")
	if _glowing(dead):
		failures.append("dead (not alive) ant should NOT glow")
	if ctrl._glowing_ants.size() != 1:
		failures.append("glowing_ants size != 1 (%d)" % ctrl._glowing_ants.size())

	# 무장 해제 시 적격 복귀 → 글로우 진입(동적 갱신 확인)
	armed.bridge_armed = false
	ctrl.refresh(Vector2(500, 300))
	if not _glowing(armed):
		failures.append("disarmed ant should re-enter glow")
	if ctrl._glowing_ants.size() != 2:
		failures.append("after disarm glowing_ants size != 2 (%d)" % ctrl._glowing_ants.size())

	_finish("TapTargetGlowEligibilityTest", failures)

func _make_floor(top_y: float) -> void:
	var fb := StaticBody2D.new()
	fb.collision_layer = 1
	fb.collision_mask = 0
	var cshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 200)
	cshape.shape = rect
	cshape.position = Vector2(500, top_y + 100.0)
	fb.add_child(cshape)
	add_child(fb)

func _spawn_ant(x: float) -> Ant:
	var a: Ant = AntScene.instantiate()
	add_child(a)
	a.global_position = Vector2(x, FLOOR_TOP_Y - 24.0)
	_ants.append(a)
	return a

func _glowing(a: Ant) -> bool:
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
