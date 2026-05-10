# Phase 6 Plan — game-flow-foundation

작성일: 2026-05-10
1차 SoT: `docs/GAME_FLOW_PROPOSAL_V5.md`
보조 SoT: `phases/mvp/REVISION_2026-05-09.md` §15
Pre-requisite: commit `7663280` (`fix: disconnect score system signals (phase 5 sweep)`) — `ScoreSystem.stop()` / `StageRunner._exit_tree()` / `tests/test_ScoreSystem.tscn` PASS

## 0. 한 줄

`Stage01.tscn`을 main scene에서 떼어내고 `Main → SceneFlow → CurrentStageRoot/GlobalUI` 컨테이너 모델로 stage 1~3 닫힌 루프 (clear/fail → Replay/Next/Menu)를 만든다. EventBus stage result signal을 Dictionary payload로 갈아엎는다.

## 1. 적용 대상 (file-level)

### 1.1 신규

| 경로 | 책임 |
|---|---|
| `scripts/core/SceneFlow.gd` | Main scene 산하 Node. stage load/unload/freeze + result overlay lifecycle 단독 소유. 마지막 result(`_last_result`)를 보관하여 `request_next`를 cleared 결과에서만 수락 (overlay disable과 이중 방어) |
| `scenes/Main.tscn` (재작성) | 컨테이너 트리: `Main(Node) → SceneFlow / CurrentStageRoot(Node) / GlobalUI(CanvasLayer layer=10) → StageResultOverlayStub` |
| `scripts/ui/StageResultOverlayStub.gd` | Cleared/Failed 텍스트 + score% + reason + Replay/Next/Menu 3 버튼. 첫 클릭 시 모든 버튼 disabled |
| `scenes/ui/StageResultOverlayStub.tscn` | Control + VBoxContainer + Buttons. 기본 visible=false |
| `tests/GameFlowTest.gd` | clear→Next, fail→Replay, last-stage Next disabled, no_more_ants 시퀀스 검증. 헤드리스 |
| `tests/GameFlowTest.tscn` | TestRoot(Node) + Main 인스턴스 + Driver 노드 |
| `tests/test_SceneFlow.gd` | TDD Guard 스텁. 진짜 coverage는 GameFlowTest에서 |
| `tests/test_StageResultOverlayStub.gd` | TDD Guard 스텁. 진짜 coverage는 GameFlowTest에서 |

### 1.2 수정

| 경로 | 변경 요지 |
|---|---|
| `project.godot` | `run/main_scene` → `res://scenes/Main.tscn` |
| `scripts/core/EventBus.gd` | `stage_cleared(score: float)` / `stage_failed(reason: String)` → 둘 다 `result: Dictionary`. `request_replay/request_next/request_menu` 신규 |
| `scripts/core/StageRunner.gd` | `_make_result(cleared, reason)` Dictionary 8키 helper. `_living_ant_count()` (group `ants` + `is_instance_valid`). `_spawner_finished` flag + `spawn_finished` connect. `_process()` 판정 순서 `clear → no_more_ants → time_out`. emit signature를 Dictionary로. `_on_stage_cleared/_on_stage_failed` 제거 (HUD show_dialog는 더 이상 StageRunner 책임 아님 — overlay가 GlobalUI에서 표시) |
| `scripts/core/GameManager.gd` | autoload 그대로 유지. SkillRegistry boot 검증만. game flow 책임은 SceneFlow로 (현재 상태에서 추가 변경 없음 — 이미 SkillRegistry validate만 함) |
| `tests/Stage02HeadlessTest.gd` | `_on_cleared(score)` → `_on_cleared(result: Dictionary)`, `_on_failed(reason)` → `_on_failed(result: Dictionary)`. `score = result.score`, `reason = result.reason` |
| `tests/Stage03HeadlessTest.gd` | 동일 시그니처 변경 |

### 1.3 변경하지 않음 (의도적)

