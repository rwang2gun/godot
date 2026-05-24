# Phase 17 Deferred — mechanic-hazard

**Status**: phase 17 impl 시점 deferred 항목. plan v4 §10 strict acceptance + impl 본체에 영향 없음. phase 20 polish 또는 후속 phase에서 처리.

---

## D-1: WaterHazardLossCarryingTest (carrying 시 lost 카운터 검증)

**의도**: WaterHazardLossEmptyHandTest는 빈손 진입만 검증. carrying 중 Water 진입 시 `lost_pieces += 1` + `in_transit -= 1` + `has_candy=false`로 LostState 처리 검증이 별도로 필요.

**왜 deferred**: dev_water_layout의 Water cell이 home→candy 진로에 있어 ant가 candy 도달 전 lost됨. carrying 시나리오 layout 별도 신설 필요 (Water가 candy → home 진로 또는 candy 너머 별도 platform). 본 phase 17 impl 시점에 essential 5종(WaterHazardLossEmptyHand/StickyStuckRelease/BridgeOverWater/BridgeOverWaterStickyOverlap/WaterStickyOverlapLostTerminal)으로 R1-H1/H2 회귀 + Bridge D8 + Lost 기본 + Sticky 기본은 모두 커버. carrying loss 경로는 LostState.enter() 코드 자체에 `if a.has_candy: EventBus.candy_piece_lost.emit(a); a.has_candy = false`로 명시 — ScoreSystem._on_lost가 in_transit -1 처리.

**처리 시점**: phase 17 sweep 또는 phase 20 polish. layout `dev_water_after_candy_layout` 신설 후 동일 패턴 test driver 추가.

---

## D-2: StickyCarryingPreservedTest

**의도**: carrying ant가 Sticky 진입 → stuck 동안 has_candy=true 유지 + in_transit 1 유지 + lost 갱신 X → timer 만료 후 carry 재개 검증.

**왜 deferred**: dev_sticky_layout의 Sticky cell이 home→candy 진로에 있어 carrying 시나리오 자연스럽지 않음. 별도 layout 필요. carrying 보존 자체는 CarryingState.gd update 첫 줄 `if a.is_stuck(): a.velocity.x=0; a.velocity.y += a.gravity*delta; a.move_and_slide(); return` 코드로 명시 — has_candy 변경 0.

**처리 시점**: phase 17 sweep 또는 phase 20 polish.

---

## D-3: StickyTimerCarryingResumeTest

**의도**: Sticky timer 정확도 검증 중심. test driver가 매 frame `_sticky_remaining` 캡처 → linear decay 검증(±0.05s 오차 허용).

**왜 deferred**: StickyStuckReleaseTest가 timer 종료 + saved>=1로 transit 동작은 검증. timer 정밀 decay 검증은 implementation detail로 별도 unit test 가치 ↓. `_sticky_remaining = max(0, _sticky_remaining - delta)` 코드 자체 단순.

**처리 시점**: phase 20 polish 또는 v1.1.

---

## D-4: HazardEntryIdempotentTest

**의도**: WaterHazard 동일 ant 다중 body_entered 시 lost 1회만 발화 검증. Area2D 크기 2 cell wide로 확장 시 body_entered 다중 frame 발화 시나리오.

**왜 deferred**: HazardBase._on_body_entered의 `if not ant.is_alive(): return` 가드가 LostState 전이 후 추가 발화 자연 차단 — WaterHazardLossEmptyHandTest의 결과(lost_pieces == 0 + 모든 ant queue_free)가 사실상 이를 검증. StickyHazard double-entry는 `_recently_processed` dict로 차단 — 단위 검증 별도 필요성 ↓.

**처리 시점**: phase 20 polish.

---

## D-5: DistributorOnStickyTransferTest

**의도**: sticky 위 분배자 정착 → 후속 walker 능력 전이 검증 (D5/D6 정책).

**왜 deferred**: SettlementMarker + Sticky overlap layout 필요(`dev_sticky_settle_layout` id=914 신설). 분배자가 sticky stuck 후 정착하는 시나리오의 timing이 복잡(stuck timer 만료 → walker 회복 → settlement 진입). 본 phase 17 impl scope에서 D5/D6 정책 코드 변경 0 (SettlementMarker 무변경, stuck은 velocity만 0 state는 WalkerState 유지) — 자연 정합. 실제 검증은 phase 17 sweep 또는 phase 20 polish.

**처리 시점**: phase 17 sweep 또는 phase 20 polish. dev_sticky_settle_layout (id=914) 신설 + DistributorOnStickyTransferTest 작성.

---

## D-6: SettledImmuneToHazardTest

**의도**: SettledState ant가 Water area에 강제 이동 시 LostState 미진입 검증 (state 가드).

**왜 deferred**: HazardBase의 `not ant.is_alive()` 가드가 SettledState도 자연 차단 (Ant.is_alive()가 SavedState/DeadState/SettledState/LostState 모두 검사). 본 가드는 D13 정책으로 plan §3.1 명시 + WaterHazardLossEmptyHandTest 등 essential test에서 간접 검증. 별도 force-teleport 시나리오 test driver 추가는 implementation detail.

**처리 시점**: phase 20 polish.

---

## 정리 (impl 진입 시 처리 정책)

본 deferred 6항목은 모두 plan v4 §10 strict acceptance + R1-H1/H2 회귀 가드와 무관 (essential 5종 test가 핵심 회귀 모두 cover). 본 phase 17 impl scope에서 추가 작업 없이 박제 + phase 17 complete 진행 가능.

후속 phase(sweep 또는 phase 20 polish)에서 6항목 추가 작성 시:
- 신규 layouts: `dev_water_after_candy_layout` (D-1/D-2), `dev_sticky_settle_layout` (D-5)
- 신규 stage data: id=916 (water_after_candy), id=914 (sticky_settle)
- 신규 stage scenes: 동일 패턴
- 신규 tests: 6종

기존 plan v4 §1.2 D13/D14/D15 정책 변경 0 — 모두 코드/test 추가만 필요.
