# UI Guide — Theme · Atoms · Motion · Save

> CandyAnts UI 1차 SoT. Phase 8(theme-assets) ~ 12(title-menu) 구현은 본 문서 + `docs/design_handoff/`를 함께 본다.
> 본 문서가 우선 — handoff와 충돌하면 본 문서가 결정. 핸드오프는 시각 레퍼런스(SVG/HTML/JSX) SoT.

## 0. 위치와 책임

```
docs/
├── UI_GUIDE.md                       ← 본 문서 (1차 SoT)
└── design_handoff/                   ← git-tracked, 디자인 시스템 패키지
    ├── README.md                     컬러/타입/스페이싱/모션 + Godot Theme 매핑 권장안
    ├── SYSTEM_README.md              디자인 철학 + 보이스/카피 가이드
    ├── colors_and_type.css           CSS 토큰 단일 SoT
    ├── assets/                       SVG (skills 8 / sprites 12 / logo 3 / illustrations 1)
    ├── preview/                      19개 HTML 시각 명세
    └── ui_kits/game/                 React/JSX 인터랙티브 프로토타입
```

**Phase 시작 시 read 강제 대상**: `PRD.md` / `ARCHITECTURE.md` / `ADR.md` / `UI_GUIDE.md`(본 문서, UI phase에 한해).

## 1. 디자인 토큰 (Godot Color() 매핑)

### 1.1 Cream / Ink (foundation)
| 토큰 | sRGB hex | `Color()` linear | handoff oklch | 용도 |
|---|---|---|---|---|
| `cream_50`  | `#FBF8F1` | `Color(0.984, 0.973, 0.945)` | `oklch(0.985 0.012 75)` | 페이지 bg (`--bg`) |
| `cream_100` | `#F5EFE3` | `Color(0.961, 0.937, 0.890)` | `oklch(0.965 0.020 70)` | 카드 표면 |
| `cream_200` | `#E9DFCB` | `Color(0.914, 0.875, 0.796)` | `oklch(0.93 0.030 70)`  | 음각 표면 |
| `cream_300` | `#D9C9AC` | `Color(0.851, 0.788, 0.675)` | `oklch(0.88 0.040 65)`  | 헤어라인 디바이더 |
| `ink_900`   | `#3A2A1C` | `Color(0.227, 0.165, 0.110)` | `oklch(0.26 0.045 50)`  | 본문 텍스트 + 외곽선 |
| `ink_700`   | `#5C4530` | `Color(0.361, 0.271, 0.188)` | `oklch(0.40 0.060 50)`  | 보조 텍스트 |
| `ink_500`   | `#8C7660` | `Color(0.549, 0.463, 0.376)` | `oklch(0.58 0.045 55)`  | 3차 / disabled |

> oklch 컬럼은 SVG 정규화(scripts/tools/svg_color_map.json) 의 sanity invariant SoT — handoff oklch가 본 표 oklch와 1:1 매칭 시 토큰 hex 사용.

### 1.2 Brand / Semantic
| 토큰 | hex | handoff oklch | 용도 (변경 금지) |
|---|---|---|---|
| `peach_300` | `#FAD9C4` | `oklch(0.90 0.08 35)`  | primary tint |
| `peach_500` | `#F2A48F` | `oklch(0.78 0.155 28)` | **PRIMARY** · candy HP 카운터 |
| `peach_700` | `#D17A60` | `oklch(0.62 0.165 30)` | primary press |
| `mint_300`  | `#D4F0E5` | `oklch(0.92 0.07 175)` | success tint |
| `mint_500`  | `#9ED9C2` | `oklch(0.82 0.13 175)` | **SUCCESS** · saved 카운터 |
| `mint_700`  | `#5EA88A` | `oklch(0.60 0.13 175)` | success press / **gamepad focus halo** |
| `berry_300` | `#F7C9C4` | `oklch(0.86 0.10 10)`  | danger tint |
| `berry_500` | `#E48579` | `oklch(0.70 0.20 15)`  | **DANGER** · lost 카운터 |
| `berry_700` | `#B85546` | `oklch(0.55 0.20 15)`  | danger press |
| `lemon_300` | `#FCEFC2` | `oklch(0.95 0.10 95)`  | warn tint |
| `lemon_500` | `#F0D77B` | `oklch(0.88 0.16 95)`  | **WARN** · 별점 fill |
| `lemon_700` | `#C9A93C` | `oklch(0.72 0.16 90)`  | **time 카운터 색** |
| `grape_300` | `#DCCEE2` | `oklch(0.88 0.07 300)` | info tint |
| `grape_500` | `#B49AC5` | `oklch(0.72 0.14 300)` | **INFO** · in-transit 카운터 |
| `grape_700` | `#7E5A9A` | `oklch(0.55 0.14 300)` | info press (handoff `--grape-700`) |
| `sky_300`   | `#CCDFEA` | `oklch(0.92 0.05 235)` | stage 하늘 (handoff `--sky-300`, illustration 전용) |
| `grass_300` | `#B0DCB4` | `oklch(0.88 0.07 140)` | stage 풀잎 (handoff `--grass-300`, illustration 전용) |

