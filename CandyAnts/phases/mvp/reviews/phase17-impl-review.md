# Phase 17 Impl Review — mechanic-hazard

**Impl target**: phase 17 implementation per [plan v4](../plans/phase17-plan.md). 신규 4 .gd + 수정 5 .gd + 신규 5 .tscn + 5 dev stage (910~913, 915) + 5 헤드리스 essential test.
**Policy**: CLAUDE.md impl-stage — codex 리뷰에서 CRITICAL/HIGH 발견 시 반드시 수정 + 재리뷰. clean 까지 자체+codex 사이클 반복.

---

## Self-Review Round 1 (2026-05-24)

**Verdict**: clean
**Coverage**: plan v4 §10 strict acceptance 7조 매칭 + impl 시점 발견 사항 점검.

### Strict acceptance 검증

| # | 조항 | 검증 결과 |
|---|---|---|
| 1 | No tone-policy violation in new code | `grep -rn 'die()\|Dead\|사망\|죽' scripts/world/hazards/ scripts/ant/states/LostState.gd` → **0 hits**. 메타 코멘트도 §0.2 어휘 우회 적용 |
| 2 | No silent hazard loss under overlap (R1-H1) | `BridgeOverWaterStickyOverlapTest` PASS: bridge 후 같은 cell의 Water + Sticky 둘 다 monitoring=false. registration 순서 무관. dev_bridge_over_overlap_layout (id=915) 신설 |
| 3 | No stuck-in-faller deadlock | FallerState/ClimberState/WorkerState 코드 변경 0 (`_place_*_tile`만 1줄 추가). 영구 공중/벽 stuck 없음 |
| 4 | No double-loss on multi-hazard entry | HazardBase `if not ant.is_alive(): return` 가드 + LostState.enter() has_candy=false 즉시 clear로 중복 emit 차단. WaterHazardLossEmptyHandTest의 `lost_pieces == 0` 확인 |
| 5 | No Bridge-blind hazard (v2) | WorkerState `_place_one_tile`/`_place_sand_mound_tile`/`_place_bridge_tile` 3개 모두 `terrain.deactivate_hazards_for_placement(target)` 호출. Stage02 회귀 PASS (hazard 없는 stage no-op) |
| 6 | No hazard cell row mismatch | Water/Sticky 노드 global_position.y=688 (body row 21 중심) — ant body cell y=21 진입 시 발화. 5 dev scene 모두 동일 컨벤션 |
| 7 | No order-dependent overlap invariant (R1-H2) | WaterStickyOverlapLostTerminalTest PASS: terminal=Lost + lost_pieces=0 (빈손) + ScoreSystem invariant만 검증. `_sticky_remaining` 값 비결정으로 명시 |

### Essential test 결과 (5/5 PASS)

| Test | Result | 검증 |
|---|---|---|
| WaterHazardLossEmptyHandTest | PASS frame=642 saved=0 lost=0 | 빈손 ant 4명 모두 Water entry → LostState → queue_free. invariant 유지 |
| StickyStuckReleaseTest | PASS frame=1747 saved=1 lost=0 | 첫 ant stuck@frame=385 → 3s timer 만료 → candy 도달 → home 회수 |
| BridgeOverWaterTest | PASS frame=1280 saved=1 lost=0 water_active=0/6 | Bridge 적용 → 6 cell Water 모두 deactivate → ant lost 0 |
| BridgeOverWaterStickyOverlapTest | PASS frame=1280 saved=1 lost=0 water/sticky all deactivated | R1-H1 회귀: 같은 cell의 Water+Sticky 모두 deactivate (Array 일괄) |
| WaterStickyOverlapLostTerminalTest | PASS frame=472 saved=0 lost=0 | R1-H2 회귀: terminal Lost 결정론. _sticky_remaining 비결정 허용 |

### Phase 14/15/16 회귀 결과 (9/9 PASS)

Stage02HeadlessTest, Stage03HeadlessTest, ClimberTraitTest, FloaterTraitTest, DistributorSettleTest, SettlementTraitTransferTest, SandMoundClimbTest, BridgeGapCrossTest, BridgeRejectStageCellTest 모두 PASS. hazard 미배치 stage들이 `terrain.deactivate_hazards_for_placement` 호출 시 no-op으로 회귀 0건.

