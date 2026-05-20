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

---

## Round 2

- **실행 시각**: 2026-05-20 (plan v2 codex 재리뷰)
- **포커스**: phase 14 plan v2 — mantle substate MANTLE_DISTANCE=36 + TraitTest.tscn StageLayoutBuilder direct wiring + cell_size=32 corrections
- **scope**: working-tree (plan v2 단독 변경, 구현 0)
- **command**: `node codex-companion.mjs adversarial-review --wait --scope working-tree "phase 14 plan v2: ClimberState mantle substate ..."`

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the v2 plan still leaves a real mantle deadlock path, hard-codes the cell-size fix it claims to generalize, and specifies a dev scene that cannot exercise trait skills through the existing toolbar flow.

Findings:
- [high] Mantle can deadlock when horizontal collision prevents dx accumulation (CandyAnts/phases/mvp/plans/phase14-plan.md:180-190)
  The required ClimberState skeleton only advances `_mantle_offset` by actual `global_position.x` delta and only exits when `_mantle_offset >= MANTLE_DISTANCE`. If the ant starts mantling while still blocked by the top cell/corner or by a thicker wall, `move_and_slide()` can produce `dx == 0`, leaving velocity.y at 0 and never reaching the exit condition. The plan itself acknowledges this exact E12 failure later but makes the stall guard optional, so the implementation can ship with an infinite mantling state on a corner-clearance edge case.
  Recommendation: Make the stall guard mandatory in the §4.2 skeleton, reset it on movement, and add a headless case with blocked/thick-top geometry that proves ClimberState exits to FallerState or resumes climbing instead of hanging.
- [medium] MANTLE_DISTANCE is described as cell_size-derived but specified as a hard-coded 36px constant (CandyAnts/phases/mvp/plans/phase14-plan.md:54-98)
  D6 says the mantle distance is `layout.cell_size + 4`, but the concrete Ant.gd spec adds `const MANTLE_DISTANCE: float = 36.0`. That only works while every climbable layout uses 32px cells; `StageLayoutData.cell_size` is exported and therefore configurable. This preserves the cell-size mismatch risk under any non-32 dev/future layout: smaller cells over-push into the wrong tile, larger cells fail to clear the corner and can re-enter ClimberState or stall.
  Recommendation: Either derive mantle distance from the active StageLayoutData cell_size at runtime, or make 32px a documented/enforced global invariant with validation that rejects non-32 layouts before ClimberState can run.
- [medium] TraitTest scene spec omits SkillToolbar wiring, so the dev stage cannot manually apply climber/floater (CandyAnts/phases/mvp/plans/phase14-plan.md:396-417)
  The dev StageData defines `available_skills` and `skill_inventory`, and the manual verification expects SkillToolbar icons and inventory decrement, but the TraitTest.tscn node skeleton only includes StageRunner, World, StageBackground, Spawner, and HUD. Existing skill stages wire `toolbar_path = NodePath("SkillToolbar")` and include a `SkillToolbar` node; Stage01 has no toolbar, so copying it exactly is insufficient for a trait-validation stage. The result is a dev scene that may build terrain correctly but cannot exercise the user-facing trait assignment flow it is supposed to validate.
  Recommendation: Extend the TraitTest.tscn spec with the Stage02/Stage03 SkillToolbar pattern: add the SkillToolbar ext_resource, set `StageRunner.toolbar_path`, instantiate `[node "SkillToolbar"]`, and assign `stage_data = trait_test.tres`.

Next steps:
- Revise the plan before implementation: mandatory mantle stall handling, real cell_size linkage or invariant enforcement, and SkillToolbar wiring in TraitTest.tscn.

---

## Round 3

- **실행 시각**: 2026-05-20 (plan v3 codex 재리뷰)
- **포커스**: phase 14 plan v3 — mandatory stall guard + runtime mantle_distance via stage_layout_builder group + SkillToolbar wiring + ClimberStallTest
- **scope**: working-tree (plan v3 단독 변경)
- **command**: `node codex-companion.mjs adversarial-review --wait --scope working-tree "phase 14 plan v3: (1) mantle stall guard MANDATORY ... (2) mantle_distance runtime via group lookup ... (3) SkillToolbar wiring ... (4) ClimberStallTest"`

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the v3 fixes cover the happy-path single-builder stage, but the new runtime mantle distance channel is still structurally under-scoped and can silently use the wrong layout or fallback without tests catching it.

Findings:
- [medium] Global StageLayoutBuilder lookup can resolve the wrong layout or silently fall back (CandyAnts/phases/mvp/plans/phase14-plan.md:115-127)
  The plan resolves `ant.mantle_distance` with `get_first_node_in_group("stage_layout_builder")` and then accepts the first builder's `layout.cell_size`, otherwise keeping fallback `36.0`. This is vulnerable because Godot groups are global to the tree, not scoped to the ant's current stage/world. The repo already has a StageRunner comment noting global group contamination during stage overlap, so a transition, headless test with multiple scenes, or an earlier builder with null layout can make a newly spawned ant read another stage's cell size or retain 36.0. The likely impact is climbers undershooting/overshooting mantle on non-32 layouts, re-entering ClimberState, falling unexpectedly, or hiding the failure because current Stage01-03 all use cell_size=32 and fallback matches them.
  Recommendation: Do not use unscoped `get_first_node_in_group` as the source of truth. Resolve the builder within the ant's current stage subtree/ancestor chain, ignore builders with null layout, log or fail loudly when no scoped layout exists for a layout-backed stage, and add a headless test with multiple builders or a null first builder plus a non-32 cell_size layout.

Next steps:
- Revise §3.1/§3.4 to define scoped builder resolution and error behavior.
- Add a targeted runtime-resolution test that would fail with the current global first-node lookup.

Note: HIGH 0건. CLAUDE.md plan-stage policy로는 진행 가능하지만 fix가 작아 plan v4로 inline 수정 후 Round 4.

---

## Round 4

- **실행 시각**: 2026-05-20 (plan v4 codex 재리뷰)
- **포커스**: phase 14 plan v4 — ancestor-scoped builder resolution, StageLayoutBuilder.gd 무변경
- **scope**: branch diff vs 67b97c8 (working-tree scope는 624 untracked files / 3.5MB tools/로 codex 1MB input limit 초과)
- **command**: `node codex-companion.mjs adversarial-review --wait --scope branch --base 67b97c8 "..."`

# Codex Adversarial Review

Target: branch diff against 67b97c8
Verdict: approve

Ship gate passes for plan-stage review: the v4 ancestor-chain scan removes the global group contamination risk, and I cannot support a remaining HIGH finding from the provided diff/context.

No material findings.

Next steps:
- In implementation, add a targeted regression for scoped resolution with two stage subtrees and differing cell_size values so the old global lookup would fail.

---

## 종합 (Plan stage)

- Round 1 (v1): needs-attention — HIGH(top-out 1px) + MEDIUM(layout wiring) → v2 작성
- Round 2 (v2): needs-attention — HIGH(stall optional) + 2 MEDIUM(MANTLE_DISTANCE 하드코딩, SkillToolbar 누락) → v3 작성
- Round 3 (v3): needs-attention — MEDIUM(group scope) → v4 inline fix
- **Round 4 (v4): approve — plan v4 ready for impl**

impl-stage에서 (Round 4 권고대로) ancestor-scoped resolution을 검증할 헤드리스 테스트 추가는 ClimberStallTest 또는 별도 MantleDistanceScopeTest로 검토 — impl 단계에서 결정.
