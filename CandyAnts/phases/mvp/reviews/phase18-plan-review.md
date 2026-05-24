# Phase 18 Plan Review — codex adversarial-review

**Plan target**: [phases/mvp/plans/phase18-plan.md](../plans/phase18-plan.md) (v3)
**Policy**: CLAUDE.md plan-stage — CRITICAL/HIGH 1건 발견 시 즉시 중단 + 사용자 결정. 자동 재리뷰 금지.

---

## Round 1 (2026-05-24)

**Verdict**: needs-attention
**Summary**: No-ship: the Digger state contract is internally inconsistent. The implementation snippet keeps a falling digger inside WorkerState and skips earth checks while off-floor, but the required fall-through test assumes the same falling ant exits WorkerState after `_digger_below_has_earth` fails.

### Findings

#### [HIGH] H1 — Falling Digger can stay in WorkerState forever, contradicting the fall-through test contract
**Location**: phase18-plan.md:285-305, phase18-plan.md:452-454, phase18-plan.md:587-589

The `_update_digger` snippet returns immediately whenever `not a.is_on_floor()`, so a Digger that removes its current floor remains in `WorkerState("digger")` during the entire fall and never reaches `_digger_below_has_earth`. However, the `DiggerFallThroughUpperAntTest` scenario says ant_B removes cell `(10,22)`, starts falling through air, then detects that cells below are air, sets `_aborted`, exits WorkerState, enters WalkerState, and only then naturally transitions to FallerState. The strict acceptance text repeats the off-floor return rule, so the plan currently specifies two incompatible outcomes for the same sequence.

Impact: an implementation that follows the code snippet can leave a digger in WorkerState until it lands on another floor, or indefinitely if it falls into empty space. The proposed essential test either fails against the snippet or gets weakened to match the snippet, leaving the "natural fall-through" behavior unguarded. This also affects any Digger drop into hazard/void cases because the ant is not using the normal Walker/Faller transition path while falling.

**Recommendation**: Make one behavior canonical before implementation. Either:

- Digger is allowed to remain a work state while falling: update §6.3/§2.4/strict acceptance so ant_B is expected to stay in `WorkerState("digger")` until landing, and add a void/hazard termination rule so it cannot remain WorkerState forever.
- Digger should hand off to normal fall handling: change `_update_digger` so the first off-floor frame after a successful floor removal exits to `FallerState` or `WalkerState` deterministically, then adjust the vertical tunnel behavior to re-enter/reapply digging only by an explicit rule.

### Next steps (codex)

Block Phase 18 implementation until the Digger off-floor state contract is resolved and the essential test expectations are rewritten to match the chosen behavior.

---

**Status (Round 1 종료)**: HIGH 1건 발견. plan-stage 정책에 따라 여기서 중단하고 사용자 결정을 대기한다.

---

## Round 2 (2026-05-24)

**Plan version**: v4 (Round 1 H1 fix 적용 — Option A 채택 + D11 `_off_floor_frames`/`DIGGER_OFF_FLOOR_LIMIT=180` void/hazard termination 신설)
**Verdict**: needs-attention
**Summary**: No-ship — the v4 D11 fix is not actually locked by the specified regression test, so the Round 1 failure mode can survive implementation.

### Findings

#### [HIGH] H1-R2 — D11 timeout can be untested because the §6.3 pseudocode passes before checking ant_B termination
**Location**: phases/mvp/plans/phase18-plan.md §6.3 test driver pseudocode (lines ~525-527 of v4)

The `DiggerFallThroughUpperAntTest` contract (§2.4 PASS 기준 1·4)은 "ant_B는 destroy frame + 5에도 여전히 WorkerState, FallerState 진입은 destroy_frame + DIGGER_OFF_FLOOR_LIMIT 이상" 을 요구하지만, §6.3에 제시된 test driver pseudocode는 `_pass()` 호출을 `ant_a_faller_frame > cell_destroy_frame` 만으로 trigger한다. 즉 _off_floor_frames 타임아웃이 누락되거나 broken한 구현도 ant_A fall-through만 발생하면 PASS가 된다. v4가 고친 "void-WorkerState 영구 잔존" 실패 모드를 enforceable regression guard로 잠그지 못한다.

**Impact**: Implementation phase가 D11 안전망 없이 진행돼도 essential test가 그것을 잡지 못함. Round 1 H1의 근본 위험(Digger off-floor 영구 잔존)이 재발할 수 있다.