### Impl 시점 발견 사항

| # | 발견 | 처리 |
|---|---|---|
| F-impl-1 | LostState.enter()의 `a.set_blocker_active(false)`이 Area2D body_entered 콜백 안에서 monitoring 직접 set 시도 → Godot "Can't change this state while flushing queries" ERROR | `a.call_deferred("set_blocker_active", false)`로 변경. 멱등 + frame 끝 deferred 실행 + queue_free와 순서 무관 |
| F-impl-2 | dev hazard test scenes의 Home/Candy y position이 floor edge가 아닌 cell center (688)로 잘못 배치 → Candy collision shape이 ant body cell과 미overlap → ant가 candy 통과 후 절벽 fall | 5 dev scene 모두 Home/Candy.y를 704 (floor top edge)로 수정. ant body extent y=694-704 → Candy shape extent y=616-704 overlap ✓ |

위 2 발견은 자체 검증 사이클에서 즉시 inline fix 적용 + 재실행으로 essential 5 test PASS 확인.

### Plan §9 체크리스트 vs impl 상태

- [x] `scripts/world/hazards/HazardBase.gd` 신규
- [x] `scripts/world/hazards/WaterHazard.gd` 신규
- [x] `scripts/world/hazards/StickyHazard.gd` 신규
- [x] `scripts/ant/states/LostState.gd` 신규
- [x] `scripts/ant/Ant.gd` 수정 (_sticky_remaining/apply_sticky/is_stuck/_sticky_badge + is_alive LostState + _physics_process timer + _update_trait_badges)
- [x] `scripts/ant/states/WalkerState.gd` stuck 분기
- [x] `scripts/ant/states/CarryingState.gd` stuck 분기
- [x] `scripts/ant/states/WorkerState.gd` _place_*_tile 3건 helper 호출
- [x] `scripts/world/Terrain.gd` Array storage + register_hazard_at_cell + deactivate_hazards_at + deactivate_hazards_for_placement
- [x] `scenes/entities/Ant.tscn` StickyBadge 추가
- [x] `scenes/entities/hazards/Water.tscn` 신규
- [x] `scenes/entities/hazards/Sticky.tscn` 신규
- [x] dev layouts 5종 (water/sticky/bridge_over_water/water_sticky_overlap/bridge_over_overlap)
- [x] dev stage data 5종 (id=910/911/912/913/915)
- [x] dev stage scenes 5종
- [x] tests 5종 essential (WaterHazardLossEmptyHand/StickyStuckRelease/BridgeOverWater/BridgeOverWaterStickyOverlap/WaterStickyOverlapLostTerminal)
- [x] §0.2 grep 자체 점검: 신규 코드 0 hits 확인
- [x] phase 14/15/16 회귀: 9 test 전부 PASS
- [→ deferred] WaterHazardLossCarryingTest (D-1), StickyCarryingPreservedTest (D-2), StickyTimerCarryingResumeTest (D-3), HazardEntryIdempotentTest (D-4), DistributorOnStickyTransferTest (D-5), SettledImmuneToHazardTest (D-6), 옵션 id=914 sticky_settle layout — 모두 [phase17-deferred.md](../plans/phase17-deferred.md) 박제

### Verdict 종합

**Self-Review Round 1 verdict: clean (HIGH 0)**. plan v4 §10 strict acceptance 7조 모두 통과 + essential 5 tests PASS + 회귀 9 tests PASS + §0.2 grep clean. 발견 사항 2건 모두 즉시 fix. codex impl-stage review 진입 가능.

---

## Codex Round 1 (2026-05-24)

**Verdict**: approve
**Summary**: Ship: I could not support a CRITICAL/HIGH blocker from the working-tree diff. The focused race/order concerns appear covered by the current guards or are deferred scope/test-depth issues rather than material no-ship defects.

### Findings

No material findings.

---

**Status (Round 1 종료, impl clean)**: codex verdict=approve, self-review verdict=clean. Phase 17 impl-stage 완료 — `python scripts/execute.py mvp complete 17` 진입 가능.

