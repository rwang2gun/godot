# Phase 1 impl-stage 적대적 리뷰 (codex)

리뷰 대상: auto-solver `3004ce5` (Phase 1), base=HEAD~1(493940b). codex-companion adversarial-review --base HEAD~1.

## Round 1 (codex, needs-attention)

```
# Codex Adversarial Review

Target: branch diff against HEAD~1
Verdict: needs-attention

No-ship: PlanRunner can misattribute stale stage results across reused/interrupted runs, and the new golden selftest can pass while SIGN/DEVICE behavior is broken.

Findings:
- [high] PlanRunner can leave an old stage running and accept its global verdict as the new run's result (CandyAnts/scripts/core/PlanRunner.gd:57-81)
  `run()` calls `_reset_state()` before creating the next stage, but `_reset_state()` only nulls bookkeeping; it does not disconnect EventBus handlers or free an already-running `_stage`. If the same PlanRunner is reused before the previous run finishes, the old StageRunner remains in the tree and can later emit global `stage_cleared`/`stage_failed`; the newly reconnected PlanRunner has no stage identity check in `_on_cleared`/`_on_failed`, so it can finish the new plan with the stale stage's verdict. Even after normal completion, `_finish()` uses `queue_free()` and emits `finished` in the same frame, so a caller that starts the next run from the `finished` callback can race the deferred deletion. Impact: batch replay can produce false clears/fails and corrupt solver training/evaluation data in a way that looks like a valid game verdict.
  Recommendation: Add an explicit teardown path before every `run()` that disconnects handlers and immediately removes/frees any prior stage, or reject `run()` while `_running`/pending free. Also bind verdicts to the active stage/run token and ignore EventBus results not emitted by the current run.
- [medium] The batch leak regression test does not exercise the documented reusable PlanRunner path (CandyAnts/tests/PlanReplayHarnessTest.gd:42-73)
  The test claims to cover batch state leakage, but `_run()` creates a new `PlanRunner` for every execution and waits a process frame after freeing it. That avoids the actual reuse/race path in `PlanRunner` where deferred stage cleanup or a second `run()` on the same runner can leak stale signals. This leaves the highest-risk lifecycle invariant untested while still printing PASS for batch leak coverage.
  Recommendation: Add a test that reuses the same PlanRunner instance for consecutive runs, including starting the second run from the first `finished` callback or before the old stage's queued free has processed, and assert stale EventBus results cannot complete the new run.
- [medium] SIGN/DEVICE golden plans can pass even if the installed skill never solves anything (CandyAnts/scripts/run_plan.py:50-63)
  `run_plan.py --selftest` treats any expectation as authoritative, including `cleared: false`, and the current SIGN/DEVICE golden entries expect failure with only `actions_fired: 1`. That means a regression where `SkillApplier.place_on_cell()` installs the wrong node, the sign never triggers, or the device effect is broken can still PASS because placement consumed one action and the stage remained uncleared exactly as expected. This is a false confidence risk for the SkillApplier equivalence and game-verdict fidelity focus area.
  Recommendation: Require at least one positive golden for each cell-target category that clears via the installed SIGN/DEVICE effect, or extend expects with effect-level invariants such as tile changes, jump/cut/build occurrence, saved/lost thresholds, and final cleared verdict.

Next steps:
- Block shipping until PlanRunner teardown/run-token isolation is fixed and covered by a same-runner reuse test.
- Replace or augment the failing SIGN/DEVICE goldens with positive verdict-bearing cases.
```

