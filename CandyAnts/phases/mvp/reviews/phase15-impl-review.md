# Phase 15 Impl Review — codex adversarial-review

**Target**: impl 변경 (plan v3 §9 체크리스트 13~21 항목 + 신규 회귀 가드)
**Plan**: [phases/mvp/plans/phase15-plan.md](../plans/phase15-plan.md) v3
**Date**: 2026-05-22
**Impl-stage policy**: CLAUDE.md — HIGH/CRITICAL 1건이라도 발견 시 반드시 수정. 자체 리뷰 → codex 재리뷰 사이클 clean까지 반복.

---

## Round 1

```
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the terminal state is still treated as live/targetable, which lets players mutate the settled distributor after settlement, and the advertised layout contract is not actually represented in StageLayoutData.

Findings:
- [high] Settled ants remain alive for skill targeting, allowing post-settlement trait injection (CandyAnts/scripts/ant/Ant.gd:143-148)
  `Ant.is_alive()` still returns true for every state except `SavedState` and `DeadState`. Because `FloaterSkill.can_apply()` only checks `is_alive()` plus duplicate trait, a settled distributor can receive `floater` after entering terminal `SettledState`. `SettlementMarker._transfer_traits()` later reads `_distributor.has_trait(&"floater")`, so the player can settle first, then spend/apply floater on the stationary distributor and transfer it to followers. That undermines the terminal contract and changes puzzle timing/inventory semantics in a way the new headless transfer test does not cover because it applies floater before settlement.
  Recommendation: Make the terminal contract explicit in code: either have `is_alive()` return false for `SettledState`, or add skill-targeting guards so no skill can be applied to `SettledState`. Add a regression that settles a distributor without floater, attempts `FloaterSkill.can_apply/apply`, and verifies no post-settlement transfer becomes possible.
- [medium] `settlement_cell` is serialized in new layouts but missing from `StageLayoutData` (CandyAnts/scripts/core/StageLayoutData.gd:3-11)
  The new `.tres` layout resources write `settlement_cell = Vector2i(...)`, and the phase plan says `StageLayoutData.gd` should export that field, but the actual script still only exports `cell_size`, platform/tile fields, home/candy/camera, spawn flags, and theme. In Godot this leaves the serialized property without a script-backed field, so consumers cannot reliably read `layout.settlement_cell` and the resources can load with invalid/ignored-property noise. The current dev scenes mask this by hardcoding marker positions, but the data contract is broken for editor use and future stages.
  Recommendation: Add `@export var settlement_cell: Vector2i = Vector2i(-1, -1)` to `StageLayoutData.gd`, then add a small guard test/load check that the three new layouts expose the expected `settlement_cell` values.

Next steps:
- Block shipping until settled ants are no longer mutable via normal skill application or the post-settlement mutation behavior is explicitly specified and tested.
- Fix the `StageLayoutData` schema before relying on the new layout resources as source data.
```

### 정리

**verdict**: needs-attention (HIGH 1 + MEDIUM 1)

| # | severity | 항목 | 수정 |
|---|---|---|---|
| F-impl-1 | **HIGH** | settled ant `is_alive()=true` → 정착 후 trait 부여 + 후속 transfer 누출 | `Ant.is_alive()`에 `SettledState` 포함 → false 반환 (단일 진입점 차단). 회귀 가드 `tests/SettledImmuneSkillTest.tscn/gd` 신설 |
| F-impl-2 | MEDIUM | `settlement_cell`이 layout `.tres`에 직렬화되지만 `StageLayoutData.gd`에 @export 누락 (impl 초기 Edit 실패로 누락 잔존) | `StageLayoutData.gd`에 `@export var settlement_cell: Vector2i = Vector2i(-1, -1)` 추가. `tests/test_StageLayoutData.gd` TDD guard 스텁 추가 |

### Self-Review Round 1 (after fixes)