- `scripts/core/ScoreSystem.gd` — Pre-Phase 6 hot-fix에서 이미 변경 완료. Phase 6는 추가 수정 없음
- `scripts/ui/HUD.gd` / `HUD.tscn` — 기존 stage 안에 위치. show_dialog는 stub overlay로 대체되지만 HUD 자체는 in-stage 정보 표시 유지. StageRunner가 더 이상 HUD.show_dialog를 호출하지 않을 뿐이라 HUD.gd 수정 불필요. AcceptDialog 노드는 unused로 남지만 Phase 12 본격 dialog로 교체 시 제거 — Phase 6 비범위
- `scenes/stages/Stage01~03.tscn` — root는 여전히 StageRunner. CurrentStageRoot의 자식으로 add되어도 동작 동일 (StageRunner._ready가 NodePath 기반으로 자식 찾기 때문)
- `scripts/core/AntSpawner.gd` — `spawn_finished` signal 이미 존재. 추가 변경 없음

## 2. EventBus 변경 contract

### 2.1 Before

```gdscript
signal stage_cleared(score: float)
signal stage_failed(reason: String)
```

### 2.2 After

```gdscript
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
signal request_replay
signal request_next
signal request_menu
```

호환 shim 두지 않음 (v5 §2.1). 모든 receiver를 한 번에 갈아엎는다.

### 2.3 Result Dictionary 8 키

```gdscript
{
    "stage_id": int,        # stage_data.id
    "cleared": bool,         # true if cleared, false if failed
    "saved": int,            # score_system.saved_pieces
    "lost": int,             # score_system.lost_pieces
    "original_hp": int,      # score_system.original_hp
    "score": float,          # score_system.score()  (saved/original_hp, 0..1)
    "time_left": float,      # _time_left when emitted
    "reason": String,        # "" if cleared, "no_more_ants" or "time_out" if failed
}
```

`_make_result(cleared: bool, reason: String) -> Dictionary` — defensive null fallback 없음 (v5 §2.3). 정상 flow에서 stage_data와 score_system은 존재. 비정상 초기화 실패는 `_ready()` `push_error` + early return으로 처리되므로 `_process()`는 그 분기에서 호출 안 됨 (`_completed` 또는 `stage_data == null` 가드).

## 3. SceneFlow API

