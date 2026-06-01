# Task: skill-tile-surface — 스킬 타일 surface tier 일관화

## 배경
3스테이지 등 3-tier(surface / under-surface / background) cookie 지형에서, 스킬이
생성하거나 파괴한 타일이 cookie surface 구조를 따르지 않아 시각적으로 어색하다.

- **bridge·builder**: `WorkerState`가 `terrain.add_tile(target)`를 기본값
  (`DYNAMIC_TILE_BRIDGE` = 단일 thin bridge 텍스처)으로 호출 → cookie surface tier 없음.
- **digger**: `terrain.destroy_tile_at(cell)`가 body를 통째로 `queue_free`만 하고,
  새로 드러난 **아래 칸**(`cell + (0,1)`)에 surface 캡을 입히지 않음 → 파인 바닥이
  맨 interior(초콜릿 단면)로 노출.
- **sand_mound**: 이미 `DYNAMIC_TILE_SAND_MOUND` + `_reskin_sand_column`으로 3-tier 적용 (선례).

## 통합 설계 원칙
**개미가 걷는 윗면(walkable top)은 항상 cookie `surface` tier로 보인다.**

- bridge·builder 생성 타일 → 윗면에 surface tier 적용.
- digger로 드러난 바닥 → 새 윗면 칸에 surface 캡(오버레이) 동적 추가.
- **수직 측벽(파낸 단면)의 surface 처리는 이번 task 범위 밖.**

## SoT
- `docs/TERRAIN_TILE_RULES.md` — 3-tier 시각 시스템 SoT (§3 `_add_solid_visual`, §11 sand-mound `_reskin`).
- `scripts/world/Terrain.gd` — `destroy_tile_at` / `add_tile` / `_reskin_sand_column` / `_apply_sand_tier`.
- `scripts/world/StageLayoutBuilder.gd` — `_add_solid_visual` / `_surface_texture` / `_solid_texture_for_cell`.
- `scripts/ant/states/WorkerState.gd` — `_update_bridge` / `_enter_builder` / `_destroy_digger_cell`.

## Phase 분해 (선형)
1. **surface-skin-infra** (셋업) — Terrain에 테마-aware 3-tier 스킨 적용 인프라 일반화 +
   빌드 타임 surface/under/background 텍스처 등록. 기존 동작 무변경, 인프라 + 테스트만.
2. **bridge-builder-surface** — bridge·builder 생성 타일이 surface tier 윗면을 갖게.
3. **digger-exposed-surface** — `destroy_tile_at` 직후 아래 노출 칸에 surface 캡 동적 추가.

## 범위 밖
- 수직 dig shaft 측벽 surface.
- basher(수평 파괴) 노출 셀 surface (별도 task 후보).
- slope / plant / hazard 시각 (TERRAIN_TILE_RULES §0 범위 밖 유지).
