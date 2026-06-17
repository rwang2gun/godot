# Phase B1 (ch1-front) — Plan Stage Adversarial Review

> 정책: CLAUDE.md plan stage — CRITICAL/HIGH 발견 시 최대 2회 수정+재리뷰(3-round cap).
> Round 1 = `codex exec -s read-only` (2026-06-09). 정식 `/codex:adversarial-review`는 disable-model-invocation이라 codex exec로 동등 구동.

## Round 1 — codex exec read-only (2026-06-09)

## Verdict: needs-attention

## Findings

### CRITICAL

[CRITICAL-1] Test plan — existing required tests will fail immediately -> Update the plan before implementation, not after.  
`tests/CampaignManifestTest.gd` hard-codes live manifest order as `[1,2,3,4,5,6,7,8,9,10]`, Ch1 as `[1,2]`, and Ch5 as `[9,10]`. The proposed manifest becomes `[1,11,12,13,14,2,3,4,5,6,7,8,9,10]`, so the verify command is knowingly red. Add explicit updates to `CampaignManifestTest.gd`.

[CRITICAL-2] GameFlowTest — Scenario A still asserts Stage01 Next -> Stage02 -> Change it to Stage01 Next -> Stage11.  
`tests/GameFlowTest.gd` Scenario A verifies current stage id `2` after clearing Stage01. With manifest order `[1,11,12,13,14,2,...]`, SceneFlow correctly loads `11`. The plan only calls out Scenario B last-stage invariance and misses the now-broken Scenario A.

### HIGH

[HIGH-1] StageSelectUnlockTest — Ch1 slot-state assertions are stale -> Rewrite it around `[1,11,12,13,14,2,0,0,0,0]`.  
`tests/StageSelectUnlockTest.gd` currently assumes Ch1 has 2 real slots plus 8 placeholders. After this phase Ch1 has 6 real slots plus 4 placeholders. With only stage1 cleared, expected states should be: `CLEARED, PLAYABLE, LOCKED, LOCKED, LOCKED, LOCKED, COMING_SOON x4`. Current test expects slot 2 onward to be placeholders, so it fails.

[HIGH-2] Blocker stage design — permanent blocker can break the return path -> Specify round-trip geometry, not just outbound redirection.  
For id12/id13, blocker collision reverses ants permanently at that location. A blocker placed “before the pit” may save outbound walkers but later bounce candy carriers away from Home or back into the hazard after candy pickup flips direction. The plan needs an explicit outbound and return path contract plus clear tests proving saved pieces return, not just that ants avoid water once.

[HIGH-3] Negative tests — “no blocker/no floater” can become false positives -> Require pickup/loss observability.  
`CampaignS12NoBlockerTest` must prove ants would otherwise reach the relevant route and fail because blocker is absent: e.g. `lost > 0`, `saved < candy_hp`, and preferably hazard/contact evidence. `CampaignS14NoFloaterTest` must apply any required climber path but withhold floater, then assert `picked > 0`, `lost > 0`, `saved < hp`. Without that, a broken map where ants never reach candy can pass as “skill is necessary.”

[HIGH-4] Scene identity — copy/repoint workflow can silently publish wrong ids -> Add identity validation.  
The plan copies existing trios and repoints resources, but manifest validity only catches duplicate ids in the manifest. It will not catch `Stage11.tscn` still pointing at `stage02.tres`, or `stage11.tres` having `id = 2`. Add checks/tests that `StageNN.tscn -> StageData.id == NN`, `stageNN.tres id == NN`, and no duplicate stage resource ids for 11-14.

### MEDIUM

[MEDIUM-1] Cleared preservation — claimed but not tested on the live insertion -> Add a live-order preservation test.  
ADR-014 preserves `SaveData` by scene id, so stage02 progress should survive moving from slot2 to slot6. The plan states this but does not add a live manifest regression: clear id2, apply/order `[1,11,12,13,14,2]`, verify id2 remains cleared and appears as slot6 `CLEARED` only when previous ids are unlocked as intended.

[MEDIUM-2] Stage02 naming — plan says “오르막”, current SoT says “절벽 아래로” -> Align name or explicitly defer rename.  
`data/stages/stage02.tres` and `scripts/core/Strings.gd` use “절벽 아래로”. The plan table and verification prose call slot6 “오르막”. Since StageSlotCard uses `Strings.stage_name()`, the UI will show the old name. Either update `stage.s2.name` deliberately or stop calling it “오르막” in the plan.

[MEDIUM-3] Water SoT — `hazard_map` is not runtime by itself -> Make Water instances part of acceptance.  
`StageLayoutData.hazard_map` is editor/roundtrip data; `StageLayoutBuilder` does not instantiate hazards from it at runtime. The plan mentions both hazard_map and Water instances, but the acceptance criteria should explicitly verify scene Water nodes exist for critical pits/margins, or the map can look hazardous in data while playing as safe empty space.

