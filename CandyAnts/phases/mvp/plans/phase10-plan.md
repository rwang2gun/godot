# Phase 10 Plan v4: UI Atoms Foundation (CButton · Chip · Counter · SkillSlot)

**Status**: post-impl backfill (2026-05-17). 본 plan v4가 phase 10 완료 시점(commit 5721b15)의 단일 SoT. plan-stage Option A 흡수 + impl-stage R3-L1 sweep 모두 반영.
**Frontmatter SoT**: `phases/mvp/phase10-ui-atoms-foundation.md` (harness 실행용, frontmatter `name/duration_estimate/verify/large_change_ok/sot/sot_aux` + 본문 동일 사본).
**Related SoT**: `docs/UI_GUIDE.md` §3 (atom 카탈로그) + §4 (Motion 시그니처). aux: `docs/INPUT_PLAN.md`, `docs/design_handoff/README.md`.
**Inputs frozen from prior phases**: Motion sig (phase 9 freeze, `caPop/boop/idle_bob/fade_in/fade_out` 5종) · Theme (phase 9 freeze, `theme/candyants.tres`) · Tokens.gd (phase 9 freeze + 본 phase에서 TintKind enum 확장).

---

## 변경 히스토리 (v1 → v4)

### v1 (initial, ~2026-05-09)
phase REVISION_2026-05-09 도입 시 작성. v2 numbering (phase 8 = theme-assets, phase 9 = atoms) 기준. 본 v1은 git에 별도 사본 미보존 (phase file 직접 작성 + revision).

### v2 (2026-05-17 진입 시 numbering refresh)
v3 harness 진입 시 plan cleanup:
- v2→v3 numbering 일괄 정정 (phase 8 → 9, phase 9 → 10, phase 10 → 11). 본문 "Phase 8에서 생성됨" → "Phase 9에서 생성됨" 등.
- Motion.gd가 phase 9 산출 + freeze 상태임을 명확화 — 본 phase는 consume-only, Motion.gd 수정 금지. 추가 시그니처 필요 시 phase 9 sweep.
- 테스트 파일 확장자 `.gd` → `.tscn + .gd` (run_test.py는 .tscn만 수용).
- atom API freeze 시점을 phase 10 완료 시로 정정 (이전 v1은 phase 9로 잘못 표기).
- "## Phase 5~7과의 호환성" → "## Phase 5~8 입력 파이프라인과의 호환성" 으로 명확화.
- "## Phase 10~11이 사용할 atom API" → "## Phase 11~12가 사용할 atom API"로 정정.

### v3 (2026-05-17 plan-stage codex review + Option A 흡수)
codex plan review verdict = **STOP** (HIGH 1: caPop kill guard mismatch w/ frozen Motion). CLAUDE.md plan-stage 정책 → 사용자 결정. 사용자가 **Option A (in-plan absorption)** 선택. H-1 + MEDIUM 4건 모두 본 plan v3에 흡수:
- **H-1 fix**: Motion.caPop은 phase 9 freeze 상태로 kill guard 미내장. 빠른 재호출 시 prior tween을 죽이는 책임은 **호출자(Counter atom)에게** 부여 — atom-local guard. Counter.set_value 안에 `_capop_tween: Tween` 필드 + `if active: kill, then Motion.caPop(...)` 패턴. Motion.gd 자체는 무수정.
- **M-1 fix**: Sticker shadow 구조를 atom 종류별로 분기 명문화. SkillSlot=Button 루트 + 자식 ShadowBG/MainBG. Counter=Control 루트 + ShadowBG(ColorRect) + MainPanel(PanelContainer + Theme). Chip=Control 루트 + ShadowBG(sm 2,2 offset) + MainPanel. CButton=Theme StyleBoxFlat + 자식 ShadowBG (show_behind_parent=true).
- **M-2 fix**: `Chip.set_label_value(label, value)`는 UI_GUIDE §3.2에 없는 phase 10 신규 API. 본 phase 안에서 UI_GUIDE §3.2를 동기 갱신 (시그니처 + tint export 추가) — UI_GUIDE는 atom phase의 SoT라 atom 신설과 함께 SoT 진화는 정상 절차. 산출물의 "수정" 목록에 `docs/UI_GUIDE.md` 명시 추가.
- **M-3 fix**: 수동 검증에서 `preview/dialog.html` 비교 제거 (dialog는 phase 12 영역). `preview/skill_toolbar.html`은 §0.5 1인 개발 운영 모델에 따라 보조 참고로 격하 (pixel diff X, token/layout sanity만).
- **M-4 fix**: Tokens.gd 확장 (TintKind enum + TINT_BG/TINT_BORDER dict)을 "phase 9 frozen 위 atom-needed 의도적 확장"으로 명문화. atom-local 상수로 빼지 않는 이유 (phase 11 HUD 등 향후 호출자도 같은 토큰 매핑 공유)도 plan에 기재.