```gdscript
class_name SceneFlow extends Node

const STAGE_SCENES := {
    1: "res://scenes/stages/Stage01.tscn",
    2: "res://scenes/stages/Stage02.tscn",
    3: "res://scenes/stages/Stage03.tscn",
}
const LAST_STAGE_ID := 3

@export var current_stage_root_path: NodePath
@export var overlay_path: NodePath

var _current_stage_root: Node = null
var _overlay: Node = null  # StageResultOverlayStub
var _current_stage_id: int = 0
var _last_result: Dictionary = {}  # 가장 최근 stage 결과; load_stage에서 reset. Next 가드용 (codex plan-review HIGH 2026-05-10 R2)

func _ready() -> void:
    _current_stage_root = get_node(current_stage_root_path)
    _overlay = get_node(overlay_path)

    EventBus.stage_cleared.connect(_on_stage_result)
    EventBus.stage_failed.connect(_on_stage_result)
    EventBus.request_replay.connect(_on_request_replay)
    EventBus.request_next.connect(_on_request_next)
    EventBus.request_menu.connect(_on_request_menu)

    start_game()

func start_game() -> void:
    load_stage(1)

func load_stage(stage_id: int) -> void:
    _unload_current_stage()
    _last_result = {}  # 새 stage 진입 시 이전 결과 무효화 (Next 가드 reset)
    if not STAGE_SCENES.has(stage_id):
        push_error("[SceneFlow] unknown stage_id %d" % stage_id)
        return
    var scene: PackedScene = load(STAGE_SCENES[stage_id])
    var stage_node: Node = scene.instantiate()
    _current_stage_root.add_child(stage_node)
    _current_stage_id = stage_id

func load_next_stage() -> void:
    var next_id: int = _current_stage_id + 1
    if not STAGE_SCENES.has(next_id):
        go_to_menu()
        return
    load_stage(next_id)

func replay_stage() -> void:
    load_stage(_current_stage_id)

func go_to_menu() -> void:
    # Phase 6: Stage01 reload fallback. Phase 13에서 실제 menu scene으로 교체.
    load_stage(1)

func _unload_current_stage() -> void:
    for child in _current_stage_root.get_children():
        child.queue_free()

func _freeze_current_stage() -> void:
    _current_stage_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_current_stage() -> void:
    _current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT

func _on_stage_result(result: Dictionary) -> void:
    _last_result = result
    _freeze_current_stage()
    _overlay.show_result(result, result["stage_id"] >= LAST_STAGE_ID)

func _on_request_replay() -> void:
    _overlay.hide_overlay()
    _unfreeze_current_stage()
    replay_stage()

func _on_request_next() -> void:
    # Next는 cleared 결과에서만 허용 — 실패 stage 우회 차단 (codex plan-review HIGH 2026-05-10 R2).
    # overlay는 disabled로 1차 방어, SceneFlow가 signal 직접 호출(테스트/추후 input router)에 대한 2차 방어.
    if not _last_result.get("cleared", false):
        return
    _overlay.hide_overlay()
    _unfreeze_current_stage()
    load_next_stage()

func _on_request_menu() -> void:
    _overlay.hide_overlay()
    _unfreeze_current_stage()
    go_to_menu()
```

설계 근거:
- `_on_stage_result` 단일 handler가 cleared/failed 두 signal 모두 받음 — 둘 다 같은 Dictionary 시그니처라 분기 불필요
- `_unload_current_stage`는 `queue_free()`만 호출 — 즉시 free되지 않지만, 같은 frame 내 새 stage `add_child` 후 다음 idle frame에 자동 정리. 같은 stage 노드가 동시에 두 개 존재할 수 있는 시점이 1 frame 있다. v5 §2.4가 `queue_free()`를 명시
- **1-frame overlap의 ants 카운팅 영향 차단**: `StageRunner._living_ant_count()`을 활성 stage subtree(`_spawn_parent` 자손)로 스코프 좁힘 (§4.4). 이전 stage의 큐드된 ant들이 같은 group에 남아 있어도 새 StageRunner의 판정에 영향 주지 않음. 이전 stage StageRunner는 `_completed=true`라 emit 안 함 — 양방향 안전 (codex plan-review HIGH 대응 2026-05-10)

## 4. StageRunner 변경 (구체)

### 4.1 신규 멤버

```gdscript
var _spawner_finished: bool = false
```

### 4.2 `_ready()` 보강

기존 코드 끝에 추가:

```gdscript
if _spawner != null:
    if not _spawner.spawn_finished.is_connected(_on_spawner_finished):
        _spawner.spawn_finished.connect(_on_spawner_finished)
```

또한 `EventBus.stage_cleared.connect(_on_stage_cleared)` / `EventBus.stage_failed.connect(_on_stage_failed)` 두 줄을 **제거**한다. StageRunner는 emit만 하고 self-receiver는 두지 않는다 (책임 분리 v5 §2.5: dialog 표시는 SceneFlow/Overlay 책임).

### 4.3 `_process(delta)` 재작성

```gdscript
func _process(delta: float) -> void:
    if _completed or stage_data == null:
        return

    _time_left = max(0.0, _time_left - delta)
    if _hud != null and _hud.has_method("update_time"):
        _hud.update_time(_time_left)

    var candy_hp: int = _candy.hp if _candy != null else 0

    if score_system.is_cleared(candy_hp):
        _completed = true
        EventBus.stage_cleared.emit(_make_result(true, ""))
        return

    if (_spawner_finished
        and _living_ant_count() == 0
        and score_system.in_transit_pieces == 0
        and candy_hp > 0):
        _completed = true
        EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))
        return

    if _time_left <= 0.0:
        _completed = true
        EventBus.stage_failed.emit(_make_result(false, "time_out"))
```

