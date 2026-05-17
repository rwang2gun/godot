# Phase 12 — Codex Adversarial Reviews

## Plan v1 — Round 1 (2026-05-17)

> Source plan: `phases/mvp/plans/phase12-plan.md` v1
> Stage: **plan** (CRITICAL/HIGH → STOP per CLAUDE.md 2026-05-09 policy)

### Verdict: STOP

### HIGH findings

**H-01** · `phases/mvp/plans/phase12-plan.md:42` · Last-stage Next visibility is internally contradictory and the planned test change masks the bug. The plan says `is_last_stage` makes Next `visible=false`, but later says cleared+last must be `visible=true, disabled=true` (`phase12-plan.md:132-134`, `:286`) and manual verification requires a grey disabled button (`:270`). The new `is_next_disabled()` contract collapses hidden and disabled into the same result (`:143-144`), replacing current direct disabled assertions in `GameFlowTest.gd:125` and `:213`.
- Risk: implementation can hide the last-stage Next button, pass GameFlowTest B/C, and still violate the visible-disabled UI contract.

**H-02** · `phases/mvp/plans/phase12-plan.md:87` · Esc/back-menu handling is deferred without a concrete dialog-local replacement. The plan says no Esc InputMap binding this phase and pushes `back_menu` wiring to phase 13 (`:294`), while the phase spec requires "modal displayed + ESC → request_menu" (`phase12-ui-stage-dialog.md:119`) and INPUT_PLAN assigns Esc `skill_cancel`/`back_menu` to phase 12 with state splitting (`docs/INPUT_PLAN.md:183`, `:193`, `:234`, `:236`, `:452`). The plan defines only CButton press handlers (`:147-157`) with no `_gui_input`/`_unhandled_input` route or test.
- Risk: keyboard/modal back behavior silently does not exist; implementers get conflicting phase ownership.

### MEDIUM findings
- `sfx_request` emit coverage is deliberately reduced to `dialog_open` only (`:215-220`, `:296`), while the phase spec still requires modal/button/counter/star emit positions (`phase12-ui-stage-dialog.md:157-158`).
- Pause-safe caPop correctness is asserted but not covered: the planned pause test checks `modulate.a` only (`:59`, `:265`), while caPop uses no `set_pause_mode` in current `Motion.gd:8` and UI_GUIDE calls out special caller responsibility for paused caPop (`docs/UI_GUIDE.md:343`).
- Cross-doc phase numbering remains confusing: UI_GUIDE and INPUT_PLAN still call StageDialog phase 11 and title/menu phase 12 (`docs/UI_GUIDE.md:415`, `docs/INPUT_PLAN.md:139-140`) while this plan is phase 12 and defers title/menu to phase 13 (`:12`).

### LOW / cosmetic findings
- `GameManager.gd` is described as "6 lines" in the plan, but the current file is longer due to print/assert lines.
- The plan references old doc line numbers textually instead of current ones in a few places.
- "Card-only fade_out" heading conflicts with the pseudocode that fades `self`.

### Positive observations
- The plan correctly preserves SceneFlow as the single orchestrator and matches existing `request_replay/request_next/request_menu` signal connections in `SceneFlow.gd:38-40`.
- It correctly avoids re-adding signals that already exist in `EventBus.gd:10-12`.
- The Scoring helper correctly matches UI_GUIDE §5.3's algorithm and handles `original_hp <= 0`.

### Decisions required (per plan-stage policy, no auto-revise)

**H-01 decision**: pick canonical behavior for the last-stage Next button.
- (a) `visible=false` (hide it)
- (b) `visible=true, disabled=true` (show grey, current GameFlowTest behavior)
- Whichever is chosen, test contract (`is_next_disabled()` vs direct `.disabled` assertions) and manual checklist must all describe the same thing.

**H-02 decision**: pick a phase owner for Esc→request_menu inside the modal.
- (a) Implement `_unhandled_input` Esc handler in StageDialog this phase + add test case + leave Esc InputMap binding to phase 13 (dialog-local only)
- (b) Implement full Esc InputMap binding + game-state dispatch this phase per INPUT_PLAN
- (c) Explicitly update INPUT_PLAN §4 and `phase12-ui-stage-dialog.md` to say phase 13 owns it, strike the phase-12 row, no Esc handling this phase


