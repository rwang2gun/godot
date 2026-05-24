## Round 1

**1. D8 First-Place Wins**

- Severity: LOW
  File + line or function: `tests/SandBridgeOverlapTest.gd:70`
  Description: The dynamic-vs-dynamic test confirms no permanent WorkerState stuck and at least one tile, but does not assert that exactly one worker lost the same-cell race.
  Fix or mitigation: Capture the first target cell and assert one successful placement plus one abort, or add a focused `Terrain.add_tile` same-cell test.

No confirmed implementation defect found. `Terrain.add_tile()` rejects dynamic and static occupancy before body creation at `scripts/world/Terrain.gd:19-22`, and all placement paths route through it.

**2. v7 Bridge Floor-Contact Guard**

No confirmed defect found. `WorkerState.gd:148-156` skips placement on first pre-tile off-floor frame, aborts on repeated/off-after-placement frames, and recharges grace only after confirmed floor contact.

**3. cell_size Unification**

No confirmed defect found. Worker placement reads `terrain.cell_size` dynamically at `WorkerState.gd:180`, `199`, `220`, and `242`; `Terrain.gd:28` and `36-42` use the same value for collision, position, and sprite scale.

**4. StageLayoutBuilder Static Occupancy**

- Severity: MEDIUM
  File + line or function: `scripts/world/StageLayoutBuilder.gd:26`, `scripts/world/Terrain.gd:15`
  Description: Hypothetical runtime rebuild risk: `build()` clears/regenerates children, but `Terrain` has no API to clear stale `_static_occupancy` if the layout changes.
  Fix or mitigation: Add a replace-static-cells API or document/guard `build()` as ready-time only.

No confirmed dev-scene lifecycle defect found; runtime registration happens at `StageLayoutBuilder.gd:39-43`, and the editor guard at `37-38` only skips preview registration.

**5. Overall Regression Risk**

No confirmed defect found. Existing public signatures are preserved, `SkillRegistry.gd:9-10` only adds new skills, and `Ant.gd:112-117` maps the new worker types to the existing build animation.

**6. Test Coverage Gaps**

- Severity: LOW
  File + line or function: `tests/BridgeRejectStageCellTest.gd:61`
  Description: `BridgeRejectStageCellTest` likely does not exercise `add_tile` rejection because the all-solid layout lets `_far_side_floor_reached` end bridge work before placement.
  Fix or mitigation: Change the fixture so the far-side ray misses while the target placement cell is static, or rename the test and rely on the direct static rejection test.

- Severity: LOW
  File + line or function: `tests/DynamicTileCellSizeAlignmentTest.gd:65`
  Description: Direct static-cell `add_tile` rejection is covered, but sand-mound static-cell rejection and out-of-bounds behavior remain untested.
  Fix or mitigation: Add a focused sand-mound-on-static-cell abort test; define bounds semantics before testing out-of-bounds placement.

Coverage notes: Codex read the relevant implementation files, new skill files, phase plan, dev layouts, and phase 16 bridge/sand/cell-size tests. Godot tests were not run because command discovery/execution was blocked by tool policy in this read-only session.

VERDICT: clean
