# Phase 15 Plan — mechanic-adaptation-settlement (v3)

**Status**: plan v3 — Round 2 codex needs-attention(MEDIUM only) 대응 inline (F-R2-M1 summary 모순 정정 + F-R2-M2 PROPOSAL §0.7.5 톤 폴리시 정합). plan-stage 정책 — Round 2는 HIGH 0 + MEDIUM 2 → 자동 중단 사유 없음, plan v3 inline 처리 후 사용자 결정으로 다음 단계 진행
**Phase frontmatter doc**: [phases/mvp/phase15-mechanic-adaptation-settlement.md](../phase15-mechanic-adaptation-settlement.md)
**1차 SoT 인용**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §3.1 (정착 + 능력 전이) / §3.1.3 (A안 — 경고 없이 정착 허용) / §0.7.5 (100% 정착 stuck-until-timeout 정책, v2에서 갱신) / §3.5 (4-카운터 무변경) / §0.2 (어휘 정책)
**관련 코드 SoT**: `scripts/ant/Ant.gd` (phase 14 trait dict + ancestor mantle resolve), `scripts/ant/states/`, `scripts/skills/`, `scripts/core/SkillRegistry.gd`, `scripts/core/StageLayoutData.gd`, `scripts/core/StageRunner.gd` (`_time_left`/`_living_ant_count` SoT — v2 F1 분석 인용), `scripts/world/StageLayoutBuilder.gd`, `scenes/stages/dev/TraitTest.tscn` (phase 14 dev stage 패턴)
**리뷰 보존**: [phases/mvp/reviews/phase15-plan-review.md](../reviews/phase15-plan-review.md)
**작성**: 2026-05-22

---

## 0.2 v2 → v3 변경 (Round 2 needs-attention MEDIUM only 대응 inline)

| 항목 | v2 | v3 | finding |
|---|---|---|---|
| §0 한 줄 요약 line 29 | "...100% 정착 시 fail 미발화 (§0.7.5)" — v1 표현 잔존 | **명시적 contract 갱신**: `stage_cleared`·`stage_failed("no_more_ants")` 모두 미발화 + `stage_failed("time_out")`은 그대로 발화 = 제한 시간 도달까지 진행 후 사탕 손실로 자연 종료. PROPOSAL §0.7.5 갱신본 정합 | F-R2-M1 [medium] — F1 contract 모순 잔존 |
| PROPOSAL §0.7.5 본문 | "puzzle stuck"·"timeout fail"·"stage_stuck"·"saved/lost"·"no_more_ants" 평문 사용 (§0.2 forbidden vocabulary) | **§0.2 어휘 정책 정합 재작성** — "막힌 상태"·"제한 시간 도달까지 자연 종료"·"사탕 손실"·"탈락" 등 §0.2 허용 어휘 평문 사용. 코드 식별자(`stage_failed`, `_time_left`, `in_transit_pieces` 등)는 backtick으로 명시 마킹 | F-R2-M2 [medium] — §0.2 톤 폴리시 위반 |

## 0.1 v1 → v2 변경 (Round 1 needs-attention 대응)

| 항목 | v1 | v2 | finding |
|---|---|---|---|
| 100% 정착 stuck contract (§4.3) | "fail/clear 미발화 = 영구 stuck" | **"stuck-until-timeout"** — `_time_left=0` 도달 시 `stage_failed("time_out")` 자연 발화 수용. SettledState ant는 `_living_ant_count`에 포함되어 `no_more_ants` 경로는 차단되지만 `time_out` 경로는 그대로 진행. PROPOSAL §0.7.5 본문도 동시 갱신 (별도 stuck 시그널 미신설, polish phase 20에서 timeout fail variant로 표현 여지) | F1 [high] — StageRunner.gd:112-115 `_time_left <= 0.0` time_out fail 경로 인지 누락 |
| `SettlementHundredPercentStuckTest` (§2.5) | 60초 stuck 후 fail/clear 미수신 확인 | **time_limit 단축 dev layout 사용 + time_limit 도달 후 `stage_failed("time_out")` 수신 확인**. test layout `time_limit_seconds=12`, total_ants=3로 빠른 검증. clear 미발화 + `no_more_ants` 미발화는 그대로 유지, **timeout fail만 expect**. PROPOSAL §0.7.5 stuck-until-timeout 검증 | F1 [high] 후속 — test가 actual contract와 정합 |
| `SettlementMarker._on_body_entered` (§4.2) | 즉시 has_candy 검사 후 settle | **`await get_tree().physics_frame`으로 한 frame 지연 후 has_candy 재검사** → Candy.body_entered가 먼저 처리되어 has_candy=true 반영되면 정착 무시. 동일-frame race 결정성 보장. _distributor 자기 자신 멱등 처리도 동시 확인 | F2 [medium] — Area2D body_entered callback 순서 비결정 race |
| `SettlementSameFrameRaceTest` (§2.5) | 없음 | **신규 헤드리스 테스트** — Candy + SettlementMarker가 겹치도록 layout 구성, 분배자가 같은 frame에 둘 다 진입 시 has_candy=true 우선 + SettledState 미진입 확인 | F2 [medium] 후속 검증 |
| TRANSFER_WHITELIST SoT (§4.2 / §5.1) | `SettledState.TRANSFER_WHITELIST` const + `SettlementMarker.transfer_whitelist` @export | **single SoT** — `SettlementMarker.transfer_whitelist` @export 제거, `_transfer_traits()`에서 `SettledState.TRANSFER_WHITELIST` 직접 참조. scene-level override 제거 (필요 시 phase 16+에서 별도 결정으로 재도입) | F3 [medium] — 2-SoT silent drift 위험 |
| PROPOSAL §0.7.5 갱신 인용 (header) | "회수 동선 정책" | **"100% 정착 stuck-until-timeout 정책, v2에서 갱신"** — 본 phase plan 작성과 동시에 PROPOSAL.md §0.7.5 본문 수정 commit (2026-05-22). plan과 1차 SoT 정합 유지 | F1 [high] 후속 — PROPOSAL.md 본문이 plan의 stuck-until-timeout 정합 보장 |