판정 순서 (v5 §2.9): clear → no_more_ants → time_out. `candy_hp > 0` 가드로 `is_cleared` 분기와 겹치지 않음.

### 4.4 helper

```gdscript
func _make_result(cleared: bool, reason: String) -> Dictionary:
    return {
        "stage_id": stage_data.id,
        "cleared": cleared,
        "saved": score_system.saved_pieces,
        "lost": score_system.lost_pieces,
        "original_hp": score_system.original_hp,
        "score": score_system.score(),
        "time_left": _time_left,
        "reason": reason,
    }

func _living_ant_count() -> int:
    # 활성 stage subtree로 스코프 — `ants` group은 EVERY stage의 ant가 누적되는
    # 전역 group. SceneFlow.queue_free + add_child 1-frame overlap 시 이전 stage의
    # 큐드된 ant들이 group에 남아 있어도 새 StageRunner의 판정에 영향 주지 않게
    # `_spawn_parent` 자손만 카운트한다 (codex plan-review HIGH 대응 2026-05-10).
    if _spawn_parent == null:
        return 0
    var count: int = 0
    for n in get_tree().get_nodes_in_group("ants"):
        if not is_instance_valid(n):
            continue
        if _spawn_parent.is_ancestor_of(n):
            count += 1
    return count

func _on_spawner_finished() -> void:
    _spawner_finished = true
```

`_spawn_parent`는 StageRunner._ready에서 `get_node_or_null(spawn_parent_path)` 또는 fallback으로 `self`. 현재 stage scene 안에 위치하므로 다른 stage scene의 ant와 구분된다. `is_ancestor_of(n)` 사용 — descendant 체크.

### 4.5 제거할 함수

`_on_stage_cleared(score: float)`, `_on_stage_failed(reason: String)`, `_show_dialog(text: String)` — Phase 6에서 stage 결과 표시는 SceneFlow가 담당. 단, **HUD는 in-stage 정보 표시용으로 유지**되므로 `_hud.show_dialog` 호출만 사라진다. `_hud.update_time` 호출은 유지.

### 4.6 _exit_tree 유지

Pre-Phase 6 hot-fix에서 추가한 `_exit_tree()`의 `score_system.stop()`은 유지. SceneFlow가 `queue_free()`로 stage scene 통째로 unload하면 StageRunner._exit_tree()도 호출됨 → ScoreSystem disconnect 자동 정리.

## 5. StageResultOverlayStub 사양

### 5.1 노드 구조

```text
StageResultOverlayStub (Control, anchors=full_rect, mouse_filter=PASS, visible=false)
  Background (ColorRect, color=Color(0,0,0,0.5))
  VBox (VBoxContainer, anchors=center)
    Title (Label, "Cleared!" / "Failed")
    Score (Label, "Score: 90%")
    Reason (Label, "" / "no_more_ants" / "time_out")  # cleared면 hide
    HBox (HBoxContainer)
      ReplayButton (Button, text="Replay")
      NextButton (Button, text="Next")
      MenuButton (Button, text="Menu")
```

### 5.2 스크립트

