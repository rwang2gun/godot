# new-user-onboarding — Plan-stage Adversarial Review

대상: 워킹트리(phases/new-user-onboarding/phase01~07 + REVISION + metadata + docs/STAGE_GUIDE_PLAN.md §0.7~§0.8 + LEVEL_REDESIGN_STATUS §0.6 + DOMAIN_MAP §3.1). Plan-stage 3-round cap 정책(CLAUDE.md 2026-05-25).

## Round 1

(node:15260) [DEP0190] DeprecationWarning: Passing args to a child process with shell option true can lead to security vulnerabilities, as the arguments are not escaped, only concatenated.
(Use `node --trace-deprecation ...` to show where the warning was created)
[codex] Starting Codex task thread.
[codex] Thread ready (019ea040-3064-7512-b46a-e1c1633d23f1).
[codex] Turn started (019ea040-344f-7af0-b199-6076e1b9cee5).
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"I’ll inspect the working tree and the relevant plan f...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git -C CandyAnts diff -- docs/DOMAIN_M...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path C:/Users/code1412/.c...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git -C CandyAnts status --short'
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git -C CandyAnts diff -- docs/DOMAIN_M... (exit -1)
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git -C CandyAnts status --short' (exit -1)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path C:/Users/code1412/.c... (exit 0)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"The parallel git calls were rejected by the local she...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git status --short'
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git diff -- docs/DOMAIN_MAP.md docs/LE...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "rg -n \"0\\.7|0\\.8|SkillAffordance|SI...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git diff -- docs/DOMAIN_MAP.md docs/LE... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git status --short' (exit 0)
[codex] Command failed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "rg -n \"0\\.7|0\\.8|SkillAffordance|SI... (exit 1)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"I have the modified docs diff and am now checking the...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path docs/STAGE_GUIDE_P...
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path docs/STAGE_GUIDE_P... (exit -1)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path scripts/world/Skil...
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path scripts/world/Skil... (exit -1)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo... (exit 0)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/world/SkillS...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/world/Placem...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/ui/SkillTool...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/core/StageRu...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/world/SkillS... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/world/Placem... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/ui/SkillTool... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path scripts/core/StageRu... (exit 0)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path docs/STAGE_GUIDE_PLA...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path phases/new-user-onbo... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'Get-Content -Path docs/STAGE_GUIDE_PLA... (exit 0)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"surface 타일\" phases\\n...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_ant_at_cell\" phases\...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"CATEGORY_GUIDE_ASSETS\...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"--check\" phases\\new-...
[codex] Command failed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"surface 타일\" phases\\n... (exit 1)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_ant_at_cell\" phases\... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"CATEGORY_GUIDE_ASSETS\... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"--check\" phases\\new-... (exit 0)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"I found one concrete mismatch in the affordance mappi...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_ready\" phases\\new-u...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"스폰/타이머\" phases\\new-u...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_spawner.start\" scrip...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_time_left\" scripts\\...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_ready\" phases\\new-u... (exit 0)
[codex] Command failed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"스폰/타이머\" phases\\new-u... (exit 1)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_spawner.start\" scrip... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_time_left\" scripts\\... (exit 0)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"카드 표시 중\" phases\\new-...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"begin\" phases\\new-us...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_ground_cell_for_sign\...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_leaf_jump_pad_exists\...
[codex] Command failed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"카드 표시 중\" phases\\new-... (exit 1)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"begin\" phases\\new-us... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_ground_cell_for_sign\... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"_leaf_jump_pad_exists\... (exit 0)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"S1 blocker\" docs\\STA...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"exact-fit\" docs\\STAG...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"can_apply\" phases\\ne...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"blocker\" docs\\STAGE_...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"S1 blocker\" docs\\STA... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"exact-fit\" docs\\STAG... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"can_apply\" phases\\ne... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"blocker\" docs\\STAGE_... (exit 0)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"No-ship: the plan knowingly ships an onboarding affor...
[codex] Turn completion inferred after the main thread finished and subagent work drained.
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan knowingly ships an onboarding affordance that can guide S1 players into an unwinnable state, and the surface-glow and asset-contract mechanics are underspecified enough to create visible regressions or false confidence.

