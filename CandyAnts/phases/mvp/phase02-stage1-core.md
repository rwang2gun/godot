---
name: stage1-core
duration_estimate: 10800
---

# Phase 2: Stage 1 Vertical Slice (빌드 0.1)

## 목표
Stage 1을 풀 가능 — 개미가 자동으로 사탕 픽업 → 180° 귀환 → Home 도착, 클리어 다이얼로그 표시. 스킬 0개로 클리어.

## 변경 대상
**ant**:
- `scripts/ant/Ant.gd` (CharacterBody2D, 중력+이동, state_machine 자식 보유, `velocity.x` 부호로 진행방향)
- `scripts/ant/AntStateMachine.gd` (current_state + change_state + update)
- `scripts/ant/AntState.gd` (베이스: enter/exit/update + ant 참조)
- `scripts/ant/states/{Walker,Faller,Carrying,Saved,Dead}State.gd`
- `scenes/entities/Ant.tscn` (CharacterBody2D + CollisionShape2D + ColorRect 12x10 placeholder, layer=3 mask=1+2)

**world**:
- `scripts/world/Candy.gd` (Area2D + hp:int, body_entered → hp-1 + EventBus.candy_piece_picked + ant 상태를 Carrying으로)
- `scripts/world/Home.gd` (Area2D, body_entered → ant가 Carrying이면 ant_saved(true), Walker(귀환 중)면 ant_saved(false))
- `scripts/world/Terrain.gd` (TileMap 래퍼 — MVP는 빈 셸, Phase 6에서 채움)
- `scenes/entities/Candy.tscn` (Area2D layer=5 mask=3 monitoring=true + ColorRect 노란색 placeholder)
- `scenes/entities/Home.tscn` (Area2D layer=6 mask=3 monitoring=true + ColorRect 갈색 placeholder)

**core**:
- `scripts/core/StageData.gd` (Resource, ARCHITECTURE §4.1 export 변수 전체)
- `scripts/core/StageRunner.gd` (스폰 오케스트레이터 + 클리어/실패 판정)
- `scripts/core/AntSpawner.gd` (Release Rate에 따라 Timer 기반 스폰)
- `scripts/core/ScoreSystem.gd` (4-카운터 + 불변식 assert + is_cleared() + 점수 계산, ARCHITECTURE §4.5)

**ui**:
- `scenes/ui/HUD.tscn` (Time / Out / Saved / Lost / Candy HP 라벨)
- `scripts/ui/HUD.gd` (EventBus 구독)
- `scenes/ui/StageCompleteDialog.tscn`

**stage**:
- `scenes/stages/Stage01.tscn` (TileMap 평지 + Home + Candy + StageRunner + HUD)
- `data/stages/stage01.tres` (total_ants=10, candy_hp=10, time_limit=120, available_skills=[], release_rate_initial=50)

## 검증 방법
1. F5 → Stage01 진입 → 개미가 Home에서 출현 시작
2. 개미가 평지를 걸어 Candy 도달 → HP -1, 색 변화/이펙트, 180° 회전
3. 운반 중 개미는 0.78배 속도로 Home 방향 귀환
4. Home 도착 시 ant_saved 발화 → Saved 카운터 증가
5. Candy HP 0 + in_transit 0 → StageCompleteDialog 표시 (점수 100%)
6. 시간 초과 시 stage_failed
7. **§5.6 4단계 점검**: Candy의 body_entered가 실제로 발화하는가?

## 엣지 케이스 (필수)
- **Walker 귀환 시 Candy 또 만나면 무시** (이미 Carrying이거나 빈손 귀환자는 재픽업 안 함)
- **Home에서 스폰 직후 즉시 Saved 트리거 방지** (스폰 grace period 또는 처음 한 번 충돌 무시)
- **운반자 사망 시 in_transit -1 + lost +1** (Phase 5 Hazard에서 첫 발생, 이번 phase에서는 인터페이스만 노출)

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
