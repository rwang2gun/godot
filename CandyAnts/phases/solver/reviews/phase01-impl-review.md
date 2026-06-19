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