Findings:
- [high] S1 onboarding can highlight a known soft-lock action (docs/STAGE_GUIDE_PLAN.md:40-41)
  The plan explicitly records that S1 has total_ants=5 and candy_hp=5, while blocker is available and permanently consumes an ant; using it leaves only 4 carriers and makes clear impossible. Despite that, the issue is deferred out of scope, while Phase 2 makes ANT_SETTLE skills glow eligible ants via can_apply. Inference: blocker will be visually advertised as a valid action on S1 because can_apply only proves the skill can attach, not that the exact-fit economy can still clear. For elementary/casual onboarding, this turns the new guidance layer into a trap on the first stage.
  Recommendation: Do not defer this for the onboarding plan. Either remove blocker from S1, budget S1 as total=6=hp5+blocker1, or add an economy-aware eligibility rule/test that suppresses optional permanent-consumer affordances when using them would make the stage unclearable.
- [medium] Surface glow is mapped to the sign trigger rule, not the actual placement rule (phases/new-user-onboarding/phase02-tap-target-glow.md:21-32)
  Phase 2 says SIGN/DEVICE surface glows should use the SkillSign._ant_at_cell/is_on_floor rule and match actual installable cells. That is the wrong runtime boundary: placement is performed by SkillToolbar._ground_cell_for_sign, which rejects occupied clicked cells, snaps downward up to 64 cells to the first floor, and leaf_jump also rejects duplicate pads. SkillSign._ant_at_cell only decides whether a walking ant later triggers a placed sign by column. The plan can therefore glow cells that cannot be clicked successfully, fail to represent snap behavior, and miss DEVICE duplicate-pad invalidity.
  Recommendation: Define a shared placement-query API for SIGN and DEVICE, e.g. resolve_surface_install_cell(skill_id, world/cell) returning valid/snap_target/reason, and require both SkillToolbar placement and AffordanceGlowController/tests to use it. Cover occupied cells, no-floor columns, snap-to-floor, and duplicate leaf_jump pads.
- [medium] Asset auto-request contract is not actually part of the failing verification path (phases/new-user-onboarding/phase07-skill-guide-asset-contract.md:4-29)
  Phase 7 claims missing guide assets should fail loudly and be automatically recorded in ASSET_PRODUCTION_NEEDS.md, but the verify command runs report_skill_guide_assets.py --check, and the phase defines --check as nonzero exit on missing assets while only the default mode appends requests. That means the normal gate can fail without producing the promised production request, while the mutating mode is not required by verify. This undercuts the contract the plan relies on for future skill additions.
  Recommendation: Make the workflow explicit and deterministic: add a required report-and-check mode that writes/updates a stable request section before exiting nonzero, or split CI check from a required generated report test that verifies ASSET_PRODUCTION_NEEDS.md is updated without duplicates.

Next steps:
- Fix the S1 exact-fit/blocker contradiction before implementing the affordance phases.
- Replace surface-glow heuristics with a shared placement validity API in the plan.
- Clarify the asset-report tool contract so failure and request generation happen in the same required workflow.


---

### R1 수정 요약 (2026-06-07)
- **HIGH (S1 blocker 소프트락)** → `stage01.tres`에서 blocker 제거(available=[climber], inv={climber:5}). CampaignS1ClearTest saved5/5 PASS. blocker 첫 등장=S2(예산 안). docs §0.7/§3.2/§3.3/§4 + LEVEL_REDESIGN §0.6 동기화.
- **MEDIUM (surface 글로우 배치 규칙)** → Phase2/3에 공유 `SignPlacement.resolve_surface_install_cell` API 신설(점유·아래스냅·leaf 중복 = 실제 배치 SoT). 글로우/프리뷰/배치/테스트가 동일 API. §0.8.2 정정.
- **MEDIUM (에셋 계약 verify)** → Phase7 `--report-check` 통합 모드(요청 기록 후 누락 시 nonzero, 같은 필수 경로) + SkillGuideAssetReportTest. §0.8.6 정정.

