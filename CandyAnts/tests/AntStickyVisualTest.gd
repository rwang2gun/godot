extends Node

# 끈끈이 = 감속 존(2026-06-07 재설계) 시각/상태 가드. 과거 "정지 + 카운트다운 게이지 + sprite pause" 폐기.
# (1) enter_sticky → is_slowed()==true, effective_speed가 STICKY_SPEED_MULT배로 감소
# (2) exit_sticky → is_slowed()==false, effective_speed 복원
# (3) 다중 소스(인접 끈끈이 띠) — 한 소스만 빠져도 여전히 감속, 전부 빠지면 해제
# (4) 머리 위 StickyBadge 아이콘은 상시 숨김 / 카운트다운 게이지(StickyTimerBar) 미사용(상시 숨김)

const AntScene := preload("res://scenes/entities/Ant.tscn")

var _failed: bool = false
var _ant: Ant = null

func _ready() -> void:
	await _case_a_slow_toggle()
	if _failed: return
	await _case_b_multi_source()
	if _failed: return
	await _case_c_badges_hidden()
	if _failed: return
	print("[AntStickyVisualTest] PASS")
	get_tree().quit(0)

func _spawn_ant() -> Ant:
	var a: Ant = AntScene.instantiate()
	add_child(a)
	a.global_position = Vector2(100, 100)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return a

# (1)/(2) 감속 토글 + effective_speed 배율.
func _case_a_slow_toggle() -> void:
	_ant = await _spawn_ant()
	var base_speed: float = _ant.effective_speed()
	if _ant.is_slowed():
		_fail("case A: 초기 is_slowed expected false")
		return
	_ant.enter_sticky(111)
	if not _ant.is_slowed():
		_fail("case A: enter_sticky 후 is_slowed expected true")
		return
	var slow_speed: float = _ant.effective_speed()
	var expected: float = base_speed * Ant.STICKY_SPEED_MULT
	if not is_equal_approx(slow_speed, expected):
		_fail("case A: 감속 속도 %f expected %f (base %f × %f)" % [slow_speed, expected, base_speed, Ant.STICKY_SPEED_MULT])
		return
	_ant.exit_sticky(111)
	if _ant.is_slowed():
		_fail("case A: exit_sticky 후 is_slowed expected false")
		return
	if not is_equal_approx(_ant.effective_speed(), base_speed):
		_fail("case A: exit 후 속도 복원 실패 %f != %f" % [_ant.effective_speed(), base_speed])
		return
	_ant.queue_free()
	await get_tree().process_frame

# (3) 다중 소스 — 인접 끈끈이 띠를 지나며 겹침이 겹칠 때 한 칸만 빠져도 감속 유지.
func _case_b_multi_source() -> void:
	_ant = await _spawn_ant()
	_ant.enter_sticky(1)
	_ant.enter_sticky(2)
	if not _ant.is_slowed():
		_fail("case B: 2 소스 진입 후 is_slowed expected true")
		return
	_ant.exit_sticky(1)
	if not _ant.is_slowed():
		_fail("case B: 1/2 소스만 빠졌는데 is_slowed false (남은 소스 무시)")
		return
	_ant.exit_sticky(2)
	if _ant.is_slowed():
		_fail("case B: 모든 소스 빠진 뒤에도 is_slowed true")
		return
	_ant.queue_free()
	await get_tree().process_frame

# (4) 머리 위 아이콘/게이지 상시 숨김.
func _case_c_badges_hidden() -> void:
	_ant = await _spawn_ant()
	_ant.enter_sticky(9)
	await get_tree().physics_frame
	var badge: Sprite2D = _ant.get_node_or_null("TraitBadges/StickyBadge") as Sprite2D
	if badge != null and badge.visible:
		_fail("case C: 감속 중 StickyBadge 아이콘이 보임(상시 숨김이어야 함)")
		return
	var bar: Sprite2D = _ant.get_node_or_null("TraitBadges/StickyTimerBar") as Sprite2D
	if bar != null and bar.visible:
		_fail("case C: 감속 중 StickyTimerBar 게이지가 보임(감속 존은 게이지 미사용)")
		return
	_ant.queue_free()
	await get_tree().process_frame

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[AntStickyVisualTest] FAIL ", msg)
	get_tree().quit(1)
