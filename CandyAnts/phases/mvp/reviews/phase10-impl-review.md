# Phase 10 Implementation Review

> Target: phase 10 전체 산출 (4 atoms + 4 scenes + 2 test scenes + Tokens.gd 확장 + UI_GUIDE §3.2 갱신)
> Date: 2026-05-17
> Policy: CLAUDE.md impl-stage — codex finding HIGH/CRITICAL 1건 발견 시 수정 → self-review → clean → codex 재리뷰. codex 사이에 self-review 1회 이상 강제.

---

## 자동 검증 결과 (impl 완료 시점, 5건 전수 PASS)

| # | 게이트 | 결과 |
|---|---|---|
| 1 | tests/AtomShowcaseHeadless.tscn (신규) | PASS — 4 atoms instantiated, Counter kill guard (H-1) works, Chip set_label_value API works |
| 2 | tests/MotionPauseSafeTest.tscn (phase 9 regression) | PASS |
| 3 | tests/SvgImportSmokeTest.tscn (phase 9 regression) | PASS — 13 SVG verified |
| 4 | tests/Stage03HeadlessTest.tscn (game regression) | PASS — Phase4Test cleared score=1.0 |
| 5 | tests/BlockerOverlapTest.tscn (game regression) | PASS §B-1 ~ §B-8 전수 |

---

## Self-Review Round 1 (구현 직후 자체 적대적 리뷰, codex 전 사전 점검)

### 발견 사항

**[MEDIUM] SR1-M1 — AtomShowcaseHeadless가 private 멤버 직접 접근**
- `ctr._capop_tween`, `c._big_number.text` 등 underscore-prefixed 멤버를 테스트에서 직접 참조.
- 영향: 테스트 fragile (내부 리네임 시 깨짐). 프로덕션 영향 없음.
- 처리: 테스트 한정 의도된 introspection — 별도 getter 도입은 phase 11+의 atom 사용처가 늘 때 검토. 현재는 acknowledged 후 유지.

**[MEDIUM] SR1-M2 — SkillSlot empty/disabled의 saturate 미구현**
- UI_GUIDE §3.4: "empty (count = 0): saturate(.3) + opacity(.55) + disabled"
- 본 impl: `self_modulate.a = 0.55`만 적용 (saturation 미감산).
- 이유: saturate는 shader 필요 — atom 단위 도입은 polish phase (post-MVP 또는 phase 20 polish).
- 처리: 시각 fadedness는 alpha 단독으로 근사. UI_GUIDE는 그대로 유지 (post-MVP에서 saturate shader 도입 시 spec 부합).

**[MEDIUM] SR1-M3 — HotkeyPill font substitution (JetBrains Mono → Jua)**
- UI_GUIDE §3.4: "10px JetBrains Mono in a translucent white pill"
- UI_GUIDE §1.4: JetBrains Mono = "디버그 오버레이 전용", `assets/fonts/`에 미동봉.
- 본 impl: 기본 Jua 폰트 사용 (Theme default_font).
- 처리: 10px small text의 mono vs sans 시각 차이는 무시 가능. UI_GUIDE §3.4의 JetBrains Mono 지정과 §1.4 "디버그 전용" 충돌은 phase 10 sweep으로 §3.4 갱신 가능 (별도 commit). 본 phase 안에서는 substitution 수용.

### 정상 동작 확인 (SR1 통과 항목)
- **H-1 fix**: Counter.set_value 연속 호출 시 prior `_capop_tween.kill()` 후 새 tween 생성. AtomShowcaseHeadless가 `first_tween.is_valid() == false` 검증.
- **Sticker shadow 자식 순서**: CButton ShadowBG `show_behind_parent=true`, Counter/Chip/SkillSlot은 ShadowBG가 첫 자식(early sibling → draws below later sibling MainBG/MainPanel). UI_GUIDE §1.6 "duplicate StyleBoxFlat 레이어" 정책 부합.
- **Focus halo z-order**: SkillSlot.tscn에서 FocusHalo가 마지막 자식 → 모든 다른 자식 위에 그려짐. `_on_focus_entered`에서 visible=true. UI_GUIDE §3.4.
- **Counter pivot 동적 보정**: `_big_number.get_minimum_size() * 0.5`로 매 set_value마다 갱신 — caPop scale이 BigNumber 중앙에서 발생.
- **MainPanel transparent on Button**: SkillSlot은 Button.normal/hover/pressed/disabled/focus 5 state를 StyleBoxEmpty로 override — MainBG/ShadowBG가 시각 담당, Button는 input 담당. State 분리 명확.
- **Chip set_label_value API**: phase 10 신규 atom API freeze (UI_GUIDE §3.2도 본 phase에서 동기 갱신). atom-local pure setter (Tween/animation 부수효과 없음).
- **Empty vs disabled 구분**: empty(count=0) = clickable이지만 faded (Button.disabled=false). disabled = Button.disabled=true (input 차단). 두 state 독립 — AtomShowcaseHeadless가 `if slot.disabled` 검증.

