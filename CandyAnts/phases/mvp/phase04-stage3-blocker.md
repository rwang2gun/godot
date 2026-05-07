---
name: stage3-blocker
duration_estimate: 5400
---

# Phase 4: Stage 3 + Blocker 스킬 (빌드 0.3)

## 목표
Blocker로 다른 개미의 진행 방향을 반전시켜 흐름 제어. Stage 1/2 회귀 없음.

## 변경 대상
- `scripts/skills/BlockerSkill.gd` (ID="blocker", apply → WorkerState.new("blocker"))
- `scripts/core/SkillRegistry.gd`: BlockerSkill preload 추가
- `scripts/ant/states/WorkerState.gd`: blocker 분기 — 정지 + 좌우 충돌 박스 활성화 → 닿는 개미의 velocity.x 부호 반전
- `scripts/ant/Ant.gd`: 다른 Ant와의 부드러운 통과 정책 + Blocker 충돌 감지 (signal `bumped_blocker(direction)` 노출)
- `scenes/stages/Stage03.tscn` (분기 지점 — Blocker 없으면 절반이 사탕 못 가는 레벨)
- `data/stages/stage03.tres` (skill_inventory={"builder":2,"blocker":2})

## 검증 방법
1. Stage 1, 2 회귀 확인
2. Stage 3 진입 → Blocker 적용한 개미가 정지하고 다음 개미부터 방향 반전
3. Blocker 자신은 사망/스킬 해제까지 영구 정지
4. 운반 중 개미가 Blocker에 부딪히면 운반 상태 유지하며 반전

## 엣지 케이스 (필수)
- **Blocker가 절벽 끝에 서면 Faller 진입 후 Dead** (정상 동작이지만 in_transit 영향 없음)
- **Blocker끼리 마주봐도 무한 반전 루프 방지** (서로 한 번만 처리, double-bump 차단)
- **Carrying 개미가 Blocker에 부딪힐 때도 Carrying 유지하며 반전**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
