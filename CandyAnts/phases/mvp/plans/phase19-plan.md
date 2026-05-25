# Phase 19 Plan — mechanic-destruction-plant (v3.1.1)

**Status**: plan v3.1.1 — codex adversarial-review **Round 4 verdict clean(2026-05-25, user-extended cap)** + R4-M1(row 컨벤션 wording) 정정 inline 반영. R3-H1/R3-M1은 v3.1에서 닫혔고 codex R4가 cross-doc grep으로 CLOSED 확인. R4-M1 MEDIUM은 본 v3.1.1에서 D4 본문 + §6.4 도식 캡션 정정으로 종결. impl-stage 진입 가능.
**Phase frontmatter doc**: [phases/mvp/phase19-mechanic-destruction-plant.md](../phase19-mechanic-destruction-plant.md)
**1차 SoT 인용**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §3.4 (파괴 메카닉) / §3.4.2 (Cutter + 식물 지형, 17b) / §5.2 (17 분할) / §0.2 (어휘 정책) / §7.1 (정수 id 정책)
**관련 코드 SoT**: `scripts/core/SkillRegistry.gd` (SKILL_SCRIPTS 명시적 preload, ADR-003), `scripts/skills/BasherSkill.gd` / `DiggerSkill.gd` (phase 18 destruction 패턴 — can_apply 가드 + WorkerState 진입), `scripts/ant/states/WorkerState.gd` (multi-mode 패턴 — builder/blocker/sand_mound/bridge/basher/digger 분기, phase 18 cutter 분기 추가), `scripts/world/Terrain.gd` (phase 18 `_static_bodies`/`_cell_kind`/`destroy_tile_at(allowed_kinds)`/`register_static_body(kind)` API 기존 보유 — phase 19는 인자 차이만), `scripts/world/StageLayoutBuilder.gd` (phase 18 `_add_cell` + `register_static_body("earth")` 기존, phase 19에서 `"plant"` tile_type 분기 추가), `scripts/ui/SkillToolbar.gd` (basher/digger 아이콘 + KO 라벨 패턴, cutter 추가), `scripts/ui/SkillSlot.gd` (SkillSlot atom — icon_texture, ko_label, set_count slot API), `assets/icons/skills/` (basher.svg / digger.svg 등, cutter.svg 신규)
**리뷰 보존**: [phases/mvp/reviews/phase19-plan-review.md](../reviews/phase19-plan-review.md) (Round 1~2 stdout 누적 완료)
**작성**: 2026-05-25 (v1 — 첫 작성), 2026-05-25 (v2 — Round 1 fix), 2026-05-25 (v3 — Round 2 fix), 2026-05-25 (v3.1 — Round 3 STOP 후 사용자 지시 수동 fix), 2026-05-25 (v3.1.1 — Round 4 clean + R4-M1 row 컨벤션 wording 정정)

---

## 0.0a v3 → v3.1 → v3.1.1 변경 (Round 3 STOP 후 사용자 지시 수동 fix + Round 4 user-extended cap clean + R4-M1 wording 정정)

| # | 항목 | 직전 버전 문제 | 수정 | finding |
|---|---|---|---|---|
| R3-H1 | §6.4 dev_cutter_over_hazard E6 spawn semantics | v3: 도식과 driver가 ant spawn (8,21)을 먼저 선언한 뒤, forward (9,21)이 plant가 아니라서 cutter가 abort된다고 인정하고 다시 "simplification"으로 (9,21) spawn을 제시. E6 구현자가 어느 좌표를 따라야 하는지 불명확 | v3.1: **ant spawn을 (9,21) 하나로 통일**. 도식의 `a` 위치, §6.4 bullet, E6 설명 모두 (9,21) direction=+1로 정정. 첫 cutter target은 (10,21)로 명시. (8,21) 경로와 simplification 문구 제거 | codex Round 3 [HIGH] R3-H1 (Round 4에서 CLOSED 확인) |
| R3-M1 | E8 backward-compat layout enumeration | v3: `data/stage_layouts/*.tres` 전수 검증을 말하면서 존재하지 않는 정적 파일명(`stage02_layout.tres`, `dev_traits_layout.tres` 등)을 함께 박제. literal 구현 시 test가 깨지거나 coverage가 손으로 관리됨 | v3.1: **동적 디렉터리 스캔만 SoT로 확정**. test driver는 `data/stage_layouts/*.tres`를 런타임에 scan/load/build하고, phase 19 신규 plant fixture 4종만 명시 exclude. stale static list 삭제. scan 결과 0건 또는 load/build 실패는 FAIL | codex Round 3 [MEDIUM] R3-M1 (Round 4에서 CLOSED 확인) |
| R4-M1 | D4 본문 / §6.4 캡션 row 컨벤션 wording | v3.1: D4 (b)/(c)가 "plant/earth cell은 floor row 배치"라 적었고 §6.4가 "일반 stage의 plant cell은 floor row 컨벤션"이라 적었으나, 실제 phase 19 모든 fixture(E1~E6)의 plant cell은 ant body row(y=21) 배치. Cutter forward 가드(`body_cell + Vector2i(dir, 0)`)도 body row 기준. 구현자가 wording을 따라 floor row(y=22) plant를 배치하면 Cutter 도달 0 | v3.1.1: **D4 (b)/(c) 재작성** — earth cell은 layout 자유, **Cutter 대상 plant cell은 phase 19 모든 fixture에서 body row(y=21)** 명시. typical cell-disjoint 근거를 "별개 row" → "별개 x좌표(둘 다 body row지만 x 다름)"로 정정. **§6.4 캡션 재작성** — "일반 stage의 plant cell은 floor row 컨벤션" 문장 제거, "phase 19 모든 fixture에서 body row 배치 컨벤션(§6.1~§6.4 일관)"으로 통일. D4 결정 헤더 본문(hazard=body row, plant=floor row)도 같이 정정 | codex Round 4 [MEDIUM] R4-M1 |

> v3.1은 R3 STOP 정책을 우회하는 자동 재리뷰가 아니라, 사용자의 명시 수정 지시에 따른 manual plan fix다. R3-H1은 플랜 내부 좌표 모순 수정으로 닫고, R3-M1은 MEDIUM이지만 구현자가 잘못된 목록을 복사할 위험이 커 함께 닫는다. v3.1.1은 사용자 cap 확장(R4)에서 codex가 **verdict clean**을 내고 잡은 MEDIUM R4-M1을 plan 내 wording 정정으로 inline 종결 — impl 진입 블로커가 아님에도 fixture(body row)와 D4/§6.4 wording의 silent contradiction을 사전 제거. 추가 라운드 없음.

## 0.0 v2 → v3 변경 (codex adversarial-review Round 2 HIGH 3건 + MEDIUM 1건 fix)

| # | 항목 | v2 | v3 | finding |
|---|---|---|---|---|
| R2-H1 | §6.4 dev_cutter_over_hazard layout primary fixture | plant + hazard same-cell을 floor row (10,22)에 배치. ant spawn (8,21)에서 cutter forward = (9,21) → plant (10,22) 미타격. 본문에 "alternate body-row 시나리오" 옵션 제공 + impl-stage 결정으로 미강제. 결과: E6 driver 작성자가 어느 시나리오 구현할지 불명 + plant 미타격이면 hazard monitoring invariant 검증 자체가 도달 안 됨 | **body-row same-cell 시나리오를 required primary fixture로 통일**. plant cell을 ant body row (10, 21)에 배치 + hazard도 동일 (10, 21) 좌표(`global_position = layout.cell_to_world(Vector2i(10, 21))`). ant spawn (8, 21) direction=+1 → cutter forward (9, 21) tick 1 → (10, 21) tick 2 시 cell kind="plant" → destroy 성공. 절단 후 ant 통과 시 hazard body_entered 자연 발화. **alternate scenario 제거**. §6.4 도식 + §2.5 E6 명세 둘 다 body-row primary로 갱신 | codex Round 2 [HIGH] R2-H1 |
| R2-H2 | §9 회귀 가드 마지막 문장 "phase 19 신규 essential 5종도 모두 PASS" | v2에서 essential 5→8 확장 + §0/§2.5/§7.1/§10 모두 갱신했으나 **§9 closing line만 stale "5종"** 잔존. impl-stage codex review가 §9 그대로 따르면 E6/E7/E8 skip 가능 → R1-H2/R1-M1 fix 무력화 | **§9 closing line "phase 19 신규 essential 8종" → "9종" (R2-H3 E9 추가 반영)**. essential test 이름을 명시 enumerate (E1~E9) + 각 test의 enforce invariant 1행씩. 추가로 `phase19-plan.md` 전수 stale "5" wording 검색 후 발견된 모든 site v3로 갱신 (v3 작성 시 본 fix 1회로 종결) | codex Round 2 [HIGH] R2-H2 |
| R2-H3 | E7 SkillRegistryCutterValidateTest의 SkillToolbar coverage 누락 | E7는 SkillRegistry.get_skill / validate_stage / _skills만 검증. SkillToolbar ICONS["cutter"] / KO_LABELS["cutter"] dict entry 누락 시 E7 PASS — §10 §6 (no skill_id collision **+ toolbar entries**) enforce 경로 단절 | **E9 SkillToolbarCutterIntegrationTest 신설**. SkillToolbar.tscn manual 인스턴스화 + stage_data 주입 (available_skills=["cutter"], skill_inventory={"cutter":2}) + _ready() 호출 후 SkillSlot atom 검증: (a) cutter slot 1개 생성, (b) slot.skill_id == StringName("cutter"), (c) slot.icon_texture == ICONS["cutter"] (non-null), (d) slot.ko_label == "절단". E7는 SkillRegistry-only로 유지(concern separation). essential 8→9종 확장 | codex Round 2 [HIGH] R2-H3 |
| R2-M1 | E8 StageLayoutBuilderEarthBackwardCompatTest single-sample | "기존 stage layout(예: stage01 또는 dev_basher_wall_layout)" — 1개 sample만 검증하면서 §10 §7는 "phase 1~18 dev/main 모두" claim → coverage gap. slope-only layout이나 phase 14~17 dev stage 회귀가 단일 sample test로는 미탐지 | **E8 parameterized 전수 검증으로 명세 강화**. test driver가 `data/stage_layouts/*.tres` 디렉토리 전수 enumeration (또는 명시 enumeration array: `stage01_layout, stage02_layout, stage03_layout, dev_basher_wall_layout, dev_digger_pillar_layout, dev_basher_digger_chain_layout, dev_basher_edge_stop_layout, ...` phase 14~17 dev 포함). 각 layout마다 Terrain + StageLayoutBuilder manual 인스턴스화 → build() → 전수 cell 순회 → `get_cell_kind(cell) == "earth"` AND plant kind 0건 assert. 어느 한 layout이라도 plant kind 발견 시 FAIL. coverage = phase 1~18 전체 | codex Round 2 [MEDIUM] R2-M1 |

> **v3 본체(§1~§11)는 v2의 design을 보존하고 R2-H1/H2/H3/M1 fix에 한해 inline 수정**. 결정 사항(D1~D10) 모두 무변경 — v2에서 D4만 wording 정정 후 v3에서 다시 정정 없음. essential count 8→9 (E9 신설). v3 변경 분기는 §6.4 도식·E6 명세·§9 closing wording·E9 신설·E8 parameterized 4건만. **v3.1은 R3-H1/R3-M1만 추가 정정**하며, E6 fixture 좌표 고정은 테스트 결정론을 위한 것이고 런타임 Cutter/plant 로직은 좌표 비의존이다.

**Plan-stage 정책 (CLAUDE.md 2026-05-25 갱신)**: 본 phase plan은 codex adversarial-review에서 **최대 2회까지 fix+재리뷰** 허용. R1(초기) → fix → R2 → fix → R3. R3에서 HIGH 1건이라도 발견되면 즉시 중단 + 사용자 결정. MEDIUM/LOW만 남으면 어느 라운드든 plan 내 처리 또는 명시 defer로 종결. 매 라운드 stdout은 `phase19-plan-review.md`에 `## Round N` 헤더로 누적.

