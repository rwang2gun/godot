# Phase 2 (digger-exposed-surface) — Impl-stage Adversarial Review

## Round 1 (codex, 2026-06-01)

Target: working tree diff
Verdict: **needs-attention**

No-ship: the opt-in path is isolated to digger, but the cap target is broader than "newly exposed solid tile" and can corrupt existing or non-solid visuals.

Findings:
- **[medium]** Digger can double-cap cells that already have a build-time surface overlay (`Terrain.gd` `_cap_exposed_below`)
  `_cap_exposed_below()` only checks `get_cell_kind(below) == "earth"`, then calls `apply_cookie_surface_overlay()`.
  That helper is idempotent only for `CookieSurfaceCap`, but StageLayoutBuilder's build-time exposed-solid overlay
  is named `SurfaceSprite`. Destroying a dynamic earth tile (bridge) above an already-exposed static solid would add
  a 2nd surface sprite → duplicate/overdraw. New idempotency test misses it (only repeats the helper-created cap).
  Rec: skip bodies that already have the builder surface overlay, or share state/name between build-time and runtime overlays.
- **[medium]** Below-cell filter treats slopes as cap-eligible earth (`Terrain.gd` `_cap_exposed_below`)
  StageLayoutBuilder registers `solid` and `slope_*` as kind `earth`. No shape guard → digger removing a cell above a
  slope adds a full square cap to a slope body, violating the documented scope excluding slopes + overwriting slope rendering.
  Rec: distinguish rectangular solid earth from slopes; only cap true solid cookie terrain. Add slope-below regression test.

Next steps (codex):
- Tighten `_cap_exposed_below()` eligibility beyond `kind == "earth"`.
- Extend test to cover pre-existing surface overlays and slope-adjacent digger destruction.

### 처리 (2026-06-01)
두 MEDIUM 모두 in-scope 실제 버그 → defer 없이 수정. CLAUDE.md impl-stage 자체리뷰 사이클 적용
(수정 → 자체 적대적 리뷰 clean까지 → codex 재리뷰).

수정 내용 (`Terrain._cap_exposed_below` + 신규 `_is_solid_cookie_body`):
- 대상을 `_static_bodies`(정적 셀)로 한정 → 동적 bridge·sand 자동 제외 (sand 자체 reskin SoT 보존).
- `_is_solid_cookie_body`로 slope(CollisionPolygon2D/SlopeVisual)·plant(PlantVisual) 배제, BaseSprite 필수.
- 캡 전 `has_node("SurfaceSprite")`(빌드타임) + `has_node(COOKIE_SURFACE_CAP_NAME)`(런타임) 중복 가드.
- 테스트 2종 추가: 노출 솔리드 위 동적타일 파괴 시 중복캡 0 / slope-below 캡 0.

## Self-Review Round 1 (2026-06-01)
HIGH 0건:
- eligibility를 좁히기만(strictly fewer caps) → 기존 basher/digger/stage 흐름 무영향. 회귀 테스트로 확인.
- 모든 solid는 `_add_solid_visual`이 BaseSprite를 항상 부여 → `_is_solid_cookie_body` false-negative 없음.
- 빌더 오버레이 이름은 항상 "SurfaceSprite" 고정 → 중복 가드 누락 없음.
- plant는 kind="plant"라 earth 게이트에서 1차 배제 + PlantVisual로 2차 배제.
- atomic invariant 보존: 캡은 erase 완료·파괴 성공 후에만, opt-in false면 무변경.
- cross-doc: TERRAIN_TILE_RULES §0(slope 범위 밖) 준수.
검증: DiggerExposedSurfaceTest 6케이스 PASS + Stage03/basher/digger 회귀 PASS. → 자체 clean, codex 재리뷰 진행.

## Round 2 (codex re-review, 2026-06-01)

Target: working tree diff
Verdict: needs-attention (MEDIUM 1)

- **[medium]** Regression tests for the fixed cap bugs are not tracked
  `git status --short` shows DiggerExposedSurfaceTest.gd/.tscn/.gd.uid as untracked → could be omitted from commit/CI.
  Rec: track the test files; ensure the new test is in the verification command.

codex가 확인: "the code fix addresses the two prior MEDIUMs" — **코드 결함 0**. 남은 지적은 packaging(테스트 tracking + verify 경로).

### 처리 — Round 3 codex 미실행 근거 (의도적 판단)
이 MEDIUM은 **working-tree 리뷰의 구조적 artifact**다:
1. harness `execute.py complete`가 `tests/**` whitelist로 새 테스트(.gd/.tscn/.gd.uid)를 **자동 staging·커밋**한다
   (Phase 1에서 동일하게 tests/CookieSurfaceOverlayTest.* 자동 추적 확인). → "untracked라 빠질 수 있다"는 commit 시점에 해소.
2. substantive 부분(새 테스트가 verify 게이트에 없음)은 phase02 `verify`를
   `DiggerExposedSurfaceTest && Stage03HeadlessTest` 체인으로 갱신해 **complete 게이트에 포함**(이번 수정).
3. codex Round 3를 돌려도 tests는 commit 전까지 untracked로 남고(complete는 clean index 요구 → 사전 staging 불가),
   동일 지적이 무한 반복되는 catch-22다. CLAUDE.md의 round-explosion·usage 경고에 따라 코드결함 0 + 구조적 해소
   확인 후 complete 진행으로 종결. (defer 아님 — verify 게이트 편입으로 실질 해소.)

검증: DiggerExposedSurfaceTest 6케이스 PASS + Stage03/basher/digger 회귀 PASS. complete가 새 verify 체인 재실행.