---

---

## 0. 한 줄 요약

민들레씨 분배자(`distributor`) 스킬과 정착(`SettledState`) + 능력 전이(`floater` 화이트리스트) 시스템 도입. 분배자 스킬 적용 + 빈손(=not `has_candy`) + 위치 기반(settlement cell) 도달 시 `SettledState`로 영구 진입. 정착 좌표 Area2D가 활성화되어 후속 walker 개미 진입 시 분배자 보유 화이트리스트 트레잇을 자동 부여. 정착 메커니즘은 phase 14 trait dict 위에 단일 `set_settled()`/`is_settled()` API로 추가. **Blocker(phase 4)는 본 phase 무변경 — `WorkerState.new("blocker")` 그대로 유지, SettledState 통합은 phase 16+ 정착 시스템 확장 시 재검토(D2 추가 결정으로 deferred 명시)**. ScoreSystem 4-카운터(ADR-002) 무변경 — 정착 개미는 `in_transit_pieces`에서 제거되어 `saved_pieces`/`lost_pieces` 어디에도 누적되지 않는 잠재 상태. **100% 정착 시 contract (v2 F1 + v3 F-R2-M1 갱신, PROPOSAL §0.7.5 정합)**: candy `hp > 0` 잔존 + 즉시 트리거되는 `stage_cleared`/`stage_failed("no_more_ants")`는 모두 미발화. 단 `StageRunner._time_left = 0` 도달 시 기존 `stage_failed("time_out")`은 그대로 발화 (코드 SoT — StageRunner.gd:112-115). 즉 stuck-until-timeout — 제한 시간 도달 시 사탕 손실로 자연 종료. dev 검증 stage는 phase 14 TraitTest.tscn 패턴 답습 — 별도 `SettleTest.tscn` 신설.

---