---

## 0.1 v1 → v2 변경 (codex adversarial-review Round 1 HIGH 2건 + MEDIUM 1건 fix)

| # | 항목 | v1 | v2 | finding |
|---|---|---|---|---|
| R1-H1 | §2.3 dev_earth_plant_separation StageData (id=921, 4 ants × 4 candy_hp, inventory {basher:2,cutter:2}) | StageData + scene 정의되어 4명 ant 전원 candy 도달 시나리오 서술. 그러나 inventory 부족(ants 1-2가 basher 2 + cutter 2 소비하면 ants 3-4 inventory 0) + 자동 player toggling 부재로 unwinnable. headless test는 sequenced 분기만 검증 → "broken stage가 ship되어도 essential test PASS" 위험 | **layout-only fixture로 격하**. `data/stage_layouts/dev_earth_plant_separation_layout.tres`만 유지. `data/stages/dev/earth_plant_separation_test.tres` (id=921) + `scenes/stages/dev/EarthPlantSeparationTest.tscn` **제거**. E3/E4 essential test는 §6.3 layout 위에 manual Stage 인스턴스화 + 직접 ant 1명에 cutter (또는 basher) 적용 후 forward kind 검증 — 전체 stage 완주 시나리오 없음. dev id 점유 921 회수(920만 점유) | codex Round 1 [HIGH] R1-H1 |
| R1-H2 | §1.1 D4 결정 row "별개 cell row 컨벤션 + cell-disjoint 자연 분리 + PROPOSAL TBD 우선순위 질문 vacuous" | D4는 cell-disjoint를 vacuous 결론 근거로 사용. 그러나 §5 표는 "Cutter가 hazard 위 plant cell 진입 시도 (동일 layout cell)" 시나리오 명시. §2.6 CutterOverHazardCellTest는 deferred — acceptance 미포함. 자기 모순: D4가 cell-disjoint라면 §5 same-cell row가 dead, §5가 same-cell을 다루면 D4 vacuous 주장 무효. essential coverage 0건이라 overlap 회귀 ship 위험 | **D4 재작성**: typical layout은 row 컨벤션 차이로 cell-disjoint(hazard=body row, plant=floor row)이지만, **same-cell overlap은 layout 작성자가 명시적으로 선택할 수 있는 puzzle 디자인 도구**(예: 식물 위 끈끈이 spore)로 허용. 두 시스템 자료구조(`_cell_kind` vs `_hazards_by_cell`) 독립이므로 cross-check 0 — 그러나 의도된 행위(plant 절단 후 hazard 노드는 monitoring 유지)를 검증하기 위해 `CutterOverHazardCellTest`를 essential로 승격. PROPOSAL TBD "우선순위 질문"은 vacuous가 아닌 "별개 채널 + 독립 발화"로 답함. §5 표 wording도 "동일 layout cell" → "layout 작성자가 명시 배치한 same-cell" 명시 | codex Round 1 [HIGH] R1-H2 |
| R1-M1 | §2.5 essential 5종 + §10 strict acceptance §6/§7 enforce 경로 | essential 5종은 Cutter 행위/cross-kind/Terrain plant round-trip만 enforce. §10 §6 (SkillRegistry/SkillToolbar 통합) + §7 (StageLayoutBuilder backward-compat earth kind)는 deterministic gate 없음 → CutterSkill preload 누락·toolbar dict entry 누락·기존 stage kind 회귀가 essential 5 PASS 후에도 발생 가능 | **essential 5종 → 8종 확장**: (1) `CutterOverHazardCellTest` 승격(R1-H2와 통합), (2) `SkillRegistryCutterValidateTest` 신설 — `SkillRegistry.validate_stage(cutter_vine_stage)` 호출하여 "cutter" id가 known + validation errors 0 검증, (3) `StageLayoutBuilderEarthBackwardCompatTest` 신설 — 기존 stage layout(예: `data/stage_layouts/stage01_layout.tres` 또는 phase 18 `dev_basher_wall_layout.tres`) build 후 모든 generated cell의 `terrain.get_cell_kind(cell) == "earth"` 검증. §7.1 essential 표 8 rows로 갱신 + §10 strict acceptance §6/§7 각각 essential test 매핑 추가 | codex Round 1 [MEDIUM] R1-M1 |

> **v2 본체(§1~§11)는 v1의 design을 보존하고 R1-H1/H2/M1 fix에 한해 inline 수정**. 결정 사항(D1~D10) 중 D4만 wording 정정 + meaning shift(vacuous→명시 허용 + essential 검증). 나머지 9건 결정 무변경. essential count 5→8, deferred count 3→2, dev StageData 점유 920~921→920만(921 회수). codex Round 2 진입 시 본 §0.1 변경분과 본체 inline 정정 + §10 acceptance 갱신만 검수 대상.

---

## 0. 한 줄 요약 (v3 · v3.1.1 row wording 정정 반영)

식물 지형 동적 파괴 메카닉 1차 도입 — phase 18 (흙 파괴 17a) 자매 phase. **신규 스킬 1종**(Cutter = 수평 절단, Basher 패턴 답습) + **신규 정적 cell kind 1종**("plant", phase 18 D5 분류 체계 활용). Terrain은 phase 18에서 `_cell_kind` registry + `register_static_body(kind)` + `destroy_tile_at(allowed_kinds)` API를 이미 보유 — 본 phase는 **kind 인자 차이만** 발생하고 Terrain 코드 변경 0. `scripts/skills/CutterSkill.gd` 신설 + `SkillRegistry.SKILL_SCRIPTS` 1줄 추가. `WorkerState`에 `cutter` work_type 분기 1종 추가 (`_enter_cutter`/`_update_cutter`/`_destroy_cutter_cell` + `_cutter_forward_has_plant` helper — Basher 패턴 구조 그대로, kind 검사만 `"plant"`로 교체). `StageLayoutBuilder._add_cell`에 `tile_type == "plant"` 분기 추가 — body 생성 후 `register_static_body(cell, body, "plant")` 호출(기존 "earth" 분기와 평행). visual은 placeholder ColorRect(연두색 알파 0.85) — 정식 식물 텍스처는 phase 20 polish로 deferred. `SkillToolbar.gd`에 `cutter` 아이콘 + KO 라벨 `"절단"` 1줄씩 추가. Cutter는 ant 진행 방향의 body row cell을 12 cell까지 tick 단위로 제거(`CUTTER_TICK=0.18s`, `CUTTER_MAX_CELLS=12`, Basher와 동일 수치 — 메카닉 대칭 + plant=horizontal vine 무드보드 가정). 매 제거 시 `a.global_position.x += dir*cs`로 1 cell 전진(Basher와 동일). **메카닉 분리 invariant** (phase 19 핵심): Basher/Digger의 `allowed_kinds=["earth"]`는 plant cell 무영향, Cutter의 `allowed_kinds=["plant"]`는 earth cell 무영향 — Terrain.destroy_tile_at의 atomic kind 검사가 두 방향 모두 강제. **v3 누적 변경(R1+R2 fix)**:
- **v2 (R1-H1/H2/M1 fix)**: (1) dev_earth_plant_separation을 unwinnable StageData(id=921) → layout-only fixture로 격하, dev id 점유 920만. (2) D4 wording 재작성 — typical cell-disjoint + same-cell overlap 명시 허용 + 자료구조 독립 + E6 essential 승격. (3) essential 5→8종 확장 — E6 승격 + E7 SkillRegistry + E8 StageLayoutBuilder backward compat 신설.
- **v3 (R2-H1/H2/H3/M1 fix)**: (4) §6.4 dev_cutter_over_hazard fixture를 body-row primary scenario로 통일 (plant + hazard 모두 (10, 21) ant body row 배치, alternate floor-row 시나리오 제거 — cutter target row 일치). (5) §9 closing wording stale "essential 5종" → "essential 9종 전체 명시 enumeration" (9개 PowerShell 명령 박제). (6) **E9 SkillToolbarCutterIntegrationTest 신설** — E7는 SkillRegistry-part 유지, E9가 SkillToolbar-part 분담 (ICONS/KO_LABELS dict integrity + SkillSlot 인스턴스 검증). essential 8→9종 확장. (7) E8 single-sample → **parameterized 전수 검증** — phase 1~18 모든 layout build 후 모든 cell kind="earth" + plant kind 0건 assert. **v3.1 (R3-H1/R3-M1 manual fix)**: E6의 ant spawn은 테스트 fixture 전용으로 (9,21) 고정하여 첫 target을 (10,21) plant/hazard same-cell로 보장한다. 이 좌표 고정은 E6 결정론만 위한 것이며, 실제 Cutter/plant 로직은 `cell_to_world`/ant direction/forward cell 계산에 의해 모든 StageLayoutData 좌표에서 동작한다. E8은 `data/stage_layouts/*.tres` 런타임 스캔만 SoT로 사용하고 phase 19 plant fixture 4종만 제외한다. dev 검증 stage **4 layout fixture** (`dev_cutter_vine_layout`=920 StageData / `dev_cutter_edge_stop_layout` / `dev_earth_plant_separation_layout` / `dev_cutter_over_hazard_layout` 3종 layout-only) + 헤드리스 회귀 essential **9종** + deferred 2종 박제. Phase 17~18 회귀 0 (`scripts/run_test.py`로 phase 14~18 essential 헤드리스 PASS 확인). **자연 분기 활용**: plant cell의 `_static_occupancy` 점유는 phase 18 `register_static_body` 내부 호출로 자동 등록 → `Terrain.add_tile`의 D8 first-place wins로 **Bridge/Sand-mound가 plant cell 위에 발판 생성 시 reject** (코드 변경 0, D5 정책 자연 충족). Hazard와 plant는 phase 17 D15·phase 19 fixture 컨벤션상 **둘 다 ant body row(y=21) 배치**이지만 typical layout은 별개 x좌표로 cell-disjoint(같은 row + 다른 x → 다른 cell). **same-cell overlap도 허용 — 자료구조 독립 + E6 essential 가드** (v2 D4 재작성, v3.1.1 row wording 정정). **§0.2 어휘 정합**: 신규 식별자·문자열·문서는 "절단"/"제거"만 사용. 신규 코드(CutterSkill/WorkerState cutter 분기/플랜트 placement)에서 `die()`/`Dead`/"사망"/"죽"/"폭탄"/"폭발" 0건 — Cutter는 ant 손실 직접 트리거 안 함.

---

## 1. Open decisions before implementation — 결정 (frontmatter doc 6건 + 본 plan 도출 4건)

> **Recommended** 표기는 사용자가 추천안을 채택하면 본 plan 명세 그대로 진행. redirect 시 v2에서 갱신.