[MEDIUM-4] Fall threshold docs/tests conflict -> Update stale assumptions around 5 vs 6 cells.  
The plan correctly says use `>=6` cells because exact 5 is unreliable in practice, but existing `CampaignS2NoFloaterTest.gd` comments still claim 5 cells should trigger. That stale test commentary will mislead future authors. Add a note to update or avoid reusing that assumption in id14.

[MEDIUM-5] Verify command references future tests but does not require their `.tscn` creation explicitly enough -> Add `.gd/.tscn` acceptance for every new test.  
The plan lists new tests in “신규”, but the verify frontmatter calls `.tscn` paths. For copied tests, missing `.tscn` wrappers are an easy failure mode. Make each required pair explicit: `CampaignS11ClearTest.gd/.tscn` through `CampaignS14ClearTest.gd/.tscn`, plus both negative pairs.

### LOW

[LOW-1] Campaign ordinal vs scene_id ambiguity — `CampaignS11` will be easy to misread -> Clarify naming.  
Docs §3 uses “Stages 11-20” as campaign ordinals for Chapter 2, while this plan uses scene ids 11-14 for Ch1 slots 2-5. That is valid under ADR-014, but easy to confuse. Add one sentence: test names `CampaignS11*` refer to immutable `scene_id=11`, not campaign stage number 11.

[LOW-2] Placeholder behavior is correct but should be asserted by id, not only state -> Strengthen StageSelect assertions.  
StageSelect pads to 10 with `stage_id=0`. After this phase, slots 7-10 should be exactly four `stage_id=0` placeholders. Assert both ids and states so a manifest/order regression cannot pass with visually similar cards.

### Round 1 대응 (plan 수정 완료, 2026-06-09)
- **C-1** → 변경 대상에 `CampaignManifestTest.gd` 하드코딩 순서/Ch1 기대값 갱신 명시.
- **C-2** → `GameFlowTest.gd` Scenario A Next=id11 갱신 명시(ScenB/C 불변).
- **H-1** → `StageSelectUnlockTest.gd` Ch1 케이스 재작성 명시(6 실제+4 placeholder, 기대 상태 배열 + placeholder `stage_id==0`).
- **H-2** → "공통 계약 §왕복 동선" 신설: blocker 분기는 사탕·집 동선과 분리된 막다른 위험 분기, Home/Candy 같은 쪽, ClearTest `saved≥hp`(귀환) 단언.
- **H-3** → "공통 계약 §필수성 negative": `lost>0 ∧ saved<hp` + 짝 ClearTest가 가용성 보장, floater는 `picked>0` 추가.
- **H-4** → `StageIdentityTest` 신설(stageNN.tres.id==NN ∧ StageNN.tscn 로드 id==NN ∧ 중복 0).
- **M-1** → `CampaignClearedPreservationTest` 신설(id2 cleared → 재배치 후 보존).
- **M-2** → slot6 이름 "절벽 아래로"(현 이름) 유지, "오르막" rename B2 defer 명시.
- **M-3** → "공통 계약 §해저드": water는 Water.tscn 인스턴스 필수(hazard_map만으론 무발화), acceptance 포함.
- **M-4** → 회귀 주의에 CampaignS2NoFloaterTest "5칸" stale 주석 경고 + id14 ≥6칸.
- **M-5** → 신규 테스트 `.{gd,tscn}` 쌍 명시.
- **LOW-1/2** → scene_id≠순번 주석 + placeholder `stage_id==0` 단언.
## Round 2 — codex exec read-only (2026-06-09)

## Verdict: needs-attention

## Findings

### CRITICAL

None.

### HIGH

[HIGH-1] CampaignManifestTest — C-1 is only partially addressed -> The revised plan updates `ordered_stage_ids` and Ch1 expectations, but current `tests/CampaignManifestTest.gd` also hard-codes derived expectations that will go red: `next_stage_id(1) == 2` must become `11`, and `position_of(10) == 10` must become `14`. Recommendation: explicitly list all changed assertions in `CampaignManifestTest.gd`: ordered list, Ch1 list, `next(1)=11`, `next(14)=2`, `position(10)=14`.

[HIGH-2] id12 negative observability — `lost > 0` does not match current water semantics -> `StageRunner` result `lost` is `ScoreSystem.lost_pieces`, and `ScoreSystem` increments it only on `candy_piece_lost`. `WaterHazard` sends empty-handed ants to `AdriftState`; `AdriftState` emits `candy_piece_lost` only if `a.has_candy`. The id12 concept says no-blocker sends ants into a danger branch before candy pickup, so `saved < hp` may happen while `lost == 0`. Recommendation: either redesign the no-blocker route so carrying ants hit water, or change the id12 negative contract to observe water/adrift entry directly instead of result `lost > 0`.