### 1.3 카운터 색 고정 매핑 (Phase 9 atoms에서 enum 강제)
```gdscript
enum CounterKind { CANDY_HP, IN_TRANSIT, SAVED, LOST, TIME }
const COUNTER_COLOR := {
    CounterKind.CANDY_HP   : Color("#F2A48F"),   # peach_500
    CounterKind.IN_TRANSIT : Color("#B49AC5"),   # grape_500
    CounterKind.SAVED      : Color("#9ED9C2"),   # mint_500
    CounterKind.LOST       : Color("#E48579"),   # berry_500
    CounterKind.TIME       : Color("#C9A93C"),   # lemon_700
}
```

### 1.4 타이포
| 토큰 | 패밀리 | 라이센스 | 용도 |
|---|---|---|---|
| `font_display` | **Jua** Regular | OFL 1.1 | 타이틀, 큰 카운터, 버튼 |
| `font_body`    | **Gaegu** Bold | OFL 1.1 | 본문, 다이얼로그 설명 |
| `font_mono`    | JetBrains Mono | OFL 1.1 | 디버그 오버레이 전용 |

**사이즈 (px)**: 12 / 14 / 16 / 20(default) / 24 / 32 / 44 / 64 / 96
**Line-height**: tight 1.05 · snug 1.20 · body 1.45

> **Substitution flag** — Jua/Gaegu는 placeholder. 팀 최종 픽 결정 시 Theme 1군데만 교체하면 끝. Cafe24 Ohsquare / Pretendard Variable / BMHanna 후보.
> 라이센스 동봉 위치: `assets/fonts/LICENSE.txt` (각 폰트 OFL 원문 포함, phase 8에서 작성).

### 1.5 Spacing / Radii / Stroke
- **Spacing (8 base)**: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96 + `safe_area = 32`
- **Radii**: sm 8 · md 12 · lg 16 · xl 20 · 2xl 24 · pill 999
- **Stroke**: 모든 인터랙티브 요소 **3px ink_900 외곽선** (브랜드 시그니처)

### 1.6 Sticker Shadow (브랜드 시그니처)
- **sm**: offset (2,2), color ink_900, alpha 1.0, blur **0**
- **default**: offset (4,4), color ink_900, alpha 1.0, blur **0**
- **lg**: offset (6,6), color ink_900, alpha 1.0, blur **0**
- **card-soft** (다이얼로그/level card): offset (0,8), color ink_900 alpha 0.35, blur 0
- **gloss inset** (filled button): inset top 4px, color white alpha 0.45

> Godot 제약: `StyleBoxFlat.shadow_*`는 **항상 blur** 발생 → hard-edge 못 만듦. **Phase 8 결정**:
> | 표면 | 그림자 구현 |
> |---|---|
> | Button / SkillSlot / Counter / Chip | **duplicate StyleBoxFlat 레이어** (Control 자식 BG로 4px offset ink_900 fill) |
> | StageDialog / TitleScene LogoPanel | **NinePatchRect** (4px ink offset 9-patch) |
> | Home hatch sprite | `Sprite2D._draw()` override로 ink rect 미리 그림 |