## R1 대응 (수정)
- **HIGH (PlanRunner stale stage/verdict 오귀속)**: EventBus 연결을 `run()`→`_ready` 1회로 이동(수명 연결, 해제 안 함). `run()` 진입 시 `_teardown()`로 직전/중단 스테이지를 트리에서 즉시 remove_child+free → stale 스테이지가 새 런에 verdict 흘리는 race 차단. verdict/pickup 핸들러에 `_running` 가드 추가. 단일-스테이지 불변식(한 시점 살아있는 스테이지 1개 + StageRunner conclude 1회)으로 run-token 없이 귀속 보장.
- **MED (배치 누수 테스트가 재사용 경로 미검증)**: `PlanReplayHarnessTest`에 ④ 추가 — 같은 PlanRunner 인스턴스를 finished 직후 같은 프레임에 재실행, r1(새 인스턴스) 대비 frame·saved·actions_fired 동일 단언(teardown race 회귀 가드).
- **MED (SIGN/DEVICE 골든 허위 PASS 여지)**: effect-level 불변식 추가 — S05 sand_mound `picked:true`+`max_best_min_y:300`(빈 플랜 baseline picked=false·520 대비 사다리 작동 핀), S08 leaf_jump `max_best_min_y:450`(baseline 472 대비 점프 발동 핀). `run_plan.py` check_expect에 `picked`/`max_best_min_y` 지원.

## Self-Review Round 1 (clean)
가혹 점검 — finished 콜백 내 재실행 시 free 안전성(emit 전 _stage=null), 두 인스턴스 동시 연결(끝난 쪽 _running=false 무시), in-flight 중단 재실행(teardown 즉시 free), effect-invariant 변별 마진(520/472 vs 300/450), 라이브 게임 회귀(PlanRunner 솔버 전용·미사용). **HIGH/CRITICAL 0건.** 게이트 재실행 GREEN(결정론2 + PlanReplayHarnessTest[새×2+재사용×2] + SkillMetadataDriftTest + selftest 5골든).

## Round 2 (codex, needs-attention)

```
# Codex Adversarial Review

Target: branch diff against 493940b
Verdict: needs-attention

No-ship: the stale-stage fix is not actually closed, and the new reuse test can pass while the broken cleanup remains in place.

Findings:
- [high] Queued old stage is no longer reachable for teardown on immediate reuse (CandyAnts/scripts/core/PlanRunner.gd:357-364)
  `_finish()` calls `_stage.queue_free()` and immediately sets `_stage = null`. Because `queue_free()` is deferred, a caller that starts the next `run()` from the `finished` continuation enters `_teardown()` with no reference to the old queued stage, so the old stage is not removed from the tree before the new stage is added. The `_running` guard is then true for the new run, so any late `stage_cleared`/`stage_failed` emission from the old stage would be accepted and reported as the new run's verdict. This is the exact stale-verdict class the change claims to close; the code comment says the next run's `_teardown` will force cleanup, but line 364 makes that impossible.
  Recommendation: Detach the stage from the tree synchronously before deferring deletion, e.g. `parent.remove_child(_stage); _stage.queue_free()`, or keep a pending reference that `_teardown()` can remove. Also add a per-run token/source check so EventBus verdicts from non-current stages are ignored rather than relying only on single-stage lifetime assumptions.
- [medium] Reuse regression test does not force the stale-callback race it claims to cover (CandyAnts/tests/PlanReplayHarnessTest.gd:62-65)
  The reuse path awaits the first `finished`, immediately calls `reuse.run(PLAN_S11)`, then awaits the second `finished`. That only proves two happy-path S11 runs are byte-stable. It does not create or assert a late verdict from the old queued stage while `_running` is true for the second run, and it does not assert that the old stage was removed from the tree. With the current `_finish()` bug, this test can still pass because the old StageRunner has already set `_completed` and normally emits only once.
  Recommendation: Make the test adversarial: after the second `run()` starts, inject a stale `EventBus.stage_failed`/`stage_cleared` emission or use a minimal test stage that emits a deferred verdict after `finished`, and assert it is ignored. Also assert there is only one live stage subtree immediately after reuse starts.

Next steps:
- Fix PlanRunner cleanup before relying on `_running` as a verdict ownership guard.
- Replace the reuse test with a deterministic stale-emission test that fails against the current implementation.
```

