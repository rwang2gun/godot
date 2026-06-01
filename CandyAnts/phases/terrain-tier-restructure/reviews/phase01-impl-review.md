# Phase 1 Impl Review — revert-excavation-surface-caps

## Verify (Claude, 2026-06-01)
`python scripts/run_test.py` 회귀 5종 전부 PASS:
- `BasherTunnelThroughWallTest` PASS (saved=1) — basher 1칸 터널로 벽 관통 정상
- `BasherEdgeStopTest` PASS — 절벽 끝 정지
- `DiggerVerticalTunnelTest` PASS (saved=1) — 수직 굴착
- `TerrainDestroyTileApiTest` PASS (sub 1~5: static/dynamic/unregistered/kind-mismatch/stale-body atomic) — 2-arg 시그니처 + atomic 불변 유지
- `Stage03HeadlessTest` PASS (clear score=1.0) — Stage 3 basher 회귀 0건

grep: `apply_below_surface_cap` / `destroy_static_cookie_cell` / `apply_under_surface_at` /
`apply_cookie_surface_overlay` / `register_cookie_tier_textures` / `_cap_exposed_below` /
`_is_solid_cookie_body` / `get_cookie_*` / `_configure_cookie_region` / `COOKIE_SURFACE_CAP` /
`_cookie_*_tex` 잔존 참조 **0건**(소스 + 테스트).

## Round 1 (codex adversarial-review, 2026-06-01)

Target: working tree diff
Verdict: **approve**

No defensible no-ship finding in the code/test diff. The removed cookie-cap APIs have no surviving
source/test callers, `destroy_tile_at` is back to the 2-arg call shape at all visible call sites, atomic
erase behavior is unchanged, and deleted test/dev scene names are not referenced by remaining tracked
scene/data/test files. (Codex could not execute the Godot regression tests in its read-only session — those
were run separately by Claude, all PASS, see Verify above.)

No material findings.

Next steps (codex):
- Run the declared Phase 1 verification chain outside the read-only review sandbox. → 완료(위 Verify, 전부 PASS).

### 처리
Impl-stage 정책(CLAUDE.md): codex verdict=approve, CRITICAL/HIGH 0건 → 수정 불요, 자체 적대적 리뷰 사이클
트리거 조건(codex finding 발생) 미충족 → impl-stage 루프 clean 종결. Phase 1 complete 진행.
