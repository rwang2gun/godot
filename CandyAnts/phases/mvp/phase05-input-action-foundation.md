---
name: input-action-foundation
duration_estimate: 7200
---

# Phase 5: Input Action Foundation (KB+Mouse)

## 목표
InputRouter 도입. KB+Mouse를 InputMap 액션 + EventBus.action_triggered 흐름으로 마이그레이션. SkillToolbar는 디바이스 모름.

## 전제
- `docs/INPUT_MAPPING.md`, `docs/INPUT_PLAN.md` (§5 전체) 1차 SoT
- 기존 Stage01~03 회귀 0건

## 변경 대상 (요약 — 상세는 INPUT_PLAN §5.1)

**신규**:
- `scripts/input/GameAction.gd` — 액션 ID 상수(StringName)
- `scripts/input/CoordSpace.gd` — screen↔world 변환 헬퍼 (단일 SoT)
- `scripts/input/InputRouter.gd` — Autoload, `_unhandled_input` + `_process` 두 진입점

**수정**:
- `project.godot` — InputMap 액션 등록 (KB+Mouse만), Autoload 4종으로 확장
- `scripts/core/EventBus.gd` — `action_triggered`, `input_mode_changed` 시그널
- `scripts/ui/SkillToolbar.gd` — `_unhandled_input` 제거, `_on_action`으로 교체. **모든 위치 동반 액션은 `position_valid` 가드 필수**

## 검증 방법 (요약)
1. `tests/InputRouterTest.tscn` (신규) — 가짜 InputEvent 주입 → 정확한 액션/payload emit
2. `tests/InputRouterShiftedCameraTest.tscn` (신규) — Camera2D 이동/줌 상태에서 좌표 변환 정확성
3. Stage01~03 마우스 회귀 PASS
4. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS

## 엣지 케이스 (필수)
- UI Control 영역 클릭 시 `skill_assign` 미발화 (`viewport.is_input_handled()`)
- 좌표 변환 누락 → 잘못된 ant 선택 (CoordSpace 단일 SoT, 카메라 매 프레임 재읽기)
- payload validity는 `position_valid: bool` flag 운반 (Vector2.ZERO sentinel 금지)

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조. 상세 명세는 `docs/INPUT_PLAN.md` §5.