- 본인 적대적 검토 5축 (correctness/readability/architecture/security/performance):
  - is_alive() 변경 사이드이펙트 검토 — CursorTargeting alive 필터(settled 타겟팅 차단, 의도 ✓), 4 skill can_apply 모두 SettledState 거부 ✓ (Climber/Blocker/Builder는 Walker/Carrying만 분기, Floater는 is_alive 검사, Distributor는 is_alive + 상태 검사), ScoreSystem 4-카운터 정합 (정착은 카운터 무영향) ✓
  - settlement_cell 기본값 (-1, -1)이 기존 layout(.tres가 미명시)에서 안전한 센티넬 — SettlementMarker 미배치 stage에는 영향 없음 ✓
  - SettlementMarker.gd의 await physics_frame 이후 ant 상태 변동 가드 (is_instance_valid + state 재검사) ✓
  - F-impl-1 회귀 가드 (SettledImmuneSkillTest) 시나리오 검증 — 분배자 정착(floater 미부여) → FloaterSkill.can_apply false 확인 + 후속 walker 미전이 ✓
- 자체 리뷰 결과: HIGH 0건. codex 재리뷰 진입 가능.

### Verification (impl Round 1 fix + 자체 리뷰 결과)

```
DistributorSettleTest                  PASS frame=257
SettlementTraitTransferTest            PASS frame=343 (receiver has_floater=true has_distributor=false)
SettlementSameFrameRaceTest            PASS frame=288 (saw_carrying=true marker_distributor=null)
SettlementHundredPercentStuckTest      PASS frame=901 (timeout_fired=1 cleared=0, time_left=0.0 정확)
SettledImmuneSkillTest (신규 회귀 가드)  PASS frame=601 (settled_immune=true no_transfer_leak=true)
```

회귀 (phase 1~14):
```
Stage02HeadlessTest                    PASS (Phase3Test)
Stage03HeadlessTest                    PASS (Phase4Test §D-1 alternation + §D-2 carrying blocker 거부)
BlockerOverlapTest                     PASS (§B-1~B-8 모두)
ClimberTraitTest                       PASS frame=759 dx=37.16
FloaterTraitTest                       PASS mean_dvy=4.50 (threshold=6.00)
ClimberBlockerOverlapStallTest         PASS (stall guard + direction 복구)
```

**작성**: 2026-05-22 / impl review Round 1 (codex adversarial-review)

---

## Round 2

```
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the settled-ant terminal fix blocks post-settlement mutation, but the targeting path still lets that visible terminal ant win closest-target selection and cancel valid nearby skill applications.

Findings:
- [medium] Settled ants can shadow valid skill targets near the settlement marker (CandyAnts/scripts/ui/SkillToolbar.gd:169-180)
  `Ant.is_alive()` now correctly returns false for `SettledState`, but `SkillToolbar._find_closest_ant()` still picks the nearest ant without filtering dead/terminal or skill-applicable targets. `_try_assign()` then validates only that single chosen ant and clears the pending skill when `can_apply()` fails. Because the settled distributor remains visible and stationary at the marker, followers passing through the same small area can be impossible or unreliable to target: a click intended for a valid follower can select the settled distributor first, fail `can_apply()`, and cancel the skill. This is an inference from the targeting flow and the settlement design; it is especially plausible at the marker where the distributor and receivers overlap spatially.
  Recommendation: Make target selection skill-aware: instantiate/resolve the pending skill before choosing a target and choose the closest ant for which `skill.can_apply(ant)` is true. At minimum, skip `not a.is_alive()` in `_find_closest_ant()`. Add a regression with a settled distributor and a live follower both inside `CLICK_RADIUS`, asserting the follower receives the skill and selection is not cleared by the settled ant.
```

### 정리

**verdict**: needs-attention (HIGH 0 + MEDIUM 1)

| # | severity | 항목 | 수정 |
|---|---|---|---|
| F-impl-R2-1 | MEDIUM | `SkillToolbar._find_closest_ant`이 SettledState ant도 closest 후보로 선택 → 클릭 의도 충돌 | `SkillToolbar._find_closest_ant`에 `not a.is_alive()` 필터 추가. 회귀 가드 `tests/SkillToolbarSettledTargetFilterTest.tscn/gd` 신설 (settled + live walker 두 ant CLICK_RADIUS 내 + live 선택 단언) |

### Self-Review Round 2 (after fix)

- 본인 적대적 검토:
  - `_find_closest_ant` 필터 추가가 phase 1~14 SkillToolbar 회귀 — 영향 없음 (기존 walker/carrying ant는 is_alive true 유지) ✓
  - is_alive() 사용처 영향 — CursorTargeting/skill can_apply는 이미 is_alive 검사하므로 일관성 ↑ ✓
  - SettlementMarker._transfer_traits의 receiver는 same-frame race 처리에서 walker/carrying만 통과 → settled ant가 receiver로 들어올 가능성 0 ✓