---

## Plan v3 — Round 2 (2026-05-17)

> Source plan: `phases/mvp/plans/phase12-plan.md` v3
> v2→v3 변경: SH-1 HIGH(GameFlowTest B/C 분리) + MED 3 + LOW 3 자체 적대적 리뷰 반영
> Stage: **plan** (CRITICAL/HIGH → STOP)

### Verdict: STOP

### HIGH

**HIGH** · `phases/mvp/plans/phase12-plan.md:196-206` + `:219` + `:336` · The v3 caPop "kill guard" does not actually fix the mid-dismiss race.

`_dismiss_then_emit()` stores the fade tween only in a local `var t`, connects `t.finished`, and emits the old `signal_ref` on completion. The proposed guard kills `_capop_tween` and snaps `Card.scale`, but does not store or kill the active `Motion.fade_out(self, ...)` tween, and does not disconnect its completion callback. `Motion.fade_out` continues tweening `modulate:a` to 0 (`scripts/ui/Motion.gd:40-44`). SceneFlow immediately reacts to stale `request_*` emits (`scripts/core/SceneFlow.gd:107-124`).

Failure scenario: `show_result()` arrives while a prior dismiss tween is mid-flight. The old fade finishes after the new result is shown, sets `visible=false`, resets `_dismissing`, and emits stale replay/next/menu into SceneFlow — causing an unintended stage reload, advance, or menu transition.

The kill guard as written papers over the caPop card animation race but leaves the outer fade-and-emit race fully open.

### MEDIUM

**M-1** · `phases/mvp/plans/phase12-plan.md:60` · Esc test injects directly into `StageDialog._unhandled_input` and does not validate the actual `_unhandled_input` chain with InputRouter. Current evidence is favorable (InputRouter handles only Pad B, mouse motion, and InputMap actions; SkillToolbar no longer has `_unhandled_input`; `skill_cancel` is right-mouse-only), but the test does not prove no double-consume or missed Esc in the real scene tree.

**M-2** · `phases/mvp/plans/phase12-plan.md:261` vs `:196-206` · `dialog_btn_press` ordering is specified in prose and in tests, but the canonical `_dismiss_then_emit()` pseudocode omits the `EventBus.sfx_request.emit(&"dialog_btn_press")` line entirely. Risk: implementer follows the pseudocode rather than prose, the ordering test fails, or the SFX hook lands in an inconsistent position.

### LOW

**L-1** · `:159-163` · `star_filled_count()` via `is_equal_approx(Tokens.LEMON_500)` is acceptable while stars are assigned directly from the constant. Brittle if future code uses theme-derived colors or alpha animation on the Polygon2D.

### Positive observation
- `:51`, `:134-136`, `:342` · SH-1 appears correctly fixed: last-stage cleared is visible+disabled, loss is hidden, GameFlowTest B/C assertions are split. No residual hidden/disabled coupling found in v3 text.

### Decision required
HIGH fix proposal: store fade tween in `_dismiss_tween` instance var; on new `show_result`, kill it AND disconnect the finished callback (or guard the callback with `if not _dismissing: return` to reject stale emits). MED 2건 + LOW 1건도 같은 v4 round에서 같이 처리하는 게 효율적.

---

## Plan v4 — Round 3 (2026-05-17)

> Source plan: `phases/mvp/plans/phase12-plan.md` v4
> v3→v4 변경: fade tween race HIGH double-belt (instance var + finished callback guard) + sfx 의사코드 + Esc test input chain + star color brittleness 주석
> Stage: **plan** (CRITICAL/HIGH → STOP)

### Verdict: STOP

### HIGH

**HIGH (Finding 1, A+G unverified)** · §3.2 `show_result()` step 0 + §3.3 `_dismiss_then_emit()` finished callback. The fade tween race fix depends on an unverified Godot 4 assumption: `_dismiss_tween.kill()` must not synchronously emit `finished` while `_dismissing` is still true. Godot docs say `kill()` "aborts all tweening operations and invalidates the Tween" but do not explicitly guarantee that an already-queued `finished` callback cannot run in the same frame. The guard `if not _dismissing: return` only catches stale callbacks **after** `_dismissing` is reset; if `finished` fires synchronously during `kill()` before the reset, `_dismissing` is still true and the guard does not block → stale request_* emit slips through.

