extends Node
# carry-mode fix dynamic verification — Stage01을 자동 진행하면서 carry+fall+landing 시점에
# ant.state가 CarryingState인지(✅) WalkerState인지(❌) 검증.
#
# fix가 작동하면: FallerState floor 안착 → Ant.return_to_walking() → has_candy 분기 → CarryingState.
# fix 없으면: floor 안착 → WalkerState 직접 전이 → sprite "walk" 잘못 표시.
#
# Headless 실행. Exit code: 0=PASS, 1=FAIL, 2=BLOCKED.

const DEADLINE_FRAMES: int = 5400  # 90s @ 60fps

var _frame: int = 0
var _result_done: bool = false
var _tracked_ant: Ant = null  # has_candy + FallerState로 관찰된 ant
var _tracked_was_falling: bool = false

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/stages/Stage01.tscn")
	if ps == null:
		print("[CarryFallTest] BLOCKED: Stage01 load failed")
		get_tree().quit(2)
		return
	add_child(ps.instantiate())
	print("[CarryFallTest] driver ready — Stage01 instantiated")

func _physics_process(_delta: float) -> void:
	if _result_done:
		return
	_frame += 1

	# 모든 살아있는 ant에 climber trait 자동 부여
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.is_alive() and not a.has_trait(&"climber"):
			var skill: ClimberSkill = ClimberSkill.new()
			if skill.can_apply(a):
				skill.apply(a)

	# carry+fall+landing 사이클 추적
	_check_carry_fall_landing()

	if _frame > DEADLINE_FRAMES:
		print("[CarryFallTest] BLOCKED: deadline exceeded — no carry+fall+landing cycle observed")
		_result_done = true
		get_tree().quit(2)

func _check_carry_fall_landing() -> void:
	# Phase 1: carrying ant가 FallerState 진입한 순간 추적
	if _tracked_ant == null or not is_instance_valid(_tracked_ant):
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a == null or not is_instance_valid(a):
				continue
			if a.has_candy and a.state_machine != null \
					and a.state_machine.current_state is FallerState:
				_tracked_ant = a
				_tracked_was_falling = true
				print("[CarryFallTest] frame=%d carrying ant entered FallerState — tracking" % _frame)
				return
		return

	# Phase 2: 추적된 ant가 fall 종료 후 어떤 state로 전이됐는지 확인
	if not _tracked_was_falling:
		return
	if _tracked_ant.state_machine == null:
		return
	var s: AntState = _tracked_ant.state_machine.current_state
	if s is FallerState:
		# 아직 떨어지는 중
		return
	# Fall 종료 — has_candy 보존된 채 어떤 state?
	_result_done = true
	if not _tracked_ant.has_candy:
		# fall 도중 사탕 잃음 (hazard 등). 검증 무효.
		print("[CarryFallTest] BLOCKED: ant lost candy during fall — unable to verify post-fall state")
		get_tree().quit(2)
		return
	if s is CarryingState:
		print("[CarryFallTest] PASS frame=%d: post-fall state=CarryingState (helper return_to_walking fix works)" % _frame)
		get_tree().quit(0)
	elif s is WalkerState:
		print("[CarryFallTest] FAIL frame=%d: post-fall state=WalkerState despite has_candy=true (bug not fixed)" % _frame)
		get_tree().quit(1)
	else:
		print("[CarryFallTest] BLOCKED frame=%d: unexpected post-fall state=%s" % [_frame, s.get_class()])
		get_tree().quit(2)