## 1. Open decisions before implementation — 결정 (frontmatter doc §"Open decisions" 11건 승격)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D1 | 정착 트리거 조건 | **위치 기반** — stage layout이 정의한 단일 `settlement_cell` cell 좌표에 분배자가 도달 시 자동 트리거 | 사용자 결정 (Recommended). 레벨 디자이너가 정착 위치를 설계 가능 → puzzle 설계 주도성. 타이머/입력은 예측 어렵거나 UX 복잡. PROPOSAL §3.1.3 A안과 정합 |
| D2 | 정착 후 상태 머신 | **신규 `SettledState`** — phase 14 ClimberState/FallerState 패턴 답습 (leaf state, AntStateMachine.change_state로 전이). 별도 controller 노드 미신설 | 추천안. Phase 14 패턴 일관성 + 단일 책임. settlement controller는 정착 1종일 때 과대. enter()에서 `_settle_pos` 캡처 + velocity=0, exit() 없음(terminal) |
| D2-ext | Blocker SettledState 통합 | **본 phase 무변경 — Blocker는 `WorkerState.new("blocker")` 그대로 유지. SettledState 통합 deferred (phase 16+ 정착 시스템 확장 시 재검토)** | 추천안 + 사용자 redirect 가능. spec §"변경 대상"의 "Blocker 스킬 + 분배자 스킬 등록"은 phase 14에 BlockerSkill 이미 등록됨을 contextual 언급한 표현으로 해석 (의미 카테고리 묶음). Blocker는 phase 4 회귀 + 4-카운터 정합 이미 잡혀 있어 SettledState 마이그레이션이 phase 4 회귀 위험·작업량 폭증. Phase 15 scope = **분배자만 신규** |
| D3 | 정착 해제 허용 | **불가(영구)** — SavedState/DeadState와 유사한 terminal state. 한 번 정착하면 SettledState 머무름. exit() 무사용 | 추천안. MVP 단순성. 능력 전이는 정착 영구화로 후속 ant 진입 보장. 해제 추가 시 transfer race condition 발생 위험 |
| D4 | 능력 전이 범위 | **정착 좌표 Area2D 진입** — `SettlementMarker.tscn` (Area2D, collision_mask=Layer 3 ant) 노드가 분배자 정착 후 활성화. walker 진입 → `set_trait(name)` 호출 | 사용자 결정 (Recommended). 결정론적, 공간적 의미 명확. 반경/시간은 race condition 위험. 직접 접촉은 분배자 본인 충돌 처리 복잡 |
| D5 | 전이 시각화 | **정착 개미 머리 위 `SettleBadge` 아이콘 (Sprite2D, visible toggle, TraitBadges 패턴 답습)** + 전이 발생 시 transient flash (수신 개미 머리 위 0.5s short sprite, fade out). 파티클 없음 (phase 20 polish 영역) | 추천안. Phase 14 TraitBadges 시각 전용 패턴 + 일관성. flash는 단순 Tween 1줄. 파티클은 polish phase로 이연 |
| D6 | 트레잇 중복 부여 (분배자 보유) | **무시(idempotent)** — phase 14 `set_trait`이 이미 dictionary에 동일 키 두 번 set 시 무영향. 별도 분기 불필요 | 추천안. 단순성. set_trait의 idempotent 본질 그대로 활용. 갱신/스택은 의미 약함 |
| D7 | 전이 가능 트레잇 화이트리스트 | **`const TRANSFER_WHITELIST: Array[StringName] = [&"floater"]`** (`SettledState.gd` 상수). Climber 제외 | 사용자 결정 (Recommended). Climber는 수직 적응이라 분배자 정착 좌표에 머무는 행동과 의미적 충돌. Floater만 능력 전이의 1차 대상. Phase 16+ 트레잇 추가 시 명시적 등록 필요 (코드 grep으로 추적 가능) |
| D8 | 분배자 정착 중 사탕 충돌 우선순위 | **운반 > 정착** — 분배자가 `has_candy=true`면 settlement cell 도달해도 정착 무시(WalkerState/CarryingState 유지). 빈손(`has_candy=false`)일 때만 정착 트리거 발화 | 추천안. PROPOSAL §3.1.3 A안 일관성 (정착이 운반 흐름을 끊지 않음). Carrying 상태에서 정착 즉시 트리거 시 in_transit 영구 잔존 + 사탕 회수 불가 → 클리어 데드락 (BlockerSkill의 carrying 거부 정책과 동일 사유). 분배자가 home 회수 완료 후 다시 빈손으로 settlement cell 도달 시 정착 트리거 |
| D9 | 전이 받는 개미 중복 트레잇 | **D6과 동일 규칙 (무시 / idempotent)** | 추천안. set_trait의 idempotent 본질 그대로. 사용자 결정 D6과 같음 |
| D10 | 정착 직후 hazard 진입 시 전이 처리 | **phase 17(hazard) 도입 시 결정 — phase 15 deferred** — phase 15 시점에 hazard 없음. plan/구현/테스트에서 "hazard 미존재 가정"으로 진행. phase 17 plan 단계에서 SettledState ↔ hazard 상호작용 결정 (현 추정: 정착 = terminal이므로 hazard 영향 0, 단 전이 발생 도중 hazard 도착 시는 phase 17 결정) | 추천안. phase 15 시점 hazard 부재로 결정 의미 없음. PROPOSAL §3.1.4 TBD 그대로 phase 17 plan으로 이연 |
| D11 | settled 카운터 추가 | **추가 안 함** — ADR-002 4-카운터 그대로 유지. 정착 개미는 in_transit에서 제거되어 saved/lost 어디에도 속하지 않는 잠재 상태. HUD/목표 표시 필요 시 `ScoreSystem.get_settled_count()` 같은 계산 메서드로 노출 가능(phase 15에는 미구현, phase 20 polish 영역) | 사용자 결정 (Recommended). PROPOSAL §3.5 기본 판단 유지. ScoreSystem 불변식 완화 + Phase 14까지의 4-카운터 코드 회귀 위험 회피 |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)
| 파일 | 용도 |
|---|---|
| `scripts/ant/states/SettledState.gd` | 새 terminal state. enter()에서 `_settle_pos` 캡처 + `velocity=Vector2.ZERO` + `_aborted=false`. update(delta)는 중력만 — `is_on_floor()` 검사로 떠있으면 약한 중력 적용 (정착 cell이 platform 위에 있으므로 정상 시 floor 유지). exit() 없음 (terminal). `TRANSFER_WHITELIST: Array[StringName] = [&"floater"]` 상수 보유 |
| `scripts/skills/DistributorSkill.gd` | ID `"distributor"`. `Ant.set_trait(&"distributor")` 호출. can_apply 조건 §3.2: WalkerState 또는 CarryingState + not has_trait("distributor") + is_alive() |
| `scripts/world/SettlementMarker.gd` | Area2D 노드. layout.settlement_cell + builder.cell_to_world로 위치 결정. 본인 collision_mask=Layer 3 (Ant). `_distributor: Ant = null` 추적. **`_on_body_entered`는 `await get_tree().physics_frame` 이후 has_candy 재검사 (v2 F2 대응)** — Candy.body_entered가 먼저 처리되어 has_candy 갱신됐을 가능성 흡수. 분배자가 진입(body_entered) + has_candy=false 유지 시 `_settle_distributor(ant)` → ant.state_machine.change_state(SettledState.new()) + `_distributor=ant` + `monitoring=true` 유지. 후속 walker(non-distributor) 진입 시 `_transfer_traits(ant)` — **`SettledState.TRANSFER_WHITELIST` 직접 참조 (single SoT, v2 F3 대응 — 자체 @export 미보유)** 각 트레잇에 대해 `_distributor.has_trait(t)`면 ant.set_trait(t) |

### 2.2 수정 (.gd)
| 파일 | 변경 |
|---|---|
| `scripts/ant/Ant.gd` | 직접 변경 0건 — 분배자/정착 표식은 모두 `traits[&"distributor"]` + state(SettledState)로 표현. `_update_trait_badges()`에 SettleBadge 분기 1줄 추가 (`_settle_badge.visible = state_machine.current_state is SettledState`). class import는 `SettledState`의 hash check 회피 위해 `is StringName` lookup으로 유지 |
| `scripts/ant/states/WalkerState.gd` | 변경 없음. SettlementMarker가 SettledState 전이를 외부 트리거 |
| `scripts/ant/states/CarryingState.gd` | 변경 없음. D8 (운반 우선)이라 분배자가 운반 중이면 SettlementMarker가 무시 |
| `scripts/core/SkillRegistry.gd` | `SKILL_SCRIPTS` 배열에 `preload("res://scripts/skills/DistributorSkill.gd")` 1줄 추가 (CLAUDE.md CRITICAL — 자기등록 금지) |
| `scripts/core/StageLayoutData.gd` | `@export var settlement_cell: Vector2i = Vector2i(-1, -1)` 1줄 추가. `(-1, -1)`은 "settlement 미설정" 센티넬 (stage layout이 정착 메커니즘 미사용 시) |
| `scripts/world/StageLayoutBuilder.gd` | 변경 없음. SettlementMarker는 stage scene이 wiring (StageLayoutBuilder가 자동 생성하지 않음 — 마커 노드는 scene-side responsibility) |

### 2.3 수정 (.tscn)
| 파일 | 변경 |
|---|---|
| `scenes/entities/Ant.tscn` | `TraitBadges` 노드 아래 `SettleBadge` Sprite2D 자식 추가. position=(0,0) (ClimberBadge와 동일 좌표지만 z-index +1로 우선), texture=`assets/icons/skills/distributor.svg` (phase 9에서 prep된 24x24 svg 재사용 가능 여부 §7.1에서 확인). scale=0.5, visible=false |

