# Phase 8 Plan v2: Pause / StepFrame / InputModeTracker

## 목표

`pause_toggle` 중에도 스킬 부여가 결정적으로 동작함을 보장하고, 정확히 한 physics tick만 전진하는 `step_frame` 헬퍼와 UI 힌트 전용 last-input 디바이스 추적기(`InputModeTracker`)를 도입한다.

`InputModeTracker`는 `InputHintLabel` 표시만 바꾼다. 게임 로직, 좌표 산출, 스킬 부여, 타게팅은 절대 input mode를 읽지 않는다.

## 리뷰 반영 요약

이 문서는 `phases/mvp/reviews/phase08-review.md`의 HIGH/MEDIUM 지적을 반영한 새 계획이다.

- `process_frame x 2`를 폐기하고 `await get_tree().physics_frame`으로 step의 시간 기준을 고정한다.
- StepFrame await 중 `pause_toggle` / `restart_stage` 재진입을 막는 `InputRouter` action gate와 StepFrame token을 추가한다.
- `InputModeTracker`의 autoload sibling ordering 주장을 제거한다. 이벤트 소비를 하지 않는다는 계약만 유지한다.
- `INPUT_PLAN.md` §7의 파일 목록과 본 phase의 실제 변경 목록을 명시적으로 재조정한다.
- paused GUI Button 경로를 실제 `Button.pressed` 또는 synthetic click으로 검증 대상에 포함한다.
- `InputHintLabel`은 `/root/InputModeTracker` null guard와 fallback을 필수로 한다.
- `_input` / `_unhandled_input` 용어를 consumed/unconsumed 경로 기준으로 분리해 적는다.

## SoT 참조

- `docs/INPUT_PLAN.md` §2 책임 분리: input mode는 UI 힌트 전용이며 게임 분기 금지.
- `docs/INPUT_PLAN.md` §5.3 `_last_cursor_*` cache 계약: KB origin 액션은 mode를 읽지 않는다.
- `docs/INPUT_PLAN.md` §7 Phase 7 input-pause-step: 본 Phase 8은 현재 `status.json` 번호 체계의 대응 phase다.
- `CLAUDE.md` plan-stage 정책: HIGH 발견 후 사용자가 수정 플랜 작성을 요청했으므로 v2를 작성한다. 자동 재리뷰 루프는 돌리지 않는다.

## 비-범위

1. 메뉴, `back_menu`, Esc 기반 game-state 분기. Phase 13 범위.
2. `InputHintLabel` 스타일링, Theme, Tokens 이관. Phase 9~10 범위.
3. pause/step 사운드와 햅틱 cue. Phase 12/21 범위.
4. stage result overlay freeze 흐름의 의미 변경. `_freeze_current_stage`는 결과 overlay용, `tree.paused`는 사용자 pause용이다.
5. `speed_toggle` 실제 시뮬레이션 속도 변경. 본 phase에서는 소비하지 않는다.

## 변경 파일

### 신규 `scripts/input/InputModeTracker.gd`

- `extends Node`.
- Autoload로 등록한다.
- `process_mode = Node.PROCESS_MODE_ALWAYS`.
- 역할: 마지막 입력 디바이스를 `&"mouse"`, `&"pad"`, `&"touch"` 중 하나로 분류하고, 변경 시 `EventBus.input_mode_changed(mode)`만 emit한다.
- 초기값: `&"mouse"`.
- 진입점: `_input(event: InputEvent)`.
- `_input`는 viewport의 일반 input path를 관찰하지만 이벤트를 소비하지 않는다. `set_input_as_handled()` 호출 금지.
- autoload sibling 순서에 의존하지 않는다. 먼저 보든 나중에 보든 read-only observer라서 결과가 같아야 한다.
- `InputEventKey`는 mode 변경 트리거가 아니다. 키보드는 PC mouse mode의 sub-device로 취급한다.

분류 규칙:

```gdscript
InputEventMouseButton / InputEventMouseMotion -> &"mouse"
InputEventJoypadButton / InputEventJoypadMotion -> &"pad"
InputEventScreenTouch / InputEventScreenDrag -> &"touch"
InputEventKey -> no change
```