### v4 (2026-05-17 impl-stage R3-L1 sweep)
codex impl review 3 round 완료 후 R3-L1 (LOW: 본 plan의 stale boop 주석) sweep로 갱신:
- **R3-L1 fix**: 엣지 케이스 §"CButton boop 시 position drift" 노트를 R2-M1 fix 결과로 동기화. Motion.boop kill 후 prior tween mid-bounce 위치를 새 base로 캡처 → drift 영구 누적 위험. 호출자(CButton/SkillSlot)가 `_boop_base: Vector2` 필드로 stable base 보관 + `if active: kill+snap to _boop_base; else: capture _boop_base = position` 패턴. `_on_boop_finished` (CONNECT_ONE_SHOT)에서 `_boop_tween=null` → 다음 호출은 base 재캡처. AtomShowcaseHeadless가 5 rapid press 후 final position == baseline 회귀 자동 검증 (CButton + SkillSlot._main_bg 둘 다).

### 본 plan에 흡수된 codex impl review 정정 (history only, fix는 코드/UI_GUIDE에서 처리)
v3 본문은 plan-stage까지의 spec. impl 단계에서 codex가 추가로 발견한 항목은 plan 본문이 아닌 코드/UI_GUIDE에 fix (impl-review 문서에 round별 기록):
- **R1-M1**: SkillSlot.tscn에서 Icon/HotkeyPill/CountBadge/KoLabel을 MainBG의 자식으로 nested (hover translate 시 동시 이동). UI_GUIDE §3.4 노드 트리를 nested 구조로 동기 갱신.
- **R1-M2**: SkillSlot.gd에 `_is_pressed` 필드 + `_on_button_down/up` 토글 + `_update_visual()`에서 `_selected or _is_pressed` 분기 (pressed-without-selected도 peach_300).
- **R1-M3**: CButton._on_pressed + SkillSlot._on_button_down에 boop kill guard (Round 1 시점).
- **R1-M4**: AtomShowcaseHeadless에 실제 boop tween 검증 추가 (`_boop_tween.is_valid()`).
- **R1-L1**: SkillSlot._ready에서 `_box_armed`/`_box_selected` 캐싱 (per-state new StyleBoxFlat 회피).
- **R1-L2**: `scripts/run_test.py` docstring에 fresh-clone bootstrap (`godot --headless --path . --import`) 안내.
- **R2-M1**: boop drift 완전 차단 — `_boop_base` 캡처+snap 패턴 (v4에 plan 본문 sync). AtomShowcaseHeadless에 final-position regression 추가 (20-frame settle + 5 rapid press + 20-frame complete + is_equal_approx 비교).
- **R2-M2**: UI_GUIDE §3.4 state table에 `Button.disabled` 컬럼 추가 + empty(false, clickable) / disabled(true, input ignore) 분리 명문화.

---

## 0. 한 줄 요약

Phase 9가 freeze한 Theme + Motion 위에 4개 atom (CButton · Chip · Counter · SkillSlot)을 Custom Control로 작성. HUD/Toolbar 씬 교체는 안 함 (phase 11이 atom 인스턴스화로 교체). 수동 시각 데모 (AtomShowcaseTest) + 헤드리스 시그널/tween 검증 (AtomShowcaseHeadless) 두 씬으로 단독 검증.

---

## 1. 목표

Phase 9가 freeze한 Theme + Motion 위에 4개 atom을 Custom Control로 작성한다. **HUD/Toolbar 씬 교체는 안 함** — 본 phase는 atoms 단위 단독 검증만 (수동 showcase + 헤드리스 시그널/tween 검증).

## 2. 전제

- Phase 9 완료 (Theme + Tokens.gd + Motion.gd + 폰트 + SVG 13장 임포트 — commit 1b9bc69)
- `docs/UI_GUIDE.md` §3 (Atom 카탈로그) + §4 (Motion 시그니처) 1차 SoT
- atoms 단독 검증용 데모 씬으로 시각/단위 검증, 헤드리스로 시그널 검증
- 본 phase는 **atom 작성만**. 다음 phase 11(ui-hud-toolbar-replace)이 atom을 인스턴스화하여 HUD/SkillToolbar 씬을 교체.