### 2.4 신규 (검증 stage)
| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_settle_test_layout.tres` | StageLayoutData. cell_size=32. layout 셀 좌표는 §6.1 도식 → §6.2 cell 좌표표. home_cell, candy_cell, camera_cell, spawn_direction, **`settlement_cell` 신규 필드 사용** |
| `data/stages/dev/settle_test.tres` | StageData. id=902 (dev 예약, 901 trait_test는 phase 14에 점유), display_name="dev-settle-test", available_skills=`["climber","floater","distributor"]`, skill_inventory=`{"climber":1,"floater":2,"distributor":1}`, total_ants=6, candy_hp=6, time_limit=180, release_rate_initial=30. 메뉴 노출 X (id ≥ 900은 dev 예약). **수동/통합 검증용 — 헤드리스 stuck test는 별도 짧은 layout(`settle_test_stuck.tres` id=903, time_limit=12, total_ants=3)을 §2.5에 분리 (v2 F1 대응)** |
| `data/stages/dev/settle_test_stuck.tres` (v2 신규) | StageData. id=903, display_name="dev-settle-stuck-timeout", available_skills=`["distributor"]`, skill_inventory=`{"distributor":3}`, total_ants=3, candy_hp=3, **time_limit_seconds=12** (짧은 timeout으로 stuck-until-timeout 검증), release_rate_initial=30. SettlementHundredPercentStuckTest 전용. 메뉴 노출 X |
| `data/stage_layouts/dev_settle_stuck_layout.tres` (v2 신규) | StageLayoutData. 분배자 3명이 모두 정착 가능한 단순 layout. settlement_cell 1개 (분배자가 진입 시 정착, 그러나 분배자 본인 +1만 정착 가능 — 첫 분배자 정착 후 _distributor!=null이면 후속 분배자는 walker로 분류되어 transfer는 받지만 정착은 못함 → 100% 정착 시뮬레이션은 다른 방식 필요). **수정: 100% 정착 시뮬레이션은 SettlementMarker 1개 + 분배자 1명 + 사탕 회수 불가능 layout(home과 candy 사이에 분배자만 통과하는 좁은 길)으로 구성** — 분배자 정착 후 후속 walker가 candy 도달 불가 → in_transit 0 + saved 0 유지 + timeout으로 stage_failed 발화. 검증 명제: candy_hp가 deplete되지 않은 채 timeout으로 fail 발화. layout 상세 §6.5 (신규 도식) |
| `scenes/stages/dev/SettleStuckTest.tscn` (v2 신규) | Stage scene. SettleTest.tscn 패턴 복제 + dev_settle_stuck_layout + settle_test_stuck.tres. SkillToolbar 포함 |
| `scenes/stages/dev/SettleTest.tscn` | Stage scene. **Stage02/Stage03 패턴 + TraitTest.tscn 패턴 답습** — SkillToolbar ext_resource + node + StageRunner.toolbar_path. World/StageLayoutBuilder가 dev_settle_test_layout.tres wiring. 추가로 World 아래 `SettlementMarker` 노드(SettlementMarker.tscn 인스턴스) 1개 — layout.settlement_cell + builder.cell_to_world() 결과를 scene에 직접 좌표 기록 (StageLayoutBuilder가 자동 위치시키지 않음 — D4 결정 §6.3 참조) |
| `scenes/world/SettlementMarker.tscn` | Area2D scene. collision_layer=8(미사용 예약), collision_mask=4(Layer 3 ant). CollisionShape2D + RectangleShape2D extents=(16,16). visible 시각 표식 (Sprite2D 단순 32x32 텍스처) — 정착 미발생 상태는 반투명 알파 0.4, 분배자 정착 후 알파 1.0으로 변환 (Tween 단순). 시각은 폴리시 영역으로 phase 20에서 재검토 |

### 2.5 신규 (tests/)
| 파일 | 검증 |
|---|---|
| `tests/DistributorSettleTest.tscn/gd` | 헤드리스. dev_settle_test_layout 사용. 첫 ant에 DistributorSkill.apply → settlement_cell 도달 → SettledState 진입 + has_trait("distributor") 유지 + velocity=ZERO. PASS = 30초 내 ant.state_machine.current_state is SettledState + ant.global_position이 settlement_cell world 좌표 ±4px 이내. FAIL = 30초 후에도 WalkerState |
| `tests/DistributorCarryingPriorityTest.tscn/gd` | 헤드리스. 분배자 ant가 사탕 픽업 + 운반 중 settlement_cell 통과 → 정착 무시(D8). PASS = SettlementMarker overlap 발생 직후 ant.state_machine.current_state is CarryingState + has_candy=true 유지. 두 번째 라운드 — home 회수 후 빈손으로 settlement_cell 재진입 시 SettledState 전이 확인 |
| `tests/SettlementTraitTransferTest.tscn/gd` | 헤드리스. 분배자 ant에 FloaterSkill 부여 → settlement_cell 정착 → 후속 walker(non-distributor) 진입 → has_trait(&"floater") true 검증 + 그 walker가 절벽에서 FallerState 진입 시 FLOATER_GRAVITY_SCALE(0.3) 적용 확인. PASS = 후속 ant.has_trait(&"floater") + FallerState.velocity.y delta < 0.4 * gravity * delta (5 frame 평균) |
| `tests/SettlementHundredPercentStuckTest.tscn/gd` (v2 수정) | 헤드리스. **dev_settle_stuck_layout + settle_test_stuck.tres(time_limit=12) 사용**. 분배자 1명 정착 + 후속 walker가 candy 도달 불가능한 layout → in_transit 0 + saved 0 + candy_hp > 0 유지. **PROPOSAL §0.7.5 stuck-until-timeout 정책 검증** — PASS = (1) test 시작 후 12초까지 `stage_cleared` 미수신 + `stage_failed("no_more_ants")` 미수신, (2) 12초 직후(15초까지 awaited) `stage_failed("time_out")` 정확히 1회 수신, (3) ScoreSystem 4-카운터 invariant `saved + in_transit + lost <= original_hp` 시점별 유지. **clear 경로(`is_cleared()`) 및 `no_more_ants` 경로(`_living_ant_count==0`)가 모두 미발화하는지 확인** — settled ant도 `ants` group + `_spawn_parent` 자손이므로 `_living_ant_count`에 +1 카운트되어 차단 |
| `tests/SettlementSameFrameRaceTest.tscn/gd` (v2 신규) | 헤드리스. **F2 [medium] 회귀 가드** — Candy와 SettlementMarker가 겹치도록 layout (settlement_cell == candy_cell 또는 인접) 구성. 분배자 ant가 두 Area2D에 같은 frame 진입. SettlementMarker는 `await physics_frame` 후 has_candy 재검사 → Candy.body_entered가 같은 frame에 has_candy=true 설정했다면 정착 무시. PASS = ant.state_machine.current_state is CarryingState + has_candy=true + _distributor==null (정착 미발생). 시뮬레이션 길이 5초로 충분. layout: 분배자가 spawn → 즉시 Candy + SettlementMarker가 겹친 cell 진입 (스폰 위치를 candy/marker cell 바로 옆으로) |

### 2.6 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 신규 시그널 0건. 정착·전이 알림은 phase 15 범위 외(phase 20 polish의 UI feedback 시 추가 가능).
- `scripts/core/ScoreSystem.gd` — 4-카운터(ADR-002) 무영향. settled 카운터 미신설 (D11). 정착 ant는 in_transit에서 제거되지만 saved/lost 어디에도 미합산. invariant 그대로.
- `scripts/core/StageData.gd` — 필드 추가 0건. 기존 available_skills/skill_inventory가 "distributor" 문자열 ID 지원.
- `scripts/core/StageRunner.gd` — 무변경. SettlementMarker는 World subtree 노드. StageRunner는 clear/fail 조건 계산만 — settlement은 candy_depleted 시그널 미발화로 자연스럽게 stuck 처리.
- `scripts/skills/Skill.gd`, `BuilderSkill.gd`, `BlockerSkill.gd`, `ClimberSkill.gd`, `FloaterSkill.gd` — 무변경.
- `scripts/ant/states/SavedState.gd`, `DeadState.gd`, `WorkerState.gd`, `WalkerState.gd`, `CarryingState.gd`, `FallerState.gd`, `ClimberState.gd` — 무변경.
- `scripts/ui/SkillToolbar.gd` — distributor 아이콘/라벨 매핑은 phase 9 ICONS/KO_LABELS에 등록 필요. **§7.1 사전 점검 항목** — phase 9에서 prep된 distributor.svg 자산이 있는지 확인 + 없으면 phase 9 sweep 또는 phase 20 polish로 이연. 본 phase에서는 svg 없으면 placeholder (24x24 단색 원)으로 SkillToolbar 동작만 검증.
- `scripts/ui/HUD.gd` — 무변경. settled 카운터 미표시 (D11).
- 기존 stages Stage01~03 / data/stages/stage0N.tres — 정착/분배자 미사용. 회귀 무영향.
- `scenes/stages/dev/TraitTest.tscn`, `data/stages/dev/trait_test.tres`, `data/stage_layouts/dev_trait_test_layout.tres` — phase 14 dev stage. 분배자 미사용. 회귀 무영향.

---

## 3. Skill 명세

### 3.1 DistributorSkill.gd
```gdscript
class_name DistributorSkill extends Skill

