extends Node

# auto-solver Phase 1 — PlanRunner in-process 회귀 테스트.
# ① 양성: S11 blocker 플랜이 무수정 게임 verdict로 클리어(saved>=hp). PlanRunner 충실성.
# ② 배치 상태누수 0: 같은 플랜을 새 PlanRunner로 2회 → byte-identical(frame·saved 동일)이어야 한다.
#    (1회차의 개미/시그널이 2회차로 새면 frame/saved가 달라짐 → 누수 검출.)
# ③ 음성: 빈 플랜은 미클리어(actions_fired=0). 하니스가 실패를 충실히 보고.
#
# 결정론·in-process. run_test.py 기본(--fixed-fps 없음)으로 돌려도 결정론 모드(SimConfig)가 시계를 프레임화.

const PLAN_S11 := {
	"stage": "res://scenes/stages/Stage11.tscn",
	"deadline_frames": 7000,
	"actions": [
		{
			"skill": "blocker",
			"target": {"mode": "ant", "select": "max_x", "y_min": 520.0, "y_max": 99999.0, "dir": 0},
			"trigger": {"type": "ant_reaches_x", "cmp": "ge", "x": 960.0},
		},
	],
}
const PLAN_EMPTY := {
	"stage": "res://scenes/stages/Stage11.tscn",
	"deadline_frames": 7000,
	"actions": [],
}

var _failures: Array[String] = []

func _ready() -> void:
	# 결정론 모드 강제(in-process — 헤드리스 env 없이도). PlanRunner.run도 켜지만 명시.
	SimConfig.set_deterministic(true)

	var r1: Dictionary = await _run(PLAN_S11)
	if not bool(r1.get("cleared", false)):
		_failures.append("① S11 not cleared: %s" % str(r1))
	if int(r1.get("saved", -1)) < int(r1.get("hp", 999)):
		_failures.append("① S11 saved(%s) < hp(%s)" % [r1.get("saved"), r1.get("hp")])
	if int(r1.get("actions_fired", -1)) != 1:
		_failures.append("① S11 actions_fired != 1: %s" % str(r1.get("actions_fired")))

	# ② 두 번째 실행(새 PlanRunner) — 상태누수 0이면 byte-identical.
	var r2: Dictionary = await _run(PLAN_S11)
	if int(r2.get("frame", -1)) != int(r1.get("frame", -2)):
		_failures.append("② batch leak: frame r1=%s r2=%s" % [r1.get("frame"), r2.get("frame")])
	if int(r2.get("saved", -1)) != int(r1.get("saved", -2)):
		_failures.append("② batch leak: saved r1=%s r2=%s" % [r1.get("saved"), r2.get("saved")])

	# ③ 음성 — 빈 플랜은 미클리어.
	var r3: Dictionary = await _run(PLAN_EMPTY)
	if bool(r3.get("cleared", true)):
		_failures.append("③ empty plan unexpectedly cleared: %s" % str(r3))
	if int(r3.get("actions_fired", -1)) != 0:
		_failures.append("③ empty plan actions_fired != 0: %s" % str(r3.get("actions_fired")))

	if _failures.is_empty():
		print("[PlanReplayHarnessTest] PASS — S11 cleared saved=%d/%d frame=%d (×2 identical), empty negative" % [
			int(r1.get("saved", -1)), int(r1.get("hp", -1)), int(r1.get("frame", -1))])
		get_tree().quit(0)
	else:
		print("[PlanReplayHarnessTest] FAIL")
		for f in _failures:
			print("  - ", f)
		get_tree().quit(1)

# PlanRunner를 자식으로 붙여 플랜 실행 → finished 대기 → 결과 반환 + runner 해제.
func _run(plan: Dictionary) -> Dictionary:
	var runner: PlanRunner = PlanRunner.new()
	add_child(runner)
	runner.run(plan)
	var result: Dictionary = await runner.finished
	runner.queue_free()
	await get_tree().process_frame
	return result
