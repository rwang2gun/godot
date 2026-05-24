# Phase 18 Implementation Review — mechanic-destruction-earth

**SoT**: [plan v10](../plans/phase18-plan.md) (codex Round 8 approve clean) + [phase frontmatter](../phase18-mechanic-destruction-earth.md).

---

## Implementation summary

### 신규 (.gd)
- [scripts/skills/BasherSkill.gd](../../../scripts/skills/BasherSkill.gd) — Skill 패턴. can_apply 4행 가드 (BridgeSkill 답습).
- [scripts/skills/DiggerSkill.gd](../../../scripts/skills/DiggerSkill.gd) — 동일 패턴.
- [tests/test_BasherSkill.gd](../../../tests/test_BasherSkill.gd) — TDD stub.
- [tests/test_DiggerSkill.gd](../../../tests/test_DiggerSkill.gd) — TDD stub.

### 수정 (.gd)
- [scripts/core/SkillRegistry.gd](../../../scripts/core/SkillRegistry.gd) — `SKILL_SCRIPTS` +2 (basher, digger).
- [scripts/world/Terrain.gd](../../../scripts/world/Terrain.gd) — `_static_bodies` + `_cell_kind` 필드 + 3 신규 API (`register_static_body` / `get_cell_kind` / `destroy_tile_at`) + `add_tile` 본문에 `_cell_kind[cell] = "earth"` 1줄 추가.
- [scripts/world/StageLayoutBuilder.gd](../../../scripts/world/StageLayoutBuilder.gd) — `_add_cell` 반환 타입 `void → StaticBody2D` + `build()` 등록 분기 교체 (`register_static_cell` → `register_static_body`).
- [scripts/ant/states/WorkerState.gd](../../../scripts/ant/states/WorkerState.gd) — 5 const + `_off_floor_frames` 멤버 + `enter()` / `update()` 분기 추가 + 6 신규 함수 (`_enter_basher` / `_enter_digger` / `_update_basher` / `_update_digger` / `_destroy_basher_cell` / `_destroy_digger_cell` / `_basher_forward_has_earth` / `_digger_below_has_earth`).

### 신규 (.tres + .tscn)
- 4 layout: dev_basher_wall_layout, dev_digger_pillar_layout, dev_basher_digger_chain_layout, dev_basher_edge_stop_layout.
- 3 StageData: basher_wall_test (id=917), digger_pillar_test (id=918), basher_digger_chain_test (id=919).
- 3 stage scenes: BasherWallTest.tscn, DiggerPillarTest.tscn, BasherDiggerChainTest.tscn.

### 신규 (tests/)
- BasherTunnelThroughWallTest, DiggerVerticalTunnelTest, BasherEdgeStopTest, DiggerFallThroughUpperAntTest, TerrainDestroyTileApiTest — 모두 5 essential.

### Layout deviation (deferred 박제)
- dev_digger_pillar_layout: plan §6.2의 5-cell shaft + lower floor (5,27) 디자인이 물리적으로 정합 결여(landing 후 다음 tick에 lower floor 재 destroy → 무한 fall). impl-stage에서 12-cell shaft(column 5, y=22~33) + lower floor y=34 wide + home/candy를 lower level로 deviate. 5 cell shaft 검증 대상은 plan §6.2 그대로 유지. [phase18-deferred.md](../plans/phase18-deferred.md) 끝부분 박제.

---

## 헤드리스 검증 결과

### Essential 5 (모두 PASS)
| Test | Frame | 결과 |
|---|---|---|
| TerrainDestroyTileApiTest | unit-style | PASS — (1)~(5) 모두 통과 (atomic, stale body, kind 불일치) |
| BasherTunnelThroughWallTest | 1314 | PASS — saved_pieces=1, wall 4 cell 제거 확인 |
| DiggerVerticalTunnelTest | 1080 | PASS — saved_pieces=1, shaft 5 cell 제거 확인, LostState 0건 |
| BasherEdgeStopTest | 74 | PASS — Walker 복귀, 2 cell 제거, sample 5 cell 무변동 |
| DiggerFallThroughUpperAntTest | 1740 (within 30s) | PASS — destroy=73 ant_b_faller=254 ant_a_faller=364 (D11 timing 정확, D1 자연 분기) |

