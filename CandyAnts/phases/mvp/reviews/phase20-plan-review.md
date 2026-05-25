# Phase 20 Plan Review — polish (MVP 종료)

## Round 1

> codex `/codex:adversarial-review` 1차. sandbox=read-only로 codex가 직접 파일 쓰기 차단되어 stdout을 본 라운드 헤더 아래 그대로 보존. verdict=needs-attention.

### HIGH: Proposed dev stage id 917 already exists

Plan §2.5 assigns `data/stages/dev/sticky_settle_test.tres` to `id=917` and says phase 20 will occupy `916~917` (`phases/mvp/plans/phase20-plan.md:109`, `:112`, `:119`). The existing repo already has `data/stages/dev/basher_wall_test.tres:7` with `id = 917`. The deferred source also reserved sticky settle as `id=914` (`phases/mvp/plans/phase17-deferred.md:53`, `:73`), and current dev ids show no existing `914`.

Recommended fix: keep `water_after_candy` at 916 if still free, assign sticky settle to 914 or another verified free id, and update the plan's dev id table before implementation.

### HIGH: Stage-specific star thresholds will not persist to SaveData

Plan F-D3 makes `stage03` use tighter thresholds and routes `"star_thresholds"` through `StageRunner._make_result` to `StageDialog.show_result` (`phases/mvp/plans/phase20-plan.md:55`, `:86`, `:91`, `:102`). But the same plan explicitly leaves `scripts/core/SaveData.gd` unchanged (`phase20-plan.md:161`). Existing `SaveData._on_stage_cleared` calls `record_clear(stage_id, saved, original_hp)` and `record_clear` calls `Scoring.compute_stars(saved, original_hp)` without reading result thresholds (`scripts/core/SaveData.gd:29-33`, `:126-127`). Result: StageDialog can show 1 star for `8/10` on stage03 while SaveData records 2 stars using global thresholds.

Recommended fix: either keep all stage data on global thresholds for phase 20, or change SaveData to pass `result.get("star_thresholds", [])` into `Scoring.compute_stars` and add a persistence regression test for stage03.

### HIGH: Proposed sticky animation pause will not resume

Plan P-D5 says adding `if is_stuck(): _sprite.pause(); return` to `Ant._update_sprite()` will "naturally" resume on the next frame after unstuck (`phase20-plan.md:68`, `:92`). Existing `Ant._update_sprite()` only calls `_sprite.play(...)` when `anim != _last_anim` (`scripts/ant/Ant.gd:116`, `:139-145`). If an ant is walking, gets stuck, and then unsticks while still in `WalkerState`, `anim` remains `"walk"` and `_last_anim` is still `"walk"`, so no play call is made and the AnimatedSprite2D stays paused.

Recommended fix: track a `_sprite_paused_for_sticky` flag and explicitly call `_sprite.play(_last_anim)` or force `_last_anim = ""` when leaving stuck state. Extend `AntStickyVisualTest` to assert animation resumes after sticky expiry, not only that pause occurred.

### HIGH: SceneFlow's last-stage predicate is not what the plan claims

Plan §3.4 says SceneFlow already calculates `is_last_stage = (result.stage_id == LAST_STAGE_ID)` and therefore can remain unchanged (`phase20-plan.md:316-318`). Existing code passes `_overlay.show_result(result, result["stage_id"] >= LAST_STAGE_ID)` (`scripts/core/SceneFlow.gd:163`). This is not equivalent: any result with a stage id above 3 is treated as last-stage. That matters because phase 20 adds high-numbered dev stages and changes last-stage title/Next behavior in `StageDialog`.

Recommended fix: either change SceneFlow to equality and count it as a deliberate SceneFlow modification, or document why `>=` is still intended and ensure dev/high-id stage results cannot reach StageDialog through SceneFlow.

### MEDIUM: Missing phase12 deferred SoT for sfx ids

The task names `phases/mvp/deferred/phase12-deferred.md` as context for `sfx_request` IDs, but this repo has no `phases/mvp/deferred/` directory and no `phase12-deferred.md`; only `phases/mvp/plans/phase17-deferred.md` exists. The plan relies on phase12-plan and current `EventBus.sfx_request(id: StringName)` instead (`phase20-plan.md:14`, `:56`, `:255`). The signal shape is consistent with existing code (`scripts/core/EventBus.gd:18`), but the requested deferred SoT for ID expansion is unavailable.

Recommended fix: add or locate the phase12 deferred record, or state in the plan that phase 20 is defining the eight gameplay sfx ids directly and phase12 only supplies the signal contract.

