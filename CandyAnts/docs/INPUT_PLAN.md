# 입력 매핑 구현 계획 (Implementation Plan)

**버전**: v0.1 (구현 계획 — phase 분할 제안)
**작성 일자**: 2026-05-09
**전제 문서**:
- `docs/INPUT_MAPPING.md` — 디바이스별 매핑 명세 (v0.1)
- Notion: [CandyAnts 멀티 플랫폼 입력 매핑 계획](https://www.notion.so/CandyAnts-35ab23cf372081019d07da0f02514f6c) — 액션 추상 레이어 + 타게팅 정책 + 우선순위
- 현재 코드: `scripts/ui/SkillToolbar.gd` (단일 진입 클릭 처리)

---

## 0. 두 문서 사이의 차이와 본 계획의 입장

| 항목 | INPUT_MAPPING.md | Notion 문서 | 본 계획의 결정 |
|---|---|---|---|
| 1순위 디바이스 | Pad (ROG Ally X) | PC (마우스+KB) | **PC를 먼저 잡고(=현 SkillToolbar 마이그레이션 비용 0), Pad를 즉시 뒤따름**. Notion 우선순위 + 현실적 구현 비용 절충 |
| 액션 추상화 | 카탈로그만 명시 | Physical → Action → Intent → Preview → Commit 5단 | **Notion 5단을 SoT로 채택**. 본 계획의 InputRouter는 Action 단계까지 책임, Intent/Preview/Commit은 SkillToolbar가 책임 |
| 타게팅 우선순위 | 개미 직접 클릭 + 스냅 점프 | 타일/경로 ≥ 개미 직접 | **MVP: 개미 스냅 유지(현 코드 보존)**. 타일/경로 스냅은 Basher/Digger phase 합류 시 함께 |
| 명령 예약 / Rewind / Preview / CommandWheel | 미언급 | "공통 4종 통합" 요구 | **MVP: pause 중 부여만 보장(가벼움). Rewind / 시뮬 Preview / CommandWheel은 post-MVP phase로 분리** |
| StepFrame (틱 진행) | 미언급 | 포함 | **MVP 포함** (`get_tree().paused` + 1 frame advance — 구현 30라인) |
| Overlay | 미언급 | 포함 | **MVP: 액션 등록 + hover hint(빨강/초록)만**. 경로/위험 오버레이는 post-MVP |

---

## 1. 결정 — Notion §13 Open Questions 응답

| 질문 | 결정 | 근거 |
|---|---|---|
| 맵이 타일 기반인지 자유 곡선인지 | **TileMap 기반** | `scripts/world/Terrain.gd`, ARCHITECTURE.md §지형. 자유 곡선 고려 불요 |
| 명령이 개미에게 / 타일에 / 둘 다? | **개미에게(MVP) → 후순위로 타일 부여 추가** | Builder/Blocker는 개미 부여로 해결됨. Basher/Digger 합류 시점에 타일 후보 추가 |
| Rewind = 시뮬 롤백 / 최근 명령 취소? | **post-MVP에서 "마지막 스킬 부여 1회 undo + 인벤토리 환불" 부터**. 시뮬 롤백은 MVP 범위 밖 | 시뮬 롤백은 결정성 보장 + 상태 직렬화가 별도 작업. MVP에 포함 시 stage 빌드 슬립 |

---

## 2. 아키텍처 — 입력 5단 레이어

```
[Physical Input]  좌클릭 / 패드 A / 화면 탭 / 키보드 1
        │
        ▼  Godot InputMap 변환 (project.godot)
[InputEventAction]  "skill_assign" / "skill_select_1" / "cursor_move"
        │
        ▼  InputRouter (Autoload — 단일 진입점)
[Gameplay Action]  EventBus.action_triggered(action_id, payload)
        │
        ▼  수신자 분기 (SkillToolbar / VirtualCursor / GameLoop)
[Command Intent]   "현재 선택=blocker, 대상=ant#3"
        │
        ▼  유효성 검사 (Skill.can_apply, paused 상태 무관)
[Preview]          (MVP: hover 색상 / post-MVP: 시뮬레이션)
        │
        ▼
[Commit]           Skill.apply(ant) + 인벤토리 차감 + UI 갱신
```

### 책임 분리 (CRITICAL)

- **InputRouter** — 두 진입점:
  - `_unhandled_input(event)` — InputMap 등록 액션 (`event.is_action_pressed(...)`) + raw `InputEventMouseMotion` (synthetic `cursor_move` 발화용). raw event 종류 분기는 router 내부에서만 허용.
  - `_process(delta)` — 패드 stick continuous polling (deadzone 적용 후 synthetic `cursor_move`/`camera_pan`/`camera_zoom` 발화).
  - 두 경로 모두 발화하는 **gameplay action 이름은 디바이스 무관** (`cursor_move` 하나). 수신자는 raw event/디바이스 모름. 좌표는 항상 screen→world 변환 후 payload 동봉.
- **VirtualCursor** — `cursor_move` 액션 구독해서 자기 screen-space 위치를 갱신. 패드 모드일 때만 visible. 마우스 모드일 때는 hide. **`get_global_mouse_position()` / `VirtualCursor.global_position` 등을 직접 호출 금지** — 좌표는 InputRouter가 payload에 실어준 값만 사용 (§2 좌표 계약).
- **SkillToolbar** — `skill_select_*`, `skill_cycle_*`, `skill_assign`, `skill_cancel` 액션 구독. 현재 `_unhandled_input`/`_on_button_pressed`를 액션 핸들러로 마이그레이션. 클릭→액션 방향 단방향.
- **InputModeTracker** (신규) — 마지막 입력 디바이스 추적 (Mouse / Pad / Touch). UI 힌트 표시에만 사용. 입력 처리 분기 X.

### 신규 EventBus 시그널

```gdscript
# scripts/core/EventBus.gd 추가
signal action_triggered(name: StringName, payload: Dictionary)
signal input_mode_changed(mode: StringName)  # "mouse" / "pad" / "touch"
```

> `payload`는 액션별 명세 (§4 액션 사전 참조). 예: `cursor_move` → `{"screen_pos": Vector2, "world_pos": Vector2}`, `skill_select_n` → `{"slot": int}`.

### 좌표계 계약 (CRITICAL — 수정 사항: codex review HIGH)

현 `SkillToolbar._unhandled_input`은 다음 변환을 **이미** 수행:

```gdscript
var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
var world: Vector2 = canvas_xform.affine_inverse() * mb.position
```

마우스 위치(screen 공간) → world 공간 변환을 거쳐야 `Ant.global_position`(world)과 거리 비교가 가능. 카메라가 origin 아닌 경우(=Stage03 포함 모든 비-자명 stage)에서 이 변환을 빼면 잘못된 개미가 선택됨. 따라서 본 plan은 **단일 좌표 변환 책임을 InputRouter에 모음**:

#### 좌표 변환 헬퍼 (단일 SoT)

```gdscript
# scripts/input/CoordSpace.gd  (Autoload 아닌 static-only 클래스)
class_name CoordSpace

static func screen_to_world(screen_pos: Vector2, viewport: Viewport) -> Vector2:
    return viewport.get_canvas_transform().affine_inverse() * screen_pos

static func world_to_screen(world_pos: Vector2, viewport: Viewport) -> Vector2:
    return viewport.get_canvas_transform() * world_pos
```

#### payload 계약

위치를 동반하는 **모든 액션 payload는 `screen_pos` + `world_pos` 둘 다 포함**. 수신자는 자기 작업에 맞는 쪽을 사용 (UI 영역 검사 = screen, 개미 거리 = world). 변환은 InputRouter 1곳에서만.

| 액션 | payload 필드 |
|---|---|
| `cursor_move` | `{screen_pos: Vector2, world_pos: Vector2}` |
| `skill_assign` | `{screen_pos: Vector2, world_pos: Vector2}` |
| `target_next_ant` / `target_prev_ant` | `{from_world_pos: Vector2}` (현 커서의 world 위치 — 다음 후보 검색 기준점) |

#### 디바이스별 screen_pos 계산 (InputRouter 책임)

| 디바이스 | screen_pos 출처 | 변환 후 world_pos |
|---|---|---|
| 마우스 | `event.position` (InputEventMouseButton/Motion) — viewport 좌표 = screen-space | `CoordSpace.screen_to_world(screen_pos, viewport)` |
| 패드 | `VirtualCursor.position` — CanvasLayer의 follow_viewport_enabled=false 기본값 하에서 viewport-screen-space (§6.3) | 동일 변환 헬퍼 |
| 터치 (post-MVP) | `event.position` (InputEventScreenTouch/Drag) | 동일 변환 헬퍼 |

> **핵심**:
> - 모든 SkillToolbar/CursorTargeting 등 **수신자는 `payload.world_pos`만** 사용. `VirtualCursor.position` / `get_global_mouse_position()`을 직접 호출 금지.
> - InputRouter가 매번 `viewport.get_canvas_transform()`을 호출하여 변환 (캐싱 금지 — 카메라 매 프레임 이동 가능).
> - SkillToolbar 코드는 디바이스를 모른다. 패드/마우스/터치 같은 분기 X.

---

## 3. Phase 분할 — input 3개 + UI 5개 신규, stage 7개 시프트

> **2026-05-09 개정 v2**: 사용자 결정으로 phase 5~12에 **input(3) + UI(5)** 8개를 끼워넣고 기존 stage 7개를 13~19로 시프트. UI는 흡수된 design handoff(`docs/design_handoff/`)를 시각 레퍼런스로, `docs/UI_GUIDE.md`를 1차 SoT로 사용. atoms는 별도 phase로 분리(phase 9). 사운드/BGM은 post-MVP.

현 status.json 기준 phase 1~4 완료, 5~19 pending.

| # | 신규/기존 | 이름 | 핵심 산출물 |
|---|---|---|---|
| 5 | **신규(input)** | input-action-foundation | InputRouter + InputMap + KB/Mouse 마이그레이션 |
| 6 | **신규(input)** | input-pad-cursor | VirtualCursor + Pad 매핑 + 개미 스냅 |
| 7 | **신규(input)** | input-pause-step | pause 중 부여 + StepFrame + InputModeTracker + UI 힌트 |
| 8 | **신규(ui)** | ui-theme-assets | Theme 리소스 + 폰트(Jua/Gaegu) + SVG 에셋 임포트 + Tokens.gd |
| 9 | **신규(ui)** | ui-atoms-foundation | CButton/Chip/Counter/SkillSlot atoms + Motion 헬퍼 (단독 검증) |
| 10 | **신규(ui)** | ui-hud-toolbar-replace | HUD/SkillToolbar 씬 교체 (atom 인스턴스화, 스크립트는 노드 경로만) |
| 11 | **신규(ui)** | ui-stage-dialog | StageDialog(win/loss) + 트랜지션 + 사운드 hook |
| 12 | **신규(ui)** | ui-title-menu | 타이틀 / 메인 메뉴 / 스테이지 셀렉트 + SaveData(`user://save.cfg`) |
| 13 | 5→13 | stage4-hazard-water | (그대로) |
| 14 | 6→14 | stage5-basher | (그대로 — 단, 타일 스냅 후보 추가는 본 phase에서) |
| 15 | 7→15 | stage6-digger | (그대로) |
| 16 | 8→16 | stage7-miner | (그대로) |
| 17 | 9→17 | stage8-climber | (그대로) |
| 18 | 10→18 | stage9-floater | (그대로) |
| 19 | 11→19 | stage10-bomber-polish | (그대로 — MVP 종료) |
| 20 | **post-MVP** | sound-bgm-sfx | 사운드/BGM 임포트 + 모달/카운터/스킬 SFX (hook 자리는 phase 11에서 `EventBus.sfx_request`로 마련) |
| 21 | **post-MVP** | input-touch | 터치 + 드래그 앤 드롭 + 루페 |
| 22 | **post-MVP** | input-advanced | Rewind(undo) + Preview + CommandWheel + Overlay |

### 왜 input → UI → stage 순서? (v2 정리)

1. **input과 UI 모두 SkillToolbar를 손댐** — input을 먼저 마이그레이션하면 UI 교체 phase에서 회귀 진단이 쉬움(원인이 노드 경로 변경뿐).
2. **현재 SkillToolbar가 stage4~10에서 매번 손댐** (인벤토리·새 스킬 추가). 액션 레이어 + 시각 레이어가 모두 안정된 후 stage 진행 → 재작업 0.
3. **ROG Ally X 환경에서 dev-test = 패드**. stage4~10을 마우스로 dev-test하다가 후반에 패드 합치면 UX 회귀 위험.
4. **UI를 input 다음에 두는 이유**: 디자인 적용 후 마우스/패드 양쪽으로 시각 검증해야 디자인 갭(예: VirtualCursor z-order, hover hint 위치)을 한 번에 잡음.
5. **atoms를 별도 phase(9)로 분리한 이유**: 4 atom + Motion 헬퍼가 phase 10 HUD/Toolbar 교체 + phase 11 StageDialog + phase 12 메뉴에서 모두 재사용. 검증 단위를 atom 단독으로 쪼개면 시각/단위/회귀 검증이 가벼워지고 다음 phase의 변경 폭이 줄어듦.
6. **타이틀/메뉴를 phase 12에 두는 이유**: StageDialog(phase 11)의 SceneFlow가 Title/Menu 진입점을 갖도록 자연스럽게 확장. 그 전에 둘 이유 없음.
7. **타일 스냅 후보 등록은 stage5(basher)에서 자연스럽게 합류** — phase 6에서 인터페이스만 열어두고 phase 14에서 채움.

---

## 4. 액션 사전 (InputMap 등록 대상)

InputMap에 등록할 **액션 이름은 snake_case 고정**. 디바이스별 binding은 InputMap entry로.

### 4.1 MVP 포함 (phase 5~7)

> **액션 종류 표기**:
> - **(InputMap)** — Godot InputMap의 액션. `event.is_action_pressed(name)`으로 잡힘.
> - **(synthetic)** — InputMap에 등록하지 않는 합성 액션. InputRouter가 raw event 종류(InputEventMouseMotion, JoypadMotion poll)를 보고 직접 emit.

| 액션 ID | KB+Mouse | Pad | 종류 | 발화 빈도 | payload |
|---|---|---|---|---|---|
| `cursor_move` | 마우스 이동 (`InputEventMouseMotion`) | 좌 스틱 (`Input.get_vector` poll) | **synthetic** | 매우 높음 | `{screen_pos: Vector2, world_pos: Vector2}` |
| `camera_pan` | Space+드래그 / WASD | 우 스틱 (poll) | KB는 InputMap, 패드는 **synthetic** (poll) | 매우 높음 | `{delta: Vector2}` (screen-space delta) |
| `camera_zoom` | 휠 (`InputEventMouseButton WHEEL_UP/DOWN`) | LT/RT (analog poll) | 휠은 InputMap, LT/RT는 **synthetic** | 중간 | `{delta: float, anchor_screen_pos: Vector2}` |
| `skill_select_1` ~ `skill_select_8` | 1~8 | (없음) | InputMap | 높음 | `{slot: int}` |
| `skill_cycle_next` | E | RB | InputMap | 높음 | — |
| `skill_cycle_prev` | Q | LB | InputMap | 높음 | — |
| `skill_assign` | 좌클릭 | A | InputMap | 매우 높음 | `{screen_pos: Vector2, world_pos: Vector2}` |
| `skill_cancel` | 우클릭 (InputMap, **phase 5**) / Esc (InputMap, **phase 12** — game state 분기와 함께) | B 단발 (game state=인게임+pending 시) | KB는 InputMap, 패드 B는 **raw** (release 시점 분기, 아래 규약) | 중간 | — |
| `target_next_ant` | Tab | D-Pad → | InputMap | 중간 | `{from_world_pos: Vector2}` |
| `target_prev_ant` | Shift+Tab | D-Pad ← | InputMap | 중간 | `{from_world_pos: Vector2}` |
| `pause_toggle` | Space | View | InputMap | 낮음 | — |
| `step_frame` | `.` 또는 → | (없음) | InputMap | 낮음 | — |
| `speed_toggle` | F | R3 | InputMap | 낮음 | — |
| `restart_stage` | Ctrl+R | B 홀드 ≥1초 | KB는 InputMap, 패드 B는 **raw** (timer 만료) | 낮음 | — |
| `release_rate_up` | F2 | D-Pad ↑ | InputMap | 낮음 | — |
| `release_rate_down` | F1 | D-Pad ↓ | InputMap | 낮음 | — |
| `info_toggle` | H | X | InputMap | 낮음 | — |
| `back_menu` | Esc (InputMap, **phase 12** — 메뉴 상태 / 또는 인게임에서 pending 없음) | B 단발 (game state=메뉴 또는 인게임+pending 없음) | KB는 InputMap, 패드 B는 **raw** (release 시점 분기) | 낮음 | — |

#### Synthetic 액션 발화 규약 (InputRouter 내부)

```
_unhandled_input(event):
    # 1. InputMap 액션 처리 — event.is_action_pressed(name)으로 모든 InputMap 액션 분기
    # 2. 마우스 모션 → synthetic cursor_move via _emit_cursor_move (cache 갱신 단일 경로)
    if event is InputEventMouseMotion:
        _emit_cursor_move(event.position)
    # 3. 패드 모션은 _process polling에서 처리 (continuous, deadzone 적용)

_process(delta):
    if has_pad:
        var stick = Input.get_vector("cursor_left","cursor_right","cursor_up","cursor_down", 0.15)
        if stick != Vector2.ZERO:
            _ensure_virtual_cursor_ready()         # 첫 사용 시 viewport 중앙 init
            _virtual_cursor.position = clamp(_virtual_cursor.position + stick * speed * delta, ...)
            _emit_cursor_move(_virtual_cursor.position)
        # camera_pan: 우 스틱 동일 패턴 (synthetic)
        # camera_zoom: LT/RT analog 동일 패턴 (synthetic)
```

> `_emit_cursor_move`만이 `GameAction.CURSOR_MOVE`의 유일한 emit + `_last_cursor_*` cache 갱신 경로. 다른 곳에서 `EventBus.action_triggered.emit(GameAction.CURSOR_MOVE, ...)` 직접 호출 금지 — KB origin 액션 (Tab=`target_next_ant`)이 stale cache 사용 위험.

> **디바이스 분기 = InputRouter 내부 입력 수집 단계에서만** 허용. 발화하는 액션 이름은 디바이스 무관 (`cursor_move` 하나). 수신자는 디바이스 모름. `skill_assign` payload 생성 규약은 §2 좌표 계약과 동일 — InputRouter가 `screen_pos` (마우스 `event.position` / 패드 `_virtual_cursor.position`) → `world_pos = CoordSpace.screen_to_world(...)` 변환 후 payload에 둘 다 동봉. **수신자가 `get_global_mouse_position()` 또는 `VirtualCursor.global_position`을 직접 호출하는 것은 금지** (구현 검토에서 매번 ban으로 검증).

#### Pad B 버튼 — 단발/홀드 분기 (raw 처리, codex review HIGH Round 4)

`skill_cancel`(우클릭 phase 5 / Esc phase 12), `restart_stage`, `back_menu`(Esc phase 12)는 디바이스마다 다른 입력 방식이어서 **단일 InputMap entry로 매핑하면 안전하지 않다**. 특히 패드 B는 단발(`skill_cancel` 또는 `back_menu`)과 홀드(`restart_stage`) 둘 다를 가지는데 `event.is_action_pressed` 발화는 press 즉시이므로 단발 emit 후 1초 후 홀드 emit이 둘 다 발생 = race + destructive.

**규약**:
- B 버튼은 **InputMap에 등록하지 않음**. InputRouter가 raw `InputEventJoypadButton`(button_index=JOY_BUTTON_B)을 직접 잡는다.
- press 시점: timer(1.0초) 시작. action emit 안 함. `viewport.set_input_as_handled()` 호출해 다른 처리 차단.
- timer 만료 전 release: 현재 game state 검사 후 **release 시점에 1회만** emit:
  - 메뉴/모달 열림 상태 → `back_menu`
  - 인게임 + 스킬 pending 있음 → `skill_cancel`
  - 인게임 + 스킬 pending 없음 → `back_menu` (전역 메뉴 열기)
- timer 만료 (1초 도달, 아직 press 중): `restart_stage` emit + 이후 release 무시 (timer reset).

KB+Mouse 측은 별도 InputMap 액션으로 명확:
- `skill_cancel` ← 우클릭 (phase 5 InputMap) / Esc (phase 12 InputMap — game state 분기와 함께 추가)
- `restart_stage` ← Ctrl+R (단발 — 단순, phase 5 InputMap)
- `back_menu` ← Esc (phase 12 InputMap — 메뉴 상태에서만, game state가 `skill_cancel`과 분기)

> 같은 raw-처리 패턴을 **post-MVP에서 다른 더블 액션이 추가되면 그대로 적용** (예: Menu 단발=minimap / 홀드 2초=nuke). InputMap 1대1이 깨지는 모든 케이스는 router에서 raw 처리.

### 4.2 post-MVP (phase 21~22)

| 액션 ID | 비고 |
|---|---|
| `tap_drag_skill` | 터치 드래그 앤 드롭 (phase 21 — input-touch) |
| `pinch_zoom` | 두 손가락 핀치 (phase 21 — input-touch) |
| `rewind_hold` | 누르는 동안 undo (phase 22 — input-advanced) |
| `command_wheel_open` | LB 홀드 / 길게 누르기 (phase 22 — input-advanced) |
| `overlay_toggle` | Alt / Y (phase 22 — input-advanced) |
| `nuke` | Menu 홀드 / F12 더블 (phase 22 — input-advanced) |

> MVP에서 `nuke`는 미구현. 사용자가 막히면 `restart_stage`로 우회.

---

## 5. Phase 5 — input-action-foundation (상세)

### 5.1 변경 대상

**신규**:
- `scripts/input/GameAction.gd` — 액션 ID 상수 (`const ASSIGN := &"skill_assign"` 형태). StringName 사용.
- `scripts/input/CoordSpace.gd` — screen↔world 변환 헬퍼 (§2 좌표계 계약).
- `scripts/input/InputRouter.gd` — Autoload 등록. **두 진입점**: ① `_unhandled_input(event)` — InputMap 액션(`event.is_action_pressed(...)`) + raw `InputEventMouseMotion` 처리, ② `_process(delta)` — 패드 stick polling (continuous, deadzone). 두 경로 모두 screen→world 변환 후 EventBus 발화.
- `scripts/input/InputBindings.gd` — InputMap 등록 헬퍼 (project.godot에 직접 쓰는 대신 startup에서 add_action — **이쪽은 결정 보류, 5.5 참조**).

**수정**:
- `project.godot` — InputMap 액션 등록 (KB+Mouse만). `[autoload] InputRouter="*res://scripts/input/InputRouter.gd"` 추가.
- `scripts/core/EventBus.gd` — `action_triggered`, `input_mode_changed` 시그널 추가.
- `scripts/ui/SkillToolbar.gd` — `_unhandled_input`/`_on_button_pressed` 제거 → EventBus.action_triggered 구독으로 교체. 클릭은 `Button.pressed` 시그널이 `EventBus.action_triggered.emit(skill_select_n, {slot:n})`을 emit하도록 어댑터.

### 5.2 씬 트리 / Autoload

- Autoload 4개로 늘어남: `GameManager`, `EventBus`, `SkillRegistry`, **`InputRouter`** (신규).
- 씬 트리 변경 없음 (InputRouter는 노드를 안 만든다 — `_unhandled_input`만).

### 5.3 시그널 흐름

#### 위치 동반 InputMap 액션의 screen_pos 산출 (CRITICAL — codex review HIGH Round 5)

`skill_assign`은 InputMap 액션이지만 매칭되는 raw event 타입이 디바이스별로 다르고 그 중 일부는 위치 정보를 가지지 않는다. **`event.position`을 무조건 쓰면 패드 A에서 미존재 필드 접근 / 잘못된 좌표 / 깨진 payload 발생**. 따라서 InputRouter는 다음 분기로 screen_pos를 산출:

**좌표 추출은 명시적 validity flag로 운반** — `Vector2.ZERO`를 에러 sentinel로 쓰면 world origin에 ant 있는 stage에서 정상 입력을 silent reject (codex review HIGH Round 7 #1). 패드 origin 액션이 virtual cursor 미초기화 시 OS 마우스 위치로 폴백하면 잘못된 ant 부여 + 인벤토리 차감 (codex review HIGH Round 7 #2). **eager init은 단일 helper에서만 일어나야 함** — `_resolve_position`과 `_process` 폴링 둘 다 같은 helper 경유 (codex review HIGH Round 8).

#### payload validity 계약 (단일 SoT — producer/consumer 동일 키)

위치 동반 액션의 payload는 다음 필드를 **항상** `position_valid` 키 이름 그대로 갖는다:

```gdscript
{
    "position_valid": bool,    # false면 수신자 noop
    "screen_pos": Vector2,     # position_valid=true일 때만 의미 있음
    "world_pos":  Vector2,     # 동일
}
```

> **producer (`_resolve_position`)와 consumer (`SkillToolbar._on_action`)가 같은 키 사용**. 다른 이름 (`valid`, `is_valid`, `ok` 등) 절대 금지. lint 또는 unit test로 보장.

#### Virtual cursor 단일 init 진입점

```gdscript
# scripts/input/InputRouter.gd
# Eager init은 이 helper에서만 일어난다. _resolve_position과 _process 폴링이 모두 경유.
# 초기 cursor_move emit은 _emit_cursor_move 위임 — CURSOR_MOVE의 유일한 발화 경로 (codex review HIGH Round 10).
func _ensure_virtual_cursor_ready() -> bool:
    if not is_instance_valid(_virtual_cursor) or not _virtual_cursor.is_inside_tree():
        return false
    if _virtual_cursor_initialized:
        return true
    var vp: Viewport = get_viewport()
    if vp == null:
        return false
    _virtual_cursor.position = vp.get_visible_rect().size * 0.5
    _virtual_cursor_initialized = true
    _emit_cursor_move(_virtual_cursor.position)   # cache 갱신 + EventBus emit 단일 경로
    return true
```

#### `_resolve_position` — 위치 동반 액션의 screen_pos 산출

캐스트는 `position` 필드를 실제로 가진 구체 클래스로만 (codex review HIGH Round 6):

| event 타입 | position 추출 |
|---|---|
| `InputEventMouse` (Button/Motion 공통 부모) | `event.position` (viewport 좌표) |
| `InputEventScreenTouch` | `event.position` |
| `InputEventScreenDrag` | `event.position` (Touch와 별개 클래스) |
| `InputEventJoypadButton`, `InputEventJoypadMotion` | virtual cursor (eager init 경유) |
| `InputEventKey` | InputModeTracker.mode 분기 |

```gdscript
func _resolve_position(event: InputEvent) -> Dictionary:
    if event is InputEventMouse:
        return {"position_valid": true, "screen_pos": (event as InputEventMouse).position}
    if event is InputEventScreenTouch:
        return {"position_valid": true, "screen_pos": (event as InputEventScreenTouch).position}
    if event is InputEventScreenDrag:
        return {"position_valid": true, "screen_pos": (event as InputEventScreenDrag).position}

    # 패드 이벤트 — virtual cursor만 사용. mouse fallback 금지.
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        if not _ensure_virtual_cursor_ready():
            return {"position_valid": false, "screen_pos": Vector2.ZERO}
        return {"position_valid": true, "screen_pos": _virtual_cursor.position}

    # 키 이벤트는 raw event에 위치 없음 → 단일 진실원천 = `_last_cursor` 캐시 (§아래 캐시 계약 참조).
    # InputModeTracker.mode 등 디바이스 모드는 절대 읽지 않음 — UI 힌트 전용 계약 유지 (codex review HIGH Round 9 #2).
    if event is InputEventKey:
        if not _last_cursor_valid:
            return {"position_valid": false, "screen_pos": Vector2.ZERO}
        return {"position_valid": true, "screen_pos": _last_cursor_screen}

    push_error("[InputRouter] unknown event type for positional action: %s" % event)
    return {"position_valid": false, "screen_pos": Vector2.ZERO}
```

#### `_last_cursor_*` 캐시 — 위치 동반 KB 액션의 단일 진실원천

KB origin 위치 동반 액션 (예: `target_next_ant` Tab 키)은 raw event에 좌표가 없으므로 InputRouter가 마지막으로 emit한 cursor 위치를 캐싱해서 사용. **`InputModeTracker.mode`를 읽지 않음** — mode는 stale될 수 있고 §2 책임 분리 계약상 UI 힌트 전용.

```gdscript
# scripts/input/InputRouter.gd  (캐시 필드)
var _last_cursor_screen: Vector2 = Vector2.ZERO
var _last_cursor_world:  Vector2 = Vector2.ZERO
var _last_cursor_valid:  bool    = false

# cursor_move를 emit할 때마다 갱신 — 마우스/패드/터치 어느 쪽이든 마지막 좌표가 캐시
func _emit_cursor_move(screen_pos: Vector2) -> void:
    var vp: Viewport = get_viewport()
    if vp == null:
        return
    var world_pos: Vector2 = CoordSpace.screen_to_world(screen_pos, vp)
    _last_cursor_screen = screen_pos
    _last_cursor_world  = world_pos
    _last_cursor_valid  = true
    EventBus.action_triggered.emit(GameAction.CURSOR_MOVE, {
        "position_valid": true,
        "screen_pos": screen_pos,
        "world_pos":  world_pos,
    })
```

> `_emit_cursor_move`는 마우스 motion (`_unhandled_input`), 패드 polling (`_process`), 패드 eager init (`_ensure_virtual_cursor_ready`) **세 진입점이 모두 호출**. 캐시는 항상 가장 최근 cursor 위치. 디바이스 무관.

> KB origin `target_next_ant` 발화 시 payload `from_world_pos`는 `_last_cursor_world`에서 가져옴. 처음에 cursor가 한 번도 emit되지 않은 상태(=`_last_cursor_valid=false`)면 액션을 invalid로 reject. 회귀 테스트로 보장.

#### Stick polling (`_process`) — 동일 helper 경유

```gdscript
func _process(delta: float) -> void:
    if not _has_pad_connected():
        return
    var stick: Vector2 = Input.get_vector(&"cursor_left", &"cursor_right", &"cursor_up", &"cursor_down", 0.15)
    if stick == Vector2.ZERO:
        return
    if not _ensure_virtual_cursor_ready():
        return    # cursor 노드 없거나 viewport 없음 — silent skip (다음 프레임에 다시 시도)
    var size: Vector2 = get_viewport().get_visible_rect().size
    _virtual_cursor.position = (_virtual_cursor.position + stick * cursor_speed * delta).clamp(Vector2.ZERO, size)
    _emit_cursor_move(_virtual_cursor.position)   # cache 갱신 + EventBus emit 단일 경로 (codex review HIGH Round 10)
    # camera_pan / camera_zoom polling 동일 패턴 (생략)
```

> `_ensure_virtual_cursor_ready` 단일 진입점이므로 stick 첫 사용도 viewport 중앙에서 시작 (default `(0,0)` 회피). `CURSOR_MOVE` emit은 항상 `_emit_cursor_move`만 호출 — `EventBus.action_triggered.emit(GameAction.CURSOR_MOVE, ...)` 직접 호출 금지 (cache stale 위험).

#### 수신자 가드 (consumer 계약)

```gdscript
# scripts/ui/SkillToolbar.gd
func _on_action(name: StringName, payload: Dictionary) -> void:
    if name == GameAction.SKILL_ASSIGN:
        if not payload.get("position_valid", false):
            return    # 좌표 추출 실패 — noop, 인벤토리 보존
        _try_assign(payload.world_pos)
```

> `Vector2.ZERO` 자체는 정상 좌표일 수 있음 — noop 판정에 사용 금지.

#### 흐름

```
[마우스 좌클릭]
InputEventMouseButton(button=LEFT, pressed=true, position=screen_pos)
    ▼
InputRouter._unhandled_input
    │ event.is_action_pressed("skill_assign") → true
    │ screen_pos = _resolve_screen_pos(event)   # → event.position
    │ world_pos  = CoordSpace.screen_to_world(screen_pos, get_viewport())
    ▼
EventBus.action_triggered.emit(&"skill_assign", {screen_pos, world_pos})

[패드 A]
InputEventJoypadButton(button_index=JOY_BUTTON_A, pressed=true)   # position 없음
    ▼
InputRouter._unhandled_input
    │ event.is_action_pressed("skill_assign") → true
    │ screen_pos = _resolve_screen_pos(event)   # → _virtual_cursor.position
    │ world_pos  = CoordSpace.screen_to_world(screen_pos, get_viewport())
    ▼
EventBus.action_triggered.emit(&"skill_assign", {screen_pos, world_pos})

▼ (수신자 공통)
SkillToolbar._on_action(name, payload)  → payload.world_pos 사용 (event 종류 모름)
InputModeTracker._on_action(...)        → mode = "mouse"|"pad" (event 종류로 판단)
```

> InputRouter가 변환 1곳 + event-source별 source 분기 1곳. 수신자는 디바이스/event 종류 모름. `Ant.global_position`과의 거리 비교는 항상 `payload.world_pos` 사용. `payload.screen_pos`는 UI hover hint 등 화면 영역 검사 전용.

### 5.4 엣지 케이스 (필수)

1. **마우스 클릭이 SkillToolbar UI 영역(버튼)일 때 `skill_assign`이 발화하면 안 됨** → InputRouter가 `get_viewport().is_input_handled()` 검사 후 emit. UI Control이 먼저 `accept_event()`함.
2. **InputMap에 등록 안 된 액션 이름으로 emit 호출** → 컴파일 타임 잡기 위해 `GameAction.gd`의 const만 emit에 사용. 매직 스트링 금지.
3. **`skill_select_3` 발화 시 stage_data.available_skills.size() < 3** → SkillToolbar에서 noop + 사운드/UI 거절 (이미 `_inventory.get(id, 0) <= 0`은 disabled 처리).
4. **Esc가 메뉴 열기와 skill_cancel 둘 다** → **phase 12 도입 시점**의 엣지 케이스. 메뉴 미오픈 상태에서만 skill_cancel. 메뉴 오픈 상태에서는 메뉴 닫기 우선. 우선순위는 InputRouter가 game state 확인 후 분기. **Phase 5에서는 Esc가 InputMap 미등록 → 어떤 액션도 발화하지 않음** (회귀 가드: phase05-plan §검증 시나리오 case-C).
5. **`_unhandled_input` 미수신** → InputRouter는 Autoload(=루트 자식)이므로 viewport input 큐의 마지막 핸들러. UI Control 노드가 먼저 받게 보장. CanvasLayer SkillToolbar의 Button 클릭은 UI 우선이므로 `_unhandled_input`까지 안 옴 — 검증 필요.
6. **stage1~3 마우스 회귀** — `_pending_skill_id` 상태 머신을 EventBus 액션 흐름으로 옮기되, 동작 일치. 헤드리스 테스트 추가: `tests/InputRouterTest.tscn` (skill_select → skill_assign → 인벤토리 차감).
7. **카메라가 origin 아닐 때 좌표 변환 (codex review HIGH 후속)** — InputRouter가 매번 `viewport.get_canvas_transform()`을 다시 읽어야 함. 캐싱 금지(카메라 매 프레임 이동 가능). 회귀 테스트 §5.6에 명시.

### 5.5 결정 보류 — InputMap 등록 위치

**옵션 A**: `project.godot`의 `[input]` 섹션에 직접 등록 (Godot 표준).
- 장점: 에디터 GUI에서 보임. 표준.
- 단점: 액션이 20+개로 늘면 project.godot 비대.

**옵션 B**: `InputBindings.gd`에서 `_init` 시 `InputMap.add_action()` 동적 등록.
- 장점: 코드로 관리. 디바이스별 모듈화.
- 단점: 에디터에서 안 보임. 다른 시스템(예: Godot 키매핑 UI)이 동작 안 함.

**결정**: **옵션 A**. 표준 우선. 디바이스 분리는 InputMap entry 단위로 하되 액션 이름은 동일.

### 5.6 검증

1. `tests/InputRouterTest.tscn` (헤드리스) — 가짜 InputEvent 주입 → EventBus.action_triggered가 올바른 액션/payload(`screen_pos`+`world_pos` 둘 다 포함)로 emit
2. **`tests/InputRouterShiftedCameraTest.tscn` (헤드리스, codex review HIGH 회귀 가드)** — Camera2D를 (500, 300)으로 이동 + zoom=1.5 적용한 상태에서:
   - 화면 좌표 (400, 300)에 마우스 클릭 시뮬
   - InputRouter가 emit한 payload.world_pos가 `Transform2D(canvas).affine_inverse() * Vector2(400,300)`과 일치하는지 assert
   - 그 world_pos에 미리 배치한 Ant가 정확히 선택되는지 assert
3. Stage01~03 마우스 회귀 — 클릭 → 부여 → 인벤토리 차감 정상 (특히 Stage03 카메라가 origin 아님)
4. 1~8 키로 슬롯 전환 + 좌클릭으로 부여
5. Q/E로 cycle, **우클릭으로 cancel** (Esc는 phase 5에 미바인딩 — phase 12에서 game state 분기와 함께 도입)
6. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS

---

## 6. Phase 6 — input-pad-cursor (상세)

### 6.1 변경 대상

**신규**:
- `scripts/ui/VirtualCursor.gd` — Sprite2D 자식 또는 Control. 패드 모드일 때만 visible.
- `scenes/ui/VirtualCursor.tscn`
- `scripts/input/CursorTargeting.gd` — 가까운 개미 스냅 계산기 (snap radius, exclude dead).

**수정**:
- `project.godot` InputMap에 패드 binding 추가 (좌/우 스틱, ABXY, LB/RB, LT/RT, D-Pad, View, R3).
- `InputRouter.gd` — 좌 스틱 deadzone 처리, `cursor_move` 발화. `target_next_ant`/`target_prev_ant` 처리.
- `scenes/Main.tscn` 또는 각 stage 씬 — VirtualCursor 인스턴스 추가 (UI CanvasLayer).
- `SkillToolbar.gd` — **변경 없음**. payload.world_pos만 사용 (디바이스 분기 X). InputRouter가 변환 책임 — 패드 케이스는 `screen_pos = VirtualCursor.position`(screen-space) → `world_pos = CoordSpace.screen_to_world(screen_pos, viewport)`. SkillToolbar는 패드/마우스를 구별하지 않음.

### 6.2 시그널 흐름

```
좌 스틱 (continuous joypad axis)
    ▼
InputRouter._process(delta)  # poll-based (deadzone + 가속 곡선)
    │ stick = Input.get_vector(...)  (deadzone=0.15)
    │ _virtual_cursor.position += stick × cursor_speed × delta   # screen-space 누적 + clamp
    │ screen_pos = _virtual_cursor.position
    │ world_pos  = CoordSpace.screen_to_world(screen_pos, get_viewport())
    ▼
EventBus.action_triggered.emit(&"cursor_move", {screen_pos: ..., world_pos: ...})
    ▼
VirtualCursor._on_action  → screen_pos로 화면 위치 갱신 + show
SkillToolbar._on_action(SKILL_ASSIGN)  → 항상 payload.world_pos만 사용 (디바이스 모름)
InputModeTracker._on_action  → mode = "pad" (UI 힌트 전용)
```

> 스틱은 InputEventJoypadMotion으로 매 프레임 수신되지만, 가속 곡선/deadzone 적용을 위해 **poll-based** (`_process`에서 `Input.get_vector()`)로 처리. payload 형식은 §2 좌표 계약과 동일 — screen+world 둘 다 동봉. 수신자는 디바이스 분기 X.

### 6.3 가상 커서 — 좌표 공간 결정 (codex review HIGH 후속)

**결정**: VirtualCursor는 **CanvasLayer 안의 Control** (screen-space). 이유:
- 카메라 줌이 변해도 커서 크기 일정 (UX: 줌 인해도 작아지지 않음)
- HUD/SkillToolbar와 같은 레이어에서 z-order 일관
- World-space Node2D로 만들면 zoom 시 커서가 같이 스케일되어 정밀 조작 어려움

**InputRouter가 stick polling + screen→world 변환 + payload 발화**: 단일 helper `_ensure_virtual_cursor_ready()` 경유로 첫 stick도 viewport 중앙 init (§2 좌표 계약 / payload validity 계약 참조). 정확한 pseudocode는 §2의 "Stick polling" 블록 참조.

> `_virtual_cursor.position`은 항상 screen-space. `world_pos`는 매 emit마다 최신 canvas_transform으로 재계산. 카메라 매 프레임 이동/줌 가능. 모든 emit payload는 `position_valid: true` 필수.

### 6.4 가상 커서 동작

- 좌 스틱 입력 시: visible=true, screen-space position 누적. 화면 가장자리 80% 도달 시 카메라 추적 활성 (카메라 이동은 screen→world 변환 결과에 자동 반영).
- 정지 5초 후: alpha 0.4로 페이드. 0으로 사라지지는 않음.
- 마우스 모드 전환 시: visible=false. 카메라 추적 해제.
- 스냅 점프 시:
  1. CursorTargeting이 다음 후보 ant.global_position(world) 계산
  2. `world_to_screen` 변환으로 목표 screen_pos 산출
  3. 0.15초 보간으로 `_virtual_cursor.position`(screen) 이동
  4. `CURSOR_MOVE` 액션은 보간 종료 시 1회만 emit (보간 중 spam 방지)

### 6.5 엣지 케이스

1. **마우스 + 패드 동시 입력** — last-emit wins. InputRouter가 마우스 모션과 패드 polling을 같은 프레임에 처리할 수도 있는데, 둘 다 같은 `cursor_move` synthetic action을 각자의 좌표로 emit. SkillToolbar는 `skill_assign` 발화 시점의 **payload.world_pos만** 사용 (그 시점 어느 디바이스가 trigger했는지 무관). InputModeTracker는 last-input mode를 별도로 추적하되 **UI 힌트 표시 전용** — SkillToolbar 어느 곳에서도 mode를 읽지 않음 (디바이스 분기 금지).
2. **D-Pad ←/→ 너무 빠른 입력** — 0.1초 cooldown. CursorTargeting이 timer로 throttle.
3. **개미가 화면 밖에 있을 때 target_next_ant** — 카메라 자동 추적 후 스냅. 단, 화면 안에 우선 후보 있으면 화면 안만.
4. **죽은 개미 / 구조 완료 개미는 스냅 후보 제외** — `Ant.is_alive()` 체크.
5. **VirtualCursor가 카메라 zoom과 함께 스케일** — Control은 zoom 영향 무 (CanvasLayer follow_viewport_enabled=false 기본). 검증 필수.
6. **패드 미연결 환경** — `Input.get_connected_joypads()` 비어있으면 InputRouter는 패드 polling skip.
7. **카메라 이동 중 좌 스틱 정지** — `_virtual_cursor.position`(screen)은 그대로지만 world_pos는 카메라 따라 변함. CURSOR_MOVE를 idle 카메라 변동 시에도 1회 emit해서 hover hint 갱신 보장.
8. **B 버튼 단발/홀드 race (codex review HIGH Round 4)** — InputRouter raw 처리. press 시 timer 시작 + `set_input_as_handled` (InputMap 발화 차단). release before 1초 → game state 따라 `skill_cancel` 또는 `back_menu` 정확히 1회 emit. release after 1초 → `restart_stage` 1회 emit (release 무시). **회귀 테스트**: `tests/PadButtonBHoldTest.tscn` — press → 0.9초 release → skill_cancel 1회만 emit / press → 1.1초 hold → restart_stage 1회만 emit (skill_cancel 발화 X).

### 6.6 검증

1. Stage03 패드만으로 클리어 — 좌 스틱 커서 + LB/RB 사이클 + A로 부여
2. 군중(개미 5+) 속에서 D-Pad ←/→로 다음 개미 정확히 선택 (snap radius 시각 확인)
3. 우 스틱 카메라 + 좌 스틱 커서 독립 동작 (카메라 이동 후에도 커서 아래 ant가 정확히 선택되는지 — codex review HIGH 회귀)
4. 마우스/패드 전환 시 VirtualCursor visibility 즉시 반영
5. **`tests/PadShiftedCameraTest.tscn`** (헤드리스, codex review HIGH Round 1+5 회귀 가드) — Camera2D 이동 후:
   - 좌 스틱 입력으로 `_virtual_cursor.position` = (400, 300)으로 이동
   - 패드 A 버튼 시뮬 (`Input.action_press("skill_assign")` + raw `InputEventJoypadButton` injection)
   - emit된 `skill_assign.screen_pos`가 (400, 300)과 일치
   - emit된 `skill_assign.world_pos`가 `CoordSpace.screen_to_world(Vector2(400,300), viewport)`와 일치
   - 그 world_pos에 미리 배치한 Ant가 정확히 선택되는지 assert
6. `tests/PadInputTest.tscn` (헤드리스) — `Input.action_press` 시뮬
7. **`tests/InputRouterEventDispatchTest.tscn`** (헤드리스, codex review HIGH Round 6+7 회귀 가드) — InputRouter._resolve_position에 다음 event 직접 주입 + emit된 payload assert:
   - `InputEventMouseButton`(position=(100,200)) → `{position_valid: true, screen_pos:(100,200)}`
   - `InputEventMouseMotion`(position=(150,250)) → `{position_valid: true, screen_pos:(150,250)}`
   - `InputEventScreenDrag`(position=(50,80)) → `{position_valid: true, screen_pos:(50,80)}`
   - `InputEventJoypadButton`(VirtualCursor 미초기화) → eager init 발동, screen_pos=viewport 중앙 = `viewport.size/2`. **OS 마우스 위치 절대 사용 안 함** (test에서 마우스 위치를 임의 위치로 미리 설정 후 검증)
   - `InputEventJoypadButton`(VirtualCursor.position=(300,400) + initialized=true) → screen_pos=(300,400)
   - VirtualCursor=null 상태에서 `InputEventJoypadButton` → `{position_valid: false}` + SkillToolbar noop (인벤토리 변동 0)
8. **`tests/InputOriginAtZeroTest.tscn`** (헤드리스, codex review HIGH Round 7 #1 회귀 가드) — Stage에 ant를 world (0, 0)에 배치 + 카메라 변환으로 그 ant가 화면 중앙에 오도록 → 마우스 클릭 시뮬 → emit payload world_pos=(0,0) + position_valid=true → SkillToolbar가 정상 적용 (Vector2.ZERO를 에러로 오인 X)
9. **`tests/PadFirstStickInputTest.tscn`** (헤드리스, codex review HIGH Round 8 회귀 가드) — VirtualCursor 트리에 추가 직후 (default position=(0,0), `_virtual_cursor_initialized=false`) → 좌 스틱 simulator로 stick=(0.5, 0) 입력 1프레임 → `_ensure_virtual_cursor_ready` 경유로 viewport 중앙 init 발동 → 그 후 stick delta 가산 → emit된 first cursor_move의 screen_pos가 `viewport.size/2 + (0.5, 0) * speed * delta`와 일치 (default (0,0) 기준 X)
10. **`tests/SkillToolbarPositionGuardTest.tscn`** (헤드리스, codex review HIGH Round 9 #1 회귀 가드) — `EventBus.action_triggered.emit(SKILL_ASSIGN, {position_valid: false, ...})` → SkillToolbar의 `_try_assign`이 절대 호출 안 됨 + 인벤토리 변동 0 assert
11. **`tests/KbCursorCacheTest.tscn`** (헤드리스, codex review MEDIUM Round 9 #2 + HIGH Round 10 회귀 가드) — 다음 4 케이스로 cache가 모든 emit 경로에서 갱신되는지 보장:
    - **(A) 마우스 motion 경유** — `InputEventMouseMotion(position=(100,200))` 주입 → `_emit_cursor_move` 호출 확인 → `_last_cursor_screen=(100,200)` + `_last_cursor_valid=true` → 직후 Tab 발화 → payload.from_world_pos가 (100,200)→world 변환과 일치
    - **(B) 패드 eager init 경유** — VirtualCursor 미초기화 상태 + `InputEventJoypadButton(A)` 주입 → eager init 발동 + `_emit_cursor_move(viewport_center)` → `_last_cursor_screen=viewport_center` → 직후 Tab → payload.from_world_pos가 viewport_center→world와 일치
    - **(C) 패드 stick polling 경유** — VirtualCursor initialized + stick=(0.5,0) 1프레임 → `_process`에서 `_emit_cursor_move(_virtual_cursor.position)` → cache 갱신 → 직후 Tab → 갱신된 cache 위치 사용
    - **(D) cursor_move 한 번도 emit 안 함** — `_last_cursor_valid=false` 상태에서 Tab → invalid 리턴 (target_next_ant payload `position_valid=false`) → CursorTargeting noop
    - **(E) stale mode 가드** — InputModeTracker.mode를 "pad"로 stale 설정 + cursor_move 1회 emit만 → KB Tab 발화 → mode 읽지 않고 _last_cursor_world 사용 (assert: 코드 grep으로 `_resolve_position`에 InputModeTracker 참조 없음)

### 6.7 결정 보류

- **카메라 추적 곡선** — 화면 가장자리 80%부터 선형 vs 90%부터 가속 → 스테이지 빌드 후 튜닝. v0.1 = 80% 선형.
- **스틱 가속 곡선** — `pow(value, 1.5)` 기본. 사용자 옵션 노출은 phase 19(stage10-bomber-polish) 또는 post-MVP.

---

## 7. Phase 7 — input-pause-step (상세)

> **2026-05-16 업데이트 (codex impl-review Round 1 LOW-2)**:
> 본 §7은 v0.1 시점 초안이며, **실제 phase 8 구현 계약은 `phases/mvp/plans/phase08-plan.md` v2가 SoT**. 본 §의 다음 항목들이 v2와 차이가 있으므로 phase 진입 시 v2를 우선 참조한다.
> - **StepFrame**: 본 §7.3의 `process_frame` 패턴은 catch-up race로 인해 폐기됨. v2는 `await tree.physics_frame × 2`로 정확히 1 physics tick 보장 + `_step_token` 소유권 + InputRouter pause-actions gate + SceneFlow 2차 guard 사용.
> - **수정 대상 파일**: 본 §7.1이 명시한 `HUD.gd` / `SkillToolbar.gd` / `Ant.gd` 수정은 v2에서 모두 **변경 없음**으로 확정. process_mode 변경은 `SkillToolbar.tscn`(scene)만, paused 부여 invariant는 테스트로 잠금.
> - **InputModeTracker** 계약: v2는 이벤트 비소비 + autoload sibling order 비의존 + 게임 로직 코드 0참조(leak guard test로 enforced)를 명시.

### 7.1 변경 대상

**신규**:
- `scripts/input/InputModeTracker.gd` — Autoload. 마지막 입력 디바이스 추적, EventBus.input_mode_changed emit.
- `scripts/ui/InputHintLabel.gd` — HUD 자식. 모드 따라 텍스트 갱신.
- `scripts/core/StepFrame.gd` — pause 토글 + `get_tree().paused = true; await get_tree().process_frame; get_tree().paused = true` 패턴 (1 frame advance).

**수정**:
- `scripts/ui/HUD.gd` — InputHintLabel 인스턴스 추가.
- `SkillToolbar.gd` — pause 상태에서도 `skill_assign` 처리 보장 (`process_mode = PROCESS_MODE_ALWAYS`).
- `Ant.gd` — pause 시 state 전이는 다음 unpause 후 적용 (current state의 `_process(delta)`가 자연 멈춤).

### 7.2 pause 중 명령 예약

현 코드 흐름은 **이미 pause 중 부여 가능에 가까움**:
- `SkillToolbar._unhandled_input`은 `_process` 외에서 호출됨 → pause 영향 안 받음
- `Skill.apply(ant)`는 `ant.state` 변경만 → pause 영향 안 받음
- ant._process가 멈춰있어 효과는 unpause 후 발현

이번 phase는 **이를 명시적으로 보장 + 회귀 테스트 추가**:
- `process_mode = PROCESS_MODE_ALWAYS` 명시
- `tests/PausedAssignTest.tscn` — pause 진입 → blocker 부여 → unpause → blocker 효과 발현

### 7.3 StepFrame

- `pause_toggle` → `get_tree().paused = !paused`
- `step_frame` (paused 상태에서만):
  ```gdscript
  func step_frame() -> void:
      if not get_tree().paused: return
      get_tree().paused = false
      await get_tree().process_frame
      get_tree().paused = true
  ```

### 7.4 검증

1. Pause → 1~3 스킬 여러 개 부여 → unpause → 모두 동시에 효과 발현
2. Pause 상태에서 `step_frame` 1회 → 개미 1프레임만 전진 → 다시 pause
3. 디바이스 전환 시 InputHintLabel 즉시 변경 (5초 지연 없이)
4. Stage01~03 pause-assign-unpause 회귀

---

## 8. 마이그레이션 시나리오 — 회귀 안전망

### 8.1 SkillToolbar 마이그레이션 (Phase 5)

**현 상태** (`scripts/ui/SkillToolbar.gd`):
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and ... KEY_ESCAPE: ...   # cancel
    if not (event is InputEventMouseButton): return
    if mb.button_index != MOUSE_BUTTON_LEFT: return
    # _pending_skill_id 검사 + 적용
```

**마이그레이션 후** — 위치 동반 액션은 반드시 `position_valid` 가드 통과 후 처리 (codex review HIGH Round 9 #1):
```gdscript
func _ready() -> void:
    EventBus.action_triggered.connect(_on_action)

func _on_action(name: StringName, payload: Dictionary) -> void:
    match name:
        GameAction.SKILL_ASSIGN:
            if not payload.get("position_valid", false):
                return    # 좌표 추출 실패 — noop, 인벤토리 보존
            _try_assign(payload.world_pos)
        GameAction.SKILL_CANCEL:
            _pending_skill_id = ""
        GameAction.SKILL_SELECT_1, ..., SKILL_SELECT_8:
            _on_button_pressed(_slot_to_id(payload.slot))
        GameAction.SKILL_CYCLE_NEXT: _cycle(+1)
        GameAction.SKILL_CYCLE_PREV: _cycle(-1)
```

> Button.pressed → 직접 `_on_button_pressed` 유지. 마우스 클릭 자체는 InputRouter 경유 안 해도 됨 (UI Control). 단 _unhandled_input은 제거. 모든 위치 동반 액션 핸들러는 진입 직후 `position_valid` 가드 필수 — 회귀 테스트(`InputRouterEventDispatchTest`의 `position_valid:false` 케이스)에서 SkillToolbar의 `_try_assign`이 호출 안 되는 것 assert.

### 8.2 회귀 테스트 패키지

phase 5/6/7 각 종료 시 다음이 모두 PASS:
- `tests/Stage02HeadlessTest.tscn`
- `tests/Stage03HeadlessTest.tscn`
- `tests/BlockerOverlapTest.tscn`
- 신규: `tests/InputRouterTest.tscn` (phase 5)
- 신규: `tests/PadInputTest.tscn` (phase 6)
- 신규: `tests/PausedAssignTest.tscn` (phase 7)

---

## 9. 리스크

| 리스크 | 영향 | 완화 |
|---|---|---|
| `_unhandled_input` 우선순위로 UI Control과 충돌 | 높음 | viewport input handling 검증 + 회귀 테스트 |
| 패드 polling이 60fps에서 stick drift 누적 | 중간 | deadzone 0.15 + epsilon 검사 |
| 카메라 추적 + 가상 커서 동시 이동 시 멀미 | 중간 | 추적 활성 임계값 80%로 보수적 시작 |
| pause 중 `_process` 멈춰서 InputModeTracker가 안 도는 이슈 | 낮음 | Tracker는 PROCESS_MODE_ALWAYS |
| 액션 이름 오타 → silent fail | 중간 | GameAction.gd const만 사용, magic string ban (lint) |
| InputMap이 project.godot에 비대해짐 | 낮음 | 액션 18개 한도 (4.1 표). 초과 시 옵션 B로 재논의 |
| **좌표 변환 누락 → 잘못된 ant 선택 (codex review HIGH Round 1+5)** | 높음 | CoordSpace.gd 단일 SoT + InputRouter._resolve_screen_pos가 event source별 분기 (마우스 button.position / 패드 button → virtual_cursor.position / 키 → mode 분기) + Shifted-camera 회귀 테스트 2개 (마우스 InputRouterShiftedCameraTest + 패드 PadShiftedCameraTest) — **둘 다 같은 CoordSpace 변환 경로 사용 검증** + payload에 screen+world 둘 다 포함하는 강제 계약 + SkillToolbar는 payload.world_pos만 사용 (디바이스 분기 금지) |
| **`cursor_move`를 InputMap에 등록하면 마우스 모션 발화 안 됨 (codex review MEDIUM Round 2)** | 중간 | `cursor_move` / `camera_pan`(패드) / `camera_zoom`(LT/RT)을 synthetic action으로 분류 (§4.1). InputRouter 내부에서만 raw event 분기, 발화 액션 이름은 디바이스 무관 |
| **Pad B 단발/홀드 multi-action race → destructive (codex review HIGH Round 4)** | 높음 | B 버튼은 InputMap 미등록 + InputRouter raw 처리. press 시 timer + handled. release/expire 시점에 정확히 1개 액션 emit. KB측은 분리된 InputMap 액션 (Esc, Ctrl+R). PadButtonBHoldTest 회귀 가드 |
| **`_resolve_position` 잘못된 캐스트 / cursor 미초기화 / origin sentinel 오인 / 패드 mouse fallback / 첫 stick polling / consumer 가드 누락 / KB stale mode (codex review HIGH+MEDIUM Round 6~9)** | 높음 | (1) 캐스트는 InputEventMouse / InputEventScreenTouch / InputEventScreenDrag만, `InputEventWithModifiers` 캐스트 금지. (2) Validity는 `position_valid: bool` flag로 운반 (Vector2.ZERO sentinel 금지). **producer/consumer 동일 키명**. (3) 패드 origin 액션은 mouse fallback 금지. (4) `_ensure_virtual_cursor_ready` 단일 helper에서만 eager init + 초기 `cursor_move` emit. `_resolve_position`과 `_process` 폴링 둘 다 helper 경유. (5) **KB origin은 `_last_cursor_*` 캐시 사용 (mode 읽기 금지). 캐시는 `_emit_cursor_move`가 모든 디바이스 emit 시 갱신**. (6) **수신자(`SkillToolbar._on_action`)는 위치 동반 액션 진입 직후 `position_valid` 가드 필수** — 누락 시 회귀 테스트로 잡힘. (7) InputRouterEventDispatchTest + InputOriginAtZeroTest + PadFirstStickInputTest + SkillToolbarPositionGuardTest + KbCursorCacheTest 회귀 가드 |

---

## 10. 비-범위 (post-MVP로 명시 보류)

- **터치 입력** (phase 21 — input-touch): 핀치 / 드래그 앤 드롭 / 루페
- **Rewind**: 시뮬 롤백 또는 명령 undo (phase 22 — input-advanced). MVP에서 결정 동결
- **Preview**: 시뮬레이션 기반 결과 미리보기 (phase 22 — input-advanced). MVP는 hover 색상만
- **CommandWheel**: 패드 LB 홀드 / 터치 길게 (phase 22 — input-advanced)
- **Overlay**: 경로/위험/스킬 영역 시각화 (phase 22 — input-advanced)
- **사용자 키 리매핑 UI** (phase 22 — input-advanced 또는 v1.2)
- **마우스 모서리 자동 스크롤** (phase 22 — input-advanced)

---

## 11. 다음 액션 (v2)

1. ~~본 문서 사용자 검토 → phase 시프트 결정 OK 받기~~ ✅ (2026-05-09 사용자 승인: 1=신설/2=post/3=동의)
2. ~~`phases/mvp/phase05~11` 작성 + 기존 phase05~11 → 12~18 시프트~~ ✅ (v1 — 본 v2에서 추가 시프트됨)
3. ~~v2 개정: design_handoff 흡수 + UI_GUIDE 신설 + atoms 분리 → phase 5~12 input(3)+UI(5), stage 13~19~~ ✅ (REVISION_2026-05-09 §8~14 참조)
4. ~~Codex adversarial-review Round 1~8 누적 needs-attention → 수정 통과~~ ✅ (`phases/mvp/reviews/REVISION_2026-05-09-review.md`)
5. **⏸ Codex Round 9 재시도** — OpenAI usage limit 풀린 후. 절차는 `phases/mvp/REVISION_2026-05-09.md` §15.3 Step 2.
6. R9+ verdict clean 시 → §15.4 plan-revision 단일 commit
7. Ant.gd / Ant.tscn (stash@{0}) 처리 — 사용자 의도 확인 후 별도 commit / 폐기 / 보류
8. phase 5(input-action-foundation) plan 작성 → adversarial-review → 구현 → impl-review → 완료
9. phase 6(pad-cursor), 7(pause-step) 동일 절차
10. phase 8~12(UI 5종) — `docs/UI_GUIDE.md`(1차 SoT) + `docs/design_handoff/`(시각 레퍼런스)로 plan 작성. 8 Theme/에셋 → 9 atoms+Motion → 10 HUD/Toolbar 교체 → 11 StageDialog → 12 Title/Menu 순서. 사운드는 phase 11에서 `EventBus.sfx_request` hook만 잡고 post-MVP로 분리.
11. phase 13~19(기존 stage4~10) — input/UI 양쪽 안정된 상태에서 마우스/패드 양쪽 dev-test.
