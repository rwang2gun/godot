# Phase 18 Deferred — mechanic-destruction-earth

**Status**: phase 18 impl 시점 deferred 항목. plan v10 §8.2 박제. phase 20 polish 또는 후속 phase에서 처리.

---

## D-1: BasherCarryingRejectedTest

**의도**: carrying 중 basher 적용 시 `BasherSkill.can_apply(ant) == false`로 거부됨을 검증.

**왜 deferred**: `can_apply` 자체 코드 단순(WalkerState + on_floor + !has_candy 4행 가드). BridgeSkill/SandMoundSkill에서 동일 패턴 답습한 결과. essential test의 `saved_pieces >= 1` 검증에서 carrying ant가 basher 미적용 상태로 정상 진행한다는 사실로 간접 검증.

**처리 시점**: phase 20 polish 또는 v1.1. 검증 layout = 일반 home/candy + ant carrying 중간에 wall이 있는 형태.

---

## D-2: DiggerCarryingRejectedTest

**의도**: carrying 중 digger 적용 시 `DiggerSkill.can_apply(ant) == false`.

**왜 deferred**: BasherCarryingRejected와 동일 패턴. `can_apply` 4행 가드는 BridgeSkill/SandMoundSkill 답습이라 회귀 위험 낮음.

**처리 시점**: phase 20 polish 또는 v1.1.

---

## D-3: BasherHazardExposeTest

**의도**: basher가 wall 뒤 hidden hazard(Water 등)를 노출시킬 때 hazard monitoring=true 유지 검증. 노출된 hazard에 ant 진입 시 LostState 자연 전이.

**왜 deferred**: `destroy_tile_at` 본문에 hazard 노드 접근 0건 → hazard `set_active` 호출 0건 → hazard 노출 시 monitoring 변화 0건이 코드 invariant로 보장. layout 복잡(wall + hidden Water 배치).

**처리 시점**: phase 20 polish 또는 v1.1. layout `dev_basher_hidden_water_layout` 신설 후 essential 패턴 답습.

---

## D-4: BasherChainNoCascadeTest

**의도**: basher가 단일 cell 제거 후 인접 cell(LEFT/RIGHT/UP/DOWN) 무영향 검증.

**왜 deferred**: BasherEdgeStopTest의 (3) "sample cell 5개 무변동" 검증이 사실상 cover. `destroy_tile_at` 본문에 인접 cell 검색 0건 — plan §10 strict acceptance §3 "No chain reaction" 기준으로 코드 invariant 강제.

**처리 시점**: 별도 처리 불필요. plan §10 §3 회귀 발생 시 sweep으로 추가.

---

## D-5: DiggerInfinityGuardTest

**의도**: digger가 정확히 `DIGGER_MAX_CELLS = 12` cell만 destroy 후 종료. _remaining 카운터 정밀 검증.

**왜 deferred**: `_remaining`는 `WorkerState._update_digger` 내부 단순 카운터 — 매 `_destroy_digger_cell` 후 `-= 1`. DiggerVerticalTunnelTest는 shaft 5 cell ((5,22)~(5,26)) 제거 + saved_pieces ≥ 1만 명시 검증. 12-cell shaft layout이 ant 안착 보장용으로 깔려 있긴 하지만 (5,27)~(5,33) 제거나 `_remaining=0 → WalkerState` 전이를 직접 assert하지 않으므로, "5 cell만 destroy 후 stop" 같은 회귀 결함이 essential test에서 PASS될 수 있다. _remaining 정밀 검증과 12-cell 경계 동작은 본 phase scope 밖으로 명시 deferred.

**처리 시점**: phase 20 polish 또는 v1.1. 별도 layout(예: column 5에 정확히 12 cell 두고 그 아래 즉시 wide floor) + test가 12 cell 제거 + 13번째 시도 시 `_remaining=0 → WalkerState` 전이를 assert.

---

## D-6: BasherIntoPlantCellTest

**의도**: phase 19에서 도입될 plant cell에 basher 적용 시 `_basher_forward_has_earth == false` (kind="plant" ≠ "earth") → _aborted.

**왜 deferred**: 본 phase 신규 코드의 runtime logic에 plant 관련 분기 0건. `scripts/world/Terrain.gd:16, 39`에 future kind 문서화 주석만 존재("earth"/"plant" 분류) — 실행 경로 0 hits. phase 19 Cutter + plant kind 도입 시 함께 작성. 본 phase plan §10 §5 "No phase-19 leakage" 정책 답습.

**처리 시점**: phase 19 mechanic-destruction-plant 진입 시.

---

## 검증 stage layout deviation 메모 (deferred 아님 — 박제용)

**DiggerVerticalTunnelTest layout (dev_digger_pillar_layout)** — plan §6.2의 5-cell shaft + lower floor (5,27) 디자인은 물리적 정합 결여(landing 후 다음 tick에 (5,27) 재 destroy → 무한 fall). 따라서 impl-stage에서 12-cell shaft(column 5, y=22~33) + lower floor y=34 wide solid + home/candy를 lower level에 배치하는 형태로 deviate. PASS 검증은 plan §6.2의 5개 shaft cell((5,22)~(5,26))과 saved_pieces >= 1 유지. 자세한 deviation 코멘트는 `tests/DiggerVerticalTunnelTest.gd` 상단 헤더에 보존.
