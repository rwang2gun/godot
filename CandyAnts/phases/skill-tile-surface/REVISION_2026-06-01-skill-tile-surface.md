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
- `scripts/ant/states/WorkerState.gd` — `_update_bridge` / `_enter_builder` / `_destroy_digger_cell` / `_destroy_basher_cell`.

## Phase 분해 (선형) — 2026-06-01 개정
초기엔 "땅파기(digger)"로 보고됐으나, Stage 3의 실제 굴착 스킬은 **basher**임이 확인됨(사용자: digger/basher
혼동, 가로 굴착 시 걸을 수 있는 면=surface가 핵심). 그에 따라 basher를 in-scope로 올리고 우선순위 재배치:
1. **surface-skin-infra** (셋업, 완료) — Terrain 테마-aware 3-tier 스킨 인프라 + 텍스처 등록.
2. **digger-exposed-surface** (완료) — `destroy_tile_at(..., apply_below_surface_cap=true)` opt-in으로 digger 파낸 칸 아래 캡.
3. **basher-exposed-surface** — basher가 뚫은 칸 아래(터널 바닥)에 동일 opt-in으로 캡. **Stage 3 실제 굴착 스킬.**
4. **basher-headroom-tier** — basher가 몸통+위 행 2칸 제거(머리공간) + 터널 바닥 2-tier(surface + 아래 under-surface).
   (Stage 3 프로토타입 확인 후 사용자 요청 추가. digger는 이번 제외.)
5. **bridge-builder-surface** — bridge·builder 생성 타일이 surface tier 윗면을 갖게 (프로토타입 확인 후 시각 방향 결정).

계약: 굴착 스킬(digger·basher) = `destroy_tile_at` opt-in true로 아래 칸 캡 / cutter = false 무캡.

## 범위 밖
- 수직 dig shaft / 가로 터널의 **측벽**(파낸 단면) surface — 윗면(walkable top) 캡만 다룸.
- slope / plant / hazard 시각 (TERRAIN_TILE_RULES §0 범위 밖 유지).
- slope / plant / hazard 시각 (TERRAIN_TILE_RULES §0 범위 밖 유지).
