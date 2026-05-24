# Phase 16 Deferred Nits (2026-05-24)

> phase 16 plan v7 자체 검토에서 발견된 cosmetic·cross-doc consistency 항목. 구현·codex 리뷰에 substantive 영향 없음. **impl 단계 또는 phase 16 sweep에서 일괄 처리.**

---

## N2 — §11 risk row wording이 §7.5보다 압축적

**위치**: [phase16-plan.md:822](phase16-plan.md) §11 row "(v7) Bridge 첫 update off-floor + 작업 중 ant fall"

**현 wording**: "v7 — `_update_bridge`에 floor-contact guard 포함. 첫 tile 전 off-floor는 1-frame grace로 placement loop를 건너뛰고, 다음에도 off-floor이면 중단. tile 배치 후 off-floor이면 즉시 중단."

**§7.5 비교 wording**: "이 frame에서는 `_tick_accum += delta`와 placement loop를 모두 건너뛴다" (`_tick_accum` 건너뛰는 점 명시)

**Gap**: §11 row는 `_tick_accum` 건너뛰는 점을 명시 안 함. cross-doc consistency 측면 minor.

**처리**: §11 row wording을 "1-frame grace로 `_tick_accum` 증가와 placement loop 모두 건너뜀"으로 tighten. 1줄 fix.

---

## N4 — §11 v7 row 본문 압축

**위치**: 위 N2와 동일 row.

**Gap**: row 전체가 §7.5의 상세 단락보다 짧음. v7 정책의 핵심 (`placed_count` 분기, `_bridge_floor_grace_used` 필드, grace 재충전) 중 일부만 언급.

**처리**: row를 §7.5의 짧은 1줄 요약 + "(자세히는 §7.5 참조)" 패턴으로 변경. 또는 §7.5와 cross-ref 명시.

**우선순위**: LOW. risk 표는 일반적으로 짧게 유지하는 게 가독성에 좋음.

---

## N5 — BridgeFirstTickOffFloorAbortTest fixture 옵션 정확도 ✅ **RESOLVED (v7 R4-M1 fix)**

**위치**: [phase16-plan.md:156](phase16-plan.md) §2.5 신규 테스트 명세

**현 wording**: "권장: ant를 위로 lift하거나 테스트 전용 fixture에서 bridge 시작 cell 아래 floor를 만들지 않음"

**문제**: 옵션 (b) "bridge 시작 cell 아래 floor를 만들지 않음"은 `BridgeSkill.can_apply`의 `is_on_floor()` gate에 막혀 실행 불가.

**처리 결과 (2026-05-24, R4-M1)**: codex Round 4가 N5와 동일한 issue를 MED finding으로 짚었고, 더 강한 권고 추가 (can_apply 통과 + WorkerState 진입 명시 검증). §2.5 명세를 8-step 시퀀스(can_apply 확인 → apply → WorkerState 진입 assert → lift → grace frame → abort)로 재서술 완료. 옵션 (b) 제거. hollow test 방지.

**잔여 작업**: 없음. impl 단계에서 본 명세 그대로 test 작성.

---

## 후속 처리

- impl 단계 진입 후 BridgeFirstTickOffFloorAbortTest 작성 시 N5 자연스럽게 fix.
- N2/N4는 다음 plan 갱신 또는 phase 16 sweep commit에서 일괄 처리.
- codex Round 4가 이 nit들 잡으면 즉시 inline fix (cosmetic이라 plan-stage policy의 HIGH/CRITICAL 미발생).

---

## Impl Stage Round 1 deferrals (2026-05-24, codex verdict = clean)

> Verdict는 clean (HIGH 0건)이라 phase complete 가능. 아래는 MEDIUM/LOW 사후 정리 candidates.

### N6 (MEDIUM) — StageLayoutBuilder.build() ready-time only 명문화 (PARTIAL FIX)

**위치**: [scripts/world/StageLayoutBuilder.gd](../../../scripts/world/StageLayoutBuilder.gd) `build()`

**문제**: 런타임 재호출 시 Terrain._static_occupancy stale cell 누적 위험. clear API 없음.

**현재 처리**: build() 상단 주석으로 "ready-time only" 명문화 (impl Round 1 inline fix). 동적 layout swap 시 Terrain.clear_static_cells() API 도입 필요.

**잔여 작업**: 실제 동적 swap 요구 phase 진입 시 clear API 추가. 현재 dev stage들은 모두 단일 ready 시 build → no risk.

### N7 (LOW) — SandBridgeOverlapTest 명세 보강

**위치**: [tests/SandBridgeOverlapTest.gd](../../../tests/SandBridgeOverlapTest.gd)

**문제**: 둘 중 정확히 하나의 ant만 race에 이겼는지 (대신 둘 다 일부 진행 X) assert 부재. PASS 명제 = tile_count >= 1 + no stuck. 더 strict하게 = 첫 target cell 캡쳐 + exactly 1 success + 1 abort.

**처리**: phase 17 진입 시 strict 명제로 강화 또는 별도 `tests/test_TerrainAddTileSameCellTest.gd` 추가.

### N8 (LOW) — BridgeRejectStageCellTest 실제 검증 경로

**위치**: [tests/BridgeRejectStageCellTest.gd](../../../tests/BridgeRejectStageCellTest.gd)

**문제**: All-solid 좌측 platform layout에서는 `_far_side_floor_reached` ray가 먼저 hit → add_tile 호출 자체가 일어나지 않음. "add_tile rejection" 검증이라기보다 "bridge 첫 tick에 자연 종료" 검증.

**현재 mitigation**: `DynamicTileCellSizeAlignmentTest` step (4)이 `terrain.add_tile(STATIC_CELL)` 직접 호출로 reject 명시 검증 (impl Round 1 inline 추가). 따라서 dynamic↔static add_tile gate는 closed.

**처리**: 향후 BridgeRejectStageCellTest fixture를 `_far_side_floor_reached`가 miss하지만 target cell이 static인 형태로 재설계. 또는 이름을 "BridgeNoForwardGapTest" 등 의도 명확한 name으로 변경 + 별도 add_tile direct test 유지.

### N9 (LOW) — Sand-mound static-cell rejection / OOB 미커버

**위치**: 부재.

**처리**: phase 17/18에서 hazard·파괴 메카닉과 함께 strict bound semantics 정의 + 헤드리스 테스트 추가.