const ID: String = "distributor"

func can_apply(ant: Ant) -> bool:
    if ant == null or ant.state_machine == null:
        return false
    if not ant.is_alive():
        return false
    if ant.has_trait(&"distributor"):
        return false
    var s: AntState = ant.state_machine.current_state
    # WalkerState 또는 CarryingState 허용. Worker(blocker/builder)/Climber/Faller/Settled 거부.
    # Faller 거부 — Floater와 달리 분배자는 공중 부여 의미 약함(정착 위치까지 도달 불가능 위험).
    if not (s is WalkerState or s is CarryingState):
        return false
    return true

func apply(ant: Ant) -> void:
    if ant == null:
        return
    ant.set_trait(&"distributor")
```

### 3.2 can_apply 비교표 (phase 14 + phase 15)
| Skill | WalkerState | CarryingState | FallerState | ClimberState | WorkerState | SettledState | 추가 조건 |
|---|---|---|---|---|---|---|---|
| Builder | ✓ (on_floor) | ✗ | ✗ | ✗ | ✗ | ✗ | not has_candy |
| Blocker | ✓ (on_floor) | ✗ | ✗ | ✗ | ✗ | ✗ | not has_candy |
| Climber | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | not has_trait(climber) |
| Floater | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | not has_trait(floater), is_alive |
| **Distributor** | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | not has_trait(distributor), is_alive |

---

## 4. 정착 메커니즘 명세

### 4.1 SettledState.gd
```gdscript
class_name SettledState extends AntState

# 화이트리스트 (D7) — phase 15에서는 floater만. Phase 16+ 트레잇 추가 시 명시적 등록.
const TRANSFER_WHITELIST: Array[StringName] = [&"floater"]

var _settle_pos: Vector2 = Vector2.ZERO

func enter() -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    _settle_pos = a.global_position
    a.velocity = Vector2.ZERO
    # blocker hitbox 정리 (분배자가 blocker 스킬 받지 못함 — can_apply 표 참조 — 하지만 멱등 호출).
    a.set_blocker_active(false)

