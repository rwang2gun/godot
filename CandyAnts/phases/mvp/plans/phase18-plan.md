# Phase 18 Plan — mechanic-destruction-earth (v10)

**Status**: plan v10 — codex adversarial-review Round 7 HIGH H1-R7 fix(§6.3 요건 3의 `is_on_floor()` 사전 가드 제거 — Mode A same-frame과 충돌하여 R5 drift 재발시키던 contract internal contradiction 해소. ant_B 안착 보장은 `_update_digger` 내부 first-tick fall-through 가드(§10 §4)에 위임). **Round 6/7는 v8 정책 전환 가설의 2차 검증 라운드**: pseudocode 박제 제거 후 R6, R7 모두 contract logic gap만 발견(코드 결함 0건). plan-stage가 본래 역할(contract 검증)로 복귀 — 가설 안정화. 이전 fix 누적: v9 Round 6 H1-R6(derivation 모드 제거 → Mode A/B만), v8 Round 5 H1-R5(§6.3 narration drift fix + pseudocode 삭제 + 6 guideline 박제), v7 Round 4 H1-R4(one-shot digger application), v6 Round 3 H1-R3(explicit headless quit), v5 Round 2 H1-R2(5-condition gate), v4 Round 1 H1(**Option A 채택** + D11 `_off_floor_frames`/`DIGGER_OFF_FLOOR_LIMIT=180` void termination), v3 local consistency fix, v2 self-review fix. plan-stage 정책: codex HIGH 1건 발견 시 **즉시 중단 + 사용자 결정** (자동 재리뷰 X). v10는 사용자 standing directive("네가 수정하고 재 리뷰 진행해봐")로 mechanical fix 적용.
**Phase frontmatter doc**: [phases/mvp/phase18-mechanic-destruction-earth.md](../phase18-mechanic-destruction-earth.md)
**1차 SoT 인용**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §3.4 (파괴 메카닉) / §3.4.1 (Basher + Digger, 17a) / §5.2 (17 분할) / §0.2 (어휘 정책) / §7.1 (정수 id 정책)
**관련 코드 SoT**: `scripts/core/SkillRegistry.gd` (SKILL_SCRIPTS 명시적 preload, ADR-003), `scripts/ant/states/WorkerState.gd` (multi-mode 패턴 — builder/blocker/sand_mound/bridge), `scripts/world/Terrain.gd` (phase 16 `_static_occupancy` + phase 17 `_hazards_by_cell` 패턴 + Bridge × hazard 통합점), `scripts/world/StageLayoutBuilder.gd` (정적 cell body 생성·register), `scripts/ant/Ant.gd` (effective_speed / is_alive 단일 진입점), `scripts/skills/{Sand,Bridge}Skill.gd` (can_apply 패턴 — Walker + on_floor + !has_candy), `scripts/ui/SkillToolbar.gd` (basher/digger 아이콘·KO 라벨 **선반영 — 코드 변경 0건**), `tests/BlockerOverlapTest.gd` (test driver runner protocol + state observation 패턴 — §6.3 guideline 답습 대상), `scripts/run_test.py` (exit code → PASS/FAIL 시그널, `--quit-after 3600` 안전망)
**리뷰 보존**: [phases/mvp/reviews/phase18-plan-review.md](../reviews/phase18-plan-review.md) (R1~R7 HIGH fix 누적 + **R8 codex APPROVE clean 종결** — plan-stage 적대적 리뷰 통과. impl-stage 진입 가능)
**작성**: 2026-05-24 (v1~v9 — 9 라운드 누적), 2026-05-24 (v10 — codex Round 7 H1-R7 fix: 요건 3에서 is_on_floor() 사전 가드 제거 → Mode A same-frame과 정합)

---

## 0.9 v9 → v10 변경 (codex adversarial-review Round 7 H1-R7 fix — 요건 3 is_on_floor() 가드 제거)

| # | 항목 | v9 | v10 | finding |
|---|---|---|---|---|
| H1-R7 | §6.3 요건 3 (One-shot apply) vs 요건 4 Mode A (same-frame) 충돌 | 요건 3은 apply 전제로 `not digger_applied AND ant_b.is_on_floor() AND is WalkerState`를 요구. 요건 4 Mode A는 spawn 직후 same-frame apply 요구. Mode A에서 ant_B spawn 직후 physics tick 미실행 → `is_on_floor()` = false(비결정적) → 요건 3 차단 → 다음 frame defer → R5 drift 재발. 두 요건이 상호 충돌하여 essential test가 정상 구현에서 fail하거나 implementer가 요건 3 우회 → R4 가드 약화 | **요건 3 본문에서 `is_on_floor()` 사전 가드 제거**. 전제 = `not digger_applied AND ant_b.state_machine.current_state is WalkerState`만. ant_B 안착 보장은 driver 단계가 아니라 `_update_digger` 내부 first-tick fall-through bypass 가드(§10 strict acceptance §4 — off-floor 시 destroy skip + `_off_floor_frames` 카운터)에 위임. driver의 is_on_floor() 검사는 redundant(§10 §4가 이미 동일 invariant 보호) | codex Round 7 [HIGH] H1-R7 |

> **R7 의의 (정책 안정화)**:
> - R6에 이어 R7도 contract logic gap(요건간 internal contradiction) — pseudocode 코드 결함 X
> - v8 정책 전환 가설 검증 2회 누적: pseudocode 박제 제거 후 plan-stage codex review가 contract 검증으로 안정화
> - 향후 라운드: contract gap만 surface → mechanical fix 후 자연 종료 expected. 코드 결함 재발 시 정책 재검토.

---

## 0.8 v8 → v9 변경 (codex adversarial-review Round 6 H1-R6 fix — derivation 모드 제거)

| # | 항목 | v8 | v9 | finding |
|---|---|---|---|---|
| H1-R6 | §6.3 요건 4 Pre-apply drift 방지 옵션 (c) | "target cell을 적용 시점 body cell에서 derive"가 옵션 (a) same-frame, (b) velocity ZERO와 동급의 enforcement 모드로 나열됨. 그러나 derivation은 drift를 **prevent X, follow O** — ant_B가 column 11로 drift되면 target=(11,22), §6.3 layout은 column 10에만 y=27 hole + column 11+ floor solid이므로 ant_B 안착 → D11 timeout 미발생 → 정상 구현이 §2.4 PASS criterion (4) fail | **derivation 모드 제거**. (a)/(c) 자리에 Mode A(same-frame spawn+apply, 필수 권장) + Mode B(별도 frame spawn 시 explicit assertion `body_cell == (10,21)`, 불일치 시 즉시 `_fail` + `quit(1)`)만 허용 명시. 본문에 "금지: target cell을 ant_b body cell에서 derive하는 모드" 명시. 옛 (b) `velocity = ZERO + WalkerState 진입 차단`도 제거 — Mode A로 충분하고 (b)는 구현 복잡 + 검증 면적 추가 | codex Round 6 [HIGH] H1-R6 |

> **Round 6 의의 (정책 전환 가설 검증)**:
> - v8 정책 전환 가설: pseudocode 박제를 guideline으로 교체하면 plan-stage codex review에서 pseudocode 코드 결함 라운드 폭증 차단되고 contract logic gap 검사로 본래 역할 복귀
> - Round 6 결과: ✓ **검증 성공**. R2~R5는 모두 §6.3 pseudocode의 specific code defects(5-cond gate / quit / one-shot / drift)였으나 R6는 contract 자체의 logic gap(option c가 drift를 prevent X, follow O) — 정확히 plan-stage가 잡아야 할 종류의 결함
> - v9 이후: contract gap fix는 mechanical → round-cycle 자연 종료 expected (R7에서 새 HIGH 발견 시 동일 패턴인지 확인하여 정책 재검토)

---

## 0.7 v7 → v8 변경 (codex adversarial-review Round 5 H1-R5 fix + 정책 전환: §6.3 pseudocode 삭제 → contract guideline)

| # | 항목 | v7 | v8 | finding |
|---|---|---|---|---|
| H1-R5 | §6.3 ant_B drift before digger apply | ant_B는 0.5s에 spawn 후 1.0s까지 0.5s 동안 default WalkerState로 walk_speed=60px/s 이동 → x=336→366 (cell 10→11). 따라서 1.0s 적용 시 destroy 대상이 (11,22)이지만 test driver는 (10,22) destroy만 기록 → false FAIL or assertion 약화 | **(a) §6.3 narration 수정**: ant_B를 1.0s 시점에 spawn + **same physics frame**에서 digger 적용 (drift window 0 frame). (b) §2.4 test 4 row 정정 — target cell을 "적용 시점 실제 body cell + (0,1)" 로 derive 명시. (c) `tests/DiggerFallThroughUpperAntTest.gd`의 column 10 가정을 contract guideline 요건 2-(1)로 박제 | codex Round 5 [HIGH] H1-R5 |
| Policy-shift | §6.3 plan 박제 범위 | test driver pseudocode 전문(~120줄) + 검증 게이트 매핑 표가 plan §6.3에 박제됨 → codex가 Round 2 H1-R2(5-cond gate 누락), Round 3 H1-R3(quit 누락), Round 4 H1-R4(one-shot 누락), Round 5 H1-R5(drift)를 4 라운드 연속 §6.3 pseudocode 영역에서 발견. plan에 검증 코드를 박제할수록 codex가 코드 결함을 찾을 surface가 늘어남 — round-cycle 폭증 | **§6.3 pseudocode 전문 삭제 + 검증 게이트 매핑 표 삭제**. 대신 **6 요건 contract guideline** 신설: (1) Runner protocol, (2) 5-condition gate, (3) One-shot digger application, (4) Pre-apply drift 방지, (5) Hard timeout, (6) State observation isolation. 각 요건은 R1~R5 fix 누적의 contract 요약. 실제 코드는 impl-stage에서 작성하고 impl-stage codex review가 enforce. plan-stage codex review는 contract gap만 검사 (코드 결함 surface 제거) | 4 라운드 누적 패턴 분석 결과 |

> **정책 전환 근거 (v8)**:
> 1. 4 라운드 연속 §6.3 pseudocode 영역에서 HIGH 발견 — self-review가 codex를 못 따라잡음
> 2. pseudocode는 implementation 상세, plan은 contract 정의의 본질 — 둘을 분리해야 round-cycle 차단
> 3. impl-stage codex review가 실제 test driver 코드를 검증 — plan-stage에서 같은 코드를 사전 검증할 가치 < 검증 round-cycle cost
> 4. CLAUDE.md plan-stage 정책 (codex HIGH 1건 → 즉시 중단)이 코드 결함마다 round을 강제 — pseudocode 박제 시 round 폭증 보장
>
> **v8 이후 contract gap 발견 시**: codex Round 6+는 §6.3 contract guideline 요건이 §2.4 PASS 5조건을 enforce하기에 충분한지를 검사. coverage 부족 시 요건 추가, redundancy 시 통합. pseudocode 자체는 plan에서 절대 다시 도입하지 않는다.

---

## 0.6 v6 → v7 변경 (codex adversarial-review Round 4 H1-R4 fix — one-shot digger application)

| # | 항목 | v6 | v7 | finding |
|---|---|---|---|---|
| H1-R4 | §6.3 test driver pseudocode step (b) | `elapsed >= 1.0` 이후 ant_B가 WalkerState일 때마다 `WorkerState.new("digger")`를 재적용. one-shot guard가 없고 `is_on_floor()` 확인도 없어, Option A 위반 구현이 잠시 WalkerState로 빠진 뒤 driver에 의해 다시 Digger로 강제 진입하면 destroy+5 WorkerState 검사에서 false-positive 가능 | `var digger_applied: bool = false` 추가. step (b)는 `not digger_applied` AND `ant_b.is_on_floor()` AND WalkerState일 때만 1회 적용하고, 적용 직후 `digger_applied = true`. 이후 driver는 상태를 관찰만 하며 ant_B를 다시 WorkerState로 강제하지 않음 | codex Round 4 [HIGH] H1-R4 |