### MEDIUM

[MEDIUM-1] CampaignClearedPreservationTest — M-1 acceptance is internally inconsistent -> The plan says “id2 cleared 기록” and also “slot6 위치(직전 id14 cleared 시 PLAYABLE)”. In `StageSelect._resolve_slot_state`, cleared wins before playable, so if id2 is cleared, slot6 should be `CLEARED`, not `PLAYABLE`. Recommendation: split this into two assertions: id2-cleared preservation means slot6 is `CLEARED`; a separate unlock case with id14 cleared and id2 not cleared should expect slot6 `PLAYABLE`.

### LOW

[LOW-1] StringsTableTest wording — minor ambiguity -> The plan says explicit key additions are unnecessary because `StringsTableTest` loops published ids, but once 11-14 are published that loop requires `stage.s11.name` through `stage.s14.name`. The plan does list those additions under `Strings.gd`, so this is mostly wording. Recommendation: say `StringsTableTest` needs no code change, but `Strings.gd` keys are mandatory.

## Round-1 Status

Resolved: C-2, H-1, H-2, H-4, M-2, M-3, M-5, LOW-1, LOW-2.

Partially resolved / still needs attention: C-1, H-3, M-1.

M-4 is acceptable as a defer/avoidance note for id14, though updating the stale `CampaignS2NoFloaterTest.gd` comment would still reduce future confusion.
### Round 2 대응 (plan 수정 완료, 2026-06-09)
- **R2-HIGH-1** → CampaignManifestTest 파생 단언 전수 열거(ordered/Ch1/next(1)=11/next(14)=2/position(10)=14).
- **R2-HIGH-2** → 공통 계약 §필수성 negative 정정: lost는 carrier-death만 카운트(빈손 익사 lost==0). blocker id12 = saved<hp 관측, floater id14 = picked>0∧lost>0∧saved<hp.
- **R2-MEDIUM-1** → CampaignClearedPreservationTest 두 단언 분리: (a) id2 cleared→slot6 CLEARED, (b) id14 cleared+id2 미클리어→slot6 PLAYABLE.
- **R2-LOW-1** → StringsTableTest 코드 변경 불요 명시 + Strings.gd 키 필수 명시.

## Round 3 — codex exec read-only (2026-06-09) — FINAL

## Verdict: clean

## Findings

### HIGH

R2-HIGH-1: RESOLVED.  
The plan explicitly lists all `CampaignManifestTest.gd` derived assertion updates: ordered ids `[1,11,12,13,14,2,3,4,5,6,7,8,9,10]`, Ch1 `[1,11,12,13,14,2]`, `next_stage_id(1)=11`, `next_stage_id(14)=2`, and `position_of(10)=14`. Current [tests/CampaignManifestTest.gd](D:/claude/godot/CandyAnts/tests/CampaignManifestTest.gd) is still old, but this is correctly planned as an implementation edit.

R2-HIGH-2: RESOLVED.  
The plan now matches engine behavior. [WaterHazard.gd](D:/claude/godot/CandyAnts/scripts/world/hazards/WaterHazard.gd) transitions ants to `AdriftState`; [AdriftState.gd](D:/claude/godot/CandyAnts/scripts/ant/states/AdriftState.gd) emits `candy_piece_lost` only when `a.has_candy`; [ScoreSystem.gd](D:/claude/godot/CandyAnts/scripts/core/ScoreSystem.gd) increments `lost_pieces` only from that signal. The plan’s common contract correctly says id12 no-blocker asserts `saved < candy_hp` without requiring `lost > 0`, while id14 no-floater keeps `picked > 0 ∧ lost > 0 ∧ saved < hp`.

### MEDIUM

R2-MEDIUM-1: RESOLVED.  
The plan splits `CampaignClearedPreservationTest` into the two correct cases: id2 already cleared means slot6 is `CLEARED`; id14 cleared and id2 not cleared means slot6 is `PLAYABLE`. This matches [StageSelect.gd](D:/claude/godot/CandyAnts/scripts/ui/StageSelect.gd), where `_resolve_slot_state()` checks `CLEARED` before `PLAYABLE`.

### LOW

R2-LOW-1: RESOLVED.  
The plan now says `StringsTableTest` needs no code change, but `Strings.gd` keys `stage.s11.name` through `stage.s14.name` are mandatory once ids 11-14 are published.

No remaining CRITICAL/HIGH blocker found in the revised plan.
### 결론: plan stage 통과 (3-round cap 내 clean). 구현 진입 승인.
