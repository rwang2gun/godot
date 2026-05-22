# Phase 15 Plan Review — codex adversarial-review

**Target plan**: [phases/mvp/plans/phase15-plan.md](../plans/phase15-plan.md) v1
**Reviewer**: codex adversarial-review (background bvq1i8sg5)
**Date**: 2026-05-22
**Plan-stage policy**: CLAUDE.md — HIGH/CRITICAL 1건이라도 발견 시 **즉시 중단 + 사용자 결정** (자동 재리뷰 금지)

---

## Round 1

```
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the plan leaves core settlement outcomes dependent on unproven timing/order assumptions and documents a stuck invariant that does not match the existing StageRunner timeout behavior.

Findings:
- [high] 100% settlement stuck test does not match StageRunner fail semantics (CandyAnts/phases/mvp/plans/phase15-plan.md:74)
  The plan asserts that 100% settlement produces no clear and no fail, and the proposed test only waits 60 seconds. Existing StageRunner always emits stage_failed on time_out when _time_left reaches 0, and the dev settle stage is planned with time_limit=180. Existing _living_ant_count also counts all ants in the stage group, so SettledState ants will suppress the no_more_ants fail path while still allowing the later timeout fail. The result is not the documented permanent stuck/restart lane; it is 'stuck until timeout', and the proposed 60s test would miss that mismatch.
  Recommendation: Decide the intended contract explicitly: either document/assert 'stuck until time_out' and extend SettlementHundredPercentStuckTest past time_limit, or add a real settlement terminal policy that prevents timeout/fail if permanent stuck is intentional.
- [medium] Carrying-over-settlement priority depends on Area2D signal ordering (CandyAnts/phases/mvp/plans/phase15-plan.md:177-190)
  D8 says carrying must win over settlement, but the planned SettlementMarker implementation only checks the current ant.has_candy value inside body_entered. If a distributor enters Candy and SettlementMarker overlaps in the same physics step, the outcome depends on which Area2D body_entered callback runs first: Candy first sets has_candy and settlement is ignored; SettlementMarker first sees has_candy=false and permanently settles the ant before candy pickup. The proposed carrying-priority test starts after candy pickup, so it does not cover this race.
  Recommendation: Make the priority deterministic: forbid/validate settlement markers overlapping candy pickup areas, or defer settlement evaluation until after the physics step and re-check has_candy/current state. Add a regression where Candy and SettlementMarker are both entered in the same frame.
- [medium] Transfer whitelist has two sources of truth that can silently diverge (CandyAnts/phases/mvp/plans/phase15-plan.md:169-204)
  The plan calls SettledState.TRANSFER_WHITELIST the code SoT, but SettlementMarker also exports an independent default transfer_whitelist and _transfer_traits iterates that exported copy. The plan even says future traits must be registered in both places. That creates a silent scene/resource drift path: one stage can transfer a trait the state policy does not allow, or fail to transfer a newly allowed trait, with no validation failure.
  Recommendation: Use a single source of truth by defaulting SettlementMarker to SettledState.TRANSFER_WHITELIST at runtime, or add an explicit override flag plus validation that exported scene values match the SoT unless override is intentional and tested.

Next steps:
- Update the phase 15 plan before implementation to resolve the timeout/stuck contract and same-frame carrying priority race.
- Add tests that exercise same-frame Candy/SettlementMarker entry and run the 100% settlement scenario beyond the configured time limit.
```

---

## 정리

**verdict**: needs-attention (HIGH 1 + MEDIUM 2)

### Findings 요약

| # | severity | 항목 | 핵심 문제 | 사용자 결정 필요 사항 |
|---|---|---|---|---|
| F1 | **HIGH** | 100% 정착 stuck contract mismatch | plan은 "fail/clear 미발화 = 영구 stuck"이라 명세했으나 실제 StageRunner는 `time_out` 시 `stage_failed` 발화. dev settle stage `time_limit=180`이므로 "stuck until timeout"이 실제 동작 | **§0.7.5 정책 재해석**: A안 "stuck-until-timeout (timeout fail 수용)" vs B안 "정착 종료 후 timeout fail 차단" |
| F2 | MEDIUM | Candy + SettlementMarker 동일 frame 진입 race | Area2D body_entered callback 순서에 따라 분배자 carrying vs settle 결과 비결정. plan v1 carrying-priority test는 race 미커버 | level design 검증 (settlement_cell ≠ candy_cell) + 또는 deferred 검증 |
| F3 | MEDIUM | TRANSFER_WHITELIST 2-SoT (SettledState const + SettlementMarker @export) | scene-side 값과 code SoT가 silent drift 가능 | single SoT (runtime resolve) vs 명시적 override + validation |

