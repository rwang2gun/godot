---
name: ui-atoms-foundation
duration_estimate: 7200
verify: ""
---

# Phase 9: UI Atoms Foundation (CButton · Chip · Counter · SkillSlot · Motion)

## 목표
Theme 위에 4개 atom을 Custom Control로 만든다 + Motion 헬퍼 정적 클래스를 만든다. **HUD/Toolbar 씬 교체는 안 함** — 본 phase는 atoms 단위 단독 검증만.

## 전제
- Phase 8 완료 (Theme + Tokens.gd + 폰트 + SVG 임포트)
- `docs/UI_GUIDE.md` §3 (Atom 카탈로그) + §4 (Motion 시그니처) 1차 SoT
- atoms 단독 검증용 데모 씬으로 시각/단위 검증, 헤드리스로 시그널 검증

## 변경 대상

### 신규 파일
**Atoms** (`scripts/ui/atoms/` + `scenes/ui/atoms/`):
- `CButton.gd` + `CButton.tscn` — `class_name CButton extends Button`. export `kind: ButtonKind { PRIMARY, SECONDARY, GHOST }`. `pressed` 시 `Motion.boop(self)` 자동 호출.
- `Chip.gd` + `Chip.tscn` — pill 스타일 정보 태그. export `label: String`, `value: String`, `tint: TintKind { PEACH, GRAPE, MINT, BERRY, LEMON }`.
- `Counter.gd` + `Counter.tscn` — 110×84. export `kind: CounterKind` (Tokens.gd enum), `top_label_en: String`, `bottom_label_ko: String`. 메서드 `set_value(n: int)` 호출 시 `Motion.caPop(big_number)` 자동.
- `SkillSlot.gd` + `SkillSlot.tscn` — 88×88. export `skill_id: StringName`, `hotkey: String`. 메서드 `set_count(n: int)`, `set_selected(b: bool)`. 8 state matrix(armed/selected/hover/pressed/empty/disabled).

**Motion** (`scripts/ui/Motion.gd`) — **시그니처 freeze 대상**:
- `class_name Motion extends RefCounted` — 정적 헬퍼
- `static caPop(node: CanvasItem) -> Tween` (scale .8→1.08→1.0, 220ms, TRANS_BACK + EASE_OUT)
- `static boop(node: Control) -> Tween` (position 진동, 120ms 선형)
- `static idle_bob(node: CanvasItem, amplitude: float = 1.03, period: float = 1.6) -> Tween` (loop, SINE in_out)
- `static fade_in(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween` — `pause_safe=true` 시 **`Tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)`** 적용 → SceneTree.paused 상태에서도 진행 (Godot 4 정확한 API)
- `static fade_out(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween` — 동일 정책

**Pause-safe 정확한 구현 (Godot 4)**:
```gdscript
static func fade_in(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween:
    var t := node.create_tween()
    if pause_safe:
        t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # NOT TWEEN_PROCESS_IDLE (그건 idle vs physics 선택일 뿐)
    node.modulate.a = 0.0
    t.tween_property(node, "modulate:a", 1.0, duration)
    return t
```

> **Pause-safe 헤드리스 검증 (phase 9 mandatory)**:
> 신규 `tests/MotionPauseSafeTest.gd` — `get_tree().paused = true` → `Motion.fade_in(node, 0.05, true)` 호출 → `await get_tree().create_timer(0.1, false, true).timeout` (paused 모드에서도 tick하는 timer) → `node.modulate.a == 1.0` 검증. 또한 `pause_safe=false` 동일 호출 시 `modulate.a < 1.0`(정지) 검증. 두 케이스 모두 PASS여야 phase 9 complete 가능.

> **Freeze 정책 (phase 9 완료 시)**: 위 5개 시그니처는 phase 11/12 호출자가 변경 없이 그대로 사용. 추가 시그니처/인자 필요 시 phase 9 sweep commit으로 처리. UI_GUIDE.md §4와 1:1 일치.

**시각 데모 씬**:
- `tests/AtomShowcaseTest.tscn` + `.gd` — 4 atom × state 매트릭스를 한 화면에 배치. 패드/마우스 둘 다 인터랙션. 헤드리스에서는 시각 검증 X, 시그널 emit/노드 트리 정합만.

**시그널 데모 헬퍼** (헤드리스 검증용):
- `tests/AtomShowcaseHeadless.gd` — Counter.set_value 호출 시 caPop tween이 생성되는지, CButton pressed 시 boop tween 생성되는지 instantiation 검증.

### 수정
- `scripts/ui/Tokens.gd` (Phase 8에서 생성됨) — `TintKind` enum + `TINT_BG`/`TINT_BORDER` 디셔너리 추가 (Chip atom용).

### 비-변경 (중요)
- `scenes/ui/HUD.tscn`, `SkillToolbar.tscn` — 본 phase 미수정 (phase 10에서 atom 인스턴스화)
- 기존 `scripts/ui/HUD.gd`, `SkillToolbar.gd` — 본 phase 미수정

## 검증 방법

