# Phase 7 Plan v2: Input Pad + VirtualCursor

## v2 변경 요약

`reviews/phase07-review.md`의 HIGH 2건을 반영해 v1을 대체한다.

- `restart_stage`는 더 이상 emit-only 액션이 아니다. `SceneFlow`가 `EventBus.action_triggered`를 구독하고 `GameAction.RESTART_STAGE`를 `replay_stage()` 경로로 라우팅한다.
- D-Pad ant targeting은 전역 `"ants"` group 결과를 그대로 쓰지 않는다. `SceneFlow`가 현재 활성 stage subtree를 단일 SoT로 제공하고, `CursorTargetingResolver`는 그 subtree 자손만 후보로 사용한다.
- 위 두 경로는 각각 end-to-end 테스트를 필수 검증에 포함한다.

## 목표 (1줄)

ROG Ally X 패드 풀 매핑 + VirtualCursor(screen-space CanvasLayer) + 개미 스냅 점프(D-Pad left/right)를 도입해 phase 5의 InputRouter/EventBus 액션 흐름을 패드까지 확장한다. SkillToolbar는 payload만 소비하고 디바이스 분기는 추가하지 않는다. Stage01~03 KB+Mouse 회귀는 0건이어야 한다.

## SoT 참조

- `docs/INPUT_PLAN.md` §6 (문서상 Phase 6 = 현 status.json Phase 7)
- `docs/INPUT_PLAN.md` §2, §4.1, §5.3: 좌표 계약, raw B 처리, `_emit_cursor_move` 단일 SoT
- `docs/INPUT_MAPPING.md` v0.2 §3.1: 패드 binding 시각 레퍼런스
- `phases/mvp/reviews/phase07-review.md`: v2 blocking 수정 근거

## 비-범위

1. `camera_pan` / `camera_zoom` 및 우 스틱/LT/RT polling. CameraController가 아직 없으므로 별도 phase로 보류한다.
2. `InputModeTracker`, `InputHintLabel`, `back_menu` 라우팅. Phase 8/12/13 범위다.
3. 화면 가장자리 cursor 자동 카메라 추적. CameraController 합류 전에는 viewport clamp만 수행한다.
4. SkillToolbar의 패드 UI 힌트, LB/RB 강조, atom 기반 교체. Phase 11 범위다.

## 변경/추가 파일

### 신규: `scripts/ui/VirtualCursor.gd`

- screen-space 표시 전용 노드.
- root scene은 `CanvasLayer`, 실제 움직이는 child는 `Control`이다.
- InputRouter가 `Control.position`을 직접 갱신한다.
- `EventBus.action_triggered`에서 `GameAction.CURSOR_MOVE`를 읽어 visible/fade 상태만 갱신한다.
- 마우스 모션을 `_input`에서 감지하면 `visible = false`로 전환한다.
- `_input`/`_unhandled_input`에서 `set_input_as_handled()`를 절대 호출하지 않는다.
- idle 5초 후 alpha 0.4로 fade한다.

### 신규: `scenes/ui/VirtualCursor.tscn`

```text
VirtualCursor (CanvasLayer, layer=11, follow_viewport_enabled=false)
└── Cursor (Control, 16x16, mouse_filter=IGNORE)
```

`Main.tscn`의 `GlobalUI` 형제로 배치한다. Stage 전환 중에도 살아 있어야 한다.

### 신규: `scripts/input/CursorTargeting.gd`

- `RefCounted` static-only utility.
- API:

```gdscript
static func find_next_ant(from_world: Vector2, ants: Array, direction: int, last_target: Ant) -> Ant
```

- `direction`: `+1` = next, `-1` = prev.
- 후보는 alive ant만 포함한다.
- 정렬은 `from_world` 기준 거리, tie-breaker는 `get_instance_id()`.
- `last_target`이 후보에 있으면 다음/이전 후보로 회전한다.
- 본 utility는 tree lookup을 하지 않는다. 활성 stage filtering은 호출자가 끝낸다.

### 신규: `scripts/ui/CursorTargetingResolver.gd`

- `Node`, `Main.tscn`의 `GlobalUI` 형제 또는 자식으로 배치한다.
- `EventBus.action_triggered`에서 `TARGET_NEXT_ANT`/`TARGET_PREV_ANT`만 처리한다.
- `SceneFlow`에서 주입받은 `active_stage_root`를 기준으로 후보 ant를 필터링한다.
- 전역 `"ants"` group은 후보 pool 수집에만 사용하고, 다음 조건을 모두 만족한 노드만 CursorTargeting에 넘긴다.
  - `is_instance_valid(n)`
  - `not n.is_queued_for_deletion()`
  - `active_stage_root != null`
  - `active_stage_root.is_ancestor_of(n)`
  - `n is Ant`