### Plan-stage 정책 적용

CLAUDE.md:
> Plan stage (Step 2~3, plan 리뷰): codex 리뷰에서 **CRITICAL/HIGH가 1건이라도 나오면 작업을 즉시 중단**하고 사용자에게 보고한다. 자동 재리뷰 사이클을 돌리지 않는다. 사용자가 수정 방향·범위·취소 여부를 결정한다.

→ **HIGH 1건(F1) 발견 → 작업 중단. plan v2 자동 작성 금지. 사용자 결정 대기.**

(MEDIUM 2건은 HIGH 결정 이후 plan v2에 inline으로 처리 가능)

---

**작성**: 2026-05-22 / plan v1 review Round 1 (codex adversarial-review)

---

## Round 2 (plan v2 + PROPOSAL §0.7.5 갱신본)

```
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: v2 still contains contradictory F1 contract text, and the PROPOSAL update violates its own §0.2 vocabulary policy in the newly added §0.7.5 text.

Findings:
- [medium] Top-level v2 summary still states the old no-fail contract (CandyAnts/phases/mvp/plans/phase15-plan.md:29)
  Line 29 says the 100% settlement case has `fail 미발화 (§0.7.5)`, but v2's stated fix is the opposite: stuck-until-timeout with `stage_failed("time_out")`. This leaves two competing contracts in the plan. An implementer or test writer following the summary can preserve the Round 1 F1 behavior while later sections expect timeout failure, so the F1 resolution is not cleanly specified.
  Recommendation: Rewrite the summary to say immediate `no_more_ants`/clear do not fire, but `time_out` failure is expected at the configured time limit. Remove the blanket `fail 미발화` wording.
- [medium] §0.7.5 update violates the proposal's tone vocabulary policy (CandyAnts/docs/PHASE_14_OPTION_B_PROPOSAL.md:43-45)
  §0.2 says new phase specs, code, and docs must use the allowed vocabulary: 정착, 임무 완수, 사탕 손실, 탈락. The updated §0.7.5 introduces `stuck`, `fail`, `time over`, `stage_stuck`, `saved/lost`, and `no_more_ants` as user-facing policy wording. This is not just style: the proposal is the SoT for later UI/result wording, so preserving these terms can leak forbidden failure language into implementation or polish decisions.
  Recommendation: Restate §0.7.5 using the §0.2 vocabulary. Keep internal signal names only if clearly marked as code identifiers, and phrase the player-facing outcome as timeout-driven 사탕 손실/탈락 rather than `fail` or `stuck`.
```

### 정리

**verdict**: needs-attention (HIGH 0 + MEDIUM 2). plan-stage 정책상 HIGH 1건도 없으므로 자동 중단 사유 없음 — MEDIUM은 plan v3에 inline 처리.

| # | severity | 항목 | 해소 방식 |
|---|---|---|---|
| F-R2-M1 | MEDIUM | plan v2 line 29 "fail 미발화" 잔존 | plan v3 §0 한 줄 요약 갱신 — `no_more_ants`/clear 미발화 + `time_out` fail은 발화 명시 |
| F-R2-M2 | MEDIUM | PROPOSAL §0.7.5 톤 폴리시 위반 | PROPOSAL §0.7.5 재작성 — §0.2 어휘 정책(정착·임무 완수·사탕 손실·탈락)으로 평문 정리. 코드 식별자(`stage_failed`/`_time_left`/`saved_pieces` 등)는 backtick 처리로 명시 마킹 |

**작성**: 2026-05-22 / plan v2 review Round 2 (codex adversarial-review)