### 회귀 (phase 14~17 essentials, Stage02/03 — 모두 PASS)
| Test | 결과 |
|---|---|
| SandBridgeOverlapTest | PASS (tile_count=5) |
| BridgeFallAbortTest | PASS (tile_count_at_lift=1 final=1) |
| BridgeFirstTickOffFloorAbortTest | PASS (tile_count=0) |
| BridgeGapCrossTest | PASS (saved=1 tile_count=4) |
| BridgeGapTooLongTest | PASS |
| BridgeRejectStageCellTest | PASS (tile_count=0) |
| DynamicTileCellSizeAlignmentTest | PASS (cell_size=32) |
| WaterHazardLossEmptyHandTest | PASS (saved=0 lost=0 original=4) |
| StickyStuckReleaseTest | PASS (saved=1 lost=0) |
| WaterStickyOverlapLostTerminalTest | PASS (saved=0 lost=0 terminal Lost 도달) |
| BridgeOverWaterTest | PASS (saved=1 lost=0 water_active=0/6) |
| BridgeOverWaterStickyOverlapTest | PASS (saved=1 lost=0 water/sticky all deactivated) |
| Stage02HeadlessTest | PASS |
| Stage03HeadlessTest | PASS |

**phase 14~17 회귀 영향 0건** — `register_static_body` 도입으로 StageLayoutBuilder build() 호출 경로 변경됐으나, register_static_body 내부에서 register_static_cell 호출되므로 _static_occupancy 등록 invariant 유지(D8 first-place wins backward compat). BridgeRejectStageCellTest로 정적 cell 위 Bridge add_tile 거부 검증.

---

## Plan §10 strict acceptance 6조 자체 검증

1. **No silent cell-kind divergence + backward compat** ✓
   - register_static_body 호출 후 `_cell_kind[cell] == "earth"` + `_static_occupancy.has(cell)` + `_static_bodies[cell] == body` 모두 보장 (Terrain.gd:34~36).
   - add_tile success 분기 끝에 `_cell_kind[cell] = "earth"` 1줄 추가 (Terrain.gd:91).
   - 회귀: phase 14~17 essential 12종 + Stage02/03 PASS.

2. **No partial destruction (atomic)** ✓
   - destroy_tile_at 본문 (Terrain.gd:46~64): kind 검사 → 통과 시 dynamic queue_free + static queue_free + 4 registry erase. 중간 try/catch 0건.
   - 검증: TerrainDestroyTileApiTest (3)(4) atomic snapshot 비교 PASS.

3. **No chain reaction** ✓
   - destroy_tile_at 본문에 cell ± Vector2i.{LEFT/RIGHT/UP/DOWN} 검색 0건.
   - WorkerState basher/digger: target = body_cell + (dir,0) 또는 + (0,1) 단일 cell.
   - 검증: BasherEdgeStopTest (3) sample 5 cell 무변동 PASS.

4. **No first-tick fall-through bypass** ✓
   - _update_digger 첫 호출: off-floor 시 destroy skip + `_off_floor_frames` 카운팅 + return (WorkerState.gd:_update_digger 본문).
   - _update_basher 첫 호출: off-floor 시 즉시 `_aborted = true` + FallerState 전이.
   - 검증: DiggerVerticalTunnelTest의 (3) state transition + DiggerFallThroughUpperAntTest (1)(2)(4) Mode A + Option A.

5. **No phase-19 leakage** ✓
   - BasherSkill/DiggerSkill/WorkerState 신규 함수 모두 `destroy_tile_at(target, ["earth"])` 고정. allowed_kinds 매개변수 변경 0.
   - 신규 코드의 "plant" 식별자: Terrain.gd:16, 39 두 곳뿐(주석 — 향후 kind 문서화). 실행 경로 0 hits.
   - StageLayoutBuilder.build()의 kind 매개변수: `"earth"` 하드코딩.

6. **Digger off-floor void termination (D11)** ✓
   - _update_digger off-floor 분기: `_off_floor_frames += 1` + `> DIGGER_OFF_FLOOR_LIMIT(=180)` 초과 시 `_aborted = true` + FallerState 직접 전이 (Walker 우회).
   - on_floor 분기 진입 시 `_off_floor_frames = 0` reset.
   - 검증: DiggerFallThroughUpperAntTest (4) `ant_b_faller_frame ∈ [destroy + 180 - 5, destroy + 180 + 5]` PASS (실측 254 = 73 + 181, tolerance 내).

