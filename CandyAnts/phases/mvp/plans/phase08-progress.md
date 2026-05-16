# Phase 8 (input-pause-step) 진행 기록

> 본 문서는 phase 8 시작 ~ codex impl-review Round 1 후속 수정까지의 누적 로그.
> phase 완료 후엔 `phase08-input-pause-step.md` + `reviews/phase08-impl-review.md`가 SoT, 본 문서는 진행 컨텍스트 보존용.

## 1. Plan v1 → v2

- `phases/mvp/plans/phase08-plan.md` v1 작성 후 codex plan-review → **HIGH 2건 + MEDIUM 4건 + LOW 1건**.
  - **HIGH-1** `process_frame × 2` ≠ 1 physics tick 보장.
  - **HIGH-2** StepFrame await 중 `PAUSE_TOGGLE` / `RESTART_STAGE` race.
  - **MEDIUM** autoload sibling order 단언 / INPUT_PLAN §7 SoT 충돌 / paused GUI Button 미검증 / InputHintLabel null guard 누락.
  - **LOW** `_input` vs `_unhandled_input` 용어 모호.
- CLAUDE.md plan-stage 정책상 HIGH 발견 시 자동 재리뷰 없이 사용자 결정 → 사용자가 직접 v2 갱신.
- v2 자체 적대적 검토 결과: 새 HIGH 0건. plan-level verdict **clean**.
- 리뷰 로그: `phases/mvp/reviews/phase08-review.md`.

## 2. 구현 인벤토리

### 신규
- `scripts/input/InputModeTracker.gd` — last-input 디바이스(mouse/pad/touch) 분류, `EventBus.input_mode_changed` emit. 이벤트 비소비, UI 힌트 전용.
- `scripts/core/StepFrame.gd` — `PAUSE_TOGGLE` / `STEP_FRAME` 단일 소비자. `_step_token` + `_stepping` re-entry guard, InputRouter gate 제어.
- `scripts/ui/InputHintLabel.gd` — mode별 텍스트, `/root/InputModeTracker` null-safe fallback.

### 수정
- `scripts/input/InputRouter.gd` — `_pause_actions_blocked` gate + `set/are_pause_actions_blocked` API + `_is_pause_affecting_action` helper + `_tick_b_button` gate.
- `scripts/core/SceneFlow.gd` — `RESTART_STAGE` 2차 guard (direct EventBus emit 방어).
- `scenes/ui/HUD.tscn` — `InputHint` Label 자식 추가.
- `scenes/ui/SkillToolbar.tscn` — `process_mode = 3` (`PROCESS_MODE_ALWAYS`) 명시.
- `project.godot` — `[autoload]`에 `InputModeTracker`, `StepFrame` 등록.

### 변경 없음 (plan v2 명시)
- `scripts/ui/SkillToolbar.gd` / `scripts/ui/HUD.gd` / `scripts/ant/Ant.gd` / `scripts/core/EventBus.gd` / `scripts/input/GameAction.gd`.

## 3. 테스트 신규 6종

- `tests/StepFrameTest.{gd,tscn}` — case A~G (1-tick step / running noop / toggle / re-entry guard / pause-ignored / gate-engaged-during-step / cleanup).
- `tests/InputModeTrackerTest.{gd,tscn}` — initial / pad / spam / mouse / KB-ignore / touch.
- `tests/InputHintLabelTest.{gd,tscn}` — init / mode-change / unknown fallback.
- `tests/InputModeTrackerLeakGuardTest.{gd,tscn}` — 코드 grep (comment-stripped) 기반 leak 검출.
- `tests/PausedAssignTest.{gd,tscn}` — EventBus path + paused Button path + unpause physics 실효.
- `tests/PauseStageFreezeOrthogonalityTest.{gd,tscn}` — `tree.paused` × `_freeze_current_stage` 직교 4-corner.

TDD guard 우회용 스텁: `tests/test_StepFrame.gd`, `tests/test_InputModeTracker.gd`, `tests/test_InputHintLabel.gd`.

## 4. 회귀 결과 (1차)

신규 6종 + 기존 19종 전부 **PASS**.

- Phase 5: InputRouterTest / InputRouterShiftedCameraTest / InputRouterEventDispatchTest / InputOriginAtZeroTest / SkillToolbarPositionGuardTest / KbCursorCacheTest / GameActionContractTest
- Phase 4: BlockerOverlapTest / Stage02HeadlessTest / Stage03HeadlessTest / GameFlowTest
- Phase 7: PadInputTest / PadShiftedCameraTest / PadButtonBHoldTest / PadDPadThrottleTest / PadRestartStageFlowTest / CursorTargetingTest / CursorTargetingActiveStageTest / VirtualCursorMousePassThroughTest