**Recommendation**: §6.3 pseudocode를 다음 4가지 관찰을 모두 충족할 때만 `_pass()`로 게이트하도록 다시 쓰기:
1. `cell_destroy_frame` 기록 완료
2. `destroy_frame + 5` 시점에 `ant_B.state` 가 여전히 WorkerState
3. `ant_B_faller_frame` 기록 완료
4. `ant_B_faller_frame >= cell_destroy_frame + DIGGER_OFF_FLOOR_LIMIT` (±5 frame 오차)
5. `ant_A_faller_frame > cell_destroy_frame` (기존 D1 검증)

위 조건 모두 충족 시에만 `_pass()`. 하나라도 위반 시 `_fail()` with explicit reason.

### Next steps (codex)

Phase 18 plan 승인 보류. §6.3 pseudocode 재작성 후 adversarial review 재실행.

---

**Status (Round 2 종료)**: HIGH 1건 발견. 사용자 결정으로 권고 채택 → plan v5에 fix 적용 (§6.3 pseudocode 5-condition gate 재작성). Round 3 트리거 대기.

---

## Round 3 (2026-05-24)

**Plan version**: v5 (Round 2 H1-R2 fix 적용 — §6.3 pseudocode 5-condition gate + add_to_group("ants") + 검증 게이트 매핑 표)
**Verdict**: needs-attention
**Summary**: No-ship — the new 5-condition gate can detect violations but does not make the headless test fail, so Round 2's D11 regression risk is still not locked down.

### Findings

#### [HIGH] H1-R3 — Gate failures only call push_error and never exit nonzero
**Location**: phase18-plan.md §6.3 pseudocode `_pass()` / `_fail()` (lines ~607-613 of v5)

§6.3 pseudocode의 `_evaluate()`는 위반된 모든 게이트를 `_fail()`로 routing하지만, `_fail()`은 `_result = -1` + `push_error` 만 수행. `_pass()`는 `_result = 1` + PASS 출력 코멘트만. 그러나 이 repo의 `scripts/run_test.py`는 scene exit code(`get_tree().quit(N)`)를 PASS/FAIL 시그널로 사용하고, 인접 헤드리스 test들은 `get_tree().quit(0)` / `quit(1)`을 호출한다. broken D11 구현이 `_fail()`을 hit해도 `_result != 0` 으로 처리만 중단하고, 명시적 종료 없이 runner의 `--quit-after` timeout에 의존 → essential regression test가 5조건 중 하나가 실패해도 implementer를 차단 못 함.

**Impact**: Round 2 H1-R2의 회귀 위험(D11 누락/오류가 essential test로 잡히지 않음)이 여전히 lock되지 않음. _pass/_fail은 internal state만 변경하고 outside-world 시그널이 없음.

**Recommendation**: `_pass()`와 `_fail()`을 다음과 같이 명시:
- `_pass() -> void`: `print("DiggerFallThroughUpperAntTest PASS"); get_tree().quit(0)`
- `_fail(reason: String) -> void`: `push_error("DiggerFallThroughUpperAntTest FAIL: " + reason); get_tree().quit(1)`

기존 헤드리스 test 패턴(`tests/*.gd`)에서 사용 중인 `get_tree().quit(N)` 패턴 답습. 모든 gate 위반이 deterministic nonzero exit code로 귀결되어 `run_test.py`가 FAIL을 잡을 수 있다.

### Next steps (codex)

Plan-stage HIGH 정책에 따라 Phase 18 plan 승인 보류. §6.3 pseudocode의 _pass/_fail을 explicit quit으로 패치 후 adversarial review 재실행.

---

**Status (Round 3 종료)**: HIGH 1건 발견. 사용자 결정으로 권고 채택 → plan v6 적용(explicit `get_tree().quit(0/1)`). Round 4 트리거 대기.

---

## Round 4 (2026-05-24)

**Plan version**: v6 (Round 3 H1-R3 fix 적용 — `_pass()`/`_fail()`에 `get_tree().quit(0/1)` 추가)
**Verdict**: needs-attention
**Summary**: No-ship — the Round 4 gate can still falsely pass because the driver may reapply Digger and hide an early WorkerState exit.

### Findings

#### [HIGH] H1-R4 — Test driver can reapply Digger every frame and mask an early WorkerState exit
**Location**: phase18-plan.md §6.3 pseudocode step (b) (lines ~556-557)