API:

```gdscript
var _mode: StringName = &"mouse"

func get_mode() -> StringName:
    return _mode
```

금지:

- `InputRouter`, `SkillToolbar`, `VirtualCursor`, `CursorTargetingResolver` 참조 금지.
- 게임 action emit 금지. `input_mode_changed`만 emit한다.

### 신규 `scripts/core/StepFrame.gd`

- `extends Node`.
- Autoload로 등록한다.
- `process_mode = Node.PROCESS_MODE_ALWAYS`.
- 역할: `pause_toggle`, `step_frame`의 단일 소비자.
- `_ready()`에서 `EventBus.action_triggered.connect(_on_action)`.

핵심 상태:

```gdscript
const GameAction := preload("res://scripts/input/GameAction.gd")

var _stepping: bool = false
var _step_token: int = 0
```

액션 처리:

```gdscript
func _on_action(name: StringName, _payload: Dictionary) -> void:
    if name == GameAction.PAUSE_TOGGLE:
        if _stepping:
            return
        var tree := get_tree()
        if tree != null:
            tree.paused = not tree.paused
        return

    if name == GameAction.STEP_FRAME:
        _step_frame_once()
```

StepFrame:

```gdscript
func _step_frame_once() -> void:
    var tree := get_tree()
    if tree == null or not tree.paused:
        return
    if _stepping:
        return

    _stepping = true
    _step_token += 1
    var token := _step_token

    tree.paused = false
    await tree.physics_frame

    if token == _step_token and is_inside_tree():
        tree.paused = true

    if token == _step_token:
        _stepping = false
```

설계 이유:

- `SceneTree.process_frame`은 idle-frame signal이라 physics step 수를 보장하지 않는다.
- 본 phase의 step 정의는 "정확히 한 physics tick 허용 후 다시 pause"다.
- `physics_frame`은 physics frame 직전 emit된다. pause를 풀고 다음 physics frame signal까지 기다리면 그 physics tick이 실행된 뒤 coroutine이 재개되고, 그 즉시 다시 pause한다.
- `_step_token`은 씬 전환, 수동 cancel, 테스트 teardown 같은 상황에서 낡은 await continuation이 현재 상태를 덮지 못하게 하는 소유권 표시다.

### 수정 `scripts/input/InputRouter.gd`

StepFrame await 중 pause-affecting action을 막는 action gate를 추가한다.

신규 상태/API:

```gdscript
var _pause_actions_blocked: bool = false

func set_pause_actions_blocked(blocked: bool) -> void:
    _pause_actions_blocked = blocked

func are_pause_actions_blocked() -> bool:
    return _pause_actions_blocked
```

`_dispatch_input_map_action(event)`에서 action emit 직전:

```gdscript
if _pause_actions_blocked and _is_pause_affecting_action(name):
    var vp := get_viewport()
    if vp != null:
        vp.set_input_as_handled()
    return
```

신규 helper:

```gdscript
func _is_pause_affecting_action(name: StringName) -> bool:
    return name == GameAction.PAUSE_TOGGLE \
        or name == GameAction.STEP_FRAME \
        or name == GameAction.RESTART_STAGE
```

Pad B hold path도 gate를 통과해야 한다.

- `_on_pad_b` release에서 `SKILL_CANCEL`은 허용한다.
- `_tick_b_button`에서 `RESTART_STAGE` emit 직전 `_pause_actions_blocked`이면 emit하지 않고 hold 상태를 정리한다.
- StepFrame 중 입력은 "queue"하지 않고 ignore한다. step은 debug/helper 성격이고, 중간 pause/restart 예약은 사용자 기대보다 race 위험이 크다.

StepFrame은 stepping 시작/종료 시 다음처럼 gate를 제어한다.

```gdscript
if InputRouter.has_method("set_pause_actions_blocked"):
    InputRouter.set_pause_actions_blocked(true)
...
if InputRouter.has_method("set_pause_actions_blocked"):
    InputRouter.set_pause_actions_blocked(false)
```

정리 보장:

- `StepFrame`은 `_notification(NOTIFICATION_PREDELETE)` 또는 `_exit_tree()`에서 gate를 false로 되돌린다.
- 테스트 teardown에서 gate가 남지 않도록 `StepFrameTest`가 검증한다.

### 수정 `scripts/core/SceneFlow.gd`

`RESTART_STAGE` 처리에서 StepFrame gate를 2차 방어로 확인한다.

```gdscript
func _on_action_triggered(name: StringName, _payload: Dictionary) -> void:
    if name != GameAction.RESTART_STAGE:
        return
    if InputRouter.has_method("are_pause_actions_blocked") and InputRouter.are_pause_actions_blocked():
        return
    EventBus.request_replay.emit()
```

이중 방어 이유:

- 일반 입력은 `InputRouter` gate에서 막힌다.
- 테스트나 다른 코드가 `EventBus.action_triggered.emit(GameAction.RESTART_STAGE, {})`를 직접 호출해도 씬 reload가 StepFrame await 중 끼어들지 않아야 한다.

### 신규 `scripts/ui/InputHintLabel.gd`

- `extends Label`.
- `process_mode = Node.PROCESS_MODE_ALWAYS`.
- `_ready()`에서 `EventBus.input_mode_changed.connect(_on_mode_changed)` 후 초기 텍스트를 설정한다.
- 초기 mode는 autoload 직접 호출 대신 null-safe lookup을 사용한다.

```gdscript
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    EventBus.input_mode_changed.connect(_on_mode_changed)
    var tracker := get_node_or_null("/root/InputModeTracker")
    var mode: StringName = &"mouse"
    if tracker != null and tracker.has_method("get_mode"):
        mode = tracker.get_mode()
    _on_mode_changed(mode)
```

텍스트:

```gdscript
mouse -> "Click: assign  ·  1~8: skill  ·  Space: pause"
pad   -> "A: assign  ·  LB/RB: cycle  ·  View: pause"
touch -> "Tap: assign"
```

금지:

- `InputRouter` 또는 game state 읽기 금지.
- 스킬 선택, 부여, cursor 위치에 관여 금지.

### 수정 `scenes/ui/HUD.tscn`

- Root VBoxContainer 마지막 자식으로 `InputHint` Label을 추가한다.
- script는 `res://scripts/ui/InputHintLabel.gd`.
- 초기 `text = ""`.

### 수정 `scripts/ui/HUD.gd`

변경 없음.

`INPUT_PLAN.md` §7의 "HUD.gd 수정"은 개념상 HUD에 힌트를 추가한다는 표현으로 보고, 본 phase의 파일 단위 SoT는 `HUD.tscn` + `InputHintLabel.gd`로 확정한다. 필요하면 별도 문서 정리 phase에서 `INPUT_PLAN.md`를 갱신한다.

### 수정 `scenes/ui/SkillToolbar.tscn`

- 최상위 `SkillToolbar` CanvasLayer에 `process_mode = 3` (`PROCESS_MODE_ALWAYS`)을 명시한다.
- paused 상태에서도 UI Button의 input/pressed 경로가 동작해야 한다.

### 수정 `scripts/ui/SkillToolbar.gd`

변경 없음.

Button pressed 경로와 `EventBus.action_triggered(SKILL_ASSIGN, payload)` 경로 모두 기존 책임을 유지한다. 본 phase는 scene process mode와 테스트로 pause 상태 동작을 잠근다.

### 수정 `scripts/ant/Ant.gd`

변경 없음.

pause 중 스킬 부여는 state 전이까지만 일어나고, 실제 physics 효과는 unpause 또는 step의 physics tick에서 발현된다. 본 phase는 이 invariant를 테스트로 고정한다.

### 수정 `scripts/core/EventBus.gd`

변경 없음.

`input_mode_changed`와 `action_triggered`는 이미 존재한다.

### 수정 `project.godot`

`[autoload]`에 추가:

```ini
InputModeTracker="*res://scripts/input/InputModeTracker.gd"
StepFrame="*res://scripts/core/StepFrame.gd"
```

등록 위치는 가독성을 위해 `InputRouter` 근처로 둔다. 동작은 sibling ordering에 의존하지 않는다.

