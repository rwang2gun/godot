# Phase 7 Adversarial Review

- **실행 시각**: 2026-05-10
- **포커스**: phase 7 plan: input pad + virtual cursor
- **scope**: working-tree
- **base ref**: 7a0487fa35c39ea426f2e4b2414e659347d1b136
- **policy**: plan-stage — HIGH 1건이라도 발견 시 즉시 중단 + 사용자 결정 대기

---

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the phase 7 plan adds pad-facing controls whose critical paths either silently no-op or can target stale stage state.

Findings:
- [high] B-hold restart emits an action nobody handles (CandyAnts/phases/mvp/plans/phase07-plan.md:128-135)
  The plan implements B hold by emitting `GameAction.RESTART_STAGE`, but the current repository has no subscriber for `RESTART_STAGE`; `SkillToolbar` is the only `EventBus.action_triggered` subscriber found and it ignores that action. Inference from the current code: B hold, and likely Ctrl+R, will produce an event but not replay the stage, so the advertised pad restart path silently fails in-game.
  Recommendation: Add an action consumer owned by game flow, e.g. have `SceneFlow` subscribe to `EventBus.action_triggered` and route `GameAction.RESTART_STAGE` to `replay_stage()` or `EventBus.request_replay`, then add an end-to-end test that verifies the active stage actually reloads after B hold.
- [high] D-Pad targeting uses the global ants group despite known stale-stage contamination (CandyAnts/phases/mvp/plans/phase07-plan.md:52)
  The new `CursorTargetingResolver` is specified to call `get_tree().get_nodes_in_group("ants")` and assume that automatically means the active stage. Existing `StageRunner` documents the opposite invariant: the `ants` group is global and queued ants from the previous stage can remain during a 1-frame stage overlap, so it scopes counts to `_spawn_parent`. The new persistent resolver would reintroduce that bug for D-Pad snap targeting, allowing cursor jumps to old-stage ants during replay/next-stage transitions or any queued-free overlap.
  Recommendation: Scope targeting to the active stage subtree instead of the global group, for example by giving the resolver a `current_stage_root`/spawn-parent reference from `SceneFlow` and filtering candidates with `is_instance_valid`, not queued for deletion, and `active_stage_root.is_ancestor_of(ant)`. Add a transition test that presses D-Pad during replay/next-stage replacement and proves old-stage ants are ignored.

Next steps:
- Block phase 7 until restart routing is wired to actual game flow.
- Change ant lookup to an active-stage-scoped query before implementing D-Pad snap targeting.

---

## Round 2 — phase07-plan-v2.md (사용자 작성 v2 + 나의 v2 헤더 in phase07-plan.md 중복)

- **실행 시각**: 2026-05-10
- **포커스**: phase07-plan-v2.md
- **scope**: working-tree
- **base ref**: 7a0487fa35c39ea426f2e4b2414e659347d1b136

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the v2 fixes are parked in a non-canonical duplicate plan, so the repository can still execute the wrong implementation instructions.

Findings:
- [high] v2 replacement is not the canonical phase plan (CandyAnts/phases/mvp/plans/phase07-plan-v2.md:5)
  `phase07-plan-v2.md` says it replaces v1, but the working tree also adds `phases/mvp/plans/phase07-plan.md`, and the task procedure defines `plans/phaseNN-plan.md` as the implementation plan path. That means the safer v2 document can be bypassed by normal phase workflow. This is not just bookkeeping: the canonical `phase07-plan.md` still contains a D-Pad signal-flow block that passes the raw global `ants` group into `CursorTargeting.find_next_ant(...)`, which is exactly the stale-stage contamination class the v2 document is meant to close. Impact: an implementer following the canonical plan can reintroduce old-stage ant targeting during replay/next transitions while believing the v2 blocker was fixed.
  Recommendation: Make `phases/mvp/plans/phase07-plan.md` the single canonical v2 plan, remove `phase07-plan-v2.md`, and eliminate any remaining unfiltered `get_nodes_in_group("ants")` flow text before proceeding.

Next steps:
- Collapse the duplicate plan files into one canonical `plans/phase07-plan.md`.
- Re-run the adversarial plan review against the single canonical plan file.

**Round 2 처리**: 사용자가 작성한 phase07-plan-v2.md를 canonical phase07-plan.md로 이전 + duplicate 파일 삭제. v3 round 재실행.

---

## Round 3 — canonical 단일 plan 파일

- **실행 시각**: 2026-05-10
- **포커스**: phase 7 plan v2 canonical (single file): RESTART_STAGE routing + active-stage ant scoping
- **scope**: working-tree
- **base ref**: 7a0487fa35c39ea426f2e4b2414e659347d1b136

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the v2 plan exists, but the active phase still routes through the older phase definition, so the blocker fixes can be bypassed by the normal workflow.

Findings:
- [high] Active phase metadata still points at the pre-v2 phase definition (CandyAnts/phases/mvp/status.json:75-78)
  `status.json` marks phase 7 in progress using `phase07-input-pad-cursor.md`, while the v2 restart routing and active-stage ant scoping are only in `plans/phase07-plan.md`. The active phase file still describes Pad B as `restart_stage` and D-Pad snap without requiring a `SceneFlow` consumer or active-stage subtree filtering. Inference from the repo workflow: `execute.py next` and the phase status entry continue to surface the older definition, so an implementer can follow the active phase artifact and reproduce the two previously blocking failures: restart emits without actual replay, and D-Pad targeting can use stale global ants.
  Recommendation: Make the active phase artifact unambiguously delegate to the reviewed v2 plan or update `phase07-input-pad-cursor.md` itself with the RESTART_STAGE `SceneFlow` route, active-stage ant filtering invariant, and required end-to-end tests before proceeding.

Next steps:
- Update the active phase definition or status/workflow so there is one canonical v2 source for phase 7.
- Re-run the adversarial review after the active artifact and reviewed plan cannot diverge.

**Round 3 처리**: `phases/mvp/phase07-input-pad-cursor.md`(phase 정의 파일)를 v2로 갱신 — v2 plan을 구현 SoT로 명시 + 핵심 invariants 5개를 inline 정의(SceneFlow RESTART_STAGE 소비, active-stage scoping, SkillToolbar 디바이스 분기 금지, `_emit_cursor_move` 단일 경로, B raw 처리). 검증 테스트 목록도 v2 신규 테스트 포함하도록 갱신. Round 4 재실행.

---

## Round 4 — phase definition aligned

- **실행 시각**: 2026-05-10
- **포커스**: phase 7 v2 round 4: phase definition aligned with v2 plan invariants
- **scope**: working-tree
- **base ref**: 7a0487fa35c39ea426f2e4b2414e659347d1b136

# Codex Adversarial Review

Target: working tree diff
Verdict: approve

Ship assessment: I do not see a defensible blocking issue in round 4. The active phase definition now delegates to the v2 plan and inlines the two previously missing invariants: SceneFlow consumes RESTART_STAGE, and D-Pad targeting must filter to the active stage subtree.

No material findings.

**최종 verdict: approve. Plan-stage clean — 구현으로 진입.**