> **H1-R4 fix는 test driver side effect 제거** — §6.3 pseudocode의 역할을 "한 번 스킬 적용 후 관찰"로 제한한다. 이로써 Option A 위반 구현이 테스트 드라이버의 재적용 때문에 가려지는 경로를 닫는다.

---

## 0.5 v5 → v6 변경 (codex adversarial-review Round 3 H1-R3 fix — explicit headless quit)

| # | 항목 | v5 | v6 | finding |
|---|---|---|---|---|
| H1-R3 | §6.3 test driver pseudocode `_pass()` / `_fail()` | `_pass()`는 `_result = 1` + 주석만, `_fail()`은 `_result = -1` + `push_error()`만 수행. `scripts/run_test.py`와 기존 headless tests 패턴이 기대하는 `get_tree().quit(0/1)` exit signal이 없어 gate 위반이 deterministic nonzero exit로 귀결되지 않음 | `_pass()`는 `print("DiggerFallThroughUpperAntTest PASS")` 후 `get_tree().quit(0)`. `_fail(reason)`은 `push_error("DiggerFallThroughUpperAntTest FAIL: " + reason)` 후 `get_tree().quit(1)`. `_result`는 재진입 방지용으로 유지하되, 외부 runner contract는 explicit quit으로 고정 | codex Round 3 [HIGH] H1-R3 |

> **H1-R3 fix는 test harness contract 보강** — v5의 5-condition gate 자체는 유지하되, PASS/FAIL 결과가 headless runner에 명시적 exit code로 전달되도록 한다. 기존 `tests/*.gd`의 `get_tree().quit(0)` / `quit(1)` 패턴을 답습한다.

---

## 0.4 v4 → v5 변경 (codex adversarial-review Round 2 H1-R2 fix — pseudocode 5-condition gate)

| # | 항목 | v4 | v5 | finding |
|---|---|---|---|---|
| H1-R2 | §6.3 test driver pseudocode | §2.4 PASS 기준은 4개로 늘렸으나 §6.3 pseudocode는 v3 그대로 — `_pass()` trigger 조건이 `ant_a_faller_frame > cell_destroy_frame` 단일 검사. D11 timeout 부재/오류 구현도 ant_A fall-through만 일어나면 PASS — v4가 막으려던 "void-WorkerState 영구 잔존" 실패 모드의 회귀 가드 없음 | **pseudocode 전면 재작성**. `_pass()`는 5조건 모두 충족 시에만 trigger: (1) cell_destroy_frame 기록, (2) destroy+5 frame에 ant_B.state == WorkerState, (3) ant_b_faller_frame 기록, (4) ant_b_faller_frame ∈ [destroy + LIMIT - 5, destroy + LIMIT + 5] (D11 enforcement, ±5 frame), (5) ant_a_faller_frame > cell_destroy_frame. 위반 시 explicit reason의 _fail. PASS_TIMEOUT_SEC = 30s hard timeout. §6.3 pseudocode 끝에 "검증 게이트 매핑" 표 추가 — 각 PASS 기준이 코드 어디서 enforce되는지 명시 | codex Round 2 [HIGH] H1-R2 |

> **H1-R2 fix는 mechanical inconsistency 해소** — v4가 §2.4 PASS row만 갱신하고 §6.3 pseudocode 갱신을 빠뜨린 누락. 본 fix는 설계 변경 X, 검증 코드 정합성만 보강. const `DIGGER_OFF_FLOOR_LIMIT`은 plan과 WorkerState.gd 양쪽에 명시되어 drift 위험 감소 (변경 시 D11 결정 + plan §1.2 + WorkerState.gd 3곳 동시 갱신 필수).

---

## 0.3 v3 → v4 변경 (codex adversarial-review Round 1 H1 fix — Option A 채택)

| # | 항목 | v3 | v4 | finding |
|---|---|---|---|---|
| H1 | Digger off-floor 시 상태 계약 | **plan 내부 자기모순**: §4.3 snippet은 off-floor 시 early return(WorkerState 유지)인데, §6.3 narration과 §2.4 test 4 line 113 PASS 기준은 "_aborted → WorkerState exit → WalkerState 복귀" 라고 기술. 같은 fall 시퀀스에 대해 두 결과가 동시에 요구돼 implementer가 어느 쪽 따를지 결정 불가 | **Option A 채택 — Digger는 falling 중에도 WorkerState 유지** (vertical tunnel 연속 굴착의 의도된 동작, §4.3 snippet 주석과 §10 strict acceptance §4와 일치). 단 void/hazard로 무한 낙하 방지 위해 **void/hazard termination rule** 신설: `_off_floor_frames` 카운터 + `DIGGER_OFF_FLOOR_LIMIT = 180` (3초 @ 60fps) 초과 시 `_aborted` → FallerState 자연 전이. §6.3 narration 정정, §2.4 test 4 PASS 기준 정정(ant_B는 landing 시점 또는 void timeout 시점에 WorkerState exit), §10 acceptance §6 신설, D11 신설 | codex Round 1 [HIGH] H1 |

> **Option A 선택 근거**:
> 1. §4.3 snippet 주석이 이미 "_aborted X — floor 다시 만나면 계속 굴착(연속 vertical tunnel)" 명시 — 설계 의도가 Option A
> 2. §10 strict acceptance §4 ("off-floor 시 destroy skip")도 Option A 전제
> 3. Option B는 Digger를 사실상 무용지물로 만듦 (1 cell 굴착 후 hand-off → DIGGER_MAX_CELLS=12 의미 상실)
> 4. v3의 §6.3 narration이 self-review H-self-1 fix 도중 잘못 갱신된 흔적 — 본질적인 fix가 아니라 narration 정합 문제

> **Option A 보강 — void/hazard termination 설계**:
> - `_off_floor_frames`는 `_update_digger` 내 멤버. on_floor 시 0으로 reset, off-floor 시 증가
> - 임계값 180 frames (3초 @ 60fps) 도달 시 `_aborted = true` → `FallerState.new()` 전이 (WalkerState 거치지 않음 — 이미 falling 중이라 Walker 전이 후 Faller 재전이는 1 frame 낭비)
> - 정상 vertical tunnel 1-cell drop은 1~3 frames, 5-cell drop도 30~60 frames → 180 frames 임계값에 도달 안 함
> - hazard 진입 시 phase 17 LostState 경로가 외부에서 `change_state` 호출 → `_off_floor_frames` 카운터와 무관하게 자연 종료. 본 rule은 "hazard도 없는 완전한 void" 의 안전망 한정
> - 정상 케이스(2~5 cell drop)에서는 trigger되지 않으므로 _off_floor_frames는 비활성 변수

---

## 0.2 v2 → v3 변경 (local consistency review fix)

| # | 항목 | v2 | v3 | finding |
|---|---|---|---|---|
| H-local-1 | §6.1/§6.2 Basher/Digger 검증 stage row convention | home/candy cell이 floor row로 표기되거나, Digger가 `body_cell + (0, 1)`로 바로 아래 floor row를 제거하는데 도식은 첫 제거 cell을 y=23 pillar로 설명. 기존 StageLayoutData 규칙(home/candy/spawn은 body row, floor는 body row+1)과 충돌 | **body row / floor row 명시 정정**. Basher home/candy는 y=21, floor row는 y=22. Digger는 body row y=21에서 시작, 첫 제거 cell은 floor row y=22이고 이후 shaft y=23~26까지 총 5 cell 제거 후 lower floor y=27에 안착. DiggerVerticalTunnelTest 기대값도 y=22~26 5 cell 제거로 갱신 | Plan would send implementer/test toward wrong cells and flaky/false failing digger tests |
| H-local-2 | §2.4 + §6.4 BasherEdgeStopTest layout | dev_basher_wall_layout의 main wall은 §6.1에서 x=12~15인데 §6.4는 x=6~9를 전제로 wall 일부를 사전 제거. 또한 test가 `destroy_tile_at`으로 wall을 미리 변형하면 BasherEdgeStopTest가 TerrainDestroyTileApiTest와 결합되어 실패 원인 분리가 어려움 | **전용 layout `dev_basher_edge_stop_layout.tres` 신설**. wall body row x=12~13 2 cell + x=14 이후 open space. test는 사전 `destroy_tile_at` mutation 없이 basher 적용 후 2 cell 제거, 추가 파괴 없음, Walker 복귀를 검증 | Shared-layout mutation was coordinate-inconsistent and made the edge-stop test depend on the destruction API under test |
| M-local-1 | stale v1/v2 labels | §0 한 줄 요약(v1), dev id 정책(v1), §13 "본 plan은 v1" 등 stale label 잔존 | 문서 상태를 v3로 통일. v2/v3 변경 이력은 §0.1/§0.2에 보존 | Avoid phase17-style contradiction/stale-label pattern |

---

## 0.1 v1 → v2 변경 (self-review pass)

| # | 항목 | v1 | v2 | finding |
|---|---|---|---|---|
| H-self-1 | §2.4 test 4 (DiggerFallThroughUpperAntTest) + §6.3 dev_basher_digger_chain 도식 | test 본문에 "재설계 필요" 코멘트 + 분기 시나리오 inline. ant_A/ant_B identity 식별 모호. §6.3 도식이 ASCII만으로 두 ant 위치 불명확 | **test 본문에서 분기 시나리오 제거하고 단일 시나리오 명시**. ant_A = 첫 spawn(spawn order 0), ant_B = test driver가 첫 spawn 후 0.5s 시점에 별도 위치에 spawn(test driver 직접 instance + add_to_group("ants")). digger 적용 대상은 ant_B. **§6.3 도식에 ant_A/ant_B 위치 + spawn timing + test driver pseudocode 추가**. v1의 "재설계 필요" 코멘트는 self-review 시점에 자기 정정한 흔적 — codex가 implementer 혼란 위험으로 잡을 가능성 99% | self-review HIGH — implementer가 시나리오 해석 분기로 잘못 구현할 위험 |
| M-self-1 | §10 strict acceptance 조항 1 (No silent cell-kind divergence) | register_static_body / add_tile invariant만 명시 | **backward compat 조항 보강** — phase 14~17 dev stages가 register_static_body 도입 후에도 _static_occupancy 등록 동작 유지(register_static_cell 내부 호출). 회귀는 §9.2 헤드리스 essential PASS로 검증 | self-review MED — register_static_body 도입 후 build() 호출 경로 변경이 phase 14~17 dev stage 회귀 영향 가능성 미명시 |
| M-self-2 | §3 destroy_tile_at snippet — stale body ref 처리 | `is_instance_valid(body) → queue_free` 분기만, "그렇지 않으면 무시"가 default. 그러나 atomic 정의가 "body queue_free + 4 registry erase"이라 stale body로 인한 queue_free skip 시 atomic 위반? | **명시 강화** — body stale(is_instance_valid false) 시 queue_free는 no-op이지만 registry erase는 항상 수행. atomic 정의 = "kind 통과 후 registry 4종은 무조건 erase + body는 valid일 때만 queue_free". snippet 코멘트로 명시. atomic은 registry 일관성 보장, body 노드 수명은 Godot에 위임 | self-review MED — atomic 정의 모호 시 codex가 "queue_free 실패하면 registry 일관성 깨질 위험" 잡을 가능성 |
| M-self-3 | §6 검증 stage 도식 | basher_wall / digger_pillar / basher_digger_chain 3 stage 도식만, BasherEdgeStopTest의 layout 도식 누락 | **§6.4 BasherEdgeStopTest layout 도식 추가** — 2 cell wall + open space + candy. 사전/사후 cell sample 위치 명시 | self-review MED — essential test 5종 중 1종이 도식 없음, codex가 "layout 명세 부족" 잡을 가능성 |
| L-self-1 | §4.2 _destroy_basher_cell 코드 스타일 | `a.global_position.x += float(a.direction) * cs` (스칼라 더하기) | `a.global_position += Vector2(float(a.direction) * cs, 0.0)` (Vector2 더하기) — Builder/Bridge/Sand-mound 패턴 통일 | cosmetic — 일관성 |