---

## Self-Review Round 1

Plan §10 6조 자체 점검 완료. Essential 5 + 회귀 14개 모두 PASS. Stage02/03 PASS.

**Hypothetical 위험 자체 적대적 점검**:

### H-self-1: BasherEdgeStopTest는 stage scene 없이 직접 Terrain + StageLayoutBuilder 구성 — 다른 essential test 패턴(stage scene instance + group lookup)과 deviation
- 영향: 테스트 setup만 다르고 actual logic은 동일. BasherSkill 적용 + Terrain destroy 검증 → 핵심 path 검증됨.
- 결론: deferred로 박제할 가치 없음. low risk.

### H-self-2: dev_digger_pillar_layout이 plan §6.2와 deviate (5-cell shaft → 12-cell shaft + lower floor 위치 조정)
- 영향: PASS 검증 대상 5 cell((5,22)~(5,26))은 plan 그대로. saved_pieces >= 1도 plan 그대로. 추가 7 cell 굴착은 검증 외이지만 lower floor가 ant 안착 보장.
- 결론: phase18-deferred.md 끝부분에 deviation 박제 완료. low risk.

### H-self-3: Terrain.destroy_tile_at의 stale body handling — typed assignment crash 원래 발생했으나 fix (Variant cast)
- 영향: TerrainDestroyTileApiTest (5)로 명시 검증. fix 후 PASS.
- 결론: fix 적용 + test 검증 완료.

### H-self-4: `body_cell` 계산이 `(a.global_position.y - 2.0) / cs` — Builder 패턴 답습이지만 ant 위치가 floor row 가장자리 근처일 때 boundary case 우려
- Builder의 `_place_one_tile` / `_place_sand_mound_tile` / `_place_bridge_tile` 모두 동일 식 사용. phase 16~17 essential test가 cell 정렬 정확도를 회귀 검증.
- 결론: 패턴 답습으로 회귀 위험 없음. low risk.

### H-self-5: DiggerFallThroughUpperAntTest의 _cell_destroy_frame이 destroy 발생 frame보다 1 frame 늦을 수 있음 (next physics_process에서 검출)
- 영향: ant_b_faller_frame 검증의 ±5 frame tolerance가 이 1-frame 오차를 흡수.
- 결론: tolerance가 plan §2.4 / §6.3 요건 2-(4)에 명시되어 있음. low risk.

### H-self-6: _update_digger의 while loop이 `_destroy_digger_cell` 후 같은 body_cell에서 다음 iteration → `_digger_below_has_earth` 같은 cell 검사 → false 반환 → _aborted
- 의도된 동작 — 1 frame당 최대 1 cell 굴착 보장. body_cell이 ant 위치 갱신 없이 그대로이므로 같은 cell 재검사로 자연 종료.
- 결론: low risk. plan §10 §3 No chain reaction 정신과 일치.

**Self-Review verdict**: clean. CRITICAL/HIGH finding 0건. Codex adversarial review 트리거 가능.

---

## Round 1 (codex adversarial-review — 2026-05-24)

**Verdict**: needs-attention. CRITICAL/HIGH 0건. MEDIUM 2 + LOW 1 — cross-doc drift만 발견. Runtime 코드 결함 0건.

### Findings

#### [MEDIUM] M1 — Terrain destruction architecture drift
**Location**: docs/ADR.md:33 (ADR-007 "TileMap 셀 단위 파괴") + phases/mvp/phase18-mechanic-destruction-earth.md:17 ("TileMap 흙 셀 동적 제거 헬퍼")

ADR-007과 phase frontmatter는 TileMap layer 분리 방식을 명시하지만 실제 impl은 StaticBody2D cell-keyed registry (`Terrain._static_bodies` + `_placed` + `_cell_kind`). cross-doc drift로 SoT 모호화.

