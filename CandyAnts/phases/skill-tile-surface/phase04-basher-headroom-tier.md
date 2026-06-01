---
name: basher-headroom-tier
duration_estimate: 5400
verify: python scripts/run_test.py tests/BasherHeadroomTierTest.tscn && python scripts/run_test.py tests/BasherExposedSurfaceTest.tscn && python scripts/run_test.py tests/BasherTunnelThroughWallTest.tscn && python scripts/run_test.py tests/BasherEdgeStopTest.tscn && python scripts/run_test.py tests/BasherOnPlantRejectedTest.tscn && python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/Terrain.gd, scripts/ant/states/WorkerState.gd, phases/skill-tile-surface/REVISION_2026-06-01-skill-tile-surface.md]
---

# Phase 4: basher-headroom-tier

## 목표
basher가 가로 굴착할 때 **몸통 행 + 바로 위 행(머리공간)을 함께 제거해 2칸 높이 터널**을 만들고,
터널 **바닥을 2-tier로 표현**한다 — 바닥 칸=surface, 그 아래 칸=under-surface. 단조로운 surface-위-interior
단면을 자연스러운 쿠키 가장자리(surface→under-surface)로 개선 + 개미 머리 공간 확보.

## 좌표계 / 기하 (좌표: +X 오른쪽, **+Y 아래**)
`_destroy_basher_cell` 기준 (`body_cell` = 개미 몸통 셀, `dir` = 진행 방향):
- `target = body_cell + (dir, 0)` — 몸통 높이 벽 (기존 제거 대상). **여기에 surface 캡 opt-in(Phase 3) 유지.**
- `above = target + (0, -1)` — 머리 높이 (위). **신규 제거 (머리공간). 캡 불필요.**
- `floor = target + (0, 1)` — 터널 바닥. surface 캡(이미 `_cap_exposed_below`가 처리).
- `under = target + (0, 2)` — 바닥 아래. **신규: under-surface로 재스킨.**
- 개미 보행 바닥(`floor`)은 제거하지 않음 → 보행/패싱 게임플레이 불변. 파괴는 위로만 2배.

## 변경 대상
- `scripts/world/Terrain.gd`
  - 신규 `apply_under_surface_at(cell)` — 해당 셀이 정적 사각 solid cookie(`_is_solid_cookie_body`)면
    그 `BaseSprite` 텍스처를 등록된 under-surface(`_cookie_under_tex`, Phase 1)로 재스킨(멱등, region 동일 규약).
    null 텍스처/비-solid면 no-op. surface 캡(CookieSurfaceCap)과 공존(별개 노드).
  - 신규 `destroy_static_cookie_cell(cell) -> bool` — **머리공간 제거 가드(MEDIUM 결정: 정적 쿠키 벽만)**.
    `kind=="earth"` AND `_static_bodies`에 존재(동적 `_placed` 제외) AND `_is_solid_cookie_body`(slope/plant 제외)일 때만
    `destroy_tile_at(cell, ["earth"])`로 제거하고 true 반환. 그 외(동적 bridge/sand·slope·plant·공기)는 **보존**하고 false.
- `scripts/ant/states/WorkerState.gd`
  - `_destroy_basher_cell`:
    1. `destroy_tile_at(target, ["earth"], true)` — 기존(바닥 surface 캡). 실패 시 abort 유지.
    2. `terrain.destroy_static_cookie_cell(above)` — 머리공간. **정적 쿠키 벽만 제거, 결과 무시**
       (동적 다리/모래·윗길 바닥·공기는 보존). 캡 불필요(아래=`target`은 이미 제거됨).
    3. `terrain.apply_under_surface_at(under)` — 바닥 아래 칸 under-surface.
  - digger/cutter 경로 무변경 (이번 스코프 아님).

## 비목표
- digger의 2-tier — 세로 샤프트는 의미 약함, 이번 제외(surface-only 유지).
- 터널 측벽(세로 단면) surface — 계속 제외.
- bridge·builder — Phase 5.

## 게임플레이/회귀 영향 (명시)
- basher 파괴량이 **행당 2배(위로 확장)**. 보행 바닥은 유지되어 이동/클리어 로직 불변.
- 기존 basher 테스트 갱신/확인 필요:
  - `BasherTunnelThroughWallTest`: 벽 cell 제거 검증 — 위 행 추가 제거가 통과를 깨지 않는지 확인(벽 cell 잔존 0 단언은 유지).
  - `BasherExposedSurfaceTest`: 바닥 surface 캡 — 유지(여전히 유효).
  - `BasherOnPlantRejectedTest` / `BasherEdgeStopTest`: earth-only 파괴·정지 로직 불변 확인.

## 검증 방법 (verify 체인 = HIGH 대응으로 basher 회귀 3종 포함)
- 신규 `tests/BasherHeadroomTierTest.gd`: 실제 basher 주행으로 (1) 위 행(정적 쿠키)도 제거(2칸 높이)
  (2) 바닥=surface 캡 (3) 바닥 아래=under-surface 재스킨 (4) 위가 공기/동적 타일인 구간에선 보존·no-op·크래시 없음
  (정적 쿠키 벽만 제거 계약 검증).
- verify 체인: BasherHeadroomTier + BasherExposedSurface + **BasherTunnelThroughWall + BasherEdgeStop +
  BasherOnPlantRejected** + Stage03. (회귀 3종을 게이트에 포함 — plan 리뷰 HIGH 대응.)