§6.3 pseudocode의 step (b):
```gdscript
if ant_b != null and elapsed >= 1.0 and ant_b.state_machine.current_state is WalkerState:
    ant_b.state_machine.change_state(WorkerState.new("digger"))
```

이 분기는 (a) one-shot guard 없음, (b) `is_on_floor()` 검사 없음. Option A를 위반한 구현(destroy 직후 WorkerState exit)이 있을 때, ant_B가 잠시 WalkerState로 떨어지는 physics-order 윈도우가 존재한다. driver가 그 윈도우 안에서 step (b)를 실행하면 WorkerState("digger")를 다시 강제 적용 → destroy+5 frame state 검사에서 ant_B가 WorkerState로 관찰됨 → criterion (2) PASS as false-positive. 5-condition gate가 Option A 위반을 못 잡는다.

**Impact**: v5/v6 fix의 핵심인 5-condition gate가 무력화. broken Option-B 구현이 essential test를 통과할 수 있어 Round 1/2의 회귀 위험이 여전히 lock되지 않는다.

**Recommendation**: Digger application을 one-shot으로 만들기:
```gdscript
var digger_applied: bool = false
# ...
if ant_b != null and elapsed >= 1.0 and not digger_applied and ant_b.is_on_floor() and ant_b.state_machine.current_state is WalkerState:
    ant_b.state_machine.change_state(WorkerState.new("digger"))
    digger_applied = true
```

위 적용 이후 driver는 ant_B의 상태 전이만 관찰. ant_B를 다시 WorkerState로 강제 진입시키지 않는다.

### Next steps (codex)

Plan-stage HIGH 정책에 따라 Phase 18 구현 보류. §6.3 pseudocode의 digger application 분기를 one-shot + on_floor guard로 패치 후 adversarial review 재실행.

---

**Status (Round 4 종료)**: HIGH 1건 발견. 사용자 결정으로 권고 채택 → plan v7 적용(one-shot digger application + is_on_floor guard + digger_applied flag). Round 5 트리거 대기.

---

## Round 5 (2026-05-24)

**Plan version**: v7 (Round 4 H1-R4 fix 적용 — one-shot digger application + on_floor guard + digger_applied flag)
**Verdict**: needs-attention
**Summary**: No-ship — Round 5 still has a HIGH false-negative risk because the test driver lets ant_B walk away from the column the assertions observe before applying Digger.

### Findings

#### [HIGH] H1-R5 — ant_B can move off column 10 before Digger is applied, invalidating the gate
**Location**: phase18-plan.md §6.3 pseudocode steps (a) + (b) (lines ~561-579)

§6.3 pseudocode는 ant_B를 0.5s 시점에 cell (10,21)에 spawn한 후 1.0s까지 0.5초간 default WalkerState로 둔다. 코드베이스의 기존 동작상 Ant._ready()는 default state = WalkerState, WalkerState는 `direction * effective_speed`로 이동, Ant.walk_speed 기본값 = 60 px/s, StageLayoutData.cell_to_world은 cell 10을 x=10*32+16=336에 배치한다. 0.5초간 ant_B는 약 30px 이동 → x=336 → x=366 → body cell floor(366/32)=11로 이동.

따라서 1.0s 시점에 digger가 적용되면 destroy 대상은 **cell (11,22)**, 그러나 test driver는 `cell_destroy_frame`을 **(10,22)** kind="" detection으로만 기록한다. 결과: (10,22)는 영원히 destroy되지 않음 → cell_destroy_frame stays -1 → 30s timeout → _fail. 정상 구현에서도 test가 fail하거나, 또는 tester가 column 가정을 약화시켜 fix → regression guard 무력화.

**Impact**: v5/v6/v7 누적된 5-condition gate + one-shot apply가 무용지물. 정상 구현이 fail하거나, assertion 약화로 Option A/D11 검증 가드 소실.

**Recommendation**:
- Spawn과 Digger 적용을 **same physics frame**에 처리 (0.5s 지연 제거), OR
- digger_applied=true 이전까지 ant_B 정지(`velocity=Vector2.ZERO` + WalkerState 진입 차단), OR
- destroy 대상 cell을 ant_B 적용 시점의 실제 body cell에서 derive (고정 (10,22) 가정 제거)

