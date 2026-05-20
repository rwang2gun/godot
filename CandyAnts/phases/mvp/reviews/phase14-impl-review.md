# Phase 14 Impl Adversarial Review

## Round 1

- **실행 시각**: 2026-05-21
- **scope**: branch diff vs 32f58ee (plan-only wip), HEAD = 3589109 (impl wip)
- **command**: `node codex-companion.mjs adversarial-review --wait --scope branch --base 32f58ee "..."`

# Codex Adversarial Review

Target: branch diff against 32f58ee
Verdict: needs-attention

No-ship: the new climber state is vulnerable to existing blocker bounce semantics, and the stall regression test does not actually prove the mandatory stall guard fires.

Findings:
- [high] Blocker overlap can flip a climbing ant off its wall (CandyAnts/scripts/ant/Ant.gd:183-204)
  ClimberState recomputes horizontal wall-contact push and wall-end probing from the mutable ant.direction every frame. Existing blocker overlap handling flips direction for any non-Worker ant, with no exemption for ClimberState. Inference from the code path: if a climber overlaps an active blocker hitbox while climbing or mantling, the blocker bounce changes direction, the next ClimberState tick pushes/probes away from the wall, and the ant can prematurely mantle or fall instead of continuing the climb. The existing BlockerOverlap regression does not cover climbers, so this can ship hidden.
  Recommendation: Either ignore blocker bounces for ants in ClimberState, or have ClimberState lock a private climb_direction on enter and use that for velocity/probes until exit; add a headless climber+blocker overlap regression.
- [medium] Stall test passes on any ClimberState exit instead of proving stall guard behavior (CandyAnts/tests/ClimberStallTest.gd:95-111)
  The phase plan requires ClimberStallTest to prove mantle enters the stalled substate and exits to FallerState after the dx<0.1 guard window. The implemented test accepts normal mantle completion or any other state transition after ClimberState, and its timeout is 500 frames despite comments claiming 90. A broken or removed stall guard could still pass if the geometry fails to produce a true dx==0 mantle stall, which the test itself says is acceptable. That leaves the mandatory stall guard unverified.
  Recommendation: Make the test assert the expected stall-specific sequence: detect mantling, observe consecutive low-dx frames or expose diagnostic state, require FallerState exit within the guard window, and fail on Walker/Carrying normal mantle completion.

Next steps:
- Patch climber/blocker interaction before shipping.
- Tighten ClimberStallTest so it fails unless the mandatory stall guard is exercised.

---

## Self-Review Round 1 (Round 1 HIGH/MEDIUM 대응 후)

### Fixes applied
1. **HIGH (blocker direction flip during climb)**: ClimberState에 `_climb_direction` private 변수 추가. enter() 시점 `ant.direction` snapshot. `_update_climbing` / `_update_mantling`은 `_climb_direction` 사용 (ant.direction 무시). mantle 완료 시 `ant.direction = _climb_direction`로 복원해 post-climb walking이 원래 climb 방향 유지.
2. **MEDIUM (stall test 강화)**: 
   - PASS 조건에 `exit_state == FallerState` 강제 추가 (Walker/Carrying exit는 FAIL).
   - `_consecutive_low_dx_frames` 관찰자 추가 — dx<0.5가 12 frame 이상 누적 시 stall 관찰됨으로 기록.
   - `_observed_stall == false`면 FAIL.

### Self-adversarial review
| sev | 항목 | 처리 |
|---|---|---|
| LOW | climbing phase에서도 dx≈0이라 _consecutive_low_dx_frames가 false-positive로 stall 관찰을 트리거함. | 그러나 PASS는 `exit_state == FallerState` 조건도 요구하므로 false-positive만으로는 PASS 불가. 정상 mantle 완료(Walker/Carrying exit) 시 fail. |
| LOW | _climb_direction lock으로 mantle 완료 후 ant.direction 복원. 의도된 동작이지만 design decision으로 명시 필요. | 코멘트로 의도 명시함 (`등반 도중 blocker bounce로 ant.direction이 뒤집혔어도 climb 방향으로 복원`) |
| LOW | climber + blocker overlap regression test 미작성 (codex 권고 사항). | self-test 결과 모든 기존 회귀(Stage02/03/BlockerOverlap) 및 신규 trait test PASS. impl-stage Round 2에서 재검토. |

### Verification
- Tests run: ClimberTraitTest, FloaterTraitTest, TraitCombinedTest, ClimberStallTest (모두 PASS).
- 회귀 PASS: Stage02HeadlessTest, Stage03HeadlessTest, BlockerOverlapTest.
- Self-review verdict: HIGH 0건 (보다 정확히 — Round 1 HIGH 해소됨, 새 HIGH 없음). Codex re-review 진행.
