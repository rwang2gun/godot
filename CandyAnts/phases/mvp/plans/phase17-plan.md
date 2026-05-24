# Phase 17 Plan — mechanic-hazard (v4)

**Status**: plan v4 — codex Round 1 HIGH 2건(H1 multi-hazard registry + H2 overlap test 순서 의존) 사용자 결정으로 inline fix 적용. Round 2 HIGH 1건(R2-H1 stale D3 Water-first contract) 사용자 요청으로 inline fix 적용. H1=Multi-hazard storage `Dictionary<Vector2i, Array[HazardBase]>`로 변경, H2/R2-H1=WaterStickyOverlap invariant를 terminal=Lost + ScoreSystem invariant로 통일하고 `_sticky_remaining` transient는 비결정으로 명시. codex Round 3 adversarial-review 직전. plan-stage 정책: HIGH 1건 발견 시 즉시 중단 + 사용자 결정. MEDIUM/LOW만 inline 처리 또는 명시 defer.
**Phase frontmatter doc**: [phases/mvp/phase17-mechanic-hazard.md](../phase17-mechanic-hazard.md)
**1차 SoT 인용**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §3.3 (Hazard) / §3.3.1 (Water) / §3.3.2 (끈끈이) / §3.3.3 (엣지 케이스) / §3.5 (4-카운터 무변경) / §0.2 (어휘 정책) / §0.7.5 (stuck-until-timeout)
**관련 코드 SoT**: `scripts/core/EventBus.gd` (`candy_piece_lost(by_ant: Node)` 시그널 기존 보유), `scripts/core/ScoreSystem.gd` (`_on_lost` handler 기존 wired, ADR-002 4-카운터), `scripts/ui/HUD.gd` (Lost counter 기존 wired), `scripts/ant/Ant.gd` (traits dict / `is_alive()` / `effective_speed()` / TraitBadges 패턴), `scripts/ant/states/` (Walker/Carrying/Faller/Climber/Worker/Saved/Dead/Settled 진입 후보), `scripts/world/Terrain.gd` (phase 16 `_static_occupancy` 패턴 + Bridge × hazard 통합점), `scripts/world/StageLayoutBuilder.gd` (cell_to_world), `scripts/world/SettlementMarker.gd` (scene-side Area2D 자체 register 패턴), `scripts/world/StageLayoutData.gd` (phase 17 신규 hazard cell 필드는 미추가 — SettlementMarker처럼 scene-side instance)
**리뷰 보존**: [phases/mvp/reviews/phase17-plan-review.md](../reviews/phase17-plan-review.md) (codex round별 누적)
**작성**: 2026-05-24 (v1), 2026-05-24 (v2 — self-review fix), 2026-05-24 (v3 — codex Round 1 HIGH 2건 fix), 2026-05-24 (v4 — codex Round 2 HIGH 1건 fix)

---

## 0.00 v3 → v4 변경 (codex Round 2 needs-attention HIGH 1건 대응)

| # | 항목 | v3 | v4 | finding |
|---|---|---|---|---|
| R2-H1 | §1.1 D3 Water + 끈끈이 겹침 결정 row | D3 canonical decision row가 여전히 "Water 우선" + StickyHazard가 LostState 가드로 무시되어 sticky timer 미발동이라고 서술. §0/§6.4/테스트 표의 relaxed invariant와 충돌 | **D3를 §6.4와 동일한 계약으로 재작성**: 같은 cell Water+Sticky의 Area2D `body_entered` 발화 순서는 미정. Water-first면 `_sticky_remaining == 0`, Sticky-first면 `_sticky_remaining > 0` transient 가능. 두 경우 모두 같은 frame Water 처리 후 LostState terminal + ScoreSystem invariant만 결정론적 acceptance. dev layout/strict acceptance의 stale "Water 우선" 표현도 제거 | codex R2-H1 [high] — D3 still specifies rejected Water-first invariant |

---

## 0.0 v2 → v3 변경 (codex Round 1 needs-attention HIGH 2건 대응)

| # | 항목 | v2 | v3 | finding |
|---|---|---|---|---|
| R1-H1 | §2.2 + §5.1 + §5.4 Terrain `_hazards_by_cell` 저장 구조 | `Dictionary<Vector2i, HazardBase>` 단일 hazard. register_hazard_at_cell이 중복 시 push_warning + skip → 후속 register는 무시. 같은 cell의 Water+Sticky 중 먼저 register된 것만 _hazards_by_cell에 보관 → deactivate_hazards_at은 그 첫 번째만 비활성 → Bridge가 Sticky만 비활성하고 Water가 monitoring 유지하는 경로 가능 → ant가 bridge 통과 시 여전히 LostState (D8 정책 무효화) | **`Dictionary<Vector2i, Array[HazardBase]>` Array 저장 구조로 변경.** register_hazard_at_cell이 cell의 Array에 append (중복 instance만 idempotent skip). deactivate_hazards_at은 cell의 모든 hazard 일괄 set_active(false). same-cell overlap layout(§6.4)에서 Bridge가 두 hazard 모두 deactivate → D8 정책 robust. push_warning 제거 (multi-hazard가 정상 정책으로 승격). **신규 회귀 테스트 `BridgeOverWaterStickyOverlapTest`**: bridge 적용 후 같은 cell의 Water + Sticky 모두 monitoring=false 검증 (registration 순서 무관) | codex R1-H1 [high] — single hazard registry breaks D8 under overlap |
| R1-H2 | §2.6 WaterStickyOverlapWaterWinsTest invariant | **PASS**: ant.is_alive() false + lost_pieces 검증 + `_sticky_remaining` 미설정 검증(test driver가 ant queue_free 직전 frame에 캡처) — Sticky timer 미설정이 acceptance에 포함 | **invariant 완화**: PASS = (1) ant.is_alive() false (queue_free 완료), (2) lost_pieces 변화량이 carrying 여부와 일치, (3) ScoreSystem invariant 유지. **`_sticky_remaining` 검증 제거** — Godot signal queue 순서 비결정성으로 Sticky가 먼저 발화하면 apply_sticky가 동작 → `_sticky_remaining > 0` 가능 (그러나 같은 frame Water 발화 시 LostState 전이 → ant queue_free). 최종 terminal=Lost는 결정론적이므로 그것만 검증. 테스트 이름도 `WaterStickyOverlapWaterWinsTest` → **`WaterStickyOverlapLostTerminalTest`** 로 변경(이름 정합). §6.4 narration도 'Water wins' 표현 제거 → 'either Water or Sticky may fire first; terminal Lost is deterministic' 표현 | codex R1-H2 [high] — overlap test asserts Godot signal order side-effect |

> v3 본체(§1~§9)는 v2의 design을 보존하고 R1-H1/H2 fix에 한해 inline 수정한다. D8 정책 자체는 v2와 동일(Bridge가 같은 cell의 hazard를 deactivate), 저장 구조와 deactivate 범위만 Array 일괄로 확장. v4에서 D3 canonical row까지 §6.4와 일치하도록 정정 — same-cell Water+Sticky의 terminal Lost만 결정론, `_sticky_remaining` transient는 비결정.

---

## 0.1 v1 → v2 변경 (self-review pass)

| # | 항목 | v1 | v2 | finding |
|---|---|---|---|---|
| H-self-1 | §5.1 Terrain.deactivate_hazards_at + §6.3 Bridge over Water 도식 | `deactivate_hazards_at(target)` 1회 호출, 도식상 Water가 floor row(y=23)에 표시 | **placement helper로 분리**: `Terrain.deactivate_hazards_for_placement(target)` 신설 — 내부에서 `target` + `target + Vector2i(0, -1)` 두 cell 모두 비활성. Hazard cell은 **항상 ant body row (y=floor-1)**로 통일 — Area2D body_entered가 ant body cell 진입 시 발화하므로. Bridge tile target은 floor row(y=23), hazard는 body row(y=22) → helper의 `target + (0,-1)` 분기가 매칭. §6.1~§6.4 도식 모두 hazard 좌표를 body row로 정정. §5.2 WorkerState `_place_*_tile` 3종 모두 helper 호출 | self-review HIGH — Bridge×Water deactivate 미매칭으로 D8 무효화 |
| M-self-1 | §3.1 HazardBase D13 state 가드 | `if s is SavedState or s is DeadState or s is SettledState or s is LostState: return` (신규 코드 `Dead` 직접 참조 — §0.2 어휘 정책 위반 borderline) | **`if not ant.is_alive(): return`** 1줄로 단순화 — Ant.is_alive()가 이미 4 terminal state 검사. 신규 코드(HazardBase)에서 `Dead` 식별자 0건 | §0.2 어휘 정합 + DRY |
| L-self-1 | §3.1 HazardBase snippet | `var name_str: String = s.get_class() if s != null else ""` (사용 안 함, dead variable) | 삭제 | cosmetic |

---

## 0. 한 줄 요약 (v4)