```gdscript
class_name StageResultOverlayStub extends Control

@onready var _title: Label = $VBox/Title
@onready var _score: Label = $VBox/Score
@onready var _reason: Label = $VBox/Reason
@onready var _replay: Button = $VBox/HBox/ReplayButton
@onready var _next: Button = $VBox/HBox/NextButton
@onready var _menu: Button = $VBox/HBox/MenuButton

func _ready() -> void:
    visible = false
    _replay.pressed.connect(_on_replay_pressed)
    _next.pressed.connect(_on_next_pressed)
    _menu.pressed.connect(_on_menu_pressed)

func show_result(result: Dictionary, is_last_stage: bool) -> void:
    _title.text = "Stage Cleared!" if result["cleared"] else "Stage Failed"
    _score.text = "Score: %d%%" % int(round(result["score"] * 100.0))
    if result["cleared"]:
        _reason.visible = false
    else:
        _reason.visible = true
        _reason.text = "Reason: %s" % result["reason"]
    _replay.disabled = false
    # Next는 cleared && !is_last_stage 일 때만 활성. 실패 stage에서 advance 차단 (codex plan-review HIGH 2026-05-10 R2).
    _next.disabled = is_last_stage or not result["cleared"]
    _menu.disabled = false
    visible = true

func hide_overlay() -> void:
    visible = false
    _replay.disabled = false
    _next.disabled = false
    _menu.disabled = false

func _disable_all_buttons() -> void:
    _replay.disabled = true
    _next.disabled = true
    _menu.disabled = true

func _on_replay_pressed() -> void:
    _disable_all_buttons()
    EventBus.request_replay.emit()

func _on_next_pressed() -> void:
    _disable_all_buttons()
    EventBus.request_next.emit()

func _on_menu_pressed() -> void:
    _disable_all_buttons()
    EventBus.request_menu.emit()
```

### 5.3 중복 클릭 방지

첫 클릭이 모든 버튼 disable. SceneFlow가 `_overlay.hide_overlay()`를 호출하면 reset (다음 stage에서 재사용 가능).

### 5.4 표시 안 함 (Phase 6 비범위)

stars / motion / saved/lost/time 상세. Phase 12에서 추가.

## 6. Main.tscn 구조

```text
[gd_scene format=3]
[ext_resource SceneFlow.gd]
[ext_resource StageResultOverlayStub.tscn]

[node name="Main" type="Node"]

[node name="SceneFlow" type="Node" parent="."]
script = SceneFlow.gd
current_stage_root_path = NodePath("../CurrentStageRoot")
overlay_path = NodePath("../GlobalUI/StageResultOverlayStub")

[node name="CurrentStageRoot" type="Node" parent="."]

[node name="GlobalUI" type="CanvasLayer" parent="."]
layer = 10

[node name="StageResultOverlayStub" parent="GlobalUI" instance=...]
```

`CurrentStageRoot`는 Node (Node2D 아님 — stage scene이 자체 Node2D World를 들고 있으므로 단순 컨테이너로 충분). `process_mode = DISABLED`가 자식에게 전파되도록 하는 데 Node로도 무리 없음 (`process_mode = INHERIT` 자식들이 부모 DISABLED를 상속).

## 7. 테스트 설계

### 7.1 GameFlowTest.tscn / .gd

헤드리스 시나리오:

**시나리오 A** (auto-play Stage01 → clear → Next → Stage02 도달 확인)

1. Main scene 인스턴스 생성, Driver 노드가 `_ready`에서 EventBus signal 구독
2. Stage01 자동 로드됨 (SceneFlow.start_game)
3. Driver가 매 frame Stage02HeadlessTest와 동일한 BuilderSkill auto-apply 로직으로 stage1 clear 유도. 단 stage1은 builder 없이도 클리어 가능 (스킬 0개) → 자연 진행
4. `stage_cleared` Dictionary 수신 → `result.stage_id == 1`, `result.cleared == true` 검증
5. Driver가 직접 `EventBus.request_next.emit()` 호출 (overlay button을 직접 누를 수 없으므로 signal로 시뮬레이션)
6. SceneFlow가 stage2 로드. Driver가 `CurrentStageRoot`의 자식 stage scene이 stage2인지 확인 (`stage_data.id == 2`)

**시나리오 B** (Stage last → Next disabled fallback)