- target을 찾으면 `CoordSpace.world_to_screen(target.global_position, viewport)`로 변환하고 `InputRouter.request_cursor_jump(screen_pos)`만 호출한다.
- resolver가 VirtualCursor position이나 InputRouter cache를 직접 쓰지 않는다.

### 수정: `scripts/input/InputRouter.gd`

- `_process(delta)`에 좌 스틱 polling과 B-hold timer를 구현한다.
- `_ensure_virtual_cursor_ready()`는 viewport center 초기화와 최초 `_emit_cursor_move()`를 담당한다.
- `request_cursor_jump(screen_pos: Vector2)` public method를 추가한다.
- D-Pad target 액션은 emit 단계에서 100ms throttle한다.
- 패드 B는 raw `InputEventJoypadButton`으로만 처리한다.
  - release before 1초: `GameAction.SKILL_CANCEL`
  - press 유지 1초 이상: `GameAction.RESTART_STAGE` 1회
  - hold 후 release: noop
- B raw event는 처리 후 viewport input handled 처리한다.
- `GameAction.CURSOR_MOVE` 직접 emit은 계속 금지하고 `_emit_cursor_move()`만 사용한다.

상수:

```gdscript
const B_HOLD_THRESHOLD: float = 1.0
const PAD_STICK_DEADZONE: float = 0.15
const PAD_CURSOR_SPEED: float = 800.0
const TARGET_EMIT_COOLDOWN_MSEC: int = 100
```

### 수정: `scripts/core/SceneFlow.gd`

`SceneFlow`가 phase 7의 game-flow-facing 액션 소비자가 된다.

- `GameAction` preload 추가.
- `@export var virtual_cursor_path: NodePath`
- `@export var cursor_targeting_resolver_path: NodePath`
- `_ready()`에서 InputRouter에 VirtualCursor Control을 주입한다.
- `_ready()`에서 CursorTargetingResolver에 active stage provider를 주입한다.
- `EventBus.action_triggered.connect(_on_action_triggered)` 추가.
- `_on_action_triggered(name, payload)`에서:
  - `GameAction.RESTART_STAGE`면 overlay hide, current stage unfreeze, `replay_stage()` 호출.
  - 그 외 액션은 무시.
- `func get_active_stage_root() -> Node` 또는 `func get_current_stage_container() -> Node` 제공.
  - resolver는 이 노드의 자손만 ant 후보로 인정한다.
  - `CurrentStageRoot` 자체를 반환해도 되고, 현재 stage instance를 반환해도 된다. 구현에서는 더 좁은 현재 stage instance 반환을 우선한다.
- `load_stage()`에서 현재 stage instance를 저장한다.
- `_unload_current_stage()` 직후/직전에 stale reference가 남지 않도록 current stage instance를 null 처리한다.

중요: `RESTART_STAGE`를 `EventBus.request_replay.emit()`으로 우회해도 되지만, 최종 효과는 기존 replay 버튼과 동일해야 한다. 테스트는 active stage instance가 실제 교체되는지 검증한다.

### 수정: `scenes/Main.tscn`

예상 구조:

```text
Main
├── SceneFlow
├── CurrentStageRoot
├── GlobalUI (CanvasLayer layer=10)
│   └── StageResultOverlayStub
├── VirtualCursor (CanvasLayer layer=11)
│   └── Cursor
└── CursorTargetingResolver (Node)
```

`SceneFlow` export:

```text
current_stage_root_path = ../CurrentStageRoot
overlay_path = ../GlobalUI/StageResultOverlayStub
virtual_cursor_path = ../VirtualCursor/Cursor
cursor_targeting_resolver_path = ../CursorTargetingResolver
```

### 수정: `project.godot`

기존 KB/Mouse InputMap binding은 보존하고 패드 binding만 병합한다.

| 액션 | 추가 binding |
|---|---|
| `skill_assign` | JoyButton A |
| `skill_cycle_next` | JoyButton RB |
| `skill_cycle_prev` | JoyButton LB |
| `target_next_ant` | JoyButton D-Pad Right |
| `target_prev_ant` | JoyButton D-Pad Left |
| `pause_toggle` | JoyButton Back/View |
| `speed_toggle` | JoyButton R3 |
| `release_rate_up` | JoyButton D-Pad Up |
| `release_rate_down` | JoyButton D-Pad Down |
| `info_toggle` | JoyButton X |

`skill_cancel`과 `restart_stage`의 패드 B 입력은 InputMap에 등록하지 않는다. B는 raw 처리만 허용한다.

내부 polling 전용 InputMap 액션:

- `pad_cursor_left`: Left X negative
- `pad_cursor_right`: Left X positive
- `pad_cursor_up`: Left Y negative
- `pad_cursor_down`: Left Y positive

이 네 액션은 GameAction registry에 추가하지 않는다.

### 수정: `tests/GameActionContractTest.gd`

- `pad_cursor_left/right/up/down`을 internal InputMap whitelist에 추가한다.
- whitelist 주석에 "Input.get_vector polling only, not GameAction" 의도를 남긴다.

### 수정: `scripts/ant/Ant.gd`

- `func is_alive() -> bool`이 없으면 추가한다.
- true: Walker/Faller/Carrying/Worker 계열 상태.
- false: Saved/Dead 상태.

## 시그널 흐름

### 좌 스틱 -> cursor_move

```text
JoyAxis LEFT_X/LEFT_Y
  -> InputRouter._process
  -> _ensure_virtual_cursor_ready()
  -> VirtualCursor/Cursor.position clamp
  -> _emit_cursor_move(screen_pos)
  -> EventBus.action_triggered(cursor_move, {position_valid, screen_pos, world_pos})
  -> VirtualCursor visible/fade 갱신
```

### 패드 A -> skill_assign

```text
JoyButton A
  -> InputMap skill_assign
  -> InputRouter._emit_positional()
  -> screen_pos = VirtualCursor/Cursor.position
  -> world_pos = CoordSpace.screen_to_world(screen_pos, viewport)
  -> EventBus.action_triggered(skill_assign, payload)
  -> SkillToolbar는 payload.world_pos만 사용
```

### D-Pad left/right -> active-stage ant snap

```text
JoyButton D-Pad Left/Right
  -> InputRouter InputMap dispatch
  -> 100ms throttle
  -> EventBus.action_triggered(target_prev_ant/target_next_ant, {from_world_pos})
  -> CursorTargetingResolver
  -> active_stage_root = SceneFlow provider
  -> get_nodes_in_group("ants") 중 active_stage_root 자손만 필터
  -> CursorTargeting.find_next_ant(...)
  -> InputRouter.request_cursor_jump(screen_pos)
  -> InputRouter._emit_cursor_move(screen_pos)
```

금지: resolver가 `get_tree().get_nodes_in_group("ants")` 결과를 active stage filtering 없이 바로 사용하면 안 된다.

### 패드 B -> cancel/restart

```text
B press
  -> InputRouter raw handler starts timer
B release < 1s
  -> EventBus.action_triggered(skill_cancel, {})
B held >= 1s
  -> EventBus.action_triggered(restart_stage, {}) exactly once
  -> SceneFlow._on_action_triggered
  -> overlay hide + unfreeze + replay_stage()
```

## 엣지 케이스

1. **B-hold restart no-op 방지**: `RESTART_STAGE`는 반드시 SceneFlow가 소비한다. 테스트는 signal count가 아니라 stage instance 교체를 확인한다.
2. **전역 ant group stale contamination 방지**: replay/next-stage 직후 queued-free ant가 남아도 D-Pad 후보에서 제외한다.
3. **VirtualCursor 미주입 상태**: 패드 위치 동반 액션은 `position_valid=false`로 emit되거나 silent skip하고, 기존 KB/Mouse 흐름은 유지한다.
4. **패드 미연결**: `_process` polling은 early return한다.
5. **첫 stick 입력**: cursor는 viewport center에서 lazy init된 뒤 delta가 적용된다.
6. **D-Pad 연타**: 100ms 이내 두 번째 target emit은 skip한다.
7. **마우스/패드 동시 사용**: 마지막 cursor emit이 cache SoT다.
8. **Stage03 shifted camera**: 매번 `CoordSpace`와 viewport canvas transform을 사용하고 좌표 변환을 캐싱하지 않는다.
9. **dead/saved ant 제외**: `Ant.is_alive()` false 후보는 snap 대상이 아니다.
10. **ant 0마리**: resolver noop, cursor 위치 유지.

## 검증 시나리오

### 기존 회귀 필수

- `tests/Stage02HeadlessTest.tscn`
- `tests/Stage03HeadlessTest.tscn`
- `tests/BlockerOverlapTest.tscn`
- `tests/InputRouterTest.tscn`
- `tests/InputRouterShiftedCameraTest.tscn`
- `tests/InputRouterEventDispatchTest.tscn`
- `tests/InputOriginAtZeroTest.tscn`
- `tests/SkillToolbarPositionGuardTest.tscn`
- `tests/KbCursorCacheTest.tscn`
- `tests/GameActionContractTest.tscn`
- `tests/GameFlowTest.tscn`

### 신규 필수

