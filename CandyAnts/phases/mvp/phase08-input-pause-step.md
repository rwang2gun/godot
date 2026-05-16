---
name: input-pause-step
duration_estimate: 5400
verify:
large_change_ok: true
sot: docs/INPUT_PLAN.md
sot_aux: []
---

# Phase 8: Pause / StepFrame / InputModeTracker

> **2026-05-16 갱신 (codex impl-review Round 2 LOW-2)**:
> 실제 구현 계약 SoT는 **`phases/mvp/plans/phase08-plan.md` v2**. 본 phase 파일 frontmatter의 `sot: docs/INPUT_PLAN.md`는 컨벤션상 docs/ 경로 유지 — `docs/INPUT_PLAN.md §7` 상단의 v2 redirect 노트를 통해 plan v2로 연결됨. 본 파일 본문의 "변경 대상" 목록은 plan v2 기준으로 갱신.

## 목표
Pause 중 스킬 부여 명시 보장 + StepFrame(정확히 1 physics tick 전진) + InputModeTracker(UI 힌트 전용).

## 전제
- Phase 5, 6, 7 완료 (input + game-flow layer 안정)
- `phases/mvp/plans/phase08-plan.md` v2 1차 SoT, `docs/INPUT_PLAN.md` §7는 참조 문서 + v2 redirect 노트 보유.

## 변경 대상 (plan v2 §변경 파일 기준)

**신규**:
- `scripts/input/InputModeTracker.gd` — Autoload, last-input 디바이스 분류, `EventBus.input_mode_changed` emit. UI 힌트 전용(게임 로직 분기 금지).
- `scripts/ui/InputHintLabel.gd` — HUD 자식. mode별 텍스트 + `/root/InputModeTracker` null-safe fallback.
- `scripts/core/StepFrame.gd` — `PAUSE_TOGGLE` / `STEP_FRAME` 단일 소비자. `await physics_frame × 2` 패턴 + `_step_token` + InputRouter gate 제어.

**수정**:
- `scripts/input/InputRouter.gd` — `_pause_actions_blocked` gate + `set/are_pause_actions_blocked` API + `_is_pause_affecting_action` helper + Pad B hold gate.
- `scripts/core/SceneFlow.gd` — `RESTART_STAGE` 2차 guard.
- `scenes/ui/HUD.tscn` — `InputHint` Label 자식 추가.
- `scenes/ui/SkillToolbar.tscn` — `process_mode = 3`(ALWAYS) 명시.
- `project.godot` — autoload `InputModeTracker`, `StepFrame` 등록.

**변경 없음** (plan v2 명시): `scripts/ui/SkillToolbar.gd`, `scripts/ui/HUD.gd`, `scripts/ant/Ant.gd`, `scripts/core/EventBus.gd`, `scripts/input/GameAction.gd`.

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
