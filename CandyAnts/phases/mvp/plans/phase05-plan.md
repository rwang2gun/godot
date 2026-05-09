# Phase 5 Plan: Input Action Foundation (KB+Mouse)

## 목표 (1줄)
Godot InputMap 기반 액션 추상 레이어(InputRouter Autoload)를 도입해 SkillToolbar의 raw `_unhandled_input`/`_on_button_pressed` 흐름을 EventBus 액션 dispatch로 마이그레이션 — Pad/터치 가산을 위한 기반(payload validity 계약 + screen↔world 단일 SoT) 마련. Stage 1~3 회귀 0건.

## SoT 참조
- **`docs/INPUT_PLAN.md` §4.1 = action-name 단일 SoT** (Codex review HIGH Round 1 후속). `GameAction.gd`/InputMap entries/테스트/수신자 모두 본 표 정확 일치 — 매직 스트링 금지, oddly cased 변형 금지.
- `docs/INPUT_PLAN.md` §2(좌표 계약), §5(phase 5 상세) — 본 plan과 충돌 시 INPUT_PLAN 우선.
- `docs/INPUT_MAPPING.md` v0.2 (2026-05-09 갱신) — 디바이스 binding 시각 레퍼런스. v0.1과 비교해 액션 이름이 INPUT_PLAN §4.1로 정합 (`skill_cycle_*`, `target_*_ant`, `speed_toggle`, `step_frame` 등).
- 본 phase 범위는 KB+Mouse만. Pad polling, VirtualCursor, 패드 B 단발/홀드, 패드 첫 stick init, 모든 패드 회귀 테스트는 Phase 6.

## 변경/추가 파일

### 신규 — `scripts/input/`

#### `GameAction.gd` — 액션 ID 상수 (StringName)
- 매직 스트링 차단 SoT. 모든 emit/connect는 본 const만 사용.
- **Phase 5 범위**: INPUT_PLAN §4.1의 phase 5(KB+Mouse) 부분만 — **22개 const** (1 synthetic `CURSOR_MOVE` + 21 InputMap-registered: 8 SKILL_SELECT_n + SKILL_CYCLE_NEXT/PREV + SKILL_ASSIGN/CANCEL + TARGET_NEXT/PREV_ANT + PAUSE_TOGGLE + STEP_FRAME + SPEED_TOGGLE + RESTART_STAGE + RELEASE_RATE_UP/DOWN + INFO_TOGGLE). 일부 액션(PAUSE/STEP/SPEED/RESTART/RELEASE_RATE/INFO)은 phase 5 InputMap에 binding되지만 subscriber는 phase 7/12/19에 도입 — 사전 등록 0건이 우려되지 않음(silent emit, 수신자 없을 때 noop). `BACK_MENU`(phase 12 game state 분기), `CAMERA_PAN`/`CAMERA_ZOOM`(phase 6 CameraController)은 본 phase에서 const 등록 안 함. 각 phase 도입 시 const 추가 + contract test REGISTRY 갱신.
```gdscript
class_name GameAction
extends RefCounted

# === Synthetic (InputMap 미등록, InputRouter가 raw event/poll에서 직접 emit) ===
const CURSOR_MOVE         := &"cursor_move"

# === InputMap-registered (phase 5 KB+Mouse) ===
const SKILL_SELECT_1      := &"skill_select_1"
const SKILL_SELECT_2      := &"skill_select_2"
const SKILL_SELECT_3      := &"skill_select_3"
const SKILL_SELECT_4      := &"skill_select_4"
const SKILL_SELECT_5      := &"skill_select_5"
const SKILL_SELECT_6      := &"skill_select_6"
const SKILL_SELECT_7      := &"skill_select_7"
const SKILL_SELECT_8      := &"skill_select_8"
const SKILL_CYCLE_NEXT    := &"skill_cycle_next"
const SKILL_CYCLE_PREV    := &"skill_cycle_prev"
const SKILL_ASSIGN        := &"skill_assign"
const SKILL_CANCEL        := &"skill_cancel"
const TARGET_NEXT_ANT     := &"target_next_ant"
const TARGET_PREV_ANT     := &"target_prev_ant"
const PAUSE_TOGGLE        := &"pause_toggle"
const STEP_FRAME          := &"step_frame"
const SPEED_TOGGLE        := &"speed_toggle"
const RESTART_STAGE       := &"restart_stage"
const RELEASE_RATE_UP     := &"release_rate_up"
const RELEASE_RATE_DOWN   := &"release_rate_down"
const INFO_TOGGLE         := &"info_toggle"

# === 헬퍼 — slot index → SKILL_SELECT_n ===
const SKILL_SELECT_BY_SLOT: Array[StringName] = [
    SKILL_SELECT_1, SKILL_SELECT_2, SKILL_SELECT_3, SKILL_SELECT_4,
    SKILL_SELECT_5, SKILL_SELECT_6, SKILL_SELECT_7, SKILL_SELECT_8,
]

# === 위치 동반 액션 분류 — payload validity 가드 강제 SoT ===
const POSITIONAL_ACTIONS: Array[StringName] = [
    CURSOR_MOVE, SKILL_ASSIGN, TARGET_NEXT_ANT, TARGET_PREV_ANT,
]

static func is_positional(name: StringName) -> bool:
    return POSITIONAL_ACTIONS.has(name)

# === Contract registry (test_GameAction.gd가 본 표 vs InputMap 정합 검증) ===
# 각 entry: {name, kind, exact_match} where:
# - kind ∈ {"input_map", "synthetic"}
#   - "input_map" → InputMap.has_action(name) 반드시 true
#   - "synthetic" → InputMap.has_action(name) 반드시 false (router 내부 emit만)
# - exact_match: bool — _dispatch_input_map_action에서 is_action_pressed(name, false, exact_match)로 사용
#   - true: 모디파이어 정확 매치 필요 (target_*_ant Tab/Shift+Tab 분리, restart_stage Ctrl+R 정확)
#   - false: 모디파이어 톨러런트 (Ctrl+click도 skill_assign, Shift+1도 skill_select_1 등)
const REGISTRY: Array[Dictionary] = [
    {"name": CURSOR_MOVE,        "kind": "synthetic", "exact_match": false},
    {"name": SKILL_SELECT_1,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_SELECT_2,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_SELECT_3,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_SELECT_4,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_SELECT_5,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_SELECT_6,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_SELECT_7,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_SELECT_8,     "kind": "input_map", "exact_match": false},
    {"name": SKILL_CYCLE_NEXT,   "kind": "input_map", "exact_match": false},
    {"name": SKILL_CYCLE_PREV,   "kind": "input_map", "exact_match": false},
    {"name": SKILL_ASSIGN,       "kind": "input_map", "exact_match": false},
    {"name": SKILL_CANCEL,       "kind": "input_map", "exact_match": false},
    {"name": TARGET_NEXT_ANT,    "kind": "input_map", "exact_match": true},
    {"name": TARGET_PREV_ANT,    "kind": "input_map", "exact_match": true},
    {"name": PAUSE_TOGGLE,       "kind": "input_map", "exact_match": false},
    {"name": STEP_FRAME,         "kind": "input_map", "exact_match": false},
    {"name": SPEED_TOGGLE,       "kind": "input_map", "exact_match": false},
    {"name": RESTART_STAGE,      "kind": "input_map", "exact_match": true},
    {"name": RELEASE_RATE_UP,    "kind": "input_map", "exact_match": false},
    {"name": RELEASE_RATE_DOWN,  "kind": "input_map", "exact_match": false},
    {"name": INFO_TOGGLE,        "kind": "input_map", "exact_match": false},
]
```

