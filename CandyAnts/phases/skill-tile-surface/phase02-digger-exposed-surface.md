---
name: digger-exposed-surface
duration_estimate: 5400
verify: python scripts/run_test.py tests/DiggerExposedSurfaceTest.tscn && python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/Terrain.gd, scripts/ant/states/WorkerState.gd, phases/skill-tile-surface/REVISION_2026-06-01-skill-tile-surface.md]
---

# Phase 3: digger-exposed-surface

## 목표
digger가 세로로 파서 타일을 제거하면, **새로 드러난 아래 칸**(`cell + (0,1)`)이 여전히 solid earth일 때
그 윗면에 cookie surface 캡(오버레이)을 동적으로 입힌다. 파인 바닥이 맨 interior로 노출되는 어색함 제거.

## 배경
- `Terrain.destroy_tile_at(cell)`은 body를 통째로 `queue_free` + registry 4종 erase만 수행.
  새로 노출된 아래 칸의 시각은 빌드 타임 interior(background)로 baked된 채 남는다.
- `_add_solid_visual` 2번 규약("위 칸이 비면 surface 오버레이")을 런타임에 재적용하는 것과 동치.
- Phase 1 surface-skin 인프라(`_apply_cookie_surface_overlay`) 사용.

## ⚠️ Plan 리뷰 HIGH 반영 — digger 경로로 게이팅 (필수)
`Terrain.destroy_tile_at`은 digger 전용이 아니다 — `WorkerState._destroy_basher_cell`도
`destroy_tile_at(target, ["earth"])`를 호출한다. surface 캡을 `destroy_tile_at` 안에서 **무조건**
적용하면 스코프에서 제외한 basher(수평 파괴) 노출 셀에도 캡이 붙어 범위 밖·미검증 상태가 된다.

→ **반드시 digger 경로로만 게이팅한다.** 채택 방식:
- `destroy_tile_at(cell, allowed_kinds, apply_below_surface_cap := false)`로 **opt-in 파라미터** 추가
  (기본 false → 기존 호출자 basher/cutter/sand 무영향, D8·atomic 불변).
- `WorkerState._destroy_digger_cell`만 `apply_below_surface_cap = true`로 호출.
- 다른 호출처(`_destroy_basher_cell`, `_update_cutter`)는 기본값 false 유지.

## 변경 대상
- `scripts/world/Terrain.gd`
  - `destroy_tile_at`에 `apply_below_surface_cap := false` 파라미터 추가. true일 때만,
    kind 검사·파괴 성공 후 `below = cell + (0,1)`가 여전히 solid earth
    (`_static_bodies` 또는 `_placed`에 존재 + kind=="earth")면 그 body에 surface 오버레이를 멱등 추가.
  - atomic invariant 유지: kind 검사 전 무변경, 파괴 실패 시 시각 변경 없음. opt-in이 false면 기존 동작 완전 동일.
  - sand_mound 동적 타일(`_sand_mound_sprites`)은 자체 reskin 경로가 있으므로 중복 적용 회피.
- `scripts/ant/states/WorkerState.gd`
  - `_destroy_digger_cell`만 `apply_below_surface_cap = true`로 호출. basher/cutter 경로 무변경.

## 비목표
- 수직 측벽(파낸 단면)의 surface — 범위 밖.
- basher(수평 파괴) 노출 셀 — 별도 task. **(이번 phase에서 명시적으로 false 유지로 보장)**
- 여러 칸을 연속으로 팔 때 측벽 표현 — 윗면(천장 노출) 캡만 다룸.

## 검증 방법
- `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` — 회귀 0.
- `data/stage_layouts/dev_digger_pillar_layout.tres` / `data/stages/dev/digger_pillar_test.tres`로
  digger 후 드러난 바닥에 surface 캡이 보이는지 시각·헤드리스 확인.
- 신규 헤드리스 테스트:
  - digger destroy(opt-in true) 후 아래 칸에 surface 오버레이 1장 추가 + 멱등 + 비-earth/공기 칸엔 미적용.
  - **basher destroy(opt-in 기본 false) 후 아래 칸에 surface 오버레이가 추가되지 않음** (HIGH 회귀 가드).
  - `data/stage_layouts/dev_basher_digger_chain_layout.tres`로 basher 구간이 캡을 안 받는지 확인.
