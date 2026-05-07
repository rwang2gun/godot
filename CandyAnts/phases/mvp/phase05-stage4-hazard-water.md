---
name: stage4-hazard-water
duration_estimate: 7200
---

# Phase 5: Stage 4 + Hazard 시스템 (빌드 0.4)

## 목표
Hazard 추상 + Water 첫 구현. 운반 중 사망 시 `lost_pieces` 첫 발생. Stage 1~3 회귀 없음.

## 변경 대상
- `scripts/world/hazards/Hazard.gd` (베이스: Area2D, body_entered → ant.die() + Carrying이면 EventBus.candy_piece_lost 발화)
- `scripts/world/hazards/WaterHazard.gd` (Hazard 상속, 시각적 placeholder = 파란색 ColorRect)
- `scenes/entities/hazards/WaterHazard.tscn` (Area2D layer=4 mask=3 monitoring=true)
- `scripts/ant/Ant.gd`: `die()` 메서드 — DeadState 전이 + was_carrying 플래그 EventBus 전달
- `scripts/ant/states/DeadState.gd`: 시각 처리 + 일정 시간 후 queue_free()
- `scripts/core/ScoreSystem.gd`: candy_piece_lost 구독 → lost +1, in_transit -1, 불변식 assert 확인
- `scripts/ui/HUD.gd`: Lost 카운터 표시 활성화
- `scenes/stages/Stage04.tscn` (Water 구덩이 — Builder로 다리 놓아야 통과)
- `data/stages/stage04.tres`

## 검증 방법
1. Stage 1~3 회귀 확인
2. Stage 4: 빈손 개미가 Water에 닿으면 즉사 + Lost 카운터 변화 없음
3. **Carrying 개미가 Water에 닿으면 Lost +1, in_transit -1, candy.hp 영향 없음**
4. ScoreSystem 불변식 (saved + in_transit + lost ≤ original_hp) 위반 시 assert 발화 확인
5. 클리어 술어: candy.hp == 0 + in_transit == 0 → score = saved/original_hp (lost 있어도 클리어 가능, 점수만 낮음)

## 엣지 케이스 (필수)
- **여러 Hazard 동시 진입 시 die() 1회만 처리** (이미 Dead면 무시)
- **Builder가 Water 위에 다리 놓을 때 Hazard와 타일이 같은 셀 점유** — 타일이 Hazard mask 영역을 가려도 Area2D는 여전히 발화. `Hazard.set_disabled()` 또는 monitoring 토글로 처리
- **Faller 상태에서 Hazard 진입 시도 정상 처리**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