Hazard 시스템 1차 도입. **`scripts/world/hazards/HazardBase.gd`** Area2D 베이스(자체 cell 캐싱 + Terrain.register 자체 호출) + **`WaterHazard.gd`**(body_entered → 사탕 손실 + ant 제거) + **`StickyHazard.gd`**(body_entered → `ant.apply_sticky(STICKY_DURATION)`)를 신설한다. Ant 측은 **`LostState`** 신규 terminal(enter()에서 candy_piece_lost emit + queue_free — §0.2 어휘 정책 준수, 기존 `DeadState`·`ant_died` 재사용 안 함)과 **`_sticky_remaining`/`apply_sticky`/`is_stuck`** API를 추가한다. WalkerState·CarryingState는 update 첫 줄에서 `if a.is_stuck(): a.velocity.x=0; move_and_slide(); return` 조기 return으로 정지 표현 (FallerState는 stuck 무영향 — 이미 공중 낙하 중). Ant는 매 physics frame `_sticky_remaining = max(0, _sticky_remaining - delta)`로 timer 감소 + StickyBadge 시각. **Bridge × Water 상호작용**(phase 16 D9 deferred 해소): `Terrain.deactivate_hazards_at(cell)` + `Terrain.deactivate_hazards_for_placement(target)` 신설 — helper는 `target` + `target + Vector2i(0, -1)` 두 cell 모두 처리(v2: hazard cell은 ant body row, Bridge tile target은 floor row라 별개 cell이므로). **v3**: `_hazards_by_cell`을 `Dictionary<Vector2i, Array[HazardBase]>` Array 저장으로 변경 — same-cell overlap(Water+Sticky 등) layout에서도 deactivate_hazards_at이 cell의 모든 hazard 일괄 set_active(false). `WorkerState._place_bridge_tile / _place_sand_mound_tile / _place_one_tile(Builder)`이 add_tile 직후 helper 호출. ScoreSystem 4-카운터(ADR-002) **무변경** — `_on_lost`가 이미 EventBus.candy_piece_lost 구독. HUD Lost counter도 **무변경** — 이미 wired (`scripts/ui/HUD.gd:27`). dev 검증 stage 4종(water·sticky·bridge_over_water·water_sticky_overlap) + 헤드리스 회귀 11종 신설(v3 Multi-hazard 검증 1종 추가). **톤 폴리시 §0.2**: 모든 신규 식별자·문자열·문서 어휘는 "사탕 손실"/"탈락"/"정지" 등 허용 어휘만 사용 — 기존 `DeadState`/`ant_died` 잔존은 PROPOSAL §7.5 별도 작업으로 분리되어 본 phase 무수정. v2 HazardBase D13 가드는 `not ant.is_alive()` 단순화로 신규 코드 `Dead` 식별자 0건. **D3 same-cell overlap 정책 명시 (v4)**: 같은 cell의 Water+Sticky 진입 시 Godot Area2D body_entered 발화 순서는 비결정 — Water가 먼저면 `_sticky_remaining == 0`, Sticky가 먼저면 `_sticky_remaining > 0` transient 가능. **그러나 같은 frame Water 발화 → LostState 전이 → ant.queue_free**로 terminal=Lost는 결정론. WaterStickyOverlapTest는 terminal Lost + ScoreSystem invariant만 검증, _sticky_remaining 값은 비결정으로 명시(테스트 이름 `WaterStickyOverlapLostTerminalTest`).

---

## 1. Open decisions before implementation — 결정 (frontmatter doc §"Open decisions" 9건 + 본 plan 도출 6건)

> **Recommended** 표기는 사용자가 추천안을 채택하면 본 plan 명세 그대로 진행. redirect 시 v2에서 갱신.

### 1.1 PROPOSAL §3.3 derived 결정 (frontmatter doc 9건)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D1 | Water 깊이 (§3.3.1) | **단일 cell area** — 깊이=1 cell. `data/stage_layouts/*` 데이터에 water_cells: Array[Vector2i]만 필요(현재 plan은 scene-side 노드, layout 필드 미추가). 다단계 깊이는 시각 표현일 뿐 게임 로직(body_entered → 손실)은 동일 | 추천안. MVP 단순성(ADR-005·ADR-008). 다단계 추가 시 Stage scene complexity vs. gameplay 차이 0. 시각 다층은 phase 20 polish |
| D2 | Water 전파 속도 (§3.3.1) | **정적 (미전파)** — Water hazard 노드는 stage 시작 시 고정 좌표. 동적 propagation 없음. stage 데이터 override도 없음 | 추천안. ADR-008(빌드 누적형). 동적 transport는 추가 시스템(propagation tick, neighbor cell 검색, performance 고려) — phase 20 polish 또는 v1.1로 deferred |
| D3 | Water + 끈끈이 겹침 (§3.3.1) | **terminal Lost만 결정론** — 같은 cell에 두 hazard 존재 시 WaterHazard와 StickyHazard의 Area2D `body_entered` 발화 순서는 Godot가 보장하지 않는다. Water가 먼저 발화하면 LostState 전이 후 Sticky는 `not ant.is_alive()` 가드로 무시되어 `_sticky_remaining == 0`일 수 있다. Sticky가 먼저 발화하면 `ant.apply_sticky(duration)`으로 `_sticky_remaining > 0` transient가 생긴 뒤 같은 frame Water가 LostState 전이 + queue_free를 수행할 수 있다. 두 순서 모두 최종 acceptance는 terminal=Lost + ScoreSystem invariant 유지이며, `_sticky_remaining` 값은 검증 대상이 아니다 | 추천안. 사탕 손실은 즉시·terminal outcome. stuck은 살아있는 ant에만 의미가 있으나 same-frame transient 부작용은 신뢰하지 않는다. 같은 cell 배치를 stage assertion으로 차단하지 않음(layout 자유도 유지). 구현은 중앙 priority dispatcher를 두지 않고 최종 terminal과 점수 불변식만 보장 |
| D4 | 끈끈이 해방 (§3.3.2) | **시간 경과 자동 (default 3.0s)** — `Ant._sticky_remaining` 감소. stage 데이터 override는 본 phase 미도입(`StickyHazard.@export var duration: float = 3.0`로 노드 단위 override만 허용) | 추천안. Phase 19 Cutter는 별도 phase. timer 방식은 결정론·테스트 용이. Cutter 도입 시 `Ant.release_sticky()` 외부 API 추가(본 phase 미신설). 시간 경과 = puzzle 페이싱 단순화 |
| D5 | 끈끈이 위 정착 허용 (§3.3.2) | **허용** — SettledState는 terminal·is_alive=false. 끈끈이 stuck timer는 SettledState 진입 시 자연 무의미화(update 호출 안 되므로 effective_speed 무관). SettlementMarker가 분배자 stuck 중에 트리거되는 경로: 분배자가 끈끈이 cell 진입 → stuck. 같은/인접 cell의 SettlementMarker.body_entered도 같은 frame/시점에 발화 → has_candy=false 확인 후 정착 트리거 → SettledState. timer 처리는 LostState/SettledState 진입 시 reset 불필요(state가 update 안 받음) | 추천안. 별도 정착 차단 분기 없음 = 단순. 끈끈이 위 SettlementMarker 배치를 puzzle 디자인 옵션으로 부여 |
| D6 | 끈끈이 상태 능력 전이 허용 (§3.3.2) | **허용** — stuck 중 walker는 여전히 WalkerState (FallerState/WorkerState 아님). SettlementMarker.body_entered는 ant.state == WalkerState/CarryingState 가드만 검사 → stuck 여부 무관하게 전이 발생. 단 D8 (carrying > settlement) 가드는 그대로 — has_candy=true면 정착·전이 모두 무시 | 추천안. 별도 분기 없음. SettlementMarker는 state 기반 가드만, stuck은 velocity만 0 (state 변화 없음) |
| D7 | 끈끈이 시각·사운드 phase 범위 (§3.3.2) | **시각만 phase 17 (사운드 phase 20 polish로 deferred)** — Sticky.tscn 노드 자체의 ColorRect/Sprite2D 표식 + Ant.tscn TraitBadges 아래 `StickyBadge` Sprite2D(visible toggle on `_sticky_remaining > 0`). 파티클·SFX 없음 | 추천안. PROPOSAL §3.3.2 명시. Phase 17 핵심은 메카닉. 시각은 메카닉 검증에 필수 최소(플레이어가 stuck 인지)만 |
| D8 | Water 위 Bridge 생성 (§3.3.3) | **허용 + hazard 비활성** — `WorkerState._place_bridge_tile`이 `terrain.add_tile(target)` true 후 **`terrain.deactivate_hazards_for_placement(target)`** 호출 (v2 helper). helper 내부에서 `target` cell + `target + Vector2i(0, -1)` cell 두 곳 모두 set_active(false). **이유**: Bridge tile target은 floor row(y=23)지만 hazard는 ant body row(y=22)에 등록되어 별개 cell. 두 cell 모두 처리해야 매칭. Sand-mound도 동일 helper 적용 (target=body row이므로 target과 above 모두 비활성). **본 phase에서는 단방향** — bridge 제거 API 없음, hazard 재활성 미고려(phase 16 D4: sand_mound/bridge 자연 무너짐 없음) | 추천안. PROPOSAL §3.2.3 / §3.3.3 즉시 해소. Bridge는 게임플레이 핵심. v2 helper 추상화로 floor row vs body row 다중 cell 매칭 명시 (v1의 단일 cell 매칭은 매칭 실패 위험) |
| D9 | Hazard 위 능력 전이 발생 (§3.3.3) | **분기**: Water 위는 분배자가 즉시 LostState로 들어가므로 정착·전이 발생 X (자연 분기, 별도 코드 가드 없음). 끈끈이 위는 D5/D6에 따라 정착·전이 정상 | 추천안. 별도 hazard-aware 가드 없음 = 단순. D5/D6와 자연 정합 |

