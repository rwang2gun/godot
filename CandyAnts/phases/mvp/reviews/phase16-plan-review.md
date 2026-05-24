# Phase 16 Adversarial Review (Plan Stage)

- **실행 시각**: 2026-05-23
- **포커스**: phase 16 plan: Sand-mound + Bridge creation skills, first-place D8 overlap policy, Bridge gap auto-detect, 10 open decisions resolved, Builder stays untouched
- **scope**: working-tree
- **base ref**: c082dc5569252cc8c3e22ea1e5aa67ed080d52bb (phase 15 ship commit)
- **plan stage 정책**: CLAUDE.md `Plan stage` 정책 — CRITICAL/HIGH 1건이라도 발견 시 즉시 작업 중단 + 사용자 보고. 자동 재리뷰 사이클 없음.

---

## Round 1

Target: working tree diff
Verdict: needs-attention

No-ship: the plan’s core overlap and gap/climb assumptions conflict with existing terrain ownership and cell sizing, so implementing it as written can produce false-positive tests and user-visible broken mechanics.

Findings:
- [high] D8 first-place policy excludes stage terrain, so overlap protection is not real (CandyAnts/phases/mvp/plans/phase16-plan.md:401-402)
  The plan claims first-place wins via `Terrain.add_tile()`, but then explicitly states StageLayoutBuilder cells are not registered in `Terrain._placed` and `add_tile` will return true on top of stage floor. Existing `Terrain.add_tile()` only checks its private `_placed` dictionary, while StageLayoutBuilder creates separate StaticBody2D cells. Impact: sand-mound/bridge can create duplicate dynamic tiles inside authored floor cells, while tests only cover dynamic-vs-dynamic overlap. This breaks the stated D8 invariant and can hide bad placement, bad tile counts, and future destruction/rollback bugs.
  Recommendation: Do not rely on `Terrain._placed` alone. Add a stage-occupancy query or register StageLayoutBuilder cells into the same terrain occupancy map, then make `add_tile()` reject both static and dynamic occupied cells. Add a test for dynamic placement attempted on an authored stage floor cell.
- [high] Phase layouts use 32px cells but the proposed mechanic uses existing 16px dynamic terrain cells (CandyAnts/phases/mvp/plans/phase16-plan.md:64-67)
  The plan defines the new dev layouts as `cell_size=32`, but the existing dynamic build path uses `WorkerState.CELL_SIZE = 16` and `Terrain.CELL_SIZE = 16`. Because the plan says Builder/Terrain stay untouched and the new branches copy the builder-style CELL_SIZE placement, the bridge/sand-mound lengths will be measured in 16px increments while the gaps/platforms are authored in 32px layout cells. Impact: an 8-cell bridge only spans 128px against a planned 256px budget, sand-mound height/positioning can land between authored cells, and the proposed headless pass conditions can fail or be tuned around the wrong unit system.
  Recommendation: Before implementation, choose one coordinate unit. Either make `Terrain`/`WorkerState` derive dynamic tile size from the active `StageLayoutData.cell_size`, or author these phase-16 dev layouts and expected gap/height counts in the existing 16px dynamic grid. Add a regression asserting dynamic tile world positions align with StageLayoutBuilder cells.

Next steps:
- Resolve stage terrain occupancy before accepting D8 as closed.
- Resolve the 16px vs 32px cell-size mismatch before writing the phase-16 tests.

---

## Round 2

- **실행 시각**: 2026-05-24
- **포커스**: phase 16 plan v5 — Sand-mound + Bridge: v4 self-review fix pass for H1 (sand_mound 4→5 cells docs unify), M1 (§7.3 ray-cast 1-cell gap analysis), M2 (§11 Stage 01 risk wording), M3 (§2.2 Terrain rect.size + sprite scale 비례)
- **scope**: working-tree
- **plan stage 정책**: CRITICAL/HIGH 1건이라도 발견 시 즉시 중단 + 사용자 결정. 자동 재리뷰 사이클 없음.

Target: working tree diff
Verdict: needs-attention

No-ship: the v5 plan still contains contradictory implementation guidance that can produce wrong bridge behavior and reintroduces the sand-mound 4-vs-5-cell ambiguity it claims to close.

Findings:
- [high] Bridge fall handling is specified inconsistently, leaving the implementation path without the required guard (CandyAnts/phases/mvp/plans/phase16-plan.md:323-342)
  The bridge update snippet continues after gravity/move_and_slide with only an is_on_wall abort before placing tiles. Later, §7.5 says _update_bridge must add an is_on_floor abort, while §11 says the guard is not introduced. If an ant falls during bridge work, the snippet can keep placing bridge cells from a falling global_position until MAX_LENGTH, creating airborne or misaligned permanent terrain. This is user-visible and hard to recover because D7 keeps partial bridge cells permanently. This conclusion is based on the plan's own acknowledged fall scenario and contradictory guidance.
  Recommendation: Make the plan single-source: add the is_on_floor guard to the §4.2 bridge implementation snippet, update §11 to say the guard is included, and add/extend a headless test that forces bridge work to lose floor contact and asserts no further tiles are placed after abort.