### 1.1 PROPOSAL §3.4.2 derived 결정 (frontmatter doc 6건)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D1 | Cutter 작동 범위 (§3.4.2 TBD: "인접 셀 1칸 / 라인?") | **인접 1칸 (수평 forward) — Basher 패턴 답습** | 추천안. (a) Basher는 ant 진행 방향(body row) 1 cell씩 tick 단위 굴착(`a.global_position.x += dir*cs`로 전진). Cutter도 동일 패턴 = plant vine/잎 barrier를 수평 절단으로 통과. (b) "라인" 모드는 1 tick에 여러 cell destroy → atomic 위반 위험 + chain reaction 의도치 않은 다른 plant 파괴 (phase 18 D2 chain-no 정책과 충돌). (c) Digger 패턴(수직 1 cell)으로 가면 plant=수직 barrier 무드보드인데 Digger와 메카닉 중복 — Basher 자매 메카닉이 가장 자연. (d) plant cell이 vine·잎 무드보드라 수평 barrier가 puzzle 디자인에 더 자연(횡스크롤 통로 막기). |
| D2 | 식물 vs 흙 구분 기준 (§3.4.2 TBD) | **`Terrain._cell_kind: Dictionary<Vector2i, String>` "plant"/"earth" 분류 — phase 18 D5에서 이미 결정된 체계 활용** | 추천안. phase 18은 destruction 도입 시 `_cell_kind`를 신설하며 "plant"(phase 19) kind 슬롯을 명시적으로 예약(`scripts/world/Terrain.gd:18` 주석). 본 phase는 그 슬롯에 값을 채우는 것뿐 — 자료구조/API 변경 0. TileMap layer 분리는 phase 16 이후 layout이 TileMap 노드 없이 Dictionary `tile_map` 기반이라 마이그레이션 비용. terrain set은 Godot TileMap autotile 의존 → phase 16 자연 진화 노선과 불일치. `_cell_kind`는 동적(`add_tile`) + 정적(`register_static_body`) 양쪽 통합 SoT로 단순. |
| D3 | 절단 후 잔여물 (§3.4.2 TBD) | **즉시 제거 — phase 18 destroy_tile_at 패턴 답습 (파편/아이템/visual lingering 0)** | 추천안. (a) phase 18은 Basher/Digger 모두 `destroy_tile_at` → body queue_free + 4 registry erase의 atomic 패턴으로 통일 — Cutter도 동일 패턴 사용해야 1) atomic invariant 일관 2) test driver 검증 코드 동일 패턴 재사용 3) 시각 lingering(파편 sprite, fade-out 등)은 phase 20 polish로 deferred (PROPOSAL §3.4.2 본 phase 시각 미명시). (b) 아이템 drop은 inventory 시스템 신규 도입 → MVP 단순성 위반(ADR-008). (c) "잔여 visual = 식물 줄기 짧게 남기기" 같은 표현주의 처리는 메카닉 검증 불필요 — 게임플레이 동일 결과(통행 가능). |
| D4 | 식물 지형 vs hazard 우선순위 (§3.4.2 TBD, **v2 재작성 · v3.1.1 row wording 정정 R4-M1**) | **Typical layout은 hazard와 plant가 별개 x좌표에 배치되어 cell-disjoint (둘 다 ant body row 컨벤션이지만 x가 다르면 cell도 다름). Same-cell overlap은 layout 작성자가 동일 (x,y)에 hazard를 의도적으로 배치할 때만 발생 — puzzle 디자인 도구로 허용 (build-time reject X). 두 시스템 자료구조 독립 + 의도된 행위는 `CutterOverHazardCellTest` essential로 검증.** | (a) Phase 17 D15: hazard 노드 `global_position = layout.cell_to_world(Vector2i(x, floor_y - 1))` — ant body row 배치 컨벤션. (b) Phase 18~19 earth cell은 layout 자유 배치(floor row solid / wall body row / slope 등 puzzle 디자인 선택). **Cutter 대상 plant cell은 phase 19 모든 fixture에서 ant body row(y=21) 배치** — Cutter의 `forward = body_cell + Vector2i(dir, 0)` 가드와 자연 정합. ant가 옆 cell에 서서 정면 절단. (c) hazard와 plant가 같은 body row 컨벤션이지만 typical layout은 x좌표를 달리 배치해 cell-disjoint(같은 row + 다른 x → 다른 cell). **(d) layout 작성자가 의도적으로 hazard 노드를 plant cell과 동일한 (x,y)에 instance하는 경우는 build-time 가드 0 — 허용된 puzzle 디자인**(예: "식물 위 끈끈이 spore"로 절단 후에도 진입 시 stuck). 자료구조 독립: `_cell_kind[cell] = "plant"` 와 `_hazards_by_cell[cell] = [hazard_node]`는 별개 Dictionary, cross-check 0. (e) PROPOSAL §3.4.2 TBD "우선순위" 질문 답: **별개 채널 + 독립 발화**. Cutter는 plant cell만 destroy → kind erase 후 그 자리는 공기 cell, 그러나 같은 cell의 hazard 노드 `monitoring=true` 유지 → ant 통과 시 body_entered 자연 발화. (f) 의도된 same-cell 행위(plant 제거 후 hazard 잔존 발화)는 `CutterOverHazardCellTest` essential로 검증(§2.5 E6 — v2에서 deferred 승격). |
| D5 | 식물 지형 위 생성 메카닉 허용 (§3.4.2 TBD + §3.2.3) | **차단 (자연 차단) — Bridge/Sand-mound `add_tile` 시 `_static_occupancy` 점유로 D8 first-place wins reject. 코드 변경 0** | 추천안. (a) plant cell은 `register_static_body(cell, body, "plant")` 호출 시 phase 18 정의대로 내부에서 `register_static_cell(cell)` → `_static_occupancy[cell] = true` 등록. (b) `Terrain.add_tile(cell)`의 1차 가드 `if _placed.has(cell) or _static_occupancy.has(cell): return false`로 자연 reject. (c) "plant 위 발판 허용" 옵션을 별도 도입 시 D8 first-place wins invariant(phase 16 정착)와 충돌 — phase 16~18 dev stage 11종 회귀 위험. (d) puzzle 디자인 의도: plant barrier는 **절단해서 통로 만들기** 또는 **위·아래로 우회**가 자연 — 그 위에 발판을 만드는 건 puzzle 의도와 어긋남. (e) 명시 코드 가드 0 (Terrain 변경 0) — phase 18 자료구조 invariant가 그대로 plant cell에 적용되어 자동 만족. |
| D6 | Cutter가 끈끈이 해방 메커니즘? (§3.4.2 ↔ phase 17 §3.3.2 TBD) | **아니오 — 끈끈이 해방은 phase 17 D4 시간 경과 자동 3.0s 결정. Cutter는 plant cell 전용** | 추천안. (a) phase 17 D4가 이미 "끈끈이 해방 = `_sticky_remaining` 시간 경과 자동, 3.0s default"로 결정·구현됨. Cutter를 추가 해방 경로로 도입 시 phase 17 결정 번복 + dual-path 비결정 위험. (b) Cutter의 destroy 대상은 `_cell_kind == "plant"` 한정. Sticky hazard cell은 `_cell_kind == ""` (hazard registry 별도) → `destroy_tile_at(sticky_cell, ["plant"])` false → Cutter 무영향. (c) "Cutter로 끈끈이 해방" 메카닉은 puzzle 디자인 옵션이지만 phase 17 ↔ 19 cross-phase 의존을 만들고 phase 19 신규 메카닉 + 회귀 검증을 동시 진행 → MVP 단순성 위반. v1.1 또는 polish phase에서 재검토 가능. |

### 1.2 본 plan 도출 결정 (구현 디테일 4건)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D7 | Cutter can_apply 가드 | **WalkerState + on_floor + !has_candy** (Basher/Digger 패턴 답습) | 추천안. (a) Basher/Digger 모두 `s is WalkerState AND ant.is_on_floor() AND not ant.has_candy` 가드(`scripts/skills/BasherSkill.gd:5-18`). (b) Cutter도 동일 — carry 중 plant 절단 허용은 puzzle 의도 흐림 (in_transit ant가 다른 ant 통과시키려 절단? 단순 puzzle 메카닉에 비균질). (c) `is_alive` 가드는 Skill 베이스 + ant 상태머신 진입점 양쪽에 이미 존재 — 중복 가드 아님(Saved/Dead/Settled/Lost terminal state 모두 차단). carry 허용은 v1.1에서 재검토 가능. |
| D8 | Cutter 상한 / tick interval | **`CUTTER_MAX_CELLS = 12, CUTTER_TICK = 0.18s`** (Basher와 동일 수치) | 추천안. (a) Basher = 12 cell × 0.18s = 2.16초로 phase 18에서 puzzle pacing 적정 검증됨. (b) Cutter는 plant barrier 절단 — 흙 굴착과 행위 시간이 거의 동일하게 느껴지는 게 puzzle UX(둘 다 "벽 통과" 메카닉). (c) Digger의 0.20s tick은 자유 낙하 cycle 고려이므로 Basher 0.18s가 수평 cut 메카닉에 더 자연. (d) 별도 상한(예: 6) 도입 시 plant barrier 길이가 짧아지는 puzzle 제약 — phase 21+ stage design에서 layout으로 조정 가능, MVP는 대칭 단순성 우선. |
| D9 | StageLayoutBuilder plant cell 시각 + 등록 패턴 | **`tile_type == "plant"` 분기 신설: body 생성 + `register_static_body(cell, body, "plant")` + placeholder ColorRect 시각 (연두색 알파 0.85, size=cell_size×cell_size)** | 추천안. (a) `_layout_tile_map()` 값은 임의 string — phase 18까지는 `TILE_SOLID/TILE_SLOPE_RIGHT/TILE_SLOPE_LEFT` 3종이었으나 확장 자유로움. (b) `_add_cell`에 분기 1건 추가: `if tile_type == TILE_PLANT_SOLID: _add_plant_collision + _add_plant_visual; kind="plant"` else 기존 분기 + `kind="earth"`. (c) build()에서 generated[g] dict에 kind 필드 추가 후 register_static_body(g.cell, g.body, g.kind) — phase 18은 hard-code "earth"였음. (d) plant slope variants는 본 phase 미도입 — vine/잎이 평면 barrier 무드보드로 충분. (e) placeholder 시각은 정식 텍스처(phase 20 polish) 도입 시 swap, MVP는 색 구분만으로 메카닉 검증 가능. |
| D10 | Cutter 아이콘 / SkillToolbar 통합 | **`assets/icons/skills/cutter.svg` placeholder 신설 + `SkillToolbar.ICONS["cutter"]` + `KO_LABELS["cutter"]="절단"` 각 1줄 추가. 기존 bomber/miner 잔존 entry는 본 phase 미정리(phase 20 polish)** | 추천안. (a) phase 18은 basher/digger 아이콘이 사전 wired(SkillToolbar dict). Cutter는 PROPOSAL §1 "Bomber 자리 대체"이지만 §0.2 어휘 정책(폭탄/폭발 금지) 위반 우려로 `bomber.svg` 재활용 미선택 — 신규 `cutter.svg` placeholder(녹색 가위 또는 잎 모티프) 생성. (b) bomber.svg/miner.svg 자체 파일 삭제 + dict entry 삭제는 phase 20 polish 범위(`scripts/ui/SkillToolbar.gd:22-23, 27-28, 32`에 dead entry 잔존). 본 phase는 cutter 추가만, 기존 dead entry 잔존 허용 — 회귀 0(stage data가 bomber/miner 참조 안 함). (c) Cutter 활성/disabled 라우팅은 SkillSlot atom + `_inventory[id]` 기존 로직이 자동 처리. SkillToolbar 코드 변경은 2 dict에 entry 1줄씩 총 2줄. |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)
| 파일 | 용도 |
|---|---|
| `scripts/skills/CutterSkill.gd` | `class_name CutterSkill extends Skill`. `const ID: String = "cutter"`. `can_apply(ant)`: ant null·is_alive·WalkerState·is_on_floor·!has_candy 검사 (Basher 패턴). `apply(ant)`: `ant.state_machine.change_state(WorkerState.new("cutter"))` |
| `tests/test_CutterSkill.gd` | TDD guard 우회 stub — `extends Node` + 한 줄 코멘트. 실제 coverage는 integration 헤드리스 (phase 18 `tests/test_BasherSkill.gd` 패턴 답습) |

