extends Node

# Phase 4 (intro-card-infra) — StageRunner.begin() 게이트 검증. STAGE_GUIDE_PLAN §2.3 방식2.
#   (1) auto_begin=false면 _ready가 spawn/timer를 시작하지 않는다(카드 대기 모사).
#   (2) begin() 호출 시 spawn 시작 + 타이머 진행.
#   (3) begin() 재호출은 멱등 — spawner를 재시작하지 않는다(정확히 1회 시작).

const Stage01Scene := preload("res://scenes/stages/Stage01.tscn")

var _failed: bool = false

func _ready() -> void:
	Engine.time_scale = 20.0
	var stage = Stage01Scene.instantiate()
	# ★ add_child(=_ready) 전에 auto_begin=false 설정 → _ready가 spawn을 시작하지 않음.
	stage.auto_begin = false
	add_child(stage)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# (1) 게이트 — begin 전: 미시작 + 스폰 0 + 타이머 정지
	if stage.is_begun():
		return _fail("expected not begun before begin()")
	if _ant_count() != 0:
		return _fail("expected 0 ants before begin(), got %d" % _ant_count())
	if not is_equal_approx(stage._time_left, stage.stage_data.time_limit_seconds):
		return _fail("timer advanced before begin(): %f != %f" % [stage._time_left, stage.stage_data.time_limit_seconds])

	# 스폰 가속 — spawner 인스턴스에만 적용(.tres resource 미변경).
	stage._spawner.set_release_rate(99)

	# (2) begin() → 스폰 시작
	stage.begin()
	if not stage.is_begun():
		return _fail("is_begun() false right after begin()")

	var waited: float = 0.0
	while stage._spawner._spawned < 2 and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if stage._spawner._spawned < 2:
		return _fail("spawner did not spawn >=2 within budget (spawned=%d)" % stage._spawner._spawned)
	var spawned_snapshot: int = stage._spawner._spawned

	# (3) begin() 재호출 멱등 — spawner 재시작(=_spawned 리셋) 없음
	stage.begin()
	await get_tree().process_frame
	if stage._spawner._spawned < spawned_snapshot:
		return _fail("second begin() restarted spawner (spawned %d < snapshot %d)" % [stage._spawner._spawned, spawned_snapshot])
	if not stage.is_begun():
		return _fail("is_begun() false after second begin()")

	# 타이머도 begin 후 진행
	if stage._time_left >= stage.stage_data.time_limit_seconds:
		return _fail("timer did not advance after begin()")

	Engine.time_scale = 1.0
	print("[StageRunnerBeginGateTest] PASS spawned=%d time_left=%.2f" % [stage._spawner._spawned, stage._time_left])
	get_tree().quit(0)

func _ant_count() -> int:
	return get_tree().get_nodes_in_group("ants").size()

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	Engine.time_scale = 1.0
	print("[StageRunnerBeginGateTest] FAIL ", msg)
	get_tree().quit(1)