### Verdict (Self-Review Round 1)
HIGH 0, MEDIUM 3 (모두 acknowledged + 의도된 trade-off로 처리), LOW 0. → **clean (HIGH 0)** → codex Round 1 진입.

---

## Round 1 (codex impl review)

### Verdict
**NEEDS-ATTENTION** — 0 CRITICAL, 0 HIGH, 4 MEDIUM, 2 LOW

### CRITICAL
None.

### HIGH
None.

### MEDIUM (모두 처리 — CLAUDE.md "MEDIUM은 defer 허용"이나 verdict clean 위해 본 라운드에서 모두 fix)
- **R1-M1** `scenes/ui/atoms/SkillSlot.tscn`: Icon/HotkeyPill/CountBadge/KoLabel이 MainBG의 자식으로 nested. UI_GUIDE §3.4 노드 트리는 SkillSlot 직속 자식으로 명시. 다만 hover translate (MainBG.position.y = -2)가 자식 4개를 동시에 이동시키는 의도였으므로 본 impl이 의미적으로 정확. **fix 방향**: UI_GUIDE §3.4 노드 트리를 nested 구조로 갱신 (SoT 갱신, hover translate 의미 명문화).
- **R1-M2** `scripts/ui/atoms/SkillSlot.gd:170`: `_update_visual()`이 PEACH_300을 `_selected`일 때만 적용. UI_GUIDE §3.4 state table은 pressed (unselected) 도 peach_300 명시. **fix 방향**: `_is_pressed` 플래그 추가 + `_update_visual()`에서 `if _selected or _is_pressed: bg = PEACH_300`.
- **R1-M3** `scripts/ui/atoms/CButton.gd:23` + `SkillSlot.gd:217`: `Motion.boop()` 반환 Tween 무시. 연속 click 시 tween 누적 — position base drift. **fix 방향**: atom-local `_boop_tween` 필드 + kill guard (Counter caPop와 동일 패턴).
- **R1-M4** `tests/AtomShowcaseHeadless.gd:33`: CButton boop 검증이 `pass`로만 끝나 실제 검증 없음. `get_processed_tweens()`는 비-API. **fix 방향**: M-3 후 `cb._boop_tween.is_valid()` 검증.

### LOW
- **R1-L1** `scripts/ui/atoms/SkillSlot.gd:156,178`: `_update_visual()`이 매 state 변경마다 `StyleBoxFlat.new()` 할당. **fix 방향**: _ready에서 `_armed_box`/`_selected_box` 캐싱 후 토글.
- **R1-L2** Fresh-clone에서 `class_name` 등록을 위한 `godot --headless --import` 부트스트랩 절차 미문서화. **fix 방향**: `scripts/run_test.py` 또는 CLAUDE.md에 한 줄 추가.

### 처리 (Self-Review Round 2 → Re-Self-Review)
- R1-M1 ~ R1-M4: 모두 fix (impl + UI_GUIDE §3.4 동기 갱신).
- R1-L1: fix (caching — 성능 + impl quality).
- R1-L2: fix (scripts/run_test.py에 안내 comment 추가).

(수정 후 Self-Review Round 2 결과 ↓)

---

## Self-Review Round 2 (Round 1 codex 수정 후 자체 리뷰, codex Round 2 전 사전 점검)