### MEDIUM

**Finding 2** · §3.2 `show_result()` step 0 + `hide_overlay()` call `_enable_all_buttons()` but the method is never defined or spec'd. Only `_disable_all_buttons()` is described through usage.

### LOW

**Finding 3** · §2.4 `StageDialogEscTest` uses `Input.parse_input_event()` (valid improvement) but plan doesn't explicitly state the test instantiates full `Main.tscn` with autoloads, so InputRouter presence in headless is unconfirmed. LOW caveat.

### PASS observations
- §3.2 step 0 scale assignment after `kill()` ordering is safe (GDScript single-threaded).
- `_dismissing` guard logic direction is correct in normal flow.
- `Motion.caPop` confirmed to return `Tween`.
- `sfx_request` emit ordering internally consistent.

### Decision required
HIGH fix proposal: replace `_dismissing` bool guard with **generation counter** (`_dismiss_token: int`). `_dismiss_then_emit` captures `var token := _dismiss_token` → callback uses `if token != _dismiss_token: return`. show_result step 0 does `_dismiss_token += 1` → 옛 captured token이 invalidate → guard state-independent (kill() 즉시 finished fire해도 stale token이라 차단). MED 1 + LOW 1도 같이 처리하면 v5 cleanup.

---

## Plan v6.1 — Round 4 (2026-05-17)

> Source plan: `phases/mvp/plans/phase12-plan.md` v6.1
> v4→v6.1 변경: codex R3 fix (generation token + _enable_all_buttons + Esc test scene) + user self-review (DismissRaceTest 신설 + show_result button ordering + Esc test wording) + v6→v6.1 assistant SL-1 sync (§3.2 ↔ §5 visible 가드 표현 통일)
> Stage: **plan** (CRITICAL/HIGH → STOP)

### Verdict: CLEAN — proceed to impl

### MEDIUM
- Cross-doc residual drift — `docs/UI_GUIDE.md` lines 415, 440, 474 still describe StageDialog/Scoring/SFX hook ownership as Phase 11 while the reviewed plan is Phase 12. Similarly, `docs/INPUT_PLAN.md` lines 139-140, 183, 193, 234-236, 726 still place StageDialog or Esc InputMap binding in the old Phase 11/12 split, while the plan defers Esc InputMap to Phase 13. Documented drift, but a real coordination hazard until swept.

### LOW
- Plan-as-SoT stabilize trigger — `phases/mvp/plans/phase12-plan.md` lines 4, 449 say pointer-ize after "plan stabilize" but do not define a concrete trigger. Can cause the sweep to linger indefinitely.
- Hidden Next state after hide — `hide_overlay()` resets everything but not `_next_should_be_disabled`. Low risk because `show_result()` explicitly recalculates `_next_should_be_disabled` before enabling, overwriting any stale value.

### Key checks passed
- `_dismiss_token` capture: `var token := _dismiss_token` creates an independent local int copy (GDScript built-in types copy on assignment). The token guard is not comparing a live alias to itself. Race correctly closed.
- Branch ordering: step 5 (`_next_should_be_disabled` computation) always precedes step 6 (`_enable_all_buttons`) in all 3 branches. `_set_buttons_disabled()` preserves the `_next_should_be_disabled` contract.
- `hide_overlay()` exhaustiveness: all critical fields reset; stale `_next_should_be_disabled` is benign since `show_result()` overwrites it first.
- Race-test timing: both scenario A and B await "old fade duration" before asserting emit count.
- Esc bypass: `_unhandled_input` is gated only on `visible` and `_dismissing`, not on NextBtn disabled state. Esc correctly routes to menu unconditionally.
- `Motion.caPop` return type: `scripts/ui/Motion.gd` declares and returns `-> Tween` correctly.