### 1.7 Motion
- **House easing**: `Tween.TRANS_BACK` + `Tween.EASE_OUT` (cubic-bezier(.5,1.5,.5,1) 근사)
- **Durations**: press **120ms** · state **220ms** · celebrate **600ms**
- **No fades for primary feedback** — 스케일/스쿼시만. 페이드는 화면 트랜지션 전용.
- **caPop** (카운터 변동 / 모달 등장): `scale .8 → 1.08 → 1.0` over 220ms (TRANS_BACK + EASE_OUT)
- **press boop** (버튼 누름): `position += (2,2) → +0,0` over 120ms (선형)
- **idle bob** (홈 해치): `scale 1.0 → 1.03 → 1.0` 1.6s loop (TRANS_SINE + EASE_IN_OUT)
- **focus halo** (패드): 3px `mint_500` outline, 4px offset, 항상 표시 (커서 없음)

## 2. Theme 결정 (Phase 8 인스펙터 입력값)

`res://theme/candyants.tres` 한 파일에 모두 박는다. 노드별 override 금지.

### 2.1 Default
```
default_font = preload("res://assets/fonts/Jua-Regular.ttf")
default_font_size = 20
default_color = Color("#3A2A1C")              # ink_900
```

### 2.2 Button StyleBoxFlat (4 state)
| state | bg_color | border | radius | content_margin (v,h) | extra |
|---|---|---|---|---|---|
| normal   | `peach_500` `#F2A48F` | 3 ink_900 | 16 | (10, 22) | gloss inset (white α0.45 top 4px via 자식 ColorRect) |
| hover    | `peach_500`           | 3 ink_900 | 16 | (10, 22) | translate y -2 (Control offset) |
| pressed  | `peach_700` `#D17A60` | 3 ink_900 | 16 | (10, 22) | shadow → sm offset (2,2), gloss 8% darker |
| disabled | `#C8B5A6` (peach 60% sat) | 3 ink_900 | 16 | (10, 22) | font_color α 0.6 |

### 2.3 Panel StyleBoxFlat (카드 / 다이얼로그)
- bg: `cream_100` `#F5EFE3`
- border: 3 ink_900
- radius: 24 (다이얼로그) / 16 (카드)

### 2.4 LineEdit / SpinBox / CheckButton
- 모두 border 3 ink_900, radius 8~12, bg `cream_100`. 상세는 `docs/design_handoff/preview/buttons.html` 참조.

### 2.5 SVG 임포트 설정 (project.godot 또는 .import)
- `svg/scale = 1.0`
- `compress/mode = 0` (lossless)
- `flags/filter = true` (anti-alias on)
- `flags/mipmaps = true` (스케일 변동 대비)
- `process/fix_alpha_border = true`

### 2.6 SVG 정규화 정책 (Phase 8 강제)

**문제**: `docs/design_handoff/assets/`의 SVG들은 다음 4가지 Godot 비호환 요소 보유:
1. `oklch(L C H)` 색 함수 — Godot 4 SVG 임포터 미지원
2. 외부 정의 없는 `class="..."` 속성 — `<defs><style>` 비어있음
3. **토큰 외 literal hex** — mascot/icon에 `#2a1f18`, `#3a2418`, `#fce6d2` 등 ink/cream 변종 다수
4. `rgba(255,255,255,...)` — gloss highlight용 (Godot OK, 그대로 통과)

**해결**: phase 8에서 `scripts/tools/normalize_svg.py` + `scripts/tools/svg_color_map.json`으로 변환 후 `assets/`에 배치. 매핑 SoT는 svg_color_map.json:
- `oklch_extras`: **토큰 외** oklch 값 → hex 매핑 (토큰 oklch 등록 금지 — sanity invariant)
- `alpha_variants`: 토큰 oklch + alpha 결합형 → rgba()
- `class_map`: class 이름 → 인라인 fill/stroke/stroke-* 매핑
- `literal_color_map`: 토큰 외 literal hex → 가까운 토큰 hex로 rewrite (디자이너 의도 통일)
- `allowed_literals.values`: 토큰 외이지만 그대로 통과시킬 literal 목록 (gloss 등 디자인 의도 보존)
- `rgba_handling.passthrough`: rgba() 그대로 통과 (default true)

**resolve_order 고정**: oklch 매칭은 (1) §1.1·§1.2 토큰 표 우선 → (2) alpha_variants → (3) oklch_extras → (4) CSS Color 4 spec 변환. 토큰 표가 항상 우선이므로 oklch_extras에 토큰 oklch가 등장하면 sanity invariant 위배 → SvgImportSmokeTest fail.

