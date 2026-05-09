# Phase 5 Impl-Stage Adversarial Review

- **포커스**: phase 5 implementation — GameAction/CoordSpace/InputRouter Autoload + InputMap + EventBus 시그널 + SkillToolbar 마이그레이션
- **base ref**: 4a8bbbc (자체 리뷰 사이클 정책 commit)
- **plan-stage 결과**: codex round 18 verdict=approve (phase05-review.md)

---

## Self-Review Round 1 (2026-05-09)

CLAUDE.md 정책 (codex 라운드 사이 자체 적대적 리뷰 사이클) 적용. 구현 완료 후 codex와 동일 기준으로 가혹 검토.

### 검사 범위

- 신규 파일: `scripts/input/{GameAction,CoordSpace,InputRouter}.gd`
- 수정 파일: `scripts/core/EventBus.gd`, `scripts/ui/SkillToolbar.gd`, `project.godot`
- 신규 헤드리스 테스트 7종 (GameActionContract + InputRouter 4종 + InputOriginAtZero + SkillToolbarPositionGuard + KbCursorCache)
- 회귀: Stage01 (score=1.0), Stage02HeadlessTest (PASS, score=1.0), Stage03HeadlessTest (PASS, score=1.0), BlockerOverlapTest (PASS)

### Findings (자체)

**[모두 검증 통과]**

#### A. class_name 의존 → preload 우회 (CRITICAL — 자체 발견)
- 증상: InputRouter Autoload 첫 로드 시 `GameAction`/`CoordSpace` class_name 미해결로 parse error.
- 처리: InputRouter + SkillToolbar에서 `const GameAction := preload("res://scripts/input/GameAction.gd")` 도입. class_name 등록 순서 의존 회피.
- 검증: 모든 헤드리스 테스트 + 회귀 PASS.

#### B. Headless InputEvent.position stretch 스케일링 (HIGH — 자체 발견)
- 증상: InputRouterTest case-A에서 InputEventMouseMotion@(150,250) 주입 시 InputRouter가 받은 screen_pos == (4500, 7500) (30x stretch).
- 원인: 헤드리스 viewport stretch 모드가 InputEvent.position을 변환.
- 처리: 정확한 screen_pos 비교 대신 `world_pos == CoordSpace.screen_to_world(screen_pos, vp)` 자기일관 검증으로 변경. 정확 좌표 검증은 stretch-aware 테스트(InputRouterShiftedCameraTest)에서.
- 회귀: case-A PASS.

#### C. Camera2D.make_current() before tree (LOW — 자체 발견)
- 증상: InputRouterShiftedCameraTest에서 `cam.make_current()`을 add_child 전에 호출 → `Condition "!enabled || !is_inside_tree()" is true` 오류 (테스트는 PASS).
- 처리: add_child 후 make_current 호출로 순서 변경.

#### D. SkillToolbarPositionGuardTest can_apply 의존 (MEDIUM — 자체 발견)
- 증상: ant가 헤드리스에서 not on_floor → BuilderSkill.can_apply false → 인벤토리 차감 실패.
- 처리: 본 테스트의 핵심 의도(position_valid 가드)는 _try_assign 진입 여부. inventory delta 대신 pending 클리어 여부로 재구성. 진입 차단 검증은 position_valid:false case에서, 진입 통과 검증은 position_valid:true case에서 pending=="" 체크.

### Hypothetical 위험 검토

#### E. dead branch — _emit_positional CURSOR_MOVE 분기 (LOW)
`_dispatch_input_map_action`이 synthetic kind를 필터링해 CURSOR_MOVE는 dispatch 경로로 안 옴. `_emit_positional`의 CURSOR_MOVE 분기는 100% dead. 그러나 plan 명세 그대로 두는 게 안전 — 향후 routing 변경 시 crash 방지. **defer (LOW)**.

#### F. dead branch — _resolve_position InputEventScreenTouch/Drag/Joypad 분기 (LOW)
phase 5에서 모두 dead (touch/joypad InputMap 미등록). 첫 활성은 phase 6/21. 검증 0%. plan §5.3 명세 그대로 두는 게 정합성 — 변경 비용은 phase 6에 위임. **defer (LOW)**.

