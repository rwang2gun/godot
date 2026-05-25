# Phase 19 Plan Adversarial Review

본 파일은 `phases/mvp/plans/phase19-plan.md` 대상 codex adversarial-review의 라운드별 stdout 누적. Plan-stage 3-round cap 정책(2026-05-25 CLAUDE.md 갱신) 적용 — R1→fix→R2→fix→R3, R3 HIGH 시 STOP.

---

## Round 1 (2026-05-25, plan v1 대상)

**Target**: working tree diff (CLAUDE.md policy + phases/mvp/plans/phase19-plan.md v1 + phases/mvp/status.json)
**Verdict**: **needs-attention**

**Summary**: No-ship — the plan contains blocker-grade validation gaps around the mixed earth/plant dev stage and hazard overlap semantics, and its essential tests do not actually gate all strict acceptance invariants.

### Findings

#### [high] R1-H1: dev_earth_plant_separation is specified as an unwinnable 4-ant StageData while tests only check partial rejection cases
**Location**: `phases/mvp/plans/phase19-plan.md:305-309`

The plan creates a real StageData with `total_ants=4, candy_hp=4`, and only `{basher:2, cutter:2}`, then describes all 4 ants reaching candy. That cannot work as written: ants 1-2 consume the two bashers and two cutters just to pass both walls, leaving no inventory for ants 3-4; the text also says the stage cannot auto-complete without player toggling and that headless tests only do sequenced branch checks.

**Impact**: A broken/unwinnable dev stage can ship while the essential tests pass, masking integration problems in the full path.

**Recommendation**: Either make this layout-only for E3/E4, or define a deterministic headless solver with enough inventory for the intended saved count; align `total_ants`/`candy_hp`/inventory with the scenario and add a full-stage completion gate if it remains StageData.

#### [high] R1-H2: D4 claims plant and hazard are naturally cell-disjoint while the plan explicitly allows same-coordinate overlap and defers the only test
**Location**: `phases/mvp/plans/phase19-plan.md:31` (D4 row in §1.1)

D4 concludes the priority question is vacuous because the systems are cell-disjoint, but the same row says same-cell placement is layout-author responsibility, and §5/§2.6 explicitly define a same-coordinate plant+hazard scenario. Existing code supports that inference: hazards register independently by scene position and plant kind is registered independently in Terrain, with no cross-check. The only test for this behavior, `CutterOverHazardCellTest`, is deferred outside acceptance, so a hazard/plant overlap regression can ship undetected despite being part of the interaction table.

**Recommendation**: Choose one policy:
- (a) Reject plant+hazard same-cell layouts with an explicit validation/build guard, or
- (b) Promote `CutterOverHazardCellTest` to essential and rewrite D4 to state overlap is supported rather than cell-disjoint/vacuous.

#### [medium] R1-M1: Essential 5 do not enforce strict acceptance invariants 6 and 7
**Location**: `phases/mvp/plans/phase19-plan.md:321-331` (§7.1 essential table)

The essential PASS table covers cutter behavior, cross-kind destruction, and Terrain plant round-trip, but it does not gate SkillRegistry/SkillToolbar integration or backward compatibility of StageLayoutBuilder-generated earth kinds. Those are strict acceptance items 6 and 7. A missing CutterSkill preload, missing toolbar icon/label, or accidental non-earth kind for existing stage cells could pass the five new tests depending on whether drivers instantiate CutterSkill directly and do not assert StageRunner/toolbar validation errors.

**Recommendation**: Add deterministic essential gates for:
- `SkillRegistry.validate_stage` on the new cutter stages
- toolbar slot/icon/label creation for cutter
- a backward-compat builder test over an existing phase 1-18 layout asserting all generated static cells remain `kind="earth"`

### Next steps (codex 권고)
- Fix the plan before implementation: clarify D4 policy, repair or downgrade the mixed dev stage, and extend essential tests to cover all strict acceptance invariants.

### Plan-stage 3-round cap 정책 (2026-05-25 CLAUDE.md 갱신) 적용
- Round 1 HIGH 2건 발견 → 즉시 중단 X. plan v2로 fix 후 Round 2 자동 재리뷰 진행.
- Round 2 이후에도 HIGH 잔존 시 Round 3 1회 더. R3 HIGH면 그때 STOP + 사용자 결정.

---

## Round 2 (2026-05-25, plan v2 대상)

**Target**: working tree diff (CLAUDE.md + phases/mvp/plans/phase19-plan.md v2 + status.json + reviews/phase19-plan-review.md Round 1)
**Verdict**: **needs-attention**

**Summary**: No-ship — v2 still leaves acceptance gates inconsistent and one promoted essential fixture underspecified enough that the Round 1 fixes can be bypassed or fail for the wrong reason.

### Findings