### Impl 진입 결정
- MED 1건은 본 phase commit에 cross-doc sweep으로 흡수: `docs/UI_GUIDE.md` §5.3 + `docs/INPUT_PLAN.md` §3·§4의 "phase 11" → "phase 12" 1줄 패치
- LOW 1 (stabilize trigger): 본 commit이 stabilize point — frontmatter doc pointer-ize 포함
- LOW 2: benign 확인됨

Total plan rounds: 4 codex + 2 self-review = 6 round. phase 9(6)와 동급 effort. impl 진입.

---

## Impl Self-Review Round 1 (2026-05-17)

> Stage: **impl** (Self HIGH 0/MED 0 → codex 재리뷰 진입)

### 자체 점검 결과: clean

#### Code review
- `scripts/ui/StageDialog.gd`: `_dismiss_token` generation guard 정합, lambda by-value capture 안전, show_result step ordering(0 cleanup → 5 _next_should_be_disabled → 6 _enable_all_buttons → 7 visible → 8 sfx) 정확
- `scripts/core/Scoring.gd`: UI_GUIDE §5.3 1:1, `original_hp <= 0` 가드
- `scripts/core/EventBus.gd`: `sfx_request(id: StringName)` 1줄 추가, 기존 signal cluster 무손상
- `scripts/ui/HUD.gd`: deprecated `show_dialog` stub 제거 (호출자 0건 grep 확인)
- `scenes/Main.tscn`: 3 라인 갱신 (ext_resource path + node name + overlay_path NodePath) 정합
- `scenes/ui/StageDialog.tscn`: Tint enum (MINT=2/BERRY=3/LEMON=4), CButton kind (PRIMARY=0/SECONDARY=1/GHOST=2), Star1~3 + Poly 트리, Theme stylebox override 정합
- `tests/GameFlowTest.gd`: Scenario B(line 125) visible+disabled, Scenario C(line 213) visible=false — SH-1 분리 적용

#### Tests (10/10 PASS)
- ScoringStarsTest: 10 boundary case
- StageDialogShowResultTest: cleared+!last / cleared+last / loss 3분기
- StageDialogDismissTest: replay/next/menu 3 button × dismiss 흐름
- StageDialogDismissRaceTest: 시나리오 A(show_result interleaved) + B(hide_overlay interleaved) → stale request_* emit 0회
- StageDialogPauseSafeTest: paused tree에서 fade_in(pause_safe) + caPop 진행 + Replay → request_replay emit
- StageDialogEscTest: visible=false idempotency + show_result(loss) → Esc → request_menu 1회 + 다른 signal stray 0
- StageDialogSfxTest: dialog_open/dialog_stats_pop/star_fill (2 cleared, 0 loss boundary)/dialog_btn_press (3 button) 정확
- Stage02/03HeadlessTest 회귀: PASS
- GameFlowTest A/B/C 시나리오 회귀: PASS

#### LOW
- LL-1: Working tree에 level-editor WIP 혼재 — complete 직전 git stash 분리 (phase 11 lesson §7).
- LL-2: phase 9 frontmatter sot_aux path fix가 phase 12 commit에 흡수 — validate 가드 회복 차원이라 정당.

#### Codex 재리뷰 진입 결정
self-review clean → impl-stage codex `/codex:adversarial-review` 1차 호출.

---

## Codex Impl Review Round 1 (2026-05-17)

> Stage: **impl** (CRITICAL/HIGH → must fix; MED/LOW → may defer per CLAUDE.md 2026-05-09)

### Verdict: NEEDS-ATTENTION (no CRITICAL/HIGH; 3 MED + 2 LOW)

#### MEDIUM
- **M-1** · `docs/INPUT_PLAN.md:139-148` phase split table still assigns `ui-stage-dialog` to phase 11 / `ui-title-menu` to phase 12 + SFX hook note says phase 11 — v3 renumber 누락.
- **M-2** · `docs/UI_GUIDE.md:282-476` LogoPanel/StageSlotCard/lock icon/SaveData/Settings/Credits 섹션이 "Phase 12"라 하나 본 phase 12는 stage-dialog. 모두 phase 13으로.
- **M-3** · `tests/StageDialogDismissRaceTest.gd` race regression 테스트가 plan §4.1+§7 요구한 `Card.scale == Vector2.ONE` assertion 누락.