### MEDIUM: Threshold override accepts invalid arrays that can desync UI and data

Plan §3.1 implements `compute_stars(saved, original_hp, thresholds := [])` by iterating every threshold in the supplied array (`phase20-plan.md:189-200`). With an exported `StageData.star_thresholds: Array[float]`, malformed stage data such as four thresholds, unsorted thresholds, or values outside `0..1` can return more than 3 stars or unexpected counts. `StageDialog` only has three star polygons (`scripts/ui/StageDialog.gd:83` and star nodes in the same file), and SaveData stores an integer star count.

Recommended fix: validate `star_thresholds` length exactly 3 when non-empty and require ascending `0.0..1.0`, either in `StageRunner`/`StageData` validation or inside `Scoring.compute_stars` with clamping to 3.

### MEDIUM: Sticky progress denominator remains stale across later sticky applications

Plan P-D4 says `_sticky_max` is "most recent apply_sticky(dur)" but the implementation snippet uses `_sticky_max = max(_sticky_max, dur)` (`phase20-plan.md:67`, `:265-286`). Existing `apply_sticky` only extends `_sticky_remaining` when a longer duration arrives (`scripts/ant/Ant.gd:108-110`). If an ant is stuck for 3.0 seconds, later exits and re-enters a 1.0-second sticky, `_sticky_max` remains 3.0 and the bar starts one-third full instead of full.

Recommended fix: reset `_sticky_max` when `_sticky_remaining` reaches 0, or set `_sticky_max = dur` whenever a fresh sticky is applied after no active sticky remains.

### LOW: Test count is internally inconsistent

Plan §2.6 lists eight new test rows: WaterHazardLossCarrying, StickyCarryingPreserved, DistributorOnStickyTransfer, SettledImmuneToHazard, SfxRequestEmit, ScoringStarsOverride, StageDialogLastStageTitle, and AntStickyVisual (`phase20-plan.md:128-135`). Later acceptance and guard text says "본 phase 신규 7 test" (`phase20-plan.md:342`, `:364`).

Recommended fix: update the claimed count to 8, or merge/split tests so the file list and acceptance count match.

### LOW: StickyTimerBar texture choice references a missing asset

Plan §2.3/§2.9 allows `assets/icons/skills/sticky.svg` for `StickyTimerBar` (`phase20-plan.md:97`, `:172`). The current `assets/icons/skills` directory has no `sticky.svg`; `Ant.tscn` currently reuses `blocker.svg` for `StickyBadge`. This is not a blocker if a new placeholder asset is created, but the plan should not leave the missing path as a valid option.

Recommended fix: choose one concrete asset path in the plan: create `assets/icons/sticky_timer_bar.svg` or explicitly reuse an existing texture that exists.

verdict: needs-attention

## Round 2

### CRITICAL

No findings.

### HIGH

**ID: R2-H1**
**Location:** §2.8 CRITICAL ban list + §3.4 "last-stage Title 분기"
**Issue:** R1-H4 is only partially applied. The ban list still contains an unstruck `scripts/core/SceneFlow.gd` entry stating "last-stage 라우팅 전부 그대로", while a separate struck-through line in the same section notes the line-163 change. §3.4 further claims SceneFlow "이미" computes equality — implying no edit is needed — contradicting the fix intent.
**Evidence:** §2.8 has two conflicting SceneFlow lines: one unstruck saying routing is unchanged, one struck saying line 163 changes. §3.4 says `SceneFlow` already computes `is_last_stage = (result.stage_id == LAST_STAGE_ID)`.
**Fix:** Delete the unstruck SceneFlow ban-list entry (keep only the struck removal note). Rewrite §3.4 to explicitly state phase 20 changes SceneFlow.gd line 163 from `>= LAST_STAGE_ID` to `== LAST_STAGE_ID`.

### MEDIUM

**ID: R2-M1**
**Location:** §0 Subtitle description; §1.2 P-D6; §6 deferred list
**Issue:** Contradictory scope for cumulative star totals. §0 says Subtitle shows cumulative star totals; P-D6 and §6 both defer this feature.
**Fix:** Update §0 so Subtitle retains the existing saved/original display; note cumulative star totals are deferred.

### LOW

**ID: R2-L1**
**Location:** §0.0 change table, §0 description, §2.6; vs §4.3 and §5.3 acceptance/guard text
**Issue:** R1-L1 partially resolved — acceptance/guard sections now say 10 tests, but earlier description sections still say 8.
**Fix:** Replace remaining "8 test" occurrences with "10 test" for consistency.

