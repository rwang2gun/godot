# Phase 02 Cumulative Adversarial Review (post-commit)

- **실행 시각**: 2026-05-08 12:05
- **포커스**: phase 1+2 누적: project bootstrap + Stage 1 vertical slice (Ant 6-state, Candy/Home/ScoreSystem 4-counter, HUD, Stage01)
- **scope**: branch
- **base ref**: ceef694 (phase 시작 직전)
- **HEAD**: 7bdfe7f (phase 2: stage1-core)

---

# Codex Adversarial Review

Target: branch diff against ceef694
Verdict: needs-attention

No-ship: Stage01 can fail at startup, and the candy/score invariant is fragile enough to deadlock level completion once a carrying ant leaves CarryingState.

Findings:
- [critical] Stage runner can start the spawner before its timer exists (CandyAnts/scripts/core/AntSpawner.gd:21-27)
  Stage01 declares `StageRunner` before `Spawner`, and `StageRunner._ready()` immediately calls `_spawner.start(_spawn_parent)`. `AntSpawner.start()` then calls `_timer.start()`, but `_timer` is only created in `AntSpawner._ready()`. In Godot ready ordering, sibling `_ready()` execution follows scene-tree order, so this ordering can dereference a null timer and prevent the vertical slice from spawning ants at all.
  Recommendation: Make `AntSpawner.start()` safe before `_ready()` by creating the timer in `_enter_tree()` or a private `_ensure_timer()` called from both `_ready()` and `start()`, or defer the StageRunner start until all sibling nodes are ready.
- [high] Candy in transit can be orphaned when a carrying ant enters FallerState (CandyAnts/scripts/world/Home.gd:19-24)
  Candy ownership is inferred from `current_state is CarryingState`. `CarryingState` switches to `FallerState` when the ant is off-floor, and `FallerState` later returns to `WalkerState`, losing the carrying state. Home then emits `ant_saved` with `with_candy=false`, so `ScoreSystem` never decrements `in_transit_pieces`; after candy HP reaches 0, `is_cleared()` can remain false until timeout even though the ant reached home. This is an inferred failure path from the state transitions, but it follows directly from the current state checks.
  Recommendation: Track candy possession as explicit ant data, e.g. `has_candy`, independent of movement state; preserve it through falling/walking transitions and emit saved/lost based on that flag, clearing it exactly once.

Next steps:
- Fix spawner lifecycle so Stage01 starts deterministically.
- Add a focused runtime/test scenario for a carrying ant entering FallerState and then reaching Home, asserting `in_transit_pieces` reaches 0 and the stage can clear.

---

## 처리 결정

| Severity | 이슈 | 결정 |
|----------|------|------|
| CRITICAL | AntSpawner timer race | 수정 — `_ensure_timer()` 헬퍼 + `_ready()`/`start()` 양쪽에서 호출 |
| HIGH     | Carrying→Faller 시 candy 분실 | 수정 — `Ant.has_candy: bool` 도입, state와 무관하게 운반 추적 |

CRITICAL/HIGH는 deferred 금지. 즉시 fix-up 커밋.
