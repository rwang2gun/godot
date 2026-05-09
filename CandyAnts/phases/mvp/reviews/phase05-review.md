# Phase 5 Adversarial Review

- **실행 시각**: 2026-05-09 (Round 1~16, 일부 round는 codex 자체 grounding 실패로 재시도)
- **포커스**: phase 5 plan: InputRouter Autoload + InputMap + KB/Mouse SkillToolbar migration
- **scope**: working-tree
- **base ref**: c1ce663b8adfca5ab87ea4a76d26808d2f8d74ef

> **상태**: Round 16 codex 재실행 시 OpenAI usage limit 도달 (재시도 가능 시점: 2026-05-09 20:45 KST 이후). Round 15 verdict는 needs-attention (Esc → skill_cancel 단독 binding이 phase 12 stateful routing을 사전 잠근다는 HIGH). Round 16 plan 갱신은 Esc 미바인딩으로 변경 + 회귀 가드 추가 완료. **재리뷰 미실시 — 사용자 결정 필요**: (a) usage limit 풀린 후 재실행 → clean 확인 후 implementation, (b) 본 round 16 변경이 단순 (Esc 한 줄 제거 + 우클릭만 cancel)이므로 사용자가 검토 후 implementation 진행 — 단 CLAUDE.md 정책상 CRITICAL/HIGH는 clean까지 재리뷰 필수.

---

## Round 1

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the phase 5 plan forks the canonical input action vocabulary, so the migration can ship controls that do not match the documented KB/mouse and future pad/touch contracts.

Findings:
- [high] Input action IDs diverge from the canonical mapping (CandyAnts/phases/mvp/plans/phase05-plan.md:33-41)
  The plan says INPUT_MAPPING is the source of truth, but the proposed GameAction constants rename several documented actions: `skill_select_next/prev` becomes `skill_cycle_next/prev`, `cursor_target_next/prev_ant` becomes `target_next/prev_ant`, and `speed_up` becomes `speed_toggle`. The same non-canonical names are then used for InputMap entries later in the plan. Inference from the existing docs: anything implemented from this plan will emit and subscribe to action names that do not match the documented KB+mouse matrix or future pad/touch consumers, causing controls like Q/E, Tab/Shift+Tab, and speed toggle to silently fail across modules that use the canonical names.
  Recommendation: Use the exact action IDs from `CandyAnts/docs/INPUT_MAPPING.md` in `GameAction`, `project.godot` InputMap entries, tests, and consumers, or update the canonical docs and every downstream consumer in the same change with compatibility tests for Q/E, Tab/Shift+Tab, and F.

Next steps:
- Rename the planned constants/InputMap entries to match the canonical action IDs before implementation.
- Add a contract test that compares `GameAction`/InputMap action names against the documented action registry.

### Round 1 처리

INPUT_PLAN.md(2026-05-09)이 INPUT_MAPPING.md(2026-05-08)를 갱신한 newer doc + Codex 사전 리뷰 8라운드 통과 이력. INPUT_PLAN을 action-name 단일 SoT로 채택, INPUT_MAPPING.md를 v0.2로 갱신해 이름 정합. phase 5 plan SoT 참조 갱신 + contract test 명세 추가 (실제 .gd 파일은 implementation 단계에서 생성).

---

## Round 2

Verdict: needs-attention

Findings:
- [high] INPUT_MAPPING v0.2 still contains obsolete action names (CandyAnts/docs/INPUT_MAPPING.md:29) — line 29 narrative + `camera_zoom_in/out` rows + WASD reference still using legacy.
- [medium] Contract-test coverage is documented as applied but is absent — review.md claimed test added when no .gd file exists.

### Round 2 처리

INPUT_MAPPING.md 잔여 stale ID 모두 갱신 (line 29, §2.1 카메라 표, §3.2 터치, §3.3 부록 영역). review.md 표기를 "plan-stage spec 추가, .gd 파일은 implementation Step 5에서 생성"으로 명확화.

---

## Round 3

Verdict: needs-attention

Findings:
- [high] Contract test spec cannot faithfully validate the declared action registry — 25 GameAction const vs 17+3 whitelist mismatch + back_menu unbound nuance.
- [medium] KB camera controls reclassified as synthetic-only — INPUT_PLAN §4.1 says KB is InputMap.

### Round 3 처리