### 2.2 수정 (.gd)
| 파일 | 변경 |
|---|---|
| `scripts/core/SkillRegistry.gd` | `SKILL_SCRIPTS` 배열에 `preload("res://scripts/skills/CutterSkill.gd"),` 1줄 추가 (ADR-003 명시적 preload 정책). 기존 9 항목 뒤 append, 순서 무관 |
| `scripts/ant/states/WorkerState.gd` | **(1)** 신규 const `const CUTTER_TICK: float = 0.18`, `const CUTTER_MAX_CELLS: int = 12`. **(2)** `enter()` 분기에 `elif _work_type == "cutter": _enter_cutter(a)` 1줄 추가 (기존 builder/blocker/sand_mound/bridge/basher/digger/else 뒤). **(3)** `update(delta)` 분기에 `elif _work_type == "cutter": _update_cutter(a, delta); return` 1줄 추가. **(4)** 신규 `_enter_cutter(a)`: `_remaining = CUTTER_MAX_CELLS; _tick_accum = 0.0; _aborted = false; a.velocity = Vector2.ZERO` (Basher 패턴). **(5)** 신규 `_update_cutter(a, delta)`: gravity + slide + on_floor 검사(off-floor 시 _aborted + FallerState) + tick 누적 + `_cutter_forward_has_plant(a)` 가드(false면 _aborted) + `_destroy_cutter_cell(a)`. _remaining<=0 or _aborted면 WalkerState 복귀. **Basher와 구조 동일, kind 검사만 "plant"로 교체**. **(6)** 신규 `_destroy_cutter_cell(a)`: body_cell 계산(Basher와 동일) + target = body_cell + (direction, 0) + `terrain.destroy_tile_at(target, ["plant"])` + 성공 시 `a.global_position += Vector2(float(a.direction) * cs, 0.0)`, _remaining-=1. 실패 시 _aborted. **(7)** 신규 `_cutter_forward_has_plant(a) -> bool`: `terrain.get_cell_kind(body_cell + (dir, 0)) == "plant"`. **(8)** `exit()` 본문 **무변경** — cutter도 Walker 복귀 시 자연 해제 (Basher/Digger 패턴 동일) |
| `scripts/world/StageLayoutBuilder.gd` | **(1)** 신규 const `const TILE_PLANT_SOLID := "plant"` (기존 `TILE_SOLID/TILE_SLOPE_RIGHT/TILE_SLOPE_LEFT` 옆 1줄). **(2)** `_add_cell(cell, tile_type) -> StaticBody2D` 본문에 분기 추가: `if tile_type == TILE_PLANT_SOLID: _add_solid_collision(body, cell_size); _add_plant_visual(body, cell_size)` else (기존 solid/slope 분기 유지). **(3)** 신규 `_add_plant_visual(body: StaticBody2D, cell_size: int) -> void`: `var rect: ColorRect = ColorRect.new(); rect.size = Vector2(cell_size, cell_size); rect.position = Vector2(-cell_size/2.0, -cell_size/2.0); rect.color = Color(0.45, 0.78, 0.32, 0.85); body.add_child(rect); rect.owner = owner` (연두색 placeholder). **(4)** `build()` 본문의 `generated` Array dict에 `kind` 필드 추가: `var kind: String = "plant" if str(_layout_tile_map()[key]) == TILE_PLANT_SOLID else "earth"; generated.append({"cell": c, "body": body, "kind": kind})`. **(5)** `register_static_body` 호출 인자 수정: `terrain.register_static_body(g["cell"], g["body"], g["kind"])` (기존 hard-coded "earth" → kind 동적 전달). **(6)** `_rebuild_preview()` 본문은 `_add_cell` 반환값 무시 그대로 — body 생성 + 자식 추가는 미리보기에서도 동작. plant cell도 editor preview에 placeholder 시각 렌더. **(7)** `_get_tile_texture_for_cell` / `_add_solid_visual` / `_add_slope_visual` / `_slope_points` **무변경** — plant 전용 helper `_add_plant_visual`만 신규 |
| `scripts/ui/SkillToolbar.gd` | **(1)** `ICONS` Dictionary에 `"cutter": preload("res://assets/icons/skills/cutter.svg"),` 1줄 추가 (기존 9 entry 뒤). **(2)** `KO_LABELS` Dictionary에 `"cutter": "절단",` 1줄 추가. 기존 bomber/miner dead entry는 **무수정** (phase 20 polish 정리 예정) |

