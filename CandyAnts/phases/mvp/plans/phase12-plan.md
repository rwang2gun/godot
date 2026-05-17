# Phase 12 Plan — ui-stage-dialog (v6.1)

**Status**: plan v6.1 (self-review HIGH 1 + MED 1 + LOW 1 반영 — dismiss race regression test + show_result button ordering + Esc test wording. v6.1: assistant SL-1 inline fix — §3.2 ↔ §5 visible 가드 표현 sync)
**Plan-as-SoT 채택**: phase 11 lesson §1을 그대로 적용. 본 plan이 1차 SoT, `phases/mvp/phase12-ui-stage-dialog.md`(이하 "구 frontmatter doc")는 plan stabilize 후 slim pointer로 격하 예정 (frontmatter 5종 + 1줄 포인터, 본문 spec 0줄).
**Related SoT**: `docs/UI_GUIDE.md` §4 (Motion sig — phase 9 freeze) + §5.3 (Scoring.compute_stars 단일 SoT, 본 phase가 owner) · `docs/INPUT_PLAN.md` §1·§4 (Esc / back_menu — **본 phase에서는 InputMap 미바인딩, StageDialog 내부 `_unhandled_input`만 처리**; Esc InputMap 바인딩은 phase 13으로 명시 deferral) · `docs/design_handoff/README.md` "Stage complete dialog" 시각 reference.
**Inputs frozen from prior phases**: Motion sig (phase 9), Theme (phase 9), CButton/Counter/Chip atom API (phase 10), EventBus action_triggered bus + request_replay/next/menu signals (phase 6), StageRunner direct toolbar disable (phase 11).

---

## 0. 한 줄 요약

`scenes/ui/StageResultOverlayStub.tscn`을 `scenes/ui/StageDialog.tscn`(380×440 Card + caPop + 3-star polygon row + 3 CButton)으로 교체. 구 stub `.gd/.tscn/test` 삭제. `scripts/core/Scoring.gd`(RefCounted, static `compute_stars(saved, original_hp) -> int`) 신설 = UI_GUIDE §5.3 단일 SoT. `EventBus`는 **`sfx_request(id: StringName)` 1개만** 추가(`request_replay/next/menu`는 phase 6 산출 그대로 재사용). `SceneFlow.overlay_path` 라우팅·`_freeze/_unfreeze` 경로·last-stage Next 가드는 전부 보존 — show_result(result, is_last_stage) + hide_overlay() 두 메서드 contract만 StageDialog가 받아 구현. **Last-stage Next canonical contract: visible=true + disabled=true.** Esc/back-menu는 **StageDialog-local `_unhandled_input`만 본 phase에서 구현**하고 InputMap/game-state 분기는 phase 13으로 넘긴다. **SaveData는 phase 13 범위 — 본 phase는 in-memory stars만**.

---

## 1. 본 plan이 구 frontmatter doc 본문과 다른 지점 (codex 검증용)

| # | 구 frontmatter doc 본문 | 본 plan v6 결정 | 근거 |
|---|---|---|---|
| Δ1 | "신규 EventBus 시그널 4종 추가 (request_replay/next/menu + sfx_request)" | **1종만 추가 (`sfx_request`)**. request_replay/next/menu는 이미 phase 6 `EventBus.gd:10-12` 존재 | 코드 사실: `grep "signal request_" scripts/core/EventBus.gd` → 3 hit. 4종 신규는 stale spec |
| Δ2 | "StageDialog.gd가 stage_cleared/stage_failed 구독" | **SceneFlow가 primary subscriber 유지** + show_result(result, is_last_stage) / hide_overlay() 두 메서드로 StageDialog에 위임 | SceneFlow가 이미 freeze/unfreeze + _last_result tracking + 9 GameFlowTest 시나리오 보유. 2-subscriber 분기는 ordering 모호 + GameFlowTest A/B/C가 overlay 노드 직접 lookup. 단일 orchestrator가 안전 |
| Δ3 | "scripts/core/GameManager.gd — request_* 시그널 라우팅" | **무변경** | GameManager는 print/validate만 보유. request_* → SceneFlow direct connect (phase 6 산출, `SceneFlow.gd:38-40`). 중간 라우팅 추가는 불필요한 인다이렉션 |
| Δ4 | "scripts/ui/HUD.gd — stage_cleared 시 SkillToolbar disable 호출 추가" | **HUD.gd는 show_dialog stub 1개 제거만** (deprecated push_warning, AcceptDialog 없음). Toolbar disable은 phase 11 산출(StageRunner._disable_toolbar direct ref, `StageRunner.gd:100/109/115`)이 이미 처리 | phase 11 lesson §2 (StageRunner-owned direct routing) 그대로. HUD가 toolbar 참조하는 새 경로 만들면 race + spec drift |
| Δ5 | "tests/Stage02HeadlessTest 헬퍼에 `bypass_dialog = true` 옵션 추가" | **무변경**. Stage02/03HeadlessTest는 Main.tscn 미사용 (Stage scene 직접 instantiate, SceneFlow/StageDialog 경로 미진입) | `tests/Stage02HeadlessTest.tscn`이 `Stage02.tscn`만 child로 가짐. 다이얼로그 우회 옵션 불필요 |
| Δ6 | "SaveData.record_clear (phase 12)" | **무관**. SaveData는 phase 13 (`ui-title-menu`) 산출 | `phases/mvp/phase13-ui-title-menu.md:33` SaveData.gd owner 명시. v3 renumber 잔재 |
| Δ7 | "request_next when last stage → request_menu fallback" | **현 SceneFlow 동작 유지 — last stage Next는 disabled** (구 overlay와 동일 계약) | GameFlowTest §B `B.last_stage NextButton not disabled` assertion이 disabled 기대. 동작 변경은 plan/test 동시 갱신 필요 → 본 phase 범위 외 |

