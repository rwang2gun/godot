# Game Flow Structure Proposal v3

작성일: 2026-05-09
상태: 제안 문서 v3

근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md`
- `docs/GAME_FLOW_PROPOSAL_REVIEW.md`
- `docs/GAME_FLOW_PROPOSAL_V2.md`
- `docs/GAME_FLOW_PROPOSAL_V2_REVIEW.md`

범위:
- 기존 `phases/mvp/*`, `status.json`, `notion-phase-ids.json`은 아직 수정하지 않음
- 이 문서는 v2 리뷰의 MEDIUM/LOW 보강까지 반영한 최신 제안

## 1. v3 결론

v2의 큰 방향은 유지한다.

```text
Phase 5 완료 인정
Pre-Phase 6 hot-fix로 ScoreSystem signal leak 수정
Phase 6을 game-flow-foundation으로 신설
기존 pending phase는 한 칸씩 뒤로 이동
Stage4 이후 확장은 Title/Menu까지 닫힌 루프 검증 후 재개
```

v3에서 달라진 점은 네 가지다.

1. mass rename은 반드시 높은 번호에서 낮은 번호 순서로 수행한다.
2. Phase 6에서는 `request_stage_select`를 만들지 않는다. `request_replay`, `request_next`, `request_menu`만 둔다.
3. `StageResultOverlayStub`는 Replay / Next / Menu 버튼 3개를 가진다.
4. `no_more_ants` 판정 순서와 boolean 조건을 코드 수준으로 고정한다.

## 2. v2 리뷰 반영 요약

### 채택한 MEDIUM 보강

#### F1. mass rename 순서 명시

문제:
- pending phase를 한 칸씩 뒤로 미는 작업 중 `phase07-*` 같은 중간 중복 상태가 생길 수 있다.
- 그 상태에서 `status.json`이나 Notion sync가 실행되면 매핑이 꼬일 수 있다.

v3 결정:
- 파일 rename은 높은 번호에서 낮은 번호 순서로 한다.
- `status.json`은 파일 rename이 끝난 뒤 한 번에 정리한다.
- `notion-phase-ids.json`도 마지막에 한 번에 정리한다.
- 작업 중 Notion sync는 실행하지 않는다.

#### F2. `request_stage_select`는 Phase 13으로 이동

문제:
- v2는 `EventBus.request_stage_select`를 Phase 6에 추가한다고 했지만, SceneFlow API에는 `go_to_stage_select()`가 없었다.
- Phase 6에는 StageSelect UI가 없으므로 dead signal이 된다.

v3 결정:
- Phase 6 EventBus request signal은 3개만 추가한다.

```gdscript
signal request_replay
signal request_next
signal request_menu
```

- `request_stage_select`와 `SceneFlow.go_to_stage_select()`는 Title/Menu/StageSelect가 들어오는 Phase 13에서 추가한다.

#### F3. Stub overlay 버튼 의무화

문제:
- v2는 `StageResultOverlayStub`를 말했지만, 버튼과 검증 방식이 불분명했다.
- Phase 6 완료 기준에 "Next로 Stage02 이동"이 있으려면 실제 클릭 가능한 UI가 필요하다.

v3 결정:
- Phase 6의 `StageResultOverlayStub`는 최소 3개 버튼을 가진다.

```text
Replay
Next
Menu
```

- 버튼 동작:

```text
Replay -> EventBus.request_replay.emit()
Next   -> EventBus.request_next.emit()
Menu   -> EventBus.request_menu.emit()
```

- headless test는 signal emit 경로를 확인한다.
- 수동 검증은 버튼 클릭 경로를 확인한다.

#### F4. `no_more_ants` 판정 조건 고정

문제:
- v2는 필요한 값만 나열했고, clear/fail 우선순위가 코드 수준으로 정해져 있지 않았다.
- Candy hp가 0이 되는 순간, 마지막 운반 개미가 저장되는 순간, spawner가 끝나는 순간이 겹칠 수 있다.

v3 결정:
- 판정 순서는 clear -> no_more_ants -> time_out 이다.
- clear 판정이 항상 실패 판정보다 우선한다.

권장 의사코드:

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

주의:
- `_spawner_finished`는 `AntSpawner.spawn_finished` signal을 받아 boolean으로 보관한다.
- living ants는 `get_tree().get_nodes_in_group("ants")` 기반으로 세되, invalid node는 제외한다.
- `in_transit_pieces == 0` 조건은 운반 중인 사탕이 아직 집으로 갈 수 있는 상황을 실패로 오판하지 않기 위해 필요하다.

### 채택한 LOW 보강

#### F5. 빌드 검증 게이트 중복성 명시

Phase 6 완료 기준과 Phase 13 이후 빌드 검증 게이트는 일부 겹친다.

v3 결정:
- Phase 6 완료 기준은 최소 루프가 처음 닫히는지 확인한다.
- Phase 13 이후 게이트는 Title/Menu/SaveData까지 붙은 실제 플레이 경로를 다시 검증한다.
- 같은 항목이 있어도 중복이 아니라 "기반 검증"과 "통합 검증"으로 본다.

#### F6. headless test 유지 근거 추가

근거:
- `scripts/run_test.py`는 scene path를 직접 받아 실행한다.
- 따라서 `project.godot`의 main scene을 `Main.tscn`으로 바꿔도 `tests/Stage02HeadlessTest.tscn`, `tests/Stage03HeadlessTest.tscn` 직접 실행 경로는 유지될 수 있다.

v3 결정:
- Phase 6 완료 기준에 이 근거를 명시한다.

#### F7. "Stage 0" 명칭 변경

v3에서는 "Stage 0" 대신 다음 명칭을 사용한다.

```text
Pre-Phase 6 hot-fix
```

#### F8. memory 문서 갱신 대상 추가

phase 번호 구조를 바꿀 경우 repo 외부 memory도 갱신 대상이다.

검토 대상:

```text
C:\Users\code1412\.claude\projects\D--claude-godot\memory\candyants_phase5_lessons.md
C:\Users\code1412\.claude\projects\D--claude-godot\memory\candyants_phase_revision_2026-05-09.md
C:\Users\code1412\.claude\projects\D--claude-godot\memory\MEMORY.md
```

주의:
- 이 경로는 현재 workspace writable root 밖일 수 있으므로, 실제 수정 시 권한 확인 또는 사용자 승인 절차가 필요할 수 있다.

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
- StageRunner reload 또는 같은 stage 2회 로드 시 카운트 중복 없음 검증
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
tests/SceneFlowTest.gd 또는 tests/GameFlowTest.gd
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

EventBus 추가 signal:

```gdscript
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

결과 payload:

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

StageResultOverlayStub:
- `GlobalUI` 산하에 둔다.
- stage scene unload와 함께 사라지지 않는다.
- Replay / Next / Menu 버튼을 가진다.
- 결과 표시 중에는 중복 클릭을 막는다.
- 본격 디자인, stars, motion은 Phase 12 StageDialog로 미룬다.

버튼 동작:

```text
Replay -> EventBus.request_replay.emit()
Next   -> EventBus.request_next.emit()
Menu   -> EventBus.request_menu.emit()
```

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

완료 기준:
- `project.godot` main scene이 `Main.tscn`
- 실행 시 `Main.tscn`을 통해 Stage01 로드
- Stage01 clear 후 overlay의 Next 버튼으로 Stage02 이동
- Stage02 fail 후 overlay의 Replay 버튼으로 Stage02 재시작
- Stage03 clear 후 마지막 stage fallback 동작
- Menu 버튼은 현재 Phase 6 범위에서 no-op 또는 로그 fallback으로 안전 처리
- `no_more_ants` 실패가 time out 전에 발생
- 결과 Dictionary의 필수 키 8개가 채워짐
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
- EventBus request signal 3개
- StageResultOverlayStub
- StageRunner result Dictionary
- no_more_ants
- tests/reviews

## 5. v2 대비 변경점

v2에서 유지:
- Phase 5 sweep 선행
- Dictionary payload 확정
- StageResultOverlayStub 명명
- no_more_ants 포함
- pending phase 전체 +1
- Stage4 전 build verification gate

v3에서 보강:
- mass rename high-to-low 순서 명시
- `request_stage_select`를 Phase 13으로 이동
- Stub overlay 버튼 3개와 emit 동작 명시
- no_more_ants 판정 순서와 조건을 코드 수준으로 명시
- headless test가 main scene 변경과 독립적인 이유 명시
- Stage 0 명칭을 Pre-Phase 6 hot-fix로 변경
- memory 문서 갱신 대상 추가

## 6. 최종 권고

v3 기준으로 다음 순서가 가장 안전하다.

```text
1. Pre-Phase 6 hot-fix로 ScoreSystem leak 수정
2. phase plan renumbering을 high-to-low 순서로 수행
3. Phase 6 game-flow-foundation 구현
4. 기존 input/UI phase를 새 번호 기준으로 진행
5. New Phase 13 완료 후 build verification gate 통과 전까지 stage4 확장 금지
```

이 안은 문서/Notion 정리 비용을 숨기지 않는다. 대신 중복 phase 번호, dead signal, 임시 UI 범위 혼선, clear/fail race를 계획 단계에서 제거한다.