## 시그널 흐름

### pause toggle

```text
InputEventKey(Space) / InputEventJoypadButton(View)
  -> InputRouter._unhandled_input
  -> EventBus.action_triggered(PAUSE_TOGGLE, {})
  -> StepFrame._on_action
  -> if not stepping: tree.paused = !tree.paused
```

### step frame

```text
[tree.paused = true]
InputEventKey(Period)
  -> InputRouter._unhandled_input
  -> EventBus.action_triggered(STEP_FRAME, {})
  -> StepFrame._step_frame_once()
     -> set InputRouter pause-actions gate = true
     -> token++
     -> tree.paused = false
     -> await tree.physics_frame
     -> if token still current: tree.paused = true
     -> set gate = false
```

### restart while stepping

```text
[StepFrame await open]
Ctrl+R or Pad B hold
  -> InputRouter sees RESTART_STAGE
  -> pause-actions gate blocks emit
```

Direct emit guard:

```text
EventBus.action_triggered(RESTART_STAGE, {})
  -> SceneFlow._on_action_triggered
  -> InputRouter.are_pause_actions_blocked() == true
  -> return
```

### last-input mode

```text
Any InputEvent
  -> InputModeTracker._input(event)
  -> classify mouse/pad/touch without consuming
  -> EventBus.input_mode_changed(mode) only when mode changed
  -> InputHintLabel updates text
```

`InputModeTracker._input` is a read-only observer path. `InputRouter._unhandled_input` remains the gameplay action dispatch path for unconsumed InputMap/raw events.

## 엣지 케이스

1. `step_frame` 연타: `_stepping`과 gate로 첫 step만 실행한다. 같은 await window의 추가 `STEP_FRAME`은 ignore.
2. step 중 pause toggle: gate 또는 StepFrame `_stepping` guard로 ignore. coroutine 마지막 `tree.paused = true`가 사용자 toggle을 덮는 race를 만들지 않는다.
3. step 중 restart: InputRouter gate와 SceneFlow 2차 guard로 reload를 막는다.
4. paused=false 상태의 step: noop. counter와 paused 상태 모두 유지.
5. stage result overlay freeze 중 step: `_current_stage_root.process_mode = DISABLED`이면 tree pause를 잠깐 풀어도 stage 내부 physics는 전진하지 않는다. 결과 overlay 중 step은 명시적 noop으로 취급한다.
6. InputModeTracker absent: `InputHintLabel`은 mouse fallback으로 초기화한다.
7. keyboard-only 사용자: mode는 mouse로 유지한다.
8. 같은 frame에 mouse/pad 입력이 모두 들어오는 경우: mode 변경 수만큼 emit될 수 있다. 수신자가 label뿐이라 idempotent하다.
9. mode leak: `InputRouter.gd`, `SkillToolbar.gd`, `Ant.gd`는 `InputModeTracker`를 참조하지 않는다.

## 검증 계획

### 기존 회귀

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
- `tests/PadInputTest.tscn`
- `tests/PadShiftedCameraTest.tscn`
- `tests/PadButtonBHoldTest.tscn`
- `tests/PadDPadThrottleTest.tscn`
- `tests/PadRestartStageFlowTest.tscn`
- `tests/CursorTargetingTest.tscn`
- `tests/CursorTargetingActiveStageTest.tscn`
- `tests/VirtualCursorMousePassThroughTest.tscn`

### 신규 `tests/StepFrameTest.tscn`

필수 케이스:

1. paused=true에서 `STEP_FRAME` emit 후 dummy node `_physics_process` counter가 정확히 1 증가하고 `tree.paused == true`.
2. paused=false에서 `STEP_FRAME` emit은 noop. counter 변화 0, paused=false 유지.
3. `PAUSE_TOGGLE` 두 번 emit하면 true -> false 토글.
4. paused=true 상태에서 같은 frame에 `STEP_FRAME` 두 번 emit해도 counter는 1만 증가.
5. step await 중 `PAUSE_TOGGLE` direct emit은 ignored. 최종 paused=true.
6. step await 중 `RESTART_STAGE` direct emit은 SceneFlow guard에서 ignored. stage instance가 reload되지 않음.
7. 테스트 종료 후 `InputRouter.are_pause_actions_blocked() == false`.

