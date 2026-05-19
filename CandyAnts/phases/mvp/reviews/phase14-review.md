# Phase 14 Adversarial Review

- **실행 시각**: 2026-05-20 00:11
- **포커스**: phase 14 plan: traits dict + ClimberState (is_on_wall + test_move) + FallerState gravity scale 0.3 + trait badges + dev stage. plan file: phases/mvp/plans/phase14-plan.md
- **scope**: working-tree (plan v1만 변경, 구현 0)
- **base ref**: 3b48d50a46e59ea24a0e55693496cee32f01ffa7
- **command**: `node codex-companion.mjs adversarial-review --wait --scope working-tree "..."`

---

## Round 1

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan still specifies a climber top-out path it already proves is too small, and the dev-stage layout wiring is underspecified against the current runtime scene architecture.

Findings:
- [high] Climber top-out can immediately re-enter/fall because the planned push is only one frame of velocity (CandyAnts/phases/mvp/plans/phase14-plan.md:145-146)
  The ClimberState skeleton treats wall-end detection as complete after setting horizontal velocity for one `move_and_slide()` frame. The plan later calculates that this is about 1px at current speed while a cell is 16px, so the ant is unlikely to actually clear the corner. Likely impact is a core phase-14 mechanic that intermittently loops at ledges, falls after climbing, or fails only on specific wall/cell alignments. The risk is not speculative: the plan's own self-check identifies this exact insufficiency but leaves the incorrect skeleton as the implementation recipe.
  Recommendation: Change the ClimberState spec before implementation to use a deterministic top-out placement, e.g. validate clearance then translate by a bounded fraction/cell size or add a multi-frame top-out substate, and make the climber test assert final x/y placement plus stable Walker/Carrying state after several frames.
- [medium] Dev trait stage plan does not wire StageLayoutData into the runtime scene path (CandyAnts/phases/mvp/plans/phase14-plan.md:55-57)
  The plan creates `dev_trait_test_layout.tres` and `trait_test.tres`, then describes `TraitTest.tscn` as a Stage03 copy with `StageRunner.stage_data` set. In the current code, `StageRunner` does not consume `stage_data.layout`; layouts are materialized by scene-side `StageLayoutBuilder`. Inference: unless the implementation adds and configures that builder explicitly, the dev stage will run with the copied Stage03 geometry or no intended cliffs/gaps, so the climber/floater manual verification can pass or fail against the wrong level shape.
  Recommendation: Update the plan to explicitly add `StageLayoutBuilder` to `TraitTest.tscn`, assign `layout = dev_trait_test_layout.tres`, and verify Home/Candy/Spawner positions come from that layout rather than assuming `StageRunner.stage_data.layout` is applied at runtime.

Next steps:
- Fix the plan before starting implementation.
- After implementation, run the new climber/floater tests plus Stage02/Stage03 regression tests.