## 3. 변경 대상

### 3.1 신규 파일
**Atoms** (`scripts/ui/atoms/` + `scenes/ui/atoms/`):
- `CButton.gd` + `CButton.tscn` — `class_name CButton extends Button`. export `kind: ButtonKind { PRIMARY, SECONDARY, GHOST }`. `pressed` 시 `Motion.boop(self)` 자동 호출.
- `Chip.gd` + `Chip.tscn` — pill 스타일 정보 태그. export `label: String`, `value: String`, `tint: TintKind { PEACH, GRAPE, MINT, BERRY, LEMON }`.
- `Counter.gd` + `Counter.tscn` — 110×84. export `kind: CounterKind` (Tokens.gd enum), `top_label_en: String`, `bottom_label_ko: String`. 메서드 `set_value(n: int)` 호출 시 `Motion.caPop(big_number)` 자동.
- `SkillSlot.gd` + `SkillSlot.tscn` — 88×88. export `skill_id: StringName`, `hotkey: String`. 메서드 `set_count(n: int)`, `set_selected(b: bool)`. 8 state matrix(armed/selected/hover/pressed/empty/disabled).

**Motion** — **phase 9 산출, 본 phase 미수정**:
- `scripts/ui/Motion.gd`는 phase 9 완료 시점에 작성 + 시그니처 freeze됨 (UI_GUIDE.md §4 와 1:1).
- 본 phase 10 atom 구현이 호출하는 5개 시그니처 (참조용):
  - `caPop(node) -> Tween`, `boop(node) -> Tween`, `idle_bob(node, amplitude, period) -> Tween`
  - `fade_in(node, duration, pause_safe) -> Tween`, `fade_out(node, duration, pause_safe) -> Tween`
- **caPop은 kill guard 미내장** (phase 9 freeze 상태). 빠른 재호출 시 prior tween을 죽이는 책임은 **호출자(atom)에게** 부여 — H-1 fix (atom-local guard). Counter.set_value 안에서 `if _capop_tween and _capop_tween.is_valid(): _capop_tween.kill()` 패턴으로 처리. 본 책임 분리는 §"엣지 케이스" 안에 상세 명시.
- atom 구현 중 추가 시그니처/인자가 필요해지면 **phase 9 sweep commit** (`fix: motion sig <name> (phase 9 sweep)`)으로 처리하고 UI_GUIDE.md §4도 동기 갱신. 본 phase 안에서 Motion.gd 수정 금지.
- `tests/MotionPauseSafeTest.tscn` (phase 9 산출)을 phase 10 자동 검증 게이트에 포함 — phase 10이 Motion.gd를 손대지 않음을 회귀로 보장.

**시각 데모 씬**:
- `tests/AtomShowcaseTest.tscn` + `.gd` — 4 atom × state 매트릭스를 한 화면에 배치. 패드/마우스 둘 다 인터랙션. 수동(에디터) 시각 검증 전용.

**시그널 데모 헬퍼** (헤드리스 검증용):
- `tests/AtomShowcaseHeadless.tscn` + `.gd` — Counter.set_value 호출 시 caPop tween이 생성되는지, CButton pressed 시 boop tween 생성되는지 instantiation 검증. 1초 이내 종료.

### 3.2 수정
- `scripts/ui/Tokens.gd` (Phase 9에서 생성, freeze 상태) — **phase 10 의도적 확장**: Chip atom용 `TintKind` enum + `TINT_BG`/`TINT_BORDER` 디셔너리 추가 (M-4 fix). atom-local 상수로 빼지 않는 이유: Chip 외의 향후 호출자(예: phase 11 HUD가 chip을 직접 인스턴스화)도 같은 토큰 매핑을 공유해야 하므로 Tokens.gd가 자연스러운 위치. UI_GUIDE §1.3 enum 패턴(CounterKind)과 동일한 확장 방식.
- `docs/UI_GUIDE.md` §3.2 Chip set_label_value 시그니처 추가 (atom API freeze — M-2). impl 단계에서 §3.4 nested tree + Button.disabled 컬럼 추가 (R1-M1 / R2-M2).

