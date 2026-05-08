# Phase 02 Adversarial Review

- **실행 시각**: 2026-05-08 11:25
- **포커스**: phase 2 plan: stage 1 vertical slice (Ant 6-state, Candy/Home, ScoreSystem 4-counter, HUD, Stage01)
- **scope**: working-tree
- **base ref**: 6e4eaf5252918cd19adfd3b055d544f5152ffc8a

---

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the Stage 1 plan leaves a deterministic core-loop failure where newly spawned ants can be saved empty after the grace window, preventing candy collection and making completion depend on scene geometry/timing luck.

Findings:
- [high] Home saves non-carrying ants after grace period, so ants can disappear before ever reaching Candy (CandyAnts/phases/mvp/plans/phase02-plan.md:47-54)
  The planned Home handler emits ant_saved and transitions to SavedState for any Ant once the 0.4s spawn grace expires; it does not require CarryingState before saving. Because Stage01 spawns ants at Home.position + (0,-32), inside or immediately adjacent to a 32x32 Home Area2D, an ant that remains overlapping Home or re-enters it after the grace window is treated as saved even with carrying=false. Inference from the provided geometry: Home at (200,880), spawn at (200,848), Home size 32x32, ant body 12x10, so the spawn point is on the Home area's top boundary if unoffset shapes are used. This can silently drain total ants without reducing Candy HP, leaving the stage unwinnable or producing misleading Saved/HUD counts.
  Recommendation: Change Home.gd to ignore non-carrying ants for Stage 1 completion, or spawn outside the Home trigger and add a one-way/return-side gate. Add a smoke test that verifies a spawned non-carrying ant is not saved before reaching Candy.

Next steps:
- Tighten the Home save condition and update the Stage01 spawn/Home geometry before implementing the vertical slice.
- Add the missing verification scenario for empty-ant Home overlap after the grace window.