> v2 본체(§1~§9)는 v1의 design을 보존하고 self-review fix에 한해 inline 수정. 결정 사항(D1~D10) 변경 0. 변경 분기는 위 5건에 한정. v3는 row convention과 BasherEdgeStop layout만 정정하며 구현 핵심 API 결정은 변경하지 않는다.

---

## 0. 한 줄 요약 (v10)

흙 지형 동적 파괴 메카닉 1차 도입. **신규 스킬 2종**(Basher = 수평 굴착, Digger = 수직 굴착)을 `scripts/skills/` + `SkillRegistry.SKILL_SCRIPTS`에 추가하고 `WorkerState`에 `basher`/`digger` 두 work_type 분기를 확장한다. **Terrain 신규 API 3종**: `register_static_body(cell, body, kind)`로 정적 cell의 StaticBody2D를 cell-keyed registry에 등록(phase 19 Cutter가 동일 API로 plant 등록), `get_cell_kind(cell)` / `destroy_tile_at(cell, allowed_kinds)`로 cell 단위 파괴(dynamic `_placed` + 정적 `_static_bodies` 둘 다 queue_free + `_static_occupancy`/`_cell_kind` atomic erase). `StageLayoutBuilder.build()`은 cell 생성 시 `terrain.register_static_body(cell, body, "earth")`로 등록 — 정적 cell 기본 kind는 "earth"(phase 19에서 "plant" 추가). `Terrain.add_tile(cell)` 동적 placement도 `_cell_kind[cell] = "earth"` 자동 설정 → Bridge·Sand-mound 동적 발판도 Basher/Digger 파괴 대상. Basher는 ant 진행 방향의 body row cell을 12 cell까지 tick 단위로 제거(`_destroy_basher_cell`, BASHER_TICK=0.18s, BASHER_MAX_CELLS=12), 매 제거 시 ant.x += dir*cs로 1 cell 전진. Digger는 ant 바로 아래 floor row cell을 12 cell까지 제거(`_destroy_digger_cell`, DIGGER_TICK=0.20s, DIGGER_MAX_CELLS=12), ant 위치 갱신 X — 다음 physics tick에 is_on_floor=false → 자유 낙하 → 다음 floor 안착 후 재개. **Digger는 falling 중에도 WorkerState 유지** (vertical tunnel 연속 굴착, v4 Option A); 단 `_off_floor_frames > DIGGER_OFF_FLOOR_LIMIT(=180 frames, 3초 @60fps)` 초과 시 `_aborted` → FallerState로 자연 종료(void 무한 낙하 안전망, codex Round 1 H1 보강). **§6.3 test driver는 plan에서 pseudocode 박제 X — 6 contract guideline만 명시(v8 정책 전환)**: Runner protocol + 5-condition gate + One-shot apply + Pre-apply drift 방지 + Hard timeout + State observation isolation. 실제 코드는 impl-stage에서 `tests/BlockerOverlapTest.gd` 패턴 답습하여 작성하고 impl-stage codex review가 enforce — plan-stage round-cycle 폭증(R2~R5 4 라운드 누적) 차단. **v3 row convention**: StageLayoutData의 home/candy/spawn cell은 ant body row, floor는 body row + 1. Digger 검증 layout은 body row y=21, first floor target y=22, shaft y=23~26, lower floor y=27로 통일. **위쪽 ant fall-through**는 자연 분기 — Walker의 `if not is_on_floor()` 체크가 다음 physics tick에 Faller 전이 (별도 코드 가드 0). **chain reaction 없음** — `destroy_tile_at`은 target cell만, 인접 cell 검사 0건. **파괴 가능 영역 시각화 없음** — preview overlay/cursor hint는 phase 20 polish로 deferred. dev 검증 stage 4종(basher_wall, digger_pillar, basher_digger_chain, basher_edge_stop_layout-only) + 헤드리스 회귀 5 essential + 6 deferred 박제. **Bridge × hazard 통합**(phase 17 D8): Basher/Digger는 hazard cell을 파괴하지 않는다 — `destroy_tile_at(cell, allowed_kinds=["earth"])`이 hazard cell의 kind는 ""(미등록)이므로 false 반환. hazard와 destruction은 독립. **§0.2 어휘 정합**: 신규 식별자·문자열·문서는 "파괴"/"굴착"/"제거"만 사용 (frontmatter "톤 폴리시" 항목과 일치). 신규 코드(Basher/Digger/Terrain 확장)에서 `die()`/`Dead`/"사망"/"죽" 0건 — 본 phase는 ant 손실 직접 트리거 안 함(낙하 후 Water 진입은 phase 17 LostState 경로로 자연 처리).

---

## 1. Open decisions before implementation — 결정 (frontmatter doc 5건 + 본 plan 도출 5건)

> **Recommended** 표기는 사용자가 추천안을 채택하면 본 plan 명세 그대로 진행. redirect 시 v3에서 갱신.

### 1.1 PROPOSAL §3.4.1 derived 결정 (frontmatter doc 5건)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D1 | 흙 동적 파괴 후 위쪽 개미 fall-through (§3.4.1) | **next physics tick — 자연 분기** | 추천안. Walker.update가 매 frame `if _frame > 1 and not a.is_on_floor(): change_state(FallerState.new())` 검사. Digger가 frame N에 floor cell 제거(queue_free deferred) → frame N+1 시작 시 body 제거 완료 → 위 ant move_and_slide가 새 physics state로 fall → Walker.update가 is_on_floor=false 검출 → FallerState 전이. 별도 가드/시그널 0건. 즉시 재계산을 강제하면 frame 중간 state 변경 race 위험(phase 11 BlockerHitbox 교훈 답습) |
| D2 | Basher/Digger chain reaction (§3.4.1) | **없음 — 단일 cell per tick** | 추천안. `destroy_tile_at(cell, allowed_kinds)`은 target cell 1개만 처리. 인접 cell 검색 0건. chain reaction은 (a) 추가 시스템(stability 모델, neighbor cell 검색, performance impact) 도입 (b) Bridge/Sand-mound 같은 동적 발판이 의도치 않게 무너지는 puzzle 파괴. MVP 단순성(ADR-008) |
| D3 | 파괴 가능 영역 시각화 (§3.4.1) | **없음 — phase 20 polish로 deferred** | 추천안. PROPOSAL §3.4.1 TBD. preview overlay는 추가 시스템(stage 단위 cell scan, cursor 추적, 시각 노드 layer). MVP는 메카닉 검증 우선. 플레이어가 wall에 직접 적용해 보고 결과 확인(Lemmings 원작 패턴) |
| D4 | Cell 제거 시 충돌 갱신 비용 — batch 처리 (frontmatter doc 추가 항목) | **단일 cell per tick — batch 없음** | 추천안. Basher/Digger는 tick 단위(0.18s/0.20s) 1 cell 제거. 12 cell 굴착은 약 2.16~2.40초. Godot queue_free deferred batch는 자동 (end-of-frame). 명시적 batch API 도입 시 부분 실패 시 atomic rollback 복잡성. 단일 cell이 단순·안전 |
| D5 | 식물 지형(phase 19)과의 구분: TileMap layer / terrain set / custom data (frontmatter doc) | **`Terrain._cell_kind: Dictionary` (Vector2i → String "earth"\|"plant", default "earth")** — 코드 측 분류, TileMap layer/custom data 미사용 | 추천안. (a) StageLayoutBuilder가 이미 TileMap 없이 Dictionary `tile_map` 기반(StageLayoutData.tile_map: `{cell_key: type}`). TileMap 도입은 마이그레이션 비용. (b) `_cell_kind`는 Terrain 측 단일 SoT로 dynamic(Bridge/Sand-mound) + static(Stage layout) 모두 커버. (c) Basher/Digger는 `destroy_tile_at(cell, ["earth"])` 고정, Cutter는 `destroy_tile_at(cell, ["plant"])`. allowed_kinds 분리로 cross-mechanic 침범 차단 |

### 1.2 본 plan 도출 결정 (구현 디테일 5건)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D6 | Basher/Digger can_apply 가드 | **WalkerState + on_floor + !has_candy** (sand_mound/bridge 패턴 답습) | 추천안. Builder는 Walker/Carrying + on_floor만(carry 중 발판 생성 가능). Sand-mound/Bridge는 추가로 !has_candy(carry 중 작업 시 has_candy 잔존 위험, phase 16 lesson). Basher/Digger도 carry 중 wall 굴착·바닥 파괴는 puzzle 디자인 의도 흐림 — 단순성 우선. carry 허용은 phase 20 polish 또는 v1.1에서 재검토. **wall 인접 가드는 없음** — Lemmings 원작 패턴 + 플레이어 책임. 적용 후 wall 없으면 `_aborted=true` → Walker 즉시 복귀 (no-op) |
| D7 | Basher/Digger MAX_CELLS 상한 | **BASHER_MAX_CELLS = 12, DIGGER_MAX_CELLS = 12** (Builder TOTAL_TILES와 동일) | 추천안. Builder=12 cell(수평 발판), Bridge=8 cell, Sand-mound=5 cell. Basher/Digger는 destruction 메카닉이라 build보다 진행 거리 동일(12)로 대칭. 너무 작으면(예: 5) puzzle scope 제한, 너무 크면(예: 32) 1 ant로 전체 stage 파괴 가능 — 12는 phase 16 Builder 길이와 일치하여 mental model 통일 |
| D8 | Basher/Digger tick interval | **BASHER_TICK = 0.18s, DIGGER_TICK = 0.20s** | 추천안. Builder=0.20s, Bridge=0.20s, Sand-mound=0.25s. Basher는 active dig라 약간 빠르게(0.18). Digger는 수직이라 floor-loss + 자유낙하 cycle 고려 0.20. 12 cell × 0.18s = 약 2.16초, × 0.20s = 2.40초 → puzzle pacing 적정 |
| D9 | Dynamic add_tile cell의 kind | **"earth" 기본값** — add_tile은 항상 _cell_kind[cell]="earth" 설정 | 추천안. Bridge/Sand-mound 발판은 동적이지만 destructible. Basher/Digger 파괴 대상 = "earth"라면 동적 발판도 파괴 가능 (puzzle 디자인: Bridge 만든 후 다른 ant가 Basher로 제거 → Bridge 재사용 X). 의도 명확. plant 동적 placement는 phase 19에서 Cutter 도입 시 분기 |
| D10 | Hazard cell에 Basher/Digger 적용 | **무효 — kind 미등록이므로 destroy_tile_at false** | 추천안. Hazard는 `_hazards_by_cell` registry에 등록되며 `_cell_kind`에는 미등록(hazard는 floor가 아니라 area). `get_cell_kind(hazard_cell) == ""` → `destroy_tile_at(hazard_cell, ["earth"])` false. Basher가 hazard cell에 도달하면 _aborted → Walker 복귀. hazard 직접 파괴는 phase 19 Cutter도 안 함 — hazard 제거는 Bridge placement의 deactivate 경로(phase 17 D8) 한정 유지 |
| D11 | Digger off-floor 무한 낙하 보호 (v4 — codex Round 1 H1) | **`_off_floor_frames` 카운터 + `DIGGER_OFF_FLOOR_LIMIT = 180` frames (3초 @60fps) 초과 시 `_aborted=true` → FallerState** | 추천안. Option A 채택으로 Digger는 falling 중에도 WorkerState 유지(vertical tunnel 연속 굴착). 그러나 hazard도 없는 완전한 void 낙하 시 무한 WorkerState 잔존 위험 → 안전망 필요. 임계값 180 frames는 (a) 정상 1~5 cell drop(1~60 frames)에서 trigger 안 됨, (b) 9.6 m/s² 중력 가속 + cell_size=32 환경에서 5+ cell 연속 drop도 ~90 frames 이내, (c) 3초 timeout이 player에게 "뭔가 잘못됨" feedback으로 적정 길이. Walker 우회하지 않고 직접 FallerState 전이 — 이미 falling 중이라 Walker 1-frame 우회 비용 회피 |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)
| 파일 | 용도 |
|---|---|
| `scripts/skills/BasherSkill.gd` | `class_name BasherSkill extends Skill`. `const ID: String = "basher"`. `can_apply(ant)`: ant null·is_alive·WalkerState·is_on_floor·!has_candy 검사 (sand_mound/bridge 패턴). `apply(ant)`: `ant.state_machine.change_state(WorkerState.new("basher"))` |
| `scripts/skills/DiggerSkill.gd` | `class_name DiggerSkill extends Skill`. `const ID: String = "digger"`. can_apply/apply 동일 패턴 with `"digger"` |
| `tests/test_BasherSkill.gd` | TDD guard 우회 stub — `extends Node` + 한 줄 코멘트. 실제 coverage는 integration 헤드리스 |
| `tests/test_DiggerSkill.gd` | 동일 stub |