1. Driver가 SceneFlow를 직접 조작하여 Stage03 로드 (`scene_flow.load_stage(3)`)
2. Stage03 자연 클리어 유도 (Stage03HeadlessTest와 동일 로직: 첫 +1 ant에 BlockerSkill apply, 단 driver는 GameFlowTest 안에서 동작)
3. `stage_cleared` 수신 → overlay에 NextButton.disabled == true 검증
4. Driver가 강제로 `EventBus.request_next.emit()` 호출 → SceneFlow.go_to_menu fallback 동작 → 다음 stage가 stage1로 reload되었는지 확인

**시나리오 C** (no_more_ants 판정 — fail 경로)

이 시나리오는 별도 stage가 필요. 기존 Stage01~03은 무조건 clear 가능한 설계라 fail을 강제하기 어려움. 대안:
- driver가 stage1 로드 후 spawner_finished를 기다림 (`AntSpawner.spawn_finished` connect)
- spawner_finished 시점에 모든 living ant에 대해 `queue_free()` 호출
- 그 후 **`await get_tree().process_frame` 2회** — Godot의 queue_free는 다음 idle frame에 free 처리. 1 frame은 SceneTree 정리, 2 frame째 `_living_ant_count`이 active stage subtree에서 0 반환 보장 (codex plan-review HIGH 대응 — queue_free 비동기성)
- 그 후 `_living_ant_count(_spawn_parent) == 0` 확인 (driver가 직접 호출하지 못하므로 group iterate로 동등 검증)
- StageRunner._process가 다음 tick에 `no_more_ants` 발화 → driver가 `result.reason == "no_more_ants"` 검증
- **Next 차단 검증** (codex plan-review HIGH 2026-05-10 R2):
  - overlay의 `_next.disabled == true` 확인 (실패 결과이므로)
  - driver가 강제로 `EventBus.request_next.emit()` 호출
  - `await get_tree().process_frame` 후 `CurrentStageRoot`의 자식이 여전히 stage1 instance인지 확인 (advance 안 됨)
  - SceneFlow `_current_stage_id == 1` 유지 확인
- driver가 `EventBus.request_replay.emit()` 호출 → stage1 reload 확인 (`stage_data.id == 1` 새 instance)

대안: ant.queue_free() 대신 `ant.free()` (즉시 free)도 가능하지만 ant의 _exit_tree(BlockerHitbox cleanup 등)가 같은 frame에 동기 실행되어 재귀/중첩 위험 ↑. queue_free + 2 frame await가 안전.

**시나리오 D** (process freeze)

- stage_cleared 수신 후 `Main/CurrentStageRoot.process_mode == PROCESS_MODE_DISABLED` 직접 확인
- `EventBus.request_replay.emit()` 후 `process_mode == PROCESS_MODE_INHERIT` 회복 확인

PASS: 4 시나리오 모두 통과 → `quit(0)`. FAIL: 단계 실패 즉시 print + `quit(1)`.

### 7.2 Stage02/Stage03 HeadlessTest 변경

```gdscript
func _on_cleared(result: Dictionary) -> void:
    if _result_emitted:
        return
    _result_emitted = true
    var score: float = result["score"]
    print("[PhaseTest] cleared score=", score)
    ...
```

`_on_failed` 동일 패턴. `reason = result["reason"]`. 기존 score/reason 추출 외 모든 로직 변경 없음.

### 7.3 TDD Guard

- `tests/test_SceneFlow.gd` (스텁)
- `tests/test_StageResultOverlayStub.gd` (스텁)

## 8. 검증 체크리스트 (impl 완료 시)