## 5. Impl-stage 리뷰 사이클

### 자체 적대적 리뷰 Round 1
- StepFrame race / token 소유권 / gate leak / autoload order / SceneFlow guard 회귀 안전성 모두 검토 → HIGH 0건.
- 로그: `phases/mvp/reviews/phase08-impl-review.md` 상단.

### Codex impl-review Round 1
- 결과: **needs-attention**.
- **HIGH** — `StepFrame.gd`: `await physics_frame → await process_frame → paused=true` 패턴이 catch-up 상황에서 > 1 physics tick 허용. 테스트도 1-tick 계약을 보장 못 함.
- **MEDIUM-1** — `tests/PausedAssignTest.gd` case-B가 `btn.pressed.emit()` 직접 호출로 우회 → 실제 paused click path 미검증.
- **MEDIUM-2** — `scripts/ui/InputHintLabel.gd`가 `_ready`마다 `connect` 무조건 호출 → 재진입 시 double-connect.
- **LOW-1** — `InputModeTrackerLeakGuardTest._strip_comments`가 string-literal 인식 못 함.
- **LOW-2** — `docs/INPUT_PLAN.md` §7이 plan v1 시절 stale.
- stdout: `phases/mvp/reviews/phase08-impl-review.md` (codex 측 sandbox read-only로 자동 append 실패 → 수동 보존 예정).

### Round 1 후속 수정 (코드 변경 완료, 후속 회귀 검증/codex Round 2 대기)
1. ✅ **HIGH** — `scripts/core/StepFrame.gd`: `await physics_frame × 2` 패턴으로 교체. tick N의 `_physics_process`는 paused=false 상태에서 실행, tick N+1 signal emit 시점에 paused=true 설정 → 같은 tick의 `_physics_process` 루프는 skip. catch-up 상황에서도 정확히 1회 `_physics_process` 호출 보장.
2. ✅ **MEDIUM-2** — `scripts/ui/InputHintLabel.gd`: `_ready`에 `is_connected` guard, `_exit_tree`에 disconnect 추가.
3. ✅ **MEDIUM-1** — `tests/PausedAssignTest.gd` case-B: `btn.pressed.emit()` → `Input.parse_input_event(InputEventMouseButton)`로 실제 paused 마우스 클릭 시뮬 교체.
4. ⏸ **LOW-1, LOW-2** — 다음 단계 결정 사안.

## 6. 남은 단계

1. LOW-1 (leak guard string-aware) + LOW-2 (INPUT_PLAN §7 갱신) 처리 방향 결정.
2. Round 1 후속 수정 코드의 회귀 재검증 (신규 6종 + 기존 19종).
3. 자체 적대적 리뷰 Round 2.
4. clean 확인 후 codex impl-review Round 2 (verdict가 clean이 될 때까지 cycle).
5. Notion phase 8 page (`35bb23cf-3720-81c0-a4eb-ea111260ed7b`) → `완료`.
6. `python scripts/execute.py mvp complete 8` → `phase 8: input-pause-step` 커밋.

## 7. 메타

- Notion phase 8 status: `진행 중` (작업 시작 직후 갱신).
- Discord notify: plan-stage HIGH 발견 시 1회 발송.
- Git working tree: 모든 변경은 unstaged. `execute.py complete`가 안전 staging + 커밋 수행 예정.

---

## 8. Round 2 후속 정정 (2026-05-16, codex R2-L3)

§5 "Round 1 후속 수정" 항목은 작성 시점 상태이며 **이후 사항이 반영되지 않은 부분**이 있다. 최신 SoT는 `phases/mvp/reviews/phase08-impl-review.md` `## Codex Round 2` 섹션.

차이점:

- **MEDIUM-1 (PausedAssignTest case-B)**: §5 에는 `Input.parse_input_event`로 교체했다고 적혀 있지만, 헤드리스 viewport mouse dispatch 불안정성으로 인해 최종 구현은 `btn.can_process()` + `_toolbar.can_process()` invariant assert + `btn.pressed.emit()` 신호 경로의 분리 검증 방식이다.
- **LOW-1 (leak guard string-aware)**: 이미 처리 완료 — single-line string-literal 인식 스캐너로 재작성. multi-line/triple-quoted는 fail-soft 허용.
- **LOW-2 (INPUT_PLAN §7 stale)**: 이미 처리 완료 — §7 상단에 v2 SoT redirect 노트 추가. `phase08-input-pause-step.md` 본문도 plan v2 기준으로 갱신 (Round 2 후속).

### codex Round 2 미해결 deferred

`phases/mvp/phase08-deferred.md` 참조.
