# Phase 8 Plan Review — Codex Adversarial (Round 1)

**Verdict**: needs-attention
**Source**: codex:rescue adversarial-review (plan stage)
**Plan**: `phases/mvp/plans/phase08-plan.md`

## HIGH findings (2)

### H1. `process_frame x 2` is not a deterministic one-physics-frame step

- **Affected**: `phase08-plan.md` lines 51-68, 208-213; `docs/INPUT_PLAN.md` lines 613-623
- **Risk**: The plan uses two `SceneTree.process_frame` awaits as a proxy for one physics tick, but `process_frame` is an idle-frame signal. The actual physics step count observed can be 0, 1, or more. The test asserting exactly one `_physics_process` increment is not reliable.
- **Fix**: Gate step-frame on a true physics-tick primitive, not idle frames. If one simulation tick is required, use `await get_tree().physics_frame` or equivalent.

### H2. StepFrame allows action re-entry while its await chain is open

- **Affected**: `phase08-plan.md` lines 48-68, 172-179; `scripts/input/InputRouter.gd` lines 62-80; `scripts/core/SceneFlow.gd` lines 126-130
- **Risk**: `_stepping` only blocks repeated `STEP_FRAME`. During the await window, `InputRouter` can still emit `PAUSE_TOGGLE` or `RESTART_STAGE`. A pause toggle can be overwritten by the coroutine's final `tree.paused = true`; a restart can reload a stage before the coroutine resumes.
- **Fix**: Add a step state/token. Queue or ignore pause-affecting actions while stepping, and only re-pause if the token still owns the current scene state.

## MEDIUM findings (4)

1. **InputModeTracker ordering** — autoload callback order between siblings is not deterministic; remove the ordering claim.
2. **Plan contradicts INPUT_PLAN §7 on modified files** — `HUD.gd`, `SkillToolbar.gd`, `Ant.gd` are listed as modified in INPUT_PLAN §7 but the plan says they are unchanged. SoT conflict needs resolution.
3. **Paused GUI-button assignment test only checks EventBus signal path**, not the real paused Button/Control path via `PROCESS_MODE_ALWAYS`.
4. **InputHintLabel null guard underspecified** — `InputModeTracker.get_mode()` called directly is not safe in scenes where the autoload is absent; use `get_node_or_null("/root/InputModeTracker")` with fallback.

## LOW findings (1)

1. `_input` / `_unhandled_input` wording blurs consumed vs unconsumed event paths — clarify in the plan.

## Next step

CLAUDE.md plan-stage policy (2026-05-09): **CRITICAL/HIGH 발견 시 즉시 중단 + 사용자 결정**. 자동 재리뷰 없음.