위 7개 차이는 본 plan §2 이하에서 본 plan 결정으로 통일. codex가 "왜 doc과 다른가?"를 물으면 본 §1을 가리킨다.

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.tscn)
| 파일 | 용도 |
|---|---|
| `scenes/ui/StageDialog.tscn` | Modal Control (anchor full, mouse_filter=STOP, visible=false 진입). Backdrop(ColorRect 알파 0.55, 갈색 #33220E) + CardWrapper(중앙 정렬 380×440) → ShadowBG(Panel offset 6,6 ink_900) + Card(PanelContainer + Theme.Panel stylebox cream_100 3px ink_900 24radius). Card 안 VBox: Title(Label Jua 22) / Subtitle(Label Gaegu 13) / HeroScore(Label Jua 36) / StarRow(HBox 3 × Star) / StatChips(HBox 3 × Chip atom) / ButtonRow(HBox 2~3 × CButton atom) |

### 2.2 신규 (.gd)
| 파일 | 변경 폭 |
|---|---|
| `scripts/ui/StageDialog.gd` | `class_name StageDialog extends Control`. **외부 API: `show_result(result: Dictionary, is_last_stage: bool) -> void` + `hide_overlay() -> void`** (구 stub과 동일 시그니처 — SceneFlow 무변경 보장). 내부: caPop on show, fade_out(0.15, pause_safe=true) on dismiss, Scoring.compute_stars 1회 호출, 3 CButton(Replay/Next/Menu) 연결, button 중복 클릭 가드(첫 클릭 즉시 set_disabled(true)), **Next canonical contract: cleared+!last_stage → visible=true/disabled=false, cleared+last_stage → visible=true/disabled=true, !cleared → visible=false/disabled=true**. Dialog-local Esc 처리: `_unhandled_input`에서 `KEY_ESCAPE` press를 감지해 `_dismiss_then_emit(EventBus.request_menu)` 호출, InputMap binding 없음 |
| `scripts/core/Scoring.gd` | `class_name Scoring extends RefCounted`. `const STAR_THRESHOLDS := [0.50, 0.80, 0.95]` + `static func compute_stars(saved: int, original_hp: int) -> int`. UI_GUIDE §5.3 1:1. **Freeze 정책**: 본 phase 완료 시 시그니처 freeze. v0.2 stage별 임계값은 옵션 인자로 추가 (UI_GUIDE §5.3 freeze 라인 그대로) |

### 2.3 수정 (.gd / .tscn)
| 파일 | 변경 |
|---|---|
| `scripts/core/EventBus.gd` | 1줄 추가: `signal sfx_request(id: StringName)` (request_replay/next/menu는 phase 6 이미 존재 — 무변경) |
| `scripts/ui/HUD.gd` | `show_dialog(message: String)` 메서드 1개 제거 (deprecated push_warning만 있었음). 본 phase에서 호출자 없으므로 grep으로 호출 검증 후 삭제 |
| `scenes/Main.tscn` | `[ext_resource]` 라인 1줄 + `[node ... instance]` 1줄: `StageResultOverlayStub.tscn` → `StageDialog.tscn`. node name `StageResultOverlayStub` → `StageDialog`. SceneFlow `overlay_path = NodePath("../GlobalUI/StageDialog")`로 1줄 갱신 |
| `tests/GameFlowTest.gd` | `_overlay = _main.get_node("GlobalUI/StageResultOverlayStub")` → `_main.get_node("GlobalUI/StageDialog")`. NextButton 노드 lookup 2곳을 **시나리오별 다른 assertion**으로 교체. line 125 (Scenario B = Stage03 cleared + last) → `is_next_visible() == true && is_next_disabled() == true` (회색+disabled). line 213 (Scenario C = stage1 loss / no_more_ants) → `is_next_visible() == false` (loss 시 hidden). hidden/disabled를 한 assertion으로 합치지 않는다 — SH-1 회귀 가드 |

### 2.4 신규 tests (.tscn + .gd)
| 파일 | 검증 |
|---|---|
| `tests/ScoringStarsTest.{tscn,gd}` | `Scoring.compute_stars(0, 10) == 0`, `(5, 10) == 1`, `(8, 10) == 2`, `(10, 10) == 3`, `(0, 0) == 0`, `(9, 10) == 2` (0.90 < 0.95 boundary), `(95, 100) == 3` (>=0.95 boundary) |
| `tests/StageDialogShowResultTest.{tscn,gd}` | StageDialog 인스턴스 → `show_result({saved:8, lost:2, original_hp:10, score:0.8, cleared:true, stage_id:1, reason:"", time_left:30.0}, false)` 호출 → visible=true · HeroScore.text contains "8" + "10" · star_filled_count() == 2 · NextButton.visible == true · NextButton.disabled == false. cleared=false 케이스 → NextButton.visible == false + disabled == true. **is_last_stage=true + cleared=true → NextButton.visible == true + disabled == true** |
| `tests/StageDialogDismissTest.{tscn,gd}` | show_result(...) → Replay CButton.pressed.emit() → fade_out 진행 60ms → 첫 클릭 후 즉시 Replay/Next/Menu .disabled == true (재진입 가드) → fade_out 완료(0.15s+ margin) 후 `EventBus.request_replay` emit 검증. Engine.time_scale=8로 가속. **CONNECT_ONE_SHOT**으로 await guarantee |
| `tests/StageDialogDismissRaceTest.{tscn,gd}` | **self-review HIGH regression**: (A) show_result(old) → Replay dismiss 시작 → 0.15s 전 show_result(new) 호출 → old fade duration 이후에도 dialog visible=true, modulate.a==1.0, Card.scale==Vector2.ONE 근처, stale `request_replay/request_next/request_menu` emit 0회. (B) show_result(old) → dismiss 시작 → 0.15s 전 hide_overlay() 호출 → old fade duration 이후 stale request_* emit 0회 + `_dismissing` 해제 + 다음 show_result 정상 표시. 이 테스트가 `_dismiss_token` 누락/오구현을 직접 잡는다 |
| `tests/StageDialogPauseSafeTest.{tscn,gd}` | tree.paused=true → show_result(...) → 200ms wait → modulate.a == 1.0 + Card.scale == Vector2.ONE 근처 (PROCESS_MODE_ALWAYS + Motion.fade_in pause_safe + caPop paused-tree 진행). 동일 트리에서 Replay 누름 → fade_out tween 진행 → request_replay emit |
| `tests/StageDialogEscTest.{tscn,gd}` | **Main.tscn 전체를 instantiate**해서 GlobalUI/StageDialog + autoload InputRouter + scene SkillToolbar/HUD nodes가 실제 headless scene tree에 있는 상태를 만든다. show_result(...) 후 `Input.parse_input_event(InputEventKey(KEY_ESCAPE, pressed=true))` 호출 (M-1 fix: `_unhandled_input` direct call 대신 **real viewport input chain 경유** — InputRouter/scene UI/StageDialog 모두 통과해 chain race가 노출됨) → buttons disabled → fade_out 완료 후 `EventBus.request_menu` 1회 emit. `InputMap`/`GameAction.BACK_MENU` 등록 없이 dialog-local route만 검증. **추가 회귀 case**: visible=false 시 Esc 무시 (idempotency) + InputRouter/scene UI가 ESC를 double-consume 안 함 (이 경로들은 ESC를 안 받지만 회귀 가드) |
| `tests/StageDialogSfxTest.{tscn,gd}` | `EventBus.sfx_request` 구독 후 (a) show_result(cleared+saved=8/10=2 stars) → id 시퀀스: `dialog_open` 1회 + `dialog_stats_pop` 1회 + `star_fill` 2회. (b) show_result(loss, 0 star) → `dialog_open` 1회 + `dialog_stats_pop` 1회 + `star_fill` **0회** (boundary 검증, SL-1). (c) Replay/Next/Menu dismiss 각각 `dialog_btn_press` 1회 emit이 request_* emit보다 먼저. CButton boop은 별도 sfx emit 없음 (atom 무수정 §2.7 확인) |
| `tests/test_StageDialog.gd` (TDD stub) | StageDialog 인스턴스 + 기본 API ping (show_result/hide_overlay 존재) |

### 2.5 삭제 (CRITICAL — git rm)
| 파일 | 사유 |
|---|---|
| `scripts/ui/StageResultOverlayStub.gd` | 본 phase가 StageDialog로 교체 |
| `scripts/ui/StageResultOverlayStub.gd.uid` | (자동 정리) |
| `scenes/ui/StageResultOverlayStub.tscn` | 동상 |
| `tests/test_StageResultOverlayStub.gd` | 동상 (대체: `tests/test_StageDialog.gd`) |
| `tests/test_StageResultOverlayStub.gd.uid` | 동상 |

### 2.6 수정 (Phase frontmatter pointer-ize — plan stabilize 후)
| 파일 | 변경 |
|---|---|
| `phases/mvp/phase12-ui-stage-dialog.md` | frontmatter 5종(name/duration_estimate/verify/large_change_ok/sot/sot_aux) 보존 + 본문 전체를 1줄 포인터로 교체: "본 phase의 1차 SoT는 `phases/mvp/plans/phase12-plan.md` v{n}. 본 문서는 execute.py validate용 frontmatter만 보존" |

### 2.7 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/SceneFlow.gd` — overlay_path 라우팅·_freeze/_unfreeze·_last_result Next 가드·request_* 핸들러 전부 그대로. StageDialog가 구 stub과 동일 메서드 contract(show_result(result, is_last_stage) + hide_overlay) 노출하므로 SceneFlow 변경 0줄
- `scripts/core/StageRunner.gd` — phase 11에서 _disable_toolbar direct ref + _make_result Dictionary 완비. 본 phase 무변경
- `scripts/core/ScoreSystem.gd` — RefCounted 4-카운터 그대로 (saved_pieces/in_transit/lost/original_hp)
- `scripts/core/GameManager.gd` — print/validate만, 무변경
- `scripts/ui/Motion.gd`, `Tokens.gd` — phase 9 freeze 그대로 (caPop/boop/fade_in/fade_out 5 sig)
- `scripts/ui/atoms/{CButton,Chip,Counter,SkillSlot}.gd` — phase 10/11 freeze 그대로. StageDialog가 CButton·Chip 인스턴스 소비만
- `scripts/ui/HUD.gd` — show_dialog 1줄 제거 외 무변경
- `scripts/ui/SkillToolbar.gd`, `PauseBtn.gd`, `ReleaseRateStepper.gd` — phase 11 산출 그대로
- `theme/candyants.tres` — phase 9 freeze
- `project.godot` — main_scene 그대로 (TitleScene 전환은 phase 13)
- `scripts/input/*` — phase 5~8 그대로. **Esc InputMap binding은 본 phase에서 추가하지 않는다** (INPUT_PLAN.md §1·§4는 codex Impl R2 sweep으로 이미 "phase 13 InputMap binding"으로 정정됨. 본 phase 범위는 dialog 자체 — back_menu 액션 wiring은 phase 13 menu 도입 시 같이 진행. 본 plan §3.3 결정 보류 항목)

---

## 3. 상세 설계

### 3.1 StageDialog 노드 트리 (handoff `preview/dialog.html` 기반)

```
StageDialog (Control, full anchor, mouse_filter=STOP, visible=false, PROCESS_MODE_ALWAYS)
├─ Backdrop (ColorRect, full anchor, color=Color(0.20,0.13,0.07,0.55), mouse_filter=STOP)
└─ CardWrapper (CenterContainer, full anchor)
   └─ Card (Control, custom_minimum_size 380×440)
      ├─ ShadowBG (Panel, anchor full + offset (6,6,6,6), StyleBoxFlat ink_900 corner_radius 24, show_behind_parent=true)
      └─ Main (PanelContainer, anchor full, theme stylebox 'panel' = Theme default cream_100 panel)
         └─ VBox (VBoxContainer, separation 12, paddings via VBox margins or wrapper Margin)
            ├─ Title (Label Jua 22, INK_900, hor align center)
            ├─ Subtitle (Label Gaegu 13, INK_700, hor align center)
            ├─ HeroScore (Label Jua 36, hor align center) — "8 / 10 조각"
            ├─ StarRow (HBoxContainer, separation 8, alignment CENTER)
            │  ├─ Star1 (Polygon2D 44×44 wrapped in Control) — 5-point star polygon, color LEMON_500(fill) or CREAM_200(dim), 3px outline via _draw() override OR Line2D overlay
            │  ├─ Star2 (동상)
            │  └─ Star3 (동상)
            ├─ StatChips (HBoxContainer, separation 8, alignment CENTER) — 3 Chip atom 인스턴스
            │  ├─ ChipSaved (Chip atom, tint=MINT, label="귀가", value=str(saved))
            │  ├─ ChipLost  (Chip atom, tint=BERRY, label="잃음", value=str(lost))
            │  └─ ChipTime  (Chip atom, tint=LEMON, label="남은 시간", value="%ds" % int(time_left))
            └─ ButtonRow (HBoxContainer, separation 12, alignment CENTER)
               ├─ ReplayBtn (CButton atom, kind=SECONDARY, text="다시 하기")
               ├─ NextBtn   (CButton atom, kind=PRIMARY,   text="다음 단계")
               └─ MenuBtn   (CButton atom, kind=GHOST,     text="메뉴로")
```

Star polygon (정 5각성): 단순 PackedVector2Array 좌표 const + Polygon2D.polygon 세팅. 채움 vs dim은 Polygon2D.color 토글. 3px ink 윤곽선은 Line2D 또는 본 v6에서는 **윤곽선 생략 + 단순 채움/dim 분기만** (handoff `preview/dialog.html`도 fill only로 충분히 인지 가능, 윤곽선은 polish — phase 20 candidate).

### 3.2 StageDialog.gd 외부 API (구 stub과 1:1 호환)

```gdscript
class_name StageDialog extends Control

func show_result(result: Dictionary, is_last_stage: bool) -> void:
    # 0) **Prior tween cleanup (codex R3 HIGH token guard)** — fade window 도중 새 show_result 시
    #    옛 fade_out + caPop이 살아있을 수 있음. 새 generation으로 stale callback을 먼저 invalidate한 뒤
    #    tween kill + _dismissing/_modulate reset을 수행한다. kill()이 같은 frame에 finished를 fire해도
    #    callback은 captured token != _dismiss_token 이므로 stale request_* emit이 불가능하다 (§3.3).
    _dismiss_token += 1
    if _dismiss_tween and _dismiss_tween.is_valid():
        _dismiss_tween.kill()
    _dismiss_tween = null
    if _capop_tween and _capop_tween.is_valid():
        _capop_tween.kill()
    _capop_tween = null
    _dismissing = false
    modulate.a = 1.0
    Card.scale = Vector2.ONE
    # 1) 결과 데이터 파싱 (구 stub과 동일 키 사용: saved/lost/original_hp/score/cleared/reason/time_left/stage_id)
    # 2) Title/Subtitle/HeroScore text 갱신 (cleared bool 분기)
    # 3) StatChips 값 갱신
    # 4) Scoring.compute_stars(saved, original_hp) 호출 → star fill 토글 + filled 수만큼 sfx_request(&"star_fill") emit
    # 5) NextBtn: cleared+!is_last_stage → visible=true, disabled=false
    #            cleared+is_last_stage → visible=true, disabled=true (last stage 가드)
    #            !cleared → visible=false, disabled=true (loss 시 hidden)
    #    여기서 _next_should_be_disabled / NextBtn.visible / NextBtn.disabled를 항상 재계산한다.
    # 6) ReplayBtn/MenuBtn 항상 visible=true, disabled=false. 마지막에 _enable_all_buttons() 호출로
    #    Replay/Menu enable + Next는 _next_should_be_disabled 계약을 유지한다.
    _enable_all_buttons()
    # 7) visible=true → Motion.fade_in(Backdrop, 0.18, true) + _capop_tween = Motion.caPop(Card)
    # 8) sfx_request(&"dialog_open") emit 1회 + sfx_request(&"dialog_stats_pop") emit 1회

func hide_overlay() -> void:
    # SceneFlow가 _on_request_replay/next/menu에서 호출. fade_out 없이 즉시 visible=false + 버튼 enable.
    # (SceneFlow 무변경 보장; 버튼 click 경로는 _dismiss_then_emit이 별도 처리)
    # SL-2 fix: dismiss fade window 도중 SceneFlow가 hide_overlay 호출하면 _dismissing이 stuck됨.
    # _dismissing/_disable_all_buttons/modulate.a/Card.scale 모두 reset해 깨끗한 다음 show_result 진입 보장.
    _dismiss_token += 1
    if _dismiss_tween and _dismiss_tween.is_valid():
        _dismiss_tween.kill()
    _dismiss_tween = null
    if _capop_tween and _capop_tween.is_valid():
        _capop_tween.kill()
    _capop_tween = null
    visible = false
    modulate.a = 1.0
    Card.scale = Vector2.ONE
    _dismissing = false
    _enable_all_buttons()

func is_next_disabled() -> bool:
    return NextBtn.disabled

func is_next_visible() -> bool:
    return NextBtn.visible

# 별 채움 상태 검증용 inspector (StageDialogShowResultTest §2.4가 호출).
# 채움 = Polygon2D.color == Tokens.LEMON_500, dim = Tokens.CREAM_200.
# **L-1 주의 (codex R2)**: 현 v0.1은 star color를 Tokens 상수로 직접 대입하므로
# is_equal_approx 비교가 안전. 향후 theme-derived color/alpha animation 도입 시
# (DEFER-2 윤곽선, DEFER-3 sfx-coupled alpha 등) 본 비교는 brittle —
# StageDialog 내부 _is_star_filled[i] bool array 도입으로 시각 비교 ↔ 논리 상태 분리.
# 본 phase는 단순 color compare로 freeze. 후속 phase에서 inspector 시그니처 보존하며 내부 교체.
func star_filled_count() -> int:
    var n := 0
    for star in [Star1, Star2, Star3]:
        if star.color.is_equal_approx(Tokens.LEMON_500):
            n += 1
    return n
```

Button enable/disable helpers:

```gdscript
func _set_buttons_disabled(disabled: bool) -> void:
    ReplayBtn.disabled = disabled
    MenuBtn.disabled = disabled
    # Next keeps its state contract after show_result. During dismiss it is disabled too.
    NextBtn.disabled = disabled or _next_should_be_disabled

func _disable_all_buttons() -> void:
    _set_buttons_disabled(true)

func _enable_all_buttons() -> void:
    _set_buttons_disabled(false)
```

`_next_should_be_disabled`는 show_result의 cleared/is_last_stage 분기에서 계산한 내부 bool이다. loss 상태에서는 `NextBtn.visible=false` + `_next_should_be_disabled=true`, last-stage cleared에서는 `NextBtn.visible=true` + `_next_should_be_disabled=true`.

`is_next_disabled()`는 `.disabled`만 반환한다. hidden과 disabled를 합치지 않는다. Loss 상태 검증은 `is_next_visible() == false`, last-stage 검증은 `is_next_visible() == true && is_next_disabled() == true`로 나눠서 잠근다.

본 phase에서 inspector 3종(`is_next_visible()`, `is_next_disabled()`, `star_filled_count()`) 시그니처를 freeze한다. 후속 phase가 dialog 노드 트리를 재배치해도 GameFlowTest/StageDialogShowResultTest 무영향.

Dialog-local Esc 처리:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not visible or _dismissing:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        _dismiss_then_emit(EventBus.request_menu)
```

본 phase에서는 `project.godot` InputMap에 Esc/back_menu를 추가하지 않는다. 이 경로는 StageDialog가 visible일 때만 작동하는 modal-local escape hatch이며, phase 13 title/menu/game-state router가 들어오면 `back_menu` 액션으로 승격한다.

### 3.3 버튼 click / Esc → dismiss 흐름 (persistent dialog)

```gdscript
var _dismissing: bool = false
var _dismiss_tween: Tween = null     # fade tween 보관 → kill 가능
var _capop_tween: Tween = null       # SM-3 caPop kill guard용
var _dismiss_token: int = 0          # codex R3 HIGH: state-independent stale callback guard
var _next_should_be_disabled: bool = true

func _on_replay_pressed() -> void:
    _dismiss_then_emit(EventBus.request_replay)
func _on_next_pressed() -> void:
    _dismiss_then_emit(EventBus.request_next)
func _on_menu_pressed() -> void:
    _dismiss_then_emit(EventBus.request_menu)

func _dismiss_then_emit(signal_ref: Signal) -> void:
    if _dismissing:
        return
    _dismissing = true
    _dismiss_token += 1
    var token := _dismiss_token
    _disable_all_buttons()
    # SFX hook: request_* emit보다 먼저, dismiss tween 시작과 같은 frame (M-2 fix).
    EventBus.sfx_request.emit(&"dialog_btn_press")
    _dismiss_tween = Motion.fade_out(self, 0.15, true)
    _dismiss_tween.finished.connect(func():
        # codex R3 HIGH: generation token은 _dismissing 상태와 무관하다.
        # show_result/hide_overlay/_dismiss_then_emit 재진입은 모두 _dismiss_token을 증가시킨다.
        # kill()이 같은 frame에 finished를 fire해도 captured token이 stale이면 request_* emit 차단.
        if token != _dismiss_token:
            return
        if not _dismissing:
            return
        visible = false
        modulate.a = 1.0   # next show_result 진입 시 1.0 보장
        _dismissing = false
        _dismiss_tween = null
        signal_ref.emit()
    , CONNECT_ONE_SHOT)
```

**핵심 invariant**:
- StageDialog는 영구 노드 (queue_free 안 됨). show_result/hide_overlay 두 메서드로 visible toggle만.
- fade_out은 `self`(StageDialog Control) 대상. `modulate.a` 0→1 reset은 다음 show_result 진입 시 필수.
- _dismissing 가드는 한 frame에 두 번 클릭(예: 빠른 마우스+키보드 동시)도 차단.
- **fade tween race 차단 (codex R3 HIGH)**: `_dismiss_tween` instance var + `_dismiss_token` generation guard. 새 show_result/hide_overlay/새 dismiss가 fade window 도중 도착하면 먼저 `_dismiss_token += 1`로 옛 callback을 invalidate한다. kill()이 synchronous finished를 fire해도 captured token mismatch로 stale request_* emit이 차단된다. `_dismissing`은 중복 입력 차단용 보조 상태일 뿐 stale emit의 1차 guard가 아니다.

### 3.4 caPop / fade 호출 (phase 9 Motion freeze 그대로)

- show_result 진입 시: `Motion.fade_in(Backdrop, 0.18, true)` + `Motion.caPop(Card)` 동시 (caPop은 scale 0.8→1.08→1.0 220ms TRANS_BACK). Card의 PROCESS_MODE_ALWAYS는 부모(StageDialog) 상속, caPop tween은 _process_mode 영향 받지 않음(set_pause_mode 미설정 시 TWEEN_PAUSE_BOUND, 부모가 ALWAYS면 정상 진행).
- dismiss 시: `Motion.fade_out(self, 0.15, true)`. pause_safe=true로 paused tree에서도 진행.
- **caPop + fade kill guard 적용** (phase 10 lesson §1 atom pattern + codex R3 HIGH 보강). 두 tween 모두 instance var(`_capop_tween` / `_dismiss_tween`)에 보관 → show_result step 0이 `_dismiss_token += 1`로 stale callback을 먼저 invalidate한 뒤 둘 다 kill + Card.scale/modulate.a snap → 새 fade_in + caPop. fade_out finished callback은 captured token mismatch로 stale fire reject. scale은 stable이라 base 캐시 불필요(phase 10 lesson §1 Counter pattern).

### 3.5 Scoring.gd 구현

```gdscript
class_name Scoring
extends RefCounted

const STAR_THRESHOLDS := [0.50, 0.80, 0.95]   # ascending, len = max_stars(3)

static func compute_stars(saved: int, original_hp: int) -> int:
    if original_hp <= 0:
        return 0
    var ratio := float(saved) / float(original_hp)
    var stars := 0
    for threshold in STAR_THRESHOLDS:
        if ratio >= threshold:
            stars += 1
    return stars
```

**Freeze 정책**: `compute_stars(saved, original_hp) -> int` 시그니처는 본 phase 완료 시 freeze. v0.2 stage별 임계값 override는 옵션 인자(`stage_thresholds: Array = STAR_THRESHOLDS`) 1개 추가 (UI_GUIDE §5.3 Freeze 라인 그대로).

### 3.6 EventBus.gd diff (1 line)

현 `scripts/core/EventBus.gd`는 line 3~13에 11개 signal 선언, line 14가 빈 줄, line 15~17 코멘트, line 18 `signal action_triggered`, line 19 `signal input_mode_changed`. 본 phase는 line 13(`release_rate_changed`) 다음 line에 1줄 추가:

```gdscript
signal release_rate_changed(new_rate: int)
signal sfx_request(id: StringName)   # phase 12 sound hook — receiver는 phase 21 sound-bgm-sfx 산출
# (기존 line 14 빈 줄 + line 15~ 코멘트/action_triggered/input_mode_changed 그대로)
```

위치는 `release_rate_changed` 직후 (`action_triggered` 코멘트 블록과 분리). signal 그룹 의미 = 게임 라이프사이클 signal cluster의 마지막 추가. 본 phase commit diff = EventBus.gd +1 line, 0 line 변경.

### 3.7 sfx_request emit 자리 (post-MVP receiver 대비)

본 phase에서 emit만, receiver 0. 구 frontmatter doc의 modal/button/counter/star hook 위치를 보존하되 **StageDialog 노드 내부에서만 emit** (atom CButton/Counter 자체는 무수정 — §2.7). atom 전역 boop/caPop SFX는 phase 21(`sound-bgm-sfx`)에서 atom-level 통합 시 별도 id로 도입.

| 위치 | emit | scope · 비고 |
|---|---|---|
| 모달 등장 | `EventBus.sfx_request.emit(&"dialog_open")` | StageDialog `show_result` 진입 직후 1회. visible 가드(§5)로 idempotent — `if visible: hide_overlay()` 후 재 emit은 race 한정 (정상 흐름엔 1회) |
| StageDialog 버튼 dismiss | `EventBus.sfx_request.emit(&"dialog_btn_press")` | `_dismiss_then_emit`에서 request_* emit 직전 1회. **id를 `dialog_btn_press`로 한정** (atom 전역 boop SFX는 phase 21에서 `ui_btn_press` 별도 id로 도입 — 본 phase scope 외) |
| Dialog 수치 강조 | `EventBus.sfx_request.emit(&"dialog_stats_pop")` | StageDialog HeroScore/StatChips 값 세팅 후 1회. **id를 `dialog_stats_pop`로 한정** (HUD 카운터 caPop 사운드는 phase 21 atom-level `counter_pop` 별도 id) |
| 별 채움 | `EventBus.sfx_request.emit(&"star_fill")` | stars 수만큼 emit (`compute_stars==0`이면 0회 — Test §2.4 boundary 검증). stagger/receiver는 phase 21 |

**id 충돌 차단 원칙**: 본 phase는 4 id 모두 `dialog_*`/`star_fill` (dialog-scoped). atom-global SFX(`ui_btn_press`/`counter_pop`/`skill_armed` 등)는 phase 21(`sound-bgm-sfx`) atom 통합 시 별도 id로 박는다. 같은 id가 두 emit 사이트(dialog vs atom)에서 의미 다르게 쓰이는 drift 차단.

phase 21은 이 id들의 receiver(BGM/SFX player)만 채운다. 본 phase 이후 sfx hook 위치 자체는 회귀 테스트로 고정한다.

### 3.8 SceneFlow 무변경 보장 (Δ2 정합)

```gdscript
# 현 SceneFlow.gd (변경 X — StageDialog가 동일 메서드 노출):
_overlay = get_node(overlay_path)   # NodePath("../GlobalUI/StageDialog")로 갱신만, code 무변경
...
func _on_stage_result(result: Dictionary) -> void:
    _last_result = result
    _freeze_current_stage()
    _overlay.show_result(result, result["stage_id"] >= LAST_STAGE_ID)
func _on_request_replay() -> void:
    _overlay.hide_overlay()
    _unfreeze_current_stage()
    replay_stage()
# ... (next/menu 동일)
```

`overlay_path` NodePath는 Main.tscn 인스펙터 값 1줄 갱신만 (script 코드 무변경). 본 phase가 GlobalUI/StageResultOverlayStub → GlobalUI/StageDialog로 노드 이름 변경.

### 3.9 GameFlowTest 변경 (Δ7 last-stage 동작 보존)

```gdscript
# tests/GameFlowTest.gd:28 변경:
_overlay = _main.get_node("GlobalUI/StageDialog") as Control

# tests/GameFlowTest.gd:125 변경 (Scenario B: Stage03 cleared + last-stage):
# Before: if not _overlay.get_node("VBox/HBox/NextButton").disabled:
# After:  if not _overlay.is_next_visible() or not _overlay.is_next_disabled():
#   (last-stage cleared → 회색+disabled 의도. visible=true && disabled=true 둘 다 충족해야 PASS)

# tests/GameFlowTest.gd:213 변경 (Scenario C: stage1 loss / no_more_ants):
# Before: if not _overlay.get_node("VBox/HBox/NextButton").disabled:
# After:  if _overlay.is_next_visible():
#   (loss → hidden 의도. visible=false expect. disabled 값은 plan §3.2가 true로 세팅하지만 hidden이면 user-visible 동작은 없음)
```

inspector method 2개(`is_next_visible()`, `is_next_disabled()`) 도입으로 노드 경로 hardcode 차단 + Scenario B(last+cleared) vs C(loss) 두 상태가 같은 assertion으로 묶이지 않게 분리. 본 phase freeze.

---

## 4. 검증 (verify field 없음 — `python scripts/run_test.py` 수동 호출 10개)

### 4.1 자동 (헤드리스, 모두 PASS 필수)
1. `python scripts/run_test.py tests/Stage02HeadlessTest.tscn` — phase 4 회귀, 무관 (Main.tscn 미경유)
2. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` — 동상
3. `python scripts/run_test.py tests/GameFlowTest.tscn` — A/B/C 시나리오 모두 PASS. **본 phase 핵심 회귀** (overlay → dialog 노드 교체 + last-stage `is_next_visible()==true && is_next_disabled()==true`)
4. `python scripts/run_test.py tests/ScoringStarsTest.tscn` — 7 case PASS
5. `python scripts/run_test.py tests/StageDialogShowResultTest.tscn` — 3 case (cleared/last/loss) PASS
6. `python scripts/run_test.py tests/StageDialogDismissTest.tscn` — 3 button × dismiss 흐름 PASS
7. `python scripts/run_test.py tests/StageDialogDismissRaceTest.tscn` — dismiss fade 도중 show_result/hide_overlay token invalidation + stale request_* emit 0회 PASS
8. `python scripts/run_test.py tests/StageDialogPauseSafeTest.tscn` — pause 진입 시 fade_in + caPop 진행 PASS
9. `python scripts/run_test.py tests/StageDialogEscTest.tscn` — dialog-local Esc → request_menu PASS
10. `python scripts/run_test.py tests/StageDialogSfxTest.tscn` — `dialog_open` / `dialog_stats_pop` / `dialog_btn_press` / `star_fill` (count = stars) emit hook PASS

### 4.2 수동 검증 (CLAUDE.md "1차 SoT는 status.json + git, Notion 보조" 원칙)
1. Stage01 자연 클리어 → 모달 등장 + caPop 보임 → "다시 하기" → 같은 stage 리셋
2. Stage01 강제 ant 사망 → loss 모달 → Next 버튼 안 보임 → "다시 하기" 동작
3. Stage03 클리어 → last-stage Next 버튼 **보임 + disabled(회색)** 확인
4. Pause 상태에서 stage_cleared 강제 emit → 모달 등장, 게임 여전히 pause
5. 빠른 버튼 더블 클릭 → 두 번째 클릭 무시 (재진입 가드)
6. 모달 표시 중 Esc → fade_out 후 menu 요청 경로 확인
7. handoff `preview/dialog.html` vs 실제 dialog 시각 비교 — caPop 220ms + 380×440 + 갈색 backdrop

---

## 5. 엣지 케이스 (구 frontmatter doc + 본 plan 검증)

- **stage_cleared 발화 중복**: ScoreSystem이 1번만 emit (phase 2 산출). 본 phase 신뢰. show_result step 0의 unconditional cleanup (`_dismiss_token += 1` + tween kill + reset + snap)이 idempotent하게 처리하므로 두 번째 show_result도 즉시 깨끗한 상태로 진입 — 별도 `if visible: hide_overlay()` 가드 불필요 (v6 sync: §3.2 step 0이 단일 진실원천).
- **fade_out 중 새 stage_cleared 도착**: SceneFlow가 _freeze 직후 show_result 호출 → 본 plan은 SL-2 fix로 hide_overlay()가 `_dismiss_token`/`_dismissing`/`modulate.a`/`Card.scale`/button enabled state를 모두 reset → show_result가 깨끗한 상태에서 caPop 재진입. fade_out tween은 generation guard로 정리.
- **버튼 중복 클릭**: _dismissing flag + _disable_all_buttons로 차단 (구 stub과 동일 패턴 + fade window 포함). SceneFlow가 같은 frame에 hide_overlay 호출해도 SL-2 reset으로 다음 show_result 정상 진입.
- **Pause 호환**: PROCESS_MODE_ALWAYS + Motion.fade_*(pause_safe=true). caPop은 Tween 기본 TWEEN_PAUSE_BOUND, 부모 ALWAYS 상속이므로 paused tree에서도 진행. **StageDialogPauseSafeTest가 modulate와 Card.scale을 함께 확인**.
- **modulate.a reset**: dismiss fade_out → modulate.a=0 → 다음 show_result 진입 시 reset 필수. show_result 시작에서 `modulate.a = 1.0` 명시 + hide_overlay()도 동일 reset (SL-2 fix).
- **star polygon 0개일 때**: `(0, 0)` 케이스(스테이지 데이터 오류) — Scoring.compute_stars 0 return → 3 star 모두 dim + `star_fill` sfx 0회 emit (StageDialogSfxTest §2.4 boundary). 크래시 0.
- **score key 부재 시**: SceneFlow는 `_make_result`로 항상 채워서 emit. 본 phase는 신뢰 — defensive `result.get("score", 0.0)` 사용으로 미래 변경 흡수.
- **last stage Next disabled vs visible**: cleared+last → visible=true + disabled=true (구 stub 동작 보존). cleared+!last → visible=true + disabled=false. !cleared → visible=false + disabled=true (loss 시 hidden). `is_next_disabled()`는 hidden을 disabled로 취급하지 않는다. GameFlowTest §3.9는 Scenario B(last+cleared)와 C(loss)를 다른 assertion으로 잠금(SH-1 fix).
- **request_replay/next/menu가 phase 6에서 이미 connect**: SceneFlow가 single subscriber. StageDialog는 emit만, 본인 구독 0. 중복 emit 위험 0.
- **CButton boop + dismiss fade_out 충돌**: CButton._on_pressed가 Motion.boop(self) 호출 → 60ms position offset. StageDialog의 _dismiss_then_emit이 fade_out(self=StageDialog) 호출. 두 tween은 서로 다른 node 대상이므로 충돌 없음. CButton는 disable 직후에도 boop 마무리.
- **caPop race**: show_result 중복 호출 시 prior caPop tween 살아있어 Card scale drift 가능 → SM-3 kill guard로 차단.
- **fade_out tween race + stale request_* emit (codex R3 HIGH fix)**: dismiss fade window(150ms) 도중 새 show_result 도착 시 → 옛 fade_out finished callback이 새 dialog 상태에서 fire되어 stale `request_replay/next/menu` emit + SceneFlow가 의도치 않은 stage reload/advance/menu 전환. **generation guard**: ① show_result/hide_overlay/_dismiss_then_emit 진입마다 `_dismiss_token += 1`, ② finished callback은 captured token과 현재 token이 다르면 즉시 return. kill()이 synchronous finished를 fire하더라도 stale token이므로 request_* emit 불가.
- **sfx id atom-level 통합**: phase 21(`sound-bgm-sfx`)에서 `ui_btn_press`/`counter_pop`/`skill_armed` 등 atom-global SFX 도입 시 본 phase의 `dialog_*` id와 겹치지 않게 분리. id 충돌 방지 원칙은 §3.7 명시.

---

## 6. 결정 보류 / DEFER

- **DEFER-1**: Esc InputMap binding (`skill_cancel` / `back_menu`) — INPUT_PLAN.md §1·§4·INPUT_MAPPING.md 4곳 모두 codex Impl R2 sweep으로 "phase 13 binding"으로 정정 완료. 실제 binding 자리(InputRouter dispatch + game state 분기)는 phase 13 menu 도입 시 같이 wiring. 본 phase는 **StageDialog-local `_unhandled_input` Esc → request_menu**만 처리.
- **DEFER-2**: Star polygon 3px ink 윤곽선 — handoff design 명시 spec이지만 본 v6은 fill/dim 분기만. polish phase 20(`stage10-bomber-polish`) 후보.
- **DEFER-3**: sfx_request receiver/asset 구현 — 본 phase는 `dialog_open` / `dialog_stats_pop` / `dialog_btn_press` / `star_fill` emit 위치만 고정한다. 실제 AudioStream import, bus, receiver 노드는 phase 21(`sound-bgm-sfx`).
- **DEFER-4**: Atom-level SFX 통합 (`ui_btn_press` / `counter_pop` 등 atom-global id) — phase 21에서 CButton·Counter atom 자체에 emit 라인 추가. 본 phase는 StageDialog 노드 한정.
- **DEFER-5**: GameFlowTest 시나리오 D (모달 caPop visual 회귀) — 헤드리스에서 scale/modulate polling은 flaky. 본 phase는 ShowResultTest의 visible/disabled만 검증, motion 회귀는 수동.

---

## 7. 산출물 요약

```
scenes/ui/StageDialog.tscn                      (신규)
scripts/ui/StageDialog.gd                       (신규)
scripts/core/Scoring.gd                         (신규)
scripts/core/EventBus.gd                        (수정 +1 line)
scripts/ui/HUD.gd                               (수정 -3 lines: show_dialog stub 제거)
scenes/Main.tscn                                (수정: 2 ext_resource/instance + 1 overlay_path 갱신)
tests/GameFlowTest.gd                           (수정: overlay path + is_next_visible/is_next_disabled)
tests/ScoringStarsTest.{tscn,gd}                (신규)
tests/StageDialogShowResultTest.{tscn,gd}       (신규)
tests/StageDialogDismissTest.{tscn,gd}          (신규)
tests/StageDialogDismissRaceTest.{tscn,gd}      (신규)
tests/StageDialogPauseSafeTest.{tscn,gd}        (신규)
tests/StageDialogEscTest.{tscn,gd}              (신규)
tests/StageDialogSfxTest.{tscn,gd}              (신규)
tests/test_StageDialog.gd                       (신규)
scripts/ui/StageResultOverlayStub.gd            (삭제 + .uid)
scenes/ui/StageResultOverlayStub.tscn           (삭제)
tests/test_StageResultOverlayStub.gd            (삭제 + .uid)
phases/mvp/phase12-ui-stage-dialog.md           (수정: pointer-ize, plan stabilize 후)
```

**+ .uid 자동 생성**: 신규 .gd/.tscn마다 .uid 1개 (Godot import). 총 staging 약 28 파일 (delete 5 + add ~23). 100개 미만 → large_change_ok=false 가드 통과.

---

## 8. plan-stage 리뷰 정책 (CLAUDE.md 2026-05-09 정책)

본 plan은 `/codex:adversarial-review`로 1회 리뷰 후:
- CRITICAL/HIGH 1건이라도 → **STOP** + 사용자 보고 + AskUserQuestion. 자동 재리뷰 금지.
- MEDIUM/LOW만 → plan 안에서 inline 처리 또는 명시적 defer.
- v2 작성 시점: plan v1 → codex review → 사용자 요청에 따라 H-01/H-02/M-sfx/M-caPop 반영 → v2 작성.
- v3 작성 시점: v2 자체 적대적 리뷰 → SH-1 HIGH (GameFlowTest scenario B/C 분리) + MED 3 (star_filled_count() inspector 명시 + btn_press/counter_pop scope 명확화 + caPop kill guard 적용) + LOW 3 (sfx 0-star boundary 검증 추가 + hide_overlay reset 명시 + EventBus diff 라인 위치 정확화) 모두 반영.
- v4 작성 시점: codex plan-review Round 2 → HIGH 1 (fade_out tween race + stale request_* emit) + MED 2 (StageDialogEscTest input chain + _dismiss_then_emit sfx_request 의사코드 누락) + LOW 1 (star_filled_count color compare brittleness 주석) 모두 반영. fade tween을 `_dismiss_tween` instance var에 보관 + show_result step 0 kill + finished callback `if not _dismissing: return` 이중 가드.
- v5 작성 시점: codex plan-review Round 3 → HIGH 1 (kill() synchronous finished 가능성에 대한 `_dismissing` guard 취약점) + MED 1 (`_enable_all_buttons` 미정의) + LOW 1 (Esc test full Main.tscn/autoload 명시 부족) 반영. `_dismiss_token` generation guard로 stale callback을 상태값과 독립적으로 차단하고, button enable helper와 Esc full scene setup을 명시.
- v6 작성 시점: 자체 리뷰 → HIGH 1 (`_dismiss_token` race를 직접 검증하는 테스트 부재) + MED 1 (`show_result`의 `_enable_all_buttons` 호출 순서 footgun) + LOW 1 (SkillToolbar를 autoload로 부른 표현 오류) 반영. `StageDialogDismissRaceTest` 추가, show_result step 5 이후 enable 순서 명시, Esc test 문구를 autoload InputRouter + scene UI nodes로 정정.

본 v6이 자체 재리뷰 clean + codex 재리뷰 Round 4 통과(needs-attention 없음 또는 MED/LOW만)하면 그대로 impl 진입.