- 자체 리뷰 결과: HIGH 0건. codex 재리뷰 진입 가능.

### Verification (impl Round 2 fix)

```
SkillToolbarSettledTargetFilterTest    PASS — _find_closest_ant skipped settled ant, picked live walker
```

**작성**: 2026-05-22 / impl review Round 2 (codex adversarial-review)

---

## Round 3

```
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the Round 2 toolbar fix closes settled-ant shadowing, but the settlement transfer path still has a same-frame ordering hole that can silently drop follower trait transfer.

Findings:
- [medium] Same-frame follower entry can miss trait transfer permanently (CandyAnts/scripts/world/SettlementMarker.gd:22-45)
  `SettlementMarker._on_body_entered()` defers every entered ant by one physics frame, then makes a one-shot decision from the current `_distributor`. If a distributor and a follower are already inside the marker in the same physics step, the follower callback can resume while `_distributor` is still null, do nothing, and return. When the distributor callback then settles the distributor, the follower is already overlapping the Area2D, so no new `body_entered` signal is guaranteed and `_transfer_traits()` is never retried. This is an ordering inference from the one-frame await and one-shot `_distributor` check; it is not covered by the current transfer test, which waits for settlement before observing a later follower.
  Recommendation: Make transfer processing order-independent: after settling `_distributor`, scan `get_overlapping_bodies()` for eligible Walker/Carrying receivers and transfer immediately, or queue receiver candidates and retry after `_distributor` becomes non-null. Add a regression where a distributor and follower enter/overlap the marker in the same physics frame and assert the follower receives the whitelisted trait.
```

### 정리

**verdict**: needs-attention (HIGH 0 + MEDIUM 1)

| # | severity | 항목 | 수정 |
|---|---|---|---|
| F-impl-R3-1 | MEDIUM | SettlementMarker._on_body_entered의 one-frame await + one-shot _distributor 검사가 same-frame overlap 시 follower transfer 누락 | `_drain_pending_receivers()` 헬퍼 추가 — 정착 직후 `get_overlapping_bodies()` 스캔으로 walker/carrying receiver들에게 즉시 transfer. 회귀 가드 `tests/SettlementSameFrameOverlapTransferTest.tscn/gd` 신설 (분배자 + follower marker monitoring=false → on 전환으로 same-frame body_entered 시뮬, follower transfer 단언) |

### Self-Review Round 3 (after fix)

- 본인 적대적 검토:
  - `_drain_pending_receivers` 중복 transfer 가능성 — `_transfer_traits → set_trait` idempotent 보장 (Dictionary 같은 key 두 번 set 시 무영향) ✓
  - body_entered ordering 시나리오 모두 검증:
    - 분배자 먼저 → 정착 + drain → follower transfer ✓
    - follower 먼저 → _distributor null 분기 return → 분배자 처리 → drain로 follower (still overlapping) transfer ✓
  - get_overlapping_bodies() 호출 시점 — monitoring=true 유지 + body_entered 콜백 내 호출 안전 ✓
  - SettledState terminal — 분배자가 marker 안에 머무름, re-enter 없음 (drain 1회 호출) ✓
- 자체 리뷰 결과: HIGH 0건. codex 재리뷰 진입 가능.

### Verification (impl Round 3 fix)

```
SettlementSameFrameOverlapTransferTest  PASS — distributor settled + follower received floater via _drain_pending_receivers
SettlementTraitTransferTest             PASS frame=343 (회귀 무영향)
SettlementSameFrameRaceTest             PASS frame=288 (회귀 무영향)
DistributorSettleTest                   PASS frame=257 (회귀 무영향)
SettledImmuneSkillTest                  PASS frame=601 (회귀 무영향)
```

**작성**: 2026-05-22 / impl review Round 3 (codex adversarial-review)

---

## Round 4

