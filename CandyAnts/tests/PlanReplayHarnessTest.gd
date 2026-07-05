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
# after 트리거 by index 검증용 — action[1]이 action[0](index 0) 발화 후 50프레임 뒤 발화.
# index "0"이 _fired_frame에 기록돼 풀려야 둘 다 발화(actions_fired==2). S12는 blocker×3라 둘 다 적용 가능.
const PLAN_AFTER_INDEX := {
	"stage": "res://scenes/stages/Stage12.tscn",
	"deadline_frames": 7000,
	"actions": [
		{"skill": "blocker", "target": {"mode": "ant", "select": "min_x", "y_min": 584.0, "y_max": 648.0},
			"trigger": {"type": "ant_reaches_x", "cmp": "le", "x": 72.0}},
		{"skill": "blocker", "target": {"mode": "ant", "select": "max_x", "y_min": 0.0, "y_max": 99999.0},
			"trigger": {"type": "after", "ref": "0", "delay": 50}},
	],
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

	# ⑥ 같은 인스턴스 재진입 거부(codex R5 HIGH) — 첫 런 진행 중 run() 재호출은 첫 런 스테이지를
	#    교체/해제하지 않고(보존) no-op이어야 하고, 첫 런은 정상 완료해야 한다.
	var r6: PlanRunner = PlanRunner.new()
	add_child(r6)
	r6.run(PLAN_S11)                  # 첫 런 활성(_running=true)
	var stage_before: Node = r6._stage
	r6.run(PLAN_S11)                  # 재진입 — 거부(teardown/replace 없이)
	var stage_after: Node = r6._stage
	if stage_after == null or stage_before != stage_after:
		_failures.append("⑥ 재진입이 첫 런 스테이지를 교체/해제함(가드 우회): same=%s" % str(stage_before == stage_after))
	var r6res: Dictionary = await r6.finished
	r6.queue_free()
	await get_tree().process_frame
	if not bool(r6res.get("cleared", false)) or int(r6res.get("frame", -1)) != int(r1.get("frame", -2)):
		_failures.append("⑥ 첫 런이 재진입에 의해 변질됨: %s" % str(r6res))

	# ⑦ after 트리거 by index(codex R5 MED) — action[1]이 after{ref:"0"}로 action[0] 발화 후 지연 발화.
	#    index "0"이 _fired_frame에 기록돼 풀려야 둘 다 발화(actions_fired==2). 깨졌으면 1에 머문다.
	var r7: PlanRunner = PlanRunner.new()
	add_child(r7)
	r7.run(PLAN_AFTER_INDEX)
	var r7res: Dictionary = await r7.finished
	r7.queue_free()
	await get_tree().process_frame
	if int(r7res.get("actions_fired", -1)) != 2:
		_failures.append("⑦ after-by-index 미해결: actions_fired=%s (기대 2) — index ref가 _fired_frame에 없음?" % str(r7res.get("actions_fired")))

	# ⑧ repeat 액션이 after 앵커를 밀지 않는지(codex R6 MED) — repeat:true 액션의 _fired_frame은
	#    *첫 발화* 프레임에 고정돼야 한다(after = 첫 발화 + delay). 같은 액션을 non-repeat/repeat로 돌려
	#    앵커가 동일함을 확인(덮어쓰기 버그면 repeat 쪽이 마지막 발화 프레임으로 밀려 달라진다).
	var anchor_norepeat: int = await _anchor_frame(false)
	var anchor_repeat: int = await _anchor_frame(true)
	if anchor_norepeat <= 0 or anchor_repeat != anchor_norepeat:
		_failures.append("⑧ repeat 앵커 드리프트: norepeat=%d repeat=%d (첫 발화로 고정돼야 동일)" % [anchor_norepeat, anchor_repeat])

	# ⑨ 전역 deterministic 복원(codex R7 MED) — false에서 시작해 플랜 실행 후 false로 복원돼야(누수 0).
	#    PlanRunner는 실행 동안만 강제로 켜고(스테이지 결정론 보장), 종료 시 이전 값으로 되돌린다.
	SimConfig.set_deterministic(false)
	var r9: Dictionary = await _run(PLAN_S11)
	if SimConfig.deterministic != false:
		_failures.append("⑨ deterministic 미복원: run 후 %s (기대 false)" % str(SimConfig.deterministic))
	if not bool(r9.get("cleared", false)):
		_failures.append("⑨ 복원 케이스 S11 미클리어(실행 중엔 결정론이어야): %s" % str(r9))
	SimConfig.set_deterministic(true)   # 이후(없지만) 일관성 위해 원복

	# ⑩ 취소(queue_free) 시 전역 상태 복원(codex R8 MED) — 런 도중 free → _exit_tree가 deterministic
	#    복원·락 해제. finished 없이 끝나도 누수 0이어야 한다.
	SimConfig.set_deterministic(false)
	var r10: PlanRunner = PlanRunner.new()
	add_child(r10)
	r10.run(PLAN_S11)                  # 실행 시작(deterministic 강제 true, _active_run=r10)
	r10.queue_free()                   # 완료 전 취소
	await get_tree().process_frame     # queue_free 처리 → _exit_tree
	await get_tree().process_frame
	if SimConfig.deterministic != false:
		_failures.append("⑩ 취소 후 deterministic 미복원: %s (기대 false)" % str(SimConfig.deterministic))
	if PlanRunner._active_run != null and is_instance_valid(PlanRunner._active_run):
		_failures.append("⑩ 취소 후 _active_run 미해제: %s" % str(PlanRunner._active_run))
	SimConfig.set_deterministic(true)

	if _failures.is_empty():
		print("[PlanReplayHarnessTest] PASS — S11 cleared saved=%d/%d frame=%d (새×2 + 재사용×2 + 분리/출처 + 동시런거부 + 재진입거부 + after-by-index), empty negative" % [
			int(r1.get("saved", -1)), int(r1.get("hp", -1)), int(r1.get("frame", -1))])
		get_tree().quit(0)
	else:
		print("[PlanReplayHarnessTest] FAIL")
		for f in _failures:
			print("  - ", f)
		get_tree().quit(1)

# at_frame0 + max_x blocker를 repeat 유무로 돌려, 첫 발화 프레임(_fired_frame["0"])을 반환.
# repeat=true면 인벤토리 소진까지 여러 번 발화하지만, _mark_fired가 첫 발화로 고정하므로 값은 동일해야 한다.
func _anchor_frame(repeat: bool) -> int:
	var r: PlanRunner = PlanRunner.new()
	add_child(r)
	r.run({
		"stage": "res://scenes/stages/Stage12.tscn", "deadline_frames": 2000,
		"actions": [{
			"skill": "blocker", "repeat": repeat,
			"target": {"mode": "ant", "select": "max_x", "y_min": 0.0, "y_max": 99999.0},
			"trigger": {"type": "at_frame", "frame": 0},
		}],
	})
	await r.finished
	var f: int = int(r._fired_frame.get("0", -1))
	r.queue_free()
	await get_tree().process_frame
	return f

# PlanRunner를 자식으로 붙여 플랜 실행 → finished 대기 → 결과 반환 + runner 해제.
func _run(plan: Dictionary) -> Dictionary:
	var runner: PlanRunner = PlanRunner.new()
	add_child(runner)
	runner.run(plan)
	var result: Dictionary = await runner.finished
	runner.queue_free()
	await get_tree().process_frame
	return result