### 3.3 비-변경 (회귀 게이트)
- `scenes/ui/HUD.tscn`, `SkillToolbar.tscn` — 본 phase 미수정 (phase 11에서 atom 인스턴스화로 교체)
- 기존 `scripts/ui/HUD.gd`, `SkillToolbar.gd` — 본 phase 미수정
- `scripts/ui/Motion.gd` — phase 9 freeze, 본 phase 미수정 (sweep 필요 시 별도 절차)
- `theme/candyants.tres` — 본 phase 미수정 (atom은 Theme의 디폴트 스타일 + atom-local override만 사용; Theme 신규 키 필요해지면 phase 9 sweep로 처리)

## 4. 검증 방법

### 4.1 자동 (헤드리스)
1. `python scripts/run_test.py tests/AtomShowcaseHeadless.tscn` 신규 — 4 atom 각자 instantiate + property 변경 + tween 생성 검증. 1초 이내 종료.
2. `python scripts/run_test.py tests/MotionPauseSafeTest.tscn` (phase 9 산출, 본 phase 회귀) — Motion.fade_in/out의 pause_safe 옵션이 paused tree에서 진행 / pause_safe=false 시 정지 두 케이스 모두 검증. **phase 10이 Motion.gd를 손대지 않음을 회귀로 증명**.
3. `python scripts/run_test.py tests/SvgImportSmokeTest.tscn` (phase 9 산출, 본 phase 회귀) — SVG 13장 sanity invariants PASS.
4. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS — 게임 회귀 0.
5. `python scripts/run_test.py tests/BlockerOverlapTest.tscn` PASS — 게임 회귀 0.

### 4.2 수동 (에디터)
1. `tests/AtomShowcaseTest.tscn` 실행 — 4 atom 모든 state 시각 확인:
   - CButton: PRIMARY(peach_500) / SECONDARY(cream_100) / GHOST(transparent), hover translate y-2, press boop
   - Chip: 5 tint × `귀가 8` 같은 KO+숫자 조합
   - Counter: 5 kind 모두 표시, `set_value(n+1)` 누를 시 caPop 발화 + 빠른 연타 시 시각 깨짐 0 (atom-local kill guard 동작)
   - SkillSlot: 8 state 모두 시각 확인. count=0 → empty(saturate30%), selected→peach_300 outline
2. 패드 연결 → focus halo (3px mint_500 outline 4px offset)가 SkillSlot에 표시되는지
3. **handoff preview 비교는 §0.5 운영 모델에 따라 보조 참고** (M-3 fix): `preview/skill_toolbar.html`만 token/layout sanity 수준 비교 (pixel diff X). `preview/dialog.html`은 본 phase 비대상 (dialog는 phase 12 영역).

## 5. 엣지 케이스 (필수)

- **Sticker shadow 구조 — atom 종류별** (M-1 fix):
  - **SkillSlot** (`Button` 루트): UI_GUIDE §3.4 트리 그대로 — `Button` 안 첫 자식 `ShadowBG` (StyleBoxFlat 4,4 offset ink_900 fill, 같은 크기/radius), 두번째 자식 `MainBG`. 순서 어기면 shadow가 위로.
  - **Counter** (UI_GUIDE §3.3은 `PanelContainer → VBoxContainer`): PanelContainer는 자신의 StyleBoxFlat panel을 가지므로 ShadowBG/MainBG 2-layer 패턴이 직접 적용 안 됨. 해결: **Counter atom 루트를 `Control`** 로 두고 자식 순서 `[ShadowBG: ColorRect (4,4 offset, ink_900 fill, same radius via custom StyleBoxFlat) → MainPanel: PanelContainer (Theme panel) → VBoxContainer (콘텐츠)]`. ShadowBG 크기는 `MainPanel.size + (4,4)` 동적 갱신 (resized 시그널 구독). UI_GUIDE §3.3 노드 트리는 MainPanel 안 부분이 1:1 유지됨.
  - **Chip** (PanelContainer pill): sticker shadow sm (2,2)만 적용 — `Control` 루트 + ShadowBG ColorRect (2,2 offset) + MainPanel(PanelContainer). 동일 패턴.
  - **CButton**: Theme의 Button StyleBoxFlat이 shadow_offset=(4,4)를 가지나 blur 강제. UI_GUIDE §1.6 정책에 따라 별도 자식 ColorRect로 hard-edge shadow 처리 — `Control` 루트 + ShadowBG + Button(content).