### 1.2 본 plan 도출 결정 (구현 디테일 6건)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D10 | Floater + Water 상호작용 (frontmatter doc 엣지 케이스) | **사탕 손실 정상 처리** — Floater trait는 FallerState에서 gravity 0.3배만 적용. WaterHazard.body_entered는 trait 무관 — Floater 보유 ant도 수면 진입 시 LostState. ant 상태/속도 trait는 hazard entry 결정에 무영향 | 추천안. PROPOSAL §3.3.3 명시. Floater는 낙하 속도만, hazard 면역은 아님 |
| D11 | Hazard 노드의 stage layout 통합 방식 | **scene-side instance — StageLayoutData 미수정** (phase 15 SettlementMarker 패턴 답습). `scenes/entities/hazards/Water.tscn`·`Sticky.tscn`을 Stage scene World 아래에 직접 인스턴스화. position은 layout.cell_to_world(hazard_cell)을 scene editor에서 직접 좌표 기록. StageLayoutBuilder는 hazard 자동 생성 X | 추천안. SettlementMarker와 패턴 일치. StageLayoutData 신규 필드(water_cells/sticky_cells) 도입 시 모든 stage data 회귀 영향(Stage01~03 + dev) — 단순성 vs 자동화 비용 |
| D12 | 신규 terminal state | **`LostState` 신설 — `scripts/ant/states/LostState.gd`**. enter()에서 `if a.has_candy: EventBus.candy_piece_lost.emit(a)` 후 `a.queue_free()`. exit() 없음(terminal). `Ant.is_alive()`에 `s is LostState` 분기 1건 추가 | §0.2 어휘 정책 — 기존 `DeadState` 재사용은 새 phase 17 코드에 "Dead" 식별자 도입. PROPOSAL §7.5는 기존 DeadState 잔존을 별도 작업으로 분리한 정책이므로 신규 코드만이라도 §0.2 정합. SavedState의 queue_free 패턴과 평행. 신규 1 파일 |
| D13 | Hazard double-entry idempotency | **`not ant.is_alive()` 가드 + Hazard 노드별 처리 ant set 캐싱** (v2 §0.2 어휘 단순화): HazardBase._on_body_entered가 `if not ant.is_alive(): return` 1줄로 terminal(Saved/Dead/Settled/Lost) 전부 차단 — Ant.is_alive()가 단일 진입점이므로 신규 코드(HazardBase)에서 `Dead`/`Saved` 식별자 0건. WaterHazard는 1회 발화 후 LostState 전이로 자연 차단. StickyHazard는 같은 hazard에 같은 ant 다중 body_entered 차단 위해 `_recently_processed: Dictionary` (Ant InstanceID → 마지막 처리 frame) — 같은 frame 중복 entry는 skip(set_deferred·signal 순서 race 대응) | 추천안. Candy(`if hp <= 0: return`)·Blocker(_active_blocker_overlaps)와 패턴 일치. SettledState도 (D5 정착 후) hazard entry는 무시 — Ant.is_alive() false라 자연 면역 |
| D14 | sticky stuck 중 추가 hazard 진입 처리 | **정상 처리** — stuck ant도 WalkerState 유지(state 미변경) → WaterHazard.body_entered가 entry시 발화 (단 stuck 중 ant velocity=0이라 새 hazard 진입 자체가 거의 없음, edge: stuck 도중 Water가 ant 좌표로 이동? — 본 phase Water 정적이라 발생 안 함). carrying ant가 stuck timer 끝나고 walker로 이동 후 Water 진입 시 정상 손실. 본 결정은 자연 분기 — 별도 코드 가드 없음 | 추천안. D13 state 가드로 LostState 진입 후 추가 발화 차단 자연 정합 |
| D15 | Hazard ↔ cell 매핑 정확도 | **cell = floor(global_position / cell_size), body row 배치 컨벤션** — Hazard `_ready()`에서 자체 좌표 + Terrain.cell_size로 cell 계산 후 `terrain.register_hazard_at_cell(cell, self)` 호출. Terrain.cell_size는 StageLayoutBuilder.build()이 set_cell_size 호출한 이후라야 정확 → Hazard._ready의 `await get_tree().physics_frame` 한 frame 지연 후 register (StageLayoutBuilder도 ready time build). **stage scene 좌표 컨벤션 (v2)**: hazard 노드의 global_position은 `layout.cell_to_world(Vector2i(x, floor_y - 1))` 즉 floor 위 ant body row에 배치 — Area2D body_entered가 ant body cell 진입 시 발화하므로 visual·trigger 일관. floor row(y=floor_y)에 hazard 배치 시 ant body cell이 그 위(y=floor_y - 1)이라 body_entered 미발화 위험 | 추천안. cell 계산 단순(정수 division). await physics_frame은 phase 15 SettlementMarker.body_entered와 패턴 일치. body row 컨벤션은 Bridge × hazard 매칭 명세(§5)와 정합 |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)
| 파일 | 용도 |
|---|---|
| `scripts/world/hazards/HazardBase.gd` | `class_name HazardBase extends Area2D`. 공통 베이스 — `_hazard_cell: Vector2i` 캐싱, `_active: bool = true` 토글, `_ready()`에서 await physics_frame 후 terrain ancestor scan + `register_hazard_at_cell(_hazard_cell, self)` 호출 + body_entered.connect(_on_body_entered). `set_active(active: bool)`: monitoring + CollisionShape.disabled + 시각 alpha (자식 sprite/colorrect.modulate.a). 추상 `_handle_ant_entry(ant: Ant)`는 서브클래스가 override. `_on_body_entered(body)` → ant 캐스팅·D13 state 가드·_active 가드 후 `_handle_ant_entry(ant)` |
| `scripts/world/hazards/WaterHazard.gd` | `class_name WaterHazard extends HazardBase`. `_handle_ant_entry(ant)`: `ant.state_machine.change_state(LostState.new())`. LostState.enter가 candy_piece_lost emit + queue_free 수행 |
| `scripts/world/hazards/StickyHazard.gd` | `class_name StickyHazard extends HazardBase`. `@export var duration: float = 3.0`. `_recently_processed: Dictionary = {}` (Ant InstanceID → frame). `_handle_ant_entry(ant)`: D13 frame-set 가드 후 `ant.apply_sticky(duration)`. body_exited에서 set entry 정리 (재진입 시 fresh trigger) |
| `scripts/ant/states/LostState.gd` | `class_name LostState extends AntState`. `enter()`: `var a := ant as Ant; if a == null: return; if a.has_candy: EventBus.candy_piece_lost.emit(a); a.queue_free()`. exit() 없음 |

### 2.2 수정 (.gd)
| 파일 | 변경 |
|---|---|
| `scripts/ant/Ant.gd` | (1) 신규 필드 `var _sticky_remaining: float = 0.0`, `var _sticky_badge: Sprite2D = null`. (2) `_ready()`에서 `_sticky_badge = _trait_badges.get_node_or_null("StickyBadge") as Sprite2D` (3) 신규 API: `apply_sticky(dur: float) -> void`: `_sticky_remaining = max(_sticky_remaining, dur)` (멱등 — 더 긴 timer 우선). `is_stuck() -> bool`: `_sticky_remaining > 0.0`. (4) `_physics_process(delta)` 최상단(state_machine.update 이전)에 `if _sticky_remaining > 0.0: _sticky_remaining = max(0.0, _sticky_remaining - delta)` 1줄. (5) `is_alive()` 분기에 `s is LostState` 추가: `return not (s is SavedState or s is DeadState or s is SettledState or s is LostState)`. (6) `_update_trait_badges()` 끝에 `if _sticky_badge != null: _sticky_badge.visible = is_stuck()` 1줄. 시각 전용 |
| `scripts/ant/states/WalkerState.gd` | `update(delta)` 최상단(velocity 갱신 이전)에 stuck 분기 추가: `if a.is_stuck(): a.velocity.x = 0.0; a.velocity.y += a.gravity * delta; a.move_and_slide(); return`. flip·climber·faller 분기 모두 skip. _frame 증가도 skip (stuck 중 grace 카운트 동결). 시각: WalkerState 유지(애니메이션은 `_update_sprite()`가 stuck-aware로 안 가도 walk 정지 표현 충분 — 단 stuck 상태 walk 애니메이션 멈춤 처리는 polish phase) |
| `scripts/ant/states/CarryingState.gd` | `update(delta)` 최상단에 동일 stuck 분기. has_candy=true 유지(stuck 중 사탕 보유). carry 애니메이션 정지는 polish |
| `scripts/ant/states/FallerState.gd` | **무변경** — 공중 낙하 중 stuck은 의미 약함(이미 정지된 hazard cell에 진입 자체가 안 됨, 끈끈이는 floor 인접 배치 컨벤션). FallerState에 stuck 분기 추가 시 영구 공중 stuck 위험 |
| `scripts/ant/states/ClimberState.gd` | **무변경** — climber는 벽 등반 중. stuck 진입 자체가 layout상 어려움(끈끈이는 floor cell). 추가 분기 시 영구 벽-stuck 위험 |
| `scripts/ant/states/WorkerState.gd` | (1) **`_place_bridge_tile(a)`** add_tile true 직후, `a.global_position += ...` 직전에 **`terrain.deactivate_hazards_for_placement(target)`** 1줄 추가 — D8 Water 위 Bridge 정책 (v2 helper, 내부에서 target + above 두 cell 처리). (2) **`_place_sand_mound_tile(a)`** 동일 추가 — target=body_cell. (3) **`_place_one_tile(a)`(Builder)** 동일 추가 — Builder도 Water 위 만들면 hazard 비활성 (Builder는 phase 3 자산이지만 같은 add_tile 경로라 일관 적용 — 회귀 0건, hazard 없는 stage는 helper no-op). (4) 별도 worker 분기 추가 없음 (sand_mound·bridge·builder 모두 같은 패턴) |
| `scripts/world/Terrain.gd` | (1) **v3 — 신규 필드 `var _hazards_by_cell: Dictionary = {}` (Vector2i → `Array[HazardBase]`)**. (2) `register_hazard_at_cell(cell: Vector2i, hazard: HazardBase) -> void`: cell의 Array에 hazard append (중복 instance만 idempotent skip — `if arr.has(hazard): return`). 첫 register 시 Array 신규 생성. (3) `deactivate_hazards_at(cell: Vector2i) -> void`: `_hazards_by_cell[cell]` Array 있으면 모든 hazard에 대해 `hazard.set_active(false)` 일괄 호출. 미존재 시 no-op. (4) **`deactivate_hazards_for_placement(target: Vector2i) -> void` (v2 helper)**: `deactivate_hazards_at(target)` + `deactivate_hazards_at(target + Vector2i(0, -1))` — placement 시 floor row + body row 모두 비활성. (5) 기존 `add_tile`/`has_tile`/`tile_count`/`cell_size`/`_static_occupancy` **무변경** |
| `scripts/core/EventBus.gd` | **무변경** — `candy_piece_lost(by_ant: Node)` 시그널 기존 보유. 새 시그널 0건 |
| `scripts/core/ScoreSystem.gd` | **무변경** — `_on_lost` handler 기존 wired. 4-카운터 invariant 기존 assert |
| `scripts/ui/HUD.gd` | **무변경** — Lost counter 이미 `_on_lost`에 connect (HUD.gd:27). EventBus.candy_piece_lost 발화 시 자동 갱신 |
| `scripts/core/StageLayoutData.gd` | **무변경** — hazard cell 필드 미도입(D11 scene-side instance) |
| `scripts/core/StageRunner.gd` | **무변경** — hazard는 World subtree. StageRunner는 clear/fail 조건 계산만 |
| `scripts/world/StageLayoutBuilder.gd` | **무변경** — hazard 자동 생성 안 함 (D11) |
| `scripts/world/SettlementMarker.gd` | **무변경** — D5/D6 정착·전이 정상 동작은 기존 SettlementMarker 코드 변경 없이 자연 분기. stuck 중 walker는 여전히 WalkerState이므로 SettlementMarker.body_entered 가드 통과 |
| `scripts/skills/*` | **전부 무변경** — Builder/Blocker/Climber/Floater/Distributor/SandMound/Bridge skill 모두 hazard 인지 분기 없음. Bridge × hazard 통합은 Terrain·WorkerState 측에서 처리 |
| `scripts/core/SkillRegistry.gd` | **무변경** — 신규 스킬 0건 |

