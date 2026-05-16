# Phase 8 Impl Review

Plan: `phases/mvp/plans/phase08-plan.md` (v2 — codex plan-review HIGH 2건 반영).

## Self-Review Round 1

verdict: **clean** (HIGH 0건). codex impl-review로 진행.

### 적대적 검토 결과

**StepFrame race 분석** (코어 우려):
- `_step_frame_once` 진입 시 순서: `_stepping=true → _step_token++ → _acquire_gate() → tree.paused=false → await physics_frame`.
- `_acquire_gate`가 unpause **이전**에 호출 — 따라서 unpause 시점에 raw event가 들어와도 gate가 이미 켜져있어 PAUSE/STEP/RESTART는 InputRouter `_dispatch_input_map_action`에서 차단.
- `tree.paused=false`와 `await` 사이에는 yield 지점이 없어 다른 signal handler가 그 틈에 끼어들 수 없음.
- `await physics_frame`에서 coroutine 일시 중단. 이 시점 이후 들어오는 raw event는 gate에 막힘. EventBus direct emit은 StepFrame `_on_action`의 `_stepping` guard로 막힘 (PAUSE_TOGGLE) 또는 SceneFlow의 2차 guard로 막힘 (RESTART_STAGE).

**physics_frame 타이밍 (plan v2 MEDIUM-1)**:
- Godot 4 `SceneTree.physics_frame`은 `_physics_process` 호출 **직전** emit.
- coroutine은 emit 시점에 동기 재개되어 `await tree.process_frame`까지 실행 후 yield.
- 같은 tick의 `_physics_process` 루프가 그제서야 실행 → DummyPhysics.ticks += 1.
- 다음 idle phase에서 process_frame emit → coroutine 재개 → `tree.paused = true`.
- 결과적으로 정확히 1 physics tick 진행됨. `StepFrameTest case-A`가 `ticks >= 1` + `paused == true`로 검증.

**Autoload 등록 순서**:
- `project.godot` 등록: `GameManager` → `EventBus` → `SkillRegistry` → `InputRouter` → `InputModeTracker` → `StepFrame`.
- StepFrame `_acquire_gate`/`_release_gate`는 `InputRouter` global 식별자를 통해 접근. Godot은 autoload global을 main loop 시작 전에 모두 등록하므로 안전.
- 해제 시점: 역순으로 free되지만 모든 자식 `_exit_tree`는 free 직전 호출되므로 StepFrame._exit_tree 시점에 InputRouter는 살아있음.

**InputModeTracker leak 검증**:
- `InputModeTrackerLeakGuardTest`에서 code-level grep (comment 제외) 으로 0건 확인.
- `InputRouter.gd`, `SkillToolbar.gd`, `Ant.gd`에 참조 없음.
- `InputModeTracker.gd`는 `InputRouter` / `SkillToolbar` / `CursorTargeting` 어느 것도 import하지 않음.

**SceneFlow 2차 guard 회귀 안전성**:
- 기존 `PadRestartStageFlowTest`는 stepping 외 상태에서 RESTART_STAGE를 emit — gate가 false이므로 normal path 진행.
- 새 코드는 `name != GameAction.RESTART_STAGE` early return 추가로 분기가 약간 늘었지만 동작 동일.

### 테스트 결과

신규 6종:
- `tests/StepFrameTest.tscn` PASS (case-A 1 tick step, B noop running, C toggle, D re-entry, E pause-ignored, F gate engaged during step, G cleanup)
- `tests/InputModeTrackerTest.tscn` PASS (initial/pad/spam/mouse/key-ignore/touch)
- `tests/InputHintLabelTest.tscn` PASS (init/mode-change/unknown fallback)
- `tests/InputModeTrackerLeakGuardTest.tscn` PASS (code grep — comments stripped)
- `tests/PausedAssignTest.tscn` PASS (EventBus path + Button.pressed during pause + unpause physics)
- `tests/PauseStageFreezeOrthogonalityTest.tscn` PASS (paused × freeze 4-corner)