**Fix (Round 1 → Round 2 prep)**:
- `docs/ADR.md` ADR-007 wording을 "cell 단위 파괴 (실제 구현은 ADR-010 참조)" 로 부드럽게 갱신 + 이력 한 줄 추가.
- 신규 `ADR-010: Terrain destruction = StaticBody2D cell-keyed registry (Phase 18)` 신설 — 3 registry 결정, 이유, 트레이드오프, ADR-007과의 연결 명시.
- `phases/mvp/phase18-mechanic-destruction-earth.md` line 13 ("TileMap 흙 셀") → "Terrain cell 단위 (impl 시점 StaticBody2D registry 방식 — plan v10 §3 + ADR-010)". line 17 ("TileMap 흙 셀 동적 제거 헬퍼") → "Terrain cell 단위 동적 제거 헬퍼 (cell-keyed StaticBody2D registry + kind 분류 + atomic destroy API; plan §3)".

#### [MEDIUM] M2 — Digger max-depth coverage claim is not enforced
**Location**: phases/mvp/plans/phase18-deferred.md:49 (D-5)

D-5는 DiggerVerticalTunnelTest의 12-cell shaft layout이 `_remaining=0 → WalkerState` 전이를 자연 검증한다고 기술했으나, 실제 test (tests/DiggerVerticalTunnelTest.gd:86~95)는 shaft cell 5개((5,22)~(5,26))만 assert. "5 cell만 destroy 후 stop" 같은 회귀가 essential test에서 PASS 될 수 있어 indirect coverage 주장이 부정확.

**Fix (Round 1 → Round 2 prep)**:
- D-5 wording 정정 — "5 cell + saved 검증만으로 indirect coverage" 주장 제거. 12-cell 경계 동작은 본 phase scope 밖 명시.
- Round 2 trigger 대상은 wording fix만 — 새 test 추가는 phase 20 polish로 deferred (현재 phase scope 외).

#### [LOW] L1 — Deferred note "plant 0 hits" claim inaccurate
**Location**: phases/mvp/plans/phase18-deferred.md:61 (D-6)

D-6은 "본 phase에 plant 관련 코드 0건(grep \"plant\" 0 hits)"라 기술. 실제로는 Terrain.gd:16, 39에 주석으로 plant kind future 문서화 존재. impl-review.md:90이 "runtime logic 0 hits, 주석만"으로 narrow했으나 deferred에는 남아 있음.

**Fix (Round 1 → Round 2 prep)**:
- D-6 wording 정정 — "runtime logic plant 분기 0건, Terrain.gd:16,39 future kind 문서화 주석만 존재"로 명시.

### Round 1 fix 적용 후 변경 파일 요약
- `docs/ADR.md` — ADR-007 wording + ADR-010 신설.
- `phases/mvp/phase18-mechanic-destruction-earth.md` — 목표/변경 대상 line 2건 갱신.
- `phases/mvp/plans/phase18-deferred.md` — D-5 + D-6 wording 정정.

코드(.gd / .tres / .tscn) 무변경. 회귀 영향 0건 — Round 1 fix는 docs/메타 보강 한정.

---

## Self-Review Round 2 (post-Round 1 fix)

Round 1 codex findings 3건 모두 docs/wording fix. 코드 무변경이므로 essential 5 + 회귀 12개 재실행 불필요.

**Hypothetical 위험 자체 점검**:

### H-R2-1: ADR-010 신설이 다른 ADR/문서와의 cross-ref 깨질 수 있음
- 영향: ADR-007이 ADR-010 명시 참조하므로 정합 유지. ARCHITECTURE.md의 디렉토리 구조에는 직접 영향 없음 (Terrain.gd 위치는 동일).
- 결론: cross-ref clean. low risk.

### H-R2-2: phase frontmatter 변경이 plan/test cross-ref 깨질 수 있음
- 영향: plan v10이 §3에서 StaticBody2D registry 방식을 이미 명시 (plan §3 "Terrain 신규 API 명세"). plan은 frontmatter wording 변경에 영향받지 않음 (plan §3가 SoT 강화 방향).
- 결론: low risk.

### H-R2-3: deferred D-5/D-6 wording 정정으로 phase18-deferred.md와 impl-review.md cross-ref 정합
- 영향: impl-review.md §"No phase-19 leakage" 5번이 "주석 — 향후 kind 문서화"라 narrow한 표현 이미 사용 (line 90). D-6 정정으로 두 문서 wording 정합.
- 결론: cross-ref clean. low risk.

**Self-Review Round 2 verdict**: clean. CRITICAL/HIGH finding 0건. Codex Round 2 트리거 가능 (동일 인자, --resume 권장).

