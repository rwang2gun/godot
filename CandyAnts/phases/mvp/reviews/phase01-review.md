# Phase 01 Adversarial Review

- **실행 시각**: 2026-05-08 11:05
- **포커스**: phase 1 plan: project bootstrap + autoload skeleton (Godot 4.6, 2D)
- **scope**: working-tree
- **base ref**: ceef6942e83163ab2781be33e1773b17c583560e

---

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the phase plan explicitly introduces a persistent TDD bypass as part of bootstrap, leaving the repository able to accept new GDScript without tests beyond this phase.

Findings:
- [medium] Planned TDD bypass can persist past Phase 1 and silently disable test enforcement (CandyAnts/phases/mvp/plans/phase01-plan.md:28)
  The plan adds `scripts/hooks/.tdd_bypass` as a Phase 1 artifact and only says it will be removed at final verification or before Phase 2. That removal is deferred rather than made an exit criterion of this change, so a partial completion, handoff, or status-only update can leave the bypass committed or present in the working tree. The likely impact is that subsequent `scripts/core/*.gd` additions can skip the TDD guard without an obvious failure signal, exactly when the bootstrap starts adding autoload code that later phases depend on.
  Recommendation: Do not add a persistent bypass file as part of the bootstrap plan. If a bypass is unavoidable, require Phase 1 completion to remove it in the same change and add an explicit verification step that fails if `scripts/hooks/.tdd_bypass` still exists.

Next steps:
- Update the plan so `.tdd_bypass` is temporary within Phase 1 and cannot remain after verification.
- Add a completion check in `status.json` or the phase checklist that blocks marking bootstrap complete while the bypass file exists.