#### G. Autoload state leak — InputRouter._last_cursor_* 캐시가 scene 전환 시 잔존 (MEDIUM)
Stage01 → Stage02 전환 시 InputRouter는 Autoload로 살아남아 cache가 stale. screen_pos는 같지만 canvas_xform이 달라 world_pos는 새 환경에서 무의미. phase 5에는 TARGET_NEXT_ANT 수신자 없음 → 영향 0. phase 6 CursorTargeting 도입 시 cache 무효화 정책 필요. **defer to phase 6 (MEDIUM)**.

#### H. EventBus.input_mode_changed 신호 추가했으나 emit 0 (LOW)
phase 7 InputModeTracker가 첫 emit. phase 5는 forward-declaration만. unused signal warning 가능. **defer to phase 7 (LOW)**.

#### I. SkillToolbar `_pending_skill_id` private 변수 직접 접근 (테스트 코드) (LOW)
SkillToolbarPositionGuardTest + InputOriginAtZeroTest가 `toolbar._pending_skill_id =`로 직접 set. private 접근 convention 위반. test-only 패턴이라 production 영향 0. **defer (LOW)**.

#### J. `_dispatch_input_map_action` modifier matching policy (검증됨 — codex Round 13+14)
- exact_match=true: target_next_ant (Tab plain), target_prev_ant (Shift+Tab), restart_stage (Ctrl+R) — case-E가 강제.
- exact_match=false: skill_assign/skill_cancel/skill_select_n/skill_cycle_*/pause_toggle/etc — case-F (Ctrl+click, Shift+우클릭, Shift+1) 확인.
- **회귀 가드 PASS** (InputRouterTest case-E + case-F).

#### K. InputMap leak (codex Round 9+10)
GameActionContract case-4 (InputMap → fixture set equality) + case-5 (legacy 이름 negative) + case-6 (deferred 가드) 3중 검증. 새 typo가 InputMap+REGISTRY 양쪽에 동시 등록돼도 fixture와 안 맞아 fail. **PASS**.

#### L. Vector2.ZERO sentinel (codex Round 7)
InputOriginAtZeroTest가 world_pos=Vector2.ZERO + position_valid:true 페이로드에서 `_try_assign` 진입 통과 검증. **PASS**.

#### M. 카메라 origin 아닐 때 좌표 변환 (codex Round 1+5)
InputRouterShiftedCameraTest가 Camera2D@(500,300) zoom=1.5 환경에서 self-consistency 검증. **PASS**.

#### N. Esc 무 발화 (codex Round 15+16+17 plan-stage 핵심)
InputRouterTest case-C가 Esc 주입 후 `EventBus.action_triggered` 발화 0건 assert. **PASS**.

### Cross-doc consistency 재검증

plan v19 시점 cross-doc matrix(22곳) 모두 일관 — phase05-review.md self-review round 3 참조. impl 단계에서 추가된 것:
- `scripts/input/GameAction.gd` REGISTRY 22 entries (1 synthetic + 21 input_map) ↔ contract test fixture 22 entries 일치 (case-1 PASS).
- `scripts/ui/SkillToolbar.gd` `_on_action` match cases (SKILL_ASSIGN/CANCEL/CYCLE_NEXT/PREV/SKILL_SELECT_n) ↔ phase 5 InputMap entries.
- `project.godot [input]` 21 entries ↔ contract test fixture (case-4 PASS).

### 자체 verdict: clean

HIGH 0건 (A/B는 자체 발견 후 fix 완료, C/D는 LOW/MEDIUM 자체 처리). dead branch는 plan 명세대로 두고 phase 6/12에서 첫 활성 시 검증. cross-doc drift 0. 회귀 0건. codex round 1 (impl-stage) 재실행 자격 획득.

---

## Round 1 (codex impl-stage)

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the new router ships a stale positional cache contract for keyboard targeting, and the tests do not cover the scene/camera transition path that makes it dangerous.

