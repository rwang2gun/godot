# Phase 6 Impl Review — game-flow-foundation

작성일: 2026-05-10
대상: phase 6 구현 (working tree 미커밋 상태). plan 통과 후 §11 작업 순서 그대로 구현 + 헤드리스 회귀 PASS.

회귀 테스트 결과:
- `tests/test_ScoreSystem.tscn` — PASS
- `tests/Stage02HeadlessTest.tscn` — PASS (Dictionary 시그니처 적용 후)
- `tests/Stage03HeadlessTest.tscn` — PASS (동일)
- `tests/GameFlowTest.tscn` — PASS (4 시나리오 A/B/C/D)

## Pre-codex 자체 적대적 리뷰

검토 범위: EventBus / StageRunner / SceneFlow / StageResultOverlayStub / Main.tscn / project.godot / Stage02·03 HeadlessTest / GameFlowTest / TDD 스텁.

검토 기준: codex와 동일 (CRITICAL/HIGH/MEDIUM/LOW + hypothetical 위험 + cross-doc 일관성 + dead branch + circular SoT).

핵심 점검 항목:
- EventBus signal 시그니처 변경 후 receiver 전체 grep — 모두 새 Dictionary 시그니처 (StageRunner emit only / SceneFlow / Stage02·03 / GameFlowTest), HUD/SkillToolbar 등은 stage 결과 signal에 connect 안 함. shim 없이 한 번에 갈아엎음 (plan §2.1 의도)
- StageRunner self-receiver 제거 — `_on_stage_cleared`/`_on_stage_failed` 함수와 connect 두 줄 모두 삭제, emit만 남음
- 1-frame stage overlap × ant counting — `_living_ant_count`이 `_spawn_parent.is_ancestor_of(n)` 자손 스코프 (codex R1 HIGH 대응 적용 확인)
- Failed stage Next 우회 차단 — overlay `show_result`의 `_next.disabled = is_last_stage or not result["cleared"]` (1차 방어) + SceneFlow `_on_request_next`의 `_last_result.get("cleared", false)` 가드 (2차 방어). `load_stage`에서 `_last_result = {}` reset (codex R2 HIGH 대응 적용 확인). GameFlowTest 시나리오 C에서 UI disabled + signal reject 양쪽 검증
- Process freeze/unfreeze — `_current_stage_root.process_mode = DISABLED/INHERIT`, GlobalUI(CanvasLayer)는 별 부모이므로 overlay 정상 동작. 시나리오 D 인라인 검증
- `_make_result` Dictionary 8키 모두 채움, `stage_data == null` early return 가드로 _process가 호출되는 분기에서는 `stage_data` 항상 valid
- ScoreSystem 누수 — Phase 5 sweep `_exit_tree`의 `score_system.stop()` 유지
- HUD `show_dialog` 호출 제거 (StageRunner) — HUD는 in-stage 정보 표시용으로 유지, AcceptDialog 노드는 Phase 12까지 unused (plan §1.3 의도)

LOW 후보:
- `Engine.time_scale = 8.0` 헤드리스 가속이 driver에서 set 후 reset 없음 (single-process로 종료되므로 영향 없음)
- AntSpawner.spawn_finished 이중 emit 가능성 — `_spawner_finished = true` set은 idempotent
- `result["cleared"]` 직접 인덱스 접근 — production에서 emit 경로가 `_make_result` 단일이므로 누락 없음

자체 리뷰 verdict: **clean (HIGH 0)**. codex impl review 진행.

---

## Round 1 (codex impl)

작성일: 2026-05-10
verdict: needs-attention (MEDIUM 1건, CRITICAL/HIGH 0건)

(node:24296) [DEP0190] DeprecationWarning ...
[codex] Thread ready (019e103b-1f79-7412-93c3-c21569202443).
[codex] Running command: pwsh git status --short / git diff / findstr StageRunner / SceneFlow / StageResultOverlayStub / AntSpawner / Stage scenes — all completed exit 0.

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the new no_more_ants path can be silently bypassed on an explicit spawner empty/degraded path because StageRunner misses or resets spawn_finished.

