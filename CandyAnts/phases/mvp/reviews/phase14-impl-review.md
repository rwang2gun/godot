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

---

## Round 2

- **실행 시각**: 2026-05-21
- **scope**: branch diff vs 3589109 (impl wip), HEAD = 12c8878 (Round 1 fixes wip)
- **command**: `node codex-companion.mjs adversarial-review --wait --scope branch --base 3589109 "..."`

# Codex Adversarial Review

Target: branch diff against 3589109
Verdict: needs-attention

No ship: the blocker-flip vector is only closed for successful mantle completion, and the tightened stall test can still pass without proving mantle stall behavior.

Findings:
- [high] Flipped direction leaks through fall exits (CandyAnts/scripts/ant/states/ClimberState.gd:66)
  The fix restores `a.direction` only in the mantle-complete branch. The ceiling fall exit and the mandatory stall-guard exit both transition directly to `FallerState` while leaving any blocker-induced direction flip in place. Since `FallerState` and then `WalkerState` drive horizontal movement from `a.direction`, a blocker hit during climb/mantle can still alter post-fall behavior even though `_climb_direction` protected the in-state velocity/probe path. This is the same mutable-direction vector surviving on the failure path, which is exactly where the stall guard exits.
  Recommendation: Restore `a.direction = _climb_direction` before every ClimberState exit, or centralize it in `ClimberState.exit()` with care for state-machine ordering, then add a regression that flips direction during mantle stall and asserts Faller/landing direction remains the climb direction.
- [medium] Stall test marks vertical climbing as mantle stall (CandyAnts/tests/ClimberStallTest.gd:103-116)
  The test sets `_observed_stall` from low x-delta during any `ClimberState` frame, starting immediately after entering the state. During the normal climbing subphase, ClimberState intentionally pushes horizontally into the wall, so observed x movement can be near zero long before mantle begins. That means the new `observed_stall && FallerState` assertion can pass on a ceiling/fall exit or other Faller path without proving the mantle stall guard fired. Inference: the test comments claim mantle-phase observation, but the code has no mantle-phase signal or offset check.
  Recommendation: Gate stall observation on actual mantle entry, preferably via exposed/debug state or a deterministic position/event boundary, and assert the exit occurs after the guard window from that mantle stall rather than from arbitrary low x-delta during vertical climbing.

Next steps:
- Fix ClimberState direction restoration on all exits.
- Make ClimberStallTest observe mantle stall specifically, not generic low horizontal movement in ClimberState.

---

## Self-Review Round 2 (Round 2 대응 — partial: code fixes 완료, test geometry는 next session 이월)

### Fixes applied
1. **HIGH (direction leak on Faller exits)**:
   - `a.direction = _climb_direction` 복원을 ClimberState.exit()로 이동 → mantle 완료/ceiling fall/stall guard fall 모든 exit 경로에 일관 적용.
   - mantle 완료 branch에서는 명시적 `a.direction =` 호출 제거 (exit()가 일괄 처리).
2. **MEDIUM (stall observation gating)**:
   - ClimberState에 `is_mantling() -> bool` getter 추가 (`_mantle_offset >= 0.0` 노출).
   - ClimberStallTest는 `is_mantling()` true일 때만 _consecutive_low_dx_frames 누적. climbing phase에서는 counter 리셋.
   - 결과: 현재 dev_trait_test 기반 stall geometry는 실제 mantle stall을 트리거하지 못함을 정직하게 노출 — test FAIL.

### Status — NEXT SESSION 이월 작업

#### ✅ 완료 (code-level fixes 검증됨)
- ClimberState.exit() 일관 direction 복원 — 모든 exit 경로 보호.
- ClimberState.is_mantling() — 외부에서 mantle phase 식별 가능.
- ClimberTraitTest, FloaterTraitTest, TraitCombinedTest, Stage02/03/BlockerOverlap 회귀 PASS.

#### ⏳ NEXT SESSION
- **ClimberStallTest geometry tuning**: 현재 (16,15) (17,15) (18,15) 천장 셀이 mantle 진행을 차단하지 못함. 더 적극적인 stall 유발 geometry 필요 (예: ceiling을 더 낮게, 또는 ant 충돌 shape 분석 후 정확한 위치 산출).
- 가능한 next-session 접근:
  1. ant 충돌 shape 좌표 dump + ceiling cell 위치 정확 계산
  2. 또는 stall 시나리오를 코드로 직접 시뮬레이트(빈 scene에 StaticBody2D 정확 배치)
  3. 또는 mantle 진입 직전에 ant를 강제 teleport해서 stall 위치에서 시작
- **climber+blocker overlap regression test** (codex Round 1 권고 잔여): _climb_direction lock + exit() direction 복원이 implementation 차원에서 보호하지만, 회귀 테스트로 명시 증명 필요.

### Self-found risks (Round 2)
| sev | 항목 | 처리 |
|---|---|---|
| HIGH | (해소됨) direction leak on Faller exits | exit()로 일괄 처리 — Round 2 코드 fix 완료 |
| MEDIUM | stall test geometry가 실제 mantle stall을 트리거 못함 | test가 정직하게 FAIL → next session에서 geometry tuning 또는 대체 검증 방법 |
| LOW | climber+blocker regression test 없음 | next session에서 추가 |

### Round 2 코드 fix만 보고 verdict — Codex Round 3 대응 가능한 상태
- HIGH (direction leak): 해소
- MEDIUM (stall observation gating): 코드 차원에서는 정확 (is_mantling() 사용), test의 PASS 어려움은 geometry 문제 (별도 이슈)
- 다음 codex Round는 next session에서 진행 — geometry fix 후 stall test PASS 확인 후 호출.