#### `CoordSpace.gd` — screen↔world 변환 단일 SoT
```gdscript
class_name CoordSpace
extends RefCounted

# 매번 viewport.get_canvas_transform()을 다시 읽는다. 캐싱 금지(카메라 매 프레임 이동 가능).
static func screen_to_world(screen_pos: Vector2, viewport: Viewport) -> Vector2:
    if viewport == null:
        return screen_pos
    return viewport.get_canvas_transform().affine_inverse() * screen_pos

static func world_to_screen(world_pos: Vector2, viewport: Viewport) -> Vector2:
    if viewport == null:
        return world_pos
    return viewport.get_canvas_transform() * world_pos
```

#### `InputRouter.gd` — Autoload 단일 진입점
- `extends Node`. Autoload (`*` prefix → 루트 children, `_unhandled_input` 큐 마지막 핸들러).
- 두 진입점:
  - `_unhandled_input(event)` — InputMap 액션(`event.is_action_pressed(...)`) + raw `InputEventMouseMotion` 처리.
  - `_process(delta)` — 패드 stick polling (Phase 6에서 채움. **Phase 5 시점은 `_has_pad_connected()` → false면 즉시 return**, 가드만 남기고 본체 비활성).
- 핵심 필드:
  ```gdscript
  var _virtual_cursor: Control = null            # Phase 6에서 set_virtual_cursor()로 주입
  var _virtual_cursor_initialized: bool = false  # _ensure_virtual_cursor_ready 단일 진입점에서만 true
  var _last_cursor_screen: Vector2 = Vector2.ZERO
  var _last_cursor_world:  Vector2 = Vector2.ZERO
  var _last_cursor_valid:  bool    = false
  ```
- 핵심 함수 (INPUT_PLAN §5.3 발췌, 본 phase 구현 분량):
  - `_unhandled_input(event)`:
    1. `event is InputEventMouseMotion` → `_emit_cursor_move((event as InputEventMouseMotion).position)` 후 return (synthetic 발화는 InputMap에 등록 안 됨).
    2. `_dispatch_input_map_action(event)` 호출 — 등록된 액션 모두 순회, 첫 매칭 액션 emit. 위치 동반 액션은 `_resolve_position(event)`로 payload 채움.
  - `_dispatch_input_map_action(event)`:
    - 액션 리스트는 `GameAction.SKILL_SELECT_BY_SLOT` + 정적 단일 const 배열(이름 SoT).
    - **per-action exact_match policy** (codex review HIGH Round 13 + MEDIUM Round 14 후속): 액션마다 modifier-disambiguated인지 따라 exact_match 인자 분기:
      - **exact_match=true 액션** (modifier 변형이 다른 액션에 매핑된 경우, 정확 매치 필요):
        - `target_next_ant` (plain Tab) — Shift+Tab이 잘못 매치되면 안 됨
        - `target_prev_ant` (Shift+Tab) — plain Tab이 잘못 매치되면 안 됨
        - `restart_stage` (Ctrl+R) — plain R은 미바인딩이지만 명시적 정확 매치로 보호
      - **exact_match=false 액션** (모디파이어 톨러런트 — 사용자가 Ctrl/Shift 누른 상태에서도 기본 binding 발화 필요):
        - `skill_assign` (좌클릭) — Ctrl+click도 부여 가능해야 함 (사용자가 Ctrl을 다른 의도로 누르고 있을 때 silent fail 방지)
        - `skill_cancel` (우클릭만 — Esc는 phase 12) — 동일 이유
        - 모든 `skill_select_n` (1~8) — Shift+1, Ctrl+1 모두 슬롯 1 선택
        - `skill_cycle_next/prev` (Q/E)
        - `pause_toggle`/`step_frame`/`speed_toggle`/`release_rate_*`/`info_toggle` — 단순 키
      - 정책 SoT는 `GameAction.REGISTRY`의 각 entry에 `exact_match: bool` 필드 추가:
        ```gdscript
        {"name": SKILL_ASSIGN,    "kind": "input_map", "exact_match": false},
        {"name": TARGET_NEXT_ANT, "kind": "input_map", "exact_match": true},
        {"name": TARGET_PREV_ANT, "kind": "input_map", "exact_match": true},
        {"name": RESTART_STAGE,   "kind": "input_map", "exact_match": true},
        # ...others: "exact_match": false
        ```
      - `_dispatch_input_map_action`은 REGISTRY 순회하며 각 entry에 대해 `event.is_action_pressed(name, false, exact_match)` 분기. 위 표대로 강제.
    - 위치 비동반(`SKILL_CYCLE_NEXT`, `PAUSE_TOGGLE` 등) → payload `{}` emit.
    - 위치 동반(`SKILL_ASSIGN`, `TARGET_NEXT_ANT`, `TARGET_PREV_ANT`) → `_emit_positional(action, event)`로 위임.
    - 매 액션 처리 후 `viewport.set_input_as_handled()` 호출해 다른 핸들러로 가지 않도록.
  - `_emit_positional(action, event)`:
    1. `pos := _resolve_position(event)`.
    2. `pos.position_valid == false` → 그대로 emit (수신자가 `position_valid` 가드).
    3. true면 `world := CoordSpace.screen_to_world(pos.screen_pos, get_viewport())`.
    4. **`action == CURSOR_MOVE`인 경우 `_emit_cursor_move(pos.screen_pos)` 위임** (cache 갱신 + 단일 발화 경로). 그 외엔 직접 `EventBus.action_triggered.emit(action, {position_valid:true, screen_pos:pos.screen_pos, world_pos:world})`.
    5. `TARGET_NEXT_ANT`/`TARGET_PREV_ANT`는 raw event에 좌표 없음 — `_resolve_position` 내부 InputEventKey 분기에서 `_last_cursor_*` 캐시 사용. payload 키는 §5.3 명세대로 `from_world_pos`로 매핑(consumer 계약 일관 — INPUT_PLAN §5.3 표).
  - `_resolve_position(event)` — INPUT_PLAN §5.3 의사 코드 그대로:
    ```gdscript
    func _resolve_position(event: InputEvent) -> Dictionary:
        if event is InputEventMouse:
            return {"position_valid": true, "screen_pos": (event as InputEventMouse).position}
        if event is InputEventScreenTouch:
            return {"position_valid": true, "screen_pos": (event as InputEventScreenTouch).position}
        if event is InputEventScreenDrag:
            return {"position_valid": true, "screen_pos": (event as InputEventScreenDrag).position}
        if event is InputEventJoypadButton or event is InputEventJoypadMotion:
            if not _ensure_virtual_cursor_ready():
                return {"position_valid": false, "screen_pos": Vector2.ZERO}
            return {"position_valid": true, "screen_pos": _virtual_cursor.position}
        if event is InputEventKey:
            if not _last_cursor_valid:
                return {"position_valid": false, "screen_pos": Vector2.ZERO}
            return {"position_valid": true, "screen_pos": _last_cursor_screen}
        push_error("[InputRouter] unknown event type for positional action: %s" % event)
        return {"position_valid": false, "screen_pos": Vector2.ZERO}
    ```
    > Phase 5: `InputEventScreenTouch/Drag` 분기는 도달 가능 — 비록 InputMap에 터치 binding이 없지만 미래 phase 21이 추가될 때를 대비한 캐스트는 본 phase에서 미리 둠 (LOC < 4 추가). Joypad 분기는 도달하면 `_ensure_virtual_cursor_ready` → false → invalid 리턴 (안전).
  - `_ensure_virtual_cursor_ready()` — INPUT_PLAN §5.3 그대로 (Phase 6에서 `set_virtual_cursor()` 주입 후 활성). Phase 5에서는 `_virtual_cursor == null` → 항상 false 리턴.
  - `_emit_cursor_move(screen_pos)` — INPUT_PLAN §5.3 그대로. **CURSOR_MOVE의 유일한 emit 경로**. cache 갱신 + EventBus.action_triggered.emit. 직접 emit 금지(코드 grep으로 검증).
  - `_process(delta)` — Phase 5: `_has_pad_connected() == false` 빠른 return만. 본체는 phase 6.
  - `_has_pad_connected()` — `Input.get_connected_joypads().size() > 0`.
  - `set_virtual_cursor(c: Control)` — Phase 6 주입 hook (Phase 5에서는 호출자 없음, 인터페이스만).

