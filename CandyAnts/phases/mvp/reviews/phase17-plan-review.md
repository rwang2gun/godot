# Phase 17 Plan Review — codex adversarial-review

**Plan target**: [phases/mvp/plans/phase17-plan.md](../plans/phase17-plan.md) (v2)
**Policy**: CLAUDE.md plan-stage — CRITICAL/HIGH 1건 발견 시 즉시 중단 + 사용자 결정. 자동 재리뷰 금지.

---

## Round 1 (2026-05-24)

**Verdict**: needs-attention
**Summary**: No-ship: the plan still leaves multi-hazard ordering and deactivation semantics underspecified in ways that can invalidate D8 and make overlap acceptance nondeterministic.

### Findings

#### [HIGH] H1 — Single-hazard cell registry can leave Water active under placed bridge
**Location**: phase17-plan.md:387-406 (Terrain `_hazards_by_cell` + `register_hazard_at_cell` + `deactivate_hazards_for_placement`)

The plan allows Water+Sticky in the same cell, but `register_hazard_at_cell` keeps only the first hazard and skips duplicates; `deactivate_hazards_for_placement()` then deactivates only that registered node. If Sticky registers before Water in a bridge-over-water/overlap layout, the helper can disable Sticky while Water remains monitoring, so an ant crossing the newly placed bridge can still enter Water and be lost. This breaks the D8 policy under a layout the plan explicitly permits for tests and does not make registration order a hard invariant.

**Recommendation**: Change `_hazards_by_cell` to store all hazards per cell (Array[HazardBase]) and deactivate every hazard in the target/body-row cells. Add a bridge-over-water-with-overlap test that proves Water cannot remain active due to registration order. — **OR** — make same-cell multi-hazard invalid everywhere before accepting D8.

#### [HIGH] H2 — WaterStickyOverlapTest asserts Water-first side effect that Godot signal order does not guarantee
**Location**: phase17-plan.md:125 (WaterStickyOverlapWaterWinsTest invariant)

The test contract says Sticky timer must not be set, but the later design text (§6.4) admits either Water or Sticky may receive `body_entered` first. If Sticky fires first, `ant.apply_sticky(duration)` runs before Water transitions to `LostState`, so `_sticky_remaining` can be positive even though the final terminal outcome is Lost. That makes the acceptance invariant order-dependent and flaky; it also contradicts D3's stated 'Water priority' behavior unless priority is implemented centrally rather than inferred from Area2D signal ordering.

**Recommendation**: Either implement deterministic priority dispatch for hazards in the same cell so Water is always handled before Sticky, **OR** relax the overlap test to assert only the terminal Lost outcome and score invariant, not that Sticky never applied.

### Next steps (codex)

Block Phase 17 implementation until the plan defines deterministic multi-hazard storage, deactivation, and overlap priority semantics.

---

**Status (Round 1 종료)**: H1/H2 모두 사용자 결정으로 inline fix 적용 — v3에서 Multi-hazard storage Array + WaterStickyOverlapTest invariant 완화. BridgeOverWaterStickyOverlapTest 신규 회귀 가드 추가.

---

## Round 2 (2026-05-24)

**Verdict**: needs-attention
**Summary**: No-ship: v3 fixes the registry/test mechanics, but the plan still preserves the old Water-first contract in the D3 decision table, directly contradicting the relaxed overlap invariant that was supposed to resolve R1-H2.

### Findings

#### [HIGH] R2-H1 — D3 still specifies the rejected Water-first invariant
**Location**: phase17-plan.md:49 (§1.1 D3 decision row)

The v3 overlap section (§6.4 + §0 한 줄 요약) says Godot may deliver Sticky before Water and explicitly allows a transient `_sticky_remaining > 0`, but the canonical D3 decision row still says Water has priority and that Sticky is ignored in the same frame, leaving `sticky timer` unset. That is the exact order-dependent behavioral contract R1-H2 was meant to remove. The implementation snippets support the v3 relaxed behavior: HazardBase only checks `not ant.is_alive()` before dispatch, so if Sticky's signal runs first the ant is alive and Sticky will apply. Keeping the stale D3 row makes the plan internally inconsistent and can send implementers or tests back toward the old flaky Water-first assertion.

**Recommendation**: Rewrite D3 to match §6.4: same-cell Water+Sticky signal order is unspecified; Water-first leaves sticky unset, Sticky-first may set `_sticky_remaining` transiently; the only required deterministic outcome is terminal Lost plus the ScoreSystem lost/in_transit invariant.

### Next steps (codex)

Update the D3 decision row, then re-review for remaining contradictions against §6.4 and the test table.

---

**Status (Round 2 종료)**: 사용자 요청으로 inline fix 적용 — plan v4에서 §1.1 D3 row를 §6.4와 동일한 relaxed invariant로 재작성. dev layout/strict acceptance의 stale "Water 우선" 표현도 제거. Round 3 adversarial-review 전 상태.

---

## Round 3 (2026-05-24)

**Verdict**: approve
**Summary**: Ship for plan-stage: v4 resolves R2-H1. The live D3, §0 summary, §6.4, strict acceptance, and WaterStickyOverlapLostTerminalTest contract now agree on terminal Lost as deterministic and _sticky_remaining as non-deterministic transient state. I found no CRITICAL/HIGH contradiction introduced by the inline edit.

### Findings

No material findings.

---

**Status (Round 3 종료, plan-stage clean)**: codex verdict=approve. plan v4 동결, impl-stage 진입.

