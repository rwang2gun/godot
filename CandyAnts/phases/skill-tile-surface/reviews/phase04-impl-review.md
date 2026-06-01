# Phase 4 (basher-headroom-tier) — Impl-stage Adversarial Review

## Self-Review Round 1 (2026-06-01)
구현:
- `Terrain.destroy_static_cookie_cell(cell)` — 정적 사각 cookie(`_static_bodies` + `_is_solid_cookie_body`)만
  제거(true). 동적(`_placed` bridge/sand)·slope·plant·공기는 보존(false). (MEDIUM 결정 = 정적 쿠키 벽만.)
- `Terrain.apply_under_surface_at(cell)` — 정적 cookie BaseSprite를 등록 under-surface로 재스킨(멱등: resource_path
  비교), 비-solid/null no-op.
- `WorkerState._destroy_basher_cell` — destroy(target,true)[기존] + destroy_static_cookie_cell(target+(0,-1))[머리공간]
  + apply_under_surface_at(target+(0,2))[바닥 아래]. abort는 target에만 묶임(머리·under는 best-effort).

HIGH 0:
- 머리공간 제거가 정적 쿠키만 → 플레이어 다리/모래·윗길·공기 보존(unit-tested). 측벽/천장은 캡 안 함(올바름).
- under cell(target+2)은 basher 기하상 항상 deep(빌드 시 covered) → SurfaceSprite 없음. base만 under로 교체 안전.
- abort 의미·전진 로직 불변. digger/cutter 무변경.
- 보행 바닥(target+1) 미제거 → 이동/패싱 게임플레이 불변.

검증(verify 체인 + 회귀):
- BasherHeadroomTierTest PASS: [UNIT] destroy_static_cookie_cell(정적 제거/동적·slope·공기 보존) +
  apply_under_surface_at(재스킨·멱등·no-op); [INTEGRATION 실주행] 머리행(20) 제거 + 바닥(22) surface 캡 +
  아래(23) under-surface.
- BasherExposedSurface / BasherTunnelThroughWall / BasherEdgeStop / BasherOnPlantRejected / Digger×2 /
  CookieSurfaceOverlay / Stage03 — 전부 PASS (2행 파괴가 회귀 0).
→ 자체 clean, codex 리뷰 진행.

## Round 1 (codex, 2026-06-01)
Target: working tree diff | Verdict: **approve** — No material findings.
"headroom destroy gated to static solid cookie bodies; +Y-down offsets match basher body/floor model;
new verify chain covers the material basher regressions." → clean to ship.