func update(delta: float) -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    # 중력만 적용 — 정착 cell이 platform 위에 있다는 가정. 떠있으면 floor 도착까지 자유낙하.
    # Faller로 전이 안 함 — SettledState는 terminal. (D3: 해제 불가)
    if not a.is_on_floor():
        a.velocity.y += a.gravity * delta
    else:
        a.velocity = Vector2.ZERO
    a.velocity.x = 0.0
    a.move_and_slide()
    # 위치 anchor — 좌우 이동 0이지만 push로 살짝 밀릴 수 있어 _settle_pos.x 복원.
    a.global_position.x = _settle_pos.x
```

### 4.2 SettlementMarker.gd (v2 — F2 deferred re-check + F3 single SoT 적용)
```gdscript
class_name SettlementMarker extends Area2D

# v2 F3: TRANSFER_WHITELIST는 SettledState.TRANSFER_WHITELIST를 직접 참조 (single SoT).
# @export 미보유 — scene-side override 의도적 미허용 (phase 16+에서 별도 결정으로 재도입 가능).

var _distributor: Ant = null

func _ready() -> void:
    monitoring = true
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    var ant: Ant = body as Ant
    if ant == null or not is_instance_valid(ant):
        return
    # v2 F2: 한 frame 지연 후 has_candy 재검사 — Candy.body_entered가 같은 frame에
    # 먼저 처리되었다면 has_candy=true 갱신 완료. 동일-frame race 결정성 보장.
    await get_tree().physics_frame
    if not is_instance_valid(ant):
        return
    if ant.state_machine == null:
        return
    # D8: 운반 > 정착. has_candy=true면 정착 무시 (carrying/walker 모두 동일 가드).
    if ant.has_candy:
        return
    var s: AntState = ant.state_machine.current_state
    # 분배자 본인의 정착 트리거.
    if _distributor == null and ant.has_trait(&"distributor"):
        # Walker 상태일 때만 정착 (Carrying/Faller/Climber/Worker는 거부 — D8 carrying 가드 이미 통과했으므로 사실상 Walker만 도달).
        if not (s is WalkerState):
            return
        _distributor = ant
        ant.state_machine.change_state(SettledState.new())
        return
    # 분배자 정착 후 후속 walker 진입 → 능력 전이.
    if _distributor != null and is_instance_valid(_distributor):
        if ant == _distributor:
            return   # self idempotent
        if not (s is WalkerState or s is CarryingState):
            return   # Faller/Worker/Settled/Saved/Dead 거부
        _transfer_traits(ant)

func _transfer_traits(receiver: Ant) -> void:
    # v2 F3: single SoT — SettledState.TRANSFER_WHITELIST 직접 참조.
    for t in SettledState.TRANSFER_WHITELIST:
        if _distributor.has_trait(t):
            receiver.set_trait(t)   # D6/D9: 이미 보유면 idempotent no-op
```

### 4.3 100% 정착 stuck 처리 — stuck-until-timeout 정책 (v2 F1 대응, PROPOSAL §0.7.5 갱신본 정합)
- 모든 분배자가 정착하면 in_transit 0 + saved 0 + lost 0 + candy_hp > 0 잔존 가능.
- `ScoreSystem.candy_depleted`는 `candy.hp == 0`일 때만 발화 → 발화 안 됨 → `StageRunner.is_cleared()` 미충족 → `stage_cleared` 미발화.
- StageRunner `no_more_ants` 경로 — SettledState ant도 `ants` group + `_spawn_parent` 자손이라 `_living_ant_count()`에 +1 카운트 → 조건 미충족 → `stage_failed("no_more_ants")` 미발화.
- **StageRunner `time_out` 경로 — `_time_left <= 0.0` 도달 시 `stage_failed("time_out")` 그대로 발화** (StageRunner.gd:112-115). 본 stuck contract는 "stuck-until-timeout" — puzzle 본질 신호는 timeout fail의 "time over" 메시지로 표현된다.
- **결과**: time_limit 도달까지 게임 진행 → 도달 시 timeout fail로 자연 종료. 사용자는 restart 결정. ScoreSystem 4-카운터 invariant `saved + in_transit + lost ≤ original_hp` 자연 유지 (정착은 어떤 카운터에도 누적 X).
- 별도 `stage_stuck` 시그널/UI는 phase 15 범위 외 — phase 20 polish의 정산 UI 영역에서 timeout fail variant로 다룰 수 있다(미정, polish phase 자율).
- 검증: `tests/SettlementHundredPercentStuckTest.gd`가 dev_settle_stuck_layout (time_limit=12) 사용 — 12초 미만에서 clear/no_more_ants 미발화 확인 + 12초 직후 stage_failed("time_out") 정확히 1회 수신 확인.

---

## 5. 능력 전이 명세

### 5.1 화이트리스트 정책 (v2 F3 single SoT 적용)
- `SettledState.TRANSFER_WHITELIST = [&"floater"]` 상수 — **유일한 SoT**.
- `SettlementMarker`는 자체 @export 미보유. `_transfer_traits()`에서 `SettledState.TRANSFER_WHITELIST` 직접 참조.
- Phase 16+ 트레잇 추가 시 `SettledState.TRANSFER_WHITELIST` 1곳에만 등록. 코드 grep `TRANSFER_WHITELIST`로 추적.
- scene-side override 의도적 미허용 — 필요 시 phase 16+에서 별도 결정으로 재도입 (override flag + validation 패턴).

### 5.2 전이 동작
- D4: SettlementMarker.body_entered → 분배자 정착 후 walker/carrying 진입 → `_transfer_traits()` 호출.
- D6/D9: 이미 보유한 트레잇은 set_trait idempotent로 no-op.
- D7: Climber는 화이트리스트에 없어 미전이.

### 5.3 시각 피드백 (D5)
- 정착 개미: `SettleBadge` Sprite2D visible toggle. `_update_trait_badges()`에 1줄 분기 추가.
  - 시각만, 게임 로직 무영향 (phase 14 TraitBadges 패턴 정확히 답습).
- 전이 발생: 후속 ant 머리 위 0.5s transient sprite flash (Tween fade). 
  - **본 phase에서는 미구현 — phase 20 polish 영역으로 이연 (위 §2.3 SettleBadge만 phase 15 구현)**. 시각 피드백 없어도 메커닉 검증 헤드리스 가능.

---

## 6. dev 검증 stage 설계

### 6.1 layout 도식 (cell_size=32)
```
y\x  0         10        20  22     28        38
                         ▓▓                   
                         ▓▓                   
                         ▓▓▓▓▓▓▓▓▓▓▓▓▓        # y=22 platform
                         ▓  H           C     # y=23 home, candy 가까이
                         ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ # y=27 ground