### 2.3 신규 (.tres / 검증 stage)
| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_cutter_vine_layout.tres` | StageLayoutData. cell_size=32. home 좌측(body row y=21) + candy 우측 + 그 사이 4 cell 두께 plant vine(tile_map value="plant", x=12~15 y=21). 그 아래 floor(y=22)는 solid earth. ant가 cutter로 plant vine 통과 → candy → home |
| `data/stages/dev/cutter_vine_test.tres` | StageData. **id=920** (dev 예약 — phase 17~18 점유 910~919 회피). display_name="dev-cutter-vine". available_skills=`["cutter"]`. skill_inventory=`{"cutter": 2}`. total_ants=4, candy_hp=4, time_limit=60, release_rate_initial=30 |
| `scenes/stages/dev/CutterVineTest.tscn` | Stage scene. BasherWallTest 패턴 + dev_cutter_vine_layout wiring |
| `data/stage_layouts/dev_cutter_edge_stop_layout.tres` | StageLayoutData. cell_size=32. **CutterEdgeStopTest 전용 layout-only fixture** (별도 StageData id 없음). body row x=12~13에 2 cell plant, x=14 이후 open space. ant가 cutter 적용 → 2 cell 제거 후 forward에 plant 없음 → _cutter_forward_has_plant false → _aborted → Walker 복귀 |
| `data/stage_layouts/dev_cutter_over_hazard_layout.tres` (v2 — R1-H2 fix, v3.1 — R3-H1 fix) | StageLayoutData. cell_size=32. **CutterOverHazardCellTest 전용 layout-only fixture** (별도 StageData id 없음). plant cell 1개 (x=10 y=21) + 같은 좌표(x=10 y=21)에 Sticky hazard 노드 인스턴스(§6.4 도식대로 body row 점유). hazard 노드는 phase 17 Sticky.tscn 직접 인스턴스 + scene-side 좌표 직접 입력 (StageLayoutData hazard_cells 필드 미도입, phase 17 D11 답습). ant spawn (9,21)은 test driver 전용이고 layout resource에는 포함하지 않음 |
| `data/stage_layouts/dev_earth_plant_separation_layout.tres` | StageLayoutData. cell_size=32. **메카닉 분리 검증 전용 layout-only fixture** (v2 — StageData 미점유). 좌측: earth wall (x=8~10 y=21). 우측: plant wall (x=14~16 y=21). 별도 home/candy 좌표는 §6.3 도식 참조하지만 essential test는 전체 stage 완주를 검증하지 않고, manual Stage 인스턴스화 + 직접 ant 1명에 skill 적용 후 forward cell kind invariant만 검증 (R1-H1 fix) |

> **dev id 정책 (v2)**: id ≥ 900 dev 예약 답습. phase 19 신규 StageData 점유 **920 (1건)** — `dev_cutter_vine_test.tres`만. `dev_cutter_edge_stop_layout`과 `dev_earth_plant_separation_layout`은 layout-only test fixture라 StageData id 미점유(v2 — R1-H1 fix로 dev_earth_plant_separation StageData id=921 회수). 점유 확인: 901~909 phase 14~16, 910~913 phase 17 essential, 914/916 phase 17 sweep 예약, 915 phase 17 R1-H1, 917~919 phase 18.

### 2.4 신규 (assets/)
| 파일 | 용도 |
|---|---|
| `assets/icons/skills/cutter.svg` | Cutter 아이콘 placeholder. 24x24 SVG. 단색 녹색(또는 가위·잎 모티프 단순 도형). 기존 `basher.svg`/`digger.svg` 시각 구조 답습(circle/rect 단순 조합). 정식 디자인은 phase 20 polish 또는 별도 디자인 트랙(codex-worklog 디자인 핸드오프) |
| `assets/icons/skills/cutter.svg.import` | Godot import .uid 자동 생성. svg 추가 시 editor open 1회면 자동 생성됨 — 본 phase staging은 svg만, .import은 editor 자동 생성을 기다림 |

### 2.5 신규 (tests/) — essential 9종 (v3 — R2-H3 fix로 8→9 확장, 누적 5→8→9)
| # | 파일 | 검증 |
|---|---|---|
| E1 | `tests/CutterCutThroughVineTest.tscn/gd` | 헤드리스. dev_cutter_vine_layout. ant 1명에 cutter 적용 → 4 cell plant vine 통과 → candy 도달 → home 회수. **PASS**: 30초 내 (1) `saved_pieces >= 1`, (2) 통과한 plant cell들의 `terrain.get_cell_kind(cell) == ""` (제거 확인), (3) `terrain.has_tile(cell) == false` AND static body 노드 free 확인 (test driver가 노드 검색). Basher의 `BasherTunnelThroughWallTest`와 구조 동일, kind만 plant. **Runner protocol** (phase 18 `tests/BlockerOverlapTest.gd` 패턴): PASS 시 `print("CutterCutThroughVineTest PASS"); get_tree().quit(0)`, FAIL 시 `push_error("...FAIL: " + reason); get_tree().quit(1)` |
| E2 | `tests/CutterEdgeStopTest.tscn/gd` | 헤드리스. **dev_cutter_edge_stop_layout 전용**. 사전 `destroy_tile_at` mutation 없음. ant가 cutter 적용 → 2 cell plant 제거 후 forward에 plant 없음 → `_cutter_forward_has_plant` false → _aborted → Walker 복귀. **PASS**: 30초 내 (1) cutter 후 ant state가 WalkerState, (2) 2 cell 제거 후 추가 plant cell 파괴 X (인접 cell 무영향), (3) §6.2의 사전 sample 5 cell(plant 외 earth/공기)의 kind 무변동 (test driver가 사전 kind 캐싱 후 사후 비교). Basher의 `BasherEdgeStopTest`와 구조 동일 |
| E3 | `tests/CutterOnEarthRejectedTest.tscn/gd` (v2 — layout-only manual 인스턴스화) | 헤드리스. **메카닉 분리 검증** — dev_earth_plant_separation_layout 사용 + manual Stage 인스턴스화. test driver가 Stage scene 없이 Terrain + StageLayoutBuilder + Ant 1명을 직접 인스턴스화하여 earth wall 좌측에 배치 → ant에 cutter 적용 → forward가 earth wall이면 destroy 0 + Walker 복귀. **PASS**: 30초 내 (1) cutter 적용 직후 첫 2 tick(~0.36s) 후 `terrain.has_tile(earth_target)` true 유지 + `get_cell_kind(earth_target) == "earth"` 유지, (2) ant state가 WalkerState 복귀(`_aborted` 경로), (3) earth wall cell 카운트(`tile_count` 또는 `_static_occupancy` size) 무변동 (사전 vs 사후 비교). 전체 stage 완주는 검증 안 함(R1-H1 — layout-only) |
| E4 | `tests/BasherOnPlantRejectedTest.tscn/gd` (v2 — layout-only manual 인스턴스화) | 헤드리스. **메카닉 분리 검증 역방향** — dev_earth_plant_separation_layout 사용 + manual Stage. test driver가 ant 1명을 plant wall 좌측에 배치 → basher 적용 → forward가 plant wall이면 destroy 0 + Walker 복귀. **PASS**: 30초 내 (1) basher 적용 직후 첫 2 tick 후 plant wall cell의 `get_cell_kind == "plant"` 유지, (2) ant state가 WalkerState 복귀, (3) plant cell 카운트 무변동. **본 essential 8의 핵심** — phase 18 destruction이 plant cell 침범하지 않는 회귀 가드. 전체 stage 완주는 검증 안 함 |
| E5 | `tests/TerrainPlantKindRoundTripTest.tscn/gd` | 헤드리스 unit-style. Stage 없이 Terrain 노드만 인스턴스화 + `register_static_body(cell, body, "plant")` 호출 + invariant 검증. **PASS**: (1) register 후 `get_cell_kind(cell) == "plant"` AND `_static_occupancy.has(cell) == true`, (2) `destroy_tile_at(cell, ["plant"])` true 후 `get_cell_kind(cell) == ""` + `has_tile(cell) == false` + `_static_occupancy.has(cell) == false` + body queue_free, (3) `destroy_tile_at(cell, ["earth"])` false (kind 불일치) — register 후 다시 호출하면 변경 0, (4) `add_tile(cell)` 호출 시 plant cell은 `_static_occupancy` 점유로 reject (D5 자연 차단 — first-place wins) |
| E6 | `tests/CutterOverHazardCellTest.tscn/gd` **(v2 — deferred → essential 승격, R1-H2 fix; v3.1 — R3-H1 fix)** | 헤드리스. **layout-only fixture `dev_cutter_over_hazard_layout.tres` 신설** (§6.4 신규 도식 — body row 같은 좌표에 hazard(Sticky 또는 Water) 인스턴스 + plant cell 등록). test driver가 manual Stage 인스턴스화 + ant 1명을 (9,21)에 direction=+1로 배치 → 첫 cutter target (10,21) plant 제거 성공 → ant가 그 자리 통과 시 hazard.body_entered 발화. **좌표 고정은 E6 deterministic fixture 전용**이며, Cutter 런타임 로직은 어떤 stage 좌표든 ant direction 기준 forward cell을 계산한다. **PASS**: 30초 내 (1) cutter destroy 성공 후 plant cell `get_cell_kind == ""`, (2) **hazard 노드 `monitoring == true` 유지** (kind 제거가 hazard registry에 영향 0 — D4 invariant 핵심), (3) ant 통과 시 hazard 발화 자연 발생(Sticky면 `is_stuck() == true` 또는 Water면 `LostState` 진입). **본 test는 D4 same-cell overlap 정책의 essential 가드** |
| E7 | `tests/SkillRegistryCutterValidateTest.tscn/gd` **(v2 — 신설, R1-M1 fix)** | 헤드리스 unit-style. Stage 없이 SkillRegistry autoload + StageData(dev_cutter_vine_test 또는 임시 `available_skills=["cutter"], skill_inventory={"cutter":2}` StageData) 사용. **PASS**: (1) `SkillRegistry.get_skill("cutter")` non-null + `script.ID == "cutter"`, (2) `SkillRegistry.validate_stage(stage_data)` 반환 errors Array 빈 배열, (3) `SkillRegistry._skills.has("cutter") == true`. 별도 unknown id 케이스도 확인: `validate_stage(stage_with_unknown_id)`이 errors 1건 이상 반환. **§10 strict acceptance §6 SkillRegistry-part enforce 경로** (SkillToolbar-part는 E9가 분담) |
| E8 | `tests/StageLayoutBuilderEarthBackwardCompatTest.tscn/gd` **(v3 — parameterized 전수, R2-M1 fix; v3.1 — R3-M1 fix)** | 헤드리스. **phase 1~18 main + dev StageLayoutData 전수 검증** (single sample 아님). test driver는 `DirAccess`/`ResourceLoader`로 `data/stage_layouts/*.tres`를 런타임 스캔한다. **정적 파일명 배열 금지**. 제외는 phase 19 신규 plant fixture 4종만 허용: `dev_cutter_vine_layout.tres`, `dev_cutter_edge_stop_layout.tres`, `dev_earth_plant_separation_layout.tres`, `dev_cutter_over_hazard_layout.tres`. 스캔 결과 0건, load 실패, StageLayoutData type mismatch, build 실패는 즉시 FAIL. 각 layout마다 Terrain + StageLayoutBuilder manual 인스턴스화 + build() + 전수 cell 순회. **PASS**: (1) 모든 scanned layout build 성공(`_static_occupancy.size() > 0`), (2) 모든 scanned layout의 모든 cell `get_cell_kind(cell) == "earth"` (slope cell 포함, kind="" 0건), (3) **plant kind cell 0건 across all scanned layouts**, (4) 각 layout의 cell 카운트 = layout `tile_map` size. **§10 strict acceptance §7(backward compat) enforce — phase 1~18 dev/main stage가 plant kind로 회귀하는 모든 경로 차단** |
| E9 | `tests/SkillToolbarCutterIntegrationTest.tscn/gd` **(v3 — 신설, R2-H3 fix)** | 헤드리스. SkillToolbar.tscn 직접 인스턴스화. test driver가 임시 StageData(`available_skills=["cutter"], skill_inventory={"cutter":2}`) 생성 + SkillToolbar instance의 `stage_data` 주입 + `hbox_path` 유효 노드 wire + scene tree에 add_child → `_ready()` 자동 호출 → SkillSlot atom 생성. **PASS**: (1) hbox 자식 SkillSlot 인스턴스 1개 생성, (2) `slot.skill_id == StringName("cutter")`, (3) `slot.icon_texture == SkillToolbar.ICONS["cutter"]` AND non-null (preload된 cutter.svg), (4) `slot.ko_label == "절단"` (KO_LABELS dict 참조), (5) `slot.hotkey == "1"` (첫 슬롯 hotkey 컨벤션). **§10 strict acceptance §6 SkillToolbar-part enforce 경로** — SkillRegistry 등록 + Toolbar UI 통합 invariant 양쪽 모두 essential gate 보유 |

> **v3 essential count 정합**: §2.5 essential 9종 (E1~E9). v2의 8종에서 E9 SkillToolbarCutterIntegrationTest 신설(R2-H3 fix). §0/§0.0/§0.1/§7.1/§9/§10/§12 모든 essential count 참조 wording을 "essential 9종"으로 통일 — stale "5종"/"8종" 잔존 0건.

### 2.6 신규 (tests/) — deferred 2종 (v2 — 3→2건, essential 통과 후 작성, phase 19 acceptance 미포함)
| 파일 | 검증 |
|---|---|
| `tests/EarthPlantMixedDestroyOrderTest.tscn/gd` (deferred D5) | 같은 stage에 earth + plant cell 혼재 + Basher와 Cutter 동시 적용. 두 skill이 서로의 target에 무영향 + ant 위치 race 없음 검증 |
| `tests/CutterCarryRejectedTest.tscn/gd` (deferred D7) | carrying ant에 cutter 적용 시도 → can_apply false → 어떤 변화도 없음 검증 (Skill 가드 unit test 성격) |

> **v2 — CutterOverHazardCellTest 변경 위치**: §2.6 deferred에서 §2.5 essential E6로 승격(R1-H2 fix). 별도 layout fixture `dev_cutter_over_hazard_layout.tres` 신설(§6.4 도식). hazard 노드는 Water 또는 Sticky 선택 — Sticky가 검증 비파괴적이라 추천(LostState 진입 시 ant 인스턴스 free → test driver state polling 어려움. Sticky는 ant 통과 + `is_stuck()` 직접 polling 가능).

### 2.7 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 시그널 추가 0건. Cutter는 ant 손실 직접 트리거 안 함 (수평 절단 후 falling 무발생)
- `scripts/core/ScoreSystem.gd` — 4-카운터(ADR-002) 무영향
- `scripts/core/StageData.gd`, `StageLayoutData.gd`, `StageRunner.gd`, `SaveData.gd`, `MenuLayout.gd` — 무변경
- `scripts/ant/Ant.gd` — 무변경. is_alive·effective_speed·has_candy·set_blocker_active 모두 그대로 (Cutter는 worker mode이므로 Walker 진입점만 사용)
- `scripts/ant/states/{Walker,Carrying,Faller,Climber,Saved,Dead,Settled,Lost}State.gd` — 무변경. Walker.update의 fall 가드는 phase 18 D1 자연 분기와 동일 (Cutter는 ant 위치를 수평으로만 이동하므로 본 phase에서는 fall 발생 X — single plant wall 절단 후 옆 earth floor 위 안착)
- `scripts/skills/{Builder,Blocker,Climber,Floater,Distributor,SandMound,Bridge,Basher,Digger,Skill}.gd` — 무변경. 신규 CutterSkill만 추가
- `scripts/world/Terrain.gd` — **무변경**. phase 18에서 `register_static_body(kind)` / `get_cell_kind` / `destroy_tile_at(allowed_kinds)` / `_cell_kind` registry 모두 완비. phase 19는 인자 차이만(`"plant"` 전달)
- `scripts/world/hazards/{HazardBase,WaterHazard,StickyHazard}.gd` — 무변경. plant cell과 hazard cell은 row 컨벤션이 별개(D4) + `_cell_kind` vs `_hazards_by_cell` registry 분리
- `scripts/world/{Candy,Home,SettlementMarker,CookiePlatformVisual}.gd` — 무변경
- `scripts/ui/HUD.gd` — 무변경. Cutter는 lost/saved 카운터 무영향
- 기존 stages Stage01~03 / data/stages/stage0N.tres — plant 미사용, 회귀 무영향
- phase 14~18 dev stages — plant 미사용, 회귀 무영향 (basher/digger 검증 stage는 모두 earth cell, Cutter 무영향)
- 기존 헤드리스 테스트 — plant 미관련, 모두 PASS 유지

### 2.8 텍스처 정책
본 phase 신규 텍스처 1건(`cutter.svg` 24x24 placeholder). 절단 시 cell body는 queue_free로 즉시 제거 — 페이드/파티클 없음(D3, phase 20 polish로 deferred). Plant cell 시각은 `_add_plant_visual` placeholder ColorRect 연두색 — 정식 식물 텍스처는 phase 20 polish.

---

## 3. Terrain API 명세 (phase 18 기준, phase 19에서 무변경)

phase 18에서 정의된 API를 그대로 사용. 변경 0. 본 절은 검증 편의 + plant kind 추가 시 invariant 명시.

```gdscript
# Terrain.gd — phase 18 정의, phase 19 무변경
# _cell_kind: Vector2i → String. "earth"(default) / "plant"(phase 19 신규 사용) / "" (미등록).
# register_static_body(cell, body, kind) → _static_bodies[cell] = body; _cell_kind[cell] = kind; register_static_cell(cell).
# destroy_tile_at(cell, allowed_kinds) → kind 검사 후 dynamic _placed + static _static_bodies 둘 다 queue_free + 4 registry erase.
# atomic: kind 검사 실패 시 어떤 registry도 변경 0.
```

**phase 19 invariants** (phase 18 invariant의 plant kind 자연 확장):

1. `register_static_body(cell, body, "plant")` 호출 후 `get_cell_kind(cell) == "plant"` AND `_static_occupancy.has(cell)` AND `_static_bodies[cell] == body`.
2. `add_tile(cell)` 호출 시 plant cell이 이미 `_static_occupancy`에 등록되어 있으면 false 반환 (D5 자연 차단).
3. `destroy_tile_at(plant_cell, ["plant"])` true 반환 후 `get_cell_kind(plant_cell) == ""` AND `has_tile(plant_cell) == false` AND `_static_occupancy.has(plant_cell) == false` AND `_static_bodies.has(plant_cell) == false`. body queue_free (end-of-frame).
4. `destroy_tile_at(plant_cell, ["earth"])` false 반환 — kind 불일치 (모든 registry 무변경, atomic).
5. `destroy_tile_at(earth_cell, ["plant"])` false 반환 — 동일 atomic.

> **메카닉 분리 invariant** (phase 19 핵심): allowed_kinds 인자가 cross-kind 침범을 atomic하게 차단. Basher/Digger는 코드에서 `["earth"]` 고정 호출, Cutter는 `["plant"]` 고정 호출. 차단은 Terrain.destroy_tile_at 측 단일 진입점에서 강제되므로 skill 측 가드 추가 0.

---

## 4. WorkerState cutter 분기 명세

### 4.1 _enter_cutter

```gdscript
const CUTTER_TICK: float = 0.18
const CUTTER_MAX_CELLS: int = 12

func _enter_cutter(a: Ant) -> void:
    _remaining = CUTTER_MAX_CELLS
    _tick_accum = 0.0
    _aborted = false
    a.velocity = Vector2.ZERO
```

> Basher와 동일한 진입 패턴 — gravity는 update에서 처리, velocity 초기화는 입력 시 명확화 차원.

### 4.2 _update_cutter

```gdscript
func _update_cutter(a: Ant, delta: float) -> void:
    if _aborted or _remaining <= 0:
        a.state_machine.change_state(WalkerState.new())
        return
    # 중력 + 좌우 정지 (Basher 패턴).
    a.velocity.y += a.gravity * delta
    a.velocity.x = 0.0
    a.move_and_slide()
    # floor contact 잃으면 abort → Faller (절벽 끝에서 cutter 활성화한 경우 자연 해제).
    if not a.is_on_floor():
        _aborted = true
        a.state_machine.change_state(FallerState.new())
        return
    _tick_accum += delta
    while _tick_accum >= CUTTER_TICK and _remaining > 0 and not _aborted:
        _tick_accum -= CUTTER_TICK
        if not _cutter_forward_has_plant(a):
            _aborted = true
            break
        _destroy_cutter_cell(a)
    if _aborted or _remaining <= 0:
        a.state_machine.change_state(WalkerState.new())
```

> Basher의 `_update_basher`와 구조 동일. kind 검사만 `"plant"`로 교체. 5-cell drop 같은 vertical fall 경로는 phase 19에서 미발생 (수평 절단 + plant cell 위 ant body row 점유 컨벤션).

### 4.3 _destroy_cutter_cell + helpers

```gdscript
func _destroy_cutter_cell(a: Ant) -> void:
    var terrain: Terrain = _find_terrain(a)
    if terrain == null:
        _aborted = true
        return
    var cs: int = terrain.cell_size
    # Basher와 동일 — (y-2.0)/cs로 ant 본체 cell.
    var body_cell: Vector2i = Vector2i(
        int(floor(a.global_position.x / cs)),
        int(floor((a.global_position.y - 2.0) / cs))
    )
    var target: Vector2i = body_cell + Vector2i(a.direction, 0)
    var ok: bool = terrain.destroy_tile_at(target, ["plant"])
    if not ok:
        _aborted = true
        return
    # Basher 스타일 통일 — Vector2 더하기로 위치 갱신.
    a.global_position += Vector2(float(a.direction) * cs, 0.0)
    _remaining -= 1

func _cutter_forward_has_plant(a: Ant) -> bool:
    var terrain: Terrain = _find_terrain(a)
    if terrain == null:
        return false
    var cs: int = terrain.cell_size
    var body_cell: Vector2i = Vector2i(
        int(floor(a.global_position.x / cs)),
        int(floor((a.global_position.y - 2.0) / cs))
    )
    return terrain.get_cell_kind(body_cell + Vector2i(a.direction, 0)) == "plant"
```

> `_find_terrain`은 phase 18에서 정의됨 (WorkerState 내부 ancestor scan). 재사용. Cutter 전용 helper 0 — phase 18 패턴 그대로 답습.

### 4.4 enter() / update() 분기 추가

```gdscript
# enter() 분기 (기존 phase 18 분기 뒤에 cutter 1줄 추가):
elif _work_type == "cutter":
    _enter_cutter(a)

# update() 분기 (기존 phase 18 분기 뒤에 cutter 1줄 추가):
elif _work_type == "cutter":
    _update_cutter(a, delta)
    return
```

`exit()` **무변경** — cutter는 Walker 복귀 시 정리 불필요 (Basher/Digger 패턴 동일).

---

## 5. Plant × Hazard × Destruction 상호작용 — 불변식

phase 17 D8(Bridge × hazard deactivate) + phase 18 D9/D10(earth dynamic destructible / hazard cell 보존) + phase 19 D4/D5(plant cell 별개 row + 위 placement reject) 통합:

| 시나리오 | 결과 | 근거 |
|---|---|---|
| Cutter가 plant 정적 cell에 도달 | 파괴 성공 (kind="plant") | D2 + phase 18 destroy_tile_at allowed_kinds |
| Cutter가 earth 정적 cell에 도달 | _cutter_forward_has_plant false → _aborted | D2 메카닉 분리 invariant |
| Basher가 plant 정적 cell에 도달 | _basher_forward_has_earth false → _aborted | 동일 — phase 18 가드가 kind="earth" 고정 |
| Digger가 plant 정적 cell 위에 있을 때 | 자기 발 밑 cell이 plant면 _digger_below_has_earth false → _aborted (WalkerState 복귀). 또는 plant cell 위 ant가 falling 중이면 next floor 안착 후 다시 검사 | 동일 |
| Cutter가 hazard cell 진입 시도(hazard active) | hazard cell은 _cell_kind == "" (미등록, hazard는 air area) → _cutter_forward_has_plant false → _aborted | D4 + phase 18 D10 |
| Cutter가 hazard와 same-cell에 배치된 plant cell 절단 (v2 — D4 명시 허용) | plant cell의 _cell_kind == "plant" → 파괴 성공 + `_cell_kind` erase. **hazard 노드 `monitoring=true` 유지** (`_hazards_by_cell` registry는 별도 자료구조라 plant erase에 영향 0). ant 통과 시 hazard body_entered 자연 발화 (Sticky면 stuck timer 발동, Water면 LostState 전이) | v2 D4 명시 허용 정책 + 두 시스템 자료구조 독립 + E6 `CutterOverHazardCellTest` essential 가드 |
| Bridge/Sand-mound가 plant cell 위에 add_tile 시도 | _static_occupancy 점유 → false 반환 (D5 first-place wins) | D5 자연 차단 (코드 가드 0) |
| Cutter 절단 후 plant 자리에 다른 ant가 진입 | plant cell 제거 완료 → 공기 cell → 자유 통행 또는 Faller 전이 | phase 18 destroy_tile_at + Walker.update 자연 분기 |
| Plant cell 위에서 ant가 정착 시도 (SettlementMarker) | SettlementMarker가 그 cell에 배치되어 있으면 정착 가능. plant cell은 floor 역할 — 정착 가능. (단 puzzle 디자인상 plant 위 settlement는 보통 미배치) | 코드 가드 0 — D5는 add_tile만 차단, settlement는 _hazards_by_cell도 아니고 SettlementMarker는 Area2D 자체 노드 |

**Plant 절단 후 Bridge 재배치**: Cutter로 plant cell 절단 → `_cell_kind.erase(cell)` + `_static_occupancy.erase(cell)` → 그 자리에 Bridge가 새로 `add_tile(cell)` 호출하면 D8 first-place wins로 **재배치 가능** (occupancy 풀려 있음). add_tile 직후 `_cell_kind[cell] = "earth"`로 자동 설정 → 이후 Basher/Digger로 또 파괴 가능. puzzle 디자인 의도: plant 통과 → 발판 만들기 같은 chained mechanic 자연 허용.

---

## 6. 검증 stage 도식 (cell_size=32)

### 6.1 dev_cutter_vine (id=920)

```
y=21 (body row)  . . . . . . . P P P P . . . . . . .
y=22 (floor row) S S S S S S S S S S S S S S S S S S
                 ↑                         ↑
                 home (cell 5,21)          candy (cell 25,21)
                                vine = cell 12~15 (y=21만 plant — floor row y=22는 earth solid 유지)
```

- `P` = plant cell (tile_type="plant", kind="plant")
- `S` = earth solid cell (kind="earth")
- ant가 home→candy 진로 중 vine 만나면 cutter 적용 → 4 cell 통과(body row 절단) → candy 도달. vine의 floor row는 earth solid 유지(ant가 그 위로 걸음).

> 검증 포인트: cutter가 vine body row 4 cell만 제거(kind="" 확인) + floor row(y=22) earth 무변동(kind="earth" 유지).

### 6.2 dev_cutter_edge_stop (layout-only, StageData id 없음)

```
y=21 (body row)  . . . . . . . . . . . . P P . . . . . .
y=22 (floor row) S S S S S S S S S S S S S S S S S S S S
                                         ↑↑
                                         plant 2 cell (x=12~13)
```

- ant가 cutter 적용 → 2 cell 제거 → x=14 forward에 plant 없음(공기 cell, kind="") → `_cutter_forward_has_plant` false → _aborted → Walker 복귀.
- test driver는 plant 제거 외 cell(특히 floor row earth)이 무변동인지 사전·사후 비교.

> 검증 포인트: cutter 2 cell 제거 후 자연 종료(_aborted) + 인접 cell(plant 외 + earth + 공기) 무변동.

### 6.3 dev_earth_plant_separation (layout-only fixture, v2 — R1-H1 fix)

```
       x:  0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22
y=21      . . . . . . . . E E E  .  .  .  P  P  P  .  .  .  .  .  .   <- body row
y=22      S S S S S S S S S S S  S  S  S  S  S  S  S  S  S  S  S  S   <- floor row (earth)
```

- `E` = earth wall body cell (kind="earth", x=8~10, y=21) — phase 18 destruction 대상
- `P` = plant wall body cell (kind="plant", x=14~16, y=21) — phase 19 cutter 대상
- `S` = earth solid floor row (kind="earth", y=22)
- **본 layout은 essential test E3/E4 전용 fixture** — 전체 stage 완주 시나리오 없음. dev_earth_plant_separation StageData/scene 미생성(v2 — R1-H1 fix로 unwinnable StageData 제거).
- **Test driver manual 인스턴스화**:
  - E3 CutterOnEarthRejectedTest: 새 Scene tree에서 Terrain + StageLayoutBuilder(layout=dev_earth_plant_separation_layout) + Ant 1명을 cell (7,21) 위에 spawn(direction=+1). cutter 적용 → 첫 tick부터 ant forward(8,21)는 earth → _cutter_forward_has_plant false → _aborted. 30s 내 ant state == WalkerState + earth wall (8~10, 21) cell 카운트 무변동 확인.
  - E4 BasherOnPlantRejectedTest: 동일 패턴. ant 1명을 cell (13,21)에 spawn(direction=+1). basher 적용 → 첫 tick부터 ant forward(14,21)는 plant → _basher_forward_has_earth false → _aborted. 30s 내 ant state == WalkerState + plant wall (14~16, 21) cell 카운트 무변동 확인.

> **v2 정정 (R1-H1)**: v1은 본 layout을 StageData id=921로 정의하여 4명 ant 전원 완주 시나리오를 서술했으나 inventory `{basher:2,cutter:2}` × 통과 2 walls × 4 ants = inventory 부족(자동 player toggling 부재로 unwinnable). v2는 layout-only로 격하 + test driver manual 인스턴스화로 essential invariant만 검증(전체 completion gate 미요구).

### 6.4 dev_cutter_over_hazard (layout-only fixture, v3.1 — R2-H1 + R3-H1 fix: body-row primary)

```
       x:  0 1 2 3 4 5 6 7 8 9 10 11 12 13
y=21      . . . . . . . . . a P  .  .  .   <- body row + ant (9,21), plant cell (10,21), hazard 동일 좌표
y=22      S S S S S S S S S S S  S  S  S   <- floor row (earth)
```

- `S` = earth solid floor (kind="earth", y=22 전체)
- `P` = **plant cell (kind="plant") at (10, 21) — ant body row**
- `a` = **test driver ant spawn position at (9, 21), direction=+1**
- **Hazard 노드 같은 좌표(10, 21) 인스턴스**: Sticky.tscn 직접 add_child 후 `global_position = layout.cell_to_world(Vector2i(10, 21))`. phase 17 D15 컨벤션(hazard=body row) 자연 정합. **plant cell도 phase 19 모든 fixture에서 ant body row(y=21) 배치 컨벤션 — Cutter forward 가드와 자연 정합**(§6.1/§6.2/§6.3/§6.4 일관, v3.1.1 R4-M1 row wording 통일). 본 fixture는 동일 body row 위에 hazard를 same-cell(같은 x=10, 같은 y=21)로 의도 배치 — same-cell overlap을 cutter target row와 일치시키기 위한 **required primary scenario** (v3 — R2-H1 fix). D4 same-cell overlap essential 검증을 위한 의도적 배치.
- **좌표 고정의 범위(v3.1 — R3-H1 fix)**: `(9,21)` spawn과 `(10,21)` target은 E6 테스트를 첫 tick부터 hazard-overlap invariant에 도달시키기 위한 fixture-local 결정이다. 런타임 Cutter/plant 시스템은 좌표를 하드코딩하지 않고 ant의 현재 cell, direction, `cell_to_world`/`world_to_cell`, `Terrain.get_cell_kind()` 조합으로 작동한다. 따라서 다른 stage의 plant/hazard 좌표 범용성에는 영향 없다.
- **Test driver manual 인스턴스화 (E6, required scenario)**:
  - test driver가 Stage scene 없이 Terrain + StageLayoutBuilder(layout=dev_cutter_over_hazard_layout) manual 인스턴스화. floor row y=22는 layout `tile_map` "earth" entry로 build. plant cell (10, 21)은 layout `tile_map` "plant" entry로 build → `register_static_body((10,21), body, "plant")` 호출됨.
  - Sticky.tscn add_child 후 `global_position = layout.cell_to_world(Vector2i(10, 21))` → `_ready()` await physics_frame 후 `register_hazard_at_cell((10,21), hazard)` 자체 호출(phase 17 패턴).
  - ant 1명을 **(9, 21)에 spawn(direction=+1, WalkerState)**. cutter 적용 → tick 1(~0.18s)에 forward target은 **(10, 21)** → `get_cell_kind((10,21)) == "plant"` → plant destroy 성공 → kind erase.
  - 절단 후 ant가 (10, 21) 위치로 한 cell 전진 → 같은 frame 또는 다음 frame에 Sticky.body_entered 발화 → `ant.apply_sticky(3.0)` → `is_stuck() == true`.
- **PASS criteria (E6, deterministic gates)**:
  - (1) cutter destroy 성공 후 `terrain.get_cell_kind((10, 21)) == ""` AND `has_tile((10, 21)) == false`,
  - (2) **hazard 노드 `monitoring == true` 유지** (kind erase가 `_hazards_by_cell` 무영향 — D4 invariant 핵심),
  - (3) ant 통과 시 `is_stuck() == true` (Sticky 자연 발화) OR (Sticky timer expire 후 검증 — `_sticky_remaining > 0` 캡처).

> 검증 포인트: D4 same-cell overlap 정책의 essential 가드. cutter destroy 후에도 hazard 노드 monitoring 유지 + ant 통과 시 hazard 자연 발화 (자료구조 독립 invariant). **v3 — alternate floor-row 시나리오 제거, body-row primary 통일. v3.1 — ant spawn (9,21) 단일화로 첫 target (10,21) deterministic 보장**.

---

## 7. 헤드리스 테스트 essential 9종 + deferred 2종 (v3)

### 7.1 essential 9종 (phase 19 acceptance 필수, v3 — 8→9 확장 with E9)

§2.5 참조. 9종 모두 30~60초 hard timeout + runner protocol(`get_tree().quit(0/1)`) + 5조건 gate 변형. phase 18 `tests/Basher*Test.gd` / `tests/Digger*Test.gd` / `tests/TerrainDestroyTileApiTest.gd` 패턴 답습.

**Phase 19 essential PASS 기준 종합**:

| # | test | PASS 핵심 | enforce |
|---|---|---|---|
| E1 | CutterCutThroughVineTest | saved >= 1 + plant cell 4건 kind="" | §10 §4 (cutter velocity drift X) + §10 §1 (no silent cell-kind divergence) |
| E2 | CutterEdgeStopTest | 2 cell 제거 + _aborted + 인접 cell 무변동 | §10 §4 (no cutter velocity drift) |
| E3 | CutterOnEarthRejectedTest (v2 — layout-only manual) | earth cell 카운트 무변동 + Cutter ant Walker 복귀 | §10 §2 (no cross-kind destruction, Cutter→earth) |
| E4 | BasherOnPlantRejectedTest (v2 — layout-only manual) | plant cell 카운트 무변동 + Basher ant Walker 복귀 | §10 §2 (no cross-kind destruction, Basher→plant) |
| E5 | TerrainPlantKindRoundTripTest | register/destroy/add_tile invariant 5건 | §10 §1 + §3 (no silent placement on plant) |
| E6 | CutterOverHazardCellTest (v2 — deferred 승격 R1-H2, v3 — body-row primary R2-H1) | plant 절단 후 hazard monitoring=true 유지 + ant 통과 시 hazard 자연 발화 | D4 same-cell overlap 정책 + 자료구조 독립 invariant |
| E7 | SkillRegistryCutterValidateTest (v2 — 신설 R1-M1) | get_skill("cutter") non-null + validate_stage errors 0 | §10 §6 SkillRegistry-part (no skill_id collision/registration) |
| E8 | StageLayoutBuilderEarthBackwardCompatTest (v3 — parameterized R2-M1) | phase 1~18 전수 layout build 후 모든 cell kind="earth" + plant kind 0건 across all | §10 §7 (backward compat — 전수 검증) |
| E9 | SkillToolbarCutterIntegrationTest (v3 — 신설 R2-H3) | SkillSlot 생성 + skill_id/icon_texture/ko_label/hotkey assertion | §10 §6 SkillToolbar-part (ICONS/KO_LABELS dict integrity) |

essential 9종 모두 PASS = phase 19 impl-stage codex review clean 종결 조건의 일부.

### 7.2 deferred 2종 (v2 — 3→2, CutterOverHazardCellTest essential 승격)

§2.6 참조. 2종 모두 phase 19 acceptance 미포함이지만 plan 박제로 backlog 형태 유지 — D5/D7 invariant의 회귀 가드 후속 강화 자료.

---

## 8. 무변경 ban list (CRITICAL)

§2.7 ban list가 코드 영역. 본 절은 phase 변경 cross-doc impact 0건 보장:

- `docs/PRD.md` — 무변경. Cutter 메카닉은 PRD §4 "8종 스킬" 슬롯 활용(Bomber 자리 대체). MVP 제외 사항 §15도 무영향
- `docs/ARCHITECTURE.md` — 무변경. SkillRegistry/Terrain/WorkerState 패턴은 그대로 (preload 1줄·work_type 분기 1종·kind 인자 사용)
- `docs/ADR.md` — 무변경. ADR-003(명시적 preload) + ADR-007(cell 단위 파괴) + ADR-010(StaticBody2D registry) 모두 phase 18에서 정착, phase 19는 패턴 답습
- `docs/PHASE_14_OPTION_B_PROPOSAL.md` — 무변경 (역사 보존, phase 19 결정은 plan 본 문서에 박제)
- `phases/mvp/REVISION_2026-05-18-option-b.md` — 무변경 (v4 매핑 그대로)
- `phases/mvp/notion-phase-ids.json` — 무변경 (phase 19 page_id 기존 매핑)
- `phases/mvp/metadata.json` — 무변경 (active_revision = v4)
- `phases/mvp/status.json` — phase 19 complete 시 자동 갱신 (사용자 수정 불필요)

---

## 9. 회귀 가드 — phase 1~18 essential 헤드리스 PASS 확인

phase 19 impl-stage 진입 전·후 다음 명령으로 회귀 검증:

```powershell
# Phase 2~4 (stage 베이스)
python scripts/run_test.py tests/Stage02HeadlessTest.tscn
python scripts/run_test.py tests/Stage03HeadlessTest.tscn
python scripts/run_test.py tests/BlockerOverlapTest.tscn
# Phase 14 (mechanic-adaptation-traits)
python scripts/run_test.py tests/SandMoundClimbTest.tscn
python scripts/run_test.py tests/SandMoundMaxHeightTest.tscn
python scripts/run_test.py tests/BridgeGapCrossTest.tscn
python scripts/run_test.py tests/BridgeGapTooLongTest.tscn
# Phase 15 (mechanic-adaptation-settlement)
python scripts/run_test.py tests/SettlementHundredPercentStuckTest.tscn
# Phase 16 (mechanic-creation)
python scripts/run_test.py tests/BridgeRejectStageCellTest.tscn
python scripts/run_test.py tests/SandBridgeOverlapTest.tscn
# Phase 17 (mechanic-hazard)
python scripts/run_test.py tests/WaterHazardLossEmptyHandTest.tscn
python scripts/run_test.py tests/StickyStuckReleaseTest.tscn
python scripts/run_test.py tests/BridgeOverWaterTest.tscn
python scripts/run_test.py tests/BridgeOverWaterStickyOverlapTest.tscn
# Phase 18 (mechanic-destruction-earth)
python scripts/run_test.py tests/BasherTunnelThroughWallTest.tscn
python scripts/run_test.py tests/DiggerVerticalTunnelTest.tscn
python scripts/run_test.py tests/BasherEdgeStopTest.tscn
python scripts/run_test.py tests/DiggerFallThroughUpperAntTest.tscn
python scripts/run_test.py tests/TerrainDestroyTileApiTest.tscn
```

모두 PASS 유지 → phase 19 변경이 phase 1~18 회귀 침범 0. 실패 시 phase 19 변경에서 원인 추적(`StageLayoutBuilder` plant 분기·`SkillToolbar` ICONS dict 등 cross-file 영향 의심).

> v3.1.1 impl-stage 정정: plan v1~v3.1의 §9 회귀 명령이 stale 파일명 4건(`Stage01HeadlessTest.tscn`, `SettleStuckTest.tscn`, `SandMoundCarryRejectedTest.tscn`, `BridgeTooLongTest.tscn`)을 박제하고 있었다. 실제 디렉터리 enumeration 기준으로 phase 14~18 essential 14개로 갱신 — Stage01은 phase 2~4 essential의 Stage02/03이 dev/main 양쪽 회귀 가드 역할을 이미 수행하므로 제거. sand_mound carry reject은 `SandMoundSkill.can_apply`의 has_candy guard로 자연 차단되어 별도 essential 없으므로 SandMoundClimb/MaxHeight 두 essential로 메카닉 회귀 가드. bridge too long도 `BridgeGapTooLongTest`가 동일 invariant 검증.

**phase 19 신규 essential 9종 전체 명시 enumeration (v3 — R2-H2 fix, 8→9 cap 확장)**:

```powershell
python scripts/run_test.py tests/CutterCutThroughVineTest.tscn                     # E1
python scripts/run_test.py tests/CutterEdgeStopTest.tscn                           # E2
python scripts/run_test.py tests/CutterOnEarthRejectedTest.tscn                    # E3
python scripts/run_test.py tests/BasherOnPlantRejectedTest.tscn                    # E4
python scripts/run_test.py tests/TerrainPlantKindRoundTripTest.tscn                # E5
python scripts/run_test.py tests/CutterOverHazardCellTest.tscn                     # E6 (v2 — R1-H2)
python scripts/run_test.py tests/SkillRegistryCutterValidateTest.tscn              # E7 (v2 — R1-M1)
python scripts/run_test.py tests/StageLayoutBuilderEarthBackwardCompatTest.tscn    # E8 (v3 — R2-M1 parameterized)
python scripts/run_test.py tests/SkillToolbarCutterIntegrationTest.tscn            # E9 (v3 — R2-H3)
```

**9종 전부 PASS → impl-stage codex review clean 종결 조건의 일부**. 어느 한 test라도 FAIL/SKIP 시 impl-stage 진입 불가. E6/E7/E8/E9 신설/승격 4종은 R1~R2 fix로 추가된 acceptance gate — impl-stage가 우회 못 함.

---

## 10. Strict acceptance (impl-stage codex review enforcement)

phase 19 impl-stage codex review가 본 invariant 위반을 HIGH로 검출:

1. **No silent cell-kind divergence**: `register_static_body(cell, body, "plant")` 호출은 `Terrain._cell_kind[cell] = "plant"` AND `_static_occupancy[cell] = true` AND `_static_bodies[cell] = body`를 동시 보장 — 세 registry 어느 하나만 등록되는 분기 0. `destroy_tile_at(cell, ["plant"])` true 반환 시에도 세 registry 일괄 erase + body queue_free atomic (phase 18 invariant 자연 적용).
2. **No cross-kind destruction**: Basher/Digger 코드의 `destroy_tile_at(target, ["earth"])` 호출은 plant cell에서 false 반환. Cutter 코드의 `destroy_tile_at(target, ["plant"])` 호출은 earth cell에서 false 반환. allowed_kinds 인자 변조 0건. WorkerState의 work_type 분기에서 다른 mode가 자기 kind 검사를 우회하는 경로 0.
3. **No silent placement on plant**: `Terrain.add_tile(cell)` 호출 시 plant cell이 `_static_occupancy` 점유면 false 반환. WorkerState `_place_*_tile` (builder/sand_mound/bridge) 어디서도 false 반환 무시 후 추가 변경 0.
4. **No cutter velocity drift**: `_destroy_cutter_cell`이 destroy success 후 `a.global_position += Vector2(dir*cs, 0)`로 1 cell 전진. tick interval 중복 적용 0건(`_tick_accum -= CUTTER_TICK` per iteration). _remaining 카운터는 destroy 성공 시에만 -=1.
5. **No off-floor cutter persistence**: `_update_cutter`의 `if not a.is_on_floor(): _aborted = true; FallerState`는 절벽 끝 cutter 활성화 시 즉시 종료. fall 도중 cutter 유지 X (Digger와 행위 다름 — Digger는 vertical tunnel 연속성 위해 fall 중 유지, Cutter는 수평 cut 메카닉이라 fall 도중 cutter는 의미 없음).
6. **No skill_id collision + no toolbar integration regression** (v3 — E7 SkillRegistry + E9 SkillToolbar split enforce): SkillRegistry._skills의 ID assertion에서 "cutter"가 신규 등록되고 기존 9 entry와 충돌 0. `validate_stage(cutter_stage)` errors 0. **SkillToolbar `ICONS["cutter"]` + `KO_LABELS["cutter"]` dict entry 신규 추가 시 기존 entry 무수정 + cutter SkillSlot 인스턴스화 시 icon_texture/ko_label 정상 wire**. 검증:
   - **E7 essential test** (SkillRegistry-part): `get_skill("cutter") != null` + `validate_stage` errors 빈 배열 + `_skills.has("cutter")` assert.
   - **E9 essential test** (SkillToolbar-part, v3 — R2-H3 fix): SkillToolbar instantiate 후 SkillSlot.icon_texture == `ICONS["cutter"]` (non-null) + SkillSlot.ko_label == "절단" + slot.skill_id == StringName("cutter") assert. ICONS dict에 cutter entry 누락 또는 KO_LABELS 누락 시 E9 deterministic FAIL.
7. **Backward compat — phase 1~18 전수 검증** (v3 — E8 parameterized enforce, R2-M1 fix; v3.1 — R3-M1 fix): phase 1~18 dev/main stages가 register_static_body 호출 시 모두 "earth" kind 그대로 등록(StageLayoutBuilder.build()의 generated[g].kind 기본값 = "earth", `TILE_PLANT_SOLID` 외 tile_type은 모두 "earth"). plant tile_type을 쓰는 stage는 phase 19 신규 fixture 4종만(dev_cutter_vine_layout / dev_cutter_edge_stop_layout / dev_earth_plant_separation_layout / dev_cutter_over_hazard_layout). 검증: **E8 essential test가 `data/stage_layouts/*.tres`를 런타임 스캔하고 phase 19 plant fixture 4종만 제외한 뒤, 모든 scanned layout build 후 전수 순회하며 모든 cell `kind == "earth"` + plant kind 0건 across all layouts assert**. slope cell, earth solid cell 모두 kind="earth" enforce. single-sample 또는 hand-maintained static enumeration 검증 미허용.

---

## 11. Risk / Open dependencies

| 리스크 | 영향 | 처리 |
|---|---|---|
| cutter.svg placeholder가 시각적으로 부족 | 토너 UX 부정적 — 어린 플레이어가 "절단" 메타포 인지 못 함 | placeholder는 phase 19 acceptance 미포함. phase 20 polish 또는 별도 디자인 핸드오프(codex-worklog) 트랙 |
| Plant cell visual ColorRect alpha 색이 earth/hazard와 시각 혼동 | 메카닉 분리 인지 어려움 | 연두색(R0.45 G0.78 B0.32) earth(갈색 R0.45 G0.28 B0.15)와 hazard(파란색/노란색)와 색상 distinct. 정식 텍스처는 phase 20 polish |
| Stage scene editor에서 plant cell preview 색 어두움 | 디자이너 작업 시 가독성 ↓ | `_rebuild_preview()` 경로도 `_add_plant_visual` 호출 — preview 시각 동일. 색 톤은 phase 20에서 디자이너 피드백 후 조정 |
| StageLayoutBuilder의 `tile_map` value vocabulary 확장 (`"solid"/"slope_*"/"plant"`)이 phase 21+ stage data 작성에 혼란 | 디자이너가 string 오타로 silent fallback (예: "plnt" → 기본 solid 처리) | `_add_cell`에서 알 수 없는 tile_type은 기본 solid(earth) — silent fallback이지만 ColorRect 시각이 plant와 distinct하므로 디자이너 즉시 인지. 명시 assertion 추가는 plan v2에서 재검토 가능 |
| plant cell이 dev_earth_plant_separation_layout에서 path 막혀 essential test FAIL 위험 | E3/E4 false fail | layout 도식(§6.3)에서 ant가 자동 통과 못 함 명시. test driver는 ant 1명에만 cutter 적용·다른 1명에만 basher 적용으로 분기 검증 (자동 player 시뮬레이션 X, sequenced apply) |
| Cutter 작동이 Basher와 시각상 거의 동일 (수평 절단 vs 수평 굴착) | player가 두 skill 차이 인지 못 함 | phase 19 1차 도입은 메카닉 메타포 분리(plant=절단, earth=굴착) 우선 — 시각 차이는 phase 20 polish에서 cell 시각 + skill cursor 시각으로 강화 |
| `register_static_body("plant")`가 phase 14~18 회귀에 영향 | 기존 stage는 모두 "earth" 사용 — kind 인자 backward compat 검증 | `_add_cell` 분기에서 plant 외 tile_type은 모두 kind="earth"로 통합. phase 14~18 dev stage 11종 헤드리스 회귀 PASS로 검증 (§9) |

---

## 12. Self-review checklist (v3.1.1 — Round 4 clean + R4-M1 wording 정정 확인)

v3.1은 R3 STOP 후 사용자 cap 확장으로 codex Round 4를 받았고 verdict clean 결과. R4-M1 MEDIUM(row 컨벤션 wording 불일치)은 v3.1.1에서 D4/§6.4 wording 정정으로 inline 종결. 다음 self-test는 v3.1.1 작성 직후 1회 실행:

- [x] §0 한 줄 요약 + §0.0 v2→v3 변경표 + §0.1 v1→v2 변경표가 모두 부합 (R1-H1/H2/M1 + R2-H1/H2/H3/M1 fix 누적 추적)
- [x] §0.0 R2-H1 fix가 §6.4 도식에서 plant cell을 body row (10, 21)로 통일 + hazard 좌표도 (10, 21) + alternate floor-row 시나리오 제거와 일관
- [x] §0.0 R2-H2 fix가 §9 closing wording "essential 5종" → "essential 9종 전체 명시 enumeration" 변경 + 9개 PowerShell 명령 박제와 일관 + 전수 grep "5종" 0건
- [x] §0.0 R2-H3 fix가 §2.5 E9 SkillToolbarCutterIntegrationTest 신설 + §7.1 essential 9 rows + §10 §6 SkillRegistry-part(E7) + SkillToolbar-part(E9) split enforce 매핑과 일관
- [x] §0.0 R2-M1 fix가 §2.5 E8를 single-sample → parameterized 전수 검증 명세로 강화 + §10 §7 "phase 1~18 전수 검증" 명시와 일관
- [x] §1 결정 D1~D10 무변경 (v3에서 결정 정정 0건, fix는 §2.5/§6.4/§7.1/§9/§10/§12 명세 측면만)
- [x] §2 변경 대상이 §8 ban list와 서로소 (v3 추가 cascade 0 — E9는 신규 test 1건, SkillToolbar.gd 수정 자체는 v1부터 명시)
- [x] §2.5 essential 9종이 §10 strict acceptance §1~7과 enforce 매핑 — E9 ↔ §10 §6 SkillToolbar-part 정합
- [x] §2.6 deferred 2종 유지 (v3에서 변경 0건)
- [x] §3 Terrain API 무변경 일관
- [x] §4 WorkerState cutter 분기 무변경 일관
- [x] §6 dev stage 도식 4종 — §6.1 cutter_vine, §6.2 cutter_edge_stop, §6.3 earth_plant_separation, §6.4 cutter_over_hazard (v3 — body-row primary). 모두 §2.3 layout 명세 좌표 일치
- [x] §9 회귀 가드 — phase 1~18 회귀 15개 명령 + phase 19 essential 9개 명령 = 24개 PowerShell 명령 박제
- [x] §10 strict acceptance §1~7 모두 essential test E1~E9 enforce 경로 명시 (E1~E5 → §1~§4, E6 → D4, E7+E9 → §6, E8 → §7)
- [x] §11 risk 표 v3 변경 0 (v2 risk 그대로 유지)
- [x] **v3 변경이 v1/v2 기본 design 보존하고 R2-H1/H2/H3/M1 fix만 inline 적용** — D1~D10 결정 무변경
- [x] **v3.1 R3-H1 fix** — §6.4 E6의 ant spawn은 (9,21) 단일 SoT, 첫 cutter target은 (10,21), (8,21) 경로는 역사적 Round 3 finding 설명 외 구현 지시에서 제거
- [x] **v3.1 좌표 범위 명시** — E6 좌표 고정은 deterministic fixture 전용이며 런타임 Cutter/plant 로직은 좌표 비의존이라고 §0/§2.5/§6.4에 명시
- [x] **v3.1 R3-M1 fix** — E8는 `data/stage_layouts/*.tres` 런타임 스캔만 SoT, hand-maintained static enumeration 금지, phase 19 plant fixture 4종만 exclude
- [x] **v3.1.1 R4-M1 fix (row 컨벤션 wording)** — D4 결정 헤더/본문 (b)/(c)가 plant=body row + typical cell-disjoint 근거를 "별개 x좌표"로 정정, §6.4 캡션이 "phase 19 모든 fixture에서 body row 배치 컨벤션(§6.1~§6.4 일관)"으로 통일. "plant=floor row" 문구 잔존 0건
- [x] **Round 4 verdict clean 확인** — codex가 R3-H1/R3-M1 CLOSED + HIGH 0건 + R4-M1 MEDIUM(wording-only)만 잔존 판정. 잔존 MEDIUM도 v3.1.1에서 닫힘

---

**다음 액션**: v3.1.1 wording 정정 내역을 `phase19-plan-review.md` Round 4 섹션에 함께 보존(이미 누적됨). plan-stage 사용자 승인 상태에서 impl-stage 진입 준비. 추가 plan 라운드 없음. 구현 시작 전에는 §9의 phase 1~18 회귀 명령과 phase 19 essential 9종 명령을 기준으로 test scaffold/implementation 순서를 맞춘다.
