# Plan-stage Adversarial Review — skill-tile-surface

## Round 1 (codex, 2026-06-01)

Target: working tree diff (untracked plan markdown only)
Verdict: **needs-attention**

No-ship: the phase plan puts digger-only behavior in a shared destruction primitive and underspecifies bridge visuals enough to risk breaking the thin-walkway read.

Findings:
- **[high]** Digger-only surface caps will also run for basher destroys (`phase03-digger-exposed-surface.md:23-27`)
  Phase 3 plans to add the below-cell overlay inside `Terrain.destroy_tile_at` after any successful earth destruction. That method is not digger-specific: `WorkerState._destroy_basher_cell` also calls `destroy_tile_at(target, ["earth"])`, while the task scope explicitly leaves basher exposed-cell surface out. Horizontal basher tunnels would start adding surface caps to cells below removed wall tiles, producing out-of-scope visuals and untested terrain states.
  Recommendation: Do not make this unconditional inside `destroy_tile_at`. Add an explicit option such as `apply_below_surface_cap := false` and set it only from `_destroy_digger_cell`, or move the overlay application into the digger path after a successful destroy.
- **[medium]** Bridge plan can erase the thin-walkway visual contract (`phase02-bridge-builder-surface.md:20-27`)
  Phase 2 says bridge tiles should use the Phase 1 surface-skin infra while preserving thin bridge gameplay, but Phase 1 defines that infra as equivalent to `_add_solid_visual`'s surface overlay (cell-sized sprite). The existing bridge visual is a thin sprite with special scale/offset. Unless the plan defines a clipped/offset bridge-specific surface cap, the cookie surface can visually read as a full solid tile even if collision is unchanged. The proposed verification only checks whether the surface is visible, not whether the thin walkway silhouette survives.
  Recommendation: Specify a bridge/builder surface style that preserves the existing thin sprite bounds and z-order, or keep the existing bridge sprite and add only a narrow top cap. Add a regression check that asserts the bridge visual dimensions/offset remain thin.

Next steps (codex):
- Gate Phase 3 overlay behavior to the digger path only.
- Define bridge-specific surface geometry and tests before implementing Phase 2.

### 처리
Plan-stage 정책(CLAUDE.md): CRITICAL/HIGH 1건 이상 → 즉시 중단, 사용자 결정 대기. 자동 재리뷰 없음.

**사용자 결정 (2026-06-01): "둘 다 plan 반영" — 재리뷰 없이 구현 진행.**

- **[HIGH] 반영**: `phase03`에 `destroy_tile_at(..., apply_below_surface_cap := false)` opt-in 파라미터
  추가 명시. `_destroy_digger_cell`만 true, basher/cutter 경로는 기본 false 유지. basher 비적용
  회귀 가드 테스트 추가. (기본 false → 기존 호출자 무영향, D8·atomic 불변.)
- **[MEDIUM] 반영**: `phase02`에 bridge/builder 전용 **narrow top 캡**(bounds·offset·z-order 보존,
  셀 전체 채우기 금지) 명시 + 얇은 실루엣 치수 회귀 assert 추가. `phase01` 헬퍼를 region/scale/offset
  geometry 인자로 일반화하여 셀 크기(digger)·narrow(bridge) 둘 다 지원하도록 의존 반영.