### 2.2 수정 (.gd)
| 파일 | 변경 |
|---|---|
| `scripts/core/SkillRegistry.gd` | `SKILL_SCRIPTS` 배열에 `preload("res://scripts/skills/BasherSkill.gd"), preload("res://scripts/skills/DiggerSkill.gd"),` 2줄 추가 (ADR-003 명시적 preload 정책). 기존 7 항목 뒤 append, 순서 무관 |
| `scripts/world/Terrain.gd` | **(1)** 신규 필드 `var _static_bodies: Dictionary = {}` (Vector2i → StaticBody2D), `var _cell_kind: Dictionary = {}` (Vector2i → String). **(2)** 신규 `register_static_body(cell: Vector2i, body: StaticBody2D, kind: String = "earth") -> void`: `_static_bodies[cell] = body; _cell_kind[cell] = kind; register_static_cell(cell)`. **(3)** 신규 `get_cell_kind(cell: Vector2i) -> String`: `return _cell_kind.get(cell, "")` ("" = cell 없음). **(4)** 신규 `destroy_tile_at(cell: Vector2i, allowed_kinds: Array[String] = ["earth"]) -> bool`: kind 검사 후 dynamic `_placed[cell]` + static `_static_bodies[cell]` 둘 다 queue_free + `_placed`/`_static_bodies`/`_static_occupancy`/`_cell_kind` 모두 erase. 한 번에 atomic. 미등록 또는 kind 불일치 시 false (어떤 변경도 0). **(5)** `add_tile(cell)` 본문 끝(success 분기)에 `_cell_kind[cell] = "earth"` 1줄 추가 — 동적 placement도 destructible. **(6)** 기존 `register_static_cell`/`has_tile`/`tile_count`/`_hazards_by_cell` API **무변경** |
| `scripts/world/StageLayoutBuilder.gd` | **(1)** `_add_cell(cell, tile_type) -> StaticBody2D` — 기존 void → StaticBody2D 반환 (호출부 build() + _rebuild_preview() 둘 다 캡처 변경). **(2)** `build()` 본문: `_layout_tile_map().keys()` 루프에서 `_add_cell(...)` 반환 body를 `generated: Array[Dictionary]`(`{"cell": c, "body": body}`)에 누적. 기존 `for c in generated_cells: terrain.register_static_cell(c)` 분기를 `for g in generated: terrain.register_static_body(g.cell, g.body, "earth")`로 교체. **이전 register_static_cell 호출은 register_static_body 내부에서 자연 호출**되므로 별도 호출 제거. **(3)** `_rebuild_preview()`은 editor preview용 — Terrain 없는 상태이므로 반환값 무시 `_ = _add_cell(...)` (또는 `_add_cell(...)`만, 무캡처). **(4)** 기존 `_clear_children`/`_add_solid_collision`/`_add_solid_visual`/`_add_slope_collision`/`_add_slope_visual` **무변경** — _add_cell이 body 생성 + 자식 추가 + body 반환만 수정 |
| `scripts/ant/states/WorkerState.gd` | **(1)** 신규 const `const BASHER_TICK: float = 0.18`, `const BASHER_MAX_CELLS: int = 12`, `const DIGGER_TICK: float = 0.20`, `const DIGGER_MAX_CELLS: int = 12`, **`const DIGGER_OFF_FLOOR_LIMIT: int = 180`** (v4 — D11). 신규 멤버 변수 **`var _off_floor_frames: int = 0`** (digger 모드에서만 사용, basher 모드는 unused — 첫 off-floor 시 즉시 _aborted라 카운팅 불필요). **(2)** `enter()` 분기에 `elif _work_type == "basher": _enter_basher(a)`, `elif _work_type == "digger": _enter_digger(a)` 2줄 추가 (기존 builder/blocker/sand_mound/bridge/else 뒤). **(3)** `update(delta)` 분기에 `elif _work_type == "basher": _update_basher(a, delta); return`, `elif _work_type == "digger": _update_digger(a, delta); return` 2줄 추가. **(4)** 신규 `_enter_basher(a)`: `_remaining = BASHER_MAX_CELLS; _tick_accum = 0.0; _aborted = false; a.velocity = Vector2.ZERO`. **(5)** 신규 `_enter_digger(a)`: 동일 with `DIGGER_MAX_CELLS` + `_off_floor_frames = 0` 초기화. **(6)** 신규 `_update_basher(a, delta)`: gravity + slide + on_floor 검사(off-floor 시 _aborted + FallerState) + tick 누적 + `_basher_forward_has_earth(a)` 가드(false면 _aborted) + `_destroy_basher_cell(a)`. _remaining<=0 or _aborted면 WalkerState 복귀. **(7)** 신규 `_update_digger(a, delta)`: gravity + slide + off-floor 분기(tick 소비 skip + `_off_floor_frames += 1` 카운팅 + `DIGGER_OFF_FLOOR_LIMIT` 초과 시 _aborted + **FallerState 직접 전이** (Walker 우회 X) + return) + on_floor 분기(_off_floor_frames=0 reset + tick 누적·소비 + `_digger_below_has_earth(a)` 가드 + `_destroy_digger_cell(a)`). _remaining<=0 or _aborted면 WalkerState 복귀 (단 off-floor timeout으로 _aborted된 경우는 _update_digger 내부에서 이미 FallerState 직접 전이됨). **(8)** 신규 `_destroy_basher_cell(a)`: body_cell 계산(Builder 패턴 `(y-2)/cs`) + target = body_cell + (direction, 0) + `terrain.destroy_tile_at(target, ["earth"])` + 성공 시 `a.global_position.x += dir*cs`, _remaining-=1. 실패 시 _aborted. **(9)** 신규 `_destroy_digger_cell(a)`: target = body_cell + (0, 1) + `terrain.destroy_tile_at(target, ["earth"])` + 성공 시 ant 위치 무변경 (다음 physics tick에 자연 낙하), _remaining-=1. 실패 시 _aborted. **(10)** 신규 `_basher_forward_has_earth(a) -> bool`: `terrain.get_cell_kind(body_cell + (dir, 0)) == "earth"`. **(11)** 신규 `_digger_below_has_earth(a) -> bool`: `terrain.get_cell_kind(body_cell + (0, 1)) == "earth"`. **(12)** `exit()` 본문 **무변경** — basher/digger는 Walker 복귀 시 자연 해제 (sand_mound/bridge 패턴 동일) |
| `scripts/ui/SkillToolbar.gd` | **무변경** — basher/digger 아이콘 + KO 라벨 모두 사전 wired (scripts/ui/SkillToolbar.gd:18-19, 31-33) |
| `scripts/core/EventBus.gd` | **무변경** — 신규 시그널 0건. Basher/Digger는 ant 손실 직접 트리거 안 함 (Digger 후 자유 낙하 + Water 진입은 phase 17 LostState 경로) |
| `scripts/core/ScoreSystem.gd` | **무변경** — 4-카운터(ADR-002) 무영향 |
| `scripts/ui/HUD.gd` | **무변경** |
| `scripts/world/StageLayoutData.gd` | **무변경** — `tile_map` 기존 Dictionary 그대로. plant kind 분류는 phase 19에서 추가 시 layout 데이터 확장 검토(본 phase 미해당) |

