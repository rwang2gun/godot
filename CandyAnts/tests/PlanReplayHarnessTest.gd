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

	# ④ 같은 PlanRunner 인스턴스 재사용 — finished 직후 *같은 프레임*에 재실행(이전 스테이지의
	#    queue_free 미처리 상태). _teardown이 stale 스테이지를 강제 정리하지 못하면 verdict 오귀속/
	#    상태누수로 결과가 r1과 달라진다(codex R1 HIGH 회귀 가드). 새 인스턴스를 쓰는 _run과 달리
	#    여기선 한 reuse 인스턴스를 두 번 돌린다.
	var reuse: PlanRunner = PlanRunner.new()
	add_child(reuse)
	reuse.run(PLAN_S11)
	var ra: Dictionary = await reuse.finished
	# finished 직후 같은 인스턴스 재실행 — _finish가 옛 스테이지를 *동기 분리*했어야 한다(codex R2 HIGH).
	reuse.run(PLAN_S11)
	# ④a 분리 단언: 재실행 직후 reuse 하위 살아있는 StageRunner는 새 것 1개뿐(옛 것은 트리서 제거됨).
	#    옛 스테이지가 남아있으면(누수) 2개 → 그건 late verdict를 흘릴 수 있는 상태.
	var live_stages: int = reuse.find_children("*", "StageRunner", true, false).size()
	if live_stages != 1:
		_failures.append("④a 재실행 후 살아있는 스테이지 %d개(기대 1) — 옛 스테이지 미분리(누수)" % live_stages)
	# ④b 출처(provenance): PlanRunner는 글로벌 EventBus가 아니라 자기 스테이지의 concluded(인스턴스
	#    시그널)만 듣는다. *같은 stage_id(11)*의 stale verdict를 글로벌 버스에 주입해도 무시돼야 한다
	#    (codex R3가 우려한 "같은 스테이지 stale verdict" 시나리오 — 인스턴스 스코프라 닿지 않음).
	#    테스트 씬엔 SceneFlow 없음. SaveData는 pid-격리 throwaway 저장이라 무해.
	EventBus.stage_failed.emit({"stage_id": 11, "reason": "STALE_GLOBAL", "saved": 0, "original_hp": 4})
	EventBus.stage_cleared.emit({"stage_id": 11, "reason": "STALE_GLOBAL", "saved": 4, "original_hp": 4, "cleared": true})
	var rb: Dictionary = await reuse.finished
	reuse.queue_free()
	await get_tree().process_frame
	if not bool(ra.get("cleared", false)) or not bool(rb.get("cleared", false)):
		_failures.append("④ reuse: cleared ra=%s rb=%s" % [ra.get("cleared"), rb.get("cleared")])
	if str(rb.get("reason", "")) == "STALE_GLOBAL":
		_failures.append("④b 글로벌 버스 stale verdict가 수락됨 — PlanRunner가 인스턴스 시그널만 듣지 않음")
	if int(ra.get("frame", -1)) != int(r1.get("frame", -2)) or int(rb.get("frame", -1)) != int(r1.get("frame", -3)):
		_failures.append("④ reuse frame drift(=상태누수): r1=%s ra=%s rb=%s" % [r1.get("frame"), ra.get("frame"), rb.get("frame")])
	if int(rb.get("saved", -1)) != int(r1.get("saved", -2)) or int(rb.get("actions_fired", -1)) != 1:
		_failures.append("④ reuse drift: saved rb=%s(want %s) actions_fired=%s(want 1)" % [rb.get("saved"), r1.get("saved"), rb.get("actions_fired")])

	# ⑤ 동시 in-process 런 거부(codex R4 HIGH) — A 진행 중 B.run()은 error로 거부되고, A는 오염 없이
	#    정상 완료(r1과 동일)해야 한다. 단일-활성-런 가드가 ScoreSystem/picked 글로벌 cross-talk의 전제를 막음.
	var rA: PlanRunner = PlanRunner.new()
	add_child(rA)
	var rB: PlanRunner = PlanRunner.new()
	add_child(rB)
	var b_results: Array = []
	rB.finished.connect(func(res: Dictionary) -> void: b_results.append(res))
	rA.run(PLAN_S11)   # A가 단일 활성 락 획득
	rB.run(PLAN_S11)   # B는 거부 → 동기 finished({error})
	var resA: Dictionary = await rA.finished
	rA.queue_free()
	rB.queue_free()
	await get_tree().process_frame
	if b_results.is_empty() or not (b_results[0] as Dictionary).has("error"):
		_failures.append("⑤ 동시 런 B가 거부되지 않음(가드 실패): %s" % str(b_results))
	if not bool(resA.get("cleared", false)) or int(resA.get("frame", -1)) != int(r1.get("frame", -2)) or int(resA.get("saved", -1)) != int(r1.get("saved", -3)):
		_failures.append("⑤ 동시 런이 A를 오염: resA=%s (기대 r1=%s)" % [str(resA), str(r1)])

	if _failures.is_empty():
		print("[PlanReplayHarnessTest] PASS — S11 cleared saved=%d/%d frame=%d (새 인스턴스 ×2 + 재사용 ×2 + 분리/출처가드 + 동시런 거부), empty negative" % [
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