```
- home_cell: (22, 22) — y=22 platform 위
- candy_cell: (35, 22)
- settlement_cell: (28, 22) — home과 candy 중간, walker 진행 방향에 자연스럽게 위치
- camera_cell: (30, 17)
- spawn_direction: 1 (오른쪽으로 walker 출발 → candy 도달 후 180° 회전 → 귀환)

### 6.2 cell 좌표표
```
platform_cells (y=22): (22,22)~(36,22)   # candy까지 닿는 길
platform_cells (y=27): (0,27)~(60,27)    # ground (안전망)
home_cell:        (22, 22)
candy_cell:       (35, 22)
settlement_cell:  (28, 22)
camera_cell:      (30, 17)
```

### 6.5 dev_settle_stuck_layout 설계 (v2 F1 — stuck-until-timeout 검증 전용)
- 100% stuck-until-timeout 시나리오를 강제하는 layout. 분배자 1명 정착 + 후속 walker가 candy에 도달 불가능한 구조.
- 기본 아이디어:
  - home과 settlement marker가 짧은 platform (y=22, x=10~14, 5 cell) 위. settlement_cell=(13,22).
  - platform 끝(x=14)에서 절벽 — walker가 settlement_cell 통과해도 candy 도달 길이 없음.
  - candy는 절벽 너머 별도 platform 또는 도달 불가능 위치(x=20, y=22).
  - ground(y=30 안전망) — walker가 절벽 fall 후 회귀해도 platform 재진입 불가 (계단 없음) → 무한 cycle.
- 분배자(스킬 부여된 3 ant 중 첫 도착자)가 settlement_cell 도달 → SettledState. 나머지 2 ant는 SettlementMarker가 `_distributor != null`로 walker 분류 → 절벽 fall → ground 회귀 → 무한 cycle.
- 결과 시점별:
  - in_transit 0 + saved 0 + lost 0 + candy_hp > 0 유지.
  - `_living_ant_count` = settled 1 + walker 2 = 3 → no_more_ants 미발화.
  - `is_cleared()` 미충족(candy_hp > 0) → cleared 미발화.
  - `_time_left=0` (time_limit=12 도달) → `stage_failed("time_out")` 정확히 1회 발화.
- 정확한 cell 좌표는 impl 단계에서 확정 (cell_size=32 + 60×34 layout 가정).

### 6.3 SettlementMarker 좌표 wiring
- StageLayoutBuilder는 SettlementMarker를 자동 생성하지 않음 (변경 없음).
- `SettleTest.tscn`이 World 아래 SettlementMarker 노드 직접 인스턴스화 + position을 `layout.cell_to_world(layout.settlement_cell)` 결과로 scene에 직접 기록 (32-cell 기준 settlement_cell=(28,22) → world (28*32+16, 22*32+16) = (912, 720)).
- editor 수동 검증 시 `data/stage_layouts/dev_settle_test_layout.tres`의 settlement_cell 변경 후 scene .tscn 좌표도 함께 갱신 필요 — 자동화는 phase 15 범위 외.

### 6.4 SettleTest.tscn 노드 구조 (Stage02/03 + TraitTest 패턴 답습)
```
StageRunner (Node, script=StageRunner.gd)
  stage_data = dev/settle_test.tres
  candy_path = NodePath("World/Candy")
  home_path = NodePath("World/Home")
  spawner_path = NodePath("Spawner")
  hud_path = NodePath("HUD")
  toolbar_path = NodePath("SkillToolbar")     # phase 14 패턴
  ant_scene = entities/Ant.tscn
  spawn_parent_path = NodePath("World")