가장 단순한 fix: ant_B spawn 직후 same frame에서 digger 적용 (0.5s delay 자체를 없앰). 단 spawn 직후 ant_B의 `is_on_floor()`가 false일 수 있어 floor 안착까지 짧은 지연 필요 시 ant_B.velocity=Vector2.ZERO로 고정.

### Next steps (codex)

Plan-stage HIGH 정책에 따라 phase 18 구현 보류. §6.3 pseudocode의 ant_B 이동 race를 제거한 후 adversarial review 재실행.

---

**Status (Round 5 종료)**: HIGH 1건 발견. 4 라운드 누적 §6.3 pseudocode 코드 결함 패턴 분석 → 사용자 결정으로 **round-cycle 종결 전략 채택**: §6.3 pseudocode 박제 삭제 + 6 contract guideline 신설(Runner protocol / 5-condition gate / One-shot apply / Drift 방지 / Hard timeout / State observation). 실제 코드는 impl-stage에서 작성. plan v8 적용. Round 6 트리거 대기 — 가설: plan-stage 검증 surface 축소 → 코드 결함 라운드 차단 예상.

---

## Round 6 (2026-05-24)

**Plan version**: v8 (Round 5 H1-R5 fix + 정책 전환 — §6.3 pseudocode 삭제, 6 contract guideline 박제)
**Verdict**: needs-attention
**Summary**: No-ship — §6.3 still leaves a drift escape hatch that conflicts with the §2.4 same-frame scenario and can make the D11 PASS gate unenforceable on the intended column-10 void layout.

**패턴 변화 detected**: Round 2~5는 §6.3 pseudocode 코드 결함이었으나, Round 6는 **contract gap** — pseudocode 삭제 후 처음으로 contract logic 결함이 surface됨. 정책 전환 가설 검증됨 (round-cycle 폭증 차단 + plan-stage가 contract logic만 검증하는 본래 역할로 복귀).

### Findings

#### [HIGH] H1-R6 — Drift contract still allows target derivation instead of preventing column drift
**Location**: phase18-plan.md §6.3 contract guideline 요건 4 옵션 (c) (lines ~563-566)

§6.3 요건 4(Pre-apply drift 방지)는 "ant_B의 column 이탈 절대 금지"라고 선언하지만, 옵션 (c) "target cell을 적용 시점의 실제 body cell에서 derive" 는 drift를 막지 않고 따라간다(prevent X, follow O). impl-stage에서 옵션 (c)를 선택하고 ant_B가 column 11로 drift하면 target = (11,22)가 된다. 그러나 §6.3 layout(line 514, 518)은 column 10에만 y=27 hole을 갖고, column 11+의 하단 floor는 solid 유지 → ant_B는 column 11 column 굴착 후 column 11의 y=27 floor에 안착 → D11 timeout 경로 미발생 → §2.4 PASS criterion (4) `ant_b_faller_frame ≥ destroy + LIMIT` 위반.

**Impact**: 정상 구현이 essential test에서 fail, 또는 implementer가 D11 assertion 약화 → 회귀 가드 무력화.

**Recommendation**: 옵션 (c) 제거. 두 가지 enforcement 모드만 허용:
- **Mode A (권장)**: same-frame spawn + apply 강제 — spawn과 digger 적용을 동일 physics frame에 처리. drift window 0 frame.
- **Mode B (alternative)**: digger 적용 직전 `assert ant_b body_cell == Vector2i(10, 21)` — 불일치 시 `_fail("ant_B drifted off column 10 — H1-R5 guard")`로 즉시 종료.

이 두 모드는 column 10 target을 결정론적으로 보장. derivation 모드는 layout과 정합 차단.

### Next steps (codex)

Plan-stage HIGH 정책에 따라 phase 18 plan 승인 보류. §6.3 요건 4의 옵션 (c) 제거 + Mode A 강제 또는 Mode B assertion 명시 후 adversarial review 재실행.

---

**Status (Round 6 종료)**: HIGH 1건 발견(contract gap, pseudocode 코드 결함 X). 사용자 standing directive("네가 수정하고 재 리뷰 진행해봐")로 mechanical fix 적용 → plan v9. v8 정책 전환 효과 확인 — round-cycle pseudocode 결함 폭증 차단 ✓. Round 7 트리거 대기.

---

## Round 7 (2026-05-24)