테스트 구현 주의:

- physics tick 검증은 `process_frame x 2`를 쓰지 않는다.
- step 완료 대기는 `await get_tree().physics_frame` 후 한 idle turn 정도만 정리용으로 허용한다. assert의 기준은 physics counter다.

### 신규 `tests/PausedAssignTest.tscn`

필수 케이스:

1. `tree.paused = true`.
2. `EventBus.action_triggered.emit(SKILL_ASSIGN, valid payload)` 경로로 ant state 전이를 확인한다.
3. 실제 paused GUI path: `SkillToolbar` Button의 `pressed` 신호 또는 synthetic mouse click으로 slot 선택이 pause 상태에서도 반영되는지 확인한다.
4. `tree.paused = false` 또는 `STEP_FRAME` 한 번 후 blocker hitbox/effect가 발현되는지 확인한다.

### 신규 `tests/InputModeTrackerTest.tscn`

필수 케이스:

1. 초기 mode는 `&"mouse"`.
2. `InputEventJoypadMotion` 주입 시 `&"pad"` emit 및 `get_mode() == &"pad"`.
3. 연속 pad event는 추가 emit 없음.
4. mouse motion 주입 시 `&"mouse"` emit.
5. `InputEventKey` 주입은 mode 변경과 emit이 없음.
6. `InputEventScreenTouch` 주입 시 `&"touch"` emit.
7. `_input` 처리 후 event handled 상태를 바꾸지 않는다.

### 신규 `tests/InputHintLabelTest.tscn`

필수 케이스:

1. `/root/InputModeTracker`가 있는 경우 현재 mode로 초기 텍스트를 설정한다.
2. tracker가 없는 isolated scene에서도 에러 없이 mouse fallback 텍스트를 설정한다.
3. `EventBus.input_mode_changed` 수신 시 텍스트만 바뀌고 다른 action emit은 없다.

### 신규 `tests/InputModeTrackerLeakGuardTest.tscn`

코드 문자열 검사:

- `scripts/input/InputRouter.gd` 안에 `"InputModeTracker"` 0건.
- `scripts/ui/SkillToolbar.gd` 안에 `"InputModeTracker"` 0건.
- `scripts/ant/Ant.gd` 안에 `"InputModeTracker"` 0건.
- `scripts/input/InputModeTracker.gd` 안에 `"InputRouter"` / `"SkillToolbar"` / `"Ant"` 0건.

### 신규 `tests/PauseStageFreezeOrthogonalityTest.tscn`

필수 케이스:

1. `tree.paused = true`, freeze 미적용: stage physics counter +0.
2. `_freeze_current_stage()` 적용, `tree.paused = true`, `STEP_FRAME` emit: stage 내부 counter +0.
3. freeze 해제 후 paused 상태에서 `STEP_FRAME` emit: counter +1.
4. freeze와 pause를 모두 해제하면 정상 진행.

## 수동 검증

1. Stage03 mouse: Space pause -> blocker 선택/부여 click -> Space unpause -> blocker가 정상 발현.
2. Stage03 mouse: Space pause -> `.` 한 번 -> 개미가 정확히 한 physics tick만 전진하고 다시 pause.
3. Step 중 Space/Ctrl+R을 빠르게 눌러도 pause 상태와 stage instance가 깨지지 않음.
4. Stage03 pad: View pause -> A assign -> View unpause -> 정상 발현.
5. 디바이스 전환: mouse 이동/클릭 -> pad stick -> touch event fixture 순으로 hint label 즉시 변경.

## 구현 순서