#### [high] R2-H1: E6 primary fixture does not put the plant in Cutter's target row
**Location**: `phases/mvp/plans/phase19-plan.md:326-340` (§6.4 v2)

§6.4 places the plant/hazard same-cell at (10,22) on the floor row, while the cutter behavior elsewhere targets the ant body-row forward cell. With the ant spawned at (8,21), Cutter will look forward on y=21, not destroy the plant at y=22. The section adds an alternate body-row scenario, but leaves it optional.

**Impact**: The promoted R1-H2 essential test can either fail before proving hazard monitoring, or be implemented inconsistently by each driver author.

**Recommendation**: Make the body-row same-cell layout the required E6 fixture, or explicitly specify the ant/body-cell calculation that makes (10,22) the cutter target. Remove the optional alternate path.

#### [high] R2-H2: Acceptance text still allows only five new essential tests to pass
**Location**: `phases/mvp/plans/phase19-plan.md:411-413` (§9 closing wording)

The v2 plan repeatedly promotes E6/E7/E8 into the phase 19 essential set, but §9 still says "phase 19 신규 essential 5종도 모두 PASS" is sufficient for impl-stage review. That stale gate directly undermines the R1-H2/R1-M1 fixes: CutterOverHazardCellTest, SkillRegistryCutterValidateTest, and StageLayoutBuilderEarthBackwardCompatTest could be skipped while the written acceptance paragraph still claims review can pass.

**Recommendation**: Change §9 to require all phase 19 essential tests by name, including E6/E7/E8 (and any newly added E9), and align any status/checklist wording that still says five.

#### [high] R2-H3: R1-M1 toolbar integration is still not gated by E7
**Location**: `phases/mvp/plans/phase19-plan.md:101` (§2.5 E7 spec)

R1-M1 called out both SkillRegistry and SkillToolbar integration, and §10.6 still requires SkillToolbar ICONS/KO_LABELS entries. But E7 only checks SkillRegistry.get_skill, validate_stage, and _skills membership. A missing cutter toolbar icon or KO label would pass E7 and all other listed essential tests unless a full UI/toolbar driver happens to exercise it elsewhere.

**Recommendation**: Extend E7 or add a separate essential test that instantiates SkillToolbar with cutter inventory and asserts the cutter slot, icon preload, enabled/disabled state, and KO label render correctly.

#### [medium] R2-M1: E8 samples one existing layout while claiming phase 1-18 compatibility
**Location**: `phases/mvp/plans/phase19-plan.md:102` (§2.5 E8 spec)

E8 is specified to use an existing layout, with examples using either stage01 or dev_basher_wall, then §10 claims it enforces all phase 1-18 dev/main stages. That is not the same coverage. A regression affecting only slope layouts, a specific dev fixture, or a later phase layout can ship while this test passes on the single chosen sample.

**Recommendation**: Define E8 as a parameterized/all-layout test: enumerate every phase 1-18 main and dev StageLayoutData resource, build each, and assert every generated static cell remains kind="earth" with matching tile_map counts.

### Next steps (codex 권고)
- Fix §6.4 E6 target-row semantics before implementation.
- Update §9 acceptance wording from five to eight (or nine) phase 19 essentials.
- Add toolbar coverage to the essential gate.
- Broaden E8 from sample layout to all phase 1-18 layouts.

### Plan-stage 3-round cap 정책 적용
- Round 2 HIGH 3건 발견 → plan v3로 fix 후 **Round 3 자동 재리뷰 (마지막 fix 라운드)**.
- Round 3 HIGH 1건이라도 발견 시 즉시 STOP + 사용자에게 finding 요약 + 권고 옵션 제시 후 대기.

---

## Round 3 (2026-05-25, plan v3 대상) — 마지막 fix 라운드

**Target**: working tree diff (CLAUDE.md + phases/mvp/plans/phase19-plan.md v3 + reviews/phase19-plan-review.md Round 1+2 + status.json)
**Verdict**: **needs-attention** — **HIGH 1건** + **MEDIUM 1건**

**Summary**: No-ship — the R2-H1 fix still leaves E6 with contradictory spawn semantics, so the promoted hazard-overlap gate can fail before testing the invariant it is supposed to protect.

### Findings

#### [high] R3-H1: E6 still specifies two incompatible ant spawn positions for the required hazard-overlap fixture
**Location**: `phases/mvp/plans/phase19-plan.md:359-360` (§6.4 v3, body-row primary scenario)

§6.4 declares the fixture with ant spawn at (8,21), then immediately admits cutter forward at tick 1 is (9,21), so the plant at (10,21) is not hit and the worker aborts. The next line changes the scenario to a "simplification" spawn at (9,21). That means the required driver is not deterministic from the plan: one implementation follows the diagram/E6 prose and never reaches hazard monitoring, while another follows the simplification.

