---
name: stage5-basher
duration_estimate: 7200
---

# Phase 6: Stage 5 + Basher (빌드 0.5)

## 목표
TileMap 동적 파괴 시스템 + Basher (수평 굴착). Stage 1~4 회귀 없음.

## 변경 대상
- `scripts/world/Terrain.gd`: `erase_cell_at_world(world_pos)`, `is_destructible(cell)`, `get_cell_at_world(pos)` 메서드 추가
- `scripts/skills/BasherSkill.gd` (ID="basher", apply → WorkerState.new("basher"))
- `scripts/core/SkillRegistry.gd`: BasherSkill preload 추가
- `scripts/ant/states/WorkerState.gd`: basher 분기 — 진행 방향으로 매 N프레임마다 1셀씩 erase, indestructible 만나면 Walker 복귀
- `scenes/stages/Stage05.tscn` (벽으로 막힌 협곡, Basher로 뚫어야 통과)
- `data/stages/stage05.tres`

## 검증 방법
1. Stage 1~4 회귀 확인
2. Stage 5: 벽 앞에서 Basher 적용 → 수평으로 셀 파괴 → 사탕 도달
3. indestructible(Layer 1) 셀 만나면 즉시 Walker 복귀
4. 파괴된 타일 위로 다른 개미들이 통과

## 엣지 케이스 (필수)
- **파괴 중 천장 무너짐 (위 셀에 의존하던 타일)** — MVP는 단순 셀 단위 erase만, 연쇄 파괴 X
- **Basher가 진행 방향 타일이 없으면 (허공) Walker 복귀**
- **Carrying 개미에 Basher 적용 시 운반 유지하며 굴착**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