| # | 항목 | 검증 방법 |
|---|---|---|
| 1 | `project.godot` main scene이 `Main.tscn` | `grep run/main_scene project.godot` |
| 2 | Main 실행 → Stage01 로드 | GameFlowTest 시나리오 A 1~3 |
| 3 | Stage01 clear → Next → Stage02 | 시나리오 A 4~6 |
| 4 | Stage02 fail → Replay → Stage02 재시작 | Stage02HeadlessTest는 항상 clear → 별도 시나리오: GameFlowTest C에서 stage1로 강제 fail 후 replay 검증 (stage2 fail 보장 어려움) |
| 5 | Stage03 clear → NextButton disabled, request_next → go_to_menu | 시나리오 B |
| 6 | 결과 overlay 표시 중 stage 시뮬레이션 정지 | 시나리오 D |
| 7 | no_more_ants 발화가 time_out 전 | 시나리오 C, candy_hp > 0 + ants 0 + in_transit 0 + spawner_finished |
| 8 | Result Dictionary 8 키 모두 채워짐 | 시나리오 A에서 8 키 typeof 검증 |
| 9 | `tests/Stage02HeadlessTest.tscn` PASS | run_test.py |
| 10 | `tests/Stage03HeadlessTest.tscn` PASS | run_test.py |
| 11 | `tests/GameFlowTest.tscn` PASS | run_test.py |
| 12 | `tests/test_ScoreSystem.tscn` PASS (회귀 없음) | run_test.py |
| 13 | failed stage에서 Next advance 차단 (overlay disabled + SceneFlow reject) | 시나리오 C 후반 step (codex R2) |

## 9. 엣지 케이스 / 알려진 한계

- **Phase 6 시점 Stage01 도중 Menu 클릭 = Replay와 동일 결과**: v5 §2.8에서 명시 허용. Phase 13에서 실제 menu로 교체
- **Overlay 첫 클릭 즉시 모든 버튼 disabled**: 중복 클릭 방지 (v5 §2.6). hide 시 reset
- **`queue_free` 1-frame overlap**: 같은 frame에 unload + load 시 1 idle frame 동안 두 stage scene 공존. process_mode DISABLED + queued free라 시뮬레이션 충돌 없음. 결과 overlay는 GlobalUI에 있어 영향 없음
- **`AntSpawner.stop()` 미구현**: v5 비범위. 결과 overlay 표시 중 process_mode DISABLED로 timer가 멈추므로 추가 spawn 없음
- **HUD AcceptDialog unused**: HUD.tscn 안에 남아있지만 더 이상 호출 안 됨. Phase 12에서 제거 예정. Phase 6 작업 안 함
- **Stage scene이 자체 HUD를 가짐**: 각 stage가 자기 HUD를 들고 있어 unload 시 자동 정리. EventBus connect는 HUD가 Node라 free 시 Godot 자동 disconnect — leak 없음 (ScoreSystem RefCounted와 다름)
- **Failed stage Next 우회 차단**: overlay에서 `_next.disabled = is_last_stage or not result["cleared"]`로 1차 차단, SceneFlow `_on_request_next`가 `_last_result.cleared`로 2차 차단. UI 클릭 경로와 `EventBus.request_next.emit()` 직접 호출 경로 양쪽 모두 보호. cleared/non-final 결과에서만 advance 허용 (codex plan-review HIGH 2026-05-10 R2)

## 10. 비범위 (재확인)

- TitleScene / MainMenu / StageSelect / SaveData → Phase 13
- 본격 StageDialog (stars / motion / saved/lost 상세) → Phase 12
- gamepad virtual cursor → Phase 7
- typed `StageResult` Resource → post-MVP
- `request_stage_select` signal → Phase 13
- 명시적 `AntSpawner.stop()` → 불필요 (process_mode DISABLED로 자동 정지)
- Sound / SFX → Phase 21 (post-MVP)

## 11. 작업 순서