1. `StepFrame.gd` 작성. `physics_frame` 기반 step과 token/gate cleanup을 먼저 구현한다.
2. `InputRouter.gd`에 pause-affecting action gate를 추가하고 Pad B hold restart path도 gate에 묶는다.
3. `SceneFlow.gd`에 direct `RESTART_STAGE` 2차 guard를 추가한다.
4. `StepFrameTest`를 작성하고 step/reentry/restart race를 먼저 통과시킨다.
5. `InputModeTracker.gd` 작성.
6. `InputHintLabel.gd` 작성 후 `HUD.tscn`에 Label 추가.
7. `SkillToolbar.tscn` 최상위 process mode를 ALWAYS로 명시.
8. `project.godot` autoload 2개 추가.
9. `PausedAssignTest`, `InputModeTrackerTest`, `InputHintLabelTest`, `InputModeTrackerLeakGuardTest`, `PauseStageFreezeOrthogonalityTest` 작성.
10. 기존 회귀 fleet와 신규 테스트를 모두 실행한다.

## 마이그레이션 안전성

- `EventBus.gd`와 `GameAction.gd` 변경 없음. 새 action 이름을 만들지 않는다.
- `InputRouter`는 gate만 추가하며 좌표 산출과 `_last_cursor_*` cache 계약은 건드리지 않는다.
- `SkillToolbar.gd`는 변경하지 않는다. paused GUI path는 scene process mode와 테스트로 보장한다.
- `Ant.gd`는 변경하지 않는다. state 전이와 physics 발현의 기존 분리를 유지한다.
- `InputModeTracker`는 이벤트를 소비하지 않으므로 기존 input dispatch와 경쟁하지 않는다.
- StepFrame 중 pause/restart 입력은 queue하지 않고 ignore한다. 이 정책은 deterministic debug helper 성격에 맞춰 race 제거를 우선한다.

## 리스크 / 완화

| 리스크 | 영향 | 완화 |
|---|---|---|
| `physics_frame` await 후 re-pause 타이밍이 테스트 환경에서 off-by-one으로 보일 수 있음 | 중간 | dummy `_physics_process` counter로 정확히 1 tick을 검증하고, idle frame 수를 assert 기준으로 삼지 않는다. |
| StepFrame gate가 예외/teardown 후 남을 수 있음 | 중간 | `_exit_tree` cleanup + `StepFrameTest` teardown assert. |
| direct EventBus emit이 InputRouter gate를 우회할 수 있음 | 중간 | `SceneFlow`가 `RESTART_STAGE`에 대해 2차 guard를 둔다. `PAUSE_TOGGLE`은 StepFrame 내부 `_stepping` guard로 막는다. |
| paused Button path가 signal direct test만으로는 부족할 수 있음 | 중간 | `PausedAssignTest`에 실제 Button `pressed` 또는 synthetic click path를 포함한다. |
| `INPUT_PLAN.md` §7 파일 목록과 실제 변경 목록 drift | 낮음 | 본 plan이 Phase 8 파일 단위 SoT다. 구현 후 문서 정리 필요 시 별도 후속으로 갱신한다. |

## 리뷰 체크리스트

- [ ] `StepFrame`은 `process_frame x 2`를 사용하지 않는다.
- [ ] `StepFrame`은 `await get_tree().physics_frame` 기준으로 정확히 1 physics tick만 허용한다.
- [ ] step await 중 `PAUSE_TOGGLE`, `STEP_FRAME`, `RESTART_STAGE` 재진입이 state를 덮지 않는다.
- [ ] `InputRouter` gate와 `SceneFlow` direct restart guard가 둘 다 있다.
- [ ] `InputModeTracker`는 event를 consume하지 않는다.
- [ ] `InputModeTracker` autoload ordering 보장 문구가 없다.
- [ ] `InputHintLabel`은 tracker absent fallback을 가진다.
- [ ] paused GUI Button path가 테스트된다.
- [ ] `InputRouter.gd`, `SkillToolbar.gd`, `Ant.gd`에 `InputModeTracker` 참조가 없다.
- [ ] `HUD.gd`, `SkillToolbar.gd`, `Ant.gd`는 변경 없음으로 확정되어 있고, 실제 변경은 scene/script 신규 파일에 한정된다.

## 표준 절차

plan/review/deferred 흐름은 `phases/mvp/README.md`를 따른다. 본 v2는 codex plan review HIGH를 반영한 사용자 요청 수정안이며, 다음 단계에서 다시 plan review를 수행할지 여부는 사용자가 결정한다.
