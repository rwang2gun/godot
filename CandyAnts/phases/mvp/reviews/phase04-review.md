# Phase 04 Adversarial Review

- **실행 시각**: 2026-05-08 22:00
- **포커스**: Blocker skill + Stage 3 양방향 release + WorkerState 분기 + Spawner alternate
- **scope**: working-tree
- **base ref**: ec9d43ce8319710d64d24383af40e80bac86cbec

---

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan contains internally inconsistent blocker eligibility and a likely off-by-one spawn alternation that can invalidate Stage 3 behavior before implementation even starts.

Findings:
- [high] Blocker eligibility contradicts the stated deadlock guard for carrying ants (CandyAnts/phases/mvp/plans/phase04-plan.md:11-12)
  The plan first specifies `BlockerSkill.can_apply(ant)` should allow `WalkerState` or `CarryingState`, but later says carrying ants must be rejected with `not ant.has_candy` because turning a carrier into a permanent blocker can leave candy in transit forever and deadlock clear. This is not a harmless documentation mismatch: implementers following the earlier skill spec would ship the exact high-impact failure the decision section identifies.
  Recommendation: Make the skill contract unambiguous at the first definition: reject `ant.has_candy`, and preferably reject `has_been_carrying` too if that matters for score/state invariants. Add a focused automated test that applying blocker to a carrying ant returns false and does not consume inventory.
- [medium] Spawner alternation is specified with a known off-by-one hazard (CandyAnts/phases/mvp/plans/phase04-plan.md:55-63)
  The proposed `_spawn_one()` logic computes direction after `_spawned` has already been incremented, so with `spawn_direction_alternate=true` the first ant becomes `-spawn_direction` despite the option being described as even index uses `spawn_direction`, odd index uses `-spawn_direction`. The plan even calls out that the mapping needs verification. That uncertainty directly affects Stage 3 topology and the headless test driver that waits for the first `+1` ant near x >= 1750; a wrong first direction can change timing/order assumptions and mask or break the intended release pattern.
  Recommendation: Compute alternation from a stable zero-based spawn index before incrementing `_spawned`, e.g. `var spawn_index := _spawned`, then increment after deriving direction. Add a unit/headless assertion for the first several spawned directions, not just log inspection.

Next steps:
- Resolve the contradictory `BlockerSkill.can_apply` contract before implementation.
- Define and test zero-based spawner alternation semantics explicitly.