**Plan version**: v9 (Round 6 H1-R6 fix 적용 — derivation 모드 제거, Mode A same-frame 필수 + Mode B explicit assertion만 허용)
**Verdict**: needs-attention
**Summary**: No-ship — v9 still leaves the contract internally inconsistent at the Mode A / one-shot boundary, so the essential DiggerFallThroughUpperAntTest can either deadlock before applying Digger or bypass its own guard.

### Findings

#### [HIGH] H1-R7 — Mode A same-frame apply conflicts with the mandatory one-shot `is_on_floor()` precondition
**Location**: phase18-plan.md §6.3 요건 3 vs 요건 4 Mode A (lines ~574-578)

§6.3 요건 3은 Digger 적용 전제로 `not digger_applied AND ant_b.is_on_floor() AND is WalkerState`를 요구한다. 요건 4 Mode A는 spawn 직후 same-frame digger 적용을 요구한다. 그러나 코드베이스 convention상 freshly added Ant는 first physics tick의 `move_and_slide()` 이후에야 `is_on_floor()`이 walking/falling 결정에 유의미한 값으로 안착한다. 따라서 Mode A에서 spawn 직후 step (b) 적용 시 `is_on_floor()` 결과가 비결정적 — implementer는 두 선택지에 직면:
- 요건 3 우회 → Mode A 만족하지만 R4 protection 약화
- 요건 3 준수 → 적용 defer → R5 drift 재발

essential test가 정상 구현에서 fail하거나 implementer가 가드 우회로 회귀 보호 모호화.

**Impact**: 한 라운드의 fix가 다른 라운드의 guard를 깨는 contract internal contradiction. R4/R5 회귀 보호가 race-condition으로 noised.

**Recommendation**: Mode A를 freshly spawned ant의 `is_on_floor()` 결과에 의존하지 않는 deterministic algorithm으로 정의. 또는 same-frame 적용 전 deterministic floor-settling step 추가. 예시: Mode A를 "exact floor-aligned cell에 spawn + 즉시 Digger 적용(is_on_floor() precondition 없이) + one-shot flag 유지 + 이후 reapply 금지"로 정의. is_on_floor() precondition은 Mode B의 (10,21) assertion 이후에만 reserve.

### Next steps (codex)

Phase 18 구현 보류. §6.3 요건 3과 요건 4 Mode A 정합화 후 adversarial review 재실행.

---

**Status (Round 7 종료)**: HIGH 1건 발견(contract internal contradiction, pseudocode 코드 결함 X — R6에 이어 contract gap 패턴 안정화). 사용자 standing directive로 mechanical fix 적용 → plan v10. Round 8 트리거 대기.

---

## Round 8 (2026-05-24) — **CLEAN**

**Plan version**: v10 (Round 7 H1-R7 fix 적용 — 요건 3에서 `is_on_floor()` 사전 가드 제거, Mode A same-frame과 정합)
**Verdict**: **approve**
**Summary**: No defensible plan-stage HIGH found in the v10 diff. The R7 fix removes the contradictory driver-side `is_on_floor()` precondition while preserving one-shot application, column drift prevention, post-apply observation isolation, and `_update_digger` off-floor handling as the stated safety boundary.

### Findings

**No material findings.**

### Phase 18 plan-stage codex adversarial review 종결

- **Total rounds**: 8 (Round 1 → Round 8)
- **HIGH fix 누적**: 7 (R1 H1, R2 H1-R2, R3 H1-R3, R4 H1-R4, R5 H1-R5, R6 H1-R6, R7 H1-R7)
- **Plan version 진화**: v1(초안) → v2(self-review) → v3(local consistency) → v4~v7(codex R1~R4 fix, pseudocode 시대) → v8(정책 전환: pseudocode → contract guideline) → v9~v10(codex R6~R7 contract gap fix) → R8 clean
- **정책 전환 가설 검증 (v8)**: pseudocode 박제 제거 후 R6, R7, R8 모두 contract logic만 검사 → plan-stage가 본래 역할로 안정화. 코드 결함 라운드 폭증 차단 ✓
- **다음 단계**: Phase 18 implementation 단계 진입. impl-stage codex review가 실제 코드(BasherSkill / DiggerSkill / Terrain 확장 / WorkerState 확장 / `tests/DiggerFallThroughUpperAntTest.gd` 등)를 enforce.

---

**Status (최종)**: Plan-stage clean ✓. Phase 18 implementation 진입 준비 완료.