#### LOW
- **L-1** · `tests/StageDialogPauseSafeTest.gd:31-33` `Card.scale.x >= 0.9` false-green 가능. axes 둘 다 [0.97, 1.10] 범위로 정확화.
- **L-2** · `tests/StageDialogSfxTest.gd:63-83` `dialog_btn_press` ordering vs request_* 검증 누락.

#### Clean confirmations (INFO)
- Token guard: no re-entrancy window. Bumped before kills, captured before fade, checked before emit.
- Esc handler: `event.pressed` + `not event.echo` 가드 정확. press/release 둘 다 안전.
- Enum values in .tscn match atom contracts.
- Main.tscn overlay path + node name updated; stub files absent.
- HUD.gd has no live show_dialog/StageResultOverlayStub reference.
- phase09 sot_aux path fix piggyback acceptable.

---

## Impl Self-Review Round 2 + Fixes (2026-05-17)

> Stage: **impl** (Codex R1 MED 3 + LOW 2 모두 fix, self-review clean)

### Fix list
- **M-1 fix**: `docs/INPUT_PLAN.md` §3 phase split table v2 → v3 (phase 6 game-flow-foundation 신설 반영 → phase 7~23 시프트). 추가로 §3 헤더 "v3 개정" 명시.
- **M-2 fix**: `docs/UI_GUIDE.md` §3.5 LogoPanel / §3.6 StageSlotCard / §3.6 lock icon / §5 SaveData / §7 Settings / §7 Credits 6곳 "Phase 12" → "Phase 13".
- **M-3 fix**: `tests/StageDialogDismissRaceTest.gd` scenario A + B 모두 `Card.scale.is_equal_approx(Vector2.ONE)` assertion 추가. scenario B는 caPop settle(0.5s wait, time_scale=8)까지 await 후 assertion (race window가 짧아 mid-flight value 회피).
- **L-1 fix**: `tests/StageDialogPauseSafeTest.gd` `Card.scale.x >= 0.9` → axes 둘 다 [0.97, 1.10] 범위 (caPop overshoot 1.08 → settle 1.0 허용폭).
- **L-2 fix**: `tests/StageDialogSfxTest.gd` `_request_log` 신설 + request_replay/next/menu 구독 → case C에서 `dialog_btn_press` 후 fade_out wait → request_* emit 1회 + expected_request 일치 검증.

### Tests (10/10 PASS) — fix 후 재검증
- ScoringStarsTest / StageDialogShowResultTest / StageDialogDismissTest / StageDialogDismissRaceTest / StageDialogPauseSafeTest / StageDialogEscTest / StageDialogSfxTest 7개 + Stage02/03HeadlessTest 회귀 2개 + GameFlowTest A/B/C 3개 = 10/10 PASS.

### Self-review verdict: clean → codex Round 2 호출

---

## Codex Impl Review Round 2 (2026-05-17)

> Stage: **impl** (Round 1 fix 검증 + 잔여 stale ref 점검)

### Verdict: NEEDS-ATTENTION (no HIGH; 2 MED + 2 LOW + 3 INFO)

#### MEDIUM
- **R2-M1** · `docs/INPUT_MAPPING.md:154,170,353,366` Esc routing이 phase 12라 함 — phase 13으로 갱신 필요 (INPUT_PLAN sweep과 별개 doc).
- **R2-M2** · `phases/mvp/phase13-ui-title-menu.md:16,124,166` "Phase 8~11", "Scoring.gd (Phase 11이 owner)", "BGM/SFX post-MVP phase 20" stale.

#### LOW
- **R2-L1** · `tests/StageDialogSfxTest.gd:91-106` 강한 temporal ordering(button press 직후 frame에 request_log empty) 검증 누락.
- **R2-L2** · `phases/mvp/phase09-ui-theme-assets.md:237` "Phase 11 (StageDialog)" stale.

#### INFO (clean confirmation)
- DismissRaceTest scale assertion 적용 확인.
- PauseSafeTest [0.97, 1.10] tolerance caPop overshoot 커버.
- INPUT_PLAN table + UI_GUIDE 6곳 renumber 정확.