### 적용된 수정
| Finding | 수정 |
|---|---|
| R1-M1 | `docs/UI_GUIDE.md` §3.4 노드 트리를 nested 구조 (MainBG의 자식이 Icon/HotkeyPill/CountBadge/KoLabel) + hover translate 동시 이동 의미 + pressed selected/unselected 동일 peach_300 명문화. |
| R1-M2 | `scripts/ui/atoms/SkillSlot.gd`: `_is_pressed` 필드 + `_on_button_down/up`에서 토글 + `_update_visual()`에서 `_selected or _is_pressed` 분기. AtomShowcaseHeadless에 pressed-without-selected 검증 추가. |
| R1-M3 | `CButton.gd._on_pressed` + `SkillSlot.gd._on_button_down`에 `_boop_tween` 필드 + `is_valid() → kill()` 패턴 (Counter caPop와 1:1). |
| R1-M4 | `tests/AtomShowcaseHeadless.gd`: CButton 첫 press → `_boop_tween.is_valid()` true 검증 / 두번째 press → 첫 tween invalid + 새 tween 발급 검증 (kill guard 회귀). |
| R1-L1 | `SkillSlot._ready()`에서 `_box_armed`/`_box_selected` 캐싱. `_update_visual()`은 두 StyleBoxFlat 인스턴스를 토글 (`add_theme_stylebox_override`만 새 호출). |
| R1-L2 | `scripts/run_test.py` docstring에 "Fresh clone bootstrap" 섹션 추가 — `godot --headless --path . --import` 1회 안내. |

### 자체 적대적 리뷰 (수정 결과 대상)

**[정상] SS2-OK1** — Empty/pressed 충돌 회피: count=0 → `_on_button_down` early-return → `_is_pressed=false` 유지 → faded cream_100 (peach_300으로 안 됨). 의도된 동작.

**[정상] SS2-OK2** — Selected + pressed 합성: 이미 peach_300인 상태에서 click → 여전히 peach_300. 시각 깜박임 없음.

**[정상] SS2-OK3** — Boop kill guard: CButton 연속 click, SkillSlot 연속 button_down 모두 prior tween kill 후 재생성. position base drift 차단. AtomShowcaseHeadless가 자동 회귀.

**[정상] SS2-OK4** — StyleBoxFlat 캐싱: `_box_armed`/`_box_selected`는 phase 9 frozen `Tokens.PEACH_300`/`Tokens.CREAM_100` 상수 기반. 런타임 토큰 변경 시나리오 없음 (const). add_theme_stylebox_override는 box를 reference로 저장 — 동일 box 인스턴스 재할당 OK.

**[INFO] SS2-I1** — `AtomShowcaseHeadless`가 `slot._on_button_down()`/`._boop_tween`/`._big_number` 등 underscore-prefixed 멤버 직접 호출. test-only introspection — production atom 호출자 (phase 11 HUD)는 public 메서드 (set_count/set_selected/set_value/pressed 시그널)만 사용. 위반 X.

**[INFO] SS2-I2** — UI_GUIDE §3.4 nested 구조 갱신은 phase 10 SoT evolution. phase 11 HUD wiring 작성자는 본 nested 구조 기준으로 HUD.tscn에 SkillSlot 인스턴스화.

### 자동 검증 재실행 (R1 수정 후, 4건 PASS)
| # | 게이트 | 결과 |
|---|---|---|
| 1 | AtomShowcaseHeadless.tscn | PASS (boop kill guard 신규 검증 + pressed-without-selected 검증 포함) |
| 2 | MotionPauseSafeTest.tscn | PASS |
| 3 | Stage03HeadlessTest.tscn | PASS Phase4Test score=1.0 |
| 4 | BlockerOverlapTest.tscn | PASS §B-1 ~ §B-8 |

### Verdict (Self-Review Round 2)
HIGH 0, MEDIUM 0, LOW 0. → **clean (HIGH 0)** → codex Round 2 진입.

---

## Round 2 (codex impl review — verdict clean 확인)
(다음 codex 호출에서 채워짐)


## Round 2

verdict: NEEDS-ATTENTION