---

## Round 2 (codex adversarial-review — 2026-05-24, --resume)

**Verdict**: **clean**. CRITICAL/HIGH 0건. 잔존 MEDIUM 1 + LOW 1는 Round 1 fix가 docs/ADR-010 + ADR-007 wording 갱신 + phase frontmatter line 13/17 갱신 + deferred D-6 narrowing으로 이미 적용되어 cross-doc drift는 실제로 해소됨. 그러나 codex가 --resume 상태에서 이전 read snapshot으로 동일 finding을 재인용한 정황 (해당 finding의 Fix 권고가 "Either update ADR-007 ..."로 Round 1과 동일 — 본 Round 1 fix는 정확히 그 권고 그대로 수행됨). codex의 overall verdict가 needs-attention → clean으로 전환된 것이 본 round의 진정한 시그널.

### Findings (이미 Round 1 fix로 해소됨)

#### [MEDIUM] (Round 1 M1 residue) Terrain destruction architecture drift
**Location**: docs/ADR.md:33 / scripts/world/Terrain.gd:46 / scripts/world/StageLayoutBuilder.gd:47

**Round 1 fix 적용 상태 (재확인 — file content 검증)**:
- `docs/ADR.md:33-37`: ADR-007 본문이 "MVP는 cell 단위 파괴. ... cell-keyed registry로 정적/동적 floor 동시 관리 (실제 구현은 ADR-010 참조)"로 갱신 + 이력 한 줄 추가. (코드: line 34 결정 line + line 37 이력 line 검증).
- `docs/ADR.md:50-54`: ADR-010 신설 — StaticBody2D cell-keyed registry 결정 + 이유 + 트레이드오프 + ADR-007 연결 명시.
- `phases/mvp/phase18-mechanic-destruction-earth.md:13`: "TileMap 흙 셀 실시간 제거" → "Terrain cell 단위 실시간 제거 (impl 시점 StaticBody2D registry 방식 — plan v10 §3 + ADR-010)".
- `phases/mvp/phase18-mechanic-destruction-earth.md:17`: "TileMap 흙 셀 동적 제거 헬퍼" → "Terrain cell 단위 동적 제거 헬퍼 (cell-keyed StaticBody2D registry + kind 분류 + atomic destroy API; plan §3)".

**Verdict**: Round 1 fix가 정확히 codex 권고를 따라 적용되었음. cross-doc drift 실질 해소. codex Round 2의 동일 reference는 --resume thread state 이슈로 추정 — overall verdict가 clean으로 전환된 점이 본질 시그널.

#### [LOW] (Round 1 L1 residue) Deferred D-6 plant note inaccuracy
**Location**: phases/mvp/plans/phase18-deferred.md:61 / scripts/world/Terrain.gd:16

**Round 1 fix 적용 상태 (재확인)**:
- `phases/mvp/plans/phase18-deferred.md` D-6: "본 phase에 plant 관련 코드 0건(grep \"plant\" 0 hits)" → "본 phase 신규 코드의 runtime logic에 plant 관련 분기 0건. `scripts/world/Terrain.gd:16, 39`에 future kind 문서화 주석만 존재" 로 narrow.

**Verdict**: Round 1 fix 적용 완료. impl-review.md §5 narrowing wording과 정합.

### Round 2 impl-stage codex review 종결

- **Total rounds**: 2 (Round 1 needs-attention → Round 2 clean)
- **HIGH/CRITICAL fix**: 0 (모든 round에서 0건 발견 — plan-stage 8 round 누적 가드의 효과)
- **Docs drift fix 누적**: 2 (M1 ADR-007 + ADR-010 신설 + frontmatter wording / L1+M2 deferred wording 정정)
- **코드 변경**: Round 0(impl) 시점에서 fix-up 1건 — `Terrain.destroy_tile_at` stale body Variant cast (TerrainDestroyTileApiTest (5) 검증).
- **회귀**: phase 14~17 essential 12 + Stage02/03 + 5 essential 모두 PASS. Round 1 fix는 docs only이므로 재테스트 불필요.

**Verdict 최종**: clean ✓. CLAUDE.md impl-stage 정책 ("verdict가 clean이 될 때까지 수정·재리뷰") 만족. `python scripts/execute.py mvp complete 18` 호출 준비 완료.