## R2 대응 (수정)
- **HIGH (큐된 옛 스테이지가 즉시 재사용 시 teardown 불가 → late verdict 수락)**: `_finish`가 `queue_free`만 하고 `_stage=null` 해 다음 `_teardown`이 옛 스테이지를 못 잡던 문제. → `_finish`에서 **동기 `remove_child` 후 queue_free**(분리 즉시 _process/emit 정지). 추가로 verdict 출처 가드 `_is_foreign_verdict` 신설 — 결과 `stage_id`가 현재 런 스테이지(StageData.id)와 다르면 무시(단일-스테이지 lifetime 가정에만 의존하지 않음). `_on_cleared`/`_on_failed`에 적용.
- **MED (재사용 테스트가 race 미강제)**: `PlanReplayHarnessTest` ④를 적대적으로 — ④a 재실행 직후 reuse 하위 살아있는 StageRunner==1 단언(옛 스테이지 분리 검증), ④b foreign stage_id의 stale `_on_failed`/`_on_cleared` 주입 → 무시(현재 런이 STALE로 끝나지 않음) 단언.

## Self-Review Round 2 (clean)
_finish의 remove_child가 stage_cleared 콜백 중 안전한지(S11/S12 정상 클리어로 확인), stage_id 가드의 실제 verdict 오거부 없음(전 골든 통과·미상 폴백 수락), ④ 검출력(미분리 2개/ foreign 수락 시 FAIL). 게이트 GREEN(결정론2 + PlanReplayHarnessTest[새×2+재사용×2+분리+출처가드] + SkillMetadataDriftTest + selftest 5골든). **HIGH/CRITICAL 0건.**

## R3 대응 (수정)
- **HIGH (stage_id 가드가 stable StageData.id라 같은 스테이지 stale/동시 런 미구분)**: verdict 수신을 글로벌 EventBus → **인스턴스-스코프 시그널**로 전환. StageRunner에 가산적 `signal concluded(result)` 추가(글로벌 stage_cleared/failed는 그대로 emit; 같은 결과 dict를 인스턴스 시그널로도 발행, 게임 동작·D4 불변). PlanRunner는 run()에서 *자기 스테이지의* StageRunner.concluded만 연결 → 다른/stale 스테이지 verdict가 구조적으로 닿지 않음. `_is_foreign_verdict`/`_expected_stage_id`/글로벌 verdict 핸들러 제거. `_teardown`/`_finish`가 인스턴스 시그널 해제.
- **테스트 강화**: ④a 재실행 직후 살아있는 StageRunner==1(분리), ④b 같은 stage_id(11) stale verdict를 *글로벌 버스*에 주입 → 무시 단언(인스턴스 스코프 증명, codex R3 시나리오 직접 반증).

## Self-Review Round 3 (clean)
StageRunner 변경의 게임 회귀(S11/S13/BeginGate/ToolbarDisable/SandMound·LeafJumpSign PASS = 동작 불변), 결과 dict 1회 빌드 동치, concluded 1회 emit(_completed 가드), 인스턴스 시그널 연결/해제 수명, sr=null 폴백(deadline). **HIGH/CRITICAL 0건.** 게이트+회귀 GREEN.

## R4 대응 (수정)
- **HIGH (concluded verdict가 글로벌-오염 가능한 ScoreSystem에서 계산됨) + MED (picked_ge가 글로벌 candy 이벤트 cross-talk)**: 둘 다 **한 프로세스에 두 스테이지가 동시 생존**할 때만 발생. 우리 아키텍처는 그런 적이 없다 — 게임은 스테이지 1개, 솔버 병렬화는 `run_plan.py`가 **별도 subprocess + CANDYANTS_SAVE_PATH pid 격리**로 띄움(프로세스마다 autoload 독립). ScoreSystem(CRITICAL 4-카운터 게임 코드)을 스테이지-스코프로 재설계하는 건 Phase 1 범위 밖·회귀 위험 큼. → **비례적 정공법**: PlanRunner에 `static _active_run` 단일-활성-런 가드 — 다른 PlanRunner 활성 중 run()은 error로 거부. 동시 in-process 런(=오염의 전제)을 구조적으로 제거. ScoreSystem/picked는 단일 스테이지만 생존하므로 글로벌이라도 모호하지 않음. 게임 코드 무변경.
- **테스트**: ⑤ A 진행 중 B.run()→B error 거부 + A는 r1과 동일(오염 0) 단언.

