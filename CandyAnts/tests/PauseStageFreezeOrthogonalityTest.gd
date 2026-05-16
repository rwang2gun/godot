extends Node

# Phase 8 — tree.paused와 SceneFlow._freeze_current_stage 직교성 검증.
# - tree.paused: 사용자 pause (StepFrame 토글)
# - process_mode=DISABLED on stage_root: 결과 overlay용 freeze
#
# 두 메커니즘이 독립적으로 동작하고 어느 한쪽만 풀려도 다른 쪽이 여전히 작동해야 함.


class DummyPhysics extends Node:
	var ticks: int = 0
	func _ready() -> void:
		# INHERIT — 실제 stage 자손 노드 default. 부모(stage_root)가 DISABLED면 자식도 정지.
		process_mode = Node.PROCESS_MODE_INHERIT
	func _physics_process(_delta: float) -> void:
		ticks += 1


const GameAction := preload("res://scripts/input/GameAction.gd")

var _stage_root: Node = null
var _dummy: DummyPhysics = null


func _ready() -> void:
	_stage_root = Node.new()
	add_child(_stage_root)
	_dummy = DummyPhysics.new()
	_stage_root.add_child(_dummy)

	await get_tree().process_frame
	get_tree().paused = false
	_stage_root.process_mode = Node.PROCESS_MODE_INHERIT

	# case-A: paused=true, freeze 미적용 → physics counter 정지
	get_tree().paused = true
	await get_tree().process_frame
	_dummy.ticks = 0
	await get_tree().physics_frame
	await get_tree().process_frame
	if _dummy.ticks != 0:
		_fail("case-A: paused=true에서 physics 진행됨 (%d)" % _dummy.ticks); return

	# case-B: freeze + paused=true + STEP_FRAME → freeze가 우선이라 stage_root counter 변화 없음
	_stage_root.process_mode = Node.PROCESS_MODE_DISABLED
	_dummy.ticks = 0
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	await _wait_for_step_completion()
	if _dummy.ticks != 0:
		_fail("case-B: freeze 상태에서 STEP_FRAME가 counter 증가시킴 (%d)" % _dummy.ticks); return

	# case-C: freeze 해제 + paused 유지 + STEP_FRAME → counter 1 증가
	_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = true  # case-B의 STEP_FRAME가 paused를 다시 true로 만들어둠
	await get_tree().process_frame
	_dummy.ticks = 0
	EventBus.action_triggered.emit(GameAction.STEP_FRAME, {})
	await _wait_for_step_completion()
	if _dummy.ticks < 1:
		_fail("case-C: freeze 해제 후 STEP_FRAME tick=%d" % _dummy.ticks); return

	# case-D: 둘 다 해제 → 정상 진행
	get_tree().paused = false
	_dummy.ticks = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _dummy.ticks < 1:
		_fail("case-D: 완전 해제 후 physics 미진행 (%d)" % _dummy.ticks); return

	print("[PauseStageFreezeOrthogonalityTest] PASS")
	get_tree().quit(0)


func _wait_for_step_completion() -> void:
	for _i in range(60):
		if not StepFrame.is_stepping():
			return
		await get_tree().physics_frame
		await get_tree().process_frame


func _fail(label: String) -> void:
	push_error("[PauseStageFreezeOrthogonalityTest] FAIL %s" % label)
	print("[PauseStageFreezeOrthogonalityTest] FAIL %s" % label)
	get_tree().quit(1)