- [medium] Sand-mound 4-cell wording remains in the risk table after the claimed 5-cell unification (CandyAnts/phases/mvp/plans/phase16-plan.md:778)
  The H1 fix says sand_mound docs are unified from 4 to 5 cells, and §5.1 states the gap is exactly 5 cells. §11 still describes the risk as MAX_HEIGHT=5 against a 'stage layout 4-cell gap'. That leaves two conflicting target layouts in the plan. An implementer can tune the dev layout or pass conditions against the stale 4-cell statement, making SandMoundClimbTest pass for the wrong geometry or forcing another plan revision after implementation.
  Recommendation: Change the §11 risk row to 5-cell gap wording and make the mitigation match §5.1/D2 exactly; if 4-cell remains intentionally relevant, add a separate explicit regression case rather than mixing it into the main dev_sand_mound_layout risk.

Next steps:
- Resolve the bridge guard contradiction before implementation.
- Remove the remaining 4-cell sand-mound reference or split it into an explicit separate test case.

---

## Round 3

- **실행 시각**: 2026-05-24
- **포커스**: phase 16 plan v6 — codex Round 2 R2-H1 (bridge is_on_floor guard) + R2-M1 (§11 sand_mound 4→5 cell wording) fix pass. v6 inline cleanup only — v4/v5 본체 무변경.
- **scope**: working-tree
- **plan stage 정책**: CRITICAL/HIGH 1건이라도 발견 시 즉시 중단 + 사용자 결정.

Target: working tree diff
Verdict: needs-attention

No-ship: the v6 bridge guard still permits tile placement while the ant is already off-floor on the first bridge update, leaving the R2-H1 permanent-airborne-tile failure only partially fixed.

Findings:
- [high] Bridge fall guard skips the first update but still allows placement in that same off-floor frame (CandyAnts/phases/mvp/plans/phase16-plan.md:350-359)
  The new guard only aborts when `_remaining < BRIDGE_MAX_LENGTH`, so the first bridge update is exempt. If floor contact is lost immediately after skill application or before the first `_update_bridge` tick, the code runs gravity/move, observes no floor, skips the guard because `_remaining` is still at max, then enters the placement loop and can add a permanent bridge tile from a falling/off-floor position. The proposed `BridgeFallAbortTest` also waits until `terrain.tile_count() >= 1` before forcing lift, so it cannot catch this first-tick hole. Impact is the same class R2-H1 was meant to block: D7-preserved misaligned/airborne terrain that can survive after abort.
  Recommendation: Do not let the first off-floor frame place tiles. Replace the first-tick exemption with a no-placement grace path, e.g. if `not a.is_on_floor()` and no bridge tile has been placed yet, return without decrementing/placing; if any tile has been placed, abort. Add a headless case that removes/lifts floor contact before the first bridge tile and asserts `tile_count()` remains unchanged.

Next steps:
- Tighten the bridge fall guard semantics before implementation.
- Extend `BridgeFallAbortTest` or add a separate first-tick off-floor regression case.

---

## Round 4

- **실행 시각**: 2026-05-24
- **포커스**: phase 16 plan v7 — codex Round 3 R3-H1 fix (bridge floor-contact guard with `_bridge_floor_grace_used` flag, `placed_count == 0` grace skip / `placed_count > 0` immediate abort) + N1/N3 cleanup (progress.md v7 갱신 + grace 재충전 정책 명시 in §4.2 snippet 주석/§7.5/§0.2 strict acceptance). 신규 헤드리스 `BridgeFirstTickOffFloorAbortTest` + 기존 `BridgeFallAbortTest` mid-work 범위 축소.
- **scope**: working-tree
- **plan stage 정책**: HIGH/CRITICAL 1건이라도 발견 시 즉시 중단. MED는 사용자 결정.

Target: working tree diff
Verdict: needs-attention

No-ship: the new first-tick bridge regression test can be implemented as a false positive, leaving the exact R3-H1 hole insufficiently guarded.

Findings:
- [medium] Bridge first-tick test fixture can bypass the skill path and pass without exercising the guard (CandyAnts/phases/mvp/plans/phase16-plan.md:157)
  The test spec allows a fixture that does not create floor under the bridge start cell, but BridgeSkill.can_apply requires is_on_floor before real skill application. If the test uses the normal skill path, bridge never enters WorkerState; the listed PASS checks can still satisfy tile_count == 0 and 'current_state is not WorkerState' without ever running _update_bridge. That makes the new regression guard hollow for the first-tick off-floor bug this change is supposed to close.
  Recommendation: Remove the no-start-floor fixture option. Require the test to start with valid floor contact, assert BridgeSkill.can_apply succeeds and the ant enters WorkerState, then lift/remove contact before the first placement tick and verify the grace frame plus abort behavior.

Next steps:
- Tighten BridgeFirstTickOffFloorAbortTest acceptance so it proves WorkerState was entered before floor contact is removed.
