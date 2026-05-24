# Phase 16 Plan — mechanic-creation (v7)

**Status**: plan v7 — codex Round 3 needs-attention (HIGH ×1) inline fix 완료. v7 변경: R3-H1 — bridge 첫 update off-floor hole 제거. `_remaining == BRIDGE_MAX_LENGTH` 예외를 삭제하고, 첫 tile 전 off-floor는 **배치 없이 1-frame grace 후 재검사**, 두 번째 off-floor 또는 tile 1개 이상 배치 후 off-floor는 즉시 중단한다. 신규 `_bridge_floor_grace_used` 필드와 `tests/BridgeFirstTickOffFloorAbortTest` 추가. 기존 `BridgeFallAbortTest`는 mid-work lift만 검증하도록 좁힘. plan-stage 정책 — v7 작성 후 codex Round 4 명시 요청만 실행. HIGH 발견 시 즉시 중단 + 사용자 결정.
**Phase frontmatter doc**: [phases/mvp/phase16-mechanic-creation.md](../phase16-mechanic-creation.md)
**1차 SoT 인용**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §3.2 (생성 메카닉) / §3.2.3 (엣지 케이스) / §0.2 (어휘 정책) / §0.7.0 (잠정치 정책)
**관련 코드 SoT**: `scripts/skills/BuilderSkill.gd` (기존 발판 생성 모델), `scripts/ant/states/WorkerState.gd` (`builder` 분기, v7 bridge floor-contact guard), `scripts/core/SkillRegistry.gd`, `scripts/core/StageLayoutData.gd`, `scripts/world/Terrain.gd` (`add_tile()` 단일 진입점, v4 cell_size + static occupancy 도입, v5 sprite scale 비례), `scripts/world/StageLayoutBuilder.gd` (v3 build() 끝에 terrain register 호출)
**리뷰 보존**: [phases/mvp/reviews/phase16-plan-review.md](../reviews/phase16-plan-review.md)
**작성**: 2026-05-23 (v1), 2026-05-23 (v2 — 같은 날 inline rev), 2026-05-24 (v3 — review cleanup), 2026-05-24 (v4 — review consistency pass), 2026-05-24 (v5 — self-review H1/M1/M2/M3 fix), 2026-05-24 (v6 — codex Round 2 R2-H1/R2-M1 fix), 2026-05-24 (v7 — codex Round 3 R3-H1 fix), 2026-05-24 (v7 R4-M1 명세 강화 — codex Round 4 MED 흡수, plan-stage policy HIGH 0건 통과)

---

## 0.2 v1 → v7 변경 (codex Round 1 needs-attention 대응 + v5 self-review pass + v6/v7 codex fixes)

| 항목 | v1 | v2 | finding |
|---|---|---|---|
| §4.4 D8 first-place wins (Terrain occupancy) | "Stage cell vs 동적 cell 좌표 겹침은 미커버. add_tile은 stage cell 좌표에 true 반환 — Godot StaticBody2D 중첩 정상." (hand-wave) | **`Terrain`에 `_static_occupancy: Dictionary` 추가, `StageLayoutBuilder.build()` 끝에서 각 생성 cell을 `terrain.register_static_cell(cell)`로 등록. `add_tile(cell)`은 `_placed.has(cell) OR _static_occupancy.has(cell)` 시 false. 신규 테스트 `BridgeRejectStageCellTest`로 회귀 검증** | F-R1-H1 [high] — D8 stage cell coverage 부재 |
| §5 dev layouts cell_size=32 vs WorkerState.CELL_SIZE=16 mismatch | layout cell_size=32 / Terrain.CELL_SIZE=16 / WorkerState.CELL_SIZE=16 (silent 2x scale mismatch — 4-cell 갭 실제는 8 dynamic tiles) | **Terrain에 `cell_size: int = 16` (default fallback) 필드 + `set_cell_size(s)` 메서드. `StageLayoutBuilder.build()` 끝에서 `terrain.set_cell_size(layout.cell_size)` 호출. WorkerState 모든 placement 함수가 `terrain.cell_size`를 읽음 (const CELL_SIZE=16 제거). Stage 02/03처럼 StageLayoutData 미사용 stage는 terrain.cell_size=16 default 유지 → Builder 회귀 0건 (Stage 02 layout 미보유). Stage 01도 Builder 미사용 (Stage 02 skill) → 회귀 0건** | F-R1-H2 [high] — 16px vs 32px unit mismatch |
| 검증 (§8.1) | Stage01/02/03HeadlessTest 회귀 명시 | **Stage02HeadlessTest를 v2 변경 후 explicit re-verify 명세 — Builder 동작이 terrain.cell_size 변경에 의해 깨지지 않음을 확인. Stage02는 layout 미보유 → terrain.cell_size=16 fallback → Builder가 16px tile 12개 placement (기존 동작 동일)** | F-R1-H2 후속 — Builder backward-compat 회귀 보장 |
| §2.6 무변경 ban list (Terrain.gd) | "무변경 — add_tile/has_tile/tile_count 인터페이스 그대로" | **수정 대상으로 이동 — `cell_size` 필드, `set_cell_size()` 메서드, `_static_occupancy` 필드, `register_static_cell()` 메서드, `add_tile()` 변경(stage occupancy 가드 추가). 인터페이스는 backward-compatible (기존 add_tile 시그니처 유지, 기존 caller 무영향)** | F-R1-H1+H2 |
| §2.6 무변경 ban list (StageLayoutBuilder.gd) | "무변경" | **수정 대상으로 이동 — `build()` 끝에서 ancestor terrain 발견 시 cell_size + static cells 일괄 register. terrain 미발견 시 `push_warning()` 출력 후 register 생략. 자체 cell 생성 로직(`_add_cell`)은 무변경** | F-R1-H1 |
| §11 리스크 표 | Builder 회귀 위험 없음 (Builder 무변경) | **신규 리스크 row — Builder backward-compat: terrain.cell_size를 모르는 stage(Stage 02/03)에서 Builder가 동일 동작 유지하는지 explicit 검증** | F-R1-H2 후속 |

### v3 cleanup (2026-05-24)

- D8 설명에서 "StageLayoutBuilder가 static 등록한 cell은 Terrain에 미등록"이라는 v1 잔여 문구 제거. v3 기준 정적 stage cell은 `_static_occupancy`에 등록되며 `Terrain.add_tile()`의 동일 gate를 통과한다.
- cell-size 정책을 하나로 고정: **StageLayoutData 사용 stage는 `layout.cell_size`**, layout 미사용 legacy stage는 **Terrain default 16**. WorkerState/Builder/Sand-mound/Bridge 모두 `terrain.cell_size`만 읽는다.
- 신규 회귀 `DynamicTileCellSizeAlignmentTest`를 추가해 `cell_size=32` layout에서 동적 tile world position이 StageLayoutBuilder 정적 cell grid와 정렬되는지 검증한다.
- StageLayoutBuilder가 Terrain을 찾지 못하면 silent skip이 아니라 `push_warning()`을 남긴다. Phase 16 dev stages는 Terrain과 StageLayoutBuilder가 같은 stage scene에 존재해야 한다.

### v4 consistency pass (2026-05-24)

- Sand-mound 검증 stage의 수직 갭을 **5 cells**로 통일했다. D2의 `MAX_HEIGHT=5`와 §5.1의 PASS 명제가 같은 단위를 사용한다.
- SkillToolbar 정책을 **무변경 + fallback 표시**로 고정했다. `sand_mound.svg`/`bridge.svg`가 없으므로 phase 16에서는 ICONS/KO_LABELS에 신규 key를 추가하지 않는다.
- Bridge floor 감지는 `Terrain.has_tile()` 의존이 아니라 Layer 1 physics ray로 명시했다. 이 ray는 StageLayoutBuilder 정적 cell과 Terrain 동적 tile을 모두 감지해야 한다.

### v5 self-review pass (2026-05-24)

| # | 항목 | v4 | v5 |
|---|---|---|---|
| H1 | §2.4 dev_sand_mound_layout 설명 | "ant가 sand_mound로 **4-cell** 높이 platform에 올라야" | **"5-cell 높이 platform" + D2 MAX_HEIGHT=5와 §5.1 갭 일치 명시** (v4 5-cell unification 갱신 누락분 해소) |
| H1 | §2.5 SandMoundClimbTest 설명 | "**4 cells** 높이 platform에 올라야" + PASS는 `saved_pieces >= 1`만 | **"5 cells 높이 platform" + PASS에 `terrain.tile_count() == 5` AND 추가** (회귀 가드 강화) |
| M1 | §7.3 Bridge `_far_side_floor_reached` 1-cell 갭 분석 | "갭 1 cell에 bridge apply → 첫 tick에 true → tile 0개" (잘못) | **§4.2 ray 도달 거리(forward 1 cell · down cs+4)를 풀어 1-cell 갭 정확 시뮬레이션 — tile 1개 적재 후 tick 2 종료. N-cell 갭은 정확히 N tiles**. §5.2의 3-cell 갭 case도 동일 논리로 재서술 |
| M2 | §11 Builder backward-compat 회귀 risk row | "Stage 01도 Builder 미사용 (Stage 02 skill)" (모호) | **Stage 01/02/03 각각 verbose 분석 — Stage 01: SLB + cell_size=32 갱신되지만 available_skills 미설정 → add_tile 호출자 0건. Stage 02/03: SLB 미사용 → terrain.cell_size=16 default. Stage03HeadlessTest 회귀 가드 명시 포함** |
| M3 | §2.2 Terrain.gd 변경 (sprite scale 누락) | `body.global_position`만 cell_size 비례로 명시, `rect.size`와 `sprite.position/scale`은 hardcoded 16px 가정 | **`rect.size = Vector2(cell_size, cell_size)` + `scale_factor = cell_size/16.0`로 sprite.position·scale을 비례 적용. cell_size=16 시 scale_factor=1.0 (기존 코드와 식별, 회귀 0건). §4.4 v4 snippet도 일관 갱신** |

> v5는 v4의 D8 stage occupancy 통합 + cell_size unification 본체에 손대지 않는다. inline cleanup only.

### v6 codex Round 2 fix (2026-05-24)

| # | 항목 | v5 | v6 |
|---|---|---|---|
| R2-H1 | §4.2 `_update_bridge` fall guard | snippet에 `is_on_wall` abort만 있음. §7.5는 "가드 추가" 명시, §11은 "미도입" 명시 → cross-doc 모순. ant fall 중 영구 공중 tile 잔재 위험 (D7) | **`_update_bridge`에 `if _remaining < BRIDGE_MAX_LENGTH and not a.is_on_floor(): _aborted = true` 가드 도입.** 첫 tick false alarm 회피 위해 `_remaining < MAX_LENGTH` 조건 포함 (enter 직후 한 frame off-floor 가능성). §4.2 snippet/§7.5/§11 일관 정리. **신규 헤드리스 `tests/BridgeFallAbortTest`**: 강제 lift로 guard 발동 검증 (§2.5/§8.1) |
| R2-M1 | §11 risk row sand_mound 갭 wording | "stage layout **4-cell 갭** 통과에 정확히 부족" (v5 H1 fix가 §2.4/§2.5만 갱신했고 §11 row 빠뜨림) | **"stage layout 5-cell 갭"**로 통일. §5.1(5-cell)/D2(MAX_HEIGHT=5)와 cross-ref 일치 |