- **Focus halo z-order** — SkillSlot의 FocusHalo는 모든 자식 위에 그려야 함. `move_child(focus_halo, get_child_count() - 1)` 또는 별도 CanvasLayer.
- **Counter tabular-nums** — Jua가 tabular-nums OpenType feature 지원 X일 가능성. fallback: `BigNumber.label_settings.font_offset_x = ...` 또는 monospace 보조 폰트(JetBrains Mono) 사용. 본 phase에서 결정 후 적용.
- **Counter caPop kill guard (H-1 fix — atom-local 책임)**:
  ```gdscript
  # Counter.gd
  var _capop_tween: Tween
  func set_value(n: int) -> void:
      big_number.text = str(n)
      if _capop_tween and _capop_tween.is_valid():
          _capop_tween.kill()
      _capop_tween = Motion.caPop(big_number)
  ```
  Motion.gd는 phase 9 freeze 유지 (kill 책임을 캡슐화하지 않음). AtomShowcaseHeadless에서 set_value 연속 3회 → `_capop_tween.is_valid()`가 마지막 1개만 true (이전 2개 kill 확인).
- **Motion 호출자 free 타이밍** — 노드가 tree에서 제거될 때 진행 중 tween이 자동 정리되는지 (Godot 4.x: `create_tween(node)` 사용 시 자동, 안 쓰면 수동 kill 필요). 본 phase atom들은 `node.create_tween()` 패턴(Motion.gd가 이미 그렇게 작성됨)만 사용 → 자동 정리됨.
- **Pause 호환** — Motion 호출자가 모달 등 `PROCESS_MODE_ALWAYS`일 때 tween도 항상 동작. 인-게임 atom은 `PROCESS_MODE_INHERIT`로 pause 시 정지.
- **CButton/SkillSlot boop position drift (R2-M1 fix, R3-L1 sweep)** — Motion.boop은 phase 9 freeze (kill guard 미내장). 연속 호출 시 kill만 하면 prior tween이 mid-bounce에서 멈추고 새 boop이 그 어긋난 위치를 base로 캡처 → 영구 drift. **호출자(atom)가 stable base를 자체 보관·복원**: `_boop_base: Vector2` 필드 + `if active: kill+snap to _boop_base; else: capture _boop_base = position` 패턴. `_on_boop_finished`(CONNECT_ONE_SHOT)에서 `_boop_tween=null` → 다음 호출은 base 재캡처. AtomShowcaseHeadless가 5 rapid press 후 final position == baseline 회귀 자동 검증 (CButton + SkillSlot._main_bg 둘 다).
- **SkillSlot empty/disabled 차이** — empty(count=0)는 시각만 회색이고 클릭 가능(count 부족 알림 sound hook). disabled(stage 종료 등)는 input ignore. 두 state 분리 필수. impl 단계에서 UI_GUIDE §3.4에 `Button.disabled` 컬럼 추가 + 두 state 분리 1문단 명문화 (R2-M2).
- **export var vs constant** — atom export 변수는 인스펙터에서 노출, Tokens.gd 상수는 코드에서만. 색깔/크기는 Tokens.gd 상수, 텍스트/숫자는 export.
- **Chip API freeze (M-2 fix)** — `Chip.set_label_value(label: String, value: String)` 메서드는 UI_GUIDE §3.2(시각 spec만 정의)에 없는 **phase 10 신규 API**. 본 phase 10 완료 시점에 atom API 표(§"Phase 11~12 사용 API")의 일부로 freeze. **본 phase 안에서** UI_GUIDE §3.2를 동기 갱신 (set_label_value 시그니처 + tint export 추가) — UI_GUIDE는 atom phase의 SoT이므로 atom 신설과 함께 SoT 진화는 정상 절차. 산출물의 "수정" 목록에 `docs/UI_GUIDE.md` 명시.

## 6. 산출물 요약

```
신규:
  scripts/ui/atoms/{CButton,Chip,Counter,SkillSlot}.gd
  scenes/ui/atoms/{CButton,Chip,Counter,SkillSlot}.tscn
  tests/AtomShowcaseTest.tscn + AtomShowcaseTest.gd            ← 수동 시각 데모
  tests/AtomShowcaseHeadless.tscn + AtomShowcaseHeadless.gd    ← 헤드리스 시그널/tween 검증
  tests/test_{Tokens,CButton,Chip,Counter,SkillSlot}.gd        ← TDD guard stub (기존 convention)

수정:
  scripts/ui/Tokens.gd        ← TintKind enum + TINT_BG/TINT_BORDER 디셔너리 추가 (phase 9 위에 atom-needed 확장 — M-4)
  docs/UI_GUIDE.md            ← §3.2 Chip set_label_value 시그니처 + tint export 추가 (M-2), §3.4 nested tree + Button.disabled 컬럼 추가 (R1-M1 / R2-M2)
  scripts/run_test.py         ← docstring "Fresh clone bootstrap" 섹션 추가 (R1-L2 — `godot --headless --path . --import` 안내)

미수정 (회귀 게이트):
  scripts/ui/Motion.gd, theme/candyants.tres,
  scenes/ui/HUD.tscn, scenes/ui/SkillToolbar.tscn,
  scripts/ui/HUD.gd, scripts/ui/SkillToolbar.gd
```

