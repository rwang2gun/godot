---
name: ui-hud-toolbar-replace
duration_estimate: 7200
verify: ""
---

# Phase 11: HUD / SkillToolbar 씬 교체 (atoms 인스턴스화)

## 목표
`scenes/ui/HUD.tscn`, `scenes/ui/SkillToolbar.tscn`을 phase 9 atom들의 인스턴스로 재구성한다. **`.gd` 스크립트는 노드 경로/시그널 계약만 보존하면 거의 무수정**.

## 전제
- Phase 8 (Theme + 에셋) + Phase 9 (atoms + Motion) 완료
- Phase 5~7(input layer) 완료 — `SkillToolbar.gd`가 `EventBus.action_triggered`로 마이그레이션된 상태
- `docs/UI_GUIDE.md` §3 (atom 카탈로그) + handoff `ui_kits/game/{HUD,SkillToolbar}.jsx`, `preview/skill_toolbar.html` 시각 SoT

## 변경 대상

### 교체
- `scenes/ui/HUD.tscn` — placeholder Label들 → atom 인스턴스로 교체
- `scenes/ui/SkillToolbar.tscn` — 빈 HBoxContainer → SkillSlot × 8 인스턴스화

### 수정 (최소)
- `scripts/ui/HUD.gd` — `@onready` 노드 경로만 갱신. `EventBus.candy_hp_changed` 등 시그널 구독 그대로. atom 메서드 호출(`counter.set_value(n)`)로 대체.
- `scripts/ui/SkillToolbar.gd` — `@onready` 슬롯 배열 경로 갱신. `_on_action_triggered`(phase 5에서 이전됨) 핸들러 그대로. SkillSlot 메서드 호출(`slot.set_count`, `slot.set_selected`)로 대체.
- `scripts/ui/InputHintLabel.gd` (phase 7에서 추가됨) — 새 HUD 트리에서 위치 조정만.

### 비-변경
- `scripts/core/EventBus.gd` — 본 phase에서 추가하는 시그널 3종 외 변경 0
- `scripts/skills/*.gd`, `scripts/core/SkillRegistry.gd` — 무관
- `scripts/input/*` (phase 5~7) — 무관

## HUD 레이아웃 (1920×1080 기준, safe-area 32px)

```
HUD.tscn (CanvasLayer)
├─ TopLeft (HBoxContainer @ position 32,32, separation 12)
│  ├─ Counter[CANDY_HP]
│  ├─ Counter[IN_TRANSIT]
│  ├─ Counter[SAVED]
│  └─ Counter[LOST]
├─ TopRight (HBoxContainer @ anchor_right=1, position -32,32, separation 12)
│  ├─ Counter[TIME]
│  ├─ ReleaseRateStepper (HBoxContainer)
│  │  ├─ CButton[GHOST] "−"  (28×28)
│  │  ├─ Label "12"          (Jua 24, ink_900, tabular)
│  │  └─ CButton[GHOST] "+"  (28×28)
│  └─ CButton[GHOST] PauseBtn (56×56, icon = Lucide pause SVG)
└─ InputHintLabel (BottomCenter above SkillToolbar, phase 7 산출물)
```

**ReleaseRateStepper**:
- range 1~99, step 5, 기본 12 (StageData에서 로드)
- −/+ 클릭 → `EventBus.release_rate_changed_request(delta: int)` emit (신규 시그널)
- StageRunner가 받아서 처리 후 기존 `EventBus.release_rate_changed(new_rate)` 발화 → HUD가 Label 갱신

**PauseBtn**:
- toggle. `EventBus.pause_toggled_request` emit (신규 시그널)
- GameManager가 받아서 `get_tree().paused = !paused` 처리 후 기존 `EventBus.pause_toggled(b)` 발화

> 신규 EventBus 시그널 3종은 본 phase 범위. SkillToolbar의 action_triggered와 동일 패턴(요청-응답 분리).

## SkillToolbar 레이아웃

```
SkillToolbar.tscn (Control, anchor bottom=1, height=140)
├─ Background (ColorRect cream_200 + 3px ink_900 top border)
└─ HBoxContainer (centered, separation 14, padding 32)
   ├─ SkillSlot[climber]  (hotkey 1, skill_id from SkillRegistry)
   ├─ SkillSlot[floater]  (hotkey 2)
   ├─ SkillSlot[bomber]   (hotkey 3)
   ├─ SkillSlot[blocker]  (hotkey 4)
   ├─ SkillSlot[builder]  (hotkey 5)
   ├─ SkillSlot[basher]   (hotkey 6)
   ├─ SkillSlot[miner]    (hotkey 7)
   └─ SkillSlot[digger]   (hotkey 8)
```