> v6는 v4/v5 본체에 손대지 않는다. R2-H1 가드 도입 + 새 헤드리스 1건 + §11 wording cleanup만. **주의: v6의 `_remaining < BRIDGE_MAX_LENGTH` guard는 Round 3에서 폐기되었고 v7 정책이 현재 기준이다.**

### v7 codex Round 3 fix (2026-05-24)

| # | 항목 | v6 | v7 |
|---|---|---|---|
| R3-H1 | §4.2 bridge 첫 update off-floor guard | `_remaining < BRIDGE_MAX_LENGTH` 조건 때문에 첫 update에서 off-floor여도 placement loop 진입 가능. `BridgeFallAbortTest`도 tile 1개 이후 lift만 검증해 첫 tile 전 hole 미검출 | **첫 tile 전 off-floor는 placement loop 진입 금지.** `_bridge_floor_grace_used`가 false면 1-frame grace로 return만 수행하고 tick accumulator도 증가시키지 않음. 다음 update에도 off-floor면 즉시 중단. tile 1개 이상 배치 후 off-floor도 즉시 중단. `BridgeFirstTickOffFloorAbortTest` 추가로 첫 tile 전 off-floor에서 `tile_count == 0`을 검증 |

> v7는 bridge floor-contact guard semantics만 바꾼다. D8 occupancy, cell_size unification, sand_mound geometry, SkillToolbar fallback 정책은 v6와 동일.
> **Normative rule**: 구현자는 과거 v5/v6 변경 이력의 코드 조건을 재사용하지 말고, §4.2의 v7 snippet과 §7.5/§8.1/§11의 v7 문구만 따른다. 특히 `_remaining < BRIDGE_MAX_LENGTH` 단독 guard는 폐기된 정책이다.

### v7 strict acceptance 기준

- **No stale assumption**: "Builder/Terrain unchanged", "StageLayoutBuilder cells are not registered", "16px dynamic grid on 32px layout" 같은 Round 1 이전 가정이 구현 지시 섹션(§2~§11)에 남아 있으면 plan fail.
- **No first-tick bridge placement off-floor**: 첫 tile 전 `not is_on_floor()`인 frame은 `_tick_accum` 증가와 `_place_bridge_tile()` 호출이 모두 금지된다. 1-frame grace 이후에도 off-floor이면 WorkerState를 빠져나와야 한다.
- **Grace recharge after re-landing (v7 N3)**: `_bridge_floor_grace_used`는 ant가 다시 floor에 안착할 때 reset된다 (§4.2 snippet placement loop 직전 line). 1-frame 물리 진동(off→on→off bouncing)을 false abort로부터 보호하기 위한 의도된 정책. 단 **tile placement는 off-floor frame에서 절대 실행되지 않음** (grace frame은 return으로 skip). 진짜 fall (연속 off-floor 2 frame)은 즉시 abort.
- **No silent unit mismatch**: StageLayoutData 사용 stage에서는 `terrain.cell_size == layout.cell_size`를 테스트로 확인해야 하며, 동적 tile collision/position/sprite scale 모두 같은 cell_size를 사용해야 한다.
- **No untested occupancy claim**: D8은 dynamic↔dynamic과 dynamic↔static 두 테스트가 모두 있어야 closed로 본다.
- **No fallback asset preload**: `sand_mound.svg`/`bridge.svg`가 생기기 전까지 SkillToolbar ICONS에 신규 preload key를 추가하지 않는다.

---

## 0. 한 줄 요약 (v7 — v4 본체 + v5 self-review cleanup + v6/v7 codex fixes)

기존 Builder(수평 12 cells 고정)의 발판 생성 모델을 두 갈래로 확장한다. **Sand-mound**(`scripts/skills/SandMoundSkill.gd`, ID `"sand_mound"`)는 ant 발 밑 column에 tile을 stack하며 ant가 위로 끌어올려진다(수직, 최대 5 cells). **Bridge**(`scripts/skills/BridgeSkill.gd`, ID `"bridge"`)는 ant 진행 방향으로 발 높이의 tile을 깔되 **반대편 floor가 감지되거나** 최대 8 cells 도달 시 자연 종료한다(수평, 갭 자동 감지). 두 스킬 모두 `WorkerState.new("sand_mound"|"bridge")`로 전이. **v4 — Terrain.cell_size unification**: `Terrain.cell_size` (default 16)을 `StageLayoutBuilder.build()`가 layout.cell_size(=32 etc)로 동기화. Stage 02·03처럼 layout 미사용 stage는 cell_size=16 fallback → Builder 동작 회귀 0건. **v4 — Stage occupancy unification (D8 real fix)**: `Terrain._static_occupancy`에 StageLayoutBuilder 생성 cell들을 일괄 register. `add_tile()`은 `_placed` OR `_static_occupancy` 점유 시 false → 동적·정적 cell 양쪽에 first-place wins 적용. **v7 — Bridge floor-contact guard**: 첫 tile 전 off-floor는 배치 없이 1-frame grace 후 재검사, 이후에도 off-floor거나 tile 배치 후 off-floor면 즉시 중단한다. ScoreSystem 4-카운터(ADR-002), EventBus 시그널 무영향. Hazard·식물 지형 위 생성 정책은 phase 17·19 진입 시 결정 (D9/D10 defer). dev StageData/layout fixture 5개(905~909) + 수동 검증 scene 3개(`SandMoundTest`, `BridgeTest`, `BridgeRejectTest`) + 헤드리스 회귀 9개 신설 (`BridgeRejectStageCellTest`, `DynamicTileCellSizeAlignmentTest`, `BridgeFirstTickOffFloorAbortTest`, `BridgeFallAbortTest` 포함). 톤 폴리시 §0.2 어휘만 사용 — 미완성 생성물 표현은 "남김"/"중단"으로 통일.

---

## 1. Open decisions before implementation — 결정 (frontmatter doc "Open decisions" 10건 승격)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D1 | Sand-mound 쌓기 속도 | **tick 기반 — `TICK_SECONDS = 0.25`** (기존 builder 0.20과 약간 다르게, 수직 작업은 시각적으로 더 명확해야 하므로 약간 느림). `_tick_accum` 패턴 답습. | 추천안. WorkerState builder의 검증된 tick 패턴 답습 + 수직 작업의 시각 가독성. 거리 기반은 velocity가 0인 정지 작업에 의미 약함 |
| D2 | Sand-mound 최대 높이 | **고정값 5 cells** (`MAX_HEIGHT = 5`, cell_size 32 기준 160px). stage layout override는 phase 16 범위 외 — 필요 시 phase 20 polish에서 도입 | 사용자 결정 (Recommended). 5 cells = ant 키(~22px)의 약 7배 = 자연스러운 "쌓는 모래 더미" 높이. dev_sand_mound_layout의 5 cells 갭을 정확히 통과하도록 맞춘 값. stage override는 데이터 추가 비용 vs 사용 빈도 낮아 후순위 |
| D3 | Sand-mound 생성 중 다른 개미 충돌 | **통과** (Ant↔Ant 충돌 미설정, 기존 builder/blocker도 동일). 다른 walker가 sand_mound 작업자를 지나가도 작업자 위치 무영향. | 추천안. ARCHITECTURE의 Ant collision_mask(Layer 1+2)는 벽만 — Ant Layer 3은 mask에 미포함이라 ant끼리 통과. Blocker만 별도 BlockerHitbox(Area2D)로 push back. |
| D4 | Sand-mound 자연 무너짐 | **없음 — 영구 platform** (terminal). Terrain.add_tile로 등록된 cell은 영구 StaticBody2D | 추천안. MVP 단순성 + Builder/Bridge 일관성. 무너짐 추가 시 timer 관리·다른 ant 추락 race·생성-소멸 사이클 추가 — phase 16 scope outside |
| D5 | Bridge 수평 거리 한계 | **고정값 8 cells** (`MAX_LENGTH = 8`, cell_size 32 기준 256px). Builder의 12 cells보다 짧지만 갭 자동 감지로 본 길이까지만 채움 → 갭이 6 cells면 6 cells에서 완성, 갭이 10 cells면 8 cells에서 미완성 종료. stage layout override 후순위. | 사용자 결정 (Recommended). Builder는 fixed 12, Bridge는 economical 8 + 갭 적응. 8 cells = dev_bridge_layout의 표준 갭 4 cells의 2배 여유 |
| D6 | Bridge 시작/끝 | **갭 자동 감지** — apply 시점에 ant.direction 방향으로 발 높이(`feet_cell.y`) 행의 cells을 스캔. 발 밑(feet_cell + Vector2i(0, 1))에 floor가 있는 첫 cell까지 진행. 매 tick `_remaining` 1 감소 + 1 cell forward. 반대편 floor 도달 또는 MAX_LENGTH 소진 시 종료 | 사용자 결정 (Recommended). 플레이어 수동 시작/끝은 input 모달리티 필요(2-step skill apply = phase 16 scope outside). 자동 감지는 결정론 + 단순. Builder 12-cell 강제와 명확히 차별화 |
| D7 | 미완성 Bridge 잔재 처리 | **잔재 유지** — 이미 놓인 cell들은 영구 StaticBody2D. ant가 사탕 손실로 lost 처리되거나 Bridge 중 사고로 작업 중단 시, 그 시점까지 놓인 cells은 그대로 유지 → 다른 ant가 통행 발판으로 활용 가능 | 사용자 결정 (Recommended). PROPOSAL §0.2 어휘 "남김". 즉시 제거 시 chain reaction(빌딩 중 떨어진 ant들도 함께 fall) 위험. 즉시 완성은 작업 ant 없이 무료 cells 발생 — 자원 무한 위험. 유지는 단순 + 협력 puzzle 가능성 부여 |
| D8 | Sand-mound + Bridge 좌표 겹침 | **선착순(first-place wins)** — Terrain.add_tile(cell)이 이미 점유된 cell에 대해 `false` 반환 → 후속 작업자가 `_aborted=true`로 종료. 작업 종료된 ant는 WalkerState로 복귀. 작업자 자신의 다음 cell 시도까지의 이전 cells는 유지(잔재). | 추천안. 기존 Terrain.add_tile() 단일 진입점의 false-return 계약 활용. 별도 우선순위 정책(time-stamp 비교, priority queue 등) 도입 0. StageLayoutBuilder가 생성한 정적 stage cells는 build 끝에서 `terrain.register_static_cell(cell)`로 등록되므로, stage layout cells과 동적 cells 모두 동일 add_tile gate를 통과한다. stage cell 위에 sand_mound/bridge가 시도되면 `_static_occupancy.has(cell)`로 `add_tile` false. 자세히는 §4.4 참조 |
| D9 | Hazard 위 생성 시도 | **phase 17(hazard) 진입 시 결정 — phase 16 deferred**. phase 16 시점 hazard 노드 부재. 본 phase plan/구현/테스트에서는 "hazard 미존재" 가정. phase 17 plan 작성 시 hazard cell 위 add_tile 호출 정책 결정 (현 추정: hazard는 Area2D 트리거이고 platform tile은 StaticBody2D라 좌표 공존 가능. add_tile 자체는 성공하지만 ant가 platform 위에서 hazard에 진입 시 사탕 손실 발화 → 즉 "hazard 위 platform 생성은 hazard를 차단하지 않음" 정책 후보) | 추천안. phase 16 시점 결정 의미 없음 (검증 불가). PROPOSAL §3.2.3 TBD 그대로 phase 17로 이연 |
| D10 | 식물 지형 위 생성 가능 여부와 우선순위 | **phase 19(Cutter + 식물 지형) 진입 시 결정 — phase 16 deferred**. 식물 지형 클래스 자체가 phase 19 신설. phase 16 시점 식물 cell 없음 → 결정 의미 없음 | 추천안. PROPOSAL §3.4.2 식물 지형 신설이 phase 19 — 그때 식물 cell vs StaticBody2D platform 좌표 공존 + Cutter 절단 정책과 함께 결정 |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)