CAMERA_PAN/CAMERA_ZOOM/BACK_MENU를 phase 5 GameAction const에서 제거 (deferred to phase 6/12). REGISTRY를 explicit table로 재구성: `[{name, kind}]` 형태 + 22 const phase 5 + deferred 가드 추가.

---

## Round 4

Verdict: needs-attention

Findings:
- [high] Deferred camera actions still documented as KB/mouse bindings — INPUT_MAPPING.md:154-158 still lists wheel as camera_zoom InputMap, WASD as camera_pan.

### Round 4 처리

INPUT_MAPPING.md §3.3 Esc/wheel/WASD 행을 "Phase 6 도입" 명시로 갱신. §2.1 카메라 표를 phase 분류 컬럼 추가해 deferred를 명시.

---

## Round 5

Verdict: needs-attention

Findings:
- [high] Camera actions still documented as synthetic-only in plan — line 426 + project.godot note conflict with INPUT_MAPPING phase 6 split.

### Round 5 처리

phase 5 plan 핵심 결정 §2 갱신: cursor_move만 synthetic-only. camera_pan/camera_zoom은 phase 6 KB InputMap + pad synthetic 분리 명시.

---

## Round 6

Verdict: needs-attention

Findings:
- [medium] INPUT_MAPPING Appendix B still tags camera_pan/camera_zoom as `(synthetic)`.

### Round 6 처리

INPUT_MAPPING.md 부록 B를 per-device producer 표기 (Pad/Touch/K+M 셀에 `(InputMap)` / `(synthetic)` 명시) 형태로 갱신.

---

## Round 7

Verdict: needs-attention

Findings:
- [medium] GameAction registry cardinality does not match the planned phase scope (CandyAnts/phases/mvp/plans/phase05-plan.md:18-90) — prose says 22 const but const block has 21 (1 + 20).

### Round 7 처리

prose 숫자를 정확 카운트로 수정 + contract test가 prose 대신 REGISTRY.size() 기반 검증 방식으로 명시.

---

## Round 8

Verdict: needs-attention

Findings:
- [high] Phase 5 action set still has 22 entries despite the 21-action contract — INFO_TOGGLE이 추가로 들어있어 22로 재카운트 필요.

### Round 8 처리

prose를 22 (1 synthetic + 21 InputMap)로 정정. INFO_TOGGLE은 INPUT_PLAN §4.1 phase 5 항목이므로 정상 등록. contract test는 explicit allowlist + size assertion 양방향으로 강화.

---

## Round 9

Verdict: needs-attention

Findings:
- [high] InputMap-to-registry guard filters the wrong namespace — `GameAction.*` 접두 필터링은 잘못 (Godot InputMap은 소문자 ID).

### Round 9 처리

contract test step 4 갱신: `InputMap.get_actions()` 사용 + `ui_*` 접두 일괄 필터 + 명시적 legacy negative fixture (skill_select_next 등) 추가.

---

## Round 10

Verdict: needs-attention

Findings:
- [medium] InputMap/REGISTRY guard does not actually pin names to the canonical SoT — set membership만 검증 (extra typo가 양쪽에 동시 추가되면 통과).

### Round 10 처리

명시적 CANONICAL_PHASE5_SYNTHETIC + CANONICAL_PHASE5_INPUT_MAP fixture 도입. set equality 검증으로 강화.

---

## Round 11

Verdict: needs-attention

Findings:
- [high] Canonical fixture is not equal to INPUT_PLAN §4.1 — camera_pan/camera_zoom/back_menu가 §4.1에 있지만 fixture에서 누락.

### Round 11 처리

Fixture를 phase 별 partition으로 재구성: PHASE5_REGISTERED + PHASE6_DEFERRED + PHASE12_DEFERRED + POSTMVP_DEFERRED. 합집합이 §4.1+§4.2 표 행 합과 일치.

---

## Round 12

Verdict: needs-attention

Findings:
- [medium] Post-MVP fixture includes actions outside the claimed INPUT_PLAN union — minimap_toggle/cursor_priority_toggle/camera_focus_cursor가 INPUT_PLAN §4.2에 없음 (INPUT_MAPPING legacy).

### Round 12 처리

POSTMVP_DEFERRED를 INPUT_PLAN §4.2의 6 entry로 한정 (tap_drag_skill, pinch_zoom, rewind_hold, command_wheel_open, overlay_toggle, nuke). CANONICAL_TOTAL_SIZE=31 자기검증 추가.

---

## Round 13

Verdict: needs-attention

