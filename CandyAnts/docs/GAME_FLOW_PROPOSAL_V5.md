# Game Flow Structure Proposal v5

작성일: 2026-05-09
상태: 제안 문서 v5

근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md`
- `docs/GAME_FLOW_PROPOSAL_REVIEW.md`
- `docs/GAME_FLOW_PROPOSAL_V2.md`
- `docs/GAME_FLOW_PROPOSAL_V2_REVIEW.md`
- `docs/GAME_FLOW_PROPOSAL_V3.md`
- `docs/GAME_FLOW_PROPOSAL_V3_REVIEW.md`
- `docs/GAME_FLOW_PROPOSAL_V4.md`
- `docs/GAME_FLOW_PROPOSAL_V4_REVIEW.md`

범위:
- 기존 `phases/mvp/*`, `status.json`, `notion-phase-ids.json`은 아직 수정하지 않음
- 이 문서는 v4와 v4 review에 대한 추가 적대적 검토까지 반영한 최신 결정안

## 1. v5 결론

v5는 v4의 큰 방향을 유지하되, v4 review에서 MEDIUM으로 남긴 결정사항을 더 이상 phase 6 plan으로 미루지 않는다. 다음 세 가지를 본 제안서의 확정 결정으로 승격한다.

1. `CurrentStageRoot`는 **빈 컨테이너 Node**다. 실제 stage scene은 그 자식으로 add/remove한다.
2. 마지막 stage에서 `Next` 버튼은 disabled 처리한다. 그래도 `request_next`가 들어오면 `go_to_menu()` fallback을 탄다.
3. `living ants` 카운트는 `ants` group 기반 `_living_ant_count()` helper로 계산하고, `is_instance_valid()`를 사용한다.

최종 방향:

```text
Phase 5 완료 인정
Pre-Phase 6 hot-fix로 ScoreSystem signal leak 수정
Phase 6을 game-flow-foundation으로 신설
기존 pending phase는 한 칸씩 뒤로 이동
Stage4 이후 확장은 Title/Menu까지 닫힌 루프 검증 후 재개
```

## 2. v5에서 확정한 주요 결정

### 2.1 EventBus stage result signal은 Dictionary signature로 변경

현재 코드:

```gdscript
signal stage_cleared(score: float)
signal stage_failed(reason: String)
```

Phase 6 이후:

```gdscript
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
```

호환성 방침:
- 기존 score/reason signature 호환 shim은 두지 않는다.
- Stage result Dictionary를 단일 계약으로 삼는다.

변경 대상:

```text
scripts/core/EventBus.gd
scripts/core/StageRunner.gd
tests/Stage02HeadlessTest.gd
tests/Stage03HeadlessTest.gd
tests/GameFlowTest.gd
```

### 2.2 Stage result Dictionary 계약

Phase 6에서 결과 payload는 Dictionary로 확정한다.

```gdscript
{
    "stage_id": int,
    "cleared": bool,
    "saved": int,
    "lost": int,
    "original_hp": int,
    "score": float,
    "time_left": float,
    "reason": String,
}
```

Typed `StageResult` Resource는 MVP 이후 SaveData/통계 고도화 시점으로 미룬다.

### 2.3 `_make_result()`는 StageRunner에 둔다

`StageRunner`가 `stage_data`, `score_system`, `_time_left`를 모두 알고 있으므로 결과 payload 생성 책임을 가진다.

권장 구현:

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
```

방침:
- 정상 flow에서 `stage_data`와 `score_system`은 존재한다고 본다.
- `_make_result()`에 defensive null fallback을 넣지 않는다.
- 비정상 초기화 실패는 `_ready()` 단계에서 fail-fast 처리한다.

### 2.4 Main scene 구조는 컨테이너 모델로 고정

`CurrentStageRoot`는 stage scene 자체가 아니다. `Main.tscn` 안에 항상 존재하는 빈 컨테이너다.

Scene tree:

```text
Main (Node)
  SceneFlow (Node)
  CurrentStageRoot (Node)          # empty container
  GlobalUI (CanvasLayer, layer = 10)
    StageResultOverlayStub (Control)
```

Stage loading model (순수 교체):

```gdscript
func load_stage(stage_id: int) -> void:
    _unload_current_stage()
    var scene: PackedScene = load(STAGE_SCENES[stage_id])
    var stage_node: Node = scene.instantiate()
    _current_stage_root.add_child(stage_node)
    _current_stage_id = stage_id
```

`load_stage`는 overlay hide와 freeze/unfreeze를 포함하지 않는다. caller (request handler 또는 `start_game`)가 lifecycle을 관리한다. 자세한 분리는 §2.5 참고.

Unload model:

```gdscript
func _unload_current_stage() -> void:
    for child in _current_stage_root.get_children():
        child.queue_free()
```

Freeze model:

```gdscript
func _freeze_current_stage() -> void:
    _current_stage_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_current_stage() -> void:
    _current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
```

주의:
- `CurrentStageRoot` 자체를 stage scene으로 교체하지 않는다.
- stage scene은 `CurrentStageRoot`의 자식으로만 add/remove한다.
- 결과 overlay는 `GlobalUI` sibling이므로 stage freeze의 영향을 받지 않는다.

### 2.5 Overlay lifecycle은 SceneFlow가 단독 소유

StageRunner:
- 결과 Dictionary를 emit한다.
- overlay를 직접 조작하지 않는다.
- scene 전환을 직접 하지 않는다.

StageResultOverlayStub:
- result를 표시한다.
- Replay / Next / Menu 버튼을 가진다.
- 버튼 클릭 시 request signal만 emit한다.

SceneFlow:
- stage result signal을 구독한다.
- request_* signal을 구독한다.
- overlay show/hide를 소유한다.
- stage freeze/unload/load를 소유한다.

책임 분리 원칙:
- `load_stage()`는 **순수 stage 교체만** 담당한다. overlay hide와 freeze toggle을 포함하지 않는다.
- overlay hide / unfreeze는 **request handler**가 호출한다.
- 이 분리로 `start_game()` 첫 호출 (overlay 없음) 시 dummy hide call을 피한다.

Lifecycle:

```text
StageRunner emits stage_cleared(result) or stage_failed(result)
SceneFlow receives result
SceneFlow freezes CurrentStageRoot
SceneFlow shows StageResultOverlayStub
User clicks Replay / Next / Menu
Overlay disables all buttons
Overlay emits request_*
SceneFlow request handler:
  hides overlay
  unfreezes CurrentStageRoot
  calls load_stage(target_id)  # 순수 교체 (unload + load)
```

Request handler 권장 구현:

```gdscript
func _on_request_replay() -> void:
    _hide_result_overlay()
    _unfreeze_current_stage()
    load_stage(_current_stage_id)

func _on_request_next() -> void:
    _hide_result_overlay()
    _unfreeze_current_stage()
    load_next_stage()

func _on_request_menu() -> void:
    _hide_result_overlay()
    _unfreeze_current_stage()
    go_to_menu()
```

### 2.6 StageResultOverlayStub 표시 범위

Phase 6의 overlay는 stub이다. 최종 UI가 아니다.

표시 정보:
- `cleared`: Cleared / Failed 텍스트
- `score`: percent 표시
- `reason`: failed일 때만 표시

표시하지 않는 정보:
- stars
- motion
- saved/lost/time 상세 레이아웃
- 최종 디자인

위 항목은 New Phase 12 StageDialog에서 처리한다.

버튼:

```text
Replay
Next
Menu
```

버튼 동작:

```text
Replay -> EventBus.request_replay.emit()
Next   -> EventBus.request_next.emit()
Menu   -> EventBus.request_menu.emit()
```

중복 클릭 방지:
- 첫 버튼 클릭 시 모든 버튼을 disabled 처리한다.
- overlay hide 시 버튼 disabled 상태를 reset한다.

### 2.7 마지막 stage의 Next 처리

Stage01~03만 Phase 6 stage set으로 본다.

마지막 stage:

```gdscript
const LAST_STAGE_ID := 3
```

Overlay 규칙:
- `result.stage_id == LAST_STAGE_ID`이면 Next 버튼을 disabled 처리한다.

SceneFlow 방어 규칙:
- 그래도 `request_next`가 들어오면 `go_to_menu()`를 호출한다.

```gdscript
func load_next_stage() -> void:
    var next_id := _current_stage_id + 1
    if not STAGE_SCENES.has(next_id):
        go_to_menu()
        return
    load_stage(next_id)
```

### 2.8 Phase 6 Menu fallback

Phase 6에는 실제 menu scene이 없다.

임시 동작:

```text
Menu -> EventBus.request_menu.emit()
SceneFlow.go_to_menu()
  -> overlay.hide()
  -> load_stage(1)
```

명시적 허용:
- Phase 6 시점에서 Stage01 도중 Menu 클릭은 Replay와 같은 결과가 된다.
- 이 임시 동작은 허용한다.
- New Phase 13에서 `go_to_menu()`를 실제 menu scene 전환으로 교체한다.

### 2.9 `no_more_ants` 판정

판정 순서:

```text
clear -> no_more_ants -> time_out
```

StageRunner state:

```gdscript
var _spawner_finished: bool = false
```

Spawner hook:

```gdscript
if _spawner != null:
    _spawner.spawn_finished.connect(_on_spawner_finished)

func _on_spawner_finished() -> void:
    _spawner_finished = true
```

Living ant count:

```gdscript
func _living_ant_count() -> int:
    var count: int = 0
    for n in get_tree().get_nodes_in_group("ants"):
        if is_instance_valid(n):
            count += 1
    return count
```

Process order:

```gdscript
func _process(delta: float) -> void:
    if _completed or stage_data == null:
        return

    _time_left = max(0.0, _time_left - delta)
    _update_hud_time()

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

근거:
- `Ant.gd`는 ant를 `"ants"` group에 등록한다.
- `is_instance_valid()`는 queue_free 직후 남아 있을 수 있는 stale reference를 피하기 위한 방어다.
- `in_transit_pieces == 0`은 운반 중인 candy가 아직 저장될 수 있는 상황을 실패로 오판하지 않기 위한 조건이다.

## 3. 최종 추천 계획

### 3.1 Pre-Phase 6 hot-fix

목표:

```text
SceneFlow 도입 전에 ScoreSystem의 EventBus signal 연결 누수를 제거한다.
```

변경 대상:

```text
scripts/core/ScoreSystem.gd
scripts/core/StageRunner.gd
tests/...
phases/mvp/reviews/phase05-impl-review.md
```

작업:
- `ScoreSystem.stop()` 추가
- `stop()`에서 `EventBus.candy_piece_picked`, `EventBus.ant_saved`, `EventBus.candy_piece_lost` disconnect
- signal이 연결되어 있을 때만 disconnect
- `StageRunner._exit_tree()`에서 `score_system.stop()` 호출
- stage reload 또는 같은 stage 2회 load 시 카운트 중복 없음 검증
- Phase 5 impl review 문서에 sweep round 기록

커밋 메시지 제안:

```text
fix: disconnect score system signals (phase 5 sweep)
```

완료 기준:
- Stage02/Stage03 headless test 통과
- stage reload 후 saved/lost/in_transit 중복 증가 없음

### 3.2 Phase 6 game-flow-foundation

파일:

```text
phases/mvp/phase06-game-flow-foundation.md
```

목표:

```text
Stage01 직접 실행 구조를 벗어나 Main/SceneFlow가 stage 1~3 플레이 세션을 소유한다.
Clear/Fail 이후 Replay/Next/Menu 요청을 처리하는 최소 게임 루프를 완성한다.
```

변경 대상:

```text
project.godot
scenes/Main.tscn
scripts/core/SceneFlow.gd
scripts/core/GameManager.gd
scripts/core/EventBus.gd
scripts/core/StageRunner.gd
scripts/core/ScoreSystem.gd
scripts/ui/StageResultOverlayStub.gd
scenes/ui/StageResultOverlayStub.tscn
tests/GameFlowTest.gd
tests/GameFlowTest.tscn
tests/Stage02HeadlessTest.gd
tests/Stage03HeadlessTest.gd
```

EventBus changes:

```gdscript
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
signal request_replay
signal request_next
signal request_menu
```

Phase 6에서 추가하지 않는 signal:

```gdscript
# New Phase 13에서 StageSelect와 함께 추가
signal request_stage_select
```

SceneFlow API:

```gdscript
class_name SceneFlow
extends Node

func start_game() -> void
func load_stage(stage_id: int) -> void
func replay_stage() -> void
func load_next_stage() -> void
func go_to_menu() -> void
```

Phase 6에서 `start_game()`은 `load_stage(1)` thin wrapper다.

Stage path:

```gdscript
const STAGE_SCENES := {
    1: "res://scenes/stages/Stage01.tscn",
    2: "res://scenes/stages/Stage02.tscn",
    3: "res://scenes/stages/Stage03.tscn",
}

const LAST_STAGE_ID := 3
```

비범위:
- TitleScene
- MainMenu
- StageSelect
- SaveData
- final StageDialog UI
- stars UI
- gamepad virtual cursor
- typed StageResult Resource
- `request_stage_select`
- explicit `AntSpawner.stop()`

완료 기준:
- `project.godot` main scene이 `Main.tscn`
- `Main.tscn`은 컨테이너 모델을 사용한다.
- 실행 시 `Main.tscn`을 통해 Stage01 로드
- Stage01 clear 후 overlay의 Next 버튼으로 Stage02 이동
- Stage02 fail 후 overlay의 Replay 버튼으로 Stage02 재시작
- Stage03 clear 후 Next 버튼 disabled
- Stage03 clear 상태에서 `request_next`가 들어오면 `go_to_menu()` fallback
- Menu 버튼은 Stage01 reload fallback으로 안전 처리
- Phase 6 시점에서 Stage01 도중 Menu 클릭은 Replay와 같은 결과임을 허용
- 결과 overlay 표시 중 stage simulation이 정지
- `no_more_ants` 실패가 time out 전에 발생
- 결과 Dictionary의 필수 키 8개가 채워짐
- EventBus stage result signal callback이 Dictionary signature로 정리됨
- `tests/GameFlowTest.tscn` 통과
- `tests/Stage02HeadlessTest.tscn`, `tests/Stage03HeadlessTest.tscn` 직접 실행 경로 통과
- headless 유지 근거: `scripts/run_test.py`는 scene path를 직접 실행하므로 main scene 변경과 독립적이다.

### 3.3 pending phase renumbering

pending phase는 한 칸씩 뒤로 이동한다.

MVP phase (status.json + 파일 + Notion):

```text
old phase06-input-pad-cursor          -> new phase07-input-pad-cursor
old phase07-input-pause-step          -> new phase08-input-pause-step
old phase08-ui-theme-assets           -> new phase09-ui-theme-assets
old phase09-ui-atoms-foundation       -> new phase10-ui-atoms-foundation
old phase10-ui-hud-toolbar-replace    -> new phase11-ui-hud-toolbar-replace
old phase11-ui-stage-dialog           -> new phase12-ui-stage-dialog
old phase12-ui-title-menu             -> new phase13-ui-title-menu
old phase13-stage4-hazard-water       -> new phase14-stage4-hazard-water
old phase14-stage5-basher             -> new phase15-stage5-basher
old phase15-stage6-digger             -> new phase16-stage6-digger
old phase16-stage7-miner              -> new phase17-stage7-miner
old phase17-stage8-climber            -> new phase18-stage8-climber
old phase18-stage9-floater            -> new phase19-stage9-floater
old phase19-stage10-bomber-polish     -> new phase20-stage10-bomber-polish
```

post-MVP phase (notion-phase-ids.json만 — 로컬 파일 없음):

```text
old phase 20 sound-bgm-sfx     -> new phase 21 sound-bgm-sfx
old phase 21 input-touch       -> new phase 22 input-touch
old phase 22 input-advanced    -> new phase 23 input-advanced
```

post-MVP shift 근거:
- 기존 `notion-phase-ids.json`이 phase 20~22를 차지하고 있어, MVP phase 19 → 20 시프트가 충돌
- post-MVP 3개도 함께 +1 시프트하여 충돌 회피
- page_id는 보존, slug-to-page_id 매핑만 갱신 (Notion page 신규 생성 불필요)

안전한 작업 순서:

```text
1. Notion sync 또는 자동 phase sync를 실행하지 않는다.
2. 로컬 파일 rename은 높은 번호에서 낮은 번호 순서로 한다.
   phase19-stage10-bomber-polish.md -> phase20-stage10-bomber-polish.md
   phase18-stage9-floater.md         -> phase19-stage9-floater.md
   ...
   phase06-input-pad-cursor.md       -> phase07-input-pad-cursor.md
3. 새 phase06-game-flow-foundation.md를 추가한다.
4. status.json을 한 번에 새 번호로 정렬한다.
5. notion-phase-ids.json을 한 번에 새 번호로 정렬한다 (MVP 6~19 → 7~20, post-MVP 20~22 → 21~23).
6. phases/mvp/README.md의 phase 목록을 갱신한다.
7. phase 파일 내부 제목과 cross-reference를 정리한다.
8. 필요하면 Notion page title/summary를 수동으로 갱신한다 (page_id는 보존, slug 매핑만 변경).
9. memory 문서 갱신이 필요한지 확인한다.
```

수정 대상:

```text
phases/mvp/status.json
phases/mvp/README.md
phases/mvp/notion-phase-ids.json
phases/mvp/phaseNN-*.md
필요 시 Notion phase page title/summary
필요 시 memory 문서
```

memory 검토 대상:

```text
C:\Users\code1412\.claude\projects\D--claude-godot\memory\candyants_phase5_lessons.md
C:\Users\code1412\.claude\projects\D--claude-godot\memory\candyants_phase_revision_2026-05-09.md
C:\Users\code1412\.claude\projects\D--claude-godot\memory\MEMORY.md
```

### 3.4 New Phase 7 input-pad-cursor

기존 Phase 6 내용을 새 Phase 7로 이동한다.

추가 검증:
- Stage01에서 cursor move 발생
- overlay Next 또는 `EventBus.request_next.emit()`으로 Stage02 이동
- 전환 직후 stale cursor payload가 skill assign에 사용되지 않음
- `InputRouter.clear_cursor_cache()` 또는 기존 scene/canvas transform 기반 자동 무효화가 동작

### 3.5 New Phase 8 input-pause-step

기존 Phase 7 내용을 새 Phase 8로 이동한다.

조정:
- `restart_stage`는 직접 reload하지 않고 `EventBus.request_replay.emit()` 경로 사용
- pause/step/speed는 StageRunner simulation state로 유지
- 결과 overlay/dialog 표시 중에는 UI 입력이 stage 입력보다 우선
- Phase 6의 `CurrentStageRoot.process_mode = DISABLED` 방식을 pause/step 설계와 통합 검토

### 3.6 New Phase 12 StageDialog

기존 Phase 11을 새 Phase 12로 이동한다.

조정:
- Phase 6의 `StageResultOverlayStub`를 본격 `StageDialog`로 교체
- `EventBus.request_*` signal과 Dictionary payload 계약은 유지
- SceneFlow 신규 생성은 하지 않는다
- saved/lost/score/time/stars 표시, motion, 중복 클릭 방지에 집중한다

### 3.7 New Phase 13 Title/Menu

기존 Phase 12를 새 Phase 13으로 이동한다.

조정:
- SceneFlow를 확장한다.
- TitleScene, MainMenu, StageSelect, SaveData를 연결한다.
- 이 phase에서 `EventBus.request_stage_select`와 `SceneFlow.go_to_stage_select()`를 추가한다.
- `SceneFlow.go_to_menu()`를 Stage01 reload fallback에서 실제 menu scene 전환으로 교체한다.
- SaveData는 Phase 6에서 확정한 Dictionary payload를 사용한다.

### 3.8 Build verification gate

위치:

```text
New Phase 13 ui-title-menu 완료 후
New Phase 14 stage4-hazard-water 진입 전
```

의미:
- Phase 6 완료 기준은 기반 검증이다.
- 이 게이트는 Title/Menu/SaveData까지 붙은 통합 검증이다.

검증 항목:
- 첫 실행 시 Title 또는 Main 흐름으로 진입
- Stage01 플레이 가능
- Stage01 clear 후 Next로 Stage02 이동
- Stage02 fail 후 Replay로 같은 stage 재시작
- Stage03 clear 후 마지막 stage fallback
- `no_more_ants` 실패 경로가 결과 UI로 이어짐
- ScoreSystem signal 누수 없음
- restart/pause/dialog 입력 충돌 없음
- 통과하지 못하면 stage4 이후 content phase에 들어가지 않음

## 4. 실제 반영 순서

권장 커밋 단위:

### Commit 1. Pre-Phase 6 hot-fix

```text
fix: disconnect score system signals (phase 5 sweep)
```

포함:
- `ScoreSystem.stop()`
- `StageRunner._exit_tree()`
- 회귀 테스트
- `phase05-impl-review.md` sweep 기록

### Commit 2. phase plan renumbering

```text
docs: insert game-flow foundation phase
```

포함:
- phase 파일 rename
- 새 `phase06-game-flow-foundation.md`
- `status.json`
- `README.md`
- `notion-phase-ids.json`
- 필요 시 memory 문서 갱신

### Commit 3. Phase 6 implementation

```text
phase 6: game-flow-foundation
```

포함:
- Main/SceneFlow
- EventBus stage result signature 변경
- EventBus request signal 3개
- StageResultOverlayStub
- StageRunner result Dictionary
- overlay lifecycle
- stage process freeze
- no_more_ants
- tests/reviews

## 5. v4 리뷰 대비 변경점

v4 리뷰에서 유지:
- v4의 EventBus Dictionary signature 결정
- v4의 Menu Stage01 reload fallback
- v4의 overlay lifecycle
- v4의 process_mode freeze
- v4의 `_make_result()` 위치

v5에서 본문으로 승격:
- `CurrentStageRoot`는 컨테이너 모델
- 마지막 stage Next 버튼 disabled, request_next fallback은 `go_to_menu()`
- `_living_ant_count()` helper와 `is_instance_valid()` 체크
- `_make_result()` null fallback 제거
- 변경 대상에 Stage02/Stage03 headless test 명시
- stub overlay 표시 범위와 중복 클릭 방지 명시
- `GlobalUI`는 `CanvasLayer(layer=10)`
- Phase 6 Menu와 Replay의 Stage01 동일 동작 허용 명시

## 6. 최종 권고

v5 기준으로 다음 순서가 가장 안전하다.

```text
1. Pre-Phase 6 hot-fix로 ScoreSystem leak 수정
2. phase plan renumbering을 high-to-low 순서로 수행
3. Phase 6 game-flow-foundation 구현
4. 기존 input/UI phase를 새 번호 기준으로 진행
5. New Phase 13 완료 후 build verification gate 통과 전까지 stage4 확장 금지
```

v5는 v4 리뷰에서 남겨둔 M1~M3를 더 이상 phase 6 plan으로 미루지 않는다. 따라서 다음 단계는 새 제안서 작성이 아니라, 이 문서를 기준으로 실제 phase 계획 반영 여부를 결정하는 것이다.
