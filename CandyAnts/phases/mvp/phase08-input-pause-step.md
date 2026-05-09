---
name: input-pause-step
duration_estimate: 5400
---

# Phase 8: Pause / StepFrame / InputModeTracker

## 목표
Pause 중 스킬 부여 명시 보장 + StepFrame(1프레임 전진) + InputModeTracker(UI 힌트 전용).

## 전제
- Phase 5, 6 완료 (input layer 안정)
- `docs/INPUT_PLAN.md` §7 전체 1차 SoT

## 변경 대상 (요약 — 상세는 INPUT_PLAN §7.1)

**신규**:
- `scripts/input/InputModeTracker.gd` — Autoload, last-input 디바이스 추적, `EventBus.input_mode_changed` emit. **UI 힌트 전용** (게임 로직 분기 금지)
- `scripts/ui/InputHintLabel.gd` — HUD 자식, 모드별 키 힌트 텍스트
- `scripts/core/StepFrame.gd` — 1 frame advance 헬퍼

**수정**:
- `scripts/ui/SkillToolbar.gd` — `process_mode = PROCESS_MODE_ALWAYS` 명시
- `scripts/ui/HUD.gd` — InputHintLabel 인스턴스 추가
- `scripts/ant/Ant.gd` — pause 시 state 전이는 unpause 후 적용 확인 (검증만)

## 검증 방법 (요약)
1. `tests/PausedAssignTest.tscn` (신규) — pause 진입 → blocker 부여 → unpause → blocker 효과 발현
2. Pause 상태 + `step_frame` 1회 → 개미 1프레임 전진 → 다시 pause
3. 디바이스 전환 시 InputHintLabel 즉시 갱신 (last-input 기반, 5초 지연 없음)
4. Stage01~03 pause-assign-unpause 회귀

## 엣지 케이스 (필수)
- pause 중 `_process` 멈춰도 InputModeTracker는 PROCESS_MODE_ALWAYS
- StepFrame은 paused 상태에서만 동작
- pause 중 부여 시 `Skill.apply(ant)`는 state 변경만 → unpause 후 자연 발현

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조. 상세 명세는 `docs/INPUT_PLAN.md` §7.
