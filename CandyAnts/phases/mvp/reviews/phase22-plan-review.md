# Phase 22 — Plan Adversarial Review

## Round 1
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan creates a real phase-number collision with the existing Notion/page-id SoT, and the asset verification path is not clean-clone safe yet.

Findings:
- [high] Phase 22 now points to two different work items in the phase trackers (phases/mvp/metadata.json:5-9)
  The working tree adds Phase 22 as `sfx-assets` and shifts post-MVP slots to 21-24, but `phases/mvp/notion-phase-ids.json` still maps phase 22 to `input-touch` and phase 23 to `input-advanced`. CLAUDE.md says Notion sync looks up `notion-phase-ids.json` by phase number, so starting/completing this Phase 22 would update the input-touch Notion page while local status says sfx-assets. This is not just documentation drift; it corrupts the external tracker and makes later phase 23/24 status ambiguous.
  Recommendation: Update `phases/mvp/notion-phase-ids.json` atomically with this renumbering, including a new/repurposed page mapping for `sfx-assets` and shifted mappings for `input-touch`/`input-advanced`, or choose a non-colliding phase number and update status/README consistently.
- [high] Verification omits the import bootstrap needed for new load() assets (phases/mvp/phase22-sfx-assets.md:51-56)
  The plan switches runtime SFX from generated `AudioStreamWAV` data to `load(res://assets/audio/sfx/<id>.ogg)` and verifies only by running `tests/SfxReceiverTest.tscn`. The repo's own `scripts/run_test.py` documents a separate `--import` bootstrap for new assets/class_names, and `docs/TERRAIN_TILE_RULES.md` records the failure mode: new assets can make runtime `load()` return null before import caches are regenerated. Inference: Ogg assets go through Godot's resource import pipeline as well, so a fresh clone with source packs ignored can pass only if the 14 copied files are committed and the import step has run. The current plan does not make that bootstrap part of the phase verify, so clean-clone CI can still miss or hit null streams depending on local `.godot/imported` state.
  Recommendation: Make the verification sequence explicitly run `python scripts/run_test.py --import` before `SfxReceiverTest`, and add a clean-clone/self-sufficiency check that removes/ignores `assets/audio/kenney_*` and verifies all 14 `assets/audio/sfx/*.ogg` load as `AudioStream`.

Next steps:
- Block Phase 22 until the phase/page-id mapping is made atomic with the renumbering.
- Add import and clean-clone asset checks to the phase plan before implementation proceeds.

## Round 2
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan still does not prove fresh-clone import safety, and one runtime tracker still advertises the pre-fix verifier.

Findings:
- [high] Clean-clone check can pass while reusing local Godot import cache (CandyAnts/phases/mvp/phase22-sfx-assets.md:64-66)
  The proposed self-sufficiency check renames only the ignored Kenney source packs before running `--import` and `SfxReceiverTest`. It does not remove or isolate `.godot/imported`, even though the plan relies on that directory being ignored and regenerated in a fresh clone. Inference: a developer machine with stale imported artifacts can still load `res://assets/audio/sfx/<id>.ogg` through existing cache state, so this check does not prove that committed `.ogg` plus `.import` sidecars are enough for a new checkout. The likely impact is a false green verification followed by null audio streams on CI or another machine.
  Recommendation: Change the required verification to use a real temporary clean worktree/clone, or explicitly move/delete `.godot/imported` and other Godot import cache state before `python scripts/run_test.py --import`, then run `SfxReceiverTest` with the Kenney source packs absent.
- [high] status.json still records the verifier without the import bootstrap (CandyAnts/phases/mvp/status.json:238-242)
  Phase 22 frontmatter uses the fixed command with `python scripts/run_test.py --import`, but the pending runtime tracker entry still says only `python scripts/run_test.py tests/SfxReceiverTest.tscn --audio-driver Dummy`. Since `status.json` is one of the repository's phase trackers, this leaves the Round 1 import-bootstrap fix internally inconsistent: any status-driven dashboard, manual runner, or automation reading the tracker can execute the stale happy-path verifier and miss fresh-clone load failures.
  Recommendation: Run/simulate `python scripts/execute.py mvp sync-status` or manually update the Phase 22 status entry so its `verify` exactly matches the frontmatter import-first verifier.

Next steps:
- Block Phase 22 until the clean-clone check invalidates local Godot import caches or runs in a real clean worktree.
- Synchronize `status.json` with the Phase 22 frontmatter before treating the Round 1 import-bootstrap fix as complete.

## Round 3
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the Round 2 fixes for Phase 22 itself are present, but the phase trackers are still not mutually consistent because Phase 21 is split between two slugs.

Findings:
- [high] Phase 21 still maps to the old Notion slug while local trackers use sfx-receiver (CandyAnts/phases/mvp/notion-phase-ids.json:119)
  `README.md` and `status.json` identify Phase 21 as `sfx-receiver`, but `notion-phase-ids.json` still maps phase 21 to `sound-bgm-sfx`. Inference: any phase-number based Notion sync or status repair that touches completed Phase 21 can update the wrong external phase identity, preserving the same tracker-corruption class that Round 1 blocked for Phase 22. This prevents a clean claim that README, status.json, metadata, and Notion mappings are mutually consistent.
  Recommendation: Rename the phase 21 Notion mapping slug to `sfx-receiver` or explicitly document why that page remains `sound-bgm-sfx` while all local trackers use `sfx-receiver`, then rerun/simulate the sync path to confirm no wrong-page update.

Next steps:
- Fix the Phase 21 tracker mismatch before treating the tracker set as consistent.
- Keep the Phase 22 import-first verifier and cache-invalidating clean-clone check; those Round 2 fixes are now represented in the plan/status entries.

### Round 3 정책 처리
CLAUDE.md plan-stage 3-round cap: Round 3 HIGH 발견 → 즉시 중단, 사용자 보고. 본 HIGH는 phase 21 notion slug(sound-bgm-sfx) ↔ local tracker(sfx-receiver) 불일치 (phase 21에서 유래한 사전 불일치, phase 22 작업과 직교). 사용자 결정 대기.

### Round 3 종결 (사용자 결정)
사용자가 "1줄 수정하고 진행" 선택 (2026-06-08). notion-phase-ids.json phase21 slug: sound-bgm-sfx → sfx-receiver 교체(page_id·완료상태 불변). 3-tracker(notion/status/README/파일명) 일치 확보. plan-stage 종료, 구현 진입.