| ID | Severity | File:Line | Description | Required Fix |
|---|---|---|---|---|
| R2-M1 | MEDIUM | `scripts/ui/Motion.gd:18` | Round 1 boop kill guard is only a partial fix. `CButton.gd:26-28` and `SkillSlot.gd:228-230` kill the previous tween, then immediately call `Motion.boop(...)`; however `Motion.boop()` captures `var base := node.position` at the current interpolated position. If a second press happens before the first 120ms boop finishes, `kill()` leaves the node at its in-flight offset, the new boop captures that shifted offset as base, and the control can settle permanently drifted. The new test at `tests/AtomShowcaseHeadless.gd:30-41` verifies tween replacement/invalidity only; it does not await boop completion or assert final position. | Reset the booped node to a stable base before starting a replacement tween, or store per-atom base position and pass/restore it before `Motion.boop()`. Add a regression that rapid-presses twice, waits past the boop duration, and asserts final position equals the pre-press position for both CButton and SkillSlot/MainBG. |
| R2-M2 | MEDIUM | `docs/UI_GUIDE.md:275` | Cross-doc contract remains inconsistent for empty SkillSlot. UI_GUIDE says `empty (count = 0)` has filter `saturate 30% + α 0.55 + disabled`, but the phase plan explicitly says empty is visually grey while still clickable (`phases/mvp/phase10-ui-atoms-foundation.md:95`), and the headless test enforces `disabled=false` (`tests/AtomShowcaseHeadless.gd:114-115`). A phase 11 HUD author following UI_GUIDE could disable empty slots and diverge from the implemented count-shortage/clickable behavior. | Sync UI_GUIDE §3.4 with the implemented/plan contract: empty should be described as visually disabled-like/faded but not `Button.disabled`; activation may be ignored or routed to a count-shortage hook. Keep true `disabled` reserved for stage-end/input-lock cases. |

### 처리 (Self-Review Round 3 → Re-Self-Review)
- R2-M1: `CButton.gd`/`SkillSlot.gd`에 `_boop_base: Vector2` 필드 추가 — 첫 boop 시 capture, 후속 호출 시 kill→snap→re-capture 패턴. `_on_boop_finished`에서 `_boop_tween = null` (다음 호출은 다시 base capture). `AtomShowcaseHeadless`에 final-position regression 추가 (CButton/SkillSlot/MainBG 둘 다), prior boop 잔여 tween 완료(20 frame)까지 대기 후 baseline 캡처 (mid-bounce baseline false-positive 방지).
- R2-M2: `docs/UI_GUIDE.md` §3.4 state table에 `Button.disabled` 컬럼 추가 + empty/disabled 두 state 시각 동일하나 입력 처리 분리 (`empty=false, disabled=true`)임을 명시. phase 11 wiring 작성자 가이드 1문단 신설.

---

## Self-Review Round 3 (Round 2 codex 수정 후 자체 리뷰, codex Round 3 전 사전 점검)

### 자체 적대적 리뷰 (수정 결과 대상)
**[정상] SS3-OK1** — Drift 0 회귀: AtomShowcaseHeadless가 CButton (cb.position) + SkillSlot._main_bg.position 둘 다 baseline-vs-final equal_approx 검증. baseline은 prior tween 완료(20 frame) 후 캡처 — false-positive 차단.
**[정상] SS3-OK2** — UI_GUIDE §3.4 empty/disabled 분리 명문화 + phase 11 wiring 가이드 추가. plan과 일치, AtomShowcaseHeadless 검증 (`if slot.disabled`)과도 일치.
**[정상] SS3-OK3** — `_boop_base` 캡처 시점: `if _boop_tween and _boop_tween.is_valid()` 거짓일 때만 (= 최초 호출 또는 _on_boop_finished 후) `_boop_base = position`. 활성 tween 중에는 kill→snap. 패턴 일관.
**[정상] SS3-OK4** — `_on_boop_finished`는 `CONNECT_ONE_SHOT`. 자연 종료 1회 + tween 객체 GC. kill 시는 firing 안 됨 (Godot 명세). 안전.
**[INFO] SS3-I1** — `_boop_base`는 atom의 일시 상태 (boop 사이클 동안만 유효). 노드가 다른 위치로 이동(e.g., HUD 레이아웃 변경)되면 보호 안 됨 — 호출자가 새 위치에서 첫 boop 호출 시 자동 재캡처. 정상 시나리오에서는 무영향.

### 자동 검증 재실행 (R2 수정 후, 5건 PASS)
| # | 게이트 | 결과 |
|---|---|---|
| 1 | AtomShowcaseHeadless.tscn | PASS (boop drift regression CButton + SkillSlot 둘 다 검증 포함) |
| 2 | MotionPauseSafeTest.tscn | PASS |
| 3 | SvgImportSmokeTest.tscn | PASS — 13 SVG sanity |
| 4 | Stage03HeadlessTest.tscn | PASS Phase4Test score=1.0 |
| 5 | BlockerOverlapTest.tscn | PASS §B-1 ~ §B-8 |