## Round 2

(node:8004) [DEP0190] DeprecationWarning: Passing args to a child process with shell option true can lead to security vulnerabilities, as the arguments are not escaped, only concatenated.
(Use `node --trace-deprecation ...` to show where the warning was created)
[codex] Starting Codex task thread.
[codex] Thread ready (019ea06a-67f7-7a42-80d2-932355c4b500).
[codex] Turn started (019ea06a-6ba3-7333-b2b4-cd1b7db0c561).
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"I’ll inspect the working tree diff and plan files dir...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git status --short'
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git status --short' (exit 0)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"Status confirms this is still mostly plan/document ch...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git diff -- CandyAnts/data/stages/stag...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'rg -n "available_skills|inventory|bloc...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'rg -n "report-check|--check|SkillGuide...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'rg -n "phase07|report_skill_guide_asse...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'git diff -- CandyAnts/data/stages/stag... (exit 0)
[codex] Command failed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'rg -n "available_skills|inventory|bloc... (exit 1)
[codex] Command failed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'rg -n "phase07|report_skill_guide_asse... (exit 1)
[codex] Command failed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command 'rg -n "report-check|--check|SkillGuide... (exit 1)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"`rg` is unavailable in this shell, so I’m falling bac...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Get-ChildItem -Path CandyAnts\\data\\s...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path CandyAnts\\phases\...
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path CandyAnts\\phases\... (exit -1)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path CandyAnts\\phases\...
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path CandyAnts\\phases\... (exit -1)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path CandyAnts\\phases\...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Select-String -Path CandyAnts\\phases\... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Get-ChildItem -Path CandyAnts\\data\\s... (exit 0)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"The live stage data no longer has blocker in S1, and ...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command '$i=0; Get-Content -Path CandyAnts'"\\p...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command '$i=0; Get-Content -Path CandyAnts'"\\p...
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command '$i=0; Get-Content -Path CandyAnts'"\\p... (exit -1)
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command '$i=0; Get-Content -Path CandyAnts'"\\p... (exit -1)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command '$i=0; Get-Content -Path CandyAnts'"\\p...
[codex] Command declined: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command '$i=0; Get-Content -Path CandyAnts'"\\p... (exit -1)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Get-ChildItem -Recurse -File CandyAnts...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "Get-ChildItem -Recurse -File CandyAnts... (exit 0)
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"report_skill_guide_ass...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"report_skill_guide_ass...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"SkillGuideAssetReportT...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"S1 blocker\" CandyAnts...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"report_skill_guide_ass... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"report_skill_guide_ass... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"SkillGuideAssetReportT... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"S1 blocker\" CandyAnts... (exit 0)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"There is also a verification coverage gap in the surf...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"verify:\" /c:\"SignPla...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"TapTargetGlowSurfaceTe...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"verify:\" /c:\"Placeme...
[codex] Running command: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"resolve_surface_instal...
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"TapTargetGlowSurfaceTe... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"verify:\" /c:\"SignPla... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"verify:\" /c:\"Placeme... (exit 0)
[codex] Command completed: "C:\\Program Files\\PowerShell\\7\\pwsh.exe" -Command "findstr /n /c:\"resolve_surface_instal... (exit 0)
[codex] Assistant message captured: {"verdict":"needs-attention","summary":"No-ship: the S1 data fix appears resolved, but two R1...
[codex] Turn completion inferred after the main thread finished and subagent work drained.
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the S1 data fix appears resolved, but two R1 fixes are still not wired into the required execution path, so the plan can regress exactly where it claims to be guarded.

Findings:
- [medium] Surface placement parity test is specified but not required by phase execution (CandyAnts/phases/new-user-onboarding/phase02-tap-target-glow.md:4-26)
  Phase 2 introduces SignPlacement.resolve_surface_install_cell as the shared source for glow, preview, placement, and tests, and it explicitly adds SignPlacementParityTest to prove the extraction preserves _ground_cell_for_sign and _leaf_jump_pad_exists behavior. However, the phase verify command only runs the three glow tests and omits SignPlacementParityTest. The status.json verify command has the same omission. That leaves the R1 double-SoT fix vulnerable to shipping with a broken extraction: glow may call the new API while placement behavior silently changes or diverges, and the required phase gate would still pass.
  Recommendation: Add python scripts/run_test.py tests/SignPlacementParityTest.tscn to the Phase 2 frontmatter verify command and sync phases/new-user-onboarding/status.json so the harness runs the parity guard.
- [medium] Asset report fix is still bypassed by status.json (CandyAnts/phases/new-user-onboarding/status.json:77)
  Phase 7 frontmatter was updated to run SkillGuideAssetReportTest and report_skill_guide_assets.py --report-check, but status.json still records the old required verify command: SkillGuideAssetContractTest plus report_skill_guide_assets.py --check. If the phase runner resumes from status.json, the required path can fail on missing guide assets without writing/updating ASSET_PRODUCTION_NEEDS.md and without running the test that proves report-check is mutating and idempotent. This reintroduces the R1 asset-contract failure mode through the machine-readable execution state.
  Recommendation: Sync status.json with phase07 frontmatter so Phase 7 verify runs SkillGuideAssetReportTest and report_skill_guide_assets.py --report-check, or regenerate status via the documented sync-status flow before considering the plan fixed.

Next steps:
- Run the status/phase sync after updating Phase 2 and Phase 7 verify commands.
- Re-run the review on the synced working tree, specifically checking phase frontmatter and status.json agree for every R1 guard.


---

### R2 결과 + 종결 (2026-06-07)
- **verdict: needs-attention, HIGH 0** — MEDIUM 2건(둘 다 frontmatter verify 변경 후 status.json 미동기화 드리프트).
  - M1: Phase2 verify에 SignPlacementParityTest 누락 → **추가** + sync-status.
  - M2: status.json:77 Phase7 verify가 옛 --check → **sync-status로 --report-check 반영**.
- 확인: status.json verify가 phase02(parity)·phase07(--report-check) frontmatter와 일치. validate ✓.
- **Plan-stage 종결**: R1 HIGH 1→해소, R1/R2 MEDIUM 4건 전부 plan 내 처리. HIGH 0 달성. 3-round cap 내(R1→fix→R2→fix) 종료, R3 불요(MEDIUM-only).

---

# Phase 7 (input-mode-polish) — Mid-flight Re-scope Plan Review (2026-06-07)

> 별개 컨텍스트: 위 Round 1/2는 task 최초 전체 계획(Phase 1~7) 리뷰. 아래는 Phase 6
> (guide-card-ui-restructure)가 페이지네이션 개편으로 흡수 완료된 뒤, **Phase 7을 페이지네이션
> 현실에 맞춰 재조정**(사용자 Option A)한 plan의 별도 적대적 리뷰 사이클. 3-round cap 동일 적용.

## Round 1

Target: working tree diff (phase06-input-mode-polish.md re-scope)
Verdict: needs-attention — HIGH 1 + MEDIUM 2

- [HIGH] Acceptance can pass while STAGE_GUIDE_PLAN §2.6/§0.8.4 still requires the discarded
  card-copy and badge parity work (phase06-input-mode-polish.md:21-66). Circular proof: plan
  declares SoT obsolete then claims compliance with it before SoT/REVISION drift is resolved.
  Rec: make SoT update a prerequisite acceptance item (gating), restate revised §2.6 invariant,
  require REVISION to record supersession before tests count as sufficient.
- [MEDIUM] Integration test does not prove the user-visible chain (instantiates card directly +
  manually wires affordance) — proves components callable in sequence, not real scene wiring.
  Rec: add seam-level test on real scene/bootstrap (headless skip overridden), or rename to
  component-chain coverage + explicit uncovered-risk note.
- [MEDIUM] Dead single-card path left unowned = drift trap (treated as both dead AND fallback).
  Stale 'tap' copy/badge can show under missing/malformed guide data. Rec: delete (migrate render
  tests off inspector) OR own as supported fallback (mode-neutral copy + pages-empty/null test).

### R1 수정 요약 (2026-06-07)
- **H1**: §0절 "SoT 정합화(게이팅)" 신설 — STAGE_GUIDE_PLAN §2.6.1 신 불변식 verbatim + §2.6/§0.8/§2/
  §3.2 supersession 마커 + REVISION §6 박제를 **수용의 전제**로 승격. 카드 배지 은퇴는 사용자 Option A
  결정의 박제(새 결정 아님).
- **M1**: OnboardingIntegrationTest를 **실씬 seam**으로 재설계 — 실 Stage01(auto_begin=false)+실 카드+
  SceneFlow 배선 모사(intro_dismissed→begin), 페이지→dismiss→is_begun+실 스폰→어포던스 적격→스킬 전이.
  StageRunnerBeginGateTest/HeadlessSkipTest를 부트/스킵 seam 커버로 인용 + 커버리지 경계 주석.
- **M2**: 단일카드 경로를 "지원 fallback"으로 소유 — `guide.badge.*` 모드 중립화 +
  StageIntroCardFallbackTest(guide-null placeholder + pages-empty 렌더 잠금). `*_desc` "탭" 동사
  중립화는 MEDIUM-residual 명시 defer(미도달+shape 잠금 근거).

## Round 2

Target: working tree diff (phase06 re-scope, R1 fixes applied)
Verdict: needs-attention — **HIGH 0** + MEDIUM 2

- [MEDIUM] Supported fallback can still render retired tap-copy because `guide.sN.*_desc`
  neutralization was deferred while the path was promoted to "supported fallback"
  (phase06-input-mode-polish.md:55-58). Internally inconsistent: supported AND allowed-to-show-stale.
  Rec: neutralize desc strings + assert no retired verbs, OR mark fallback non-user-facing/diagnostic.
- [MEDIUM] status.json verify omits StageIntroCardFallbackTest (status.json:80-82) → M2 guard not
  gating if automation uses status.json. Rec: sync status.json verify to phase frontmatter.

### R2 수정 요약 + 종결 (2026-06-07)
- **M1(R2)**: "지원 fallback" 프레이밍 폐기 → 단일카드 스킬 경로를 **legacy·non-user-facing**로 재분류.
  StageIntroCardFallbackTest를 3-part로 강화: (a) **출하 가드** = 모든 캠페인 guide(n=1..8) `pages`
  non-empty 단언 → 단일카드 경로 캠페인 도달불가(malformed/missing-pages guide 출하 시 fail);
  (b) guide-null → placeholder 카피-free(유일 user-facing degraded); (c) legacy pages-empty 렌더
  shape regression 가드. → `*_desc` "탭" 동사는 **어떤 사용자에게도 미렌더**(가드로 보장)라 중립화
  불요·defer 잔여 아님. 배지 4키는 그대로 모드 중립화(inspector 어휘 일관).
- **M2(R2)**: phase frontmatter verify에 3번째 테스트 추가 + **status.json Phase 6 verify 수동
  동기화**(Phase 6 완료 커스텀 필드 보존 위해 sync-status 대신 직접 편집). 일치 검증: MATCH, validate ✓.
- **Plan-stage(Phase 7 재조정) 종결**: R1 HIGH 1 → R2 HIGH 0. MEDIUM은 전부 plan 내 처리(코덱스
  권고 중 더 견고한 대안 채택). 정책상 "HIGH 0 + MEDIUM plan 내 처리 → 어느 라운드든 종결" 적용,
  R3 codex 불요. 2-round(R1→fix→R2→fix)로 3-round cap 내 종료. → 구현(impl stage) 진입.