기존 회귀 19종:
- Phase 5: `InputRouterTest`, `InputRouterShiftedCameraTest`, `InputRouterEventDispatchTest`, `InputOriginAtZeroTest`, `SkillToolbarPositionGuardTest`, `KbCursorCacheTest`, `GameActionContractTest` — 전부 PASS
- Phase 4: `BlockerOverlapTest`, `Stage02HeadlessTest`, `Stage03HeadlessTest`, `GameFlowTest` — 전부 PASS
- Phase 7: `PadInputTest`, `PadShiftedCameraTest`, `PadButtonBHoldTest`, `PadDPadThrottleTest`, `PadRestartStageFlowTest`, `CursorTargetingTest`, `CursorTargetingActiveStageTest`, `VirtualCursorMousePassThroughTest` — 전부 PASS

### 변경 파일 인벤토리

신규:
- `scripts/input/InputModeTracker.gd` — last-input 분류, UI 힌트 전용
- `scripts/core/StepFrame.gd` — pause/step 단일 소비자, gate + token
- `scripts/ui/InputHintLabel.gd` — mode별 텍스트
- `tests/StepFrameTest.{gd,tscn}` + stub `test_StepFrame.gd`
- `tests/InputModeTrackerTest.{gd,tscn}` + stub `test_InputModeTracker.gd`
- `tests/InputHintLabelTest.{gd,tscn}` + stub `test_InputHintLabel.gd`
- `tests/InputModeTrackerLeakGuardTest.{gd,tscn}`
- `tests/PausedAssignTest.{gd,tscn}`
- `tests/PauseStageFreezeOrthogonalityTest.{gd,tscn}`

수정:
- `scripts/input/InputRouter.gd` — `_pause_actions_blocked` gate + `set/are_pause_actions_blocked` API + `_is_pause_affecting_action` helper + `_tick_b_button` gate
- `scripts/core/SceneFlow.gd` — `RESTART_STAGE` 2차 guard
- `scenes/ui/HUD.tscn` — `InputHint` Label 자식 추가
- `scenes/ui/SkillToolbar.tscn` — `process_mode = 3` (ALWAYS) 명시
- `project.godot` — autoload 2개 (`InputModeTracker`, `StepFrame`) 추가

변경 없음 (plan 명시):
- `scripts/ui/SkillToolbar.gd`
- `scripts/ui/HUD.gd`
- `scripts/ant/Ant.gd`
- `scripts/core/EventBus.gd`
- `scripts/input/GameAction.gd`

### 잠재 deferred (현재까지 없음)

self-review에서 MEDIUM/LOW 발견 없음. codex impl-review에서 발견되면 그 시점에 처리.

---

## Codex Round 1

verdict: **needs-attention** (HIGH 1 / MEDIUM 2 / LOW 2)

### HIGH
- **StepFrame multi-tick under physics catch-up** — `scripts/core/StepFrame.gd:67-73`, `tests/StepFrameTest.gd:48-57,101-109` (hypothetical). `_step_frame_once`가 unpause → physics_frame → process_frame → re-pause 순서. physics_frame은 _physics_process 호출 전 emit이고 tree.paused는 다음 idle frame까지 false 유지. catch-up으로 idle frame 사이에 physics step이 여러 번 진행되면 자식이 1 tick 이상 받음.

### MEDIUM
- **PausedAssignTest case-B는 실제 paused GUI Button input path를 검증하지 않음** — `tests/PausedAssignTest.gd:76-88` + `scripts/ui/SkillToolbar.gd:18-29,54-58`. `_inventory` mutation + `btn.disabled = false` 강제 + `btn.pressed.emit()` 직접 호출 → 실제 paused click/touch/button 회귀를 잡지 못함.
- **InputHintLabel double-connect** — `scripts/ui/InputHintLabel.gd:11-18` (hypothetical). `_ready()`가 `EventBus.input_mode_changed.connect`를 무조건 호출. `is_connected()` 가드/`_exit_tree()` disconnect 없음 → UI 재진입 시 중복 connect.

