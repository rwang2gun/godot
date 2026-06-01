---
name: digger-exposed-surface
duration_estimate: 5400
verify: python scripts/run_test.py tests/DiggerExposedSurfaceTest.tscn && python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/Terrain.gd, scripts/ant/states/WorkerState.gd, phases/skill-tile-surface/REVISION_2026-06-01-skill-tile-surface.md]
---

# Phase 2: digger-exposed-surface

> **⚠️ SUPERSESSION (Phase 3, 2026-06-01):** 이 문서가 "basher는 opt-in false 유지 / basher 노출 셀은
> 범위 밖" 이라고 적은 부분은 **Phase 2 시점의 스코프**다. 사용자가 Stage 3 실제 굴착 스킬이 basher임을
> 확인한 뒤, **Phase 3(basher-exposed-surface)에서 basher도 의도적으로 opt-in true로 캡**하도록 변경했다.
> 즉 아래의 basher 관련 "false 유지/제외/캡 미적용" 서술은 Phase 3로 supersede됨 — 현재 계약은
> "굴착(digger·basher)=opt-in true 캡, cutter=false 무캡". 본 문서의 digger 내용은 그대로 유효.

## 목표
digger가 세로로 파서 타일을 제거하면, **새로 드러난 아래 칸**(`cell + (0,1)`)이 여전히 solid earth일 때
그 윗면에 cookie surface 캡(오버레이)을 동적으로 입힌다. 파인 바닥이 맨 interior로 노출되는 어색함 제거.

## 배경
- `Terrain.destroy_tile_at(cell)`은 body를 통째로 `queue_free` + registry 4종 erase만 수행.
  새로 노출된 아래 칸의 시각은 빌드 타임 interior(background)로 baked된 채 남는다.
- `_add_solid_visual` 2번 규약("위 칸이 비면 surface 오버레이")을 런타임에 재적용하는 것과 동치.
- Phase 1 surface-skin 인프라(`_apply_cookie_surface_overlay`) 사용.

## opt-in 게이팅 설계 (Plan 리뷰 HIGH 대응)
`Terrain.destroy_tile_at`은 digger 전용이 아니다 — `_destroy_basher_cell` 등 여러 호출처가 공유한다.
그래서 surface 캡을 `destroy_tile_at` 안에서 **무조건** 적용하면 안 되고, **호출처가 opt-in으로 켜는** 구조를 쓴다:
- `destroy_tile_at(cell, allowed_kinds, apply_below_surface_cap := false)` — 기본 false라 opt-in 안 한
  호출처는 D8·atomic 불변, 기존 동작 동일.
- **굴착 스킬이 호출처에서 true로 켠다.**

> **현재 계약 (Phase 3 기준):** `_destroy_digger_cell`(Phase 2) + `_destroy_basher_cell`(Phase 3) **둘 다
> opt-in true**로 호출해 캡을 켠다. `_update_cutter`는 false 유지(무캡).
> *(Phase 2 원안은 "digger 경로로만 게이팅, basher는 false"였으나 — Stage 3 실제 굴착 스킬이 basher임이
> 확인되어 Phase 3에서 basher도 true로 supersede. 아래 "변경 대상"의 basher false 서술은 Phase 2 시점 기록.)*

## 변경 대상 (Phase 2 시점)
- `scripts/world/Terrain.gd`
  - `destroy_tile_at`에 `apply_below_surface_cap := false` 파라미터 추가. true일 때만,
    kind 검사·파괴 성공 후 `below = cell + (0,1)`가 여전히 solid earth
    (`_static_bodies` 또는 `_placed`에 존재 + kind=="earth")면 그 body에 surface 오버레이를 멱등 추가.
  - atomic invariant 유지: kind 검사 전 무변경, 파괴 실패 시 시각 변경 없음. opt-in이 false면 기존 동작 완전 동일.
  - sand_mound 동적 타일(`_sand_mound_sprites`)은 자체 reskin 경로가 있으므로 중복 적용 회피.
- `scripts/ant/states/WorkerState.gd`
  - `_destroy_digger_cell`을 `apply_below_surface_cap = true`로 호출.
    *(Phase 2 시점엔 basher/cutter는 false였음 → Phase 3에서 basher는 true로 변경, cutter는 false 유지.)*

## 비목표
- 수직 측벽(파낸 단면)의 surface — 범위 밖.
- basher(수평 파괴) 노출 셀 — Phase 2 당시 별도 task로 분리(이 phase는 false 유지). **→ Phase 3에서 basher도 opt-in true로 캡(supersede).**
- 여러 칸을 연속으로 팔 때 측벽 표현 — 윗면(천장 노출) 캡만 다룸.

## 검증 방법
- `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` — 회귀 0.
- `data/stage_layouts/dev_digger_pillar_layout.tres` / `data/stages/dev/digger_pillar_test.tres`로
  digger 후 드러난 바닥에 surface 캡이 보이는지 시각·헤드리스 확인.
- 신규 헤드리스 테스트:
  - digger destroy(opt-in true) 후 아래 칸에 surface 오버레이 1장 추가 + 멱등 + 비-earth/공기 칸엔 미적용.
  - opt-in=false 경로 후 아래 칸에 surface 오버레이가 추가되지 않음 (`_test_no_cap_when_optin_false`).
    **(Phase 2 원안은 "basher 미적용" 가드였으나, Phase 3에서 basher가 opt-in true로 캡하게 되어
    이 케이스는 cutter 등 false 경로 계약으로 재정의됨. basher positive 계약은 BasherExposedSurfaceTest.)**