Findings:
- [high] Modifier-sensitive InputMap dispatch can turn Shift+Tab into target_next_ant — Godot 기본 `is_action_pressed`는 modifier 느슨 매치라 Shift+Tab이 plain Tab도 매치.

### Round 13 처리

`event.is_action_pressed(action, false, true)` exact_match=true로 변경 + Shift+Tab/Ctrl+R 회귀 케이스 추가.

---

## Round 14

Verdict: needs-attention

Findings:
- [medium] Global exact-match dispatch blocks modified mouse assignment — 모든 액션에 exact_match=true 적용하면 Ctrl+click이 skill_assign 미발화.

### Round 14 처리

per-action exact_match policy 도입: Tab/Shift+Tab/Ctrl+R만 exact_match=true. 마우스/skill_select 등 modifier-tolerant. Ctrl+click/Shift+1 회귀 케이스 추가. REGISTRY entry에 `exact_match: bool` 필드 추가.

---

## Round 15

Verdict: needs-attention

Findings:
- [high] Esc is cemented as `skill_cancel` before the required menu-state split exists — phase 12 game state 분기가 추가될 때 phase 5의 단독 Esc binding이 conflict 가능.

### Round 15 처리

Codex 권고 Option B 채택: phase 5에서 Esc → skill_cancel binding 제거. 우클릭만 skill_cancel. Esc는 phase 12에서 game state 분기 + back_menu InputMap 추가 + dispatch state branching 동시 도입. INPUT_MAPPING.md Esc 행 갱신. 회귀 가드: phase 5 Esc keypress가 어떤 액션도 emit 안 함을 InputRouterTest case에서 assert.

---

## Round 16 (대기 중)

OpenAI Codex usage limit (`Codex error: You've hit your usage limit ... try again at 8:45 PM`). 재시도 시점:  2026-05-09 ~20:45 KST. 본 round 변경분이 단순 (Esc 한 줄 제거 + 회귀 케이스 추가)이라 needs-attention 해소 가능성 높음.

---

## Self-Review Round 1 (2026-05-09)

CLAUDE.md에 새로 도입된 "codex 라운드 사이 자체 적대적 리뷰 사이클" 정책 적용. codex round 15 이후 plan 갱신본을 codex와 동일 기준으로 자체 검토.

### Findings (자체)

**[HIGH] N: Fixture가 INPUT_PLAN §4.1 SoT가 아니라 plan 자체가 partition SoT인데 plan은 §4.1을 SoT로 표기 (CandyAnts/phases/mvp/plans/phase05-plan.md:300)**
- INPUT_PLAN §4.1은 MVP 전체 액션을 한 표로 나열, "phase" 컬럼 없음. 어떤 액션이 phase 5인지의 결정은 plan 작성자가 한 partition decision.
- plan 표기 "INPUT_PLAN §4.1을 phase별로 split"는 §4.1이 partition SoT인 것처럼 오해 유발.
- 다음 phase에서 fixture migration 시 "INPUT_PLAN을 보고 갱신"하면 partition 정보 부재로 결정 못 함 → 잘못된 갱신 위험.

**[HIGH] O: REGISTRY와 CANONICAL_*_fixture circular SoT 미명시 (CandyAnts/phases/mvp/plans/phase05-plan.md:300-338)**
- contract test가 REGISTRY(GameAction.gd)와 fixture(GameActionContractTest.gd) 일치를 검증하는데, 둘 다 같은 정보를 하드코딩.
- GDScript는 class const reflection 불가라 회피 불가. 그래서 contract test가 silent drift 차단.
- 어느 게 1차 SoT인지 plan에 명시 없음 → 미래 implementer가 한 곳만 갱신하고 다른 곳 빠뜨릴 가능성.

**[MEDIUM] A: SkillToolbar Button.pressed 직접 경로와 SKILL_SELECT_n action 경로 이중 dispatch가 의도임을 plan에 명시 부족**
**[MEDIUM] G: payload 키 컨벤션 불일치 (`world_pos` vs `from_world_pos`) — 위치 동반 액션 4종에 통일 컨벤션 부재**
**[MEDIUM] J+K+Q: dead branch 3건 (touch/joypad InputEvent 분기 + CURSOR_MOVE _emit_positional 분기) — phase 5에서 100% dead, 다음 phase에서 첫 활성 시 검증 0**
**[MEDIUM] I: UI Control vs InputRouter 입력 우선순위가 검증 안 된 가정**
**[LOW] R8 후 처리에서 22 vs 21 핑퐁이 plan 본문에 회귀 가능 (size hardcode 분산)**