### 수정 — `scripts/core/EventBus.gd`
1줄 형 시그널 2개 추가. **payload 형식은 위 GameAction.is_positional 분류와 일치** (소비자 가드 강제 SoT).
```gdscript
signal action_triggered(name: StringName, payload: Dictionary)
signal input_mode_changed(mode: StringName)  # "mouse" / "pad" / "touch" — Phase 7에서 InputModeTracker가 emit
```

### 수정 — `scripts/ui/SkillToolbar.gd`
`_unhandled_input` 제거 → `_on_action(name, payload)` 단일 핸들러. 위치 동반 액션은 진입 직후 `position_valid` 가드 필수 (INPUT_PLAN §5.3 / §8.1).

```gdscript
const _SLOT_ACTIONS: Array[StringName] = GameAction.SKILL_SELECT_BY_SLOT  # 슬롯 1~8

func _ready() -> void:
    # 기존 stage_data null 가드 + 인벤토리 복제 + 버튼 생성 그대로 유지
    EventBus.action_triggered.connect(_on_action)
    # 기존 _unhandled_input 분기 제거 — phase 5는 우클릭 → InputMap "skill_cancel" 액션 → EventBus.action_triggered(SKILL_CANCEL) 경로로 대체. Esc는 phase 5 InputMap에 미등록(phase 12에서 game state 분기와 함께 추가).

func _on_action(name: StringName, payload: Dictionary) -> void:
    match name:
        GameAction.SKILL_ASSIGN:
            if not payload.get("position_valid", false):
                return
            _try_assign(payload.get("world_pos", Vector2.ZERO))
        GameAction.SKILL_CANCEL:
            _pending_skill_id = ""
        GameAction.SKILL_CYCLE_NEXT:
            _cycle(+1)
        GameAction.SKILL_CYCLE_PREV:
            _cycle(-1)
        _:
            var slot_idx: int = _SLOT_ACTIONS.find(name)
            if slot_idx >= 0:
                _select_by_slot(slot_idx)

func _try_assign(world: Vector2) -> void:
    if _pending_skill_id == "":
        return
    var ant: Ant = _find_closest_ant(world)
    if ant == null:
        return
    var skill_script: Script = SkillRegistry.get_skill(_pending_skill_id)
    if skill_script == null:
        _pending_skill_id = ""
        return
    var skill: Skill = skill_script.new() as Skill
    if skill == null or not skill.can_apply(ant):
        _pending_skill_id = ""
        return
    skill.apply(ant)
    _inventory[_pending_skill_id] = int(_inventory[_pending_skill_id]) - 1
    _refresh_button(_pending_skill_id)
    print("[SkillToolbar] applied=", _pending_skill_id, " to=", ant.name,
        " remaining=", _inventory[_pending_skill_id])
    _pending_skill_id = ""

func _select_by_slot(slot_idx: int) -> void:
    if slot_idx < 0 or slot_idx >= stage_data.available_skills.size():
        return  # 슬롯 부재 → noop (소리/UI 거절은 phase 10 폴리싱)
    var id: String = stage_data.available_skills[slot_idx]
    _on_button_pressed(id)

func _cycle(step: int) -> void:
    if stage_data == null or stage_data.available_skills.is_empty():
        return
    var ids: Array = stage_data.available_skills
    var cur: int = ids.find(_pending_skill_id) if _pending_skill_id != "" else -1
    var next_idx: int = posmod(cur + step, ids.size())
    _on_button_pressed(ids[next_idx])
```

> Button.pressed → `_on_button_pressed`(id) 그대로 유지(UI 마우스 클릭 자체는 InputRouter 경유 안 해도 됨 — Control 우선). `_unhandled_input` 함수 자체는 삭제(viewport input 큐에 핸들러 0개 = InputRouter 단일).

### 수정 — `project.godot`
1. Autoload 4종으로 확장:
   ```
   [autoload]
   GameManager="*res://scripts/core/GameManager.gd"
   EventBus="*res://scripts/core/EventBus.gd"
   SkillRegistry="*res://scripts/core/SkillRegistry.gd"
   InputRouter="*res://scripts/input/InputRouter.gd"
   ```
   > 순서 결정 — InputRouter는 EventBus를 사용. Godot Autoload는 등록 순서대로 ready. EventBus가 먼저 ready돼야 InputRouter._ready가 connect 가능. 위 순서 유지.
2. `[input]` 섹션 신설(or 기존 추가). KB+Mouse만.
   ```
   [input]
   skill_assign={"deadzone":0.5,"events":[<MouseButton LEFT pressed>]}
   skill_cancel={"deadzone":0.5,"events":[<MouseButton RIGHT pressed>]}
   ; Esc는 phase 12에서 game state 분기 도입과 함께 skill_cancel/back_menu 양쪽에 binding 추가.
   ; phase 5에서 Esc 미바인딩 — codex review HIGH Round 15 후속 (phase 12 stateful routing 사전 잠금 방지).
   skill_select_1={"deadzone":0.5,"events":[<Key 1>]}
   ... (skill_select_2~8 동일 패턴)
   skill_cycle_next={"deadzone":0.5,"events":[<Key E>]}
   skill_cycle_prev={"deadzone":0.5,"events":[<Key Q>]}
   target_next_ant={"deadzone":0.5,"events":[<Key TAB>]}
   target_prev_ant={"deadzone":0.5,"events":[<Key TAB shift>]}
   pause_toggle={"deadzone":0.5,"events":[<Key SPACE>]}
   step_frame={"deadzone":0.5,"events":[<Key PERIOD>]}
   speed_toggle={"deadzone":0.5,"events":[<Key F>]}
   restart_stage={"deadzone":0.5,"events":[<Key R ctrl>]}
   release_rate_up={"deadzone":0.5,"events":[<Key F2>]}
   release_rate_down={"deadzone":0.5,"events":[<Key F1>]}
   info_toggle={"deadzone":0.5,"events":[<Key H>]}
   ```
   > **`back_menu`는 본 phase에 InputMap 등록 안 함**. INPUT_MAPPING §3.3에서 KB는 Esc 공유 (`skill_cancel`/메뉴 닫기 분기) — Phase 12(메뉴) 도입 시 game state 분기와 함께 `skill_cancel` Esc binding + `back_menu` Esc binding + dispatch state branching 동시 추가. **Phase 5에는 Esc 미바인딩** (codex review HIGH Round 15 후속). 우클릭만 skill_cancel.
   > **`cursor_move`만 synthetic-only** (mouse motion 직발화). **`camera_pan`/`camera_zoom`은 phase 5 미포함** — phase 6에서 GameAction const + KB InputMap binding(WASD / 마우스 휠) + 패드 synthetic poll(우 스틱 / LT/RT) 동시 추가. INPUT_MAPPING §2.1 참조.

