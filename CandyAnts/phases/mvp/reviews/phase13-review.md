# Phase 13 Adversarial Review

- **실행 시각**: 2026-05-18 10:47
- **포커스**: phase 13 plan: title/menu/stage-select + SaveData autoload + SceneFlow screen state. Focus: SaveData autoload sibling order/EventBus contract, SceneFlow _swap_screen + boot_to_stage_id race, GameFlowTest 회귀 bypass, request_main_menu vs request_menu alias, Esc 라우팅(dialog-local vs InputRouter), menu_layout.tres + 4 SlotState 분리. plan file: phases/mvp/plans/phase13-plan.md
- **scope**: working-tree (plan v1만 변경, 구현 0)
- **base ref**: fd2d27545eda592feb0b728a38e0ee43e12abc54
- **command**: `/codex:adversarial-review --wait "phase 13 plan: ..."`

---

## Round 1

**Findings**

**HIGH** `_unload_current_screen()` only `queue_free()`s old children, while menu handlers call `_overlay.hide_overlay()` then `_unfreeze_current_stage()` before swapping. A frozen stage can be re-enabled for one frame while MainMenu/StageSelect is already being added. Current SceneFlow already uses delayed frees ([SceneFlow.gd](C:/Users/code1/Projects/godot/CandyAnts/.claude/worktrees/naughty-feistel-61e4e0/CandyAnts/scripts/core/SceneFlow.gd:88)), but phase 13 makes this worse because old gameplay and menu can coexist. Fix: remove children from `CurrentStageRoot` before `queue_free()`, or disable each old child before unfreezing root. Add a regression that menu transition cannot emit stale `stage_cleared/stage_failed`.

**HIGH** The plan says to set `boot_to_stage_id` from `GameFlowTest._ready` at line 70, then correctly contradicts itself at line 697. Remove the earlier instruction. For `GameFlowTest` and `StageDialogEscTest`, use one explicit path: wait for Title boot, call `load_stage(1)`, then wait two frames, matching existing load/reload expectations in [GameFlowTest.gd](C:/Users/code1/Projects/godot/CandyAnts/.claude/worktrees/naughty-feistel-61e4e0/CandyAnts/tests/GameFlowTest.gd:87). `SceneFlowBootBypassTest` must set `boot_to_stage_id` before `add_child(main)`, otherwise it tests the same race.

**MEDIUM** SaveData/EventBus contract is internally inconsistent. Line 60 says SaveData connects only `stage_cleared`; line 245 pseudocode connects both `stage_cleared` and `stage_failed`; line 99 describes a `stage_cleared` emit with `cleared=false` which violates [EventBus.gd](C:/Users/code1/Projects/godot/CandyAnts/.claude/worktrees/naughty-feistel-61e4e0/CandyAnts/scripts/core/EventBus.gd:8) signal meaning. Make the contract strict: `stage_cleared` always records clear; `stage_failed` records attempt only.

**MEDIUM** SaveData test isolation is risky. The plan mutates the autoload singleton's private `_save_path` at line 409, then uses EventBus emits. Unless every test restores `_save_path`, reloads production state, and avoids leaving the singleton connected to test data, later tests can write to the wrong save. Add explicit setup/teardown, or instantiate an un-autoloaded SaveData for pure method tests and reserve one integration test for EventBus wiring.

**MEDIUM** `request_menu` vs `request_main_menu` alias boundary is undefined. Current `request_menu` is StageDialog's contract ([EventBus.gd](C:/Users/code1/Projects/godot/CandyAnts/.claude/worktrees/naughty-feistel-61e4e0/CandyAnts/scripts/core/EventBus.gd:12)); phase 13 adds `request_main_menu`. Add comments/tests that Title/MainMenu/StageSelect never emit `request_menu`; only StageDialog may use the legacy alias.

**MEDIUM** Esc/back routing contradicts itself. Line 5 references "game state 분기와 함께 InputMap 도입" but line 766 says `InputRouter` remains unchanged and `back_menu` is a dead placeholder. Pick one. If dialog-local routing is the decision, remove "game state 분기" language and add tests proving Esc does not emit `action_triggered`. If `back_menu` is real, add `GameAction.BACK_MENU` and route through SceneFlow.

**LOW** `menu_layout.tres` + 4 `SlotState` derivation order needs one sharper guard in tests: include "stage1-3 cleared + stage4 unavailable" to prove `COMING_SOON` wins over progression unlock, otherwise stage4 can accidentally become `PLAYABLE` as soon as stage3 is cleared.
