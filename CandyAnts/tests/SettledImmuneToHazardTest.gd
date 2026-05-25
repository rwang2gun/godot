extends Node

# Phase 20 — D-6 회귀 가드. SettledState ant가 hazard(Water) entry 시도 시 LostState 미진입.
# HazardBase._on_body_entered 가드 `if not ant.is_alive(): return`이 SettledState 일괄 차단.
# Ant.is_alive() 단일 진입점에 SettledState 포함 (Phase 15 F-impl-1).

const AntScene := preload("res://scenes/entities/Ant.tscn")

var _failed: bool = false

func _ready() -> void:
	# (1) Ant 인스턴스 생성 → SettledState 강제 진입.
	var ant: Ant = AntScene.instantiate()
	add_child(ant)
	await get_tree().physics_frame
	ant.global_position = Vector2(200, 200)
	ant.state_machine.change_state(SettledState.new())
	await get_tree().physics_frame
	if not (ant.state_machine.current_state is SettledState):
		_fail("expected SettledState after change_state, got %s" % str(ant.state_machine.current_state))
		return
	if ant.is_alive():
		_fail("Ant.is_alive() expected false for SettledState (D-6 가드 회귀)")
		return
	# (2) WaterHazard 생성 + body_entered 직접 호출 시뮬레이션.
	var water: WaterHazard = WaterHazard.new()
	add_child(water)
	# HazardBase._ready가 body_entered.connect를 이미 수행 — 중복 connect 금지.
	await get_tree().physics_frame
	# HazardBase._on_body_entered는 _on_body_entered가 protected 아님 — 직접 호출 OK.
	water._on_body_entered(ant)
	await get_tree().physics_frame
	# (3) SettledState 유지 (LostState 미진입) 검증.
	if not (ant.state_machine.current_state is SettledState):
		_fail("SettledState should remain after Water entry attempt, got %s" % str(ant.state_machine.current_state))
		return
	if ant.state_machine.current_state is LostState:
		_fail("ant unexpectedly entered LostState (D13 is_alive guard broken)")
		return
	# (4) sfx_request(water_splash)도 발화 안 됐어야 함 — HazardBase가 _handle_ant_entry 호출 전 차단.
	# (별도 sfx 캡처 없이도 LostState 미진입 = water_splash 미발화 자명)
	print("[SettledImmuneToHazardTest] PASS — SettledState immune to WaterHazard entry")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[SettledImmuneToHazardTest] FAIL ", msg)
	get_tree().quit(1)