**Impact**: The R1-H2/R2-H1 essential gate can fail for the wrong reason or be implemented inconsistently, leaving same-cell plant+hazard behavior unproven.

**Recommendation**: Make one spawn authoritative everywhere. Prefer changing the diagram, E6 prose, and §6.4 driver steps to spawn at (9,21) with direction +1, or move the plant/hazard to (9,21) if (8,21) must remain the spawn. Remove the abandoned (8,21) path and state the expected first cutter target explicitly.

#### [medium] R3-M1: E8 claims directory-wide coverage but embeds a stale static layout list
**Location**: `phases/mvp/plans/phase19-plan.md:117` (§2.5 E8 v3 parameterized list)

E8 says the driver uses a hard-coded enumeration array, but the listed files do not match the current repository: `stage02_layout.tres`, `stage03_layout.tres`, `dev_traits_layout.tres`, and `dev_settle_layout.tres` are not present under `CandyAnts/data/stage_layouts`, while existing layouts include `dev_trait_test_layout.tres` and `dev_settle_test_layout.tres`. The same line also says the exact enumeration is the impl-stage directory scan, so the acceptance source of truth is ambiguous.

**Impact**: The backward-compat gate can either be unexecutable if implemented literally, or miss layouts if someone maintains the static list by hand.

**Recommendation**: Specify dynamic enumeration as the only allowed behavior: scan `data/stage_layouts/*.tres` at runtime, exclude only the named phase 19 plant fixtures, and fail if any load/build fails. Remove the static list or replace it with a generated snapshot that must match the directory exactly.

### Next steps (codex 권고)
- Stop under the Round 3 HIGH policy and revise E6 before implementation-stage work continues.
- After E6 is fixed, tighten E8 to runtime directory enumeration so new or renamed dev fixtures cannot silently escape coverage.

### Plan-stage 3-round cap 정책 — STOP 발동
- **R3 HIGH 1건 발견 → 즉시 작업 중단 + 사용자 결정 대기**.
- CLAUDE.md 2026-05-25 갱신 정책: "Round 3 = 2차 수정 후 재리뷰. HIGH 1건이라도 나오면 즉시 중단하고 사용자에게 보고. 사용자가 수정 방향·범위·취소 여부를 결정한다".
- 자동 R4 진행 금지. 사용자가 명시적으로 cap 확장 또는 manual fix 결정 시에만 추가 진행.

---

## Post-Round 3 Manual Fix (2026-05-25, plan v3.1)

**Trigger**: User explicitly asked to review/check/fix phase19 plan after Round 3 STOP, then confirmed continuing after asking why E6 coordinates are fixed and whether other-stage generality is preserved.

**Policy handling**: This is not an automatic Round 4 adversarial-review. The 3-round cap remains intact. v3.1 records a manual plan correction under user direction.

### Fixes Applied

#### R3-H1 resolved: E6 spawn semantics made deterministic

- `dev_cutter_over_hazard` E6 fixture now uses ant spawn `(9,21)`, direction `+1`.
- The first cutter target is explicitly `(10,21)`, the same cell that contains both `kind="plant"` and the Sticky hazard node.
- The abandoned `(8,21)` path and "simplification" wording were removed from implementation instructions.
- The plan now states that fixed coordinates are **fixture-local only**. Runtime Cutter/plant behavior remains coordinate-agnostic: stages may place plant cells anywhere, and Cutter uses ant direction + forward-cell kind checks rather than hard-coded coordinates.

#### R3-M1 resolved: E8 static stale list removed

- `StageLayoutBuilderEarthBackwardCompatTest` now uses runtime scan of `data/stage_layouts/*.tres` as the only SoT.
- Hand-maintained static enumeration arrays are forbidden.
- Only the four phase 19 plant fixtures may be excluded:
  `dev_cutter_vine_layout.tres`, `dev_cutter_edge_stop_layout.tres`, `dev_earth_plant_separation_layout.tres`, `dev_cutter_over_hazard_layout.tres`.
- Empty scan results, load failures, type mismatches, and build failures are specified as FAIL.

**Manual-fix conclusion**: The known Round 3 HIGH is addressed in the plan text without opening R4. Remaining implementation risk should be handled by the phase 19 essential tests during impl-stage.

---

## Round 4 (2026-05-25, plan v3.1 대상, user-extended cap)

**Target**: working tree diff (CLAUDE.md + phases/mvp/plans/phase19-plan.md v3.1 + phases/mvp/status.json + Round 1+2+3+Post-Round 3 manual fix)
**Trigger**: 사용자가 plan-stage 3-round cap STOP 후 manual fix(v3.1)를 직접 수행하고 "검토하고 코덱스 리뷰 진행해"로 명시 cap 확장 결정. 본 라운드는 정책상 자동 진입이 아닌 user-extended cap.
**Verdict**: **clean** — HIGH 0건. R3-H1/R3-M1 모두 CLOSED, R4-M1 MEDIUM 1건 잔존(impl 진입 블로커 아님).