### 처리 (Round 1)

- **HIGH N+O 처리**: canonical fixtures 블록 헤더를 SoT 명시 형태로 갱신. "이름 SoT = INPUT_PLAN", "partition SoT = plan fixture 자체", "code SoT = REGISTRY (fixture는 mirror)" 3계층 명시. circular SoT는 GDScript reflection 한계로 회피 불가하다는 사실 + contract test가 drift 차단 정책 명문화.
- **MEDIUM A·G·J·K·Q·I**: 각각 plan-stage에서는 implementation에 위임. impl-review에서 다시 검증.
- **LOW**: deferred — phase 5 implementation 후 contract test가 size를 derive하므로 prose 잔존 hardcode가 contract와 어긋나면 즉시 fail.

### 자체 재리뷰 (Round 1 결과 검증)

위 처리 후 plan을 다시 가혹하게 살펴본 결과:
- HIGH N+O fix는 SoT 3계층을 명시했으니 partition decision의 출처와 code-fixture circular reference 사실이 plan에서 발견 가능.
- 새 HIGH 발견 없음.

**자체 리뷰 verdict: clean** (HIGH 0건). codex round 16 재실행 자격 획득.

---

## Round 16

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the Esc removal is not actually clean; the phase 5 plan and mapping still contain executable-looking instructions that can reintroduce the exact Round 15 binding conflict.

Findings:
- [high] Stale Esc specs can re-bind Esc to skill_cancel in phase 5 (CandyAnts/phases/mvp/plans/phase05-plan.md:386)
  The plan now says phase 5 leaves Esc unbound, but the same plan still specifies an InputRouter test case named "Esc -> skill_cancel emit" and later states Esc is a single skill_cancel mapping. INPUT_MAPPING also still lists `skill_cancel` as `right-click / Esc (InputMap)` in Appendix B. An implementer following these sections can add an Esc InputMap binding or write the wrong regression, contradicting the new zero-action Esc guard and prematurely cementing the phase 12 skill_cancel/back_menu split.
  Recommendation: Remove or rewrite every phase 5 Esc->skill_cancel instruction: delete the stale case-C, update the later decision text that says Esc=skill_cancel, and fix INPUT_MAPPING Appendix B so phase 5 K+M for `skill_cancel` is right-click only while Esc is explicitly phase 12-only.

Next steps:
- Re-run the review after the stale Esc references in phase05-plan.md and INPUT_MAPPING.md are made consistent with the phase 5 zero-action Esc contract.

### Round 16 처리

stale Esc 잔재가 plan 5곳 + INPUT_MAPPING 2곳 남아있음을 확인. Round 15 정책(phase 5 Esc 미바인딩, 우클릭만 skill_cancel)을 모든 잔재에 일관 적용:

**phase05-plan.md 수정**:
- L140 (exact_match=false 액션 목록): `skill_cancel (우클릭/Esc)` → `skill_cancel (우클릭)` + Esc 주석 제거
- L386-388 (InputRouterTest case-C): "Esc → skill_cancel emit" → "Esc → 무 발화 검증 (회귀 가드)"로 재작성. payload 0회 + EventBus.action_triggered 발화 0건 assert.
- L491-497 ([Esc] flow 블록): 통째로 제거하고 phase 5에서 Esc는 InputMap 미등록임을 한 줄 주석으로 대체.
- L533 (info_toggle 결정): `Esc=skill_cancel 단일 매핑` → `phase 5에서 skill_cancel은 우클릭 단일 매핑, Esc는 미바인딩 (phase 12 game state 분기 도입 시 Esc → skill_cancel/back_menu routing 동시 추가)`.
- L546 (edge case 8b): 새 case-C로 통합되었음을 명시 (위치만 보존, 내용은 case-C 참조).
- L590 (수동 검증 step 3): `Esc로 pending cancel` → `우클릭으로 pending cancel`.
- L637 (리스크 표): "Esc binding이 skill_cancel과 미래 back_menu 둘 다 매칭" 행 → "phase 12에서 Esc binding 도입 시 game state 분기 필요" (phase 5는 미바인딩이라 본 phase 영향 0).