1. `scripts/core/EventBus.gd` 시그널 갱신
2. `scripts/core/StageRunner.gd` Dictionary payload + helper
3. `tests/Stage02HeadlessTest.gd`, `tests/Stage03HeadlessTest.gd` 시그니처 변경 → run_test로 회귀 확인
4. `scripts/ui/StageResultOverlayStub.gd` + `.tscn`
5. `scripts/core/SceneFlow.gd`
6. `scenes/Main.tscn` 재작성
7. `project.godot` main_scene 변경
8. `tests/GameFlowTest.gd` + `.tscn` 시나리오 4종
9. TDD guard 스텁 (test_SceneFlow.gd, test_StageResultOverlayStub.gd)
10. 회귀 테스트 일괄: ScoreSystem / Stage02 / Stage03 / GameFlow

## 12. 리스크 / 보류

| 리스크 | 영향 | 처리 |
|---|---|---|
| GameFlowTest 시나리오 C에서 ant 강제 free의 결정성 | 중간 | `queue_free` 후 `await get_tree().process_frame` 2회로 active stage subtree에서 ant가 빠져나간 것을 보장. `_living_ant_count`도 active stage subtree로 스코프 좁혀 있어 1-frame overlap의 stale ants에 영향 받지 않음 (codex plan-review HIGH 대응 2026-05-10) |
| Main.tscn 재작성 시 기존 빈 Main.tscn은 git에서 단순 modify로 인식. ext_resource 누락 시 import error | 중간 | tscn 직접 작성보다 Godot Editor에서 만들기보다는 텍스트로 명시적 작성 — load_steps + ext_resource 정확히 |
| stage scene이 CurrentStageRoot의 자식으로 들어가도 StageRunner의 NodePath(World/Candy 등)가 self-relative라 자동으로 작동 | 낮음 | 검증: Stage02HeadlessTest는 `[node name="Stage02" parent="." instance=...]` 패턴이라 root가 한 단계 위에 있어도 NodePath는 stage scene 내부 상대 경로로 그대로 동작 — 같은 패턴 |
| HUD가 stage scene 안에 있어 unload 시 Godot 자동 disconnect가 동작하는지 (Node가 _exit_tree에서 자기 connect를 자동 정리) | 낮음 | Godot 4의 `Object.is_connected` 후 free → disconnect는 엔진 책임. HUD가 EventBus.candy_piece_picked.connect(_on_picked) 후 free되면 EventBus는 freed callable을 호출 시도하지 않음. 단, **stage reload 시 HUD가 새로 _ready → connect**해도 이전 HUD는 free 후라 carrier의 Callable이 invalid → 자동 정리. 명시 disconnect 불필요 |
| HUD의 `_in_transit` 카운터가 stage reload 후 잔존 (HUD는 새 instance인데 _refresh가 stale 0으로 초기) | 낮음 | HUD는 새 인스턴스라 멤버는 자동 0 초기화. score_system도 새 instance. 실제 카운트는 새로 누적 — 정상 |
| EventBus `request_*` 시그널을 SceneFlow가 자기 시그널처럼 듣지만 Stage 내부에서 emit 가능 (오용) | 낮음 | Phase 6 비범위. Overlay만 emit. Phase 8(input-pause-step)에서 restart_stage가 request_replay.emit()으로 통합될 때 재검토 |

## 13. 커밋 단위

단일 commit:

```text
phase 6: game-flow-foundation
```

포함:
- Main / SceneFlow / StageResultOverlayStub 신규
- EventBus / StageRunner 갱신
- project.godot main_scene 변경
- Stage02/03 HeadlessTest 시그니처 변경
- GameFlowTest + TDD 스텁
- `phases/mvp/reviews/phase06-impl-review.md` (codex impl review 기록)

`phases/mvp/status.json`은 `complete 6` 시점에 자동 갱신.

## 14. plan-stage 리뷰 정책

CLAUDE.md (2026-05-09 정책): **Plan stage codex `/codex:adversarial-review`에서 CRITICAL/HIGH 1건이라도 발견 시 즉시 중단 + 사용자 보고**. 자동 재리뷰 사이클 없음.

Impl stage는 codex + 자체 적대적 review 사이클 (HIGH 0 될 때까지 반복).