├ World (Node2D)
│ ├ StageLayoutBuilder (Node2D, script=StageLayoutBuilder.gd)
│ │   layout = dev_settle_test_layout.tres
│ ├ Terrain (Node2D, script=Terrain.gd)
│ ├ Home (Area2D instance, position=cell_to_world(home_cell))
│ ├ Candy (Area2D instance, position=cell_to_world(candy_cell), hp=6)
│ ├ SettlementMarker (Area2D instance, position=cell_to_world(settlement_cell))
│ └ Camera2D (position=cell_to_world(camera_cell))
├ StageBackground (CanvasLayer instance, layer=-100)
├ Spawner (Node, script=AntSpawner.gd)
│   spawn_position = cell_to_world(home_cell) + Vector2(0, -5)
│   total = 6
│   release_rate = 30
│   spawn_direction = 1
├ HUD (CanvasLayer instance)
└ SkillToolbar (CanvasLayer instance)
```

---

## 7. 사전 점검 항목 (impl 시작 전 확인)

### 7.1 distributor.svg 아이콘 자산
- Phase 9에서 prep된 24x24 svg가 `assets/icons/skills/distributor.svg`에 있는지 확인.
- 미존재 시: phase 15 impl에서 24x24 단색 원 placeholder svg를 임시 생성 (별도 codex 디자인 트랙 아님) + phase 20 polish에서 정식 디자인 교체.
- SkillToolbar의 `ICONS`/`KO_LABELS` 매핑에 `"distributor"` 키 등록 (1줄씩).

### 7.2 StageSelect dev stage 노출 미여부 확인
- Phase 14 D5 결정 — dev id ≥ 900은 메뉴에서 노출 X. 검증: `MainMenuContinueGuardTest` 또는 `StageSelectUnlockTest`이 901(trait_test) 노출 안 함을 이미 검증했는지 확인. 미검증 시 phase 15 impl에서 902(settle_test)도 미노출 단언 추가.

### 7.3 ScoreSystem 정착 invariant 검증
- `tests/test_ScoreSystem.gd`에 "ant가 SettledState로 전이 시 in_transit -1, saved/lost 모두 무변경" 단위 테스트 추가 검토.
- 본 phase 헤드리스 통합 테스트 (`SettlementHundredPercentStuckTest`)에서 검증되므로 unit test 추가는 optional — 다만 ScoreSystem 시그널 핸들러를 새로 추가하지 않는다는 점만 plan 단계에서 확인.

---

## 8. 회귀 항목 (impl 후 검증)

1. **Stage 1~3 회귀** — distributor 미사용, settlement_cell 미설정. 기존 헤드리스 4종 PASS (Stage02HeadlessTest, Stage03HeadlessTest, BlockerOverlapTest, ClimberBlockerOverlapTest).
2. **Phase 14 trait 회귀** — ClimberTraitTest, FloaterTraitTest, TraitCombinedTest, ClimberStallTest, ClimberBlockerOverlapStallTest 모두 PASS.
3. **Skill registry** — SkillRegistry._skills에 "distributor" 등록 + Stage02/03 stage data validate 통과 (available_skills "distributor" 없음, 회귀 0).
4. **SkillToolbar UI** — distributor 아이콘 위치/라벨 정상 (수동 또는 SkillToolbarPositionGuardTest 확장).
5. **ScoreSystem invariant** — saved + in_transit + lost ≤ original_hp 모든 phase 15 헤드리스에서 유지.
6. **dev TraitTest.tscn** — phase 14 dev stage 단독 실행 시 distributor/settlement 미간섭 (회귀 0).

---

## 9. impl 단계 변경 요약 (체크리스트, v2 갱신)

- [ ] `scripts/ant/states/SettledState.gd` 신규 (TRANSFER_WHITELIST 상수 보유, v2 F3 single SoT)
- [ ] `scripts/skills/DistributorSkill.gd` 신규
- [ ] `scripts/world/SettlementMarker.gd` 신규 (**v2 F2 await physics_frame deferred re-check + v2 F3 @export 미보유**)
- [ ] `scripts/core/SkillRegistry.gd` SKILL_SCRIPTS에 DistributorSkill preload 1줄 추가
- [ ] `scripts/core/StageLayoutData.gd` settlement_cell 필드 1줄 추가
- [ ] `scripts/ant/Ant.gd` _update_trait_badges()에 SettleBadge 분기 1줄 (시각 전용)
- [ ] `scenes/entities/Ant.tscn` TraitBadges 아래 SettleBadge Sprite2D 자식 추가
- [ ] `scenes/world/SettlementMarker.tscn` 신규
- [ ] `data/stage_layouts/dev_settle_test_layout.tres` 신규 (정상 검증용)
- [ ] `data/stage_layouts/dev_settle_stuck_layout.tres` 신규 (**v2 F1 stuck-until-timeout 검증 전용**)
- [ ] `data/stages/dev/settle_test.tres` 신규 (id=902, time_limit=180)
- [ ] `data/stages/dev/settle_test_stuck.tres` 신규 (**v2 F1, id=903, time_limit=12**)
- [ ] `scenes/stages/dev/SettleTest.tscn` 신규
- [ ] `scenes/stages/dev/SettleStuckTest.tscn` 신규 (**v2 F1**)
- [ ] `tests/DistributorSettleTest.tscn/gd` 신규
- [ ] `tests/DistributorCarryingPriorityTest.tscn/gd` 신규
- [ ] `tests/SettlementTraitTransferTest.tscn/gd` 신규
- [ ] `tests/SettlementHundredPercentStuckTest.tscn/gd` 신규 (**v2 F1 갱신 — time_limit=12 후 stage_failed("time_out") 수신 확인**)
- [ ] `tests/SettlementSameFrameRaceTest.tscn/gd` 신규 (**v2 F2 회귀 가드 + DistributorCarryingPriorityTest 통합** — D8 carrying > settlement priority root cause 동일이라 1개 통합 테스트로 cover. 별도 layout `dev_settle_race_layout.tres`, stage `settle_test_race.tres`, scene `SettleRaceTest.tscn` 신설)
- [ ] ~~`tests/DistributorCarryingPriorityTest.tscn/gd` 신규~~ → **SameFrameRaceTest에 통합 (v3 impl 결정)**
- [ ] (SkillToolbar) distributor 아이콘/라벨 매핑 1줄씩 (icon 자산 §7.1)
- [ ] 회귀 (헤드리스 9종 + Phase 14 trait 5종 + ScoreSystem invariant) 확인
- [ ] PROPOSAL §0.7.5 stuck-until-timeout 갱신본 (별도 commit 또는 본 phase commit에 묶음) 확인

---

## 10. 표준 절차
plan-stage codex adversarial-review → CRITICAL/HIGH 0건이면 impl-stage 진입 → impl 자체 적대적 리뷰 → codex impl-stage 재리뷰 → clean까지. 자세한 흐름은 [phases/mvp/README.md](../README.md) 및 CLAUDE.md plan/impl stage 정책.

**작성**: 2026-05-22 / plan v3 — Round 2 codex needs-attention MEDIUM only(F-R2-M1 summary 모순 + F-R2-M2 §0.2 톤 폴리시 위반) inline 처리. v1 Round 1 finding(F1·F2·F3)은 v2에서 해소 확정 (Round 2 verdict 재발견 없음). PROPOSAL §0.7.5 §0.2 어휘 정합 재작성 commit 동반. v2 → v3 변경 표는 §0.2 참조. plan-stage 정책 — HIGH 0건이라 자동 중단 사유 없음, 사용자가 다음 단계(Round 3 추가 리뷰 vs impl 진입) 결정.
