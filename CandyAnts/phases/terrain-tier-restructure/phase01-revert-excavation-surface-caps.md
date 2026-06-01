---
name: revert-excavation-surface-caps
duration_estimate: 5400
verify: python scripts/run_test.py tests/BasherTunnelThroughWallTest.tscn && python scripts/run_test.py tests/BasherEdgeStopTest.tscn && python scripts/run_test.py tests/DiggerVerticalTunnelTest.tscn && python scripts/run_test.py tests/TerrainDestroyTileApiTest.tscn && python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/Terrain.gd, scripts/ant/states/WorkerState.gd, scripts/world/StageLayoutBuilder.gd, phases/terrain-tier-restructure/REVISION_2026-06-01-terrain-tier-restructure.md]
---

# Phase 1: revert-excavation-surface-caps

## 목표
직전 트랙 `skill-tile-surface`(Phase 1~4)가 추가한 **굴착 surface 캡 인프라를 통째 제거**하고,
digger/basher를 **Phase 18 동작**(굴착 칸 1개 제거, 캡/재스킨/머리공간 없음)으로 복귀시킨다.
**정적 지형 렌더는 무변경** — surface 타일/오버레이는 Phase 2에서 제거한다.

## 배경
- surface tier 자체를 없애기로 했으므로(REVISION §2), "굴착으로 드러난 바닥 = surface 캡" 로직은 모순.
- 캡 인프라는 `docs/TERRAIN_TILE_RULES.md`에 박제돼 있지 않다(skill-tile-surface 자체 phase 문서에만 존재)
  → 이 phase는 **SoT 문서 불변**, 코드/테스트만 정리한다.
- basher 2칸 머리공간(Phase 4)도 함께 제거 → basher 1칸 터널(Phase 18) 복귀(REVISION 결정 #4).

## 변경 대상
- `scripts/world/Terrain.gd` — 다음을 제거:
  - 필드/상수: `COOKIE_SURFACE_CAP_NAME`, `_cookie_surface_tex`, `_cookie_under_tex`, `_cookie_background_tex`.
  - 메서드: `register_cookie_tier_textures`, `get_cookie_surface_texture`, `get_cookie_under_texture`,
    `get_cookie_background_texture`, `apply_cookie_surface_overlay`, `_configure_cookie_region`,
    `_cap_exposed_below`, `_is_solid_cookie_body`, `apply_under_surface_at`, `destroy_static_cookie_cell`.
  - `destroy_tile_at`: `apply_below_surface_cap` 파라미터 + 본문의 `if apply_below_surface_cap: _cap_exposed_below(cell)`
    제거 → Phase 18 시그니처 `destroy_tile_at(cell, allowed_kinds=["earth"]) -> bool` 복귀.
  - **sand-mound(§11) 관련(`_sand_*`, `_reskin_sand_column`, `_apply_sand_tier` 등)은 절대 건드리지 않는다** —
    별도 동적 시스템. cookie 캡 인프라만 정밀 제거.
- `scripts/ant/states/WorkerState.gd`
  - `_destroy_digger_cell`: `destroy_tile_at(target, ["earth"], true)` → `destroy_tile_at(target, ["earth"])`.
  - `_destroy_basher_cell`: `destroy_tile_at(target, ["earth"], true)` → `destroy_tile_at(target, ["earth"])`,
    그리고 `destroy_static_cookie_cell(target + (0,-1))`(머리공간) + `apply_under_surface_at(target + (0,2))`(바닥 재스킨)
    **두 호출 제거** → basher 1칸 터널.
- `scripts/world/StageLayoutBuilder.gd`
  - `build()` 내 `terrain.register_cookie_tier_textures(...)` 호출(약 line 58~62) 제거. (`_surface_texture()`는
    Phase 2에서 다룸 — 이 phase에선 호출만 제거.)
- 테스트 제거(파일 삭제, `.gd` / `.gd.uid` / `.tscn` 3종 세트):
  - `tests/CookieSurfaceOverlayTest.*`, `tests/DiggerExposedSurfaceTest.*`,
    `tests/BasherExposedSurfaceTest.*`, `tests/BasherHeadroomTierTest.*`.
  - dev 픽스처: `data/stage_layouts/dev_basher_headroom_layout.tres`, `scenes/stages/dev/BasherHeadroomTest.tscn`.

## 비목표 (이 phase에서 하지 않음)
- `surface` 타일 타입 / 노출천장 오버레이 / `_solid_texture_for_cell` 규칙 변경 (Phase 2).
- 레이아웃 `.tres` 마이그레이션 (Phase 2).
- `TERRAIN_TILE_RULES.md` 재작성 (Phase 2).
- sand-mound / 슬로프 관련 코드.

## 검증 방법
- `verify` 명령(basher/digger/terrain-API/Stage03 회귀) 전부 PASS.
- `TerrainDestroyTileApiTest`는 2-arg `destroy_tile_at`만 호출 → 시그니처 축소에도 통과해야 함.
- basher가 1칸 터널을 뚫는지(머리공간 없음) 헤드리스/실측 확인.
- grep으로 `apply_below_surface_cap` / `destroy_static_cookie_cell` / `apply_under_surface_at` /
  `apply_cookie_surface_overlay` / `register_cookie_tier_textures` / `_cap_exposed_below` /
  `COOKIE_SURFACE_CAP` 잔존 참조 0건 확인(소스 + 테스트).