미매핑 발견 시 normalize_svg.py exit 1 → svg_color_map.json 보강 강제.

**정규화 후 검증** (모두 phase 8 complete 차단 조건):
- `grep -RE "oklch\(|class=\"|<style" assets/**/*.svg` → 0건
- `tests/SvgImportSmokeTest.gd` — 모든 production SVG가 (1) 비-blank 텍스처 (≥5% 픽셀) + (2) color sanity가 **모든 색 등장 위치**(fill, stroke, stop-color, flood-color, lighting-color, color, 인라인 `style="..."`의 *-color 선언)에서 hex가 토큰/extras/literal_map/allowed_literals 합집합 부분집합. fill/stroke만 검사하면 stop-color drift를 놓침.

**무엇이 SoT인가**:
- **색 토큰 SoT** = 본 문서 §1.1·§1.2 (hex 사전 변환됨)
- **매핑 SoT** = `scripts/tools/svg_color_map.json` (class/literal/oklch_extras)
- **시각 레퍼런스 SoT** = `docs/design_handoff/preview/*.html` (브라우저 렌더 시 oklch 그대로 작동)
- **게임 런타임 SoT** = `assets/**/*.svg` (정규화 결과)
- `docs/design_handoff/assets/`의 원본 SVG는 디자이너 갱신 입력용. 게임이 직접 로드 X.

**디자이너 갱신 절차**:
1. `docs/design_handoff/assets/`에 새 SVG 덮어쓰기
2. `python scripts/tools/normalize_svg.py --scan docs/design_handoff/assets/` 실행
3. 출력에서 등장한 새 oklch/class/literal/rgba 값 → svg_color_map.json에 매핑 추가
4. `python scripts/tools/normalize_svg.py` 실행 → assets/ 갱신
5. `tests/SvgImportSmokeTest.gd` 실행 → PASS 확인

## 3. Atom 카탈로그 (Phase 9 = ui-atoms-foundation)

각 atom은 `scripts/ui/atoms/<Name>.gd` + `scenes/ui/atoms/<Name>.tscn` 1쌍. 모든 atom은 Theme의 디폴트 스타일 + atom-local override만 사용 (인스턴스별 override X).

### 3.1 `Button` (CButton — `class_name CButton extends Button`)
- Theme의 Button StyleBoxFlat 자동 사용
- export `kind: ButtonKind { PRIMARY, SECONDARY, GHOST }` — bg 변경
  - PRIMARY: peach_500 / hover peach_500+y-2 / pressed peach_700
  - SECONDARY: cream_100 / hover cream_100+y-2 / pressed cream_200
  - GHOST: transparent / hover cream_100 α 0.4 / pressed cream_200 α 0.6
- Press 시 `Motion.boop(self)` 자동 호출

### 3.2 `Chip` (정보 태그 — `귀가 8`, `잃음 2`)
- HBox: 12px Jua label + 14px Jua value
- bg: 카운터 색 tint (peach_300/grape_300/mint_300/berry_300/lemon_300 중)
- border: 2px ink_900, radius 999 (pill), padding (6, 12)

### 3.3 `Counter` (HUD 4 + 1)
- 사이즈: **110×84**
- 노드 트리:
  ```
  Counter (PanelContainer, panel = cream_100 + 3 ink + 16 radius + sticker sm)
  └─ VBoxContainer
     ├─ HBoxContainer  (gap 6)
     │  ├─ ColorDot    (10×10, 카운터 색)
     │  └─ TopLabel    (Jua 12, uppercase, letter-spacing 0.04em)
     ├─ BigNumber      (Jua 32, color = 카운터 색, tabular-nums)
     └─ KoLabel        (Jua 11, ink_700)
  ```
- export `kind: CounterKind` (1.3절 enum)
- 메서드: `set_value(n: int)` — `Motion.caPop(big_number)` 자동 호출

### 3.4 `SkillSlot` (스킬 toolbar 1칸)
- 사이즈: **88×88**
- 노드 트리:
  ```
  SkillSlot (Button + 자식 BG로 sticker shadow)
  ├─ ShadowBG       (StyleBoxFlat 4,4 offset, ink_900)
  ├─ MainBG         (cream_100 / peach_300 selected, 3 ink, 16 radius)
  ├─ Icon           (TextureRect, 56×56 SVG)
  ├─ HotkeyPill     (top-left, 10px JetBrains Mono, white α0.7 pill)
  ├─ CountBadge     (top-right, 13px Jua, ink fill, white text, pill, 2px cream border)
  ├─ KoLabel        (bottom, 11px Jua, "등반"/"낙하산"/...)
  └─ FocusHalo      (3px mint_500 outline, 4px offset, visible on `gui_focus_changed`)
  ```