### 2.3 신규 (검증 stage)
| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_basher_wall_layout.tres` | StageLayoutData. cell_size=32. home 좌측 + candy 우측 + 그 사이 4 cell 두께 수직 wall 있음. ant가 basher로 wall 통과 → candy → home |
| `data/stages/dev/basher_wall_test.tres` | StageData. **id=917** (dev 예약 — phase 17 sweep 914/916 회피). display_name="dev-basher-wall". available_skills=`["basher"]`. skill_inventory=`{"basher": 2}`. total_ants=4, candy_hp=4, time_limit=60, release_rate_initial=30 |
| `scenes/stages/dev/BasherWallTest.tscn` | Stage scene. BridgeTest 패턴 + dev_basher_wall_layout wiring |
| `data/stage_layouts/dev_digger_pillar_layout.tres` | StageLayoutData. cell_size=32. home 좌측(body row y=21) + first floor target(y=22) + 4 cell shaft(y=23~26) + 그 아래 candy 위치한 하단 floor(y=27). ant가 digger로 y=22~26 총 5 cell 굴착 → 낙하 → candy 도달 → home (귀환은 점프·climb 불필요 layout) |
| `data/stages/dev/digger_pillar_test.tres` | StageData. **id=918**. display_name="dev-digger-pillar". available_skills=`["digger"]`. skill_inventory=`{"digger": 2}`. total_ants=4, candy_hp=4, time_limit=60, release_rate_initial=30 |
| `scenes/stages/dev/DiggerPillarTest.tscn` | Stage scene. 동일 패턴 |
| `data/stage_layouts/dev_basher_digger_chain_layout.tres` | StageLayoutData. cell_size=32. wall + pillar 조합 layout — 위쪽 ant가 walk 중 아래 ant의 digger로 인해 fall-through. 위쪽 ant fall-through 회귀 검증 전용 |
| `data/stages/dev/basher_digger_chain_test.tres` | StageData. **id=919**. display_name="dev-basher-digger-chain". available_skills=`["basher","digger"]`. skill_inventory=`{"basher":2,"digger":2}`. total_ants=6, candy_hp=6, time_limit=90 |
| `scenes/stages/dev/BasherDiggerChainTest.tscn` | Stage scene |
| `data/stage_layouts/dev_basher_edge_stop_layout.tres` | StageLayoutData. cell_size=32. **BasherEdgeStopTest 전용 layout-only fixture**. body row x=12~13에 2 cell wall, x=14 이후 open space. 별도 StageData id 없음(테스트 씬 직접 참조) |

> **dev id 정책 (v3)**: id ≥ 900 dev 예약 답습. phase 18 신규 StageData 점유 **917~919 (3건)**. `dev_basher_edge_stop_layout.tres`는 layout-only test fixture라 StageData id 미점유. phase 17 sweep 예약 914(sticky_settle) / 916(water_after_candy) 회피. 점유 확인: 901~909 phase 14~16, 910~913 phase 17 essential, 915 phase 17 v3 R1-H1.

### 2.4 신규 (tests/)
| 파일 | 검증 |
|---|---|
| `tests/BasherTunnelThroughWallTest.tscn/gd` | 헤드리스. dev_basher_wall_layout. ant 1명에 basher 적용 → 4 cell wall 통과 → candy 도달 → home 회수. **PASS**: 30초 내 (1) `saved_pieces >= 1`, (2) 통과한 wall cell 들의 `terrain.get_cell_kind(cell) == ""` (제거 확인), (3) `terrain.has_tile(cell) == false` AND static body 노드 free 확인 (test driver가 노드 검색) |
| `tests/DiggerVerticalTunnelTest.tscn/gd` | 헤드리스. dev_digger_pillar_layout. ant 1명에 digger 적용 → first floor target + 4 cell shaft(**y=22~26 총 5 cell**) 굴착 → 자유 낙하 → 하단 floor 안착 → candy → home. **PASS**: 30초 내 (1) `saved_pieces >= 1`, (2) 굴착된 shaft cell 들 kind="" + body queue_free, (3) 굴착 과정에서 ant_state가 `WorkerState("digger")` → `WalkerState`/`FallerState` 자연 전이를 거쳐 walker 재개, (4) 낙하 도중 LostState 진입 0건 (hazard 없음) |
| `tests/BasherEdgeStopTest.tscn/gd` | 헤드리스. **dev_basher_edge_stop_layout (§6.4) 전용**. 사전 `destroy_tile_at` mutation 없음. ant가 basher 적용 → 2 cell wall 제거 후 forward에 earth 없음 → `_basher_forward_has_earth` false → _aborted → Walker 복귀. **PASS**: 30초 내 (1) basher 후 ant state가 WalkerState, (2) 2 cell 제거 후 추가 cell 파괴 X (인접 cell 무영향), (3) §6.4의 사전 sample 5 cell의 kind 무변동 (test driver가 사전 kind 캐싱 후 사후 비교) |
| `tests/DiggerFallThroughUpperAntTest.tscn/gd` | 헤드리스. dev_basher_digger_chain_layout (§6.3). **시나리오 (v8)**: 상단 floor 위에 ant_A(첫 spawn, spawn order 0) walk 진행 중. test driver가 1.0s 시점에 ant_B를 cell (10,21)에 spawn + **같은 physics frame**에서 즉시 digger 적용 (v8 — drift 방지). ant_B는 ant_A보다 우측. ant_B 발 밑 cell (10,22) 제거 → ant_B 낙하 시작. **v4 Option A**: ant_B는 falling 중에도 WorkerState("digger") 유지. 하단 floor(y=27)가 column 10에 hole이므로 ant_B는 `_off_floor_frames` 누적 → `DIGGER_OFF_FLOOR_LIMIT(=180 frames)` 초과 시 `_aborted` → FallerState 직접 전이. ant_A는 좌→우 walk 진행 중 cell (10,22) 위 진입 시점에 is_on_floor=false → WalkerState 자연 분기로 FallerState 전이. **PASS (5 criteria — 구현 요구사항은 §6.3 contract guideline에서 enforce)**: 30초 내 (1) `cell_destroy_frame` 기록 — 추적 대상 = cell (10,22) literal (§6.3 요건 4 Mode A/B로 ant_B body cell == (10,21) 보장), (2) ant_B의 destroy+5 frame 시점 state == WorkerState (Option A enforcement), (3) `ant_b_faller_frame` 기록, (4) `ant_b_faller_frame ∈ [destroy + DIGGER_OFF_FLOOR_LIMIT − 5, destroy + DIGGER_OFF_FLOOR_LIMIT + 5]` (D11 enforcement), (5) `ant_a_faller_frame > cell_destroy_frame` (D1 enforcement). 하나라도 위반 시 `_fail(reason)` + `get_tree().quit(1)`. **시나리오 단일성**: digger 적용 대상은 ant_B 한정 (ant_A에 적용 X). 분기 시나리오 없음 |
| `tests/TerrainDestroyTileApiTest.tscn/gd` | 헤드리스 unit-style. Stage 없이 Terrain 노드만 인스턴스화 + register_static_body로 cell 등록 + add_tile로 동적 cell 등록 + destroy_tile_at 호출 검증. **PASS**: (1) `destroy_tile_at(static_cell, ["earth"])` true 후 `has_tile(static_cell)==false` + `get_cell_kind(static_cell)==""` + `_static_occupancy` 미포함 + body queue_free, (2) `destroy_tile_at(dynamic_cell, ["earth"])` true 후 동일 invariant + `_placed` 미포함, (3) `destroy_tile_at(unregistered_cell, ["earth"])` false (변경 0), (4) `destroy_tile_at(static_cell, ["plant"])` false (kind 불일치, 변경 0), (5) atomic: false 반환 시 어떤 registry도 변경 0 (test driver가 사전 snapshot 후 사후 비교) |

### 2.5 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 시그널 추가 0건. Basher/Digger는 ant 손실 직접 트리거 안 함
- `scripts/core/ScoreSystem.gd` — 4-카운터(ADR-002) 무영향
- `scripts/core/StageData.gd`, `StageLayoutData.gd`, `StageRunner.gd`, `SaveData.gd`, `MenuLayout.gd` — 무변경
- `scripts/ant/Ant.gd` — 무변경. is_alive·effective_speed·has_candy·set_blocker_active 모두 그대로 (Basher/Digger는 worker mode이므로 Walker/Carrying 진입점만 사용)
- `scripts/ant/states/{Walker,Carrying,Faller,Climber,Saved,Dead,Settled,Lost}State.gd` — 무변경. Walker.update의 fall 가드(`if not is_on_floor: change_state(FallerState)`)는 본 phase D1 자연 분기 그대로 사용
- `scripts/skills/{Builder,Blocker,Climber,Floater,Distributor,SandMound,Bridge,Skill}.gd` — 무변경. 신규 BasherSkill/DiggerSkill만 추가
- `scripts/ui/HUD.gd`, `SkillToolbar.gd` — 무변경 (toolbar 아이콘·라벨 사전 wired)
- `scripts/world/hazards/{HazardBase,WaterHazard,StickyHazard}.gd` — 무변경. Hazard cell은 `_cell_kind`에 미등록이므로 Basher/Digger 자연 무시 (D10)
- `scripts/world/{Candy,Home,SettlementMarker,CookiePlatformVisual}.gd` — 무변경
- 기존 stages Stage01~03 / data/stages/stage0N.tres — hazard·basher·digger 미사용, 회귀 무영향
- phase 14~17 dev stages — basher/digger 미사용, 회귀 무영향
- 기존 헤드리스 테스트 — basher/digger 미관련, 모두 PASS 유지

### 2.6 텍스처 정책
본 phase 신규 텍스처 0건. SkillToolbar는 기존 basher.svg / digger.svg 재사용. 파괴 시 cell body는 queue_free로 즉시 제거 — 페이드/파티클 없음(phase 20 polish로 deferred).

---

## 3. Terrain 신규 API 명세

```gdscript
# Terrain.gd — phase 18 추가
# Phase 18 — 정적 cell body registry. StageLayoutBuilder가 register_static_body로 등록 → destroy_tile_at 시 body 직접 queue_free 가능.
# Dynamic _placed와 별도 — 정적 cell은 StageLayoutBuilder 자식이지만 destroy_tile_at에서 통합 처리.
var _static_bodies: Dictionary = {}   # Vector2i → StaticBody2D
# Phase 18 — cell 종류 분류. "earth"(default) / "plant"(phase 19) / "" (미등록).
# destroy_tile_at의 allowed_kinds 매개변수로 cross-mechanic 침범 차단.
var _cell_kind: Dictionary = {}        # Vector2i → String

func register_static_body(cell: Vector2i, body: StaticBody2D, kind: String = "earth") -> void:
	if body == null:
		return
	_static_bodies[cell] = body
	_cell_kind[cell] = kind
	register_static_cell(cell)   # 기존 _static_occupancy 등록 — D8 first-place wins 자연 정합

func get_cell_kind(cell: Vector2i) -> String:
	# "" = cell 미등록(공기 또는 hazard). "earth"/"plant" 등 명시 kind 있을 때만 destroy 후보.
	return _cell_kind.get(cell, "")

func destroy_tile_at(cell: Vector2i, allowed_kinds: Array[String] = ["earth"]) -> bool:
	# atomic invariant (M-self-2):
	# - kind 검사 통과 전: 모든 registry 무변경.
	# - kind 통과 후: registry 4종(_placed/_static_bodies/_static_occupancy/_cell_kind)은 무조건 erase.
	# - body 노드는 valid일 때만 queue_free. stale ref (이미 free된 노드)는 queue_free skip + registry는 정상 erase.
	# - 즉 atomic은 "Terrain 측 registry 일관성" 보장. body 노드 수명은 Godot scene tree에 위임.
	var kind: String = get_cell_kind(cell)
	if kind == "" or not allowed_kinds.has(kind):
		return false
	# dynamic 먼저 — 같은 cell이 dynamic + static 둘 다일 수 없음(add_tile의 D8 가드).
	# 그러나 방어적 — 둘 다 검사하여 stale ref 제거.
	if _placed.has(cell):
		var body_dyn: StaticBody2D = _placed[cell]
		if is_instance_valid(body_dyn):
			body_dyn.queue_free()
		_placed.erase(cell)
	if _static_bodies.has(cell):
		var body_static: StaticBody2D = _static_bodies[cell]
		if is_instance_valid(body_static):
			body_static.queue_free()
		_static_bodies.erase(cell)
	_static_occupancy.erase(cell)
	_cell_kind.erase(cell)
	return true

# 기존 add_tile 본문 끝(success 분기)에 1줄 추가:
func add_tile(cell: Vector2i) -> bool:
	if _placed.has(cell) or _static_occupancy.has(cell):
		return false
	# ... 기존 body 생성/sprite/global_position 설정 ...
	add_child(body)
	_placed[cell] = body
	_cell_kind[cell] = "earth"   # Phase 18 — 동적 placement도 destructible
	return true
```

**불변식**:
1. `register_static_body(cell, body, "earth")` 호출 후 `get_cell_kind(cell) == "earth"` AND `_static_occupancy.has(cell)` AND `_static_bodies[cell] == body`.
2. `add_tile(cell)` true 반환 후 `get_cell_kind(cell) == "earth"` AND `_placed.has(cell)`.
3. `destroy_tile_at(cell, ["earth"])` true 반환 후 `get_cell_kind(cell) == ""` AND `has_tile(cell) == false` AND `_static_occupancy.has(cell) == false` AND `_static_bodies.has(cell) == false`. body는 queue_free (end-of-frame).
4. `destroy_tile_at` false 반환 시 모든 registry 무변경 (atomic — kind 검사 전 어떤 erase도 X).

---

## 4. WorkerState basher/digger 분기 명세

### 4.1 _enter_basher / _enter_digger

```gdscript
const BASHER_TICK: float = 0.18
const BASHER_MAX_CELLS: int = 12
const DIGGER_TICK: float = 0.20
const DIGGER_MAX_CELLS: int = 12
const DIGGER_OFF_FLOOR_LIMIT: int = 180   # v4 — D11 void/hazard termination safety net (3s @ 60fps)

var _off_floor_frames: int = 0            # v4 — digger off-floor 연속 frames

func _enter_basher(a: Ant) -> void:
	_remaining = BASHER_MAX_CELLS
	_tick_accum = 0.0
	_aborted = false
	a.velocity = Vector2.ZERO

func _enter_digger(a: Ant) -> void:
	_remaining = DIGGER_MAX_CELLS
	_tick_accum = 0.0
	_aborted = false
	_off_floor_frames = 0                 # v4 — D11
	a.velocity = Vector2.ZERO
```

### 4.2 _update_basher

```gdscript
func _update_basher(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())
		return
	# 중력 + 좌우 정지 (Builder/Sand-mound 패턴).
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	# floor contact 잃으면 abort → Faller (절벽 끝에서 basher 활성화한 경우 자연 해제).
	if not a.is_on_floor():
		_aborted = true
		a.state_machine.change_state(FallerState.new())
		return
	_tick_accum += delta
	while _tick_accum >= BASHER_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= BASHER_TICK
		if not _basher_forward_has_earth(a):
			_aborted = true
			break
		_destroy_basher_cell(a)
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())