### 자동 (헤드리스)
1. `python scripts/run_test.py tests/AtomShowcaseHeadless.gd` 신규 — 4 atom 각자 instantiate + property 변경 + tween 생성 검증. 1초 이내 종료.
2. `python scripts/run_test.py tests/MotionPauseSafeTest.gd` 신규 — Motion.fade_in/out의 pause_safe 옵션이 `TWEEN_PAUSE_PROCESS`로 설정되어 paused tree에서 진행 / pause_safe=false 시 정지 두 케이스 모두 검증. **본 테스트 PASS는 phase 9 complete 강제 조건** — pause_safe contract가 phase 11에서 사용되기 전에 보장.
3. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS — 회귀 0.
4. `python scripts/run_test.py tests/BlockerOverlapTest.tscn` PASS — 회귀 0.

### 수동 (에디터)
1. `tests/AtomShowcaseTest.tscn` 실행 — 4 atom 모든 state 시각 확인:
   - CButton: PRIMARY(peach_500) / SECONDARY(cream_100) / GHOST(transparent), hover translate y-2, press boop
   - Chip: 5 tint × `귀가 8` 같은 KO+숫자 조합
   - Counter: 5 kind 모두 표시, `set_value(n+1)` 누를 시 caPop 발화
   - SkillSlot: 8 state 모두 시각 확인. count=0 → empty(saturate30%), selected→peach_300 outline
2. 패드 연결 → focus halo (3px mint_500 outline 4px offset)가 SkillSlot에 표시되는지
3. handoff `preview/skill_toolbar.html`, `preview/dialog.html` 브라우저 캡처와 atom 단위 시각 비교

## 엣지 케이스 (필수)

- **Sticker shadow duplicate 자식 노드 위치** — atom 루트는 `Control` 또는 `PanelContainer`, 첫 자식이 ShadowBG (StyleBoxFlat 4,4 offset ink_900 fill, 같은 크기/radius). 두번째 자식이 MainBG. 순서 어기면 shadow가 위로 올라감.
- **Focus halo z-order** — SkillSlot의 FocusHalo는 모든 자식 위에 그려야 함. `move_child(focus_halo, get_child_count() - 1)` 또는 별도 CanvasLayer.
- **Counter tabular-nums** — Jua가 tabular-nums OpenType feature 지원 X일 가능성. fallback: `BigNumber.label_settings.font_offset_x = ...` 또는 monospace 보조 폰트(JetBrains Mono) 사용. 본 phase에서 결정 후 적용.
- **Motion.caPop 재호출** — 카운터가 빠르게 여러 번 변동할 때 tween 누적 → 시각 깨짐. `Motion.caPop`는 매 호출 시 기존 tween을 `kill()` 후 새로 생성.
- **Motion 호출자 free 타이밍** — 노드가 tree에서 제거될 때 진행 중 tween이 자동 정리되는지 (Godot 4.x: `create_tween(node)` 사용 시 자동, 안 쓰면 수동 kill 필요). 본 phase는 `node.create_tween()`만 사용.
- **Pause 호환** — Motion 호출자가 모달 등 `PROCESS_MODE_ALWAYS`일 때 tween도 항상 동작. 인-게임 atom은 `PROCESS_MODE_INHERIT`로 pause 시 정지.
- **CButton boop 시 position drift** — boop이 Vector2(2,2) → 0이지만 동시 발화 시 base position이 흐트러짐. base를 `node.position` 캡처 후 매 호출 시 0으로 reset.
- **SkillSlot empty/disabled 차이** — empty(count=0)는 시각만 회색이고 클릭 가능(count 부족 알림 sound hook). disabled(stage 종료 등)는 input ignore. 두 state 분리 필수.
- **export var vs constant** — atom export 변수는 인스펙터에서 노출, Tokens.gd 상수는 코드에서만. 색깔/크기는 Tokens.gd 상수, 텍스트/숫자는 export.

## 산출물 요약

```
scripts/ui/atoms/{CButton,Chip,Counter,SkillSlot}.gd
scripts/ui/Motion.gd
scripts/ui/Tokens.gd                  ← TintKind enum + 디셔너리 추가 (phase 8 위에)
scenes/ui/atoms/{CButton,Chip,Counter,SkillSlot}.tscn
tests/AtomShowcaseTest.tscn + .gd
tests/AtomShowcaseHeadless.gd
```

## Phase 5~7과의 호환성
- atoms는 input 호출자(SkillToolbar.gd 등)와 무관. 본 phase는 atom 단독 검증만.
- 단, CButton/SkillSlot은 phase 10에서 SkillToolbar/HUD가 인스턴스화하면서 EventBus.action_triggered와 연결됨. 본 phase에서는 atoms가 EventBus 직접 구독 X (atom은 dumb, 외부에서 메서드 호출).

## Phase 10~11이 사용할 atom API (계약)
| atom | 외부에서 호출하는 메서드/시그널 |
|---|---|
| CButton | `pressed` 시그널 (Godot 기본), `kind` export |
| Chip | `set_label_value(label, value)`, `tint` export |
| Counter | `set_value(n)`, `kind` export |
| SkillSlot | `set_count(n)`, `set_selected(b)`, `pressed` 시그널, `skill_id`/`hotkey` export |
| Motion | static caPop/boop/idle_bob/fade_in/fade_out |

> 본 계약을 phase 9 완료 시 freeze. phase 10에서 인터페이스 추가 필요 시 phase 9로 회귀 수정 (sweep).

## 표준 절차
phase 시작 시 plan 작성 → `/codex:adversarial-review` → 구현 → 헤드리스+수동 검증 → impl review → complete. 명세 SoT는 `docs/UI_GUIDE.md` §3·§4.