- 8 states (4 base × 2 hover/press):
  | state | bg | border | filter |
  |---|---|---|---|
  | armed (idle, count > 0) | cream_100 | 3 ink | none |
  | selected | peach_300 | 3 ink | none |
  | hover (armed) | cream_100 | 3 ink | y-2 translate |
  | pressed | peach_300 | 3 ink | sm shadow + boop |
  | empty (count = 0) | cream_100 | 3 ink | saturate 30% + α 0.55 + disabled |
  | disabled (stage 종료 등) | cream_100 | 3 ink | saturate 30% + α 0.55 |
- export `skill_id: StringName` (SkillRegistry ID와 1:1)
- 메서드: `set_count(n: int)`, `set_selected(b: bool)`

### 3.5 `LogoPanel` (Phase 12 title)
- `wordmark.svg` + `mascot.svg` 합성. 1.0 → 1.03 idle bob.

### 3.6 `StageSlotCard` (Phase 12 stage select)
- 사이즈: 200×140
- bg: cream_100 (잠금 시 cream_300 + α 0.6)
- 자물쇠 아이콘: design_handoff에서 Lucide CDN 권장이지만 **정적 SVG로 박는다** (오프라인 보장) — Phase 12에서 `assets/icons/ui/lock.svg` 신규 작성
- 별점 표시: 3개 polygon star (lemon_500 fill / cream_200 dim, 18×18, 3px ink)

## 4. Motion 헬퍼 (Phase 9 = ui-atoms-foundation 신설, **시그니처 freeze**)

`scripts/ui/Motion.gd` (Autoload 아님, 정적 클래스). atoms (CButton boop / Counter caPop)가 본 헬퍼를 호출하므로 phase 9에서 작성. **본 절의 시그니처는 phase 9 시점에 freeze** — phase 11(stage-dialog)에서 동일 시그니처 그대로 호출. 이후 시그니처 변경 = sweep commit (간단한 인자 추가 X, 옵션 인자만 미리 박음).

```gdscript
class_name Motion
extends RefCounted

# scale .8 → 1.08 → 1.0, 220ms, TRANS_BACK + EASE_OUT
static func caPop(node: CanvasItem) -> Tween:
    var t := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    node.scale = Vector2(0.8, 0.8)
    t.tween_property(node, "scale", Vector2(1.08, 1.08), 0.10)
    t.tween_property(node, "scale", Vector2(1.0, 1.0),  0.12)
    return t

# position += (2,2) → 0, 120ms 선형
static func boop(node: Control) -> Tween:
    var t := node.create_tween()
    var base := node.position
    t.tween_property(node, "position", base + Vector2(2, 2), 0.06)
    t.tween_property(node, "position", base, 0.06)
    return t

# scale 1.0 ↔ amplitude, period s, infinite loop, SINE in_out
static func idle_bob(node: CanvasItem, amplitude: float = 1.03, period: float = 1.6) -> Tween:
    var t := node.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    t.tween_property(node, "scale", Vector2(amplitude, amplitude), period * 0.5)
    t.tween_property(node, "scale", Vector2(1.0, 1.0), period * 0.5)
    return t

# 페이드 트랜지션 (트랜지션 전용, 인-게임 피드백 사용 금지).
# pause_safe=true 시 SceneTree.paused 상태에서도 tween 진행 (모달 fade용).
# pause_safe=false (default) 시 노드의 process_mode 따름 — pause 시 정지.
static func fade_in(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween:
    var t := node.create_tween()
    if pause_safe:
        # Godot 4: TWEEN_PAUSE_PROCESS = paused tree에서도 진행 (= 노드 process_mode 무시).
        # 호출자(StageDialog 등)는 추가로 노드 자체도 PROCESS_MODE_ALWAYS로 둬야 다른 처리(_process 등)도 동작.
        t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    node.modulate.a = 0.0
    t.tween_property(node, "modulate:a", 1.0, duration)
    return t

static func fade_out(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween:
    var t := node.create_tween()
    if pause_safe:
        t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    t.tween_property(node, "modulate:a", 0.0, duration)
    return t

# 모달 등장 = caPop. 별도 함수 제공 X.
# caPop도 paused tree에서 사용해야 한다면 호출자가 노드를 PROCESS_MODE_ALWAYS로 두고
# tween을 직접 set_pause_mode 하는 책임 — caPop 자체에는 pause_safe 인자 불필요
# (모달 등장 = pop, 페이드 = fade라 분리. fade_*만 pause_safe 인자 보유).
```