### Verdict (Self-Review Round 3)
HIGH 0, MEDIUM 0, LOW 0. → **clean (HIGH 0)** → codex Round 3 진입.

---

## Round 3 (codex impl review — verdict clean 확인)
(다음 codex 호출에서 채워짐)

## Round 3

verdict: NEEDS-ATTENTION

### Summary

Round 2 behavior findings are resolved in implementation and primary SoT:
- R2-M1 boop drift is fixed in both atoms. `CButton.gd:17-18` adds `_boop_tween` + `_boop_base`; `_on_pressed()` kills any valid prior tween, snaps back to `_boop_base`, then starts `Motion.boop(self)` (`CButton.gd:25-33`). Natural completion clears `_boop_tween` (`CButton.gd:35-37`), so the next press enters the recapture path (`CButton.gd:30-31`).
- `SkillSlot.gd:53-54` uses the same pattern for `_main_bg`; `_on_button_down()` early-returns for disabled/empty (`SkillSlot.gd:223-225`), kill-snaps active boops (`SkillSlot.gd:229-235`), and `_on_boop_finished()` clears the tween (`SkillSlot.gd:243-244`).
- The rapid-press regression now captures a settled baseline and asserts final position for both `CButton` and `SkillSlot/MainBG` (`tests/AtomShowcaseHeadless.gd:42-54`, `tests/AtomShowcaseHeadless.gd:121-134`).
- R2-M2 is fixed in `docs/UI_GUIDE.md`: the SkillSlot state table now has a `Button.disabled` column (`docs/UI_GUIDE.md:268-276`), and the freeze contract explicitly separates empty/count=0 clickability from true disabled input ignore (`docs/UI_GUIDE.md:278`).

### CRITICAL
None.

### HIGH
None.

### MEDIUM
None.

### LOW

| ID | Severity | File:Line | Description | Required Fix |
|---|---|---|---|---|
| R3-L1 | LOW | `phases/mvp/phase10-ui-atoms-foundation.md:94` | Secondary phase-plan docs still say CButton boop drift needs no caller handling: "Motion.boop이 `var base := node.position` 캡처 후 매 호출 시 base로 reset ... 호출자는 추가 처리 불요." That is now stale after R2-M1: `Motion.boop()` still captures the current position (`scripts/ui/Motion.gd:16-20`), so atoms must store stable base and snap before replacement. The implementation is correct, but this doc can mislead future atom authors or phase 10 sweep readers. | Update the edge-case bullet to match the implemented contract: repeated boop callers must own a stable base, kill any valid prior tween, snap to base, then call `Motion.boop()`. Mention CButton boops self and SkillSlot boops `MainBG`. |

### Race / Hypothetical Checks

- Kill race: no blocking race found in the implementation. In both atoms, the old valid tween is killed before the new tween is assigned (`CButton.gd:27-33`, `SkillSlot.gd:229-235`). Natural completion clears `_boop_tween` (`CButton.gd:35-37`, `SkillSlot.gd:243-244`), so later presses recapture base instead of reusing stale active state.
- Hold button: acceptable. `SkillSlot._on_button_down()` starts one boop and sets `_is_pressed=true` (`SkillSlot.gd:223-236`); `_on_button_up()` only clears pressed visuals and does not kill the boop (`SkillSlot.gd:238-241`), letting the tween settle back to base.
- `set_count(0)` mid-boop: acceptable. `set_count()` only updates count/visuals (`SkillSlot.gd:88-92`); the in-flight tween can finish and clear `_boop_tween` (`SkillSlot.gd:243-244`). Later empty button_down returns before creating a new boop (`SkillSlot.gd:223-225`).
- Test wait design: `tests/AtomShowcaseHeadless.gd:44-52` and `tests/AtomShowcaseHeadless.gd:124-132` use 20 process frames. In this local shell I could not independently rerun the gate because `python`, `python3`, `py`, and `godot` are not on PATH. The test has reportedly passed in the project environment; no severity assigned beyond noting that time-based waits would be more portable than frame-count waits if the runner remains uncapped.

### Verdict

Round 2 findings all resolved in implementation and `docs/UI_GUIDE.md`. No CRITICAL/HIGH/MEDIUM remain. One LOW secondary-doc drift remains in the phase plan and is defer-allowed under the stated policy.