func _destroy_basher_cell(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	# Builder 패턴 답습 — (y-2.0)/cs로 ant 본체 cell.
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = body_cell + Vector2i(a.direction, 0)
	var ok: bool = terrain.destroy_tile_at(target, ["earth"])
	if not ok:
		_aborted = true
		return
	# L-self-1 — Vector2 더하기로 Builder/Bridge/Sand-mound 스타일 통일.
	a.global_position += Vector2(float(a.direction) * cs, 0.0)
	_remaining -= 1

func _basher_forward_has_earth(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	return terrain.get_cell_kind(body_cell + Vector2i(a.direction, 0)) == "earth"
```

### 4.3 _update_digger

```gdscript
func _update_digger(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())
		return
	# 중력 + 좌우 정지.
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	# v4 Option A — off-floor면 자유 낙하 진행. WorkerState 유지(vertical tunnel 연속 굴착).
	# Basher와 달리 _aborted X — digger는 floor 다시 만나면 계속 굴착.
	# 단 D11 void/hazard termination — off-floor 연속 frames 임계값 초과 시 안전망 작동.
	if not a.is_on_floor():
		_off_floor_frames += 1
		if _off_floor_frames > DIGGER_OFF_FLOOR_LIMIT:
			# Void 무한 낙하 안전망. Walker 우회하지 않고 FallerState 직접 전이
			# (이미 falling 중이라 Walker 1-frame 우회는 낭비).
			_aborted = true
			a.state_machine.change_state(FallerState.new())
		return
	# on_floor — counter reset 후 tick 소비.
	_off_floor_frames = 0
	_tick_accum += delta
	while _tick_accum >= DIGGER_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= DIGGER_TICK
		if not _digger_below_has_earth(a):
			_aborted = true
			break
		_destroy_digger_cell(a)
	if _aborted or _remaining <= 0:
		a.state_machine.change_state(WalkerState.new())

func _destroy_digger_cell(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = body_cell + Vector2i(0, 1)   # floor row (ant 바로 아래)
	var ok: bool = terrain.destroy_tile_at(target, ["earth"])
	if not ok:
		_aborted = true
		return
	# ant 위치는 갱신 안 함 — 다음 physics tick에 is_on_floor=false → 중력으로 자연 낙하.
	# 다음 floor 안착 후 _update_digger의 on_floor 분기에서 tick 재개.
	_remaining -= 1

func _digger_below_has_earth(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	return terrain.get_cell_kind(body_cell + Vector2i(0, 1)) == "earth"
```

### 4.4 enter() / update() 분기 추가

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
	elif _work_type == "basher":     # ← 신규
		_enter_basher(a)
	elif _work_type == "digger":     # ← 신규
		_enter_digger(a)
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
	elif _work_type == "basher":     # ← 신규
		_update_basher(a, delta)
		return
	elif _work_type == "digger":     # ← 신규
		_update_digger(a, delta)
		return
	# 기존 builder 분기 (default) — 코드 변경 0
	# ...
```

`exit()` **무변경** — basher/digger는 Walker 복귀 시 정리 불필요. blocker만의 `set_blocker_active(false)` 분기는 그대로 유지.

---

## 5. Bridge × Hazard × Destruction 상호작용 — 불변식

Phase 17 D8(Bridge가 hazard cell 위 발판 생성 시 hazard deactivate) + Phase 18 D10(Basher/Digger는 hazard cell 무영향)을 동시 만족:

| 시나리오 | 결과 | 근거 |
|---|---|---|
| Basher가 Bridge 동적 cell에 도달 | 파괴 성공 (kind="earth") | D9 — add_tile이 _cell_kind="earth" 자동 설정 |
| Basher가 Sand-mound 동적 cell에 도달 | 파괴 성공 (kind="earth") | 동일 |
| Basher가 hazard cell 진입 시도(hazard active) | `_basher_forward_has_earth` false (kind="") → _aborted | D10 |
| Basher가 hazard cell 진입 시도(Bridge로 deactivate된 hazard 위 발판) | Bridge cell의 kind="earth" → 파괴 성공. hazard는 이미 deactivate, monitoring=false라 추가 발화 없음 | D9 + D10 + phase 17 D8 |
| Digger가 Bridge 동적 cell 위에 있을 때 | 자기 발 밑 floor cell 파괴 (kind="earth") | D9 |
| Digger가 모든 cell 굴착 후 hazard 위 위치 | 자유 낙하 → hazard body_entered → 자연 처리 (phase 17 LostState) | 본 phase 추가 가드 0 |

**Basher가 파괴한 cell 위 hazard**: phase 17 hazard cell convention = ant body row (floor_y - 1). Basher가 wall 굴착 = body row의 ant 진행 방향 cell 제거. 그 cell이 hazard cell이면 — D10에 따라 파괴 안 됨 (hazard cell의 `_cell_kind == ""`). hazard 노드 자체는 floor 아닌 air에 있어 wall 굴착과 cell 겹침 거의 없음. 만약 hazard가 wall의 body row에 register됐다면 (이상한 layout) Basher는 그 cell에서 _aborted.

---

## 6. 검증 stage 도식 (cell_size=32)

### 6.1 dev_basher_wall (id=917)

```
y=21 (body row)  . . . . . . . W W W W . . . . . . .
y=22 (floor row) S S S S S S S S S S S S S S S S S S
                 ↑                         ↑
                 home (cell 5,21)          candy (cell 25,21)
                                wall = cell 12~15 (y=21+22 두 row 모두 solid)
```

ant가 home→candy 진로 중 wall 만나면 basher 적용 → 4 cell 통과(body row 굴착) → candy 도달. wall의 floor row는 유지(ant가 그 위로 걸음).

> 검증 포인트: basher가 wall body row 4 cell만 제거. floor row는 그대로(ant가 그 위 걸음). y=21 row의 4 cell 제거 확인 + y=22 row 무변동 확인.

### 6.2 dev_digger_pillar (id=918)

```
y=21  . . . H . . . . . . . . . . .   ← body row (home/candy/spawn row)
y=22  S S S S S S . . . . . . . . .   ← 상단 floor + first dig target at (5,22)
y=23  . . . . . W . . . . . . . . .
y=24  . . . . . W . . . . . . . . .   ← shaft cells (5,23~26)
y=25  . . . . . W . . . . . . . . .
y=26  . . . . . W . . . . . . C . .   ← lower body row after shaft is cleared
y=27  S S S S S S S S S S S S S S S   ← 하단 floor (candy쪽)
                ↑                  ↑
                first target       candy (cell 14,26)
```

상단 body row cell (5,21)에서 ant가 digger 적용 → 자기 발 밑 floor row cell (5,22)을 첫 파괴 → 한 cell 낙하 → 다시 발 밑 shaft cell (5,23) 파괴 → ... → (5,26)까지 총 5 cell 제거 → 하단 floor(cell 5, y=27) 위 안착(body row y=26) → walker로 우측 진행 → candy.

> 검증 포인트: first target + shaft 5 cell(y=22,23,24,25,26) 모두 kind="" + body queue_free. 낙하 도중 LostState 진입 0건. 최종 saved_pieces >= 1.

### 6.3 dev_basher_digger_chain (id=919)

```
       x:  0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22
y=20      . . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .  .  .
y=21      . . . a . . . . . . B  .  .  .  .  .  .  .  .  .  .  .  .   <- body row (ant 위치)
y=22      S S S S S S S S S S S  S  S  S  S  S  S  S  S  S  S  S  S   <- 상단 floor
y=23      . . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .  .  .
y=24      . . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .  .  .
y=25      . . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .  .  .
y=26      . . . . . . . . . . .  .  .  .  .  .  .  .  .  .  .  .  .
y=27      S S S S S S S S S S .  S  S  S  S  S  S  S  S  S  S  S  S   <- 하단 floor (column 10에 hole — v4 D11 timeout 검증용)
```

- **home (상단)**: cell (1, 21) 위치(scene editor에서 직접 좌표). spawn_direction=+1(우측). candy는 하단 floor에 cell (22, 27) (test scope에서 saved 검증 X).
- **column 10 hole (v4)**: y=27 row 중 (10,27)만 빈 cell. 이유: ant_B가 cell (10,22) 파괴 후 column 10 그대로 낙하 → (10,27)에도 floor 없음 → 무한 낙하 → D11 timeout 검증. 다른 column(0~9, 11~22)의 y=27 floor는 유지 — ant_A가 fall-through 후 하단 floor 안착 (LostState 진입 0건 보장).
- **ant_A**: 첫 spawn(AntSpawner spawn order 0). spawn 후 walker로 우측 진행. 도식 시점 위치: cell (3, 21).
- **ant_B (v8)**: test driver가 시뮬레이션 시작 후 1.0s 시점에 spawn — 같은 physics frame에서 cell (10, 21) 배치 + group 등록 + digger 즉시 적용. spawn → walk drift window 없음(R5 fix). spawn_direction=+1이지만 spawn 후 한 frame 안에 WorkerState("digger")로 진입하므로 Walker 이동 0 frame.
- **digger 적용 대상**: ant_B 단일. spawn과 같은 frame에서 `ant_b.state_machine.change_state(WorkerState.new("digger"))` 호출. ant_A에는 어떤 skill도 적용 X. **One-shot guarantee**: driver가 digger를 1회만 적용하고 이후 ant_B 상태를 재변경하지 않음 (R4 fix).
- **digger 동작 (v4 Option A)**: ant_B 발 밑 cell (10, 22) 파괴 → ant_B 낙하 시작. cell (10, 23) 등은 공기지만, **ant_B는 off-floor 상태에서 WorkerState("digger") 유지** (v4 Option A — vertical tunnel 연속성). `_update_digger`의 off-floor 분기에서 tick 소비 없이 `_off_floor_frames` 카운터만 증가. ant_B가 닿을 floor가 없으므로 (chain layout은 cell (10,22) 외 같은 column에 floor 없음) ant_B는 약 3초간 자유 낙하 후 `_off_floor_frames > DIGGER_OFF_FLOOR_LIMIT(=180)` 도달 → `_aborted = true` → **FallerState 직접 전이** (D11 void termination 안전망). 단 chain layout의 하단 floor y=27이 column 10에 존재하면 ant_B는 그 위에 안착 → 다음 tick에 `_digger_below_has_earth((10,28))` false (y=28은 공기) → _aborted → WalkerState로 복귀(이 경우엔 timeout 발동 안 함). **§6.3 layout 의도**: column 10에는 y=22 이외 floor 없음 → ant_B는 timeout 경로로 종료되도록 layout 설계(test 4 D11 검증 의도).
- **ant_A 검증**: ant_A가 좌→우 walker로 진행. ant_A의 body cell이 (10, 21)을 점유할 때 = cell (10, 22) 위에 위치. cell (10, 22)는 ant_B의 digger frame N에 제거됨 → frame N+1부터 ant_A의 is_on_floor=false → WalkerState.update의 `_frame > 1 and not is_on_floor` 분기 → FallerState 전이 (D1 자연 분기).

> 검증 포인트:
> - cell (10, 22)이 ant_B의 digger로 제거된 physics_frame N → ant_A가 그 다음 physics tick(frame N+1 이후) FallerState 전이 detected. ant_A.FallerState 진입 frame > cell (10, 22) destroy frame (D1 자연 분기).
> - ant_B는 cell (10, 22) destroy 직후에도 WorkerState("digger") 유지 (test driver가 destroy frame + 5 frame 시점에 ant_B.state 검사). ant_B의 FallerState 진입 frame ≥ destroy frame + DIGGER_OFF_FLOOR_LIMIT(180) (±5 frame 오차) — D11 void termination 검증.

**Test driver 구현 요구사항 (`tests/DiggerFallThroughUpperAntTest.gd`, impl-stage 작성)**:

> **Plan-stage policy (v8)**: §6.3 pseudocode 박제는 codex adversarial review의 round-cycle 폭증 원인이었다(Round 2~5 4 라운드 연속 §6.3 코드 결함 발견). v8에서 plan은 **contract 명시만** 보유하고, 실제 test driver 코드는 impl-stage에서 작성한다. impl-stage codex review가 §6.3 narration + §2.4 PASS 기준 + 아래 6 요건을 enforce.

본 essential test의 driver(`tests/DiggerFallThroughUpperAntTest.gd`)는 다음 6 요건을 모두 충족해야 한다. 누락 시 Round 1~5 fix로 누적된 회귀 가드가 무력화된다.

1. **Runner protocol (codex Round 3 H1-R3)** — PASS 시 `print("DiggerFallThroughUpperAntTest PASS"); get_tree().quit(0)`, FAIL 시 `push_error("...FAIL: " + reason); get_tree().quit(1)`. `tests/BlockerOverlapTest.gd` 패턴 답습. `scripts/run_test.py:94`가 exit code를 PASS/FAIL 시그널로 사용한다.

2. **5-condition gate (codex Round 2 H1-R2)** — PASS는 다음 5조건 모두 충족 시에만 trigger. 하나라도 위반 시 explicit reason의 `_fail()`:
   - (1) `cell_destroy_frame` 기록 완료. 추적 대상 cell = **(10, 22) literal** (요건 4 Mode A/B가 ant_B body cell == (10, 21)을 frame-deterministic하게 보장 → destroy 대상이 결정론적으로 (10, 22)이므로 magic number 우려 없음). cell (10, 22) 외 cell이 먼저 destroy되면 요건 4 enforcement 실패 — driver는 (10, 22) destroy만 감지하고, 30s 내 미 detection 시 hard timeout `_fail` (요건 5)
   - (2) `destroy_frame + 5` 시점에 `ant_b.state_machine.current_state is WorkerState` (Option A enforcement)
   - (3) `ant_b_faller_frame` 기록 완료
   - (4) `ant_b_faller_frame ∈ [destroy + DIGGER_OFF_FLOOR_LIMIT − 5, destroy + DIGGER_OFF_FLOOR_LIMIT + 5]` (D11 enforcement, ±5 frame 오차)
   - (5) `ant_a_faller_frame > cell_destroy_frame` (D1 enforcement)

3. **One-shot digger application (codex Round 4 H1-R4 + Round 7 H1-R7)** — `digger_applied: bool` flag로 단 1회만 `change_state(WorkerState.new("digger"))` 호출. 전제: `not digger_applied AND ant_b.state_machine.current_state is WalkerState`. **is_on_floor() 사전 가드 제거** (R7 H1-R7 fix): Mode A의 same-frame spawn 직후에는 physics tick 미실행 → `is_on_floor()` 비결정적(보통 false) → Mode A 적용 차단 → 다음 frame defer → R5 drift 재발. is_on_floor() 가드가 요건 4 Mode A와 충돌. 대신 ant_B의 floor 안착 보장은 `_update_digger` 내부의 **first-tick fall-through bypass 가드** (§10 strict acceptance §4 — off-floor 시 destroy skip + `_off_floor_frames` 카운터)가 처리하므로 driver 단계의 is_on_floor() 검사는 redundant. 적용 직후 즉시 `digger_applied = true`. driver는 이후 ant_B 상태 전이를 **관찰만** — 재적용 절대 금지(broken Option-B 구현이 WalkerState로 떨어졌을 때 driver가 mask하는 false-positive 차단, R4).

4. **Pre-apply drift 방지 (codex Round 5 H1-R5 + Round 6 H1-R6)** — ant_B spawn 후 digger 적용 전까지 column 이탈 절대 금지. **두 enforcement 모드만 허용** (derivation 모드는 금지 — drift를 prevent하지 않고 follow하므로 column 10 hole layout과 정합 깨짐, codex R6):
   - **Mode A (필수 — 권장)**: **same physics frame**에 spawn + digger 적용. driver의 동일 `_physics_process` 호출에서 `ant_b = ANT_SCENE.instantiate()` + `add_child` + `global_position` 설정 + `state_machine.change_state(WorkerState.new("digger"))` 모두 처리. spawn timing trigger와 apply timing trigger를 분리하지 않는다. drift window 0 frame 보장.
   - **Mode B (alternative — Mode A가 불가할 때)**: spawn과 apply를 별도 frame에 처리해야 한다면, digger 적용 직전 **explicit assertion** 필수 — `assert int(floor(ant_b.global_position.x / cs)) == 10 and int(floor((ant_b.global_position.y - 2.0) / cs)) == 21` (StageLayoutBuilder body cell convention 답습). 불일치 시 즉시 `_fail("ant_B drifted off (10,21) — H1-R5/R6 guard: body=(%d,%d)" % [...])` 후 `get_tree().quit(1)`.

   **금지**: target cell을 적용 시점의 ant_b body cell에서 derive하는 모드. 본 layout(§6.3)은 column 10에만 y=27 hole을 두고 column 11+의 lower floor는 solid이므로, ant_B가 다른 column으로 drift된 후 굴착하면 D11 timeout 경로(요건 2-(4))가 발생하지 않아 정상 구현이 fail한다.

5. **Hard timeout (codex Round 3 H1-R3 보완)** — driver 내부 `PASS_TIMEOUT_SEC` (권장 30s) 가 runner의 `--quit-after 3600` (60s, `scripts/run_test.py`)보다 짧아야 함. 30초 내 5조건 관찰을 끝내지 못하면 `_fail` with diagnostic reason → deterministic FAIL exit code 보장.

6. **State observation isolation** — driver는 ant_A/ant_B 상태를 **관찰만**. `change_state` 강제 호출은 §6.3 step (b)의 one-shot digger 적용 1회만 허용. ant_A의 state는 절대 강제 변경 X. ant_B의 state도 digger 적용 이후 절대 강제 변경 X.

**구현 참조**: `tests/BlockerOverlapTest.gd` (runner protocol + state observation 패턴), `tests/AtomShowcaseTest.gd` (가장 단순한 PASS-only 패턴).

**§2.4 PASS 5조건 → enforcement source 매핑**:

| § PASS 기준 | 구현 요구사항 | 검증 대상 |
|---|---|---|
| (1) destroy frame 기록 | 요건 2-(1) — cell (10,22) literal 감지 (요건 4 Mode A/B로 column 10 보장) | implementer가 destroy_tile_at 호출했는지 |
| (2) destroy+5 에 ant_B WorkerState | 요건 2-(2) + 요건 3 (one-shot) + 요건 4 (drift 방지) | Option A enforcement (falling 중 WorkerState 유지, driver 재적용/drift 모두 차단) |
| (3) ant_B FallerState frame 기록 | 요건 2-(3) | implementer가 D11 timeout으로 FallerState 전이했는지 |
| (4) FallerState frame ≥ destroy + LIMIT ±5 | 요건 2-(4) 양방향 bound | D11 enforcement (constant 정확도) |
| (5) ant_A FallerState > destroy frame | 요건 2-(5) | D1 enforcement (자연 fall-through) |

### 6.4 BasherEdgeStopTest 전용 layout (v3 — 2 cell wall + open space)

`data/stage_layouts/dev_basher_edge_stop_layout.tres` 신규. dev_basher_wall_layout(§6.1)을 사전 mutation하지 않는다. wall은 body row에 2 cell만 두고, 그 오른쪽은 open space라서 Basher가 2 cell 제거 후 `_basher_forward_has_earth == false`로 자연 종료한다.

```
       x:  8 9 10 11 12 13 14 15 16 17
y=21      . . H  .  W  W  .  .  C  .   <- body row (wall = cell 12,13)
y=22      S S S  S  S  S  S  S  S  S   <- floor row (전구간 solid)
```

- home/body row: (10,21), candy/body row: (16,21), floor row: y=22.
- ant가 home에서 walker로 우측 → wall (12,21) 직면 → basher 적용 → cell (12,21), (13,21) 2 cell 제거 → cell (14,21)에서 `_basher_forward_has_earth(cell 15,21)` false → _aborted → Walker 복귀.
- **검증 사전 sample**: cell (11,21), (14,21), (15,21), (12,22), (13,22) 5개 — basher가 건드리지 않는 영역. 사전 kind 캐싱(모두 ""/earth) 후 사후 비교 → 무변동 확인.

---

## 7. 시그널 흐름

본 phase **신규 시그널 0건**. 기존 EventBus 시그널은 자연 분기로 처리:

- Basher/Digger → 직접 시그널 emit 없음
- Digger 후 ant 자유낙하 → Water hazard 진입 시: `WaterHazard._handle_ant_entry` → `LostState.enter()` → `EventBus.candy_piece_lost` emit (phase 17 경로 그대로)
- 위쪽 ant fall-through → `WalkerState.update`의 `if not is_on_floor: change_state(FallerState)` 분기 → state machine 내부 전이만, 시그널 emit 없음

---

## 8. 엣지 케이스 (검증 시나리오)

> 본 phase는 새로운 destruction API 도입 + 기존 state machine과의 자연 분기. 엣지 케이스는 essential 5 test + deferred 6 박제로 분류.

### 8.1 essential 5 test (§2.4)
1. **BasherTunnelThroughWallTest** — 4 cell wall 정상 통과
2. **DiggerVerticalTunnelTest** — first floor target + 4 cell shaft(y=22~26, 총 5 cell) 정상 굴착 + 낙하 + 회수
3. **BasherEdgeStopTest** — wall 끝 도달 시 자연 종료 (chain reaction 없음 검증)
4. **DiggerFallThroughUpperAntTest** — D1 자연 분기 검증 (위쪽 ant Faller 전이) + **v4 D11 void termination 검증** (ant_B WorkerState 유지 → off-floor timeout → FallerState)
5. **TerrainDestroyTileApiTest** — API atomic 불변식 검증 (dynamic/static/kind 필터/atomic rollback)

### 8.2 deferred 6 (phases/mvp/plans/phase18-deferred.md 박제)
| # | test | 의도 | 박제 사유 |
|---|---|---|---|
| D-1 | BasherCarryingRejectedTest | basher carrying 가드 (can_apply false) | can_apply 자체 코드 단순, BridgeSkill / SandMoundSkill 패턴 답습. essential test의 saved_pieces >= 1로 carrying ant가 basher 후 정상 진행 간접 검증 |
| D-2 | DiggerCarryingRejectedTest | digger carrying 가드 | 동일 |
| D-3 | BasherHazardExposeTest | basher가 hazard 노출(wall 뒤 hidden Water 등) — 노출된 hazard monitoring=true 유지 | hazard 노드는 destroy_tile_at 대상이 아니므로 set_active 변경 0. layout 복잡(wall + hidden Water), phase 20 polish 또는 sweep |
| D-4 | BasherChainNoCascadeTest | basher 단일 cell 제거 후 인접 cell 무영향 | BasherEdgeStopTest의 (3) "wall 외 cell의 kind 무변동" 검증이 사실상 cover. 명시적 chain reaction 검증은 implementation detail |
| D-5 | DiggerInfinityGuardTest | digger _remaining=DIGGER_MAX_CELLS=12에서 정확히 12회만 동작 후 종료 | _remaining 카운터 자체 단순. DiggerVerticalTunnelTest의 5 cell shaft로 자연 종료 검증 (12 cell 굴착은 layout 폭증) |
| D-6 | BasherIntoPlantCellTest | phase 19 plant cell에 basher 적용 시 false | phase 19 Cutter + plant kind 도입 시 함께 작성. 본 phase에 plant 관련 코드 0 |

---

## 9. 검증 시나리오 (수동 + 자동)

### 9.1 헤드리스 자동 (essential 5)
```powershell
& $Python scripts/run_test.py tests/BasherTunnelThroughWallTest.tscn
& $Python scripts/run_test.py tests/DiggerVerticalTunnelTest.tscn
& $Python scripts/run_test.py tests/BasherEdgeStopTest.tscn
& $Python scripts/run_test.py tests/DiggerFallThroughUpperAntTest.tscn
& $Python scripts/run_test.py tests/TerrainDestroyTileApiTest.tscn
```

### 9.2 회귀 (phase 14~17 essential)
phase 16: SandBridgeOverlapTest, BridgeFallAbortTest, BridgeFirstTickOffFloorAbortTest, BridgeGapCrossTest, BridgeGapTooLongTest, BridgeRejectStageCellTest, DynamicTileCellSizeAlignmentTest
phase 17: WaterHazardLossEmptyHandTest, StickyStuckReleaseTest, WaterStickyOverlapLostTerminalTest, BridgeOverWaterTest, BridgeOverWaterStickyOverlapTest

모두 PASS 유지 필수. `register_static_body` 도입으로 StageLayoutBuilder.build() 호출 경로 변경 → phase 14~17 dev stages가 정상 build·plays 검증.

### 9.3 에디터 수동
- **basher_wall_test.tscn** 에디터 실행 → ant가 wall 만나면 basher hotkey(1) → 4 cell 통과 + candy 도달 + home 회수 시각 확인
- **digger_pillar_test.tscn** → ant가 pillar 위에서 digger hotkey → 자유 낙하 + 하단 floor 안착 + candy 도달
- **basher_digger_chain_test.tscn** → ant_B digger 적용 → ant_A가 cell 위 진입 시 자연 fall

---

## 10. Strict acceptance (§0.2 5조 — phase 16 패턴 답습)

> 각 조항은 codex/self-review가 어디를 잡을지 미리 차단. plan 본문 변경 시 본 조항 갱신 필수.

1. **No silent cell-kind divergence + backward compat (M-self-1)**
   - `register_static_body(cell, body, "earth")` 호출 후 `_cell_kind[cell] == "earth"` AND `_static_occupancy.has(cell)` AND `_static_bodies[cell] == body`. 셋 중 하나라도 false면 build 실패.
   - `add_tile(cell)` true 반환 후 `_cell_kind[cell] == "earth"` AND `_placed.has(cell)`. plan §3 add_tile 본문 끝 1줄 추가가 빠지면 동적 발판이 destroy 대상 X (BasherTunnelThroughWallTest는 정적 wall만 검증 — 회귀 검출은 BridgeOverWaterTest 변형 deferred 또는 sweep).
   - **backward compat**: 기존 StageLayoutBuilder.build() 호출 경로(register_static_cell만 호출)에서 register_static_body로 교체 시에도 _static_occupancy 등록 invariant 유지 — register_static_body 내부에서 register_static_cell을 호출하므로 D8 first-place wins(add_tile reject 분기)가 phase 14~17 dev stages에서 그대로 동작. 회귀 검출은 §9.2 phase 14~17 essential 헤드리스 PASS (BridgeRejectStageCellTest 포함 — 정적 cell 위 Bridge add_tile 거부 검증).

2. **No partial destruction (atomic)**
   - `destroy_tile_at` 본문은 kind 검사를 가장 먼저 수행. kind 미통과 시 어떤 erase/queue_free도 X.
   - kind 통과 후에는 dynamic + static body queue_free + 4개 registry(`_placed`/`_static_bodies`/`_static_occupancy`/`_cell_kind`) 모두 erase. 중간 실패 분기 없음 (try/catch 0건).
   - 검증: TerrainDestroyTileApiTest의 (5) atomic 검증 — false 반환 케이스의 사전/사후 snapshot 비교.

3. **No chain reaction**
   - `destroy_tile_at(cell, allowed_kinds)` 본문 내 인접 cell(`cell ± Vector2i.{LEFT,RIGHT,UP,DOWN}`) 검색·접근 0건.
   - WorkerState basher/digger도 target = body_cell + (dir, 0) 또는 + (0, 1) 단일 cell 계산만. 추가 cell 처리 0건.
   - 검증: BasherEdgeStopTest의 (3) "wall 외 cell의 kind 무변동" — 5개 sample cell의 사전/사후 kind 비교.

4. **No first-tick fall-through bypass**
   - `_update_digger`의 첫 호출에서 ant가 floor 위에 있을 때만 destroy. off-floor 시 destroy skip (`if not is_on_floor: return`). 첫 tick 떨어지는 ant가 cell 제거하는 race 차단.
   - `_update_basher`의 첫 호출에서 off-floor 시 즉시 `_aborted = true` → FallerState 전이. 절벽 끝 basher 활성화의 silent destroy 차단.
   - 검증: DiggerVerticalTunnelTest의 (3) ant_state 전이 sequence + 명시적 off-floor frame counting.

5. **No phase-19 leakage**
   - Basher/Digger는 `destroy_tile_at(cell, ["earth"])` 고정. allowed_kinds 매개변수 변경 X.
   - 본 phase 코드(BasherSkill/DiggerSkill/Terrain 확장/WorkerState 확장)에 "plant" 식별자 0건 (grep 0 hits 검증). plant 관련 분기는 phase 19에서.
   - StageLayoutBuilder.build()의 kind 매개변수는 "earth" 하드코딩 (StageLayoutData에 kind 필드 추가 0건). plant kind 도입 시 phase 19 plan에서 layout 확장.

6. **Digger off-floor void termination (v4 — D11, codex Round 1 H1)**
   - `_update_digger`의 off-floor 분기는 `_off_floor_frames += 1` 후 `DIGGER_OFF_FLOOR_LIMIT(=180)` 초과 시 `_aborted = true` + `FallerState.new()` 직접 전이.
   - on_floor 분기 진입 시 `_off_floor_frames = 0` reset (정상 vertical tunnel은 timeout trigger X).
   - 임계값 `DIGGER_OFF_FLOOR_LIMIT`는 코드 const로 고정 — magic number 회피. 변경 시 D11 결정 갱신 필수.
   - FallerState 직접 전이 (WalkerState 우회): 이미 falling 중이라 Walker 1-frame 우회는 낭비 + state machine race 회피.
   - 검증: DiggerFallThroughUpperAntTest PASS 기준 (1) ant_B WorkerState 유지 후 timeout, (4) FallerState 진입 frame ≥ destroy + 180 (±5 frame 오차).

---

## 11. 리스크 / 가정

| 리스크 | 영향 | 대응 |
|---|---|---|
| StageLayoutBuilder._add_cell 반환 타입 변경(void → StaticBody2D)이 _rebuild_preview 호출부 영향 | 에디터 preview 깨질 위험 | `_add_cell()` 호출만 (반환값 무캡처)으로 변경 — Godot에서 함수 반환값 무시 OK |
| register_static_body 도입으로 기존 stage build 회귀 | Stage01~03 + 모든 dev stages | phase 14~17 dev stages 회귀 헤드리스 PASS 검증 (§9.2) — register_static_body가 register_static_cell를 내부 호출하므로 _static_occupancy 등록 invariant 유지 |
| Digger 자유낙하 도중 _tick_accum 누적 폭증 | landing 직후 tick 다발 → 의도치 않은 다중 cell 즉시 파괴 | v4 — off-floor 분기에서 `_tick_accum += delta` 호출 X (tick 누적 자체 skip). landing 후에만 tick 누적. `while _tick_accum >= DIGGER_TICK` 루프도 _remaining/_aborted 가드로 자연 제한 |
| Digger off-floor 무한 잔존 (v4 — codex Round 1 H1) | hazard도 없는 void column에서 Digger ant가 영원히 WorkerState 잔존 | D11 — `_off_floor_frames` 카운터 + `DIGGER_OFF_FLOOR_LIMIT(=180 frames)` 안전망. 임계 도달 시 FallerState 직접 전이 (Walker 우회). 정상 1~5 cell drop은 1~60 frames이므로 trigger X. DiggerFallThroughUpperAntTest PASS (4)로 검증 |
| `_off_floor_frames` 임계값 180이 비현실적 stage(매우 긴 다단 vertical tunnel)에서 false-positive trigger | 의도된 긴 vertical tunnel이 timeout으로 끊김 | 임계값 180 frames(3초 @60fps)는 (a) 9.6 m/s² 중력 + cell_size=32 환경에서 약 10 cell 연속 drop도 ~120 frames 이내, (b) 12 cell DIGGER_MAX_CELLS와 정합. 더 긴 stage 필요 시 D11 임계값 갱신. MVP scope에서 false-positive 리스크 낮음 |
| Basher 절벽 끝 활성화 → off-floor 즉시 _aborted | Faller 전이로 자연 해제 — 사용자에게 silent "활성화 후 즉시 아무 동작 안 함"으로 보일 위험 | Open Decision D6에서 "wall 인접 가드 없음" 결정 — Lemmings 원작 패턴. 시각 피드백은 phase 20 polish |
| Bridge 동적 cell이 _cell_kind="earth"로 설정되면 puzzle 디자인 의도 약화 (Bridge 만든 후 Basher로 제거 가능) | 의도된 puzzle 메카닉 vs 우발적 제거 | D9 명시 결정 — Bridge·Sand-mound도 "earth"로 destructible. 의도된 puzzle 디자인 옵션. 보호 발판이 필요하면 phase 20에서 별도 kind ("indestructible" 등) 도입 검토 |
| Hazard cell이 wall의 body row에 register된 비정상 layout에서 Basher가 _aborted | dev stage 작성 시 hazard·wall 좌표 분리 필요 | D10 결정 + plan §5 표. dev_basher_wall_layout은 wall에 hazard 미배치 |

---

## 12. 산출물 요약

```
신규 (.gd):
  scripts/skills/BasherSkill.gd
  scripts/skills/DiggerSkill.gd
  tests/test_BasherSkill.gd (stub)
  tests/test_DiggerSkill.gd (stub)

신규 (.tres + .tscn):
  data/stage_layouts/dev_basher_wall_layout.tres
  data/stage_layouts/dev_digger_pillar_layout.tres
  data/stage_layouts/dev_basher_digger_chain_layout.tres
  data/stage_layouts/dev_basher_edge_stop_layout.tres (layout-only test fixture)
  data/stages/dev/basher_wall_test.tres (id=917)
  data/stages/dev/digger_pillar_test.tres (id=918)
  data/stages/dev/basher_digger_chain_test.tres (id=919)
  scenes/stages/dev/BasherWallTest.tscn
  scenes/stages/dev/DiggerPillarTest.tscn
  scenes/stages/dev/BasherDiggerChainTest.tscn

신규 (tests/):
  tests/BasherTunnelThroughWallTest.tscn/gd
  tests/DiggerVerticalTunnelTest.tscn/gd
  tests/BasherEdgeStopTest.tscn/gd
  tests/DiggerFallThroughUpperAntTest.tscn/gd
  tests/TerrainDestroyTileApiTest.tscn/gd

수정 (.gd):
  scripts/core/SkillRegistry.gd  (SKILL_SCRIPTS +2 entries)
  scripts/world/Terrain.gd       (_static_bodies + _cell_kind 필드 + 3 신규 API + add_tile +1줄)
  scripts/world/StageLayoutBuilder.gd  (_add_cell 반환 타입 변경 + build 등록 분기 교체)
  scripts/ant/states/WorkerState.gd  (basher/digger work_type 분기 + 6 신규 함수 + 4 const)

신규 (plans/):
  phases/mvp/plans/phase18-deferred.md  (D-1~D-6 박제)
```

전체 변경: 신규 14 + 수정 4 = 18 파일. count guard(100 cap) 여유 충분.

---

## 13. 변경 이력 상태

본 plan은 v10. v1→v2 self-review 변경은 §0.1, v2→v3 local consistency review 변경은 §0.2, v3→v4 codex R1 H1 fix(Option A + void/hazard termination)는 §0.3, v4→v5 codex R2 H1-R2 fix(§6.3 pseudocode 5-condition gate)는 §0.4, v5→v6 codex R3 H1-R3 fix(explicit headless quit)는 §0.5, v6→v7 codex R4 H1-R4 fix(one-shot digger application)는 §0.6, v7→v8 codex R5 H1-R5 fix + 정책 전환(§6.3 pseudocode 삭제 → contract guideline)은 §0.7, v8→v9 codex R6 H1-R6 fix(derivation 모드 제거 + Mode A/B 명시)는 §0.8, v9→v10 codex R7 H1-R7 fix(요건 3 is_on_floor() 가드 제거 — Mode A 정합)는 §0.9에 보존한다. plan-stage 정책: codex HIGH 1건 발견 시 즉시 중단 + 사용자 결정. R1→Option A→v4. R2~R4 mechanical→v5~v7. R5→정책 전환→v8. R6→mechanical→v9. R7→mechanical→v10. **v8 정책 전환 가설 검증 2회 누적 (R6, R7 모두 contract gap)**: pseudocode 박제 제거 후 plan-stage가 본래 역할(contract 검증)로 안정화. 다음 단계: codex R8 재리뷰. R8도 contract gap 패턴 유지 시 정책 안정. 코드 결함 재발 시 정책 재검토.