### 2.3 수정 (.tscn)
| 파일 | 변경 |
|---|---|
| `scenes/entities/Ant.tscn` | `TraitBadges` 노드 아래 `StickyBadge` Sprite2D 자식 1개 추가. position=(0, -16) (다른 badge보다 약간 위로 — 겹침 방지), texture=`assets/icons/skills/sticky.svg` 또는 미존재 시 16x16 단색 placeholder (phase 20 polish에서 정식 교체), scale=0.5, visible=false |

### 2.4 신규 (.tscn — hazard 자산)
| 파일 | 용도 |
|---|---|
| `scenes/entities/hazards/Water.tscn` | Area2D + script=WaterHazard.gd. collision_layer=8(미사용 예약), **collision_mask=4** (Layer 3 ant — CLAUDE.md CRITICAL: Area2D 측 mask). CollisionShape2D + RectangleShape2D extents=(16, 16) (cell_size=32 가정, half_extents=cell_size/2). visual: ColorRect 자식(파란색 알파 0.6) 또는 Sprite2D — phase 20에서 정식 텍스처 교체 |
| `scenes/entities/hazards/Sticky.tscn` | Area2D + script=StickyHazard.gd. collision_layer=8, **collision_mask=4** (Layer 3 ant). CollisionShape2D + RectangleShape2D extents=(16, 16). visual: ColorRect (어두운 노란색 알파 0.7) 또는 Sprite2D. `duration: float = 3.0` @export 기본값 |