> **Freeze 정책**: `caPop` / `boop` / `idle_bob` / `fade_in(node, duration, pause_safe)` / `fade_out(node, duration, pause_safe)` 5개 시그니처는 phase 9 완료 시 freeze. 이후 phase에서 추가 인자/메서드 필요 시 phase 9 sweep commit (`fix: motion sig <name> (phase 9 sweep)`)으로 처리.

> **Pause-safe 검증 (phase 9 강제)**: `tests/MotionPauseSafeTest.gd` — `get_tree().paused = true` 상태에서 `Motion.fade_in(node, 0.05, true)` 호출 → 60ms 후 `await get_tree().process_frame` 5회 → `node.modulate.a == 1.0` 검증. 동일 테스트의 `pause_safe=false` 케이스에서는 `modulate.a < 1.0` (정지) 확인.

**호출 위치 강제**:
| 이벤트 | 호출자 | 대상 |
|---|---|---|
| `EventBus.candy_hp_changed` | `HUD.gd` | `Counter[CANDY_HP].caPop()` |
| `EventBus.ant_in_transit_changed` | `HUD.gd` | `Counter[IN_TRANSIT].caPop()` |
| `EventBus.ant_saved` | `HUD.gd` | `Counter[SAVED].caPop()` |
| `EventBus.ant_lost` | `HUD.gd` | `Counter[LOST].caPop()` |
| `EventBus.stage_cleared` / `stage_failed` | `StageDialog.gd` | `self.caPop()` (모달 자체) |
| 버튼 `pressed` | `CButton._on_pressed` | `boop(self)` |
| Home `_ready` | `Home.gd` | `idle_bob(home_sprite)` |

**Pause 호환**: 모달은 `PROCESS_MODE_ALWAYS`, 인-게임 motion은 `PROCESS_MODE_INHERIT` (pause 시 정지).

## 5. SaveData 스키마 (Phase 12)

`scripts/core/SaveData.gd` (Autoload), 저장 위치 `user://save.cfg` (ConfigFile).

### 5.1 v0.1 스키마
```ini
[meta]
schema_version = 1
last_played_stage = 1            # 1-based stage_id
created_at = "2026-05-09T..."
last_saved_at = "2026-05-09T..."

[stage_progress.1]
cleared = true
best_saved = 8                   # ScoreSystem.saved at best run
best_score = 0.80                # saved / original_hp
stars = 2                        # 0..3
attempts = 3

[stage_progress.2]
cleared = false
attempts = 1
# best_* 없으면 미클리어
```

### 5.2 Migration hook (의무화)
```gdscript
const CURRENT_SCHEMA := 1

func load() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://save.cfg") != OK:
        _init_fresh(); return
    var v := cfg.get_value("meta", "schema_version", 0)
    if v < CURRENT_SCHEMA:
        _migrate(cfg, v, CURRENT_SCHEMA)
    _populate_from(cfg)

func _migrate(cfg: ConfigFile, from_v: int, to_v: int) -> void:
    # stage4~10 추가 phase에서 schema bump 시 본 함수에 case 추가
    for v in range(from_v, to_v):
        match v:
            0: _migrate_0_to_1(cfg)   # 신규 게임 init도 이 경로
            # 1: _migrate_1_to_2(cfg) # stage4~10 phase에서 추가
    cfg.set_value("meta", "schema_version", to_v)
    cfg.save("user://save.cfg")
```

### 5.3 별점 알고리즘 (v0.1) — **단일 SoT: `Scoring.compute_stars`**

