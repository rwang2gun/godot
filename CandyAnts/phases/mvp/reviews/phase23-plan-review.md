# Phase 23/24 (BGM) — Plan adversarial review

## Round 1

Target: working tree diff
Verdict: needs-attention

No-ship: the plan/status change creates tracker drift and leaves the riskiest BGM behaviors either unverified or only tested through synthetic seams.

Findings:
- [high] Phase numbers now collide with existing tracker mappings (phases/mvp/status.json:250-262)
  status.json now declares phases 23 and 24 as bgm-receiver/bgm-assets, but the existing tracker SoTs still map 23 to input-touch and 24 to input-advanced: README lines 191-192, metadata notes, and notion-phase-ids lines 129-137. Any sync/status automation keyed by phase id can update the wrong Notion pages or make input work appear replaced by BGM work. This is not just planned future cleanup because status.json has already been changed to the new IDs while the mapping files remain stale.
  Recommendation: Make the tracker update atomic with the status change: update README, metadata post_mvp_phase_range/notes, and notion-phase-ids for bgm phases and shifted input phases, or remove the status.json phase additions until the mapping is resolved.
- [high] Phase 23 claims runtime silence but the verification plan cannot prove it (phases/mvp/phase23-bgm-receiver.md:33-46)
  The phase explicitly relies on missing BGM files causing _streams to be empty and runtime silence, but the only planned logic test injects synthetic streams before exercising playback. That means accidental committed/local assets, stale imports, or a path typo masked by injection would not fail Phase 23, while Phase 24 assumes the exact precondition that Phase 23 had no real streams.
  Recommendation: Before synthetic injection, add a Phase 23 assertion that BgmPlayer._streams is empty and that no tracked assets/audio/bgm/menu.ogg or gameplay.ogg exists; alternatively stop claiming silence and change Phase 24 to not depend on that state.
- [medium] SceneFlow/autoload wiring is not actually covered by the advertised verify command (phases/mvp/phase23-bgm-receiver.md:4)
  The frontmatter verify command runs only BgmReceiverTest, while the plan's only SceneFlow regression coverage is listed separately in prose. A repo scanner that finds bgm_request.emit literals can pass even if emits are inserted in the wrong transition point, emitted before BgmPlayer subscribes, or not reached by real SceneFlow transitions.
  Recommendation: Put the SceneFlow regression tests into the phase verify command, or add a dedicated BgmSceneFlow test that instantiates Main/SceneFlow, observes bgm_request emissions through real transitions, and asserts BgmPlayer is subscribed before boot emits.
- [medium] Fade/idempotency tests ignore rapid re-entry and overlapping tween failure modes (phases/mvp/phase23-bgm-receiver.md:35-37)
  The design depends on 0.4s crossfades and claims the two-player toggle avoids race conditions, but the planned tests avoid waiting for fades and only check synchronous seams. Rapid menu->gameplay->menu requests can leave old tweens fighting new ones or stopping/fading the wrong player after state has already changed.
  Recommendation: Specify per-player tween tracking and cancellation before starting a new fade, then add tests that emit rapid alternating tracks, await longer than the fade duration, and assert only the current track's player is playing/audible while stale players are stopped or silent.

Next steps:
- Block shipment until tracker IDs are made atomic and the Phase 23/24 test plan proves the asset boundary, real SceneFlow wiring, and overlapping fade behavior.

## Round 2

Target: working tree diff
Verdict: needs-attention

No-ship: Round 1 is not fully closed. The SceneFlow coverage is internally inconsistent with the Phase 23 no-asset boundary, and the runtime tracker still advertises the stale verifier that skips SceneFlow entirely.

Findings:
- [high] BgmSceneFlowTest contract conflicts with Phase 23's empty-stream boundary (phases/mvp/phase23-bgm-receiver.md:50)
  Phase 23 now requires `_streams.is_empty()` and missing menu/gameplay.ogg before synthetic injection, but `BgmSceneFlowTest` is specified to instantiate Main.tscn and assert menu idempotency via `play_generation == 1` without seeding synthetic streams first. Since `play_generation` increases only on actual playback/restart, a real SceneFlow boot with empty `_streams` cannot both remain runtime-silent and produce one generation. Implementers will get an impossible verifier, inject streams in an unstated way that masks the no-stream boot path, or make `play_generation` increment for skipped playback.
  Recommendation: Make BgmSceneFlowTest explicit — assert real boot/menu emits are graceful with empty `_streams` and no playback generation, then seed synthetic streams before any generation/idempotency assertions; or move all `play_generation` assertions back to BgmReceiverTest and keep SceneFlow focused on real emit ordering/mapping.
- [medium] status.json still drops the new SceneFlow verifier (phases/mvp/status.json:253)
  The phase file frontmatter includes both BgmReceiverTest and BgmSceneFlowTest, but the status tracker entry for phase 23 records only BgmReceiverTest. A status-driven dashboard/manual runner can green-light the phase without exercising the real SceneFlow wiring.
  Recommendation: Run/simulate `python scripts/execute.py mvp sync-status` or update the phase 23 verify field so it matches the frontmatter, including tests/BgmSceneFlowTest.tscn.

Next steps:
- Fix the Phase 23 SceneFlow test contract so it is compatible with intentional no-asset silence.
- Synchronize status.json with phase frontmatter before treating Round 1 SceneFlow coverage as resolved.

## Round 3

Target: working tree diff
Verdict: needs-attention (no HIGH/CRITICAL — MEDIUM only → resolved in-plan per CLAUDE.md plan-stage policy)

No remaining HIGH/CRITICAL found in the Round 2 fixes themselves, but the BGM plan still should not ship as-is because Phase 24 makes the new SceneFlow test contract stale and then omits it from verification.

Findings:
- [medium] Phase 24 leaves BgmSceneFlowTest incompatible with the asset-present state (phases/mvp/phase24-bgm-assets.md:25)
  Phase 23 defines BgmSceneFlowTest as an empty-_streams/무음 test asserting boot emits do not update current_track and play_generation remains 0. Phase 24 adds real menu/gameplay streams (_streams populated) but says BgmSceneFlowTest is unchanged. After assets land, that SceneFlow test either fails if run, or stays excluded from Phase 24 verification — so real audible SceneFlow boot/transition wiring is uncovered in the configuration users actually get.
  Recommendation: In Phase 24, explicitly update/split BgmSceneFlowTest — keep the empty-stream boundary for Phase 23 only, add an asset-present SceneFlow assertion for menu/gameplay boot and transitions with play_generation/playback expectations, and include it in the Phase 24 verify command.

Next steps:
- Revise Phase 24 test plan and verify command before treating the BGM plan as final.

### Resolution (in-plan, Round 3 MEDIUM)
Phase 24 updated: (1) verify command now includes `tests/BgmSceneFlowTest.tscn`; (2) new change-target — BgmSceneFlowTest's empty-stream boundary assertions (phase23 item 11: `current_track` 미갱신, `play_generation==0`) are **inverted to asset-present playback assertions** (boot "menu" → `current_track=="menu"` + `play_generation` 증가; menu→gameplay 전이 시 갱신), mirroring the BgmReceiverTest (c) boundary inversion. No HIGH/CRITICAL remained → plan stage concluded (CLAUDE.md: MEDIUM/LOW만 남으면 plan 내 처리로 종결).