---

## Impl Self-Review Round 3 + Fixes (2026-05-17)

### Fix list
- **R2-M1 fix**: `docs/INPUT_MAPPING.md` 4곳 (line 154/170/353/366) phase 12 → phase 13 (Esc InputMap routing). DEFER-1 명시.
- **R2-M2 fix**: `phases/mvp/phase13-ui-title-menu.md` 4곳 — Phase 8~11 → 9~12 + SceneFlow ownership 확장 + Scoring owner phase 11 → 12 + sfx_request hook 출처 phase 12 + BGM/SFX phase 20 → 21.
- **R2-L1 fix**: `tests/StageDialogSfxTest.gd` case C에 강한 temporal ordering assert 추가 — button press 직후 (await 전) `_sfx_log`에 dialog_btn_press 1개 기록 + `_request_log.is_empty()` (request_* 아직 fade_out 진행 중) 검증.
- **R2-L2 fix**: `phases/mvp/phase09-ui-theme-assets.md:237` Phase 11 → Phase 12.

### Tests (10/10 PASS) — 모든 fix 후 재검증
- ScoringStars / StageDialogShowResult / StageDialogDismiss / StageDialogDismissRace / StageDialogPauseSafe / StageDialogEsc / StageDialogSfx 7개 + Stage02/03/GameFlow 회귀 3개 = 10/10 PASS.

### Self-review verdict: clean → codex R3 호출

---

## Codex Impl Review Round 3 (2026-05-17)

> Stage: **impl** (Round 2 fix 검증 + 잔여 phase 번호 sweep 점검)

### Verdict: NEEDS-ATTENTION (no HIGH; 3 MED + 1 LOW)

#### MEDIUM
- **R3-M1** · `phases/mvp/plans/phase05-plan.md` (lines 140, 277, 293, 325, 388, 495, 538, 550, 625, 642) Esc/back_menu을 phase 12로 routing — phase 13으로 sweep 필요 (DEFER-1과 정합).
- **R3-M2** · `phases/mvp/plans/phase12-plan.md` (lines 90, 420) "INPUT_PLAN phase 12 binding" stale — Round 3에서 phase 13으로 갱신됐으니 본 plan 자기 노트도 update.
- **R3-M3** · `phases/mvp/plans/phase12-plan.md` (lines 314, 322, 327-333, 414, 421-423) SFX follow-up을 phase 20으로 가리킴 — metadata/UI doc은 phase 21 (`sound-bgm-sfx`).

#### LOW
- **R3-L1** · `phases/mvp/plans/phase02-plan.md` (lines 85, 213) + `phases/mvp/plans/phase03-plan.md` (lines 207-211) generic ref to phase 11/12 — HUD/StageDialog 의미로 stale.

---

## Session boundary — 2026-05-17

> 사용자 결정: "지금 상태 정리하고 다음 세션으로 넘어가자"

### 현재 상태
- **코드 산출 완료**: Scoring.gd / EventBus.gd +1 / StageDialog.{gd,tscn} / Main.tscn / HUD.gd / GameFlowTest.gd / 신규 tests 7개 + 5 stub 삭제.
- **Doc sweep 완료**: UI_GUIDE.md (§3.5/§3.6/§5/§7/§5.3), INPUT_PLAN.md (§3 table + 10 lines), INPUT_MAPPING.md (4 lines), phase09/phase12/phase13 plan/frontmatter.
- **Tests 10/10 PASS** (Stage02/03 + GameFlowTest + 7 phase 12).
- **Plan-as-SoT**: `phases/mvp/plans/phase12-plan.md` v6.1.
- **Review log**: `phases/mvp/reviews/phase12-impl-review.md` (plan R1~R4 + impl R1~R3 + self R1~R3).
- **WIP isolation**: working tree에 level-editor 변경(`addons/candyants_level_tool/`, `scripts/core/StageLayoutData.gd`, `scripts/world/StageLayoutBuilder.gd`, `codex-worklog/map-editor/*`) 그대로 있음. commit 시 stash 필요.
- **Notion phase 12**: status `진행 중` 유지 (완료 안 함).
- **status.json**: phase 12 pending 유지.