### 신규 — TDD Guard 스텁 + Contract test (per-file 정책 준수)
- **`tests/test_GameAction.gd` — Contract test** (Codex review HIGH Round 1+3 후속). 단순 stub 아닌 동작형 contract:
  - **registry 일관성** (양방향 + 명시적 canonical 검증, codex review HIGH+MEDIUM Round 8~11 후속):

    **Canonical fixtures** — phase별 partition (Self-Review HIGH N+O 후속, 2026-05-09):
    - **이름 SoT (어떤 액션이 존재하는가)**: `docs/INPUT_PLAN.md` §4.1+§4.2 표.
    - **Partition SoT (각 액션이 어느 phase에 등록되는가)**: 본 plan의 fixture 자체가 SoT. INPUT_PLAN §4.1 표에 "phase" 컬럼이 없으므로, 액션→phase 매핑은 plan 작성자(2026-05-09)의 결정이고 본 fixture가 그 결정의 1차 진실원천.
    - **Code SoT (REGISTRY vs fixture)**: GDScript는 class const를 reflection으로 enumerate 못 하므로 REGISTRY(GameAction.gd)와 fixture(GameActionContractTest.gd)는 같은 정보를 두 곳에 기술하는 **순환 참조 구조**다. 회피 불가. 그래서 contract test가 두 곳 set equality를 검증해 silent drift를 차단. **REGISTRY를 1차 SoT, fixture를 mirror로 정책화** — fixture만 갱신하고 REGISTRY를 빠뜨리거나 그 반대 시 case 1(REGISTRY→fixture set equality)에서 fail.
    - 합치면 §4.1+§4.2 표 행 합과 정확히 일치.
    ```gdscript
    # tests/GameActionContractTest.gd 내부 fixture
    # === Phase 5 등록 대상 (synthetic 1 + InputMap 21 = 22) ===
    const CANONICAL_PHASE5_SYNTHETIC: Array[StringName] = [
        &"cursor_move",
    ]
    const CANONICAL_PHASE5_INPUT_MAP: Array[StringName] = [
        &"skill_select_1", &"skill_select_2", &"skill_select_3", &"skill_select_4",
        &"skill_select_5", &"skill_select_6", &"skill_select_7", &"skill_select_8",
        &"skill_cycle_next", &"skill_cycle_prev",
        &"skill_assign", &"skill_cancel",
        &"target_next_ant", &"target_prev_ant",
        &"pause_toggle", &"step_frame", &"speed_toggle",
        &"restart_stage", &"release_rate_up", &"release_rate_down",
        &"info_toggle",
    ]
    # === Phase 6 도입 예정 (CameraController 합류 시 KB InputMap + 패드 synthetic poll) ===
    const CANONICAL_PHASE6_DEFERRED: Array[StringName] = [
        &"camera_pan", &"camera_zoom",
    ]
    # === Phase 12 도입 예정 (메뉴 game state 분기) ===
    const CANONICAL_PHASE12_DEFERRED: Array[StringName] = [
        &"back_menu",
    ]
    # === Post-MVP (phase 21~22) — INPUT_PLAN §4.2 만 ===
    # 6 actions: §4.2 표 그대로. INPUT_MAPPING.md catalog의 추가 액션
    # (minimap_toggle, cursor_priority_toggle, camera_focus_cursor)은
    # INPUT_PLAN에 미등록이라 본 canonical fixture에 포함 안 함.
    # 누군가 그런 이름으로 InputMap action 추가하면 case 4 set equality에서 fail.
    const CANONICAL_POSTMVP_DEFERRED: Array[StringName] = [
        &"tap_drag_skill", &"pinch_zoom",
        &"rewind_hold", &"command_wheel_open", &"overlay_toggle", &"nuke",
    ]
    # 합집합 size 가드: 22 (phase 5) + 2 (phase 6) + 1 (phase 12) + 6 (post-MVP) = 31.
    # INPUT_PLAN §4.1+§4.2 표 행 합과 정확히 일치.
    const CANONICAL_TOTAL_SIZE: int = 31
    ```
    INPUT_PLAN §4.1 또는 §4.2가 변경되면 본 fixture 4개 + `CANONICAL_TOTAL_SIZE` 모두 갱신 필수. 변경 누락 시 contract test가 fail.

    **6단계 양방향 검증**:

    1. **REGISTRY → fixture 정확 set equality**: `Set(REGISTRY.filter(kind=="synthetic").map(name))` == `Set(CANONICAL_PHASE5_SYNTHETIC)`, `Set(REGISTRY.filter(kind=="input_map").map(name))` == `Set(CANONICAL_PHASE5_INPUT_MAP)`. 어느 한쪽이라도 set 차이 발생 시 fail (extra/missing/typo 모두 검출 — 새 typo가 REGISTRY+InputMap 양쪽에 동시 추가돼도 fixture와 안 맞아 fail).

    2. **GameAction const → REGISTRY 누락 검출**: GameAction의 emit-가능 const(헬퍼 `SKILL_SELECT_BY_SLOT`/`POSITIONAL_ACTIONS`/`REGISTRY` 제외) 명시 리스트를 직접 들어, REGISTRY에 누락된 const 있으면 push_error + fail.

    3. **REGISTRY size 일치 가드**: `GameAction.REGISTRY.size()` == `CANONICAL_PHASE5_SYNTHETIC.size() + CANONICAL_PHASE5_INPUT_MAP.size()` == 22 (1 + 21).

    4. **InputMap → fixture 정확 set equality** (codex review HIGH Round 9 + MEDIUM Round 10 후속): `InputMap.get_actions()`로 실제 InputMap action 이름(소문자 ID) enumerate. Godot 내장 액션(`ui_` 접두 일괄)을 필터링. 남은 모든 actions == `Set(CANONICAL_PHASE5_INPUT_MAP)`. 차이 발생 시 fail. **새 typo가 InputMap + REGISTRY 양쪽에 동시 등록돼도 fixture와 안 맞아 fail** — 본 케이스가 codex review MEDIUM Round 10 핵심 가드.

    5. **Negative fixture (legacy 이름 회귀 가드)**: 다음 옛 이름이 InputMap에 절대 등록되지 않음 — `InputMap.has_action(name) == false`. canonical 검증의 보완 (이중 안전망):
       - `skill_select_next`, `skill_select_prev` (INPUT_MAPPING v0.1 → v0.2 rename)
       - `cursor_target_next_ant`, `cursor_target_prev_ant`
       - `speed_up`, `speed_normal` (`speed_toggle`로 압축)
       - `cursor_move_to` (잘못된 별칭)

    6. **Deferred 가드** (canonical-fixture 기반): `CANONICAL_PHASE6_DEFERRED + CANONICAL_PHASE12_DEFERRED + CANONICAL_POSTMVP_DEFERRED`의 모든 이름이 `InputMap.has_action(name) == false` (phase 5 InputMap leak 방지). Phase 6 진입 시 contract test fixture에서 `CANONICAL_PHASE6_DEFERRED`를 `CANONICAL_PHASE6_INPUT_MAP`로 승격 + `CANONICAL_PHASE5_INPUT_MAP`과 합쳐 set equality 검증 — 동일 contract test 구조가 phase별 fixture만 갱신해 자동 회귀 가드.

    7. **Union size 자기검증** (codex review MEDIUM Round 12 후속): `CANONICAL_PHASE5_SYNTHETIC.size() + CANONICAL_PHASE5_INPUT_MAP.size() + CANONICAL_PHASE6_DEFERRED.size() + CANONICAL_PHASE12_DEFERRED.size() + CANONICAL_POSTMVP_DEFERRED.size()` == `CANONICAL_TOTAL_SIZE` (= 31). 일치하지 않으면 fail. INPUT_PLAN §4.1+§4.2 변경 후 fixture만 부분 갱신했을 때 검출 (size 상수 갱신 잊은 경우).

    실패 시 `[GameActionContract] FAIL <case> <details>` + quit(1). 모든 케이스 통과 시 `[GameActionContract] PASS` + quit(0).
  - **REGISTRY entries는 `kind` 따라 InputMap 검증**:
    - `kind == "input_map"` → `InputMap.has_action(name)` true 검증.
    - `kind == "synthetic"` → `InputMap.has_action(name)` false 검증 (synthetic 오등록 = INPUT_PLAN MEDIUM Round 2 회귀 가드).
  - **deferred 가드**: Phase 5 미포함 const(`back_menu`, `camera_pan`, `camera_zoom`)는 `InputMap.has_action`이 false여야 함 (phase 5 InputMap에 leak 방지). 본 phase에서 GameAction const도 미등록 — 향후 phase에서 const 추가 시 동일 contract test가 자동 검증.
  - 본 contract는 헤드리스 `tests/GameActionContractTest.tscn`(루트 Node + Phase5TestDriver script)로 실행 — `--quit-after 60` 안 PASS/FAIL emit. 실패 시 `[GameActionContract] FAIL ...` + `quit(1)`.