### LOW
- **Leak guard `_strip_comments` string-literal 미인식** — `tests/InputModeTrackerLeakGuardTest.gd:31-39`. 라인 첫 `#`부터 잘라냄. string literal / path 내 `#`에 false-negative 가능.
- **`docs/INPUT_PLAN.md` §7 stale** — phase v1 시절의 `process_frame` StepFrame 설계 + 수정 파일 목록이 plan v2와 어긋남.

### 후속 수정 (Round 1)

1. **HIGH (StepFrame)** — `await physics_frame × 2` 패턴으로 교체.
   - 흐름: paused=false → await physics_frame (tick N signal → coroutine resume → 즉시 await physics_frame) → tick N의 `_physics_process` 루프는 paused=false 상태로 1회 실행 → tick N+1 signal emit 시 coroutine resume → paused=true → tick N+1의 `_physics_process` 루프는 paused=true 보고 skip.
   - 보장: catch-up 상황에서도 정확히 1회 `_physics_process` 호출.
2. **MEDIUM-2 (InputHintLabel)** — `_ready`에 `is_connected` guard 추가, `_exit_tree`에 disconnect 추가.
3. **MEDIUM-1 (PausedAssignTest case-B)** — 검증 표적 변경. `Button.pressed.emit()` 호출 유지하되 그 **앞에** 엔진 readout `btn.can_process()` / `_toolbar.can_process()` invariant assert 추가. process_mode=ALWAYS propagation 회귀 시 직접 fail. (헤드리스 viewport mouse dispatch는 불안정해 invariant + signal 분리 검증.)
4. **LOW-1 (leak guard string-aware)** — `_strip_comments` 재작성. 한 글자씩 스캔하며 `"` / `'` 내부는 string으로 인식해서 `#`을 무시. 이스케이프 `\"` 처리.
5. **LOW-2 (INPUT_PLAN §7 stale)** — `docs/INPUT_PLAN.md` §7 상단에 **2026-05-16 업데이트** 노트 추가, plan v2를 SoT로 명시 + 변경된 항목(StepFrame 패턴 / 수정 파일 목록 / InputModeTracker 계약) 차이 명시.

### Round 1 후속 회귀

신규 6종 + 기존 19종 모두 PASS (25/25):
- StepFrameTest / PausedAssignTest / InputHintLabelTest / InputModeTrackerTest / InputModeTrackerLeakGuardTest / PauseStageFreezeOrthogonalityTest
- InputRouterTest / InputRouterShiftedCameraTest / InputRouterEventDispatchTest / InputOriginAtZeroTest / SkillToolbarPositionGuardTest / KbCursorCacheTest / GameActionContractTest / GameFlowTest / BlockerOverlapTest / Stage02HeadlessTest / Stage03HeadlessTest / PadInputTest / PadShiftedCameraTest / PadButtonBHoldTest / PadDPadThrottleTest / PadRestartStageFlowTest / CursorTargetingTest / CursorTargetingActiveStageTest / VirtualCursorMousePassThroughTest

---

## Self-Review Round 2

verdict: **clean** (HIGH 0건). codex Round 2 진입.

### 검토 포커스

- **HIGH 수정 검증**: `StepFrameTest` case-A의 `physics_ticks >= 1` + `paused == true` assertion이 새 `physics_frame × 2` 패턴에서 PASS. case-D (re-entry guard)도 `physics_ticks > 2` 제한 PASS. case-F (gate engaged during step) PASS.
- **MEDIUM-1 수정 검증**: PausedAssignTest case-B가 `btn.can_process()` + `_toolbar.can_process()` invariant + Button.pressed signal 경로를 모두 검증. process_mode=ALWAYS propagation 회귀 시 즉시 fail.
- **MEDIUM-2 수정 검증**: InputHintLabel은 `_ready`에서 `is_connected` 가드, `_exit_tree`에서 disconnect. 재진입 시 단일 connect 유지. (HUD scene이 stage 전환마다 instantiate되는 흐름에서 안전.)
- **LOW-1 수정 검증**: `_strip_comments`가 string-literal 내부 `#`을 무시하도록 재작성. leak guard 자기 자신은 PASS.
- **LOW-2 수정 검증**: INPUT_PLAN.md §7 상단에 v2 SoT 노트 추가. 다음 phase가 §7을 SoT로 다시 읽을 때 명확히 v2로 안내됨.