```
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the Round 3 drain fix still contradicts the stated walker/carrying receiver contract, so carrying receivers silently miss transfers in both normal and same-frame overlap paths.

Findings:
- [medium] Carrying receivers are filtered out before transfer (CandyAnts/scripts/world/SettlementMarker.gd:27-29)
  `_on_body_entered()` returns immediately on `ant.has_candy` before it reaches the Walker/Carrying receiver branch, and `_drain_pending_receivers()` repeats the same `has_candy` skip. Since `CarryingState.enter()` sets `has_candy = true`, any carrying follower inside or entering the marker can never receive the whitelisted traits, despite the implementation comments and Round 4 focus saying walker/carrying receivers should be transferred. Impact: a follower carrying candy through an already-settled distributor marker will not receive floater, and the same-frame drain regression only proves WalkerState because the new test never constructs a CarryingState receiver.
  Recommendation: Separate the distributor-settlement guard from receiver-transfer eligibility: keep `has_candy` blocking settlement of the distributor, but do not reject `CarryingState` receivers solely because `has_candy` is true. Mirror that in `_drain_pending_receivers()` and add a regression with an overlapping CarryingState follower asserting floater transfer.
```

### 정리

**verdict**: needs-attention (HIGH 0 + MEDIUM 1)

| # | severity | 항목 | 수정 |
|---|---|---|---|
| F-impl-R4-1 | MEDIUM | `_on_body_entered`의 has_candy 검사가 receiver 분기까지 차단 → carrying receiver(분배자 정착 후 사탕 운반 follower)가 영구 transfer 누락 | `has_candy` 검사 위치를 분배자 본인 정착 트리거 분기 안쪽으로만 이동 (D8 운반 > 정착 정책은 분배자 본인에게만 적용). `_drain_pending_receivers`의 has_candy 검사도 제거. 회귀 가드 `tests/SettlementCarryingReceiverTransferTest.tscn/gd` 신설 (carrying follower + marker._distributor 사전 점유 + monitoring=true → follower has_floater=true + CarryingState/has_candy 유지 단언) |

### Self-Review Round 4 (after fix)

- 본인 적대적 검토:
  - 분배자 carrying 중 marker 진입 — has_candy=true → 분배자 분기에서 즉시 return → 정착 무시. receiver 분기는 _distributor==null이라 진입 안 함. 결과: carrying 분배자는 정착 안 됨, transfer 받음? — _distributor==null 동안 receiver 분기 거부됨. ✓ (D8 carrying > 정착 정책 정합)
  - 분배자 trait 보유 + has_candy=true ant가 정착된 다른 분배자 marker 진입 — _distributor != null + ant.has_trait("distributor")이지만 receiver 분기는 `if not (s is WalkerState or s is CarryingState): return` + ant == _distributor 체크. ant != _distributor이고 carrying이면 transfer 받음. (다중 분배자 상호작용 정상 — 두 번째 분배자도 transfer 대상)
  - _drain_pending_receivers 정착 직후 호출 — overlapping bodies 중 carrying receiver가 transfer 받음. has_candy 검사 제거로 정상 동작. ✓
  - Round 3 SettlementSameFrameOverlapTransferTest(walker receiver) 회귀 무 — 여전히 PASS ✓
- 자체 리뷰 결과: HIGH 0건. codex 재리뷰 진입 가능.

### Verification (impl Round 4 fix)

```
SettlementCarryingReceiverTransferTest  PASS — carrying follower received floater + CarryingState/has_candy 유지
SettlementSameFrameOverlapTransferTest  PASS (회귀 무영향)
SettlementTraitTransferTest             PASS frame=342 (회귀 무영향)
SettlementSameFrameRaceTest             PASS frame=288 (회귀 무영향)
```

**작성**: 2026-05-22 / impl review Round 4 (codex adversarial-review)

---

## Round 5

```
# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the Round 4 production fix is present, but the new regression guard can pass without exercising a carrying receiver, so the evidence for F-impl-R4-1 is weaker than claimed.

Findings:
- [medium] Carrying receiver regression test transfers while the follower is still a walker (CandyAnts/scripts/world/SettlementMarker.gd:11-12)
  `SettlementMarker._ready()` unconditionally sets `monitoring = true`, so the test's pre-add `marker.monitoring = false` is overwritten when `add_child(marker)` runs. The follower is then added while the marker is already monitoring, before `follower.has_candy = true` and before `change_state(CarryingState)`. That means the marker can transfer floater to a plain Walker receiver and the test will still pass later after the test mutates the follower into CarryingState. Inference: this guard would not reliably catch a reintroduction of the Round 4 `has_candy` receiver filter.
  Recommendation: Either stop forcing `monitoring = true` in `_ready()` and rely on the scene default, or update the regression tests to add the marker first, let `_ready()` run, then set `marker.monitoring = false` before adding ants. In `SettlementCarryingReceiverTransferTest`, assert the follower does not have floater before setting `has_candy`/`CarryingState`, then toggle monitoring and assert the transfer happens only after it is actually a carrying receiver.
```