## Self-Review Round 4 (clean)
가드 락 획득/해제(run 끝·_finish·_teardown), B 거부 시 A·_active_run 불간섭, deadline 경로도 _finish로 해제, static 락 테스트 간 누수 없음(순차 해제). 동시성 전제 제거가 HIGH/MED 둘 다 닫음. ScoreSystem 재설계는 범위 밖(아키텍처상 동시 in-process 스테이지 없음)으로 의도적 미수행. 게이트 GREEN(가드 테스트 ⑤ 포함). **HIGH/CRITICAL 0건.**

## R5 대응 (수정)
- **HIGH (같은 인스턴스 재진입이 가드 우회)**: `_active_run != self` 가드는 같은 인스턴스 재호출을 막지 못해, 첫 런 진행 중 run() 재호출 시 teardown→첫 런이 finished 없이 중단(await hang). → run()에 `if _running:` 분기 추가 — 첫 런 진행 중이면 teardown/emit 없이 거부(첫 런 보존). 다른-인스턴스 케이스는 종전대로 자기 finished({error}).
- **MED (after{ref:index} 미해결)**: 액션이 `_label=skill#i`만 기록해 index 참조가 `_fired_frame`에 없어 영영 안 풀림. → `_mark_fired`가 label·index(문자열) 두 키 모두 기록. 액션에 `_index` 저장 + 명시 `label` 필드 지원. after.ref가 label/index 어느 쪽이든 해결.
- **테스트**: ⑥ 재진입 시 첫 런 스테이지 보존(stage_before==stage_after) + 첫 런 정상 완료 단언. ⑦ after{ref:"0"}로 둘째 액션 지연 발화(actions_fired==2) 단언.

## Self-Review Round 5 (clean)
재진입 가드(첫 런 보존·emit 없음), 다른-인스턴스 emit 분리, after 두-키 기록의 label/index 양립, 게임 코드 무변경(회귀 0). 게이트 GREEN(⑥⑦ 포함 PlanReplayHarnessTest + drift + selftest). **HIGH/CRITICAL 0건.**

## R6 대응 (수정, HIGH 0 / MED 1)
- **MED (repeat 액션이 after 앵커를 덮어씀)**: `_mark_fired`가 매 발화마다 `_fired_frame`을 덮어써, repeat:true 액션을 참조하는 after가 "첫 발화+delay"가 아니라 마지막 발화까지 밀림. → `_fired_frame`은 **키 부재 시에만 기록**(첫 발화 고정). `_actions_fired`는 종전대로 발화마다 증가(카운트).
- **테스트**: ⑧ 같은 at_frame0/max_x blocker를 non-repeat/repeat로 돌려 `_fired_frame["0"]`(첫 발화 프레임)이 동일함을 단언(덮어쓰기면 repeat 쪽이 마지막 발화로 밀려 불일치).

## Self-Review Round 6 (clean)
첫-발화 고정(record-if-absent), actions_fired 카운트 의미 불변(⑦ non-repeat 여전히 2), 게임 코드 무변경. 게이트 GREEN(⑧ 포함 PlanReplayHarnessTest + selftest). **HIGH/CRITICAL 0건.**

## R7 대응 (수정, HIGH 0 / MED 1)
- **MED (전역 deterministic 미복원)**: PlanRunner가 `SimConfig.set_deterministic(true)`를 강제하나 복원 안 해, in-process 호출 시 이후 게임 타이밍이 결정론 모드로 누수. → `_prior_deterministic`/`_det_forced`로 *우리가 켠 경우에만* 종료 시(`_finish`·`_teardown`·load-error) 이전 값 복원(`_restore_deterministic`, 멱등). 캡처는 _teardown(복원) 후 현재값.
- **테스트**: ⑨ deterministic=false에서 시작 → 플랜 실행(중엔 결정론) → 종료 후 false 복원 단언 + 클리어 확인.

## Self-Review Round 7 (clean)
_det_forced 표식으로 우리가 켠 경우만 복원(env/외부 true 오버라이드 안 함), 멱등 복원, 정상/중단/에러 종료 모두 복원, DeterminismReplayTest·CampaignS11 회귀 0(SimConfig 복원은 솔버 경로 한정). 게이트 GREEN(⑨ 포함). **HIGH/CRITICAL 0건.**
