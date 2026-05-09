---
name: input-pad-cursor
duration_estimate: 7200
---

# Phase 6: Pad + VirtualCursor

## 목표
ROG Ally X 패드 풀 매핑. VirtualCursor 도입 + 개미 스냅 점프. SkillToolbar는 디바이스 분기 없음.

## 전제
- Phase 5 완료(InputRouter 가동, EventBus.action_triggered 흐름)
- `docs/INPUT_PLAN.md` §6 전체 1차 SoT

## 변경 대상 (요약 — 상세는 INPUT_PLAN §6.1)

**신규**:
- `scripts/ui/VirtualCursor.gd`, `scenes/ui/VirtualCursor.tscn` (CanvasLayer + Control, screen-space)
- `scripts/input/CursorTargeting.gd` — 다음/이전 ant 스냅 계산기

**수정**:
- `project.godot` — InputMap에 패드 binding 추가
- `scripts/input/InputRouter.gd` — 좌 스틱 polling + `cursor_move` 발화, Pad B 단발/홀드 raw 처리, `_ensure_virtual_cursor_ready` 단일 helper
- 각 Stage 씬 — VirtualCursor 인스턴스 추가 (또는 Main.tscn 공통)

## 검증 방법 (요약)
1. Stage03 패드 단독 클리어 (좌 스틱 + LB/RB + A)
2. `tests/PadInputTest.tscn`, `tests/PadShiftedCameraTest.tscn`, `tests/PadButtonBHoldTest.tscn`, `tests/InputRouterEventDispatchTest.tscn`, `tests/InputOriginAtZeroTest.tscn`, `tests/PadFirstStickInputTest.tscn`, `tests/SkillToolbarPositionGuardTest.tscn`, `tests/KbCursorCacheTest.tscn` (전부 INPUT_PLAN §6.6 명세)
3. 마우스/패드 전환 시 VirtualCursor visibility 즉시 반영
4. Stage01~03 회귀 (마우스+패드 양쪽)

## 엣지 케이스 (필수)
- 마우스+패드 동시 입력 → last-emit wins, payload.world_pos만 사용
- D-Pad 연타 throttle (0.1초)
- Pad B 단발=cancel, 홀드 1초=restart_stage (race-free, raw 처리)
- 패드 미연결 환경 → polling skip

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조. 상세 명세는 `docs/INPUT_PLAN.md` §6.