### 정리

**verdict**: needs-attention (HIGH 0 + MEDIUM 1)

| # | severity | 항목 | 수정 |
|---|---|---|---|
| F-impl-R5-1 | MEDIUM | `SettlementMarker._ready()`가 무조건 `monitoring = true` set → driver test의 pre-add `monitoring = false`가 덮어쓰이고 follower가 walker 단계에서 transfer 받음 → carrying receiver 시나리오 실제 검증 약화 | (1) `SettlementMarker._ready()`에서 `monitoring = true` 라인 제거 (scene .tscn의 monitoring=true default에 의존). (2) 두 회귀 가드(`SettlementCarryingReceiverTransferTest`, `SettlementSameFrameOverlapTransferTest`)를 add_child 후 명시적 `monitoring=false` set + walker→carrying 전이 전 has_floater 미수신 pre-condition assertion 추가. (3) SameFrameOverlap test에 floor 추가(walker 자유낙하 방지) + walker grace |

### Self-Review Round 5 (after fix)

- 본인 적대적 검토:
  - `_ready` monitoring=true 제거가 phase 15 dev scene(SettleTest/SettleStuckTest/SettleRaceTest)에 영향 — scene .tscn의 monitoring=true default 유지로 동작 동일 ✓
  - SettleTest/Stuck/Race 헤드리스 4종 (DistributorSettle/TraitTransfer/SameFrameRace/HundredPercentStuck) 모두 PASS 재확인 ✓
  - SettledImmuneSkillTest/SkillToolbarSettledTargetFilterTest 무영향 (marker 사용 안 함 or _ready monitoring과 무관) ✓
  - carrying/overlap test의 pre-cond assertion이 false-positive(walker 단계 transfer)를 정확히 catch — recommendation 정합 ✓
- 자체 리뷰 결과: HIGH 0건.

### Verification (impl Round 5 fix)

```
SettlementSameFrameOverlapTransferTest  PASS (floor 추가 + pre-cond assertion 통과)
SettlementCarryingReceiverTransferTest  PASS (carrying-pre-cond assertion 통과)
DistributorSettleTest                   PASS frame=257
SettlementTraitTransferTest             PASS frame=343
SettlementHundredPercentStuckTest       PASS frame=901
```

**작성**: 2026-05-22 / impl review Round 5 (codex adversarial-review)

---

## Round 6 — **APPROVE (clean)**

```
# Codex Adversarial Review

Target: working tree diff
Verdict: approve

Ship: Round 1-5 findings are addressed in the inspected working tree, and I could not support a material remaining blocker from the Phase 15 settlement code or regression guards.

No material findings.

Next steps:
- Optional: rerun the five headless settlement regressions once more before merge, since this review was static/read-only.
```

### 정리

**verdict**: approve. impl-stage codex 리뷰 종료.

누적 finding 9건 모두 해소:
- Plan stage Round 1: F1 (HIGH stuck contract), F2 (MEDIUM same-frame race), F3 (MEDIUM 2-SoT)
- Plan stage Round 2: F-R2-M1 (summary mismatch), F-R2-M2 (§0.2 tone)
- Impl Round 1: F-impl-1 (HIGH settled is_alive leak), F-impl-2 (MEDIUM settlement_cell missing)
- Impl Round 2: F-impl-R2-1 (MEDIUM SkillToolbar shadow)
- Impl Round 3: F-impl-R3-1 (MEDIUM same-frame transfer loss)
- Impl Round 4: F-impl-R4-1 (MEDIUM carrying receiver filter)
- Impl Round 5: F-impl-R5-1 (MEDIUM monitoring _ready override)

**작성**: 2026-05-22 / impl review Round 6 — approve (codex adversarial-review)
