---
name: surface-skin-infra
duration_estimate: 5400
verify: python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/Terrain.gd, scripts/world/StageLayoutBuilder.gd, phases/skill-tile-surface/REVISION_2026-06-01-skill-tile-surface.md]
---

# Phase 1: surface-skin-infra

## 목표
Terrain에 "동적 cell에 cookie 3-tier surface 스킨을 입히는" 재사용 인프라를 일반화하고,
빌드 타임에 테마-aware surface/under/background 텍스처를 Terrain에 등록한다. **기존 동작 무변경** —
인프라 + 테스트만. (sand_mound `_reskin_sand_column` / `_apply_sand_tier`가 선례.)

## 배경
- 현재 cookie 지형 텍스처 선택 로직(`_surface_texture` / `_solid_texture_for_cell` / `_get_tile_texture_for_cell`)은
  `StageLayoutBuilder`에 string `if/elif` theme chain으로 박혀 있다 (TERRAIN_TILE_RULES §9-2 한계).
- sand_mound 동적 reskin은 `Terrain` 안에 surface/under/background 텍스처를 직접 `load`해 갖고 있다.
- Phase 2(bridge·builder)·Phase 3(digger)가 둘 다 "동적으로 cookie surface tier를 입히는" 동작을
  필요로 하므로, 그 공통 메커니즘을 먼저 Terrain에 만든다.

## 변경 대상
- `scripts/world/Terrain.gd`
  - 빌드 타임에 cookie surface/under/background 텍스처(현 stage theme 기준)를 등록받는 setter
    (예: `register_cookie_tier_textures(surface, under, background)`), null-safe.
  - 임의의 cell/body에 surface 오버레이 sprite를 추가하는 헬퍼(예: `_apply_cookie_surface_overlay(body, cell, ...)`),
    `_add_solid_visual` 2번(노출 천장 → surface 오버레이)과 동일 시각 규약. 멱등(중복 호출 시 오버레이 1장 유지).
  - **헬퍼는 geometry를 일반화한다 (Phase 2 MEDIUM 의존)**: 셀 크기 오버레이(digger/solid 기본)와
    bridge용 **narrow top 캡**(bounds·offset·z-order 보존)을 모두 표현할 수 있게 region/scale/offset 인자를 받는다.
    Phase 2(bridge 얇은 캡)·Phase 3(digger 셀 크기 캡)이 같은 헬퍼를 다른 geometry로 호출.
- `scripts/world/StageLayoutBuilder.gd`
  - `build()`에서 Terrain에 위 텍스처 등록 1회 호출 (theme chain 재사용, 새 분기 없음).

## 비목표 (이 phase에서 하지 않음)
- bridge·builder·digger의 실제 동작 변경 (Phase 2/3).
- 수직 측벽 surface, basher 노출 셀.

## 검증 방법
- `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` — Stage 3 회귀 0건(시각 인프라 추가가
  기존 충돌/점유/스코어에 영향 없음).
- 기존 `tests/test_StageLayoutBuilder.gd` invariant(§8) 통과 유지.
- 신규: Terrain 인프라 단위 테스트 — 등록된 텍스처 getter 정합 + 오버레이 헬퍼 멱등성
  + geometry 인자(셀 크기 vs narrow 캡)별 sprite bounds 정합.
