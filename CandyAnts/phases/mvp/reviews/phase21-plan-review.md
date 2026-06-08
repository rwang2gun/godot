# Phase 21 — Plan Adversarial Review

## Round 1
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan’s receiver/test scope is not grounded in the actual SFX emit surface, and its dummy-audio claim is not verified by the stated harness.

Findings:
- [high] Receiver coverage is based on a false emit-site inventory (CandyAnts/phases/mvp/phase21-sfx-receiver.md:17-59)
  The plan says there are "emit 14곳" and then proposes only checking that those 14 ids exist in SFX_SPECS plus rerunning the old SfxRequestEmitTest. The repo currently has 22 sfx_request.emit call sites, and the existing SfxRequestEmitTest only enumerates the original 8 sites. Current untested emit sites include DroppedCandy.gd:26, AdriftState.gd:44, DeadState.gd:23/27, FloaterSkill.gd:41, StageIntroCard.gd:121/326/333/487, StageDialog.gd:94/112/113/162, and StageSelect.gd:69. A receiver could ship with the hardcoded 14-id table while regressions in these emit sites remain invisible, especially around duplicate ids and the locked normalization.
  Recommendation: Replace the hardcoded/legacy coverage with a repo-derived assertion: scan scripts for every sfx_request.emit literal, normalize the intended locked id, assert every emitted id maps to SFX_SPECS, and update SfxRequestEmitTest or the new receiver test to freeze all current emit sites, not just the old 8.
- [medium] Dummy-audio requirement is not exercised by the stated verify command (CandyAnts/phases/mvp/phase21-sfx-receiver.md:28-56)
  The implementation requirement says play() must pass under headless/dummy audio, but the verification only runs `python scripts/run_test.py tests/SfxReceiverTest.tscn`. The harness command shown in scripts/run_test.py uses `--headless --path ... --quit-after ... <scene>` and does not force a dummy audio driver or assert on audio-driver stderr. Inference: a green SfxReceiverTest would prove only the default headless path for the local Godot binary, not the explicit dummy-audio condition the plan claims to support.
  Recommendation: Add an explicit dummy-audio verification path to the plan and harness, and make the test fail on Godot audio/script errors from stderr. Keep the normal headless run, but do not treat it as proof of dummy-driver compatibility.

Next steps:
- Revise Phase 21 before implementation: derive SFX ids/sites from the repository and add an explicit dummy-audio test mode.

## Round 2
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the revised repo-derived coverage can still greenlight SFX emits that the receiver will silently drop at runtime.

Findings:
- [high] Repo scan normalizes away invalid emitted IDs before proving the receiver can play them (CandyAnts/phases/mvp/phase21-sfx-receiver.md:39-41)
  The planned test extracts raw `sfx_request.emit(&"...")` literals but then strips the `sfx:` prefix before asserting `SfxPlayer.SFX_SPECS` coverage, and the only raw-prefix regression check is hardcoded to `StageSelect.gd`. Inference from the same plan: `SfxPlayer` specs are keyed by the normalized 14 ids and unmapped ids only `push_warning`/skip, so any prefixed emit outside `StageSelect.gd` such as `&"sfx:locked"` would pass the repo-derived coverage as `locked` while production emits the raw prefixed id and gets no sound. This breaks the stated “new emit site added 자동 감지” guarantee and creates a silent user-visible miss.
  Recommendation: Make the test fail on raw extracted ids with `sfx:` before any normalization, across all scanned scripts, or explicitly require runtime normalization in `SfxPlayer._on_sfx_request` and test playback using the raw extracted ids. Do not limit the raw-prefix regression to `StageSelect.gd`.

Next steps:
- Revise the receiver test contract so raw emit ids are validated globally before normalization, then re-run the plan review against the updated diff.

## Round 3
# Codex Adversarial Review

Target: working tree diff
Verdict: approve

No-ship finding not supported at CRITICAL/HIGH. The Round 2 masking issue is addressed: SfxPlayer is specified to use raw ids with no normalization, SFX_SPECS is keyed by clean ids, the test fails globally on any colon/prefix before coverage checks, and playback is exercised with the raw extracted ids.

No material findings.