- 슬롯 순서는 `SkillRegistry.SKILL_ORDER` const로 명시 (코드 SoT, INPUT_MAPPING.md 1~8 hotkey와 1:1)
- 슬롯의 `skill_id`는 인스펙터에서 박는 게 아니라 `SkillToolbar.gd._ready()`에서 SKILL_ORDER 순회하며 set

## 검증 방법

### 자동 (헤드리스)
1. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS — Stage 1~3 회귀 0
2. `python scripts/run_test.py tests/Stage02HeadlessTest.tscn` PASS
3. `python scripts/run_test.py tests/InputRouterTest.tscn` PASS — phase 5 회귀 (action 시그널이 atom에 정확히 도달)
4. `python scripts/run_test.py tests/PadInputTest.tscn` PASS — phase 6 회귀
5. 신규 `tests/HudCounterRegressionTest.tscn` — `EventBus.candy_hp_changed(5)` emit → Counter[CANDY_HP] big_number 텍스트 = "5" 검증

### 수동
1. Stage01~03 마우스 풀 플레이 — 카운터 4개 정상 갱신, caPop motion 발화, 스킬 부여/취소/사이클 정상
2. Stage01~03 패드 풀 플레이 — 동일 + focus halo 표시 + B 취소 + LB/RB 슬롯 사이클
3. Release rate stepper −/+ 둘 다 동작, 1/99 경계 clamp, Jua 24 색 ink_900
4. Pause btn 토글 → backdrop은 phase 11 작업이므로 본 phase는 시각 변화 0이지만 paused state 정확히 토글
5. handoff `preview/skill_toolbar.html` 캡처 vs Godot Stage01 캡처 — atom 토큰값(컬러/spacing/radii) 일치

## 엣지 케이스 (필수)

- **VirtualCursor z-order** (phase 6 산출물) — 항상 toolbar/HUD 위에. CanvasLayer.layer: HUD/Toolbar = 10, Cursor = 100.
- **Stage 종료 시 toolbar disable** — `EventBus.stage_cleared`/`failed` 수신 → 모든 SkillSlot.set_disabled(true). 본 phase 범위.
- **InputHintLabel 위치** — toolbar height 140px 위쪽. 새 트리에서 anchor 재계산.
- **Stepper 빠른 클릭** — −/+ 버튼 boop motion 동안 입력 누적 OK (step 5라 시각 안 깨짐).
- **Counter 값 0** — `set_value(0)` 호출 시 BigNumber "0" + caPop. 빈 문자열 X.
- **SkillSlot count=0 클릭** — `_pressed`에서 `if count == 0: EventBus.skill_empty.emit(id); return`. action 발화 0.
- **1280×720 vs 1920×1080** — atom 사이즈는 px fixed. anchor만 사용. 1280×720에서 HUD가 toolbar와 12px 이상 띄워지는지 시각 확인.
- **Theme override 금지** — 본 phase에서 `theme_override_*` 0건. 파일 내 grep으로 강제 (CI 스크립트 1줄 권장).
- **신규 시그널의 idempotency** — `pause_toggled_request` 두 번 빠르게 → 두 번 토글되어 원상복구 OK. debounce X.

## 신규 EventBus 시그널 (본 phase 범위)
```gdscript
# scripts/core/EventBus.gd 추가
signal release_rate_changed_request(delta: int)   # HUD → StageRunner
signal pause_toggled_request                       # HUD → GameManager
signal skill_empty(skill_id: StringName)          # SkillSlot → (post-MVP sound)
```
> 기존 `release_rate_changed`, `pause_toggled`, `candy_hp_changed`, `ant_in_transit_changed`, `ant_saved`, `ant_lost`, `time_changed` 등은 그대로 사용.

## 산출물 요약

```
scenes/ui/HUD.tscn                       ← 교체
scenes/ui/SkillToolbar.tscn              ← 교체
scripts/ui/HUD.gd                        ← @onready 경로 + atom 메서드
scripts/ui/SkillToolbar.gd               ← @onready 경로 + atom 메서드
scripts/ui/InputHintLabel.gd             ← 위치 조정
scripts/core/EventBus.gd                 ← 시그널 3개 추가
tests/HudCounterRegressionTest.tscn      ← 신규
```

## Phase 11 (StageDialog)이 사용할 인터페이스 (계약)
- HUD/Toolbar는 `EventBus.stage_cleared`/`failed` 수신 시 모든 SkillSlot disable. 본 phase에서 처리.
- StageDialog는 phase 11에서 새로 띄움. HUD/Toolbar는 dialog가 떠도 여전히 보이지만 disabled.

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md`. 시각 명세는 `docs/UI_GUIDE.md` §3 + `docs/design_handoff/preview/skill_toolbar.html` SoT.
