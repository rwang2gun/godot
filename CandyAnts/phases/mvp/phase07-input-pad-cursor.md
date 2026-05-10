---
name: input-pad-cursor
duration_estimate: 7200
verify:
large_change_ok: false
sot: docs/INPUT_PLAN.md
sot_aux: [docs/INPUT_MAPPING.md]
---

# Phase 7: Pad + VirtualCursor (v2 정의)

## 정의 SoT
**구현 SoT는 `phases/mvp/plans/phase07-plan.md` (v2)**. 본 phase 정의 파일은 v2 plan의 핵심 invariants를 inline + delegate하는 단일 소비 진입점이다. Round 1 codex review HIGH 2건 반영 후 v2로 갱신됨(2026-05-10).

## 목표
ROG Ally X 패드 풀 매핑. VirtualCursor 도입 + active-stage subtree로 필터된 개미 스냅 점프. SkillToolbar는 디바이스 분기 없음. **B-hold restart와 Ctrl+R restart는 SceneFlow가 단일 replay 경로로 소비**(silent no-op 금지).

## 전제
- Phase 5 완료(InputRouter 가동, EventBus.action_triggered 흐름)
- Phase 6 완료(SceneFlow + game-flow 토대)
- `phases/mvp/plans/phase07-plan.md` v2 = 구현 1차 SoT
- `docs/INPUT_PLAN.md` §6 = 입력 매핑 1차 SoT
- `phases/mvp/reviews/phase07-review.md` Round 1 HIGH = v2 변경 근거

## v2 핵심 invariants (구현 시 반드시 준수)

1. **`GameAction.RESTART_STAGE` 소비자 = SceneFlow 단독**: SceneFlow가 `EventBus.action_triggered`를 구독해 `RESTART_STAGE` → `EventBus.request_replay.emit()`(또는 직접 `replay_stage()`) 라우팅. B-hold/Ctrl+R 모두 이 경로로 합류 — silent fail 금지. 회귀: `tests/PadRestartStageFlowTest.tscn`(stage instance 실제 교체 검증).
2. **CursorTargetingResolver active-stage scoping**: SceneFlow의 `get_active_stage_root()`(또는 동급 provider) 결과 subtree 자손만 D-Pad/Tab snap 후보. 전역 `get_nodes_in_group("ants")` 결과는 active-stage 필터 통과 + `is_instance_valid` + `not is_queued_for_deletion()` 검증 후에만 사용. 회귀: `tests/CursorTargetingActiveStageTest.tscn`(replay/next 전환 중 stale ants 차단).
3. **SkillToolbar 디바이스 분기 금지**: 코드 grep ban — `Input.is_joy_button_*`/`InputModeTracker`/`VirtualCursor` 직접 참조 0건. payload.world_pos만 사용.
4. **`_emit_cursor_move`만이 CURSOR_MOVE 발화 + cache 갱신 단일 경로**(Phase 5 계약 유지). `request_cursor_jump`도 본 helper 경유.
5. **Pad B는 InputMap 미등록 + raw 처리만**: `InputEventJoypadButton` direct dispatch, press timer, release-time/expire 분기로 정확히 1회 emit. `set_input_as_handled` 호출.

## 변경 대상 (요약 — 상세는 phase07-plan.md v2)

**신규**:
- `scripts/ui/VirtualCursor.gd`, `scenes/ui/VirtualCursor.tscn` (CanvasLayer layer=11 + Control, screen-space, Main.tscn GlobalUI 형제)
- `scripts/input/CursorTargeting.gd` — 순수 계산 utility (tree lookup 금지)
- `scripts/ui/CursorTargetingResolver.gd` — active-stage 필터링 후 InputRouter.request_cursor_jump 호출

**수정**:
- `project.godot` — InputMap에 패드 binding 병합 + internal `pad_cursor_*` 4개
- `scripts/input/InputRouter.gd` — 좌 스틱 polling + B raw + D-Pad throttle + `request_cursor_jump`
- `scripts/core/SceneFlow.gd` — `action_triggered` 구독 + RESTART_STAGE 라우터 + `get_active_stage_root()` 제공 + VirtualCursor/Resolver 주입
- `scenes/Main.tscn` — VirtualCursor + CursorTargetingResolver 신규 노드
- `tests/GameActionContractTest.gd` — `pad_cursor_*` whitelist
- `scripts/ant/Ant.gd` — `is_alive()` 헬퍼(없으면 추가)

## 검증 방법 (요약)
1. **Stage03 패드 단독 클리어** (좌 스틱 + LB/RB + A 만으로)
2. **B 단발 = cancel, B 홀드 1초 = restart**(stage instance 실제 reload)
3. **D-Pad ←/→ snap이 active stage ants만 잡음**(replay 직후 stale ants 무시)
4. **마우스/패드 전환 시 VirtualCursor visibility 즉시 반영**
5. **Stage01~03 KB+Mouse 회귀 0건**
6. **헤드리스 회귀 PASS 필수**: `tests/Stage02HeadlessTest.tscn`, `Stage03HeadlessTest`, `BlockerOverlapTest`, `InputRouterTest`, `InputRouterShiftedCameraTest`, `InputRouterEventDispatchTest`, `InputOriginAtZeroTest`, `SkillToolbarPositionGuardTest`, `KbCursorCacheTest`, `GameActionContractTest`, `GameFlowTest`
7. **헤드리스 신규**: `PadInputTest`, `PadShiftedCameraTest`, `PadButtonBHoldTest`, `PadRestartStageFlowTest`, `PadDPadThrottleTest`, `CursorTargetingTest`, `CursorTargetingActiveStageTest`, `VirtualCursorMousePassThroughTest`

## 엣지 케이스 (필수)
- 마우스+패드 동시 입력 → last-emit wins, payload.world_pos만 사용
- D-Pad 연타 throttle (100ms)
- Pad B 단발=cancel, 홀드 1초=restart_stage (raw 처리, race-free, SceneFlow가 RESTART_STAGE 소비)
- 패드 미연결 환경 → polling skip
- VirtualCursor 미주입(헤드리스 stage 테스트) → 패드 위치 동반 액션 `position_valid=false`로 emit, KB+Mouse 회귀 0
- Stage replay/next 1-frame overlap → resolver가 `is_ancestor_of(active_stage_root)` + `not is_queued_for_deletion()` 가드로 stale ants 차단

## 비-범위(deferred)
- `camera_pan` / `camera_zoom`(우 스틱, LT/RT) — CameraController phase 별도
- `InputModeTracker` / `InputHintLabel` / `back_menu` — phase 8/12/13
- 화면 가장자리 카메라 자동 추적 — CameraController 합류 시점

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조. 구현 1차 SoT는 `phases/mvp/plans/phase07-plan.md` v2.
