extends Node

# Phase 8 Autoload — pause_toggle / step_frame 단일 소비자.
#
# 책임:
# - PAUSE_TOGGLE → tree.paused 토글 (stepping 중에는 ignore — race 방지)
# - STEP_FRAME → 정확히 한 physics tick 전진 후 다시 pause
#
# 설계:
# - `await tree.physics_frame`은 _physics_process 호출 직전에 emit.
#   같은 frame에서 paused=true로 되돌리면 physics가 skip될 수 있으므로
#   tick 실제 진행을 보장하기 위해 `physics_frame` 후 한 idle frame을 더 기다린다.
# - `_step_token`은 씬 전환/teardown 등에서 stale continuation이 현재 상태를
#   덮어쓰지 못하게 하는 소유권 표시.
# - stepping 중 PAUSE/RESTART/STEP 입력은 InputRouter._pause_actions_blocked
#   gate로 차단. SceneFlow direct RESTART_STAGE에도 2차 guard.

const GameAction := preload("res://scripts/input/GameAction.gd")

var _stepping: bool = false
var _step_token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.action_triggered.connect(_on_action)


func _exit_tree() -> void:
	_release_gate()


func is_stepping() -> bool:
	return _stepping


func _on_action(name: StringName, _payload: Dictionary) -> void:
	if name == GameAction.PAUSE_TOGGLE:
		if _stepping:
			return
		var tree: SceneTree = get_tree()
		if tree != null:
			tree.paused = not tree.paused
		return
	if name == GameAction.STEP_FRAME:
		_step_frame_once()


func _step_frame_once() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not tree.paused:
		return
	if _stepping:
		return

	_stepping = true
	_step_token += 1
	var token: int = _step_token

	_acquire_gate()

	# Catch-up 안전한 1-tick 계약 (codex impl-review Round 1 HIGH):
	# - physics_frame 시그널은 같은 tick의 _physics_process 호출 직전에 emit된다.
	# - tick N: 첫 await에서 시그널 emit → coroutine resume → 다음 라인(두 번째 await)에서
	#   다시 yield → _physics_process 루프는 paused=false인 채로 실행 → DummyPhysics 등
	#   PROCESS_MODE_INHERIT/PAUSABLE 자식 노드의 _physics_process가 1회 호출.
	# - tick N+1: 두 번째 await에서 시그널 emit → coroutine resume → paused=true 설정
	#   → 같은 tick의 _physics_process 루프는 paused=true를 보고 skip.
	# - 결과: 정확히 1회의 _physics_process 호출 보장. 엔진 catch-up으로 tick N과 N+1이
	#   같은 main loop iteration에 연속 emit되어도 tick N+1의 _physics_process가 skip되므로
	#   N 1회만 카운트됨.
	tree.paused = false
	await tree.physics_frame  # tick N signal — 그 직후 tick N의 _physics_process 진행
	await tree.physics_frame  # tick N+1 signal — coroutine이 _physics_process 호출 전에 끼어듦
	if token == _step_token and is_inside_tree():
		var tree2: SceneTree = get_tree()
		if tree2 != null:
			tree2.paused = true  # tick N+1의 _physics_process 루프는 paused=true 보고 skip

	if token == _step_token:
		_stepping = false
		_release_gate()


func _acquire_gate() -> void:
	if InputRouter != null and InputRouter.has_method("set_pause_actions_blocked"):
		InputRouter.set_pause_actions_blocked(true)


func _release_gate() -> void:
	if InputRouter != null and InputRouter.has_method("set_pause_actions_blocked"):
		InputRouter.set_pause_actions_blocked(false)
