extends Node

# 회귀 가드 (2026-06-20) — StageRunner._living_ant_count()가 종착(terminal) 개미를
# Ant.is_alive() 단일 진입점으로 일관 제외하는지 검증한다.
#
# 버그: _living_ant_count가 terminal 상태를 직접 나열(AdriftState/DeadState)하면서
#   SettledState(floater 낙하산 분배자 정착)를 빠뜨려, 분배자가 정착한 뒤 다른 개미가
#   모두 종착해도 "남은 개미"로 카운트돼 no_more_ants가 발화하지 못하고 time_limit까지
#   대기(time_out)했다. is_alive() 통일로 Saved/Dead/Settled/Lost/Adrift 모두 제외된다.
#
# 합성 환경: container(=_spawn_parent) 아래 walker 1 + settled 1 + adrift 1 + dead 1.
# PASS: _living_ant_count() == 1 (walker만). FAIL(=버그 재현): settled 등이 카운트돼 > 1.

const ANT_SCENE := preload("res://scenes/entities/Ant.tscn")

var _done: bool = false

func _ready() -> void:
	_run()

func _run() -> void:
	var container := Node2D.new()
	add_child(container)
	var runner := StageRunner.new()
	# get_tree().get_nodes_in_group 접근을 위해 트리에 둔다. stage_data가 null이라
	# StageRunner._ready는 push_error 후 곧장 return하지만(무해), 우리가 _spawn_parent를
	# 직접 주입하므로 _living_ant_count는 정상 동작한다.
	add_child(runner)
	runner._spawn_parent = container

	var walker: Ant = _spawn(container)
	var settled: Ant = _spawn(container)
	var adrift: Ant = _spawn(container)
	var dead: Ant = _spawn(container)
	# Ant._ready(그룹 등록 + WalkerState 초기화) 완료 보장.
	await get_tree().physics_frame
	await get_tree().physics_frame

	settled.state_machine.change_state(SettledState.new())
	adrift.state_machine.change_state(AdriftState.new())
	dead.state_machine.change_state(DeadState.new())
	await get_tree().physics_frame

	var count: int = runner._living_ant_count()
	if count == 1:
		_pass(walker)
	else:
		_fail("expected 1 living ant (walker only), got %d — terminal(settled/adrift/dead) 제외 실패" % count)

func _spawn(parent: Node) -> Ant:
	var a: Ant = ANT_SCENE.instantiate() as Ant
	parent.add_child(a)
	return a

func _pass(walker: Ant) -> void:
	if _done:
		return
	_done = true
	print("[LivingAntCountTerminalTest] PASS — _living_ant_count()==1, terminal 3종(settled/adrift/dead) 제외 (walker alive=%s)" % str(walker.is_alive()))
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _done:
		return
	_done = true
	print("[LivingAntCountTerminalTest] FAIL %s" % msg)
	get_tree().quit(1)