- `tests/test_CoordSpace.gd` — 3줄 stub (실제 검증은 InputRouterShiftedCameraTest).
- `tests/test_InputRouter.gd` — 3줄 stub (실제 검증은 InputRouterTest 외 6종).
- `tests/GameActionContractTest.tscn` + `tests/GameActionContractTest.gd` — Phase 5 verification §H에서 호출.

### 신규 — 헤드리스 회귀 테스트

#### `tests/InputRouterTest.tscn` + `tests/InputRouterTest.gd`
스코프: 단일 시나리오 안에서 EventBus.action_triggered emit 정확성 + payload validity 계약 검증. CRITICAL 레벨 회귀 가드.

테스트 케이스(코드 driver, **모두 동일 씬에서 직렬 실행**):
1. **case-A 마우스 motion → cursor_move emit + cache 갱신**:
   - `Input.parse_input_event(InputEventMouseMotion@(150, 250))` (or `_handle_input_event` API 사용).
   - assert: 직후 `EventBus.action_triggered`(`CURSOR_MOVE`) 1회 + payload `{position_valid:true, screen_pos:(150,250), world_pos:CoordSpace.screen_to_world((150,250), vp)}`.
2. **case-B 마우스 좌클릭 → skill_assign emit**:
   - `_pending_skill_id` 미설정 상태에서 InputEventMouseButton@(100,200) LEFT pressed 주입.
   - assert: `SKILL_ASSIGN` 1회 + payload `{position_valid:true, screen_pos:(100,200), world_pos:...}`.
3. **case-C Esc → 무 발화 검증 (회귀 가드, codex review HIGH Round 15+16 후속)**:
   - InputEventKey ESCAPE pressed 주입.
   - assert: 직후 `EventBus.action_triggered` 발화 **0회** (어떤 액션도 emit 안 됨). phase 5에서 Esc는 InputMap 미등록 — phase 12에서 game state 분기와 함께 Esc → `skill_cancel`(인게임/pending) / `back_menu`(메뉴 오픈) routing 도입 시 본 case는 update.
   - 우클릭 → skill_cancel은 case-F가 검증 (modifier-tolerant 마우스).
4. **case-D 슬롯 키 1~8 → skill_select_n**:
   - 각 키 주입 → 8회 emit.
5. **case-E Q/E → skill_cycle_prev/next, Tab/Shift+Tab → target_prev/next_ant** (codex review HIGH Round 13 후속):
   - Tab 주입 + cursor_move 미발화 상태(_last_cursor_valid=false) → `TARGET_NEXT_ANT` payload `{position_valid:false}`.
   - 그 후 마우스 motion 1회로 cache 채움 → Tab 재주입 → payload `{position_valid:true, from_world_pos:cached_world}`.
   - **Shift+Tab 회귀 가드**: `InputEventKey(keycode=KEY_TAB, shift_pressed=true, pressed=true)` 주입 → emit된 액션 정확히 `TARGET_PREV_ANT` 1회 + `TARGET_NEXT_ANT` 발화 0회. exact_match=true 가드 검증.
   - **Ctrl+R 회귀 가드**: `InputEventKey(keycode=KEY_R, ctrl_pressed=true, pressed=true)` 주입 → emit `RESTART_STAGE` 1회. plain R(없음) 매칭 안 됨.
6. **case-F modifier-tolerant 마우스 (codex review MEDIUM Round 14 후속)** — exact_match=false 정책 회귀 가드:
   - **Ctrl+좌클릭 → skill_assign 정상 발화**: `InputEventMouseButton(button_index=LEFT, pressed=true, ctrl_pressed=true, position=(100,200))` 주입 → emit `SKILL_ASSIGN` 1회 + payload `{position_valid:true, screen_pos:(100,200)}`. Ctrl 누른 상태에서도 부여 동작.
   - **Shift+우클릭 → skill_cancel 정상 발화**: `InputEventMouseButton(button_index=RIGHT, pressed=true, shift_pressed=true)` 주입 → emit `SKILL_CANCEL` 1회.
   - **Shift+1 → skill_select_1 정상 발화**: `InputEventKey(keycode=KEY_1, shift_pressed=true, pressed=true)` 주입 → emit `SKILL_SELECT_1` 1회. (Shift는 무시 — modifier-tolerant 정책)
   - **Alt+E → skill_cycle_next 정상 발화**: 동일 패턴. 모든 modifier-tolerant 키가 모디파이어 무관 발화.
7. **case-G (deferred 가드 sanity)**: `InputMap.has_action(&"camera_pan")` / `&"camera_zoom"` / `&"back_menu"` / `&"nuke"` 모두 false 검증 (phase 5 InputMap leak 부재 — GameActionContractTest와 중복이지만 InputRouterTest 환경에서도 1회 sanity).

검증 통과 시 `[InputRouterTest] PASS` + `quit(0)`. 실패 시 `quit(1)`.