### 2.5 신규 (검증 stage)
| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_water_layout.tres` | StageLayoutData. cell_size=32. home_cell 좌측 + candy_cell 우측 + 그 사이 floor에 1 cell Water hazard 1~2개. Floor 가운데에 갭 만들지 않고 Water만 배치(ant가 Water 진입 → 손실) |
| `data/stages/dev/water_test.tres` | StageData. **id=910** (dev 예약 — 901~909는 phase 14~16 점유 확인). display_name="dev-water-test". available_skills=`[]` (skill 없이 자연 진행). total_ants=4, candy_hp=4, time_limit=60, release_rate_initial=30 |
| `scenes/stages/dev/WaterTest.tscn` | Stage scene. Stage02 패턴 + dev_water_layout wiring. World 아래 Water.tscn 인스턴스 1~2개 — position은 layout.cell_to_world(water_cell) |
| `data/stage_layouts/dev_sticky_layout.tres` | StageLayoutData. cell_size=32. home_cell 좌측 + candy_cell 우측 + 그 사이 floor에 1 cell Sticky hazard 1개. ant가 sticky 진입 → 3초 stuck → 해방 후 candy 도달 → home 회수 |
| `data/stages/dev/sticky_test.tres` | StageData. **id=911**. display_name="dev-sticky-test". available_skills=`[]`. total_ants=3, candy_hp=3, time_limit=60, release_rate_initial=30 |
| `scenes/stages/dev/StickyTest.tscn` | Stage scene. World 아래 Sticky.tscn 인스턴스 1개 |
| `data/stage_layouts/dev_bridge_over_water_layout.tres` | StageLayoutData. cell_size=32. floor에 갭 + 갭에 Water hazard 배치. available_skills=["bridge"]로 ant가 bridge 만들면 갭 통과(D8 hazard 비활성) |
| `data/stages/dev/bridge_over_water_test.tres` | StageData. **id=912**. display_name="dev-bridge-over-water". available_skills=`["bridge"]`. skill_inventory=`{"bridge":3}`. total_ants=4, candy_hp=4, time_limit=90 |
| `scenes/stages/dev/BridgeOverWaterTest.tscn` | Stage scene. World 아래 Water.tscn 3~5개(갭 cell들). Bridge 통과 후 deactivate 시각 검증 가능 |
| `data/stage_layouts/dev_water_sticky_overlap_layout.tres` | StageLayoutData. cell_size=32. **WaterStickyOverlapTest 전용**. floor에 Water + Sticky 같은 cell 배치. ant 진입 시 terminal Lost + ScoreSystem invariant 검증 (`_sticky_remaining` transient는 비검증) |
| `data/stages/dev/water_sticky_overlap_test.tres` | StageData. **id=913**. display_name="dev-water-sticky-overlap". available_skills=`[]`. total_ants=2, candy_hp=2, time_limit=30 |
| `scenes/stages/dev/WaterStickyOverlapTest.tscn` | Stage scene. World 아래 Water + Sticky 같은 좌표 인스턴스 |

> **dev id 정책 (v3 갱신)**: id ≥ 900 dev 예약 답습. phase 17 신규 점유 **910~915 (6건)** — 910 water_test, 911 sticky_test, 912 bridge_over_water_test, 913 water_sticky_overlap_test, 914 sticky_settle_test(옵션 §6.5), 915 bridge_over_overlap_test(v3 R1-H1 회귀). 점유 확인: 901~904 phase 14, 905~909 phase 16 (phase 14 lessons + 16 plan 점유 명세 confirmed).

### 2.6 신규 (tests/)
| 파일 | 검증 |
|---|---|
| `tests/WaterHazardLossEmptyHandTest.tscn/gd` | 헤드리스. dev_water_layout 사용. 빈손 ant 4명 모두 Water 진입 → LostState → queue_free. ScoreSystem.lost_pieces 갱신 검증. **PASS**: 30초 내 (1) `ants.size() == 0` (모두 free), (2) `lost_pieces == 0` (빈손은 사탕 손실 0 — emit 안 함), (3) `saved_pieces == 0`, (4) ScoreSystem invariant 유지 |
| `tests/WaterHazardLossCarryingTest.tscn/gd` | 헤드리스. dev_water_layout + 갭 없이 Water 좌표를 ant 귀환 경로에 배치. ant가 candy 픽업 → 운반 중 Water 진입 → `lost_pieces += 1` + `in_transit -= 1`. **PASS**: 60초 내 (1) `lost_pieces >= 1`, (2) `in_transit_pieces == 0` (운반 끝남), (3) ScoreSystem invariant 유지 |
| `tests/StickyStuckReleaseTest.tscn/gd` | 헤드리스. dev_sticky_layout 사용. 첫 ant Sticky 진입 → `is_stuck() == true` + velocity.x == 0 stuck 약 3초 → `is_stuck() == false` 회복 → candy 도달 → home 회수. **PASS**: 30초 내 (1) test step별 timeline: stuck 진입 시점 `is_stuck()` 1회 이상 true, (2) 3.5초 후 `is_stuck()` false, (3) `saved_pieces >= 1` |
| `tests/StickyCarryingPreservedTest.tscn/gd` | 헤드리스. ant가 candy 픽업 → 운반 중 Sticky 진입 → stuck 동안 has_candy=true 유지 + in_transit_pieces 1 유지 + lost 갱신 X. timer 만료 후 carry 정상 진행. **PASS**: stuck 시점 has_candy=true + `in_transit_pieces == 1`, 3.5초 후 carrying 정상 + 60초 내 `saved_pieces >= 1` |
| `tests/WaterStickyOverlapLostTerminalTest.tscn/gd` (v3 — R1-H2 fix, 이름 변경) | 헤드리스. dev_water_sticky_overlap_layout 사용. ant 진입 시 Water+Sticky 같은 frame 발화 가능 — Godot signal queue 순서 비결정으로 어느 게 먼저 발화하는지는 보장 안 됨. 그러나 같은 frame 안에 Water가 LostState 전이를 적용 → ant.queue_free → terminal=Lost는 결정론. **PASS**: 10초 내 (1) ant.is_alive() false 또는 ant가 더 이상 ants group에 없음 (queue_free 완료), (2) `lost_pieces` 변화량이 ant carrying 여부와 일치(빈손이면 0, 운반 중이었으면 1), (3) ScoreSystem invariant `saved + in_transit + lost ≤ original_hp` 유지. **`_sticky_remaining` 값은 검증 안 함** — Sticky가 먼저 발화하면 transient 양수 가능하나 같은 frame Water 처리로 ant 종료되므로 의미 없음 (v3 R1-H2 fix) |
| `tests/BridgeOverWaterTest.tscn/gd` | 헤드리스. dev_bridge_over_water_layout 사용. ant가 bridge skill 적용 → 갭의 Water cell 위에 bridge tile 배치 → `terrain.deactivate_hazards_at(cell)` 호출 → Water hazard.set_active(false). ant가 bridge 위 통과 → candy 도달 → home 회수. **PASS**: 60초 내 (1) `saved_pieces >= 1`, (2) bridge 통과한 ant들이 Water entry로 lost 처리 X (즉 hazard deactivate 성공 검증), (3) bridge cell의 hazard 노드 `monitoring == false` (test driver가 직접 노드 인스펙트) |
| `tests/HazardEntryIdempotentTest.tscn/gd` | 헤드리스. WaterHazard 동일 ant 다중 body_entered 시 lost 1회만 발화 검증. dev_water_layout 단순 변형 — Area2D 크기를 ant 통과 시간이 약간 길어지도록(2 cell wide) 확장. body_entered가 같은 frame 다중 발화하거나 frame 차이 발화해도 1회만 lost. **PASS**: 30초 내 ant 4명, `lost_pieces` 변화량 == ant 운반 여부와 일치(빈손 4명이면 lost == 0, 운반 N명이면 lost == N) |
| `tests/DistributorOnStickyTransferTest.tscn/gd` | 헤드리스. layout: SettlementMarker가 Sticky cell 또는 인접 cell. 분배자 ant가 sticky 진입 → stuck. SettlementMarker.body_entered가 같은 frame에 발화하면 정착 → SettledState. 정착 후 후속 walker 진입 → floater trait 전이. **PASS**: 30초 내 (1) 분배자 SettledState 도달, (2) 후속 walker has_trait(&"floater") == true, (3) ScoreSystem invariant 유지. 시뮬레이션 단순화: stage layout이 sticky cell == settlement cell이 되도록 구성 |
| `tests/SettledImmuneToHazardTest.tscn/gd` | 헤드리스. SettlementMarker · Water hazard 인접 cell. 분배자 정착 후 → test driver가 정착 ant를 강제로 Water area로 이동(global_position 갱신) → body_entered 발화하지만 D13 state 가드(SettledState ant 무시)로 LostState 미진입. **PASS**: 분배자 SettledState 도달 후 Water entry 시도 → `ant.state_machine.current_state is SettledState` 유지, `lost_pieces` 무변동 |
| `tests/StickyTimerCarryingResumeTest.tscn/gd` | 헤드리스. StickyCarryingPreservedTest와 유사하지만 timer 정확도 검증 중심. test driver가 매 frame `_sticky_remaining` 캡처 → linear decay 검증(±0.05s 오차 허용). **PASS**: `_sticky_remaining` 단조 감소 + 3.0s ± 0.1s에 0 도달 |
| `tests/BridgeOverWaterStickyOverlapTest.tscn/gd` **(v3 신규 — R1-H1 회귀 가드)** | 헤드리스. **dev_water_sticky_overlap_layout 위에 갭 구성 + bridge skill 부여한 변형 layout** (`dev_bridge_over_overlap_layout.tres` id=915 신규 — §6.6 도식 참조). 같은 cell에 Water + Sticky 둘 다 register된 cell들 위에 Bridge 적용 → Bridge tile placement 시 `terrain.deactivate_hazards_for_placement(target)`이 cell의 Array 모든 hazard에 set_active(false) 적용. ant가 bridge 위 통과 → 두 hazard 모두 monitoring=false라 body_entered 미발화 → candy 도달. **PASS**: 60초 내 (1) `saved_pieces >= 1`, (2) overlap cell들의 Water 노드 `monitoring == false` AND Sticky 노드 `monitoring == false` (test driver가 두 노드 직접 inspect), (3) bridge 통과 ant 누구도 LostState 진입 X, (4) registration 순서 무관성 검증을 위해 Water/Sticky 둘 다 deactivate 확인. **FAIL**: 어느 한 hazard라도 monitoring=true 유지 또는 ant lost 발생 (R1-H1 재발) |

### 2.7 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 시그널 추가 0건
- `scripts/core/ScoreSystem.gd` — 4-카운터(ADR-002) 무영향
- `scripts/core/StageData.gd` — 필드 추가 0건
- `scripts/core/StageLayoutData.gd` — hazard 관련 필드 미도입(D11)
- `scripts/core/StageRunner.gd` — 무변경
- `scripts/core/SkillRegistry.gd` — 신규 스킬 0건
- `scripts/core/SaveData.gd`, `MenuLayout.gd` — 무변경
- `scripts/skills/*` — 전부 무변경. Bridge × hazard는 Terrain·WorkerState 측 처리
- `scripts/ant/states/FallerState.gd` / `ClimberState.gd` / `SavedState.gd` / `DeadState.gd` / `SettledState.gd` / `WorkerState.gd`의 builder/blocker/sand_mound/bridge 분기 코어 로직 — **stuck 분기 미추가**, `_place_*_tile`만 `terrain.deactivate_hazards_for_placement(target)` 1줄 추가 (v2 helper)
- `scripts/world/SettlementMarker.gd` — D5/D6 자연 분기 (코드 변경 없음)
- `scripts/world/Candy.gd`, `Home.gd`, `CookiePlatformVisual.gd` — 무변경
- `scripts/ui/HUD.gd` — Lost counter 이미 wired (HUD.gd:27)
- `scripts/ui/SkillToolbar.gd` — 신규 스킬 0건, 무변경
- 기존 stages Stage01~03 / data/stages/stage0N.tres — hazard 미사용, 회귀 무영향
- phase 14~16 dev stages (TraitTest, SettleTest, SettleStuckTest, SettleRaceTest, SandMoundTest, BridgeTest, BridgeRejectTest, BridgeTooLongTest, SandBridgeOverlapTest) — hazard 미사용, 회귀 무영향
- 기존 헤드리스 테스트 — hazard 미관련, 모두 PASS 유지

### 2.8 텍스처 정책 (minimal)
본 phase는 메카닉 검증 우선 — hazard 시각은 placeholder ColorRect/단색 Sprite2D로 충분:
- WaterHazard 시각: ColorRect (파란색 알파 0.6, size=cell_size×cell_size). 정식 텍스처는 phase 20 polish
- StickyHazard 시각: ColorRect (어두운 노란/갈색 알파 0.7). 정식 텍스처는 phase 20 polish
- StickyBadge: 16x16 단색 placeholder svg 또는 기존 24x24 svg에서 1개 재활용(임시) — phase 20 polish에서 정식 디자인

**deferred to phase 20 polish**: 정식 hazard 텍스처(물결·꿀 등), 진입 시 파티클·소리, stuck ant 위 progress bar

---

## 3. Hazard 명세

### 3.1 HazardBase.gd (v2 — §0.2 어휘 단순화)
```gdscript
class_name HazardBase extends Area2D

# Phase 17 — hazard 베이스. Area2D 자체 monitoring + Terrain 자체 register.
# 서브클래스(WaterHazard·StickyHazard)는 _handle_ant_entry(ant)만 override.

var _hazard_cell: Vector2i = Vector2i.ZERO
var _active: bool = true
var _terrain: Terrain = null

func _ready() -> void:
    monitoring = true
    body_entered.connect(_on_body_entered)
    # cell_size race 회피 — StageLayoutBuilder.build 이후 frame에 cell 계산 + register.
    await get_tree().physics_frame
    if not is_inside_tree():
        return
    _terrain = _find_ancestor_terrain()
    if _terrain == null:
        push_warning("[%s] could not find ancestor Terrain — hazard cell registration skipped" % name)
        return
    var cs: int = _terrain.cell_size
    _hazard_cell = Vector2i(
        int(floor(global_position.x / cs)),
        int(floor(global_position.y / cs))
    )
    _terrain.register_hazard_at_cell(_hazard_cell, self)

func _find_ancestor_terrain() -> Terrain:
    var n: Node = get_parent()
    while n != null:
        var t: Terrain = n.get_node_or_null("Terrain") as Terrain
        if t != null:
            return t
        if n is Terrain:
            return n as Terrain
        n = n.get_parent()
    return null

func set_active(active: bool) -> void:
    _active = active
    monitoring = active
    var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
    if shape != null:
        shape.disabled = not active
    # 시각 alpha 토글 — 모든 자식 visual 노드(ColorRect/Sprite2D)에 modulate.a 적용.
    for c in get_children():
        if c is CanvasItem:
            (c as CanvasItem).modulate.a = (1.0 if active else 0.3)

func _on_body_entered(body: Node2D) -> void:
    if not _active:
        return
    var ant: Ant = body as Ant
    if ant == null or not is_instance_valid(ant):
        return
    # v2 D13 — Ant.is_alive() 단일 진입점으로 terminal(Saved/Dead/Settled/Lost) 일괄 차단.
    # 신규 코드에서 `Dead`/`Saved` 등 식별자 직접 참조 0건 (§0.2 어휘 정합).
    if not ant.is_alive():
        return
    _handle_ant_entry(ant)

func _handle_ant_entry(_ant: Ant) -> void:
    # 추상 — 서브클래스가 override.
    pass
```

### 3.2 WaterHazard.gd
```gdscript
class_name WaterHazard extends HazardBase

func _handle_ant_entry(ant: Ant) -> void:
    # 즉시 LostState로 전이 — LostState.enter()가 candy_piece_lost emit + queue_free.
    ant.state_machine.change_state(LostState.new())
```

### 3.3 StickyHazard.gd
```gdscript
class_name StickyHazard extends HazardBase

@export var duration: float = 3.0

var _recently_processed: Dictionary = {}   # Ant InstanceID → Engine.get_physics_frames()

func _ready() -> void:
    super._ready()
    body_exited.connect(_on_body_exited)

func _handle_ant_entry(ant: Ant) -> void:
    # D13 — 같은 frame 중복 entry 차단(set_deferred/signal race 대응).
    var frame: int = Engine.get_physics_frames()
    var aid: int = ant.get_instance_id()
    if _recently_processed.get(aid, -1) == frame:
        return
    _recently_processed[aid] = frame
    ant.apply_sticky(duration)

func _on_body_exited(body: Node2D) -> void:
    var ant: Ant = body as Ant
    if ant == null:
        return
    _recently_processed.erase(ant.get_instance_id())
```

---

## 4. Ant · State 변경 명세

### 4.1 Ant.gd 신규 API
```gdscript
# Phase 17 — sticky timer.
var _sticky_remaining: float = 0.0
var _sticky_badge: Sprite2D = null   # _ready에서 _trait_badges.get_node_or_null("StickyBadge")

# Phase 17 — 외부 (StickyHazard) 호출 진입점.
func apply_sticky(dur: float) -> void:
    # 멱등 — 더 긴 timer 우선(중복 entry 시 더 큰 값 보존).
    if dur > _sticky_remaining:
        _sticky_remaining = dur

func is_stuck() -> bool:
    return _sticky_remaining > 0.0

# 기존 _physics_process 첫 줄에 timer 감소 추가:
func _physics_process(delta: float) -> void:
    if _sticky_remaining > 0.0:
        _sticky_remaining = max(0.0, _sticky_remaining - delta)
    if state_machine != null:
        state_machine.update(delta)
    _update_sprite()
    _update_trait_badges()

# is_alive: LostState 분기 추가.
func is_alive() -> bool:
    if state_machine == null or state_machine.current_state == null:
        return false
    var s: AntState = state_machine.current_state
    return not (s is SavedState or s is DeadState or s is SettledState or s is LostState)

# _update_trait_badges 끝에:
func _update_trait_badges() -> void:
    # ...기존 climber/floater/settle badge...
    if _sticky_badge != null:
        _sticky_badge.visible = is_stuck()
```

### 4.2 WalkerState.gd stuck 분기
```gdscript
func update(delta: float) -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    # Phase 17 — stuck 시 좌우 0, 중력만 + slide. flip/climber/faller 전이 모두 skip.
    if a.is_stuck():
        a.velocity.x = 0.0
        a.velocity.y += a.gravity * delta
        a.move_and_slide()
        return
    # 기존 로직:
    a.velocity.y += a.gravity * delta
    a.velocity.x = float(a.direction) * a.effective_speed()
    a.move_and_slide()
    _frame += 1
    if a.is_on_wall():
        if a.has_trait(&"climber"):
            a.state_machine.change_state(ClimberState.new())
            return
        a.flip()
    if _frame > 1 and not a.is_on_floor():
        a.state_machine.change_state(FallerState.new())
```

### 4.3 CarryingState.gd stuck 분기
```gdscript
func update(delta: float) -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    # Phase 17 — stuck 시 carrying 유지 + 정지.
    if a.is_stuck():
        a.velocity.x = 0.0
        a.velocity.y += a.gravity * delta
        a.move_and_slide()
        return
    # 기존 로직:
    a.velocity.y += a.gravity * delta
    a.velocity.x = float(a.direction) * a.effective_speed()
    a.move_and_slide()
    if a.is_on_wall():
        if a.has_trait(&"climber"):
            a.state_machine.change_state(ClimberState.new())
            return
        a.flip()
    if not a.is_on_floor():
        a.state_machine.change_state(FallerState.new())
```

### 4.4 LostState.gd
```gdscript
class_name LostState extends AntState

# Phase 17 — hazard 진입으로 ant 탈락(§0.2 어휘) terminal state.
# enter()에서 candy_piece_lost emit(보유 시) + queue_free. exit() 없음.

func enter() -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    if a.has_candy:
        EventBus.candy_piece_lost.emit(a)
        a.has_candy = false   # ScoreSystem._on_lost가 in_transit -1 처리하므로 멱등성 위한 즉시 clear.
    # Blocker hitbox 정리 (이미 비활성이라도 멱등).
    a.set_blocker_active(false)
    a.queue_free()
```

---

## 5. Bridge × Hazard 상호작용 명세 (phase 16 D9 해소 — D8)

### 5.1 Terrain.gd 신규 API (v3 — Multi-hazard Array 저장)
```gdscript
# v3 — codex R1-H1 대응: cell의 Array로 저장하여 same-cell overlap(Water+Sticky 등)
# layout에서도 deactivate 시 모든 hazard 일괄 처리. registration 순서 무관 D8 정책 robust.
var _hazards_by_cell: Dictionary = {}   # Vector2i → Array[HazardBase]

func register_hazard_at_cell(cell: Vector2i, hazard: HazardBase) -> void:
    if hazard == null:
        return
    var arr: Array = _hazards_by_cell.get(cell, [])
    if arr.has(hazard):
        return   # idempotent — 같은 instance 중복 register 무효
    arr.append(hazard)
    _hazards_by_cell[cell] = arr

func deactivate_hazards_at(cell: Vector2i) -> void:
    var arr: Array = _hazards_by_cell.get(cell, [])
    for h in arr:
        var hazard: HazardBase = h as HazardBase
        if hazard != null and is_instance_valid(hazard):
            hazard.set_active(false)

# v2 — placement helper. Bridge/Sand-mound/Builder의 add_tile 직후 호출.
# target은 floor row(Bridge/Builder의 경우) 또는 body row(Sand-mound의 경우).
# hazard는 D15에 따라 항상 body row 컨벤션 → floor row placement는 target과 target-1 두 cell 모두 처리.
# Sand-mound도 동일 적용 — target(body row)과 그 위(new ant body row) 모두 비활성.
# v3 — Array 저장이라 각 cell의 모든 hazard에 set_active(false) 적용.
func deactivate_hazards_for_placement(target: Vector2i) -> void:
    deactivate_hazards_at(target)
    deactivate_hazards_at(target + Vector2i(0, -1))
```

### 5.2 WorkerState.gd 1줄 추가 (3 곳)
```gdscript
# _place_one_tile (Builder), _place_sand_mound_tile, _place_bridge_tile 모두
# add_tile true 직후, ant 이동 직전에:
terrain.deactivate_hazards_for_placement(target)
```

### 5.3 동작 시나리오 (v2 cell row 정합)
- **BridgeOverWater**: ant가 갭 직전 도달 → bridge skill apply → WorkerState("bridge") 진입 → 매 tick `_place_bridge_tile` → target = body_cell + (dir, +1) = floor row(y=23) → `add_tile(target)` true → `terrain.deactivate_hazards_for_placement(target)` → helper가 target(y=23) + target-1(y=22, body row) 모두 비활성 시도 → Water는 body row(y=22)에 등록되어 있으므로 두 번째 호출에서 hit → WaterHazard.set_active(false) → 같은 frame 이후 body_entered 발화 안 함. ant가 bridge 위(y=22) 통과 → candy 도달 → home 회수 (사탕 손실 0).
- **Sand-mound over Water**: 동일 helper 패턴. Sand-mound target = body_cell (y=22 = body row). add_tile 후 ant.y -= cs → ant new body cell = y=21. helper의 target(y=22) + target-1(y=21) 모두 비활성 → 기존 body row hazard + 새 body row 위치 hazard 모두 처리. 단 Sand-mound 진입 자체가 hazard cell에 ant가 있는 상태에서 일어나기 어려움 (Sand-mound 적용 전에 hazard.body_entered가 먼저 발화) — case는 edge.
- **Builder over Water**: phase 3 Builder도 같은 helper 적용. Builder는 hazard 미배치 stage(Stage 02)에서 동작 — helper는 no-op으로 회귀 0.
- **단방향**: bridge 제거 API 없음, hazard 재활성 미고려. 본 phase 17 범위.

### 5.4 same-cell 다중 hazard 정책 (v3 — Array 일괄 적용)
- D11 scene-side instance라서 동일 cell에 Water + Sticky 둘 다 배치 가능. **v3 — `_hazards_by_cell[cell]`이 Array[HazardBase]라 같은 cell에 N개 hazard 모두 register 누적.** deactivate_hazards_at은 Array 전체 순회 set_active(false).
- **D8 정책 robust**: Bridge가 same-cell overlap layout 위에 만들어져도 Array의 모든 hazard(Water + Sticky 둘 다) 일괄 비활성 → registration 순서 무관 ant 안전 통행.
- **신규 회귀 테스트 `BridgeOverWaterStickyOverlapTest`** (§2.6 신규 11번째): bridge 적용 후 같은 cell의 Water + Sticky 모두 monitoring=false 검증 (test driver가 두 hazard 노드 직접 inspect).
- WaterStickyOverlapLostTerminalTest는 body_entered 경로(Bridge 미적용)로 직접 진입 시 terminal=Lost 결정성 검증.

---

## 6. dev 검증 stage 설계

### 6.1 dev_water_layout (id=910) 도식 (cell_size=32, body row 컨벤션 v2)
```
y\x  0     5     10  12 14 16  18    23
                                          
                       H   ~~   C      # y=22 ant body row + Water(~) at (14,22),(15,22)
              ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ # y=23 continuous floor (갭 없음)
```
- platform_cells (y=23): (0~30, 23) 연속 floor. **갭 없음** — Water는 floor 위 ant 진입 cell로 발화.
- home_cell: (10, 22), candy_cell: (20, 22)
- **Water cells (body row 컨벤션): [(14, 22), (15, 22)]** — ant body가 진입하는 cell. ant walker가 floor(y=23) 위 진행 → body cell이 y=22 row → (14, 22) entry 시 Water.body_entered 발화 → LostState.
- scene editor 좌표: Water1 node global_position = `layout.cell_to_world(Vector2i(14, 22))` = (14*32+16, 22*32+16) = (464, 720). Water2 = (15, 22) → (496, 720).

### 6.2 dev_sticky_layout (id=911) 도식 (body row 컨벤션 v2)
```
y\x  0     5     10    14   18    23
                       H ⚠  C          # y=22 ant body row + Sticky(⚠) at (14, 22)
              ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ # y=23 continuous floor
```
- platform_cells (y=23): (0~30, 23) 연속.
- **Sticky cell (body row): (14, 22)** 1 cell. ant 진입 시 3초 stuck → 해방 후 candy 도달.
- home_cell: (10, 22), candy_cell: (20, 22).

### 6.3 dev_bridge_over_water_layout (id=912) 도식 (body row 컨벤션 v2)
```
y\x  0     5     10  12      17  18    23
                       H ~~~~~~        C  # y=22 ant body row + Water(~) at (12~17, 22)
              ▓▓▓▓▓▓▓▓               ▓▓▓▓ # y=23 floor (갭 12~17, 6 cells)
```
- platform_cells (y=23): (0~11, 23) + (18~30, 23). **갭 = 6 cells at (12~17, 23)**.
- **Water cells (body row): [(12,22) ~ (17,22)]** — 6개. ant가 갭에 진입 시(walker fall) 사탕 손실, 또는 갭 직전에 ant 진입(body cell 그대로 y=22 row)도 Water 발화.
- home_cell: (10, 22), candy_cell: (20, 22), available_skills: ["bridge"].
- **Bridge 동작**: ant가 갭 직전(x=11) 도달 → bridge apply → WorkerState("bridge") 진입 → 매 tick `_place_bridge_tile`로 target=(x, 23) (floor row) 적재 → `terrain.deactivate_hazards_for_placement(target)` → helper의 target-1=(x, 22) hit → Water at (x, 22) set_active(false) → ant가 bridge floor(y=23) 위(body y=22) 통과 → Water 비활성이라 LostState 미진입 → candy 도달.

### 6.4 dev_water_sticky_overlap_layout (id=913) 도식 (body row 컨벤션 v2, v3 invariant 완화)
```
y\x  0     5     10    14   18    23
                       H ✖  C          # y=22 ant body row + Water+Sticky(✖) at (14, 22)
              ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ # y=23 continuous floor
```
- 같은 cell **(14, 22)** 에 Water + Sticky 두 노드 모두 인스턴스 (scene editor에서 둘 다 같은 global_position). v3 — Terrain `_hazards_by_cell[(14,22)]`는 Array [Water, Sticky] (또는 [Sticky, Water] — 노드 _ready 순서 의존).
- **ant 진입 시 (v3 invariant 완화)**: Water.body_entered + Sticky.body_entered가 같은 frame 발화. **Godot signal queue 순서는 비결정** — 둘 중 어느 게 먼저 발화하는지 보장 안 됨. 시나리오:
  - Water가 먼저 발화: LostState 전이 → 같은 frame Sticky 발화 시 `not ant.is_alive()` 가드로 무시. `_sticky_remaining == 0` 유지.
  - Sticky가 먼저 발화: ant.apply_sticky(3.0) → `_sticky_remaining = 3.0` (transient) → 같은 frame Water 발화 → LostState 전이 → ant.queue_free. ant 종료되므로 `_sticky_remaining` 양수는 의미 없음.
- **terminal=Lost는 결정론**: 두 시나리오 모두 ant 최종 상태는 Lost (queue_free 완료). lost_pieces 갱신은 carrying 여부에 따라 결정론.
- **v3 검증 명제** (WaterStickyOverlapLostTerminalTest): terminal=Lost + ScoreSystem invariant만 검증. `_sticky_remaining` transient 값은 검증 대상 아님 (codex R1-H2 fix).

### 6.5 SettlementMarker × Sticky overlap (DistributorOnStickyTransferTest용)
- 별도 layout `dev_sticky_settle_layout`(id=914) 또는 dev_sticky_layout 재활용 + Sticky cell == settlement_cell. 분배자가 Sticky cell(body row y=22) 진입 → stuck + 같은 frame SettlementMarker.body_entered → 정착 (SettledState는 update 호출 안 되므로 timer 무관). 후속 walker는 sticky stuck 안 받게 stage layout 조정(walker 진로가 sticky cell 안 거치게).
- 또는 단순화: Sticky cell과 SettlementMarker cell을 인접 분리(예: Sticky at (13,22), settlement at (14,22)). 분배자가 Sticky 진입 → stuck → 3초 후 해방 → walker 진행 → settlement 진입 → SettledState. 후속 walker가 Sticky 안 거치게 spawn 위치 또는 진로 조정.

### 6.6 dev_bridge_over_overlap_layout (id=915, v3 신규 — R1-H1 회귀 가드 layout)
```
y\x  0     5     10  12      17  18    23
                       H ✖✖✖✖✖✖        C  # y=22 ant body row + Water+Sticky overlap at (12~17, 22)
              ▓▓▓▓▓▓▓▓               ▓▓▓▓ # y=23 floor (갭 12~17, 6 cells)
```
- platform_cells (y=23): (0~11, 23) + (18~30, 23). 갭 = 6 cells at (12~17, 23).
- **각 갭 cell의 body row(y=22)에 Water + Sticky 두 노드 모두 인스턴스** — same-cell overlap × 6 cells. Terrain `_hazards_by_cell[(x, 22)]`는 각각 `[Water, Sticky]` Array.
- home_cell: (10, 22), candy_cell: (20, 22), available_skills: ["bridge"], skill_inventory: {"bridge": 3}, total_ants: 4, candy_hp: 4, time_limit: 90.
- **BridgeOverWaterStickyOverlapTest 동작**: 첫 ant가 갭 직전(x=11) 도달 → bridge skill apply → 매 tick `_place_bridge_tile`로 target=(x, 23) → `add_tile(target)` true → `terrain.deactivate_hazards_for_placement(target)` → target(y=23, hazard 없음 — no-op) + target-1(y=22, Array[Water, Sticky] 둘 다 set_active(false)). 6 cell 모두 동일 처리. ant + 후속 ant들 bridge 위(body y=22) 통과 → 두 hazard 모두 monitoring=false라 body_entered 미발화 → candy 도달 → home 회수.

---

## 7. 사전 점검 항목 (impl 시작 전 확인)

### 7.1 dev id 905~909 점유 재확인
- phase 16 plan §2.4에 905~909 점유 명시. 본 phase 910~914 (5건 — 914는 §6.5 옵션) 신규 점유.
- grep으로 stage_data id 확인: `grep -rn 'id.*=.*9[0-9]\{2\}' data/stages/dev/` → 점유 충돌 없는지 확인.

### 7.2 Hazard 시각 자산 부재
- Water/Sticky 정식 텍스처 phase 17 미생성. ColorRect placeholder 사용. SkillToolbar 아이콘은 hazard 무관(스킬 없음).
- StickyBadge 24x24 svg — 미존재 시 16x16 단색 placeholder 또는 기존 icon 재활용. phase 20 polish에서 정식.

### 7.3 §0.2 어휘 정합 자체 점검
- 신규 코드(HazardBase/WaterHazard/StickyHazard/LostState) 식별자·문자열·주석에 forbidden 어휘(`die()`, `Dead`, `사망`, `죽`) 0건.
- 기존 코드 참조(DeadState/ant_died)는 PROPOSAL §7.5 별도 작업 — impl 단계 grep 점검.

### 7.4 Bridge × hazard 회귀 회피
- WorkerState `_place_one_tile`(Builder)에도 `terrain.deactivate_hazards_for_placement(target)` (v2 helper) 추가 → 기존 Stage 02/03 Builder 동작에 변화 없음(hazard 미배치 stage는 `_hazards_by_cell` 빈 dict, helper 두 cell 모두 no-op). 헤드리스 Stage02HeadlessTest / Stage03HeadlessTest 회귀 확인.

### 7.5 Sticky timer 정확도
- `_sticky_remaining` delta 기반 감소 — physics frame rate (60 Hz default)에 비례. test에서 ±0.05s 오차 허용 명시.

---

## 8. 회귀 항목 (impl 후 검증)

1. **Stage 1~3 회귀** — hazard 미배치. 헤드리스 Stage02HeadlessTest, Stage03HeadlessTest PASS.
2. **Phase 14 trait 회귀** — ClimberTraitTest, FloaterTraitTest, ClimberStallTest, ClimberBlockerOverlapTest, ClimberBlockerOverlapStallTest PASS.
3. **Phase 15 정착 회귀** — DistributorSettleTest, SettlementTraitTransferTest, SettlementSameFrameRaceTest, SettlementHundredPercentStuckTest PASS.
4. **Phase 16 생성 회귀** — SandMoundClimbTest, SandMoundMaxHeightTest, BridgeGapCrossTest, BridgeGapTooLongTest, SandBridgeOverlapTest, BridgeRejectStageCellTest, DynamicTileCellSizeAlignmentTest, BridgeFirstTickOffFloorAbortTest, BridgeFallAbortTest PASS.
5. **ScoreSystem invariant** — `saved + in_transit + lost ≤ original_hp` 모든 phase 17 헤드리스에서 유지.
6. **Phase 11 HUD 회귀** — HudCounterRegressionTest PASS. Lost counter는 EventBus 시그널 갱신만으로 동작 확인.
7. **SkillRegistry** — 신규 스킬 0건, validate_stage 회귀 0.

---

## 9. impl 단계 변경 요약 (체크리스트)

- [ ] `scripts/world/hazards/HazardBase.gd` 신규
- [ ] `scripts/world/hazards/WaterHazard.gd` 신규
- [ ] `scripts/world/hazards/StickyHazard.gd` 신규
- [ ] `scripts/ant/states/LostState.gd` 신규
- [ ] `scripts/ant/Ant.gd` — `_sticky_remaining`/`apply_sticky`/`is_stuck`/`_sticky_badge` + `is_alive`에 LostState 분기 + `_physics_process` 1줄 + `_update_trait_badges` 1줄
- [ ] `scripts/ant/states/WalkerState.gd` — stuck 분기 update 첫 줄
- [ ] `scripts/ant/states/CarryingState.gd` — stuck 분기 update 첫 줄
- [ ] `scripts/ant/states/WorkerState.gd` — `_place_one_tile`/`_place_sand_mound_tile`/`_place_bridge_tile` 각 add_tile 직후 `terrain.deactivate_hazards_for_placement(target)` 1줄 (v2 helper)
- [ ] `scripts/world/Terrain.gd` — `_hazards_by_cell` + `register_hazard_at_cell` + `deactivate_hazards_at` + **`deactivate_hazards_for_placement(target)` helper (v2)**
- [ ] `scenes/entities/Ant.tscn` — TraitBadges 아래 StickyBadge Sprite2D 추가
- [ ] `scenes/entities/hazards/Water.tscn` 신규
- [ ] `scenes/entities/hazards/Sticky.tscn` 신규
- [ ] `data/stage_layouts/dev_water_layout.tres` 신규
- [ ] `data/stages/dev/water_test.tres` 신규 (id=910)
- [ ] `scenes/stages/dev/WaterTest.tscn` 신규
- [ ] `data/stage_layouts/dev_sticky_layout.tres` 신규
- [ ] `data/stages/dev/sticky_test.tres` 신규 (id=911)
- [ ] `scenes/stages/dev/StickyTest.tscn` 신규
- [ ] `data/stage_layouts/dev_bridge_over_water_layout.tres` 신규
- [ ] `data/stages/dev/bridge_over_water_test.tres` 신규 (id=912)
- [ ] `scenes/stages/dev/BridgeOverWaterTest.tscn` 신규
- [ ] `data/stage_layouts/dev_water_sticky_overlap_layout.tres` 신규
- [ ] `data/stages/dev/water_sticky_overlap_test.tres` 신규 (id=913)
- [ ] `scenes/stages/dev/WaterStickyOverlapTest.tscn` 신규
- [ ] (옵션) `data/stage_layouts/dev_sticky_settle_layout.tres` + `data/stages/dev/sticky_settle_test.tres` (id=914) + `scenes/stages/dev/StickySettleTest.tscn`
- [ ] `tests/WaterHazardLossEmptyHandTest.tscn/gd` 신규
- [ ] `tests/WaterHazardLossCarryingTest.tscn/gd` 신규
- [ ] `tests/StickyStuckReleaseTest.tscn/gd` 신규
- [ ] `tests/StickyCarryingPreservedTest.tscn/gd` 신규
- [ ] `tests/WaterStickyOverlapLostTerminalTest.tscn/gd` 신규 (v3 R1-H2 — 이름 변경 + invariant 완화)
- [ ] `tests/BridgeOverWaterTest.tscn/gd` 신규
- [ ] `tests/BridgeOverWaterStickyOverlapTest.tscn/gd` 신규 (v3 R1-H1 회귀 가드)
- [ ] `data/stage_layouts/dev_bridge_over_overlap_layout.tres` 신규 (v3 — §6.6)
- [ ] `data/stages/dev/bridge_over_overlap_test.tres` 신규 (v3, id=915)
- [ ] `scenes/stages/dev/BridgeOverOverlapTest.tscn` 신규 (v3)
- [ ] `tests/HazardEntryIdempotentTest.tscn/gd` 신규
- [ ] `tests/DistributorOnStickyTransferTest.tscn/gd` 신규
- [ ] `tests/SettledImmuneToHazardTest.tscn/gd` 신규
- [ ] `tests/StickyTimerCarryingResumeTest.tscn/gd` 신규
- [ ] §0.2 어휘 grep 자체 점검 (신규 코드만): `grep -rn 'die(\|Dead\|사망\|죽' scripts/world/hazards/ scripts/ant/states/LostState.gd` → 0 hits 확인
- [ ] 회귀 (헤드리스 phase 11/14/15/16 전부 + Stage02/03HeadlessTest) PASS 확인

---

## 10. strict acceptance 기준 (v4)

phase 16의 v7 strict acceptance 패턴 답습 — 본 phase 7조:

- **No tone-policy violation in new code**: 신규 파일(HazardBase·WaterHazard·StickyHazard·LostState)의 식별자·문자열·주석에 `die()`/`Dead`/`사망`/`죽` 0 hits. HazardBase D13 가드는 `not ant.is_alive()` 단일 진입점 사용 (v2 §0.2 정합). **기존 파일(Ant.gd / WorkerState.gd / WalkerState.gd / CarryingState.gd) incremental edit의 기존 `DeadState`/`ant_died` 참조 잔존은 phase 17 신규 식별자 도입이 아니라 보존이며 PROPOSAL §7.5 별도 작업 범위** — 본 strict acceptance 범위 외. 신규 파일 4건만 grep 0 hits 강제.
- **No silent hazard loss under overlap (v3 갱신 — R1-H1)**: 같은 cell에 hazard 둘 이상 register 시 **Array 일괄 저장** + deactivate_hazards_at가 Array 모든 hazard set_active(false). registration 순서 무관 D8 정책 robust. `BridgeOverWaterStickyOverlapTest`가 회귀 가드.
- **No stuck-in-faller deadlock**: stuck 분기는 WalkerState/CarryingState만. FallerState/ClimberState/WorkerState 미적용 — 영구 공중/벽 stuck 방지.
- **No double-loss on multi-hazard entry**: HazardBase._on_body_entered의 D13 가드 (Ant.is_alive()=false 시 무시) + WaterHazard 즉시 LostState 전이로 다중 발화 자연 차단. LostState.enter()에서 has_candy=false 즉시 clear로 candy_piece_lost 중복 emit 차단.
- **No Bridge-blind hazard (v2)**: WorkerState `_place_*_tile` 3개 분기 모두 `terrain.deactivate_hazards_for_placement(target)` helper 호출 — helper는 target(floor row) + target-1(body row) 두 cell 모두 비활성. Builder(phase 3)/Sand-mound(phase 16)/Bridge(phase 16)이 일관 적용. hazard 없는 stage는 no-op (회귀 0).
- **No hazard cell row mismatch (v2 new)**: hazard 노드는 항상 ant body row(`floor_y - 1`)에 배치 — Area2D body_entered가 ant body cell 진입 시 발화. floor row(`floor_y`)에 hazard 배치는 stage 디자인 컨벤션 위반 (body_entered 미발화 위험). dev stage 5종 모두 body row 컨벤션 검증.
- **No order-dependent overlap invariant (v4 — R1-H2/R2-H1)**: WaterStickyOverlapLostTerminalTest는 terminal=Lost + ScoreSystem invariant만 검증 — `_sticky_remaining` transient 값(Godot signal queue 순서로 Sticky 먼저 발화 시 양수 가능)은 의도적으로 검증 안 함. D3 canonical decision row와 §6.4 모두 same-cell 효과(terminal Lost) 결정론, 부작용(_sticky_remaining transient) 비결정으로 일치.

---

## 11. 표준 절차

plan-stage codex adversarial-review → HIGH 0건이면 사용자 결정으로 impl-stage 진입 → impl 자체 적대적 리뷰 → codex impl-stage 재리뷰 → clean까지. 자세한 흐름은 [phases/mvp/README.md](../README.md) 및 CLAUDE.md plan/impl stage 정책.

**작성**: 2026-05-24 / plan v1 → v2 (self-review) → v3 (codex Round 1 HIGH 2건 fix) → v4 (codex Round 2 HIGH 1건 fix, 동일 날짜). v4 변경 표는 §0.00, v3 변경 표는 §0.0, v2 변경 표는 §0.1 참조. plan-stage 정책 — codex Round 3에서 HIGH 0건이면 impl 진입, HIGH 1건 이상이면 즉시 중단 + 사용자 결정.