### Section 1 — R3 Finding Closure Verification

#### R3-H1 — CLOSED

Evidence:
- Prior finding: `phases/mvp/reviews/phase19-plan-review.md:113-120` flagged incompatible E6 spawns `(8,21)` vs `(9,21)`.
- v3.1 fix: `phases/mvp/plans/phase19-plan.md:16` states ant spawn is unified to `(9,21)` and first Cutter target is `(10,21)`.
- Current E6 spec: `phase19-plan.md:124` says the test driver places one ant at `(9,21)` direction `+1`, first target `(10,21)`.
- Current diagram/prose: `phase19-plan.md:357`, `362-365`, `367-369` all align on ant `(9,21)`, plant/hazard `(10,21)`, first target `(10,21)`.
- Cross-doc/code check: existing WorkerState Basher pattern targets `body_cell + Vector2i(direction, 0)` matching the plan's Cutter body-row model. Existing tests already use manual body-cell spawn patterns.

Residual risk: none. Fixture coordinates are now deterministic and explicitly fixture-local.

#### R3-M1 — CLOSED

Evidence:
- v3.1 fix: `phase19-plan.md:17` declares dynamic runtime scan as the SoT; static list removed.
- Current E8 spec: `phase19-plan.md:126` requires `DirAccess`/`ResourceLoader` runtime scan of `data/stage_layouts/*.tres`, bans static filename arrays, excludes only four phase 19 plant fixtures, and fails on empty/load/type/build failures.
- Strict acceptance: `phase19-plan.md:477` repeats runtime scan as the E8 enforcement path; no competing doc claims a static E8 list as SoT.

Residual risk: historical R2 change-history text at `phase19-plan.md:28` still quotes a stale example list from v3, but it is explicitly history and current §2.5/§10 override it.

### Section 2 — Full Adversarial Sweep (remaining findings)

**HIGH: 0**

#### R4-M1
**Category**: internal row-convention wording inconsistency
**Severity**: MEDIUM
**Location**: `phase19-plan.md:67`, `101`, `104-106`, `227`, `308-319`, `339-345`, `364`

**Impact**: D4 and §6.4 contain "plant=floor row" wording, but every phase 19 Cutter target fixture places cuttable plant cells on the ant body row (y=21 in all E1/E2/E3/E4/E6 fixtures). Cutter itself is specified as body-row forward destruction. If a future implementer follows the "floor row" wording instead of the fixture tables, a plant placed at y=22 would never be reached by Cutter.

**Recommendation**: Change D4/§6.4 wording to "cuttable plant barriers for Cutter are body-row cells; same-cell overlap is explicitly allowed for E6." Not a blocker because all current fixtures give explicit body-row coordinates and essential tests would fail if implemented floor-row-only.

### Section 3 — New Risk Assessment (v3.1-introduced)

- Spawn unification to `(9,21)`: No HIGH risk. Existing runtime spawn is vector/resource-based; no existing script hardcodes `(9,21)` or `(10,21)` as runtime assumptions. E6 coordinates are fixture-local per `phase19-plan.md:365`.
- E8 runtime scan replacing static list: No HIGH risk. `data/stage_layouts/*.tres` scan is compatible with existing harness. Fail-on-empty/load/type/build behavior strengthens coverage.
- §0/§2.5/§6.4 coordinate consistency: Internally consistent across all three sections (`(9,21)` spawn, `(10,21)` target/hazard). New MEDIUM captured as R4-M1. No HIGH.

### Section 4 — Termination Recommendation

**CLEAN — proceed to impl.** HIGH 0건.

Recommended pre-impl cleanup: fix R4-M1 "plant=floor row" wording in D4/§6.4 (not a blocker; all fixture coordinates are body-row explicit and tests enforce it).

### Plan-stage 정책 — user-extended cap 종결

- 본 R4는 정책상 자동 라운드가 아니라 사용자 cap 확장. R3 STOP 이후 manual fix가 R3-H1/R3-M1을 모두 닫았음을 codex가 cross-doc grep으로 검증.
- HIGH 0건 → 추가 cap 확장(R5) 불필요. R4-M1 MEDIUM은 plan 내 1줄 wording 정정으로 닫거나 명시 defer 가능.
- 사용자 결정 옵션: (1) R4-M1 즉시 plan 내 wording 수정 → impl 진입, (2) R4-M1 deferred 박제 후 impl 진입, (3) plan 그대로 impl 진입(현재 fixture가 invariant 강제하므로 실용상 무영향).