#### `tests/InputRouterShiftedCameraTest.tscn` + `tests/InputRouterShiftedCameraTest.gd`
**CRITICAL 회귀 가드 — Codex review HIGH Round 1+5 대응** (INPUT_PLAN §5.6 #2).

scene 구성:
- 루트 Node + Camera2D(@(500,300), zoom=1.5,1.5, current=true) + Ant 1개 (group "ants", global_position=`canvas_xform.affine_inverse() * Vector2(400,300)` — 즉 화면 좌표 (400,300)에 정확히 위치).
- driver script:
  1. 1프레임 process_frame 대기 (카메라 transform 정착).
  2. InputEventMouseButton@(400,300) LEFT pressed 주입.
  3. EventBus.action_triggered(SKILL_ASSIGN) 수신 → assert payload.world_pos == CoordSpace.screen_to_world(Vector2(400,300), vp). 절대 ant.global_position과 거리 ≤ 1.0.
  4. (보조) SkillToolbar 없는 환경이라 `_find_closest_ant`를 driver가 직접 흉내내서 ant가 정확히 매치되는지 확인.

PASS/FAIL 동일 패턴.

#### `tests/InputRouterEventDispatchTest.tscn` + `tests/InputRouterEventDispatchTest.gd`
**INPUT_PLAN §6.6 #7의 phase 5 가능 부분만 본 phase에 선반영** — Pad 분기는 phase 6에서 본 driver 확장.

phase 5 케이스:
- `InputEventMouseButton`(position=(100,200)) → `{position_valid:true, screen_pos:(100,200)}` ✓
- `InputEventMouseMotion`(position=(150,250)) → `{position_valid:true, screen_pos:(150,250)}` ✓
- `InputEventScreenDrag`(position=(50,80)) — InputMap 미등록 액션이라도 `_resolve_position`이 valid 리턴 검증 (직접 `_resolve_position` 호출 — driver는 InputRouter 인스턴스의 helper에 접근 가능. 만약 private라 noop면 case 생략).

#### `tests/InputOriginAtZeroTest.tscn` + `tests/InputOriginAtZeroTest.gd`
**CRITICAL 회귀 가드 — Codex review HIGH Round 7 #1 대응** (INPUT_PLAN §6.6 #8).

scene:
- World Ant @ global_position=(0,0).
- Camera2D 변환으로 그 ant가 화면 중앙에 오도록 (camera @ (0,0) zoom=1, 화면 중앙 = (960,540) — viewport size 1920x1080 → screen_pos for world=(0,0) is `canvas_xform * (0,0) = canvas_xform.origin`).
- driver: 마우스 클릭 시뮬 (위 screen_pos에 정확히), SKILL_ASSIGN 수신 → assert `world_pos == Vector2(0,0)` + `position_valid == true`.
- 가공: SkillToolbar mock(`_pending_skill_id="builder"`)을 두고 `_try_assign`이 정상 호출 + Vector2.ZERO를 sentinel로 오인 안 함. **인벤토리 1 차감 확인**.

#### `tests/SkillToolbarPositionGuardTest.tscn` + `tests/SkillToolbarPositionGuardTest.gd`
**CRITICAL 회귀 가드 — Codex review HIGH Round 9 #1 대응** (INPUT_PLAN §6.6 #10).

scene:
- SkillToolbar instance + mock stage_data (skill_inventory={"builder":2}). _pending_skill_id="builder".
- driver:
  1. `EventBus.action_triggered.emit(SKILL_ASSIGN, {position_valid:false})` 강제 emit.
  2. assert `_pending_skill_id == "builder"` 보존 + `_inventory["builder"] == 2` 변동 0.
  3. 그다음 정상 emit `{position_valid:true, world_pos:<ant 위치>}` → 차감 1, _pending 클리어.

#### `tests/KbCursorCacheTest.tscn` + `tests/KbCursorCacheTest.gd` (case A + D만 — phase 5)
**INPUT_PLAN §6.6 #11 phase 5 부분.** 케이스 B/C(패드)는 phase 6.

- **(A) 마우스 motion → cache → Tab 키**:
  1. InputEventMouseMotion@(100,200) 주입 → cache 갱신 확인 (assert _last_cursor_screen==(100,200)).
  2. InputEventKey TAB pressed 주입 → `TARGET_NEXT_ANT` emit + `payload.from_world_pos == CoordSpace.screen_to_world(Vector2(100,200), vp)`.
- **(D) cursor_move 미발화 상태 Tab 키**:
  - 새 InputRouter 인스턴스 (또는 cache 강제 invalid). Tab 주입 → `payload.position_valid == false`.
- **(E) stale mode 가드**:
  - 코드 정적 검증: `scripts/input/InputRouter.gd`에 `InputModeTracker`/`input_mode` 문자열 grep → 0 hit. 본 phase에 InputModeTracker 없음 → 검증 자동 통과. driver는 Engine.has_singleton("InputModeTracker") == false 확인 후 OK.

> 회귀 테스트 6개 추가는 codex review가 phase 5/6에 걸쳐 정의한 가드를 phase 5 종료 시점에 가능한 만큼 끌어당기는 것. phase 6에서 같은 driver 파일에 케이스 추가(코드 라인만 늘어남, 새 씬 없음).

## 씬 트리 / Autoload (Phase 5 변경분)

```
Autoload (project.godot 순서):
  GameManager       res://scripts/core/GameManager.gd
  EventBus          res://scripts/core/EventBus.gd
  SkillRegistry     res://scripts/core/SkillRegistry.gd
  InputRouter       res://scripts/input/InputRouter.gd       (신규)

Stage scenes — 변경 없음 (SkillToolbar는 이미 자식. CanvasLayer 노드 트리 동일).
```

## 시그널 흐름 (Phase 5)

```
[마우스 모션]
InputEventMouseMotion(position=screen_pos)
    ▼ _unhandled_input → _emit_cursor_move(screen_pos)
       ├ cache 갱신 (_last_cursor_*)
       └ EventBus.action_triggered.emit(CURSOR_MOVE, {position_valid:true, screen_pos, world_pos})

[좌클릭]
InputEventMouseButton(LEFT pressed, position=screen_pos)
    ▼ _unhandled_input → _dispatch_input_map_action
        event.is_action_pressed("skill_assign") = true
    ▼ _emit_positional(SKILL_ASSIGN, event)
        pos = _resolve_position(event)  # InputEventMouse → screen_pos = event.position
        world = CoordSpace.screen_to_world(pos.screen_pos, vp)
    ▼ EventBus.action_triggered.emit(SKILL_ASSIGN, {position_valid:true, screen_pos, world_pos})
    ▼ SkillToolbar._on_action
        position_valid 가드 통과 → _try_assign(world_pos)
        → SkillRegistry.get_skill(_pending) → can_apply → apply → 인벤토리 차감

[Esc]
InputEventKey(ESCAPE pressed)
    ▼ _dispatch_input_map_action — phase 5 InputMap에 Esc 미등록 → 매칭 없음 → emit 0
    ▼ (phase 12에서 game state 분기와 함께 Esc → skill_cancel / back_menu routing 도입)
    ▼ phase 5 회귀 가드: InputRouterTest case-C가 Esc 주입 후 action_triggered 발화 0건 assert

[우클릭]
InputEventMouseButton(RIGHT pressed)
    ▼ _dispatch_input_map_action → SKILL_CANCEL (위치 비동반 → payload {})
    ▼ EventBus.action_triggered.emit(SKILL_CANCEL, {})
    ▼ SkillToolbar._on_action → _pending_skill_id = ""

[1~8 슬롯 키]
InputEventKey(KEY_1 pressed)
    ▼ _dispatch_input_map_action → SKILL_SELECT_1
    ▼ EventBus.action_triggered.emit(SKILL_SELECT_1, {})
    ▼ SkillToolbar._on_action → _select_by_slot(0)
        → stage_data.available_skills[0] → _on_button_pressed(id)
        → _pending_skill_id = id

[Tab — 위치 동반 KB 액션]
InputEventKey(TAB pressed)
    ▼ _dispatch_input_map_action → TARGET_NEXT_ANT
    ▼ _emit_positional(TARGET_NEXT_ANT, event)
        pos = _resolve_position(event)  # InputEventKey → cache 사용
        if not _last_cursor_valid → {position_valid:false}
        else → {position_valid:true, screen_pos:_last_cursor_screen}
    ▼ EventBus.action_triggered.emit(TARGET_NEXT_ANT, {position_valid, from_world_pos:_last_cursor_world})
    ▼ (CursorTargeting 수신자는 phase 6에 추가, phase 5는 emit만 검증)

[기존 SkillToolbar 버튼 클릭 — UI Control 직접 경로]
Button.pressed (직접 시그널)
    ▼ SkillToolbar._on_button_pressed(id) (마이그레이션 영향 없음)
        _pending_skill_id = id
```

## 핵심 결정 (선택지 + 사유)

1. **InputMap 등록 위치 = `project.godot` 직접 (옵션 A)** — INPUT_PLAN §5.5. 표준 + 에디터 GUI 가시성. 18개 액션은 `project.godot` 비대 한도 내. 향후 옵션 B 전환은 액션 30+개일 때 재논의.
2. **`cursor_move`만 synthetic-only** — InputMap 등록 시 `event.is_action_pressed`가 마우스 모션 발화 안 함(Codex review MEDIUM Round 2 가드). InputRouter 내부 raw 분기에서만 emit. **`camera_pan`/`camera_zoom`은 INPUT_PLAN §4.1에서 KB는 InputMap (WASD source-actions / 마우스 휠), 패드는 synthetic (우 스틱 poll / LT/RT analog poll) — 두 producer 모두 phase 6 도입**. Phase 5 plan은 const 미등록 + InputMap 미등록 + 회귀 가드(deferred contract)로 현 시점 unbound임을 보장. Phase 6에서 동일 contract registry에 entry 2개 추가 + KB binding + 패드 producer 동시 합류.
3. **payload validity = `position_valid: bool` flag** — Vector2.ZERO sentinel 금지. INPUT_PLAN §5.3 / §6.6 #8. world (0,0)에 ant 있는 stage(예: stage1 spawn) 정상 동작 보장.
4. **CURSOR_MOVE 단일 emit 경로 = `_emit_cursor_move`** — INPUT_PLAN §4.1 footnote / §6.6 #11(E). 다른 곳에서 직접 `EventBus.action_triggered.emit(CURSOR_MOVE, ...)` 호출 금지. cache stale 위험 차단.
5. **`_ensure_virtual_cursor_ready` 단일 진입점** — eager init은 본 helper에서만. INPUT_PLAN §6.6 #9. Phase 5는 `_virtual_cursor==null` → 항상 false 리턴 (안전).
6. **KB origin 위치 동반 액션 = `_last_cursor_*` 캐시** — `InputModeTracker.mode` 읽기 금지 (UI 힌트 전용). INPUT_PLAN §5.3 / §6.6 #11(E). Phase 5 시점 InputModeTracker 부재로 정적 grep 통과 자동.
7. **위치 동반 액션 분류 SoT = `GameAction.POSITIONAL_ACTIONS`** — payload 형식 강제 SoT. SkillToolbar `_on_action`이 `position_valid` 가드 누락 시 회귀 테스트(SkillToolbarPositionGuardTest)가 잡음.
8. **SkillToolbar 마이그레이션은 `_unhandled_input` 제거 + `_on_action` 추가만** — 기존 Button.pressed → `_on_button_pressed` 경로 보존. UI Control 우선순위 보장(viewport `is_input_handled` → `_unhandled_input`까지 안 옴).
9. **`info_toggle` 핸들러 본 phase 미연결** — InputMap entry 등록(`info_toggle`)하지만 emit은 InputRouter가 함. SkillToolbar는 받지 않음 (subscriber는 phase 7/12에 도입). **`back_menu`는 phase 5 GameAction const + InputMap 둘 다 미등록 + Esc도 미바인딩** — phase 5에서 `skill_cancel`은 우클릭 단일 매핑이고 Esc는 어떤 액션에도 매핑되지 않음. 메뉴 분기는 phase 12 game state 도입 시 `back_menu` const + Esc InputMap entry(`skill_cancel`/`back_menu` 양쪽) + dispatch 분기 로직 동시 추가 (codex review HIGH Round 15+16 후속).
9b. **`camera_pan`/`camera_zoom` 본 phase 미포함** — INPUT_PLAN §4.1은 KB camera_pan(WASD)·camera_zoom(휠)을 InputMap-registered + 패드 paths를 synthetic으로 분류. **그러나 phase 5에는 CameraController 소비자가 없음**(스테이지 카메라 고정). Phase 6에서 VirtualCursor + 카메라 컨트롤러 도입 시 `CAMERA_PAN`/`CAMERA_ZOOM` GameAction const + InputMap 등록 + KB(InputMap) / 패드(synthetic poll) 양 producer 동시 추가. Phase 5 contract test의 `deferred 가드`가 본 phase에 leak 방지.
10. **Notion phase 5 동기화** — phase 5 plan 작성 시점에 `상태=진행 중`으로 갱신 완료 (CLAUDE.md 정책 §1).

## 엣지 케이스 (필수)

1. **마우스 클릭이 SkillToolbar UI 영역(버튼)일 때 `skill_assign` 미발화** — UI Control이 먼저 input 소비 → InputRouter `_unhandled_input` 미수신. **검증**: SkillToolbar Button을 클릭하면 `_on_button_pressed`만 호출되고 `_try_assign`은 호출 안 됨. `tests/Stage02HeadlessTest.tscn` 회귀로 보장(기존 stage2가 버튼 클릭 → 펜딩 → 캔버스 클릭 → 부여 패턴 검증).
2. **`_pending_skill_id == ""`인데 좌클릭** — `_try_assign` 진입 시 가드 → 즉시 return. 인벤토리 보존. (회귀 테스트 case-B 변형으로 검증.)
3. **InputMap에 등록 안 된 액션 이름으로 emit 호출** — `GameAction.gd` const만 사용. magic string 발생 시 컴파일 통과해도 `EventBus.action_triggered`에 들어간 이름이 InputMap과 매칭 안 돼 silent fail. **방어책**: `tests/InputRouterTest.gd`가 모든 등록 액션 발화를 검증.
5. **Tab으로 `target_next_ant` 발화 시 cursor 한 번도 emit 안 한 상태** — `_resolve_position`이 InputEventKey 분기에서 `_last_cursor_valid==false` → `position_valid:false` 리턴. CursorTargeting(phase 6)이 `position_valid` 가드로 noop. `KbCursorCacheTest` case-D가 강제.
6. **세계 좌표 (0,0)에 ant** — Vector2.ZERO 수신자 reject 위험(이전 review HIGH). `position_valid:true`로 명시 → `_try_assign`이 거리 비교만 함. `InputOriginAtZeroTest`가 강제.
7. **Camera2D origin 아닐 때(Stage03 카메라 (1210,540))** — `CoordSpace.screen_to_world`가 매번 `viewport.get_canvas_transform()` 재읽기. **회귀**: `InputRouterShiftedCameraTest` + Stage03HeadlessTest(이미 존재) 둘 다 PASS 필수.
8. **우클릭만 skill_cancel 매핑 (Esc는 phase 5에 미바인딩)** — codex review HIGH Round 15 후속. phase 12에서 menu game state 분기와 함께 Esc → skill_cancel(인게임 + pending) / back_menu(메뉴 오픈) routing 도입. phase 5는 우클릭 단일 cancel. 우클릭으로 cancel 시 `_dispatch_input_map_action`이 위치 비동반(`SKILL_CANCEL`)로 처리해 `_resolve_position` 호출 안 함 → 좌표 누락 우려 없음.
8b. **Esc 키 → 무 발화 검증 (회귀 가드)** — `tests/InputRouterTest.gd` **case-C**가 본 엣지 케이스를 강제. `InputEventKey(KEY_ESCAPE, pressed=true)` 주입 후 `EventBus.action_triggered` 발화 0건 assert. phase 12에서 Esc 등록 후 본 case는 update. (case-C와 본 항목은 같은 contract — 테스트 spec과 엣지 케이스 양 곳에서 명문화하여 stale 잔재 재발 방지.)
9. **회귀 — Stage01/02/03 마우스 클릭 → 부여** — Stage01 카메라 origin 가까움, Stage03 카메라 (1210,540) 시프트. 둘 다 회귀 PASS. `Stage03HeadlessTest`는 driver가 직접 BlockerSkill 적용(UI 우회) 패턴이라 본 phase 5 변경 영향 없음(여전히 PASS).
10. **EventBus.action_triggered 시그널 누락 connect** — InputRouter가 emit한 액션을 수신할 노드가 트리에 없으면 silent. **방어책**: SkillToolbar `_ready`에서 `connect`, 트리 제거 시 `disconnect` 안 해도 Godot이 자동 해제. 회귀 테스트가 emit 자체를 검증해 connect 누락 시 fail.

## 검증 시나리오

### A. Stage 1 회귀 (필수)
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 4500 res://scenes/stages/Stage01.tscn 2>&1 | Tee-Object stage1-regression.log
```
기대: `cleared score=1.0`, errors 0건, picked 10건, saved 10건. SkillToolbar 마이그레이션이 마우스 클릭 부여 흐름 깨뜨리지 않음 검증.

### B. Stage 2 회귀 (필수)
```powershell
python scripts/run_test.py tests/Stage02HeadlessTest.tscn
```
기대: `[Phase3Test] PASS`, exit 0, score >= 0.6. Builder + UI 버튼 클릭 패턴 회귀.

### C. Stage 3 회귀 (필수)
```powershell
python scripts/run_test.py tests/Stage03HeadlessTest.tscn
```
기대: `[Phase4Test] PASS`, exit 0, score >= 0.85. Camera2D (1210,540) 시프트 환경에서 회귀.

### D. BlockerOverlap 회귀 (필수)
```powershell
python scripts/run_test.py tests/BlockerOverlapTest.tscn
```
기대: PASS. (phase 4 sweep 완료 commit 회귀.)

### E. InputRouter 신규 테스트 (필수)
```powershell
python scripts/run_test.py tests/InputRouterTest.tscn
python scripts/run_test.py tests/InputRouterShiftedCameraTest.tscn
python scripts/run_test.py tests/InputRouterEventDispatchTest.tscn
python scripts/run_test.py tests/InputOriginAtZeroTest.tscn
python scripts/run_test.py tests/SkillToolbarPositionGuardTest.tscn
python scripts/run_test.py tests/KbCursorCacheTest.tscn
```
모두 exit 0 + `[<Test>] PASS` 출력.

### F. (수동, 선택) 에디터 플레이
1. F5 (main_scene = Stage03).
2. 1~2 키로 builder/blocker 슬롯 전환 → 좌클릭으로 부여 → 인벤토리 차감.
3. 우클릭으로 pending cancel (Esc는 phase 5에서 미바인딩 — 누른 후에도 펜딩 유지 확인).
4. Q/E로 cycle (선택지가 2개라 toggle 동작 확인).
5. Stage 좌측 클릭 → 빈 영역이면 noop.

### G. TDD Guard 통과
```powershell
@("GameAction","CoordSpace","InputRouter") | ForEach-Object {
  if (-not (Test-Path "tests/test_$_.gd")) { throw "FAIL: tests/test_$_.gd missing" }
}
```

### H. GameAction-InputMap contract test (Codex review HIGH Round 1 후속)
```powershell
python scripts/run_test.py tests/test_GameAction.gd
```
또는 별도 씬 `tests/GameActionContractTest.tscn`이 존재하면 그 씬 실행. 기대:
- exit 0
- `[GameActionContract] PASS` 출력
- `assert/push_error`로 매직 스트링 / 누락 InputMap entry / synthetic 오등록을 정적 검출

## 비포함 (Phase 6 / 7 / 12 으로 분리)

| 항목 | 처리 phase | 이유 |
|------|-----------|------|
| Pad InputMap binding (좌/우 스틱, ABXY, LB/RB, LT/RT, D-Pad, View, R3) | Phase 6 | INPUT_PLAN §6 |
| VirtualCursor 노드 + scene + Pad polling 본체 | Phase 6 | INPUT_PLAN §6.3 |
| Pad B 단발/홀드 raw 처리 + `restart_stage`/`back_menu` 분기 | Phase 6 | INPUT_PLAN §4.1 footnote |
| `_ensure_virtual_cursor_ready` eager init 활성 + `_emit_cursor_move(viewport_center)` | Phase 6 | InputRouter scaffolding은 phase 5에 두지만 본체는 phase 6 |
| `target_next_ant` 수신자(CursorTargeting) | Phase 6 | INPUT_PLAN §6.1 |
| `pause_toggle`/`step_frame` 수신자 | Phase 7 | INPUT_PLAN §7 |
| `back_menu` InputMap binding + 메뉴 game state 분기 | Phase 12 | INPUT_PLAN §4.1 |
| InputModeTracker (`input_mode_changed` emit) | Phase 7 | INPUT_PLAN §7.1 |
| 터치 binding (post-MVP phase 21) | Phase 21 | INPUT_PLAN §10 |
| Rewind/Preview/CommandWheel/Overlay (post-MVP phase 22) | Phase 22 | INPUT_PLAN §10 |

## 리스크

| 리스크 | 영향 | 완화 |
|---|---|---|
| **`_unhandled_input` 우선순위로 UI Control과 충돌** | 높음 | viewport `is_input_handled`까지 InputRouter가 받지 않음 + Stage02 회귀 테스트로 보장 |
| **액션 이름 오타 → silent fail** | 중간 | `GameAction.gd` const만 사용 + `InputRouterTest`가 모든 등록 액션 발화 검증 |
| **좌표 변환 누락 → 잘못된 ant 선택** | 높음 | `CoordSpace.gd` 단일 SoT + `InputRouterShiftedCameraTest` + 수신자가 `payload.world_pos`만 사용 (디바이스 분기 금지) |
| **payload validity 키 누락 (consumer가 `valid`/`is_valid` 등 다른 이름 사용)** | 높음 | `GameAction.POSITIONAL_ACTIONS` SoT + `SkillToolbarPositionGuardTest`가 `position_valid:false` 강제 emit 후 SkillToolbar noop 검증 |
| **Vector2.ZERO sentinel 오인 (world 원점 ant silent reject)** | 높음 | `position_valid: bool` flag 채택 + `InputOriginAtZeroTest` 강제 |
| **`CURSOR_MOVE` 직접 emit 경로 재발 (cache stale)** | 중간 | `_emit_cursor_move` 단일 진입점 + 코드 grep 정적 검증 + `KbCursorCacheTest` case-A |
| **InputMap이 project.godot에 비대해짐** | 낮음 | 액션 18개 한도 내 (§4.1 표). 30+개 도달 시 옵션 B 재논의 |
| **Autoload 순서 잘못 → InputRouter._ready에서 EventBus null** | 중간 | `project.godot` `[autoload]` 순서를 GameManager → EventBus → SkillRegistry → InputRouter로 명시 (EventBus 먼저) |
| **phase 12에서 Esc binding 도입 시 `skill_cancel`과 `back_menu` 둘 다 매칭 필요** | 중간 | Phase 5는 Esc 미바인딩(우클릭만 `skill_cancel`) + `back_menu` const/InputMap 미등록. phase 12에서 game state 분기 + Esc → state별 routing 도입. 본 phase 영향 0 (회귀 가드: InputRouterTest case-C가 Esc 주입 시 발화 0건 assert) |
| **Tab/Shift+Tab은 한 InputMap entry로 표현 가능?** | 낮음 | Godot InputEventKey는 `shift_pressed` 모디파이어로 entry 분리 가능 — `target_next_ant`(TAB plain), `target_prev_ant`(TAB shift) 두 entry |
| **Stage03 driver(`Stage03HeadlessTest.gd`)가 InputRouter 우회로 BlockerSkill 직접 적용 — 본 phase 변경 영향 0** | 낮음 | 의도적 설계. driver는 UI/InputRouter 시뮬 안 하고 핵심 로직만 검증. Stage03 회귀 PASS 보장 |

## Notion 동기화

- Phase 5 진입 시 (= 본 plan 작성 시점) `notion-phase-ids.json[5].page_id`로 상태=`진행 중` 갱신. **이미 완료**(2026-05-09 plan 작성 시점).
- Phase 5 완료 직전 (= adversarial-review verdict clean 후 `execute.py complete 5` 호출 직전) 상태=`완료`.
