---
name: stage8-climber
duration_estimate: 5400
---

# Phase 9: Stage 8 + Climber (빌드 0.8)

## 목표
Climber (벽 등반) 추가. Walker가 벽 만나면 회전 대신 등반. Stage 1~7 회귀 없음.

## 변경 대상
- `scripts/skills/ClimberSkill.gd` (ID="climber", apply → ant에 climber 플래그 set, 상태는 Walker 유지)
- `scripts/core/SkillRegistry.gd`: ClimberSkill preload
- `scripts/ant/Ant.gd`: `is_climber: bool` 플래그 추가
- `scripts/ant/states/WalkerState.gd`: 벽 충돌 감지 시 → climber면 ClimbingState 전이, 아니면 기존 회전
- `scripts/ant/states/ClimbingState.gd` 신설 (수직 위 이동, 천장 만나면 회전 후 Walker 복귀, 벽 끝에 도달하면 Walker 복귀)
- `scenes/stages/Stage08.tscn` (수직 벽으로 분리된 두 영역)
- `data/stages/stage08.tres`

## 검증 방법
1. Stage 1~7 회귀 확인
2. Stage 8: Climber 부여한 개미는 벽을 타고 올라가 사탕 도달
3. Climber 끝나기 전 Hazard 만나면 정상 사망

## 엣지 케이스 (필수)
- **천장 도달 시 회전 후 Walker** — 무한 루프 방지
- **Climbing 중 벽이 사라지면 (Basher 등) Faller 전이**
- **Carrying 개미가 Climber면 운반 유지하며 등반 (속도 페널티 누적)**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