- `tests/PadInputTest.tscn`: VirtualCursor 주입 상태에서 JoyButton A가 valid positional payload를 emit.
- `tests/PadShiftedCameraTest.tscn`: shifted Camera2D에서 pad assign world_pos가 transform inverse와 일치.
- `tests/PadButtonBHoldTest.tscn`: B single tap은 cancel 1회, B hold는 restart 1회 및 cancel 0회.
- `tests/PadRestartStageFlowTest.tscn`: `RESTART_STAGE` action emit 후 SceneFlow active stage instance가 실제 reload된다.
- `tests/PadDPadThrottleTest.tscn`: 50ms 간격 D-Pad 두 번 중 두 번째는 target emit 없음.
- `tests/CursorTargetingTest.tscn`: 거리 정렬, 방향, last_target 회전, alive 필터.
- `tests/CursorTargetingActiveStageTest.tscn`: old stage ant와 current stage ant가 동시에 `"ants"` group에 있을 때 current stage 자손만 snap 후보.
- `tests/VirtualCursorMousePassThroughTest.tscn`: VirtualCursor가 마우스 모션을 숨김 처리해도 InputRouter cursor_move가 막히지 않음.

### 수동

1. Stage03를 패드만으로 진행: 좌 스틱, LB/RB, A 사용.
2. 개미 5마리 이상일 때 D-Pad left/right snap 확인.
3. 마우스 이동 시 VirtualCursor hide, 좌 스틱 입력 시 show 확인.
4. B 단발 cancel과 B hold restart 구분 확인.
5. Stage01~03 KB+Mouse 기존 조작 회귀 확인.

## 구현 순서

1. `VirtualCursor` scene/script 추가.
2. `InputRouter`에 virtual cursor init, stick polling, raw B handling, cursor jump, D-Pad throttle 추가.
3. `SceneFlow`에 VirtualCursor 주입, active stage provider, `RESTART_STAGE` action routing 추가.
4. `CursorTargeting`과 `CursorTargetingResolver` 추가. resolver는 active stage provider 없으면 noop.
5. `Main.tscn` 노드 및 export path 연결.
6. `project.godot` InputMap 패드 binding 추가.
7. `Ant.is_alive()` 및 contract whitelist 추가.
8. 신규 테스트 추가 후 기존 회귀와 함께 실행.

## 마이그레이션 안전성

- SkillToolbar 변경 금지. payload.world_pos만 계속 사용한다.
- `EventBus.request_replay` 버튼 흐름과 `GameAction.RESTART_STAGE` 입력 흐름은 같은 최종 replay 동작을 공유한다.
- `StageRunner._living_ant_count()`의 active subtree invariant와 CursorTargetingResolver의 filtering invariant를 일치시킨다.
- `pad_cursor_*`는 internal InputMap action으로만 취급한다.
- Main.tscn을 우회하는 헤드리스 stage 테스트에서는 VirtualCursor 미주입 상태가 허용된다.

## 리스크 / 결정 보류

| 리스크 | 영향 | 완화 |
|---|---|---|
| SceneFlow가 `action_triggered`를 구독하면서 phase 8 이후 pause/menu 액션과 충돌 | 낮음 | Phase 7에서는 `RESTART_STAGE`만 처리하고 나머지는 무시한다. |
| active stage root reference가 reload 중 null | 중간 | resolver는 null이면 noop. replay/next transition test로 queued-free overlap을 검증한다. |
| VirtualCursor 초기화 순서가 stick polling보다 늦음 | 낮음 | `_ensure_virtual_cursor_ready()`가 매 frame 재시도한다. |
| `RESTART_STAGE`가 overlay 표시 중/미표시 중 모두 호출 가능 | 중간 | SceneFlow route에서 overlay hide + unfreeze 후 replay. 테스트에서 일반 진행 중 restart와 result overlay 중 replay 중 최소 하나를 검증한다. |
| `PAD_CURSOR_SPEED = 800.0` 체감 | 낮음 | v0.1 기본값. 수동 테스트 후 튜닝 가능. |

## 리뷰 반영 체크리스트

- [ ] `GameAction.RESTART_STAGE` consumer가 존재한다.
- [ ] B hold 테스트가 stage reload를 검증한다.
- [ ] CursorTargetingResolver가 active stage subtree filtering을 수행한다.
- [ ] D-Pad transition test가 old-stage ant를 무시함을 검증한다.
- [ ] SkillToolbar에 디바이스 분기가 없다.
- [ ] `get_nodes_in_group("ants")` 직접 사용 지점은 active subtree filtering 주석/테스트를 가진다.

## 표준 절차 참조

plan/review/deferred는 `phases/mvp/README.md` 참조. v2는 v1 plan review의 HIGH findings를 수정한 구현 기준 문서다.