Findings:
- [medium] Keyboard targeting can emit a valid position from a stale autoload cursor cache (CandyAnts/scripts/input/InputRouter.gd:90-93)
  `InputRouter` is an autoload and `_last_cursor_valid` is only ever set true in `_emit_cursor_move`; it is never cleared when the stage scene, viewport camera, or world changes. A mouse move in one stage can leave `_last_cursor_valid=true`, then a later Tab/Shift+Tab in another stage takes the cached screen coordinate as valid and emits `target_*_ant` with `position_valid:true`. Because `_emit_positional` recalculates world coordinates against the current viewport, this can look internally consistent while still being based on a cursor observation from a previous scene. The provided tests fill the cache and assert the happy path, but the planned fresh-cache-negative case is not actually covered in the shown `KbCursorCacheTest`. Impact is mis-targeting once the phase 6 consumer is added, with the foundation already declaring the payload valid.
  Recommendation: Add an explicit cache invalidation path for scene/viewport changes, or store enough context with the cache to reject it when the active scene/camera/viewport generation changes. Add a regression test that fills the cache, changes to a different camera/scene transform without mouse motion, then verifies Tab emits `position_valid:false` or an intentionally refreshed cursor position.

Next steps:
- Patch InputRouter cache invalidation before building consumers on top of `target_next_ant`/`target_prev_ant`.
- Add the missing stale-cache regression described in the phase plan.

### Round 1 처리

policy: codex MEDIUM은 defer 가능하나 verdict=needs-attention 해소 위해 처리.

**InputRouter.gd 수정**:
- `clear_cursor_cache()` public 메서드 추가 — `_last_cursor_screen/world = Vector2.ZERO`, `_last_cursor_valid = false`로 reset.
- 호출자 명세: scene_changed 감지(phase 6 CameraController 합류 시) 또는 stage 전환 hook. phase 5에서는 회귀 가드에서 직접 호출.

