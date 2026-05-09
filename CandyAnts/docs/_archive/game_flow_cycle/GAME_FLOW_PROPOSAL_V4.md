# Game Flow Structure Proposal v4

작성일: 2026-05-09
상태: 제안 문서 v4

근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md`
- `docs/GAME_FLOW_PROPOSAL_REVIEW.md`
- `docs/GAME_FLOW_PROPOSAL_V2.md`
- `docs/GAME_FLOW_PROPOSAL_V2_REVIEW.md`
- `docs/GAME_FLOW_PROPOSAL_V3.md`
- `docs/GAME_FLOW_PROPOSAL_V3_REVIEW.md`

범위:
- 기존 `phases/mvp/*`, `status.json`, `notion-phase-ids.json`은 아직 수정하지 않음
- 이 문서는 v3 리뷰의 HIGH/MEDIUM/LOW 보강까지 반영한 최신 제안

## 1. v4 결론

v3의 큰 방향은 유지한다.

```text
Phase 5 완료 인정
Pre-Phase 6 hot-fix로 ScoreSystem signal leak 수정
Phase 6을 game-flow-foundation으로 신설
기존 pending phase는 한 칸씩 뒤로 이동
Stage4 이후 확장은 Title/Menu까지 닫힌 루프 검증 후 재개
```

v4의 핵심 변경은 `EventBus.stage_cleared` / `EventBus.stage_failed`의 signature를 명시적으로 바꾸는 것이다.

현재 코드:

```gdscript
signal stage_cleared(score: float)
signal stage_failed(reason: String)
```

Phase 6 이후 목표:

```gdscript
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
```

이 결정을 통해 StageRunner, StageResultOverlayStub, 이후 StageDialog, SaveData가 모두 같은 결과 payload를 소비한다.

## 2. v3 리뷰 반영 요약

### N1. EventBus stage result signal signature 변경

v3 리뷰의 HIGH 지적:
- v3는 `_make_result()` Dictionary를 emit하는 의사코드를 제안했다.
- 하지만 현재 `EventBus.gd`는 `stage_cleared(score: float)`, `stage_failed(reason: String)`이다.
- `StageRunner._on_stage_cleared(score: float)`와 `_on_stage_failed(reason: String)`도 기존 signature에 묶여 있다.

v4 결정:

```gdscript
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
```

선택하지 않은 대안:
- 새 `stage_completed(result)` signal 추가: 기존 signal과 새 signal이 공존해 책임이 나뉜다.
- `stage_cleared(score, result)` 형태: `score`와 `result.score`가 중복된다.

변경 대상:
- `scripts/core/EventBus.gd`
- `scripts/core/StageRunner.gd`
- stage result signal을 구독하는 headless tests
- HUD 또는 임시 결과 UI 연결부

호환성 방침:
- Phase 6에서 기존 score/reason signal 호환을 유지하지 않는다.
- Stage result Dictionary를 단일 계약으로 삼는다.

### N2. Phase 6 Menu 동작 고정

v3 리뷰 지적:
- Phase 6에는 실제 menu scene이 없는데 `request_menu`와 `go_to_menu()`가 존재한다.
- no-op, log fallback, Stage01 reload, disabled 중 하나를 정해야 한다.

v4 결정:
- Phase 6의 Menu 버튼은 활성화한다.
- `SceneFlow.go_to_menu()`는 임시 동작으로 overlay를 숨기고 Stage01을 로드한다.
- 이 동작은 Phase 13에서 실제 menu scene 전환으로 교체된다.

Phase 6 임시 동작:

```text
Menu -> EventBus.request_menu.emit()
SceneFlow.go_to_menu()
  -> overlay.hide()
  -> load_stage(1)
```

근거:
- Phase 6에 Title/Menu scene은 없지만, "현재 플레이 흐름에서 빠져나간다"는 안전한 fallback이 필요하다.
- disabled 버튼보다 수동 검증이 쉽고, no-op보다 사용자에게 덜 이상하다.

### N3. Overlay show/hide lifecycle 고정

v3 리뷰 지적:
- StageResultOverlayStub가 GlobalUI 산하에 있으면 stage unload와 독립적이다.
- 그렇다면 언제 show/hide 되는지 SceneFlow 책임을 명확히 해야 한다.

v4 결정:
- StageRunner는 결과 signal만 emit한다.
- SceneFlow가 `stage_cleared(result)` / `stage_failed(result)`를 받아 overlay를 show한다.
- Overlay button은 request signal만 emit한다.
- SceneFlow는 request signal을 받으면 overlay hide -> current stage unload -> next stage load 순서로 처리한다.

Lifecycle:

```text
StageRunner emits stage_cleared/result
SceneFlow receives result
SceneFlow freezes current stage
SceneFlow shows StageResultOverlayStub
User clicks Replay/Next/Menu
Overlay emits request_*
SceneFlow hides overlay
SceneFlow unloads current stage
SceneFlow loads target stage
SceneFlow unfreezes current stage root after load
```

### N4. Result display 중 stage process_mode 처리

v3 리뷰 지적:
- `_completed = true`는 StageRunner만 멈춘다.
- ants, spawner, world nodes가 계속 움직일 수 있다.
- 결과 overlay가 떠 있는 동안 화면 뒤에서 stage가 계속 변할 수 있다.

v4 결정:
- 결과 overlay 표시 중 `CurrentStageRoot.process_mode = Node.PROCESS_MODE_DISABLED`를 적용한다.
- replay/next/menu 요청을 처리할 때 기존 stage를 unload하므로 별도 unfreeze는 새 stage load 후 처리한다.

구체 방침:

```gdscript
func _freeze_current_stage() -> void:
    if _current_stage_root != null:
        _current_stage_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_current_stage() -> void:
    if _current_stage_root != null:
        _current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
```

근거:
- spawner Timer, ants physics, world process를 한 번에 멈출 수 있다.
- Phase 8 pause/step과도 같은 방향으로 통합할 수 있다.

### N5. `_make_result()` helper 위치와 signature 고정

v3 리뷰 지적:
- `_make_result(true, "")`를 사용했지만 helper 정의가 없었다.

v4 결정:
- `_make_result(cleared: bool, reason: String) -> Dictionary`는 `StageRunner.gd`에 둔다.
- `StageRunner`가 stage_data, score_system, time_left를 모두 알고 있으므로 결과 payload 생성 책임을 갖는다.

권장 구현:

```gdscript
func _make_result(cleared: bool, reason: String) -> Dictionary:
    return {
        "stage_id": stage_data.id if stage_data != null else 0,
        "cleared": cleared,
        "saved": score_system.saved_pieces if score_system != null else 0,
        "lost": score_system.lost_pieces if score_system != null else 0,
        "original_hp": score_system.original_hp if score_system != null else 0,
        "score": score_system.score() if score_system != null else 0.0,
        "time_left": _time_left,
        "reason": reason,
    }
```

### LOW 보강

#### start_game wrapper

Phase 6에서 `SceneFlow.start_game()`은 단순히 `load_stage(1)`을 호출한다.

```gdscript
func start_game() -> void:
    load_stage(1)
```

Phase 13에서 Title/Menu가 들어오면 `start_game()` 의미를 확장할 수 있다.

#### test name 고정

Phase 6의 신규 game-flow 검증은 다음 이름으로 고정한다.

```text
tests/GameFlowTest.gd
tests/GameFlowTest.tscn
```

근거:
- 검증 범위가 SceneFlow 단일 컴포넌트가 아니라 EventBus request, StageRunner result, overlay lifecycle까지 포함한다.

#### AntSpawner stop 문제

`CurrentStageRoot.process_mode = DISABLED`를 채택하므로 결과 표시 중 spawner Timer와 ants도 함께 멈춘다.

별도 `AntSpawner.stop()`은 Phase 6 필수 범위가 아니다. 이후 더 명시적인 lifecycle이 필요하면 추가한다.

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
```

Scene tree 제안:

```text
Main
  SceneFlow
  CurrentStageRoot
  GlobalUI
    StageResultOverlayStub
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

EventBus 변경:

```gdscript
# 기존 signature 변경
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)

# 새 request signal
signal request_replay
signal request_next
signal request_menu
```

Phase 6에서 추가하지 않는 signal:

```gdscript
# Phase 13에서 StageSelect와 함께 추가
signal request_stage_select
```

Stage path:

```gdscript
const STAGE_SCENES := {
    1: "res://scenes/stages/Stage01.tscn",
    2: "res://scenes/stages/Stage02.tscn",
    3: "res://scenes/stages/Stage03.tscn",
}
```

Stage result Dictionary:

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

StageRunner result emission:

```gdscript
EventBus.stage_cleared.emit(_make_result(true, ""))
EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))
EventBus.stage_failed.emit(_make_result(false, "time_out"))
```

StageRunner result helper:

```gdscript
func _make_result(cleared: bool, reason: String) -> Dictionary:
    return {
        "stage_id": stage_data.id if stage_data != null else 0,
        "cleared": cleared,
        "saved": score_system.saved_pieces if score_system != null else 0,
        "lost": score_system.lost_pieces if score_system != null else 0,
        "original_hp": score_system.original_hp if score_system != null else 0,
        "score": score_system.score() if score_system != null else 0.0,
        "time_left": _time_left,
        "reason": reason,
    }
```

StageResultOverlayStub:
- `GlobalUI` 산하에 둔다.
- stage scene unload와 함께 사라지지 않는다.
- Replay / Next / Menu 버튼을 가진다.
- 결과 표시 중 중복 클릭을 막는다.
- 본격 디자인, stars, motion은 Phase 12 StageDialog로 미룬다.

Button behavior:

```text
Replay -> EventBus.request_replay.emit()
Next   -> EventBus.request_next.emit()
Menu   -> EventBus.request_menu.emit()
```

SceneFlow overlay lifecycle:

```text
stage result signal 수신
-> CurrentStageRoot.process_mode = DISABLED
-> overlay.show(result)
-> request_* 수신
-> overlay.hide()
-> current stage unload
-> target stage load
-> CurrentStageRoot.process_mode = INHERIT
```

Menu fallback:

```text
Phase 6 go_to_menu()
-> overlay.hide()
-> load_stage(1)
```

Phase 13에서 `go_to_menu()`는 실제 menu scene 전환으로 교체한다.

`no_more_ants` 판정:
- clear 판정 후에 실행한다.
- time out 판정보다 먼저 실행한다.
- 조건:

```text
_spawner_finished == true
living ants == 0
score_system.in_transit_pieces == 0
candy_hp > 0
```

판정 순서:

```gdscript
clear -> no_more_ants -> time_out
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
- 실행 시 `Main.tscn`을 통해 Stage01 로드
- Stage01 clear 후 overlay의 Next 버튼으로 Stage02 이동
- Stage02 fail 후 overlay의 Replay 버튼으로 Stage02 재시작
- Stage03 clear 후 마지막 stage fallback 동작
- Menu 버튼은 Stage01 reload fallback으로 안전 처리
- 결과 overlay 표시 중 stage simulation이 정지
- `no_more_ants` 실패가 time out 전에 발생
- 결과 Dictionary의 필수 키 8개가 채워짐
- EventBus stage result signal callback이 Dictionary signature로 정리됨
- `tests/GameFlowTest.tscn` 통과
- `tests/Stage02HeadlessTest.tscn`, `tests/Stage03HeadlessTest.tscn` 직접 실행 경로 통과
- headless 유지 근거: `scripts/run_test.py`는 scene path를 직접 실행하므로 main scene 변경과 독립적이다.

### 3.3 pending phase renumbering

pending phase는 한 칸씩 뒤로 이동한다.

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

안전한 작업 순서:

```text
1. Notion sync 또는 자동 phase sync를 실행하지 않는다.
2. 파일 rename은 높은 번호에서 낮은 번호 순서로 한다.
   phase19 -> phase20
   phase18 -> phase19
   ...
   phase06 -> phase07
3. 새 phase06-game-flow-foundation.md를 추가한다.
4. status.json을 한 번에 새 번호로 정렬한다.
5. notion-phase-ids.json을 한 번에 새 번호로 정렬한다.
6. phases/mvp/README.md의 phase 목록을 갱신한다.
7. phase 파일 내부 제목과 cross-reference를 정리한다.
8. 필요하면 Notion page title/summary를 수동으로 갱신한다.
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

## 5. v3 대비 변경점

v3에서 유지:
- Pre-Phase 6 hot-fix
- Dictionary payload 확정
- StageResultOverlayStub
- no_more_ants 포함
- pending phase 전체 +1
- mass rename high-to-low
- Stage4 전 build verification gate

v4에서 보강:
- `stage_cleared` / `stage_failed` signal signature를 Dictionary로 변경한다고 명시
- StageRunner callback/test callback도 Dictionary signature로 정리한다고 명시
- Phase 6 Menu 동작을 Stage01 reload fallback으로 고정
- overlay hide -> unload -> load lifecycle 고정
- 결과 표시 중 `CurrentStageRoot.process_mode = DISABLED` 적용
- `_make_result(cleared, reason)` helper를 StageRunner에 둔다고 명시
- 신규 test 이름을 `GameFlowTest`로 고정

## 6. 최종 권고

v4 기준으로 다음 순서가 가장 안전하다.

```text
1. Pre-Phase 6 hot-fix로 ScoreSystem leak 수정
2. phase plan renumbering을 high-to-low 순서로 수행
3. Phase 6 game-flow-foundation 구현
4. 기존 input/UI phase를 새 번호 기준으로 진행
5. New Phase 13 완료 후 build verification gate 통과 전까지 stage4 확장 금지
```

v4는 v3 리뷰의 HIGH였던 EventBus signature 충돌을 해소한다. 또한 Phase 6에서 메뉴, overlay lifecycle, stage freeze, result helper까지 결정해 self-review에서 다시 흔들릴 여지를 줄인다.