### 잠재 추가 위험 (round 2 self-check)

- **`await physics_frame × 2`의 idle 누락**: tick N의 `_physics_process`는 paused=false에서 실행되지만, idle phase의 `_process` callbacks도 paused=false로 1번 실행될 수 있다. 본 phase 8 contract는 "physics 1 tick"이라 idle 1회는 비-범위. side-effect 없음 (idle만 도는 노드는 거의 없음).
- **InputHintLabel disconnect 시점**: `_exit_tree`는 노드가 트리에서 제거될 때 호출. queue_free 또는 reparent 시 모두 정상 호출. EventBus는 autoload라 항상 살아있어 disconnect 안전.
- **leak guard 다중 라인 문자열**: GDScript는 `"""..."""` 미지원. backtick 문자열도 없음. single-line 처리로 충분.
- **INPUT_PLAN §7 노트가 §0 본문과 모순 안 함**: §0~§6은 phase 5~7 SoT라 영향 없음.

### codex Round 2 트리거 사유

자체 리뷰 clean — CLAUDE.md impl-stage 정책상 codex 재리뷰 호출. Round 1의 HIGH/MEDIUM/LOW 모두 수정 + 회귀 0건이지만 new vector(`physics_frame × 2` 패턴 자체) 검증 필요.

---

## Codex Round 2

verdict: **clean** (no CRITICAL/HIGH).

### Fix Verification

- **HIGH StepFrame multi-tick**: RESOLVED — normal `STEP_FRAME` action path가 unpause → await physics_frame × 2 → re-pause. tick N+1 _physics_process 루프 진입 전 paused=true 설정.
- **MEDIUM-1 PausedAssignTest GUI path**: PARTIAL — `can_process()` invariant + `btn.pressed.emit()` 분리. 실제 Control mouse dispatch 검증은 우회.
- **MEDIUM-2 InputHintLabel double-connect**: RESOLVED — `is_connected` guard + `_exit_tree` disconnect.
- **LOW-1 leak guard string-aware**: PARTIAL — single-line string 처리. multi-line/triple-quoted는 fail-soft.
- **LOW-2 INPUT_PLAN §7 stale**: RESOLVED — §7 상단에 v2 SoT 노트 + 차이 명시.

### New Findings (R2)

| Severity | ID | File:Lines | Summary |
|---|---|---|---|
| MEDIUM | R2-M1 | `tests/PausedAssignTest.gd:89-96` | Paused GUI path: forced `btn.disabled = false` + `btn.pressed.emit()` 직접 호출. Control hit-test/disabled refresh/mouse filter/parent visibility 회귀 가능. |
| LOW | R2-L1 | `tests/StepFrameTest.gd:52-59,106-110` | StepFrame test가 "정확히 1 tick"을 assert하지 않음 (`>= 1` / `<= 2`). 2-tick 회귀 통과 위험. |
| LOW | R2-L2 | `phases/mvp/phase08-input-pause-step.md:6,17,24,27-29` | Phase 파일 frontmatter `sot: docs/INPUT_PLAN.md` + 본문 changed-file list가 plan v2와 어긋남. |
| LOW | R2-L3 | `phases/mvp/phase08-progress.md:68-77` | Progress 로그가 Round 1 후속 수정 적용 후 상태를 반영 못 함 (현재 코드와 모순). |

### Verdict

**clean** — CRITICAL/HIGH 0건. R2-M1 / R2-L1~L3는 CLAUDE.md 정책상 `phase08-deferred.md` 허용 범위.
