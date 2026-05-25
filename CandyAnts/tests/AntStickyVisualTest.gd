extends Node

# Phase 20 — P-D4 / P-D5 / R1-H3 / R1-M3 회귀 가드.
# (1) StickyTimerBar.visible toggle (stuck 중 true / 해제 후 false)
# (2) StickyTimerBar.scale.x 단조 감소 (=`_sticky_remaining/_sticky_max`)
# (3) R1-H3: stuck 진입 시 _sprite.pause(), 해제 후 명시 _sprite.play(_last_anim) 재개
# (4) R1-M3: timer 만료 후 fresh apply_sticky의 _sticky_max가 정확히 새 dur로 reset

const AntScene := preload("res://scenes/entities/Ant.tscn")

var _failed: bool = false
var _ant: Ant = null

func _ready() -> void:
	# (1)/(2) stuck 진입 + bar 시각 + sprite pause
	await _case_a_basic_visual()
	if _failed: return
	# (3) sprite resume 검증
	await _case_b_sprite_resume()
	if _failed: return
	# (4) R1-M3 _sticky_max reset 검증
	await _case_c_max_reset()
	if _failed: return
	print("[AntStickyVisualTest] PASS")
	get_tree().quit(0)

func _spawn_ant() -> Ant:
	var a: Ant = AntScene.instantiate()
	add_child(a)
	a.global_position = Vector2(100, 100)   # 임의 위치 (floor 무관 — _physics_process만 검증)
	await get_tree().physics_frame
	await get_tree().physics_frame   # _ready 완료 후 1 frame 추가
	return a

func _case_a_basic_visual() -> void:
	_ant = await _spawn_ant()
	var bar: Sprite2D = _ant.get_node("TraitBadges/StickyTimerBar") as Sprite2D
	if bar == null:
		_fail("case A: StickyTimerBar 노드 없음 (Ant.tscn 갱신 누락?)")
		return
	# 초기엔 invisible
	if bar.visible:
		_fail("case A: 초기 bar.visible expected false, got true")
		return
	# apply_sticky(3.0) — fresh entry
	_ant.apply_sticky(3.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not bar.visible:
		_fail("case A: apply_sticky 후 bar.visible expected true")
		return
	if bar.scale.x > 1.05 or bar.scale.x < 0.85:
		_fail("case A: 첫 frame bar.scale.x expected ≈ 1.0, got %f" % bar.scale.x)
		return
	# sprite pause 검증 (R1-H3)
	var sprite: AnimatedSprite2D = _ant.get_node("Sprite") as AnimatedSprite2D
	if sprite.is_playing():
		_fail("case A: stuck 중 sprite.is_playing expected false (pause), got true")
		return
	# stuck 해제 대기
	var deadline: int = 0
	while _ant.is_stuck() and deadline < 400:
		await get_tree().physics_frame
		deadline += 1
	if _ant.is_stuck():
		_fail("case A: 400 frame 후에도 is_stuck=true (apply_sticky decay 실패)")
		return
	# 해제 후 bar invisible
	await get_tree().physics_frame
	if bar.visible:
		_fail("case A: stuck 해제 후 bar.visible expected false")
		return
	_ant.queue_free()
	await get_tree().process_frame

func _case_b_sprite_resume() -> void:
	# R1-H3 회귀 가드 — stuck 해제 직후 1~2 frame 내 sprite.is_playing == true.
	# unstuck 후 anim이 stuck 전과 동일(walk→walk)이라도 명시 play() 재호출 발화.
	_ant = await _spawn_ant()
	var sprite: AnimatedSprite2D = _ant.get_node("Sprite") as AnimatedSprite2D
	_ant.apply_sticky(2.0)
	await get_tree().physics_frame
	if sprite.is_playing():
		_fail("case B: stuck 중 is_playing expected false")
		return
	# 해제 대기
	var deadline: int = 0
	while _ant.is_stuck() and deadline < 300:
		await get_tree().physics_frame
		deadline += 1
	if _ant.is_stuck():
		_fail("case B: deadline 초과 — sticky decay 실패")
		return
	# unstuck 직후 1~3 frame 안에 명시 play() 재호출돼야 함
	var resumed: bool = false
	for i in 5:
		await get_tree().physics_frame
		if sprite.is_playing():
			resumed = true
			break
	if not resumed:
		_fail("case B: stuck 해제 후 5 frame 내 sprite.is_playing == true 미관찰 — R1-H3 회귀")
		return
	_ant.queue_free()
	await get_tree().process_frame

func _case_c_max_reset() -> void:
	# R1-M3 회귀 가드 — apply_sticky(3.0) 만료 후 apply_sticky(1.0) → 첫 frame scale.x ≈ 1.0
	# (3.0 stale denominator가 잡혔으면 scale.x ≈ 0.33).
	_ant = await _spawn_ant()
	var bar: Sprite2D = _ant.get_node("TraitBadges/StickyTimerBar") as Sprite2D
	_ant.apply_sticky(0.2)   # 짧게 — 빨리 만료
	await get_tree().physics_frame
	# 만료까지 대기 (0.2초 = 12 frame at 60fps + 여유)
	var deadline: int = 0
	while _ant.is_stuck() and deadline < 60:
		await get_tree().physics_frame
		deadline += 1
	if _ant.is_stuck():
		_fail("case C: deadline 초과 — sticky decay 실패")
		return
	# 만료 후 _sticky_max == 0 (R1-M3) — 직접 검증 가능
	if _ant._sticky_max != 0.0:
		_fail("case C: 만료 후 _sticky_max expected 0.0, got %f" % _ant._sticky_max)
		return
	# fresh apply_sticky(1.0)
	_ant.apply_sticky(1.0)
	await get_tree().physics_frame
	if _ant._sticky_max != 1.0:
		_fail("case C: fresh apply 후 _sticky_max expected 1.0, got %f (R1-M3 회귀)" % _ant._sticky_max)
		return
	if bar.scale.x < 0.85:
		_fail("case C: fresh apply 첫 frame bar.scale.x expected ≈ 1.0 (stale 0.2 denominator 안 잡힘), got %f" % bar.scale.x)
		return
	_ant.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[AntStickyVisualTest] FAIL ", msg)
	get_tree().quit(1)