**INPUT_MAPPING.md 수정**:
- L154 (§3.3 K+M 표 우클릭 행): `phase 5 InputMap (Esc와 동일 액션)` → `phase 5 InputMap (우클릭만, Esc는 phase 12)`.
- L353 (Appendix B `skill_cancel` 행 K+M): `우클릭 / Esc (InputMap)` → `우클릭 (InputMap, phase 5) — Esc는 phase 12에서 추가`.

Round 16 fix 완료. 자체 적대적 리뷰 round 2로 진입.

---

## Self-Review Round 2 (2026-05-09)

Round 16 codex finding 처리 후 plan + INPUT_MAPPING을 codex와 동일 기준으로 자체 가혹 검토.

### 검사 범위

- phase05-plan.md `[Ee]sc|skill_cancel|SKILL_CANCEL|back_menu` 전수 grep 결과 19건 일관성 확인
- INPUT_MAPPING.md 동일 grep 결과 6건 일관성 확인
- 잔재 stale 특히: SkillToolbar 코드 주석(L205), 결정 #9(L538), 엣지 8b(L551), Appendix B(INPUT_MAPPING L353/366)

### Findings (자체)

**[모두 처리됨] Round 16 변경 후 발견 잔재**:
- plan L205: SkillToolbar 주석이 `InputMap "skill_cancel"이 대체`라고만 명시해 미래 reader가 Esc=skill_cancel으로 오해 가능 → "phase 5는 우클릭 → InputMap skill_cancel + Esc 미등록"으로 명시화 완료.
- INPUT_MAPPING L366: `back_menu` Appendix B K+M 셀이 `Esc (메뉴 오픈 시)`만 적혀 phase 표기 누락 → `Esc (InputMap, phase 12 — 메뉴 오픈 시 game state 분기)`로 갱신 완료. (camera_pan/camera_zoom 행이 `phase 6` 명시한 것과 동일 패턴.)

**Cross-doc consistency 검증**:
- phase 5 Esc 미바인딩 정책이 (a) plan 결정 #8 (L550), (b) plan 엣지 케이스 8b (L551), (c) plan InputRouterTest case-C (L386), (d) plan 리스크 표 (L642), (e) plan 흐름도 [Esc] 블록 (L492), (f) plan SkillToolbar 코드 주석 (L205), (g) INPUT_MAPPING §3.3 우클릭 행 (L154), (h) INPUT_MAPPING §3.3 Esc 행 (L170), (i) INPUT_MAPPING Appendix B `skill_cancel` 행 (L353), (j) INPUT_MAPPING Appendix B `back_menu` 행 (L366) — **10곳 모두 일관**.
- phase 12 도입 시점 표기도 "game state 분기와 함께 skill_cancel/back_menu 양 binding 동시 추가"로 통일.

**Hypothetical 위험 재검토**:
- 미래 phase 12에서 Esc binding 도입 시 case-C 테스트 update 누락 가능성? → 엣지 8b가 case-C와 contract 동기화 명시했으므로 grep으로 발견 가능. defer.
- back_menu가 INPUT_MAPPING §1 액션 표(L79)에 있는데 plan 결정 #9는 phase 5 const 미등록이라고 함 → 일관(액션 정의는 docs SoT, phase 5 const만 미포함). 결정 #9가 explicit이라 silent drift 위험 없음.
- 우클릭 단일 cancel이 사용자 학습 곡선에 부담? → phase 12 만들 때까지 임시. INPUT_MAPPING §3.3에서 사용자 가시 — Esc 행에 phase 12 도입 명시. UX 결정은 phase 12 menu work에서 다시 검토.

**Dead branch 재검사** (round 1 자체리뷰 MEDIUM J+K+Q):
- Esc 처리 dead branch가 phase 5에 추가되지 않았는지? → plan에서 Esc는 InputMap 미등록 + GameAction const 미등록 (BACK_MENU 미정의) → 어떤 dead branch도 안 만듬. 정상.

### 자체 verdict: clean

HIGH 0건. cross-doc 10곳 일관 + dead branch 신규 0 + hypothetical 위험 모두 phase 12로 명시 deferred + grep contract로 미래 update 강제. codex round 17 재실행 자격 획득.

---

## Round 17

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the stale Esc binding was removed from the phase plan and INPUT_MAPPING, but the canonical INPUT_PLAN still preserves the conflicting Esc contract and can drive the implementation back to the Round 15 failure.