| 파일 | 용도 |
|---|---|
| `scripts/skills/SandMoundSkill.gd` | ID `"sand_mound"`. can_apply: `WalkerState` + `is_on_floor()` + `not has_candy` + `is_alive()`. apply: `state_machine.change_state(WorkerState.new("sand_mound"))`. Builder/Blocker `can_apply` 패턴 일관 |
| `scripts/skills/BridgeSkill.gd` | ID `"bridge"`. can_apply: `WalkerState` + `is_on_floor()` + `not has_candy` + `is_alive()`. apply: `state_machine.change_state(WorkerState.new("bridge"))`. Builder/Blocker `can_apply` 패턴 일관 |

### 2.2 수정 (.gd)

| 파일 | 변경 |
|---|---|
| `scripts/ant/states/WorkerState.gd` | (1) **`const CELL_SIZE: int = 16` 삭제** — 모든 placement 함수는 `terrain.cell_size`를 dynamic read. (2) 신규 분기 2건 추가: `_work_type == "sand_mound"` → `_enter_sand_mound` / `_update_sand_mound` / `_place_sand_mound_tile`. const `SAND_MOUND_TICK = 0.25`, `SAND_MOUND_MAX_HEIGHT = 5`. `_work_type == "bridge"` → `_enter_bridge` / `_update_bridge` / `_place_bridge_tile` / `_far_side_floor_reached`. const `BRIDGE_TICK = 0.20`, `BRIDGE_MAX_LENGTH = 8`, 신규 field `_bridge_floor_grace_used: bool`. (3) `enter()`/`update()` 분기 dispatch 라우터 +2건. `exit()`는 두 신규 분기 정리 0 (terminal cleanup 불필요 — Walker 복귀 시 자연 해제). (4) **Builder 기존 분기(`_place_one_tile`)의 `CELL_SIZE` 참조도 `terrain.cell_size`로 치환** — Stage 02/03처럼 terrain.cell_size=16 fallback 유지 stage는 동작 동일 (회귀 0건). (5) **Bridge floor-contact guard(v7)**: 첫 tile 전 off-floor는 1-frame grace만 허용하고 tile placement는 절대 수행하지 않음. grace 이후에도 off-floor이거나 tile 배치 후 off-floor면 즉시 중단 |
| `scripts/core/SkillRegistry.gd` | `SKILL_SCRIPTS` 배열에 `preload("res://scripts/skills/SandMoundSkill.gd")` + `preload("res://scripts/skills/BridgeSkill.gd")` 2줄 추가 (CLAUDE.md CRITICAL — 자기등록 금지). `_skills` dict 자동 빌드. validate_stage 자동 적용 |
| `scripts/ant/Ant.gd` | `_update_sprite()`의 WorkerState 분기에 `"sand_mound"`, `"bridge"` 추가 — 둘 다 fallback `"build"` 애니메이션 재사용 (시각 전용, 게임 로직 무영향). 신규 anim 추가는 phase 20 polish |
| `scripts/world/Terrain.gd` | **v2 — 수정 (인터페이스 backward-compatible) / v5 — visual scale 명시**: (1) `const CELL_SIZE: int = 16` 삭제, 대신 `var cell_size: int = 16` (runtime 필드, default 16 = layout 미보유 stage fallback). (2) `set_cell_size(s: int)` 메서드 신설 — StageLayoutBuilder가 호출. (3) `var _static_occupancy: Dictionary = {}` 신설 — stage 정적 cell 좌표 추적. (4) `register_static_cell(cell: Vector2i)` 메서드 — StageLayoutBuilder가 build 끝에서 호출. (5) `add_tile(cell)` 수정: `if _placed.has(cell) or _static_occupancy.has(cell): return false`. 기존 caller(`WorkerState._place_one_tile`)는 인터페이스 변화 무영향 (false 처리 동일). (6) **add_tile 본문 전반의 CELL_SIZE 참조 → self.cell_size**: `rect.size = Vector2(cell_size, cell_size)` (collision box), `body.global_position = Vector2(cell.x * cell_size + cell_size / 2.0, cell.y * cell_size + cell_size / 2.0)` (위치), **sprite 비례 (v5 신규)**: 기존 hardcoded `sprite.position = Vector2(0, -13)`는 16px tile 기준 → `var scale_factor: float = float(cell_size) / 16.0; sprite.position = Vector2(0, -13.0 * scale_factor); sprite.scale = Vector2(scale_factor, scale_factor)` 로 변경. 이로써 cell_size=32 stage에서도 sprite/collision 정합 (BridgeGapCrossTest 등 시각 정합). cell_size=16 (Stage 02/03 default) 시 scale_factor=1.0 → 기존 코드와 식별 (회귀 0건). |
| `scripts/world/StageLayoutBuilder.gd` | **v3 — 수정**: `build()` 끝에서 ancestor scan으로 `Terrain` 노드 발견 시: (a) `terrain.set_cell_size(int(layout.cell_size))` 호출, (b) 본인이 `_add_cell`로 생성한 모든 cell 좌표에 `terrain.register_static_cell(cell)` 호출. Terrain 미발견 시 `push_warning()` 출력 후 register만 생략한다. Phase 16 dev stages는 Terrain과 StageLayoutBuilder가 같은 stage scene에 존재해야 하며, 미발견은 수동/로그 검증에서 즉시 드러나야 한다. 자체 cell 생성 로직(`_add_cell`)은 무변경 |
| `scripts/core/StageLayoutData.gd` | **무변경** — settlement_cell처럼 sand_mound/bridge 전용 cell 신설 안 함. 두 스킬은 ant의 현재 위치 + direction만 기반 |

### 2.3 수정 (.tscn)

| 파일 | 변경 |
|---|---|
| `scenes/entities/Ant.tscn` | **무변경** — sand_mound/bridge 시각은 기존 "build" 애니메이션 재사용. 별도 TraitBadges 추가 없음 (skill 시각은 sprite 애니메이션으로만) |

### 2.4 신규 (검증 stage)

| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_sand_mound_layout.tres` | StageLayoutData. cell_size=32. 수직 갭 1개 — ant가 sand_mound로 5-cell 높이 platform에 올라야 candy 도달 가능 (v4 unification — D2 MAX_HEIGHT=5와 §5.1 갭 일치). 도식 §5.1 |
| `data/stages/dev/sand_mound_test.tres` | StageData. **id=905** (dev 예약 — 901 trait_test, 902 settle_test, 903 settle_test_stuck, 904 settle_test_race 점유 확인 완료. 905~908이 phase 16 신규 점유). display_name="dev-sand-mound-test". available_skills=`["sand_mound"]`. skill_inventory=`{"sand_mound":2}` (1 시도 + 1 여유). total_ants=3, candy_hp=3, time_limit=120, release_rate_initial=30. **메뉴 노출 X (id ≥ 900 dev 예약)** |
| `scenes/stages/dev/SandMoundTest.tscn` | Stage scene. Stage02 패턴 + dev_sand_mound_layout wiring + SkillToolbar |
| `data/stage_layouts/dev_bridge_layout.tres` | StageLayoutData. cell_size=32. 수평 갭 1개 (4 cells 폭) — ant가 bridge로 가로질러야 candy 도달 가능. 도식 §5.2 |
| `data/stages/dev/bridge_test.tres` | StageData. **id=906**. display_name="dev-bridge-test". available_skills=`["bridge"]`. skill_inventory=`{"bridge":2}`. total_ants=3, candy_hp=3, time_limit=120, release_rate_initial=30 |
| `scenes/stages/dev/BridgeTest.tscn` | Stage scene. Stage02 패턴 + dev_bridge_layout wiring + SkillToolbar |
| `data/stage_layouts/dev_bridge_too_long_layout.tres` | StageLayoutData. **`BridgeGapTooLongTest`만 사용**. 수평 갭 12 cells (MAX_LENGTH=8 초과). ant가 bridge 적용해도 가로지를 수 없음 검증 |
| `data/stages/dev/bridge_too_long_test.tres` | StageData. **id=907**. display_name="dev-bridge-toolong". available_skills=`["bridge"]`. skill_inventory=`{"bridge":3}`. total_ants=2, candy_hp=2, time_limit=60 |
| `data/stage_layouts/dev_sand_bridge_overlap_layout.tres` | StageLayoutData. **`SandBridgeOverlapTest`만 사용**. 두 ant가 같은 cell을 두고 sand_mound 동시 시도하는 layout (§5.4 도식 참조 — 같은 발 cell 위에 두 ant spawn) |
| `data/stages/dev/sand_bridge_overlap_test.tres` | StageData. **id=908**. display_name="dev-sand-bridge-overlap". available_skills=`["sand_mound","bridge"]`. skill_inventory=`{"sand_mound":2,"bridge":2}`. total_ants=2, candy_hp=2, time_limit=60 |
| `data/stage_layouts/dev_bridge_reject_layout.tres` **(v3 유지)** | StageLayoutData. cell_size=32. ant가 좌측 platform 끝에 도달 후 bridge apply 시 인접 cell이 **이미 stage 정적 cell**로 등록된 단순 layout — 좌측 platform이 한 칸만 더 있는 형태(즉 갭이 없고 platform이 더 길 뿐). bridge가 첫 cell 시도 시 `_static_occupancy` hit → reject 검증 |
| `data/stages/dev/bridge_reject_test.tres` **(v3 유지)** | StageData. **id=909**. display_name="dev-bridge-reject". available_skills=`["bridge"]`. skill_inventory=`{"bridge":2}`. total_ants=2, candy_hp=2, time_limit=30 |
| `scenes/stages/dev/BridgeRejectTest.tscn` **(v3 유지)** | Stage scene. Stage02 패턴 + dev_bridge_reject_layout wiring + SkillToolbar (헤드리스 테스트는 toolbar 없이 직접 skill.apply 호출) |

> **dev id 정책**: id ≥ 900은 dev 예약(phase 14의 trait_test=901 결정 답습). 메뉴 진입 미노출 — `scripts/core/MenuLayout.gd` filter 또는 SaveData unlock 미설정으로 자연 차단. **확인됨 (2026-05-23 grep)**: 901 trait_test / 902 settle_test / 903 settle_test_stuck / 904 settle_test_race 점유. 본 phase 905~909 신규 점유 (5건).

### 2.5 신규 (tests/)

| 파일 | 검증 |
|---|---|
| `tests/SandMoundClimbTest.tscn/gd` | 헤드리스. dev_sand_mound_layout + sand_mound_test.tres 사용. 첫 ant에 `SandMoundSkill.apply()` → 5 cells 높이 platform에 올라야 candy 도달 → CarryingState 진입 → home 회수. **PASS**: 30초 내 `ScoreSystem.saved_pieces >= 1` AND `terrain.tile_count() == 5`. **FAIL**: 30초 후 saved=0 또는 ant가 sand_mound 작업 중 무한 stuck |
| `tests/SandMoundMaxHeightTest.tscn/gd` | 헤드리스. dev_sand_mound_layout 사용 + ant 위 5 cells 모두 비어있는 spawn 위치. sand_mound apply → 5 tiles 정확히 stack → 6번째 시도 시 `_remaining=0`으로 WalkerState 복귀. **PASS**: `terrain.tile_count() == 5` + ant.state_machine.current_state is WalkerState. **FAIL**: 6 tiles 이상 또는 작업 무한 진행 |
| `tests/BridgeGapCrossTest.tscn/gd` | 헤드리스. dev_bridge_layout + bridge_test.tres 사용. 첫 ant에 `BridgeSkill.apply()` → 갭 가로지름 → 반대편 floor 도달 시 자동 종료 → candy 도달 → home 회수. **PASS**: 30초 내 `saved_pieces >= 1` + `terrain.tile_count()` 가 갭 폭과 일치 (4-cell 갭이면 4, 3-cell 갭이면 3) + tile_count < MAX_LENGTH (8). **FAIL**: tile_count >= 8 (MAX_LENGTH 도달 = 갭 종료 미감지) 또는 saved=0 |
| `tests/BridgeGapTooLongTest.tscn/gd` | 헤드리스. dev_bridge_too_long_layout + bridge_too_long_test.tres 사용. 12-cell 갭에 bridge apply → 8 cells 도달 시 미완성 종료 → ant가 8번째 tile 끝에서 절벽으로 fall → 사탕 손실 또는 사탕 미도달. **PASS**: 60초 내 `terrain.tile_count() == 8` (D7 잔재 유지 검증). **추가 검증**: `saved_pieces == 0` (가로지르기 실패) |
| `tests/SandBridgeOverlapTest.tscn/gd` | 헤드리스. dev_sand_bridge_overlap_layout 사용. 두 ant가 같은 cell을 두고 sand_mound + bridge 시도. **D8 first-place wins 검증 (dynamic↔dynamic)**: 첫 add_tile 성공한 작업자만 진행, 두 번째는 `_aborted=true` → WalkerState 복귀. **PASS**: 60초 내 (1) `terrain.tile_count() >= 1` (최소 1 cell 생성), (2) 두 ant 모두 WorkerState에 영구 stuck 없이 WalkerState 복귀, (3) ScoreSystem invariant 유지 |
| `tests/BridgeRejectStageCellTest.tscn/gd` **(v2 신규 — F-R1-H1 대응)** | 헤드리스. dev_bridge_reject_layout(신규 layout, cell_size=32) — ant가 진행 방향으로 bridge 적용 시 좌측 elevated platform 끝에서 인접 cell이 **이미 stage 정적 cell**로 등록된 좌표. apply 후 bridge 첫 placement 시도 → `terrain._static_occupancy.has(cell)` true → `add_tile` false → `_aborted=true` → WalkerState 즉시 복귀. **PASS**: 30초 내 (1) `terrain.tile_count() == 0` (동적 cell 0개 추가), (2) ant.state_machine.current_state is WalkerState (WorkerState 빠져나옴), (3) ScoreSystem invariant 유지. **회귀 명제 (D8 stage occupancy coverage)** — F-R1-H1이 다시 발생하면 `tile_count > 0`이 되어 FAIL |
| `tests/DynamicTileCellSizeAlignmentTest.tscn/gd` **(v3 신규 — F-R1-H2 대응)** | 헤드리스. `dev_bridge_layout`(cell_size=32) + Terrain + StageLayoutBuilder 사용. `StageLayoutBuilder.build()` 뒤 `terrain.cell_size == 32`를 확인하고, 갭 cell에 `terrain.add_tile(Vector2i(gap_x, platform_y))`를 직접 호출하거나 Bridge 첫 placement를 유도한다. **PASS**: 추가된 동적 tile의 `global_position == Vector2(cell.x * 32 + 16, cell.y * 32 + 16)`이고, 인접 StageLayoutBuilder 정적 cell 중심도 같은 32px grid에 놓인다. **FAIL**: 동적 tile이 16px grid 중심(`cell.x * 16 + 8`)에 생성되거나 stage cell과 반 cell 이상 어긋남 |
| `tests/BridgeFirstTickOffFloorAbortTest.tscn/gd` **(v7 신규 — R3-H1 대응, R4-M1 명세 강화)** | 헤드리스. `dev_bridge_layout` 사용 (floor 있는 정상 stage). 실행 순서: (1) 첫 ant가 floor 위 안착할 때까지 대기, (2) `assert BridgeSkill.new().can_apply(ant) == true` (skill 적용 가능성 확인 — false면 fixture 잘못), (3) `BridgeSkill.apply(ant)`, (4) **`assert ant.state_machine.current_state is WorkerState` 즉시 확인 — bridge가 실제로 WorkerState로 진입했음을 명시 검증** (R4-M1 권고 핵심), (5) `tile_count_before_lift = terrain.tile_count()` 캡쳐 (정상 진입 직후 0이어야 함), (6) **첫 bridge placement tick 전에** `ant.global_position.y -= 200.0`으로 강제 공중 lift, (7) 다음 `_physics_process` 1 frame: `_update_bridge`가 off-floor 감지 + `_bridge_floor_grace_used == false` → tick accumulator 증가와 placement loop 진입 없이 return. `tile_count == 0` 유지 검증, (8) 이어지는 `_physics_process`: 여전히 off-floor → `_aborted = true` → state 전이. **PASS**: (1) step (4)에서 WorkerState 진입 확인, (2) grace frame 직후 `terrain.tile_count() == 0`, (3) 5 frame 후에도 `terrain.tile_count() == 0`, (4) ant.state_machine.current_state가 WorkerState가 아닌 다른 state (WalkerState/FallerState), (5) ScoreSystem invariant 유지. **FAIL**: WorkerState 진입 실패 (fixture 잘못 = hollow test), 또는 lift 이후 tile_count 증가 (R3-H1 재발), 또는 ant가 WorkerState 영구 stuck |
| `tests/BridgeFallAbortTest.tscn/gd` **(v6 신규, v7 범위 축소 — mid-work fall 대응)** | 헤드리스. `dev_bridge_layout` 재활용 (cell_size=32, 4-cell 갭). 첫 ant에 `BridgeSkill.apply()` → 1~2 tick 진행해서 `terrain.tile_count() >= 1` 확인 후 test driver가 `ant.global_position.y -= 200.0`으로 강제 공중 lift. 다음 `_physics_process` tick에 `_update_bridge`의 tile-after guard(`BRIDGE_MAX_LENGTH - _remaining > 0` AND `not is_on_floor`)가 발동 → `_aborted=true` → WalkerState/FallerState 전이. **PASS**: 30초 내 (1) lift 시점의 `tile_count_at_lift` 값 캡쳐 → 5 frame 후 `terrain.tile_count() == tile_count_at_lift` (가드 후 추가 tile 0개), (2) ant.state_machine.current_state가 WorkerState가 아닌 다른 state (WalkerState 또는 FallerState), (3) ScoreSystem invariant 유지. **FAIL**: lift 이후에도 tile_count 증가 (mid-work guard 미발동) 또는 ant가 WorkerState에 영구 stuck |

### 2.6 무변경 (CRITICAL — codex 검증 ban list, v7 갱신)

- `scripts/core/EventBus.gd` — 신규 시그널 0건. sand_mound/bridge 완료/중단 알림은 phase 16 범위 외 (phase 20 polish UI에서 도입 가능)
- `scripts/core/ScoreSystem.gd` — 4-카운터(ADR-002) 무영향. 생성물은 ScoreSystem과 직접 연결 0
- `scripts/core/StageData.gd` — 필드 추가 0건. 기존 available_skills/skill_inventory가 `"sand_mound"`/`"bridge"` 문자열 ID 지원
- `scripts/core/StageLayoutData.gd` — 신규 필드 0건. 두 스킬은 layout cell 의존 없음 (ant 위치 + direction만)
- `scripts/core/StageRunner.gd` — 무변경. 새 시그널 미수신
- `scripts/skills/Skill.gd`, `BuilderSkill.gd`, `BlockerSkill.gd`, `ClimberSkill.gd`, `FloaterSkill.gd`, `DistributorSkill.gd` — **전부 무변경**. 회귀 영향 0
- `scripts/ant/Ant.gd` — `_update_sprite()` 신규 work_type 매핑 1줄(`elif w == "sand_mound" or w == "bridge": anim = "build"`)만 추가. 그 외 무변경 — has_candy/has_been_carrying/traits dict 무영향
- `scripts/ant/states/WalkerState.gd` / `CarryingState.gd` / `FallerState.gd` / `ClimberState.gd` / `SavedState.gd` / `DeadState.gd` / `SettledState.gd` — **전부 무변경**
- `scripts/world/SettlementMarker.gd` — phase 15 자산. sand_mound/bridge 미사용. **무변경**
- `scripts/world/Candy.gd`, `Home.gd`, `CookiePlatformVisual.gd` — 무변경
- `scripts/world/hazards/**` — 무변경 (phase 17 영역, phase 16 시점 미존재)
- 기존 stages Stage01~03 / data/stages/stage0N.tres — sand_mound/bridge available_skills 미사용. **회귀 무영향** (v2 — Builder backward-compat: terrain.cell_size=16 fallback로 Stage 02 Builder 동작 식별)
- phase 14 dev stages (TraitTest), phase 15 dev stages (SettleTest, SettleRaceTest, SettleStuckTest) — sand_mound/bridge available_skills 미사용. **회귀 무영향**. **단 v2 — Terrain 변경의 사이드이펙트 회귀 가드**: 이 dev stages 모두 StageLayoutBuilder + cell_size=32를 사용 — Terrain이 set_cell_size(32) 호출 받음. 그러나 이 stages는 add_tile을 호출하지 않으므로 cell_size 변경의 영향 없음. Settlement 메커니즘은 Area2D/Marker 기반이라 Terrain.cell_size 무관
- `scripts/ui/HUD.gd` — 무변경. tile_count 카운터 미표시
- `scripts/ui/SkillToolbar.gd` — **무변경**. §10.2 사전 점검 기준으로 `sand_mound.svg`/`bridge.svg`가 없으므로 ICONS/KO_LABELS에 신규 key를 추가하지 않는다. dev 검증 중에는 `SkillSlot.icon_texture = null`, label은 영문 ID fallback을 허용한다. 정식 아이콘/한글 라벨은 phase 20 polish 영역

**v2 — 수정 대상으로 이동된 파일** (§2.2 참조):
- `scripts/world/Terrain.gd` — cell_size 필드 + static_occupancy 도입 (인터페이스 backward-compatible)
- `scripts/world/StageLayoutBuilder.gd` — build() 끝에서 terrain register 호출
- `scripts/ant/states/WorkerState.gd` — CELL_SIZE const 삭제 + terrain.cell_size dynamic read (Builder 분기 포함)

### 2.7 텍스처 정책 (minimal)

본 phase는 시각 자산 최소화 — 모두 기존 텍스처 재사용:

- Sand-mound tile: `assets/sprites/terrain/thin_cookie_bridge_tile.png` 재사용 (Terrain.gd `_bridge_tile_texture`). 별도 sand 텍스처 도입은 phase 20 polish
- Bridge tile: 동일 (`thin_cookie_bridge_tile.png`). Bridge는 기존 Builder와 동일 텍스처 — 게임 로직 차이는 placement 패턴이지 시각 자산이 아님
- Sand-mound · Bridge 작업 애니메이션: 기존 `"build"` 애니메이션 재사용

**deferred to phase 20 polish**: 별도 sand 텍스처(모래 더미 시각), bridge 시각 차별화, 작업 애니메이션 추가 (`"sand_mound"`, `"bridge"`).

---

## 3. Skill 명세

### 3.1 SandMoundSkill.gd
```gdscript
class_name SandMoundSkill extends Skill

const ID: String = "sand_mound"

func can_apply(ant: Ant) -> bool:
    if ant == null or ant.state_machine == null:
        return false
    if not ant.is_alive():
        return false
    var s: AntState = ant.state_machine.current_state
    # Walker만 — Carrying 거부(운반 중 작업 시 in_transit 영구 잔존 위험, Builder/Blocker 정책 일관).
    if not (s is WalkerState):
        return false
    if not ant.is_on_floor():
        return false
    if ant.has_candy:
        return false
    return true

func apply(ant: Ant) -> void:
    if ant == null or ant.state_machine == null:
        return
    ant.state_machine.change_state(WorkerState.new("sand_mound"))
```

### 3.2 BridgeSkill.gd
```gdscript
class_name BridgeSkill extends Skill

const ID: String = "bridge"

func can_apply(ant: Ant) -> bool:
    if ant == null or ant.state_machine == null:
        return false
    if not ant.is_alive():
        return false
    var s: AntState = ant.state_machine.current_state
    if not (s is WalkerState):
        return false
    if not ant.is_on_floor():
        return false
    if ant.has_candy:
        return false
    return true

func apply(ant: Ant) -> void:
    if ant == null or ant.state_machine == null:
        return
    ant.state_machine.change_state(WorkerState.new("bridge"))
```

### 3.3 can_apply 비교표 (phase 14~16)
| Skill | WalkerState | CarryingState | FallerState | ClimberState | WorkerState | SettledState | 추가 조건 |
|---|---|---|---|---|---|---|---|
| Builder | ✓ (on_floor) | ✓ | ✗ | ✗ | ✗ | ✗ | (없음 — Carrying 허용은 기존 phase 3 결정) |
| Blocker | ✓ (on_floor) | ✗ | ✗ | ✗ | ✗ | ✗ | not has_candy |
| Climber | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | not has_trait(climber) |
| Floater | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | not has_trait(floater), is_alive |
| Distributor | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | not has_trait(distributor), is_alive |
| **Sand-mound** | ✓ (on_floor) | ✗ | ✗ | ✗ | ✗ | ✗ | not has_candy, is_alive |
| **Bridge** | ✓ (on_floor) | ✗ | ✗ | ✗ | ✗ | ✗ | not has_candy, is_alive |

**Carrying 거부 사유**: Sand-mound/Bridge는 작업 중 ant가 위치 anchor(정지)된 상태. Carrying 중 작업 진입 시 has_candy=true 유지 + in_transit 1 잔존 → 작업 중 시간 경과로 time_out fail 가능성 + 사탕 회수 흐름 정지. Blocker 정책(can_apply의 `not has_candy`) 일관.

---

## 4. WorkerState 분기 명세

> 본 phase 추가 분기는 기존 `"builder"`/`"blocker"` 분기와 동일한 enter/update 라우팅 패턴. `_init(work_type)`의 dispatch는 `enter()`의 if/elif 체인 + `update()`의 if/elif 체인 두 곳.

### 4.1 Sand-mound 분기

```gdscript
# WorkerState.gd 신규 const
const SAND_MOUND_TICK: float = 0.25
const SAND_MOUND_MAX_HEIGHT: int = 5

# enter() 신규 분기
elif _work_type == "sand_mound":
    _enter_sand_mound(a)
# (기존 _enter_builder 등과 동일 패턴)

func _enter_sand_mound(a: Ant) -> void:
    _remaining = SAND_MOUND_MAX_HEIGHT
    _tick_accum = 0.0
    _aborted = false
    a.velocity = Vector2.ZERO   # 정지

# update() 신규 분기
elif _work_type == "sand_mound":
    _update_sand_mound(a, delta)
    return

func _update_sand_mound(a: Ant, delta: float) -> void:
    if _aborted or _remaining <= 0:
        a.state_machine.change_state(WalkerState.new())
        return
    # 정지 — 좌우 무이동. 중력은 적용(tile 사이 떠있을 때 대비).
    a.velocity.y += a.gravity * delta
    a.velocity.x = 0.0
    a.move_and_slide()
    _tick_accum += delta
    while _tick_accum >= SAND_MOUND_TICK and _remaining > 0 and not _aborted:
        _tick_accum -= SAND_MOUND_TICK
        _place_sand_mound_tile(a)
    if _remaining <= 0 and not _aborted:
        a.state_machine.change_state(WalkerState.new())

func _place_sand_mound_tile(a: Ant) -> void:
    var terrain: Terrain = _find_terrain(a)   # 기존 helper 재사용
    if terrain == null:
        _aborted = true
        return
    var cs: int = terrain.cell_size   # v2 — dynamic read (const CELL_SIZE 제거)
    # ant 발 밑 한 칸(현재 floor cell) 위에 tile 추가 — ant는 그 위로 끌어올려짐.
    var feet_cell: Vector2i = Vector2i(
        int(floor(a.global_position.x / cs)),
        int(floor((a.global_position.y + 2.0) / cs))   # 발 직하 cell
    )
    var target: Vector2i = feet_cell + Vector2i(0, -1)
    var ok: bool = terrain.add_tile(target)
    if not ok:
        _aborted = true
        return
    # ant를 1 cell 위로 끌어올림.
    a.global_position.y -= float(cs)
    _remaining -= 1
```

**Sand-mound 동작 도식** (terrain.cell_size에 따라 가변, 도식은 cs=16 기준):
```
초기:                tick 1 후:           tick 2 후:
       👤              👤                  👤
═══════floor═      ═══tile═════         ═══tile═════
                    ═══floor═══          ═══tile═════
                                          ═══floor═══
```

### 4.2 Bridge 분기

```gdscript
# WorkerState.gd 신규 const
const BRIDGE_TICK: float = 0.20
const BRIDGE_MAX_LENGTH: int = 8
var _bridge_floor_grace_used: bool = false

# enter()/update() 분기 (builder 패턴 답습)

func _enter_bridge(a: Ant) -> void:
    _remaining = BRIDGE_MAX_LENGTH
    _tick_accum = 0.0
    _aborted = false
    _bridge_floor_grace_used = false
    a.velocity = Vector2.ZERO   # 정지

func _update_bridge(a: Ant, delta: float) -> void:
    if _aborted or _remaining <= 0:
        a.state_machine.change_state(WalkerState.new())
        return
    # 정지 — velocity.x=0 유지, 중력만 적용.
    a.velocity.y += a.gravity * delta
    a.velocity.x = 0.0
    a.move_and_slide()
    # 벽 충돌 시 abort (builder 정책 답습).
    if a.is_on_wall():
        _aborted = true
        a.state_machine.change_state(WalkerState.new())
        return
    # v7 — floor-contact guard.
    # 첫 tile 전 off-floor는 1-frame grace만 허용하되 tile placement는 절대 수행하지 않는다.
    # tile 1개 이상 배치 후 off-floor이거나 grace 이후에도 off-floor이면 즉시 중단한다.
    # **Grace 재충전 정책 (v7 명시)**: 한 번 off-floor → grace 소비 후, ant가 다시 floor 위로
    # 안착(`is_on_floor() == true`)하면 `_bridge_floor_grace_used = false`로 reset되어 다음
    # off-floor 시 다시 1-frame grace 사용 가능. 의도: 물리 simulation의 1-frame 진동
    # (move_and_slide 직후 한 frame off-floor → 다음 frame 정상 안착)을 abort 시키지 않으면서도,
    # 진짜 fall (연속 off-floor frame)은 grace 소비 후 즉시 abort. tile placement는 항상
    # `placed_count == 0 AND grace_used == false` 분기로만 skip되고 actual placement는 차단됨.
    if not a.is_on_floor():
        var placed_count: int = BRIDGE_MAX_LENGTH - _remaining
        if placed_count == 0 and not _bridge_floor_grace_used:
            _bridge_floor_grace_used = true
            return
        _aborted = true
        a.state_machine.change_state(WalkerState.new())
        return
    _bridge_floor_grace_used = false   # 안착 → grace 재충전 (위 주석 참조)
    _tick_accum += delta
    while _tick_accum >= BRIDGE_TICK and _remaining > 0 and not _aborted:
        _tick_accum -= BRIDGE_TICK
        if _far_side_floor_reached(a):
            _aborted = true   # 정상 종료 (반대편 floor 도달)
            break
        _place_bridge_tile(a)
    if _aborted or _remaining <= 0:
        a.state_machine.change_state(WalkerState.new())

func _far_side_floor_reached(a: Ant) -> bool:
    # ant 진행 방향 다음 cell의 발 밑 row에 floor가 있는지 검사.
    # Terrain.has_tile만으로는 StageLayoutBuilder 정적 cell을 볼 수 없으므로 사용하지 않는다.
    # Layer 1 physics ray가 Terrain 동적 tile과 StageLayoutBuilder 정적 cell을 모두 감지해야 한다.
    # 발 위치에서 direction 방향 cs+2 px forward → 거기서 아래로 cs+4 px ray.
    # collision이 있으면 floor 존재 = 반대편 floor 도달.
    var terrain: Terrain = _find_terrain(a)
    if terrain == null:
        return false
    var cs: int = terrain.cell_size   # v2 dynamic read
    var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
    if space == null:
        return false
    var feet: Vector2 = a.global_position + Vector2(0, 2)
    var forward_target: Vector2 = feet + Vector2(float(a.direction) * (cs + 2), 0)
    var down_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
        forward_target,
        forward_target + Vector2(0, cs + 4),
        1   # Layer 1 (floor mask)
    )
    down_query.exclude = [a.get_rid()]
    var hit: Dictionary = space.intersect_ray(down_query)
    return not hit.is_empty()

func _place_bridge_tile(a: Ant) -> void:
    var terrain: Terrain = _find_terrain(a)
    if terrain == null:
        _aborted = true
        return
    var cs: int = terrain.cell_size   # v2 dynamic read
    var cell: Vector2i = Vector2i(
        int(floor(a.global_position.x / cs)),
        int(floor((a.global_position.y + 2.0) / cs))
    )
    var target: Vector2i = cell + Vector2i(a.direction, 0)
    var ok: bool = terrain.add_tile(target)
    if not ok:
        _aborted = true
        return
    a.global_position += Vector2(float(a.direction) * cs, 0.0)
    _remaining -= 1
```

**Bridge 동작 도식** (갭 4 cells, MAX_LENGTH=8):
```
초기:                                tick 4 후 (갭 4 cells 통과):
👤                          👤                    
═══floor═                   ═══floor═══tile═tile═tile═tile═════floor═══
                                       ↑far_side_floor 감지 → 자연 종료
        ____gap 4 cells____           ↑ant 위치
        ════════════════floor═══
```

### 4.3 분기 dispatch 라우터 (enter/update if/elif)

`WorkerState._init(work_type)`: `_work_type = work_type` (기존). 신규 work_type 추가는 enter/update 두 곳의 if/elif 체인에만.

```gdscript
func enter() -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    if _work_type == "builder":
        _enter_builder(a)
    elif _work_type == "blocker":
        _enter_blocker(a)
    elif _work_type == "sand_mound":
        _enter_sand_mound(a)
    elif _work_type == "bridge":
        _enter_bridge(a)
    else:
        _aborted = true

func update(delta: float) -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    if _work_type == "blocker":
        _update_blocker(a, delta)
        return
    elif _work_type == "sand_mound":
        _update_sand_mound(a, delta)
        return
    elif _work_type == "bridge":
        _update_bridge(a, delta)
        return
    # builder 기본 분기 (기존 로직 유지)
    ...

func exit() -> void:
    if _work_type == "blocker":
        var a: Ant = ant as Ant
        if a != null:
            a.set_blocker_active(false)
    # sand_mound/bridge는 terminal cleanup 불필요 — Walker 복귀 시 자연 해제
```

### 4.4 D8 좌표 겹침 — first-place wins (Terrain.add_tile 단일 진입점, **v2 — stage occupancy 통합**)

**v2 변경 (F-R1-H1 대응)**: `Terrain`이 동적 cell (`_placed`)과 정적 stage cell (`_static_occupancy`) 양쪽을 통합 추적. `add_tile()`은 둘 중 하나라도 점유 시 false 반환 → 동적·정적 cell 양쪽에 first-place wins 적용.

```gdscript
# Terrain.gd (v2)
var cell_size: int = 16   # default fallback; StageLayoutBuilder가 set_cell_size로 갱신
var _placed: Dictionary = {}              # 동적 cell (sand_mound/bridge/builder가 추가)
var _static_occupancy: Dictionary = {}    # 정적 cell (StageLayoutBuilder가 등록)

func set_cell_size(s: int) -> void:
    if s > 0:
        cell_size = s

func register_static_cell(cell: Vector2i) -> void:
    # idempotent — 중복 register OK.
    _static_occupancy[cell] = true

func add_tile(cell: Vector2i) -> bool:
    # v2: 정적/동적 둘 중 하나라도 점유면 reject.
    if _placed.has(cell) or _static_occupancy.has(cell):
        return false
    var body: StaticBody2D = StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    var shape: CollisionShape2D = CollisionShape2D.new()
    var rect: RectangleShape2D = RectangleShape2D.new()
    rect.size = Vector2(cell_size, cell_size)   # v5: const → dynamic
    shape.shape = rect
    body.add_child(shape)
    var sprite: Sprite2D = Sprite2D.new()
    if _bridge_tile_texture == null:
        _bridge_tile_texture = load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D
    sprite.texture = _bridge_tile_texture
    var scale_factor: float = float(cell_size) / 16.0   # v5: 16px native → proportional scale
    sprite.position = Vector2(0, -13.0 * scale_factor)
    sprite.scale = Vector2(scale_factor, scale_factor)
    body.add_child(sprite)
    body.global_position = Vector2(
        float(cell.x) * cell_size + cell_size / 2.0,
        float(cell.y) * cell_size + cell_size / 2.0
    )
    add_child(body)
    _placed[cell] = body
    return true
```

```gdscript
# StageLayoutBuilder.gd (v5 — build() 끝 부분 추가, v3에서 도입)
func build() -> void:
    _clear_children()
    if layout == null:
        return
    var generated_cells: Array[Vector2i] = []
    for key in _layout_tile_map().keys():
        var c: Vector2i = _cell_from_key(str(key))
        _add_cell(c, str(_layout_tile_map()[key]))
        generated_cells.append(c)
    # v3: ancestor에서 Terrain 발견 시 cell_size 동기화 + static cells register.
    var terrain: Terrain = _find_ancestor_terrain()
    if terrain != null:
        terrain.set_cell_size(int(layout.cell_size))
        for c in generated_cells:
            terrain.register_static_cell(c)
    else:
        push_warning("StageLayoutBuilder could not find Terrain; cell_size/static occupancy registration skipped")

func _find_ancestor_terrain() -> Terrain:
    # Ant._resolve_mantle_distance 패턴 답습 — ancestor 스캔, 첫 Terrain 매치.
    var node: Node = self
    while node != null:
        var t: Terrain = node.get_node_or_null("Terrain") as Terrain
        if t != null:
            return t
        if node is Terrain:
            return node as Terrain
        node = node.get_parent()
    return null
```

- 후속 작업자(`_place_sand_mound_tile`/`_place_bridge_tile`/builder)에서 `add_tile == false` 받으면 `_aborted=true` → WalkerState 복귀. **dynamic↔dynamic** 겹침은 `SandBridgeOverlapTest`로, **dynamic↔static** 겹침은 신규 `BridgeRejectStageCellTest` (§2.5)로 회귀 가드.
- 정적 cell 자체는 phase 16에서 unregister/destroy 미지원 — 파괴 메카닉(phase 18) 진입 시 별도 결정 (현재는 `_static_occupancy.erase(cell)` 메서드도 미신설, YAGNI).

---

## 5. 검증 stage 설계

> **공통 정책**: 본 §5의 layout은 **설계 의도 + 핵심 cell만 명시**. 픽셀 정밀 cell 좌표(특히 ant 시작 위치에서 sand_mound 시도 시 정확한 cell 정합 — `floor((y+2)/cell_size)` 결과 vs MAX_HEIGHT vs 상부 platform y)는 구현 시 dev 수동 검증으로 미세 조정한다. 본 plan은 검증 명제와 cell_size·constants 만 고정.

### 5.1 dev_sand_mound_layout — 설계 의도 (cell_size=32, vertical pillar)

**구조** (도식 schematic, 정확한 좌표는 구현 시 확정):
```
y\x  0    5    10        20   25         35
                                                
upper▓▓▓▓▓▓▓▓▓▓ (column) ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  # 상부 platform
                                                
                                                 # gap rows (5 cells 정확)
                                                
ground▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  # ground
      H            (sand_mound 시도점)        C
```

**검증 의도**:
- 갭 = 5 cells 정확히 (MAX_HEIGHT 매칭). 상부 platform은 ant가 sand_mound 컬럼 정상 위로 한 칸 우측 walker step으로 도달하도록 column x + 1 위치에서 시작.
- ant가 sand_mound 5번 stack 완료 후 walker 복귀 → 즉시 우측 평탄 진행 → candy 도달 → home 회수
- ground row 자체는 시각·낙하 안전망 역할

**핵심 데이터**:
- home_cell: ground 위 좌측 (≈ `(2, ground_y - 1)`)
- candy_cell: 상부 platform 위 우측 (≈ `(30, upper_y - 1)`)
- spawn_direction: 1 (오른쪽)
- camera_cell: 중앙 (≈ `(20, (ground_y + upper_y) / 2)`)
- ground_y, upper_y: 구현 시 확정 (제약: `ground_y - upper_y == 5`)

### 5.2 dev_bridge_layout — 설계 의도 (cell_size=32, 4 cells 폭 갭)

**구조** (도식, 정확 좌표는 구현 시):
```
y\x  0    5    10   15        20   25         35
                                                
left ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                          ▓▓▓▓▓▓▓▓▓▓ # 두 elevated platform 같은 y
                              gap (4 cells)              
                                                          
ground▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ # safety
      H                                                C
```

**검증 의도**:
- 갭 폭 = 정확히 4 cells (MAX_LENGTH=8 미만, 자연 종료 검증)
- ant가 좌측 platform 끝에서 bridge apply → 4 tiles 깔리고 우측 platform 직전 cell의 far_side floor 감지 → 종료 → walker 복귀 → 우측 platform 진행 → candy 도달
- 만약 갭=3 cells PASS 명제는 `tile_count == 3`으로 조정 (§7.3 ray 분석상 N-cell 갭이면 정확히 N tiles 적재 후 종료 — far_side_floor_reached는 마지막 tile의 다음 tick에 우측 platform 1 cell forward를 감지)
- ground row 자체는 시각·낙하 안전망 역할

**핵심 데이터**:
- home_cell: 좌측 platform 위 (≈ `(2, platform_y - 1)`)
- candy_cell: 우측 platform 위 (≈ `(30, platform_y - 1)`)
- 갭 위치: 좌측 platform 끝 x + 1 ~ 우측 platform 시작 x - 1 (4 cells)

### 5.3 dev_bridge_too_long_layout — 설계 의도 (cell_size=32, 12+ cells 폭 갭)

**구조** (도식):
```
y\x  0    5    10        15        20        25        30        35   40
left ▓▓▓▓▓▓▓▓▓▓▓▓                                                  ▓▓▓▓ # 두 platform 거리 멀음
                          gap (12+ cells)                              
ground▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ # safety
      H                                                            C
```

**검증 의도**:
- 갭 폭 ≥ MAX_LENGTH+4 = 12 cells (확실히 초과)
- ant가 좌측 끝에서 bridge apply → 8 tiles 깔림 (far_side 미감지) → MAX_LENGTH 소진 → 미완성 종료
- 8 tiles 끝에서 walker 복귀 → 절벽 → FallerState → safety ground 도달 → walker → 우측 platform 닿지 못함 → time_out fail
- **D7 잔재 유지 검증**: 8 tiles는 영구 보존 (terrain.tile_count() == 8)

### 5.4 dev_sand_bridge_overlap_layout — 설계 의도 (cell_size=32)

**구조**: 두 ant가 같은 cell에서 동시에 sand_mound 시도 (가장 단순한 D8 race 시나리오).

```
ground ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
       H A1A2                       C
        (두 ant 같은 cell에서 출발, 둘 다 sand_mound 적용)
```

**검증 의도**:
- A1과 A2가 같은 ant 발 cell 위에 spawn (또는 spawn 직후 동일 cell 도달)
- 둘 다 sand_mound 적용 → 첫 tick에 동일 target cell (둘 다 동일 발 cell 위 cell) add_tile 시도
- **D8 first-place wins**: 한 ant의 add_tile은 true, 다른 ant는 false → 다른 ant `_aborted=true` → WalkerState 복귀
- bridge skill도 inventory에 포함되어 있어 보조 시나리오로 한 ant sand_mound + 다른 ant bridge 시도 가능 (대안 검증 — 본 시나리오의 PASS 명제와 무관)

**핵심 PASS 명제** (sand_mound vs sand_mound race):
1. `terrain.tile_count() >= 1` (최소 1 cell 생성)
2. 60초 내 두 ant 모두 WorkerState 영구 stuck 없음 (둘 중 한 명은 sand_mound 진행, 다른 한 명은 즉시 WalkerState 복귀)
3. ScoreSystem 4-카운터 invariant 유지

**구현 시 fine-tune**: spawn parent (AntSpawner) 코드의 동일-frame multi-spawn 보장 여부 확인. 동일 frame 보장 안 되면 release_rate를 매우 높여 (e.g., 100/sec) 두 ant가 첫 frame에 spawn하도록 조정. 또는 dev script로 두 ant를 같은 cell에 강제 placement.

### 5.5 dev_id 점유 갱신표 (확정, v2)

| id | slug | phase |
|---|---|---|
| 901 | trait_test | 14 |
| 902 | settle_test | 15 |
| 903 | settle_test_stuck | 15 |
| 904 | settle_test_race | 15 |
| **905** | **sand_mound_test** | **16** |
| **906** | **bridge_test** | **16** |
| **907** | **bridge_too_long_test** | **16** |
| **908** | **sand_bridge_overlap_test** | **16** |
| **909** | **bridge_reject_test** | **16 (v2 신규 — F-R1-H1 회귀)** |

> **확인됨 (2026-05-23, `grep -E "^id\s*=" data/stages/dev/*.tres`)**: 901~904 점유. 905~909가 phase 16 신규 5건.

---

## 6. 시그널 흐름

신규 시그널 0건. 기존 시그널만 사용:

- `EventBus.candy_piece_picked` / `candy_piece_lost` / `ant_saved` / `candy_depleted` — 무영향 (sand_mound/bridge는 카운터 미발화)
- `Ant.bumped_blocker` — 무영향 (blocker hitbox 미사용)

신규 시그널 도입 시점: phase 20 polish에서 "bridge complete"/"sand_mound complete" UI feedback 필요 시.

---

## 7. 엣지 케이스 — 구현 중 빠뜨리면 안 되는 시나리오

### 7.1 Sand-mound 진행 중 위에 이미 cell 존재

- 시나리오: ant가 sand_mound 진행 중 5번째 tile 시도 시 그 cell이 이미 점유 (다른 작업물 또는 stage static cell)
- 처리: `terrain.add_tile()` false → `_aborted=true` → WalkerState 복귀. 이전 cells는 잔재 유지 (D7)
- 검증: `SandBridgeOverlapTest`에서 일부 커버. 별도 `SandMoundCollisionAbortTest` 신규는 phase 16 scope outside (생략)

### 7.2 Bridge 진행 중 측면 wall 충돌

- 시나리오: bridge 진행 중 forward direction에 stage wall이 있어 `_place_bridge_tile`의 add_tile은 성공하지만 그 다음 `move_and_slide` + 다음 tick의 `is_on_wall()` true → `_aborted=true`
- 처리: 기존 builder의 `is_on_wall` abort 패턴 답습. 잔재 유지

### 7.3 Bridge `_far_side_floor_reached` 검사 시점

- **검사 시점**: tile placement 직전, 매 tick. 이미 reach했으면 더 이상 tile 추가하지 않음.
- **Ray 도달 범위(v5 정정)**: ray는 `forward_target = feet + (direction*(cs+2), 0)` → down `cs+4` px. cs=32 기준 ant 발 기준 **1 cell forward**의 cell 윗면에서 36px 아래까지만 본다. 즉 1 cell 더 멀리 있는 floor만 감지 — 2 cells 이상 forward나 깊은 safety floor는 못 본다.
- **경계 케이스 (1 cell 갭, v5 정정)**: 갭 폭 1 cell에 bridge apply
  - tick 1: ant가 좌측 platform 끝에 있음 → ray는 forward 1 cell(=갭 cell) 윗면에서 아래로 36px 만 본다. safety ground는 그보다 깊이 있으므로 ray miss → false → tile 1개 추가 (갭 cell). ant 1 cell 우측 이동.
  - tick 2: ant가 갭 cell 위에 있음 → ray는 forward 1 cell(=우측 platform 시작 cell) 윗면에서 아래로 36px → 우측 platform top 즉시 hit → true → break. **종료 시 tile_count == 1.**
  - 헤드리스 검증 명제: 1 cell 갭에서 `tile_count == 1`. (0이 아님 — 이전 v4까지 "0 valid" 문구는 오류였다.)
- **2+ cell 갭**: 1 cell 갭과 동일 패턴 — 매 tick 1 tile 추가, ant 1 cell 우측 이동. 우측 platform 1 cell forward 도달 시 false→true 전환 + break. 최종 `tile_count == 갭_폭` (≤ MAX_LENGTH).
- 더 보수적 정책: 1 cell 갭은 bridge 적용 자체가 의미 없음 — 그러나 can_apply에서 갭 검사 추가는 복잡도 증가. MVP: 1 cell tile 잔재도 D7 정책상 valid abort 결과로 수용.

### 7.4 Sand-mound 5 cells stack 후 ant가 wall 옆에 위치

- 시나리오: sand_mound로 5 cells 위로 올라간 후 좌우에 wall (다른 platform 측면)이 있어 walker가 즉시 wall로 인해 flip 반전
- 처리: 정상 동작. ant는 새 platform 위에서 walker 진행 → wall 만나면 flip → 다른 방향 진행. 게임 로직 무영향.
- 검증: `SandMoundClimbTest`에서 ant가 sand_mound 완료 후 우측 walker 진행 + top platform 진입까지 검증.

### 7.5 Bridge 작업 중 ant가 fall (예: bridge 자체에 ant가 떠있다가 안 잡힘)

- 시나리오 분석: bridge는 `velocity.y += gravity * delta` + `move_and_slide()` → ant는 매 tick floor 검사로 platform 위 stable. 단 첫 tick에 ant가 cliff edge에 위치 + bridge tile이 ant 발 밑 cell이 아닌 forward cell에 추가 → ant는 platform edge에 stable 유지, forward로 한 칸 이동 후 새 bridge tile 위에 stable.
- 위험 케이스: ant가 cliff 직전 cell에 위치 + bridge apply 첫 tick에 add_tile은 forward cell에 성공 + ant는 그 forward cell로 이동 → 정상.
- 위험 케이스 2: 작업 중 ant가 어떤 이유로 fall (예: bridge 아래 floor가 갑자기 사라짐 — phase 16에는 일어나지 않지만 강제 lift 등 인위적 케이스 + 미래 hazard 도입 시) → `_update_bridge`가 `is_on_wall` 검사만 두면 떨어지면서도 작업 계속 시도. **위험**: ant가 떨어지는 동안 bridge tile들이 공중에 깔리고 D7 잔재 정책상 영구 보존.
- **처리 (v7 — R3-H1 fix)**: `_update_bridge`에 floor-contact guard 도입. `placed_count = BRIDGE_MAX_LENGTH - _remaining`로 tile 배치 여부를 계산한다. `placed_count == 0`이고 `_bridge_floor_grace_used == false`이면 1-frame grace로 return하지만, 이 frame에서는 `_tick_accum += delta`와 placement loop를 모두 건너뛴다. 다음 update에도 off-floor이면 `_aborted=true`로 중단한다. `placed_count > 0` 상태에서 off-floor이면 grace 없이 즉시 중단한다. 회귀 검증: `tests/BridgeFirstTickOffFloorAbortTest`(첫 tile 전 off-floor) + `tests/BridgeFallAbortTest`(tile 배치 후 off-floor).
- **Grace 재충전 정책 (v7 — N3 명시)**: 한 번 off-floor → grace 소비 후 ant가 다시 floor 위로 안착하면 placement loop 진입 직전에 `_bridge_floor_grace_used = false`로 reset된다(§4.2 snippet 마지막 line). 즉 bouncing(off-floor 1 frame → on-floor 1 frame → off-floor 1 frame …)이 발생해도 매 off-floor cycle마다 grace 1회 사용 가능. 이는 의도된 동작이며, 물리 simulation의 1-frame off-floor 진동을 false abort로부터 보호한다. **tile placement는 절대 off-floor frame에서 실행되지 않는다**(grace 사용 frame은 return으로 skip, abort frame은 placement loop 진입 전 종료). 진짜 fall은 연속 off-floor 2 frame으로 즉시 abort된다.
- **sand_mound**: ant가 sand_mound 중 떠있을 수 있는 시점은 1 tile 추가 직후 ant 이동 1 cell 위로 (`global_position.y -= terrain.cell_size`) → 다음 frame에 `move_and_slide` 후 새 tile 위에 stable. 그러나 sand_mound는 본질적으로 ant를 위로 들어올리는 작업이라 "fall scenario" 자체가 phase 16에서 비현실적 (외부 강제 lift 없이는 발생 불가). MVP: sand_mound는 가드 미도입 (Builder 동일 패턴). 위험은 hazard 도입 phase 17에서 sand_mound도 동일 가드 적용 여부 재검토.
- **builder**: 기존 코드 무변경 (회귀 위험 회피). Builder fall scenario는 phase 17에서 sand_mound와 함께 일괄 재검토.

### 7.6 SandBridgeOverlapTest의 race condition

- 두 ant가 같은 frame에 sand_mound 적용 → 같은 tick에 동일 cell add_tile 시도 → Godot의 `_physics_process` 호출 순서에 따라 한 ant가 먼저 → 두 번째 false. 순서는 SceneTree의 자식 노드 등록 순서에 결정론적 (AntSpawner의 spawn 순서).
- 검증 PASS 명제: `tile_count >= 1` + 두 ant 모두 WorkerState→WalkerState 복귀 (무한 stuck 없음).

---

## 8. 검증 방법 (frontmatter doc §"검증 방법" 매핑)

### 8.1 자동 회귀 (모두 PASS 필수, v7 갱신)

기존 (phase 1~15 전체 회귀):
- `tests/Stage01HeadlessTest.tscn` / **`tests/Stage02HeadlessTest.tscn` (v2 — Builder backward-compat 회귀 가드, F-R1-H2 후속)** / Stage03
- `tests/BlockerOverlapTest.tscn`
- `tests/ClimberStallTest.tscn` / `ClimberBlockerOverlapTest` / `ClimberBlockerOverlapStallTest` / `ClimberTraitTest`
- `tests/FloaterTraitTest.tscn`
- `tests/DistributorSettleTest` / `DistributorCarryingPriorityTest` / `SettlementTraitTransferTest` / `SettlementHundredPercentStuckTest` / `SettlementSameFrameRaceTest`
- 기타 UI 관련 회귀 (AtomShowcaseTest, CButtonGhostShadowTest, CursorTargetingTest 등)

**v4 회귀 가드 강조**: Stage02HeadlessTest는 Builder가 terrain.cell_size 변경 후에도 동일 동작(16px tile 12개 placement)을 유지하는지 검증한다. Stage 02는 StageLayoutBuilder 미사용 → terrain.cell_size는 default 16 유지 → Builder 동작 식별. 만약 Stage02HeadlessTest가 깨지면 **즉시 plan revision 트리거** (Builder 회귀 = F-R1-H2 처리 실패).

신규 (phase 16):
- `tests/SandMoundClimbTest.tscn` — sand_mound로 ant 상승 + candy 도달
- `tests/SandMoundMaxHeightTest.tscn` — MAX_HEIGHT=5 정확 + abort
- `tests/BridgeGapCrossTest.tscn` — bridge로 갭 가로지름 + 자연 종료 (far_side_floor)
- `tests/BridgeGapTooLongTest.tscn` — MAX_LENGTH=8 도달 + 미완성 + 잔재 유지 (D7)
- `tests/SandBridgeOverlapTest.tscn` — D8 first-place wins (dynamic↔dynamic)
- **`tests/BridgeRejectStageCellTest.tscn`** — D8 first-place wins (dynamic↔static, F-R1-H1 회귀 가드)
- **`tests/DynamicTileCellSizeAlignmentTest.tscn`** — layout cell_size=32 stage에서 동적 tile world position이 정적 stage grid와 정렬됨을 검증 (F-R1-H2 회귀 가드)
- **`tests/BridgeFirstTickOffFloorAbortTest.tscn`** **(v7 신규)** — 첫 tile 전 off-floor 상태에서 tile placement가 발생하지 않음을 검증 (R3-H1 회귀 가드)
- **`tests/BridgeFallAbortTest.tscn`** **(v6 신규, v7 범위 축소)** — bridge tile 배치 후 강제 lift로 추가 tile placement가 중단됨을 검증 (R2-H1/R3-H1 mid-work 회귀 가드)

### 8.2 에디터 수동 검증

| Stage | 시나리오 |
|---|---|
| Stage 1~3 | 회귀 무영향 확인 — sand_mound/bridge SkillToolbar에 미노출 (available_skills 미포함) |
| `dev/SandMoundTest.tscn` | sand_mound apply → 5 cells stack → ant top platform 진입 → candy 도달 → home 회수. tile_count == 5 |
| `dev/BridgeTest.tscn` | bridge apply → 4 cells fill → far_side floor 감지 → 자연 종료. tile_count == 4 |
| `dev/SandBridgeOverlapTest.tscn` (수동) | 두 ant에 각각 sand_mound + bridge 동시 적용 → 한 ant만 진행, 다른 ant는 즉시 WalkerState 복귀. 잔재 cells 시각 확인 |

---

## 9. 톤 폴리시 점검 (§0.2 어휘)

본 plan/구현/테스트에서 사용 어휘:
- 허용 어휘만: "남김"(잔재 처리), "중단"(작업 종료), "사탕 손실"(페일), "임무 완수"(saved)
- 금지 어휘 검사 — `die()`, `DeadState`, "사망", "죽" — 본 plan에 없음 (DeadState 클래스는 §2.6 무변경 ban list에 명시, 기존 코드)
- `scripts/check_tone_policy.py`가 본 phase 신규 파일들에 대해 0 hit 보장 (구현 후 검증)

---

## 10. 사전 점검 (구현 시작 전)

### 10.1 dev_id 점유 — **확정 (2026-05-23)**

`grep -E "^id\s*=" data/stages/dev/*.tres` 결과:
- 901 trait_test, 902 settle_test, 903 settle_test_stuck, 904 settle_test_race
- phase 16 신규: 905 sand_mound_test, 906 bridge_test, 907 bridge_too_long_test, 908 sand_bridge_overlap_test

추가 확인 불필요 — §5.5 표 그대로 사용.

### 10.2 SkillToolbar 아이콘/라벨 매핑 — **방침 확정**

확인된 사실 (2026-05-23):
- `assets/icons/skills/` 디렉토리: blocker / builder / climber / basher / digger / miner / floater / bomber / distributor svg 존재. **`sand_mound.svg` / `bridge.svg` 미존재**.
- `scripts/ui/SkillToolbar.gd:14-24` `ICONS` dict는 `preload()` 사용 — 미존재 파일 path 추가 시 스크립트 compile fail. 따라서 ICONS dict에 새 키 추가는 svg 파일 도입 후에만 가능.

**phase 16 방침**: ICONS/KO_LABELS **무변경**. SkillToolbar는 다음 fallback으로 동작:
- `ICONS.get("sand_mound") -> null` → `SkillSlot.icon_texture = null` (아이콘 없는 슬롯)
- `KO_LABELS.get("sand_mound", "sand_mound") -> "sand_mound"` (영문 ID 라벨로 fallback)
- 본 phase 검증은 dev stage SkillToolbar UI를 거치지 않고 헤드리스 테스트가 `SkillRegistry.get_skill("sand_mound").apply(ant)` 직접 호출 → ICONS/KO_LABELS 매핑 없어도 검증 PASS 가능. 정식 아이콘/라벨 도입은 **phase 20 polish 영역**.
- 수동 검증(에디터에서 dev SandMoundTest 플레이) 시에도 슬롯이 영문 라벨로 보이는 것은 허용 — dev 자산이므로 UX 미완성 OK.

### 10.3 thin_cookie_bridge_tile.png 자산 존재 확인

```bash
ls assets/sprites/terrain/thin_cookie_bridge_tile.png
```

기존 Terrain.gd가 이미 사용 중이라 보장됨. 미존재 시 phase 9 sweep으로 확인.

---

## 11. 리스크 / 결정 보류 (v7 갱신)

| 리스크 | 영향 | 처리 |
|---|---|---|
| Sand-mound `_place_sand_mound_tile`의 ant 위치 cell 계산이 발 직하 cell 정확 매핑 안 됨 | sand_mound가 잘못된 cell에 stack → 시각 어긋남 또는 ant가 tile 안에 박힘 | 구현 시 dev SandMoundTest 수동 검증으로 cell 좌표 정확도 확인. 발 직하 계산은 `feet_y = ant.global_position.y + 2.0` 패턴 — builder와 동일 |
| Bridge `_far_side_floor_reached` ray cast의 layer mask 정확도 | bridge가 stage static cell 미감지 시 8 cells까지 무용 fill | StageLayoutBuilder의 cell collision_layer=1 확인 (이미 §StageLayoutBuilder.gd:46). ray mask=1 정합 |
| **(v7) Bridge 첫 update off-floor + 작업 중 ant fall** — 공중에 무한 tile 잔재 + D7 영구 보존 위험 | 사용자 가시 + D7 잔재 정책상 영구 공중 다리 | **v7 — `_update_bridge`에 floor-contact guard 포함** (§4.2 snippet). 첫 tile 전 off-floor는 1-frame grace로 placement loop를 건너뛰고, 다음에도 off-floor이면 중단. tile 배치 후 off-floor이면 즉시 중단. `tests/BridgeFirstTickOffFloorAbortTest` + `tests/BridgeFallAbortTest`로 회귀 검증. sand_mound는 가드 미도입 유지(작업이 본질적으로 ant를 위로 들어올리므로 fall scenario 부재 + Builder 동일 패턴) |
| Sand-mound MAX_HEIGHT=5가 stage layout 5-cell 갭 통과에 정확히 부족하거나 과잉 | 검증 stage 통과 실패 | layout 도식(§5.1)을 5 cells 정확히 맞춤 (R2-M1 fix — v5에서 §2.4/§2.5는 unify했지만 본 row가 4-cell 잔존했었음). 부족 시 layout 갭 1 cell 줄임 또는 MAX_HEIGHT=6 조정 (D2 재결정) |
| **(v4) Builder backward-compat 회귀** — Terrain.cell_size 변경 후 Builder가 다른 길이의 bridge 생성 | Stage 02 클리어 불가 → Stage02HeadlessTest FAIL | **Stage 01**: StageLayoutBuilder + stage01_layout.tres(cell_size 미설정 → StageLayoutData default=32) 사용 → terrain.cell_size=32로 갱신되지만 `stage01.tres`는 `available_skills` 미설정(skill UI 없음) → add_tile 호출자 0건 → 회귀 0건. **Stage 02**: StageLayoutBuilder 미사용 → terrain.cell_size=16 default 유지 → Builder 동작 식별. **Stage 03**: StageLayoutBuilder 미사용(inline StaticBody2D 플랫폼) → terrain.cell_size=16 default 유지 → Builder 동작 식별. 가정 검증은 `tests/Stage02HeadlessTest` + `tests/Stage03HeadlessTest`로 explicit 회귀 — FAIL 시 즉시 plan revision 트리거 |
| **(v2) StageLayoutBuilder._find_ancestor_terrain이 잘못된 Terrain을 찾음** | 잘못된 cell들이 register → add_tile false alarm 또는 stage cell 누락 | ancestor scan은 Ant._resolve_mantle_distance 검증된 패턴 답습. terrain 다중 인스턴스 stage 부재 (전 stage 1개) — 위험 낮음. 헤드리스 테스트(`BridgeRejectStageCellTest`)가 false alarm 발생 시 발견 |
| **(v4) StageLayoutBuilder가 build() 끝에서 Terrain을 못 찾음** | static cells 미등록 → add_tile이 stage cell 위에 placement 허용 (F-R1-H1 재발) | Phase 16 dev stages 모두 StageLayoutBuilder + Terrain 둘 다 인스턴스화. 미발견 시 `push_warning()`을 출력하고, `BridgeRejectStageCellTest`가 동적↔정적 reject 실패(`tile_count > 0`)로 잡는다. 향후 stage가 Terrain 없이 layout만 사용하면 register 생략은 허용하되, 생성 스킬 검증 stage에는 Terrain 필수 |

---

## 12. 표준 절차 진행

- 본 plan v1 작성 후 codex `/codex:adversarial-review --wait "phase 16 plan: Sand-mound + Bridge creation, first-place D8, gap auto-detect"` 실행
- stdout → `phases/mvp/reviews/phase16-plan-review.md`
- HIGH/CRITICAL 1건 이상 → **즉시 작업 중단 + 사용자 보고**. CLAUDE.md plan stage 정책 준수
- HIGH 0건 → 구현 진입 (Step 5)
- 구현 → 자체 적대적 리뷰 사이클 → codex 재리뷰 (impl stage) → clean → `python scripts/execute.py mvp complete 16`
- 완료 직전 Notion DB phase 16 → 완료
