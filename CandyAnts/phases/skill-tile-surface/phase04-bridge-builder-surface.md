---
name: bridge-builder-surface
duration_estimate: 5400
verify: python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/Terrain.gd, scripts/ant/states/WorkerState.gd, phases/skill-tile-surface/REVISION_2026-06-01-skill-tile-surface.md]
---

# Phase 2: bridge-builder-surface

## 목표
bridge·builder 스킬이 생성하는 동적 타일이 **걷는 윗면에 cookie surface tier**를 갖게 한다.
현재는 둘 다 `add_tile(target)` 기본값(`DYNAMIC_TILE_BRIDGE` = 단일 thin bridge 텍스처)을 써서
cookie surface 구조를 따르지 않는다.

## 배경
- `WorkerState._update_bridge` ([:241]) + builder 경로([:299])가 `terrain.add_tile(target)`을
  visual_style 인자 없이 호출 → `DYNAMIC_TILE_BRIDGE`.
- Phase 1에서 만든 surface-skin 인프라를 사용해, 이 타일들의 윗면을 surface tier로 렌더.
- **게임플레이(충돌/점유/D8) 불변** — 시각만 변경. bridge의 "얇은 다리" 충돌 특성은 유지하되
  윗면 시각이 cookie surface로 읽히게 한다 (단일 sticker 인상 제거).

## ⚠️ Plan 리뷰 MEDIUM 반영 — 얇은-다리 시각 계약 보존 (필수)
Phase 1 인프라의 surface 오버레이는 `_add_solid_visual`과 동치인 **셀 크기(cell_size×cell_size)**
sprite다. 기존 bridge는 특수 scale/offset의 **얇은 스프라이트**(`_configure_dynamic_tile_sprite`:
16px native, `position.y = -13*scale_factor`). 셀 크기 surface를 그대로 얹으면 충돌이 그대로여도
**시각이 꽉 찬 solid 타일처럼 읽힌다.**

→ **bridge/builder 전용 "얇은 top 캡" 스타일을 명시한다:**
- 기존 얇은 bridge 스프라이트의 **경계(bounds)·offset·z-order를 보존**한다.
- surface tier는 그 얇은 윗면 영역에만 clip/offset 되어 얹힌다 (셀 전체 채우기 금지).
- 즉 Phase 1 헬퍼를 bridge에 쓸 때는 셀 크기 오버레이가 아니라 **bridge bounds에 맞춘 narrow top cap**
  파라미터를 전달한다 (Phase 1 헬퍼가 region/scale을 받도록 일반화되어 있어야 함 — Phase 1 의존).

## 변경 대상
- `scripts/world/Terrain.gd`
  - bridge·builder용 visual_style(또는 add_tile 옵션)에서 Phase 1 인프라로 **얇은 top 캡** surface 적용.
    bridge 충돌 형상/위치 + 스프라이트 scale·offset·z-order는 회귀 0 유지.
- `scripts/ant/states/WorkerState.gd`
  - bridge·builder의 `add_tile` 호출이 새 surface 시각 경로를 타도록 (게임플레이 인자 무변경).

## 비목표
- digger 노출 바닥 (Phase 3).
- bridge를 "3칸 두께 solid 블록"으로 바꾸는 것 — 얇은 다리 게임플레이 유지, 윗면 시각만 surface.

## 검증 방법
- `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` — 회귀 0.
- dev 레이아웃 시각 확인: `data/stage_layouts/dev_bridge_layout.tres`,
  `dev_basher_digger_chain_layout.tres`로 bridge·builder 타일 윗면이 cookie surface로 보이는지.
- **신규 회귀 테스트 (MEDIUM 가드): bridge 시각 스프라이트의 치수(bounds)·offset이 기존 얇은 값으로
  유지되는지 assert** — "surface가 보이는지"만이 아니라 **얇은 실루엣 보존**을 검증.
- 기존 bridge 회귀 테스트(있으면) 통과 유지 — 충돌·점유·D8 reject 불변.