### 다음 세션 핸드오프
1. **R3 finding 4건 처리 결정** — 선택지:
   - (a) 자기참조만 fix (R3-M2 + R3-M3) + R3-M1/L1 deferred.md
   - (b) 전부 fix + codex R4
   - (c) 전부 defer + commit/complete
2. **WIP stash**: `git stash push -u -m "phase12-WIP" -- addons/candyants_level_tool scripts/core/StageLayoutData.gd scripts/world/StageLayoutBuilder.gd codex-worklog/` (phase 11 lesson §7 패턴).
3. **commit**: phase 12 산출 + cross-doc sweep + phase 9 frontmatter fix 묶음.
4. **`python scripts/execute.py mvp complete 12`** (Notion `완료` 동기화 직전 호출).
5. **Notion phase 12 → `완료`** via mcp `notion-update-page` (page_id `35bb23cf-3720-816c-9d0d-da1f40b879a1`).
6. **`git stash pop`** WIP 복원.

### Round count meta
- Plan: 4 codex + 2 self-review = 6 round (phase 9의 6 round와 동급).
- Impl: 3 codex + 3 self-review = 6 round.
- Total: 12 round. phase 9 (9) 초과. 큰 폭의 phase였음. 후속 phase의 plan 작성 시 ephemeral dialog 대안 등 race-free architecture 고려 가치.

---

## Impl Self-Review Round 4 + Decision (2026-05-17, 다음 세션)

> Stage: **impl** (R3 finding 4건 처리)

### 결정: 옵션 (a) — 자기참조만 fix + 나머지 deferred

R3 4건 분류:
- **자기참조 (R3-M2, R3-M3)**: 본 plan(`phase12-plan.md`)의 SoT 일관성 결손. inline fix.
- **historical record (R3-M1, R3-L1)**: 이미 완료된 phase 02/03/05 plan의 stale refs. 동작 영향 0. `phase12-deferred.md`로 분리.

근거:
- impl-stage 정책(CLAUDE.md 2026-05-09): HIGH/CRITICAL만 반드시 fix, MED/LOW는 defer 가능.
- 이미 plan 6 round + impl 6 round = 12 round. 추가 codex R4는 효율 낮음 (MED만 남음 + 자기 참조 정합 확보 후엔 새 HIGH 발생 위험 미미).
- phase 02/03/05 plan retroactive 수정은 historical record의 의미 훼손.

### Fix 적용
- **R3-M2 fix**: `phases/mvp/plans/phase12-plan.md` 2곳 (line 90 §2.7 + line 420 DEFER-1) — "INPUT_PLAN.md ... phase 12 InputMap binding" → "INPUT_PLAN.md ... codex Impl R2 sweep으로 이미 phase 13 binding으로 정정됨" 로 정정.
- **R3-M3 fix**: `phases/mvp/plans/phase12-plan.md` 9곳 — SFX follow-up "phase 20" → "phase 21(`sound-bgm-sfx`)". DEFER-3/DEFER-4(SFX receiver/asset · atom-level emit) phase 21로, DEFER-2(star polygon outline polish)는 phase 20(`stage10-bomber-polish`) 유지 (polish vs SFX 의도 분리).
- **R3-M1, R3-L1 defer**: `phases/mvp/phase12-deferred.md` 신설 — phase 02/03/05 plan stale refs 기록 + resolution path 노트.

### Self-review verdict: clean

- 자기참조 fix는 grep-driven, 모든 `phase 20` 잔류는 polish 의도(line 123, 421)로 의도 명시.
- deferred.md는 plan v6.1 §6 DEFER-1과 정합 (Esc InputMap binding phase 13 ownership). 회귀 위험 0.
- codex R4 호출 안 함. 본 round = self-review only.

### Impl 완료 결정
다음 단계: WIP stash → commit (phase 12 + cross-doc sweep + phase 9 frontmatter fix + 본 round R3 자기참조 fix + deferred.md) → `execute.py complete 12` → Notion phase 12 → `완료`.

### Round count 갱신
- Plan: 4 codex + 2 self-review = 6 round.
- Impl: 3 codex + **4 self-review** = 7 round.
- Total: **13 round**.