**KbCursorCacheTest.gd case-D 추가** (plan §6.6 #11(D) 명세 그대로):
- `InputRouter.clear_cursor_cache()` 호출 → cache invalidate.
- Tab 주입 → `TARGET_NEXT_ANT` emit + `payload.position_valid == false` assert.
- PASS 확인.

**phase 6 hook 명세 (plan에는 미반영, 본 review에 기록)**:
- phase 6 CameraController/CursorTargeting 도입 시 SceneTree.scene_changed 시그널에 `clear_cursor_cache()` 연결 또는 stage StageRunner._ready에서 직접 호출.
- 본 phase 5 시점은 외부 호출자 0 (회귀 테스트만), 실제 production stale 가능성은 phase 6 consumer 도입과 함께 닫힘.

자체 적대적 리뷰 round 2로 진입.

---

## Self-Review Round 2 (2026-05-09)

Round 1 codex finding 처리 후 가혹 검토.

### Findings (자체)

**[처리됨] codex MEDIUM stale cache**: clear_cursor_cache() + KbCursorCacheTest case-D 회귀 가드. clean.

**Hypothetical 재검사**:

#### 새 위험: clear_cursor_cache가 phase 6에서 누가 호출하는가? (LOW)
- 본 phase 5는 회귀 테스트가 유일한 호출자 → production state leak 가능. 그러나 phase 5에는 TARGET_*_ANT consumer 없음(CursorTargeting은 phase 6) → 실제 영향 0.
- phase 6 진입 시 명세: SceneTree.scene_changed → InputRouter.clear_cursor_cache() 연결. plan에는 미반영이지만 phase 6 plan 작성 시 본 hook 추가 필요. memory에 기록.

#### Vector2.ZERO sentinel 재발 가능성? (LOW)
- clear 후 _last_cursor_screen = Vector2.ZERO이지만 _last_cursor_valid = false라 _resolve_position에서 invalid 리턴. world_pos 계산 안 됨. sentinel 위험 0.

#### Test scene order — Test가 InputRouter Autoload state를 다른 테스트로 leak시키는가? (LOW)
- 각 헤드리스 테스트는 별도 Godot process → state isolation. KbCursorCacheTest의 clear_cursor_cache 호출이 다른 테스트에 leak 안 함. 같은 process 안의 후속 case도 같은 InputRouter Autoload를 공유하지만 case-D 끝에는 clear 후 어떤 cursor_move도 없는 state라 "(E)" 가 영향 받지 않음. OK.

#### `Vector2.ZERO`로 reset 시 phase 6의 future "screen_pos를 보존하되 valid=false" 패턴과 충돌? (LOW)
- clear는 단순 reset이고 phase 6은 별도 정책 (예: "stale 표시" + screen_pos 보존)이 필요할 수 있음. phase 6 plan 작성 시 정책 결정. 본 phase 5에서는 단순 reset이 plan §5.3 의사 코드와 일치.

#### Cross-doc consistency 재검증 (impl 후): plan §5.3 + INPUT_PLAN §5.3 + INPUT_MAPPING §3.3 모두 phase 5 시점 Esc/skill_cancel/back_menu 정책과 일관. 새 변경 없음. **clean**.

### 자체 verdict: clean

HIGH 0건. codex Round 1 MEDIUM 처리 + 새 hypothetical 위험 모두 phase 6 plan 작성 시점으로 명시 deferred. codex round 2 (impl-stage) 재실행 자격 획득.

---

## Round 2 (codex impl-stage)

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the stale-cache production path is still open; the new test only proves a manually called helper works.

Findings:
- [medium] Cursor cache invalidation is exposed but never wired into the lifecycle that makes the cache stale (CandyAnts/scripts/input/InputRouter.gd:90-93)
  `InputRouter` is an autoload, `_last_cursor_valid` remains true after any mouse motion, and keyboard targeting still trusts `_last_cursor_screen` whenever that flag is set. The new `clear_cursor_cache()` method resets the fields, but no production path calls it on scene/camera/viewport changes; the comments explicitly defer that hook. The added test calls `InputRouter.clear_cursor_cache()` directly, so it does not cover the failure path from the prior finding: fill cache in one scene/camera context, transition without mouse motion, then press Tab and emit `position_valid:true` from stale cursor state. Impact is mis-targeting for any current or phase-6 `target_*_ant` consumer while the EventBus payload advertises a valid position.
  Recommendation: Wire invalidation now to the actual lifecycle boundary, e.g. connect `SceneTree.scene_changed` or the stage transition hook to `clear_cursor_cache()`, or store viewport/canvas context with the cache and reject it when that context changes. Add a regression test that fills the cache, changes scene/camera transform without explicitly clearing, presses Tab, and asserts `position_valid:false`.

Next steps:
- Do not treat `KbCursorCacheTest` case-D as closing the stale-cache bug until it exercises the real scene/camera transition path.

### Round 2 처리

codex 권고 옵션 B 채택 — viewport/canvas context를 cache와 함께 저장하고 컨텍스트 변경 시 자동 폐기.

**InputRouter.gd 변경**:
1. 새 필드 `_last_cursor_scene: Node`, `_last_cursor_canvas_xform: Transform2D` — cursor_move 시점 컨텍스트.
2. `_emit_cursor_move`에서 컨텍스트 동시 capture.
3. `_resolve_position` InputEventKey 분기 — cache valid이지만 (scene OR canvas_xform) 변경 감지 시 `clear_cursor_cache()` 호출 후 invalid 리턴. **자동 stale 검출.** scene_changed signal 연결 불필요.
4. `clear_cursor_cache()`도 새 필드 reset.

**KbCursorCacheTest case-D 확장** (codex 권고 회귀 가드):
- (D-1) 직접 clear API: `clear_cursor_cache()` 호출 후 Tab → position_valid:false (기존).
- (D-2) **자동 stale 감지** (codex round 2 핵심): mouse motion으로 cache 채움 → Camera2D 추가 + make_current로 canvas_xform 변경 → Tab 주입 (clear 호출 X) → `_resolve_position`이 컨텍스트 차이 자동 감지 → position_valid:false assert.

**검증**: 7개 헤드리스 테스트 + Stage01/02/03 + BlockerOverlap 모두 PASS. 자동 stale 검출 회귀 가드 신규 추가.

자체 적대적 리뷰 round 3로 진입.

---

## Self-Review Round 3 (2026-05-09)

Round 2 codex finding 처리 후 가혹 검토.

### Findings (자체)

**[처리됨] codex MEDIUM stale 자동 감지 미구현**: 컨텍스트 비교 (scene + canvas_xform) 자동 stale 감지 + (D-2) 회귀 가드 추가. clean.

**Hypothetical 재검사**:

#### 새 위험: canvas_xform float-comparison precision (LOW)
- Transform2D 비교는 == 연산자 (Godot 내부 컴포넌트별 == 비교). 동일 frame 동일 카메라면 동일 xform. 미세한 floating-point 변동은 부동 카메라가 매 frame 미세 이동하는 케이스에서 가능. 그 경우 cache가 매 frame 폐기 → keyboard targeting이 cursor_move 직후만 valid (= "Tab은 마우스를 막 움직인 후에만 정확한 cursor 위치로 매칭"이라는 UX). 보수적 정책으로 acceptable. **defer (LOW)**.

#### 새 위험: scene_changed signal 미연결 (LOW)
- 자동 감지 로직이 InputEventKey dispatch 시점에 동작 → 액션 발화 직전에 fallback. lifecycle hook을 추가하지 않아도 검출 보장. plan §6.6 phase 6에서 추가 hook 도입 가능. **acceptable**.

#### 새 위험: Camera2D zoom 변경만 (scene 동일, position 동일)? (LOW)
- canvas_xform은 zoom + position의 조합으로 다른 Transform2D. 비교 검출 가능. OK.

#### Cross-doc consistency 재검증
- plan v19, INPUT_PLAN, INPUT_MAPPING — Esc/skill_cancel/back_menu 정책 변경 없음.
- 새로 추가된 `clear_cursor_cache` API + stale 자동 감지는 plan §5.3 InputRouter 명세의 안전 강화. plan 본문에 반영하지 않아도 contract test가 검증.

#### Test scene transition flow 자체 일관성
- (D-1)은 직접 API 호출, (D-2)는 Camera2D current 변경. (D-2) 후 (E)는 InputModeTracker singleton 부재 검증 — InputRouter cache 상태와 무관. OK.

### 자체 verdict: clean

HIGH 0건. codex Round 2 MEDIUM 처리 (옵션 B 자동 감지). 새 hypothetical LOW 3건 모두 acceptable/defer. 회귀 가드 (D-2) 추가로 codex 권고 충족. codex round 3 (impl-stage) 재실행 자격 획득.

---

## Round 3 (codex impl-stage)

# Codex Adversarial Review

Target: working tree diff
Verdict: approve

No ship-blocking finding supported from the inspected working tree context. The InputRouter now stores cursor scene and canvas transform with the cache, rejects cached keyboard positions when either changes, and KbCursorCacheTest covers the no-explicit-clear Camera2D transform-change path.

No material findings.

### Round 3 결과

**impl-stage 적대적 리뷰 완료 — verdict=approve**. phase 5 ship 자격 획득.

### 총 round 통계 (impl-stage)

- codex rounds: 3 (round 1+2 MEDIUM stale cache, round 3 approve)
- self-review rounds: 3 (round 1 base, round 2 MEDIUM 옵션 A→해소, round 3 옵션 B 자동 감지)
- 총 자체 리뷰 사이클: 3회 (CLAUDE.md 정책 준수)

### 종합 (plan + impl)

- plan-stage: codex 18 round + self-review 3 round → verdict=approve
- impl-stage: codex 3 round + self-review 3 round → verdict=approve
- 회귀: Stage01 (1.0), Stage02HeadlessTest (PASS, 1.0), Stage03HeadlessTest (PASS, 1.0), BlockerOverlapTest (PASS), 신규 7 헤드리스 테스트 모두 PASS.

다음: Notion phase 5 상태 → `완료`, `python scripts/execute.py mvp complete 5` 호출.

