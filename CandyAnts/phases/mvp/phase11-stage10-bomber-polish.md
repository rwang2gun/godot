---
name: stage10-bomber-polish
duration_estimate: 9000
---

# Phase 11: Stage 10 + Bomber + 폴리싱 (빌드 1.0 = MVP 완료)

## 목표
Bomber (원형 폭파) 추가 + Release Rate 슬라이더 폴리싱 + 카메라/HUD 정돈. MVP 종료.

## 변경 대상
**Bomber**:
- `scripts/skills/BomberSkill.gd` (ID="bomber", apply → ant에 fuse_seconds=5 카운트다운)
- `scripts/core/SkillRegistry.gd`: BomberSkill preload (총 8종 ID 모두 등록 검증)
- `scripts/ant/Ant.gd`: `bomber_fuse: float` + Process에서 카운트다운, 0 도달 시 Terrain.erase_circle(world_pos, radius_cells) + Carrying이면 lost 처리 + die()
- `scripts/world/Terrain.gd`: `erase_circle(world_pos, radius_cells)` 추가 (셀 거리 ≤ radius인 destructible만 erase)

**폴리싱**:
- `scripts/core/AntSpawner.gd`: Release Rate 슬라이더 ↔ EventBus.release_rate_changed 연동, Timer 인터벌 동적 갱신
- `scenes/ui/HUD.tscn`: Release Rate 슬라이더 추가 (min=stage.release_rate_min, max=99, value=initial)
- `scripts/ui/HUD.gd`: 슬라이더 시그널 → EventBus emit
- `scenes/Main.tscn`: 메뉴 → 스테이지 선택 → 인게임 → 결과 → 메뉴 라우팅 검증
- 카메라 한계(limits) — 모든 stage 씬의 Camera2D limit_left/right/top/bottom 명시
- `scenes/stages/Stage10.tscn` (Bomber로만 풀리는 스틸 우회 또는 좁은 통로 클리어)
- `data/stages/stage10.tres`

**MVP 종료 점검** (회귀 패키지):
- Stage 1~10 순차 클리어 1회씩 시연
- 8 스킬 모두 1회씩 사용
- ScoreSystem 불변식 위반 0회
- SkillRegistry.validate_stage 모든 stageNN.tres에 대해 빈 배열 반환

## 검증 방법
1. Stage 1~9 회귀 — 전부 클리어 가능
2. Stage 10: Bomber로 막힌 통로 폭파 → 통과 → 클리어
3. Bomber 폭발 반경 시각적으로 합리적 (3~4셀)
4. Release Rate 슬라이더 좌측/우측 끝에서 스폰 간격 변화 즉시 반영
5. 클리어 후 메뉴 복귀 → 다른 스테이지 선택 가능

## 엣지 케이스 (필수)
- **Bomber 카운트다운 중 Hazard 사망 시 폭발 취소** (die() 시 fuse 무효화)
- **Carrying 개미 Bomber 시 폭발 시점에 lost +1** (사탕 조각도 함께 소실)
- **Bomber 폭발 영역에 indestructible 포함되어도 destructible만 제거**
- **여러 Bomber 동시 폭발 시 in_transit 카운터 정합성**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