Findings:
- [high] INPUT_PLAN still makes Esc a skill_cancel/back_menu binding source (CandyAnts/docs/INPUT_PLAN.md:183-193)
  `INPUT_PLAN.md` still lists `skill_cancel` as right-click/Esc and `back_menu` as Esc in the action table. The same stale contract also appears later as separate Esc mappings and a manual check for Esc cancel. Inference: an implementer using INPUT_PLAN §4.1/§5 as the implementation source can add the phase 5 Esc InputMap binding despite phase05-plan case-C requiring Esc to emit zero actions. That reintroduces the premature phase 12 state-routing conflict and makes the cross-doc contract unsafe.
  Recommendation: Update INPUT_PLAN so Esc is explicitly phase-12-only for both `skill_cancel` and `back_menu`, and rewrite the later Esc cancel/manual-verification snippets to match the phase 5 zero-emit guard or mark them as phase 12 work.

Next steps:
- Fix INPUT_PLAN Esc references, then re-run the stale-reference grep across phase05-plan, INPUT_MAPPING, and INPUT_PLAN.

### Round 17 처리

자체 리뷰 round 2가 plan + INPUT_MAPPING은 봤지만 INPUT_PLAN.md 잔재를 미발견 (이름 SoT는 INPUT_PLAN인데 phase 분기 표기 SoT는 plan에만 있다고 가정). codex가 더 정확.

**INPUT_PLAN.md 수정** (§4.1 표 + §4.1 디바이스 분기 paragraph + §5.4 엣지 4 + §5.6 검증 step 5):
- L183 (`skill_cancel` 행 K+M): `우클릭 / Esc` → `우클릭 (InputMap, phase 5) / Esc (InputMap, phase 12 — game state 분기와 함께)`.
- L193 (`back_menu` 행 K+M): `Esc (메뉴 상태 / 또는 인게임에서 pending 없음)` → `Esc (InputMap, phase 12 — 메뉴 상태 / 또는 인게임에서 pending 없음)`.
- L222 (Pad B 더블 액션 paragraph): `skill_cancel(우클릭/Esc), restart_stage, back_menu` → `skill_cancel(우클릭 phase 5 / Esc phase 12), restart_stage, back_menu(Esc phase 12)`.
- L234-236 (KB+Mouse 측 별도 InputMap 액션 list): 3행 모두 phase 표기 추가.
- L452 (엣지 케이스 4): "Esc가 메뉴 열기와 skill_cancel 둘 다" — phase 12 시점 엣지로 명시 + phase 5는 Esc 미바인딩 → 어떤 액션도 발화 안 함 회귀 가드 명시.
- L478 (§5.6 검증 step 5): `Esc로 cancel` → `우클릭으로 cancel (Esc는 phase 5에 미바인딩)`.

이제 docs 3종(plan + INPUT_MAPPING + INPUT_PLAN) Esc/skill_cancel/back_menu 표기 모두 일관: phase 5 = Esc 미바인딩 + 우클릭 단일 skill_cancel, phase 12 = Esc → game state 분기 routing 도입.

자체 적대적 리뷰 round 3로 진입.

---

## Self-Review Round 3 (2026-05-09)

Round 17 codex finding 처리 후 docs 3종을 grep contract 기준으로 재검사.

### 검사 명령

```
rg -n "[Ee]sc|skill_cancel|SKILL_CANCEL|back_menu" phases/mvp/plans/phase05-plan.md docs/INPUT_MAPPING.md docs/INPUT_PLAN.md
```

### 결과

**phase05-plan.md** (19건): 모두 phase 5=Esc 미바인딩 + 우클릭만 skill_cancel, phase 12=Esc → state 분기 routing 도입과 일관.
**docs/INPUT_MAPPING.md** (6건): §3.3 우클릭+Esc 행 + Appendix B `skill_cancel`+`back_menu` 행 모두 phase 표기 통일.
**docs/INPUT_PLAN.md** (10건): §4.1 표(`skill_cancel`/`back_menu` 행) + §4.1 디바이스 분기 paragraph + §4.1 KB+Mouse 측 list + §5.4 엣지 4 + §5.6 검증 5 모두 phase 표기 일관.