**owner**: `scripts/core/Scoring.gd` (RefCounted, 정적 헬퍼). Phase 11(stage-dialog)에서 신설. Phase 11 StageDialog와 Phase 12 SaveData.record_clear가 **모두 본 함수만 호출**. 두 곳에서 직접 계산 금지.

```gdscript
# scripts/core/Scoring.gd
class_name Scoring
extends RefCounted

const STAR_THRESHOLDS := [0.50, 0.80, 0.95]   # ascending, 길이 = max_stars(3)

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

| 호출자 | 위치 | 호출 |
|---|---|---|
| StageDialog | `scripts/ui/StageDialog.gd._on_stage_cleared` | `Scoring.compute_stars(saved, original_hp)` → 별 polygon fill 토글 |
| SaveData    | `scripts/core/SaveData.record_clear` | `Scoring.compute_stars(saved, original_hp)` → `stage_progress[id].stars` 저장 |

> **Freeze 정책**: `Scoring.compute_stars(saved, original_hp) -> int` 시그니처는 phase 11 완료 시 freeze. stage별 임계값 override는 v0.2(`data/stages/stageNN.tres.star_thresholds: PackedFloat32Array`)에서 도입 — 그때 본 함수에 옵션 인자 1개 추가(`stage_thresholds: Array = STAR_THRESHOLDS`).

### 5.4 손상/누락 처리
- 파일 누락 → 신규 게임 init (warn만, error 아님)
- schema_version 미상 → v0 처리 → migrate → 진행 (assertion fail 금지)
- 개별 stage 키 손상 → 해당 stage만 reset, 나머지는 유지

## 6. 카피 가이드 (handoff SYSTEM_README §Voice 발췌)

- **POV**: "당신" 회피, 개미를 3인칭으로 ("개미들이 사탕을 옮깁니다")
- **Tone**: warm, encouraging. Failure는 retry 프레임 ("다시 해볼까요?")
- **Casing**: KO sentence-natural, no honorific endings on UI ("재시작" not "재시작합니다")
- **Numerals**: Arabic everywhere ("10마리", "120초")
- **Emoji**: UI 사용 금지. 시각 언어가 따뜻함 운반.

### 표준 문자열 테이블
| 표면 | KO | EN mirror |
|---|---|---|
| HUD 카운터 | 사탕 HP · 운반 중 · 귀가 · 잃음 | Candy HP · In transit · Saved · Lost |
| 시간 | 남은 시간 | Time left |
| 출구 속도 | 출구 속도 | Release rate |
| Pause | 잠시 멈춤 | Paused |
| Win 모달 | 사탕을 무사히 옮겼어요! | The candy made it home! |
| Loss 모달 | 사탕이 부족했어요. 다시 해볼까요? | Not enough candy. Try again? |
| Replay btn | 다시 하기 | Replay |
| Next btn | 다음 단계 | Next |
| Menu btn | 메뉴로 | Back to menu |
| 스킬 lock | 남은 횟수 0 | 0 left |
| Nuke | 모두 보내기 | Send them all |

## 7. 비-범위 (post-MVP)

| 항목 | 처리 |
|---|---|
| BGM / SFX | post-MVP phase 20 (sound-bgm-sfx). Phase 11(stage-dialog)에서 hook 시그널만 자리 마련 |
| Settings 화면 실제 동작 | Phase 12에서 stub만 |
| Credits 화면 | Phase 12에서 stub만 |
| 키 리매핑 UI | post-MVP |
| 별점 stage별 override | stage4~10 phase에서 필요 시 도입 |
| 폰트 최종 픽 (Jua/Gaegu 교체) | 디자이너 후속 작업, Theme 1군데만 교체 |
| 일러스트 최종 픽 (sprite/logo 교체) | 디자이너 후속, 파일명 보존 1:1 교체 |

## 8. 시각 회귀 절차 (Phase 9~11)

각 UI phase 완료 시:
1. Stage01 1280×720 / 1920×1080 둘 다 헤드리스 + 시각 캡처
2. `docs/design_handoff/preview/<관련>.html` 브라우저 캡처와 비교 (스크린샷 첨부 권장)
3. 픽셀 일치 강제 X — 토큰값(컬러/스페이싱/radii) 일치만 검증

---

**관련**: `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/ADR.md`, `docs/INPUT_PLAN.md`, `docs/design_handoff/`
**최초 작성**: 2026-05-09 (REVISION 보강)
