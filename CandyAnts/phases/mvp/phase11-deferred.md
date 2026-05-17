# Phase 11 — Deferred Items

Generated 2026-05-17 during phase 11 impl-stage. Per CLAUDE.md: MEDIUM/LOW codex findings can be deferred with rationale.

## DEFER-1 (MED) — HudPauseFreezeTest (counter caPop pause freeze regression)

**Source**: codex plan-review v1 MED-1 + impl-review R1 #2 (planned test file missing).

**What was planned**: `tests/HudPauseFreezeTest.{tscn,gd}` to lock the invariant "Counter atom caPop tween must freeze when tree is paused (HUD root = INHERIT)".

**What was attempted**: Wrote and ran the test. In Godot 4.6 headless, `tree.paused = true` + `counter.set_value(5)` produced scale=1.0 (tween completed) after 10 paused frames, indicating the tween did NOT freeze as plan v2 §3 claimed. Investigation determined this is likely a Godot 4.6 Tween default behavior question (TWEEN_PAUSE_BOUND vs TWEEN_PAUSE_PROCESS) that interacts subtly with headless tree behavior and node process_mode propagation through CanvasLayer → Control → HBoxContainer → Counter → MainPanel → VBox → BigNumber chains.

**Why deferred**:
- Codex MED-1 was tagged `RISK-LOW` (FP-3 in plan-review v2).
- The real-world impact is a minor visual polish issue (counter motion continuing for ~220ms after pause press), not a functional bug. Game state itself is correctly paused (StepFrame.gd unchanged, ant physics frozen, score system stable).
- Production verification via plan §7.3 step 4 manual check covers the visual.
- Spending more time pinning down Godot 4.6 Tween pause semantics is yak-shaving relative to MVP scope.

**Resolution plan** (post-MVP polish phase 20 or sweep):
1. Verify production behavior on real desktop run — does counter actually animate during pause?
2. If yes, either:
   a. Extend Motion.gd freeze with explicit `t.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)` in caPop (Motion sig sweep).
   b. Set Counter atom node `process_mode = PROCESS_MODE_PAUSABLE` explicitly.
3. Re-attempt HudPauseFreezeTest with whichever fix.

**Affected files** (none — test was removed, not added):
- `tests/HudPauseFreezeTest.{tscn,gd}` — removed before commit.

## Acceptance

Phase 11 commits without HudPauseFreezeTest. Manual pause-during-counter-pop verification is the SoT for this invariant until post-MVP polish.
