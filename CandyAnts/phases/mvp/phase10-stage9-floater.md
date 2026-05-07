---
name: stage9-floater
duration_estimate: 5400
---

# Phase 10: Stage 9 + Floater (빌드 0.9)

## 목표
Floater (낙하 면역) 추가. Faller가 일정 거리 이상 떨어지면 사망 → Floater면 면역. Stage 1~8 회귀 없음.

## 변경 대상
- `scripts/skills/FloaterSkill.gd` (ID="floater", apply → ant에 is_floater 플래그)
- `scripts/core/SkillRegistry.gd`: FloaterSkill preload
- `scripts/ant/Ant.gd`: `is_floater: bool` 추가
- `scripts/ant/states/FallerState.gd`: 낙하 거리 누적 측정. 착지 시 거리 임계 초과 + 비-Floater면 die(), Floater면 그대로 Walker 복귀. Floater일 때 낙하 속도 제한 (terminal velocity ↓)
- `scenes/stages/Stage09.tscn` (높은 절벽 — Floater 없이 떨어지면 사망)
- `data/stages/stage09.tres`

## 검증 방법
1. Stage 1~8 회귀 확인
2. Stage 9: 비-Floater 개미가 절벽에서 떨어지면 사망 (Carrying이면 lost +1)
3. Floater 부여한 개미는 같은 높이에서 살아 착지
4. Floater 낙하 속도가 비-Floater보다 명확히 느림

## 엣지 케이스 (필수)
- **낙하 임계값** — Phase 정의 시 const로 명시 (예: 192px = 12 셀). 임의 magic number 금지
- **Floater Carrying 사망 처리** — 면역이지만 다른 사인(Hazard)으로 죽으면 Lost 정상 처리
- **Faller 진입 시 누적 거리 0으로 reset**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