## 7. Phase 5~8 입력 파이프라인과의 호환성

- atoms는 input 호출자(SkillToolbar.gd 등)와 무관. 본 phase는 atom 단독 검증만.
- CButton/SkillSlot의 `pressed` 시그널은 Godot Button 기본 시그널. **phase 11에서** SkillToolbar/HUD가 atom을 인스턴스화하면서 EventBus.action_triggered / InputRouter와 연결. 본 phase에서는 atoms가 EventBus 직접 구독 X (atom은 dumb, 외부에서 메서드 호출).
- AtomShowcaseTest는 입력 파이프라인 외부에서 직접 `Input.action_press()` 등을 호출하지 않음. Showcase 내에서만 mouse hover/click 인터랙션 확인.

## 8. Phase 11~12가 사용할 atom API (계약 — phase 10 freeze 대상)

| atom | 외부에서 호출하는 메서드/시그널 | export |
|---|---|---|
| CButton | `pressed` 시그널 (Godot 기본) | `kind: ButtonKind { PRIMARY, SECONDARY, GHOST }` |
| Chip | `set_label_value(label: String, value: String)` | `label`, `value`, `tint: TintKind` |
| Counter | `set_value(n: int)` | `kind: CounterKind`, `top_label_en: String`, `bottom_label_ko: String` |
| SkillSlot | `set_count(n: int)`, `set_selected(b: bool)`, `pressed` 시그널 | `skill_id: StringName`, `hotkey: String` |
| Motion (phase 9 freeze) | static `caPop/boop/idle_bob/fade_in/fade_out` | — |

> 본 atom API 표는 **phase 10 완료 시점에 freeze**. phase 11~12에서 인터페이스 추가가 필요해지면 phase 10 sweep commit으로 처리하고 본 표를 동기 갱신. Motion 시그니처는 phase 9 freeze 대상이므로 별개 sweep 절차.
> Phase 11 진입 시 user가 `SkillSlot.set_disabled_state(b: bool)` 1개를 SkillSlot.gd에 추가 — phase 11 plan에서 freeze 확장으로 명시 처리 (phase 10 commit 5721b15 이후 user edit).

## 9. 표준 절차

plan codex 리뷰 (CRITICAL/HIGH=stop & report) → 구현 → 헤드리스+수동 검증 → self-review + codex impl-review 사이클 (clean까지) → complete. 명세 SoT는 `docs/UI_GUIDE.md` §3·§4.

---

## 10. 실행 결과 (commit 5721b15, 2026-05-17)

- **Plan codex**: STOP (HIGH 1: caPop kill mismatch w/ frozen Motion) → user Option A → in-plan absorption.
- **Impl codex Round 1**: NEEDS-ATTENTION (0H/4M/2L) → 모두 fix.
- **Impl codex Round 2**: NEEDS-ATTENTION (0H/2M) → 모두 fix (R2-M1 boop drift 완전 차단 + R2-M2 UI_GUIDE empty/disabled 명문화).
- **Impl codex Round 3**: NEEDS-ATTENTION (0H/0M/1L) → R3-L1 sweep (본 plan §"엣지 케이스 boop drift" 동기 갱신).
- **5 verify gates 전수 PASS**: AtomShowcaseHeadless · MotionPauseSafeTest · SvgImportSmokeTest · Stage03HeadlessTest · BlockerOverlapTest.
- **리뷰 보존**: `phases/mvp/reviews/phase10-review.md` (plan), `phases/mvp/reviews/phase10-impl-review.md` (Self-Review 1~3 + codex Round 1~3 누적).
- **Notion phase 10**: 진행 중 → 완료.

본 v4 plan은 commit 5721b15 시점의 SoT snapshot. 향후 phase 10 sweep 발생 시 본 plan v5+로 누적 갱신.
