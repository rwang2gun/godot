---
name: stage2-builder
duration_estimate: 7200
---

# Phase 3: Stage 2 + Builder 스킬 (빌드 0.2)

## 목표
스킬 시스템 활성화. Builder로 사선 다리를 놓아야 클리어 가능한 Stage 2 추가. Stage 1은 회귀 없이 그대로 동작.

## 변경 대상
**core**:
- `scripts/skills/Skill.gd` (베이스: ID const, apply(ant), can_apply(ant))
- `scripts/skills/BuilderSkill.gd` (ID="builder", apply → WorkerState.new("builder")로 전이)
- `scripts/core/SkillRegistry.gd`: `SKILL_SCRIPTS`에 BuilderSkill preload 추가, `validate_stage()`가 stageNN.tres의 미등록 ID 검출

**ant**:
- `scripts/ant/states/WorkerState.gd` (work_type 인자, builder 시 12셀 사선 타일 추가 후 Walker 복귀)

**world**:
- `scripts/world/Terrain.gd`: `add_tile_diagonal(start_cell, direction, count)` 메서드 추가 (Layer 0 destructible)

**ui**:
- `scenes/ui/SkillToolbar.tscn` (스킬 버튼 + 인벤토리 카운트)
- `scripts/ui/SkillToolbar.gd` (StageData.skill_inventory 구독, 클릭 시 cursor 모드 전환 → 다음 클릭한 개미에게 적용)

**stage**:
- `scenes/stages/Stage02.tscn` (협곡 — Builder 없으면 사탕 도달 불가)
- `data/stages/stage02.tres` (skill_inventory={"builder":3})

## 검증 방법
1. Stage 1 회귀: F5 → Stage01 클리어 가능 (skill 0개)
2. Stage 2 진입 → SkillToolbar에 Builder 3개 표시
3. Builder 클릭 → 개미 클릭 → WorkerState 전이 → 사선 12셀 추가 → Walker 복귀
4. 추가된 타일 위로 다른 개미가 통과 → 사탕 도달 가능
5. SkillRegistry.validate_stage(stage02) → 에러 없음

## 엣지 케이스 (필수)
- **Builder 작업 중 개미가 절벽 끝에 닿으면 작업 중단** (현재 위치에서 Walker 복귀)
- **타일 배치 시 indestructible 위에 덮어쓰기 금지**
- **이미 WorkerState인 개미에 Builder 재적용 거부** (`can_apply` false)

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