Findings:
- [medium] Synchronous spawn_finished can be missed or wiped, preventing no_more_ants (CandyAnts/scripts/core/StageRunner.gd:57-63)
  StageRunner calls `_spawner.start(_spawn_parent)` before connecting `_on_spawner_finished`, then unconditionally resets `_spawner_finished = false` after start. AntSpawner.start emits `spawn_finished` synchronously when `total <= 0` or `ant_scene == null`, so an empty or misconfigured stage leaves `_spawner_finished` false forever. The no_more_ants branch then cannot run, and the stage waits for `time_out` instead of producing the deterministic failure result. This is an inference from StageRunner lines 57-63 plus AntSpawner.start's synchronous emit path.
  Recommendation: Initialize `_spawner_finished = false` before starting, connect `spawn_finished` before `_spawner.start()`, and do not reset the flag after start. Add a regression test with `total_ants = 0` or missing `ant_scene` that asserts a prompt `no_more_ants` result rather than timeout.

Next steps:
- Fix the StageRunner spawner signal ordering and add an empty/degraded spawner regression before shipping Phase 6.

### 처리 방향 (CLAUDE.md 정책)

- HIGH/CRITICAL 0건이라 plan-stage·impl-stage 의무 수정 대상 아님.
- 단, 코드 수정 자체가 매우 작아(connect/start 순서 + reset 위치 1단 이동) 즉시 적용. Round 1 finding을 코드 변경으로 해소하고 재리뷰.
- Regression test (total_ants=0 / missing ant_scene)는 MEDIUM 권고 1차 항목이라 `phases/mvp/phase06-deferred.md`에 기록하고 후속 phase 또는 별도 sweep에서 처리.

---

## Self-Review Round 1 (R1 fix 후)

작성일: 2026-05-10
대상: codex R1 fix (StageRunner connect-before-start 순서 + `_spawner_finished = false` reset 위치 이동).

검토:
- AntSpawner.start의 동기 emit 경로 (`total<=0`, `ant_scene==null`) 모두 connect 후 호출되므로 callback 등록됨 → `_spawner_finished` 즉시 true로 set → `_process` 다음 tick에서 candy_hp>0 + ants==0 + in_transit==0 → no_more_ants 발화. fix 의도 충족.
- `_spawner_finished = false` reset이 `_spawner.start()` 전이라, callback이 동기 emit으로 호출돼도 false → true 흐름이 정확. start 후 reset이 false로 덮어쓰던 버그 해소.
- `_spawner == null` (spawner_path 비정상) 분기에서는 `_spawner_finished = false` 그대로 → no_more_ants 가드 통과 안 함 → time_out으로 fallback. 이 자체는 plan의 명시 가드(_spawner != null)에 부합. degraded 시 강력한 fail이 아니라 time_out fallback인 건 의도적 (plan §4.3은 spawner 존재 가정).
- 회귀 (Stage02/03 + GameFlowTest 4 시나리오 + ScoreSystem) 모두 PASS — 변경이 정상 path를 깨지 않음.

추가 가혹 점검:
- `_spawner_finished = false` reset이 spawner 블록 진입 *전*에 있어 spawner_null 분기와 spawner_present 분기 모두 false 시작 — 일관됨.
- connect는 `is_connected` 가드로 중복 connect 방지. 2번 stage reload에서도 idempotent.
- AntSpawner.start의 비동기 emit 경로(timer 기반)도 정상 callback 호출 — 동일 path.

결과: HIGH 0건. Round 2 codex 재리뷰 진행.

---

## Round 2 (codex impl, clean)

작성일: 2026-05-10
verdict: approve / no material findings.

(node:21572) [DEP0190] DeprecationWarning ...
[codex] Thread ready (019e1040-2123-70a2-8771-18f8cea6e7b2).
[codex] Running command: pwsh git status / git diff / findstr StageRunner / SceneFlow / overlay / EventBus / scenes — all completed.

# Codex Adversarial Review

Target: working tree diff
Verdict: approve

Ship: the StageRunner ordering bug is fixed in the working tree. `_spawner_finished` is reset before `AntSpawner.start()`, `spawn_finished` is connected before `start()`, and the synchronous `total <= 0` / `ant_scene == null` emit path now reaches `_on_spawner_finished()` instead of being missed or overwritten. I found no material round-2 blocker.

No material findings.

---

## 종합

- Plan stage: 3 라운드 (R1 ant-counting HIGH → R2 failed-state Next HIGH → R3 clean)
- Impl stage: 2 라운드 (R1 spawner ordering MEDIUM → R2 clean)
- 자체 적대적 리뷰: 1 사이클 (R1 fix 후)
- Deferred (MEDIUM): empty/degraded spawner regression test → `phases/mvp/phase06-deferred.md`
- 회귀 (ScoreSystem / Stage02 / Stage03 / GameFlow 4 시나리오) 모두 PASS

Phase 6 ship-ready. `python scripts/execute.py mvp complete 6` 진행.