## R1 Fix Verification Table

| ID | Status | Notes |
|---|---|---|
| R1-H1 | Resolved | `sticky_settle_test` reassigned to id=914; 917 remains `basher_wall_test`. |
| R1-H2 | Resolved | SaveData signature extended with `thresholds` arg; threshold routing and regression test specified. |
| R1-H3 | Resolved | `_sprite_paused_for_sticky` flag and explicit `play(_last_anim)` call specified; resume assertion added. |
| R1-H4 | Partial | Fix intent present but §2.8 unstruck ban-list entry and §3.4 stale equality claim remain contradictory. See R2-H1. |
| R1-M1 | Resolved | Phase 20 directly defines 8 gameplay sfx ids; phase 12 covers only signal contract and dialog ids. |
| R1-M2 | Resolved | Threshold validation (length≠3 / non-descending / out-of-0..1 range) → 0 star + warning specified. |
| R1-M3 | Resolved | `_sticky_max` reset on expiry and fresh-entry new-duration usage specified and tested. |
| R1-L1 | Partial | Acceptance/guard text corrected to 10, but earlier description text still says 8. See R2-L1. |
| R1-L2 | Resolved | `assets/icons/sticky_timer_bar.svg` confirmed as single new placeholder SVG. |

## Round 2 Verdict

**needs-attention**

Blocking HIGH+ items:
- **R2-H1** — `SceneFlow.gd` ban-list and §3.4 are contradictory: one says no change needed, the other says a change is already done. An implementer following the ban list will skip the fix entirely.

## Round 3

### Target

`phases/mvp/plans/phase20-plan.md` v3 after Round 2 fixes.

### Verdict

**clean** — HIGH 0 / MEDIUM 0 / LOW 0.

### Verification

- **R2-H1 CLOSED**: The unstruck `scripts/core/SceneFlow.gd` no-change ban-list entry is gone. §2.8 only keeps the struck-through "moved to modified targets" entry, and §3.4 is now the single implementation SoT for changing `SceneFlow.gd:163` from `result["stage_id"] >= LAST_STAGE_ID` to `result["stage_id"] == LAST_STAGE_ID`. SceneFlow's other routing/freeze/request handlers remain explicitly unchanged.
- **R2-M1 CLOSED**: §0, P-D6, and §6 consistently state that Subtitle keeps the phase 12 `saved {n} / {original_hp} 조각` display. Cumulative star totals remain deferred.
- **R2-L1 CLOSED**: The implementation/acceptance sections consistently require the phase 20 **10 test** set: D-1, D-2, D-5, D-6, SfxRequestEmit, ScoringStarsOverride, StageDialogLastStageTitle, AntStickyVisual, SaveDataStarOverride, and SceneFlowLastStagePredicate.

### Round 3 Conclusion

Plan-stage review is complete. No Round 3 blocker remains; proceed to implementation using `phase20-plan.md` v3.1 as the SoT.

## Round 3 verification (v3.1 metadata 정리)

> 사용자 요청으로 v3.1(메타데이터 정리 라운드) 기준 추가 verification 호출. codex sandbox=read-only로 직접 append 차단되어 stdout을 본 헤더 아래 그대로 보존.

- **Verdict**: clean
- **Check 1 — New HIGH contradictions**: PASS. §0.000 states v3.1 is only Round 3 documentation/status cleanup and that SceneFlow/SaveData/StageDialog/Ant/Sfx/Test specs are unchanged (`phase20-plan.md:7-15`); the implementation directive sections for those areas remain the body SoT (`phase20-plan.md:124-220`, `phase20-plan.md:230-419`) with no new contradictory metadata directive.
- **Check 2 — Termination consistency**: PASS. The Status header, §0.000, Status history, and round log all consistently say Round 3 was clean and plan-stage is closed (`phase20-plan.md:3`, `phase20-plan.md:7-15`, `phase20-plan.md:47`, `phase20-plan.md:448-464`), while still-open work is implementation-stage work described in the body, not further plan review.
- **Check 3 — Change-table chain integrity**: PASS. The change-table chain is strictly chronological and non-duplicated: §0.0 records v1→v2 Round 1 fixes, §0.00 records v2→v3 Round 2 fixes, and §0.000 records v3→v3.1 Round 3 metadata cleanup (`phase20-plan.md:7-45`), matching the Status history sequence (`phase20-plan.md:47`).
- **Summary**: v3.1 is safe to proceed to implementation stage.