**Cross-doc consistency 매트릭스** (phase 5 시점 Esc 정책):
| 문서 | 위치 | 표기 | 일관 |
|---|---|---|---|
| plan | L140 (exact_match=false 액션) | "skill_cancel (우클릭만 — Esc는 phase 12)" | ✓ |
| plan | L205 (SkillToolbar 주석) | "Esc는 phase 5 InputMap에 미등록(phase 12 추가)" | ✓ |
| plan | L277-278 (project.godot InputMap entry) | "Esc는 phase 12... phase 5에서 Esc 미바인딩" | ✓ |
| plan | L293 (back_menu deferred 결정) | "Phase 5에는 Esc 미바인딩, 우클릭만 skill_cancel" | ✓ |
| plan | L386-389 (InputRouterTest case-C) | "Esc → 무 발화 검증, 발화 0회" | ✓ |
| plan | L494-496 ([Esc] 흐름도) | "InputMap에 Esc 미등록 → 매칭 없음 → emit 0" | ✓ |
| plan | L538 (결정 #9) | "phase 5 skill_cancel 우클릭 단일 + Esc 미바인딩" | ✓ |
| plan | L550 (엣지 8) | "우클릭만 skill_cancel (Esc는 phase 5에 미바인딩)" | ✓ |
| plan | L551 (엣지 8b) | "case-C가 본 엣지 케이스 강제" | ✓ |
| plan | L595 (수동 검증 step 3) | "우클릭으로 pending cancel" | ✓ |
| plan | L642 (리스크 표) | "Phase 5는 Esc 미바인딩, 본 phase 영향 0 (case-C 가드)" | ✓ |
| INPUT_MAPPING | L154 (§3.3 우클릭) | "phase 5 InputMap (우클릭만 — Esc는 phase 12)" | ✓ |
| INPUT_MAPPING | L170 (§3.3 Esc) | "Phase 12 도입... Phase 5에는 미바인딩" | ✓ |
| INPUT_MAPPING | L353 (Appendix B skill_cancel K+M) | "우클릭 (InputMap, phase 5) — Esc는 phase 12" | ✓ |
| INPUT_MAPPING | L366 (Appendix B back_menu K+M) | "Esc (InputMap, phase 12 — game state 분기)" | ✓ |
| INPUT_PLAN | L183 (§4.1 skill_cancel) | "우클릭 (InputMap, phase 5) / Esc (InputMap, phase 12)" | ✓ |
| INPUT_PLAN | L193 (§4.1 back_menu) | "Esc (InputMap, phase 12)" | ✓ |
| INPUT_PLAN | L222 (§4.1 디바이스 분기) | "skill_cancel(우클릭 phase 5 / Esc phase 12)" | ✓ |
| INPUT_PLAN | L234-236 (KB+Mouse 별도 list) | 3행 모두 phase 표기 추가 | ✓ |
| INPUT_PLAN | L452 (§5.4 엣지 4) | "phase 12 시점 엣지... Phase 5에서는 Esc 미등록 → 어떤 액션도 발화 안 함" | ✓ |
| INPUT_PLAN | L478 (§5.6 검증 5) | "우클릭으로 cancel (Esc는 phase 5에 미바인딩)" | ✓ |

총 22곳 cross-doc 일관 (plan 11 + INPUT_MAPPING 4 + INPUT_PLAN 7).

### Findings (자체)

새 HIGH/CRITICAL 0건. dead branch 신규 0. circular SoT 위험 무 (3 docs 모두 같은 정책 명시 → drift 시 grep으로 즉시 발견).

### 자체 verdict: clean

codex round 18 재실행 자격 획득.

---

## Round 18

# Codex Adversarial Review

Target: working tree diff
Verdict: approve

Ship review clean for the requested Esc-binding concern. I found no remaining doc/spec source in the reviewed HEAD working tree that permits a phase 5 Esc binding; the surviving Esc references are explicitly phase 12 or zero-emit guards.

No material findings.

### Round 18 결과

**plan-stage 적대적 리뷰 완료 — verdict=approve**. phase 5 implementation 진입 자격 획득.

총 round 통계:
- codex rounds: 18 (Round 1-15 본 round, Round 16-17 stale 잔재 fix, Round 18 final approve)
- self-review rounds: 3 (Round 1 SoT 3-tier, Round 2 plan+INPUT_MAPPING grep, Round 3 INPUT_PLAN 추가 grep)
- 총 자체 리뷰 사이클: 3회 (codex round 사이 1회씩 + 마지막 1회)
- 정책 commit: 4a8bbbc (자체 리뷰 사이클 도입)

다음 단계: phase 5 implementation (plan §변경/추가 파일대로 작성 → 회귀 테스트 → impl-stage adversarial-review 사이클 → execute.py complete 5).



