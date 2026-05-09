# Game Flow Structure Proposal v2

작성일: 2026-05-09
상태: 제안 문서 v2
근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md`
- `docs/GAME_FLOW_PROPOSAL_REVIEW.md`

범위:
- 기존 `phases/mvp/*`, `status.json`, `notion-phase-ids.json`은 아직 수정하지 않음
- 이 문서는 다음 개발 계획을 어떻게 바꾸면 좋을지에 대한 결정 가능한 제안

## 1. v2 결론

Phase 5는 완료된 상태다. 다음 작업은 기존 Phase 6 `input-pad-cursor`로 바로 들어가기보다, 먼저 게임 플로우 기반을 세우는 편이 좋다.

다만 v1 제안처럼 Phase 6 이후 모든 pending phase 번호를 일괄 +1 하는 방식은 비용이 크다. 반대로 리뷰 문서의 "Phase 6 슬롯 swap" 안은 의도는 좋지만, 실제 파일 구조상 `phase07-input-pad-cursor.md`와 기존 `phase07-input-pause-step.md`가 충돌하는 문제가 있다.

따라서 v2의 추천안은 다음이다.

```text
완료: Phase 5 input-action-foundation
즉시: Phase 5 sweep hot-fix - ScoreSystem.stop/disconnect
다음: Phase 6 game-flow-foundation
이후: 기존 Phase 6~19는 한 칸씩 뒤로 이동
게이트: Phase 13(stage4) 진입 전, stage 1~3 게임 루프 검증
```

즉, 번호 재배열 비용은 받아들이되, 그 이유와 작업 범위를 명확히 한다. 이 방식이 가장 단순하고, 중복 phase 번호나 애매한 Notion 매핑을 만들지 않는다.

## 2. 리뷰 반영 사항

### 채택한 리뷰 지적

#### 2.1 ScoreSystem leak은 game-flow 전에 고쳐야 한다

리뷰 근거:
- `ScoreSystem.gd`는 `EventBus.candy_piece_picked`, `EventBus.ant_saved`, `EventBus.candy_piece_lost`에 connect만 하고 disconnect가 없다.
- SceneFlow가 stage reload를 시작하면 즉시 중복 카운트 위험이 생긴다.
- `CLAUDE.md`의 sweep 정책상 사후/현재 발견된 HIGH는 다음 phase 전에 hot-fix로 처리해야 한다.

v2 반영:
- `game-flow-foundation` 전에 별도 Phase 5 sweep hot-fix를 둔다.
- 이 작업은 새 phase가 아니라 완료된 Phase 5의 후속 sweep으로 본다.

#### 2.2 결과 payload는 MVP 동안 Dictionary로 확정한다

리뷰 근거:
- v1은 Dictionary, typed `StageResult`, `get_result()`를 모두 열어두었다.
- 그러면 StageDialog와 SaveData phase에서 입력 계약이 다시 흔들린다.
- MVP 소비자는 StageDialog와 SaveData 정도로 제한된다.

v2 반영:
- Phase 6에서 결과 payload는 Dictionary로 확정한다.
- typed `StageResult` Resource는 post-MVP 또는 SaveData/통계 고도화 시점으로 미룬다.

필수 키:

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

#### 2.3 StageDialog의 lifecycle은 미리 결정해야 한다

리뷰 근거:
- StageDialog가 stage scene 하위에 있으면 `Next` 클릭 직후 stage unload와 함께 사라질 수 있다.
- GlobalUI에 두면 scene unload와 분리되지만 결과 payload 계약이 중요해진다.

v2 반영:
- Phase 6에서는 본격 StageDialog UI를 만들지 않는다.
- 대신 `Main.tscn` 아래 `GlobalUI` 영역에 임시 결과 overlay/stub를 둔다.
- 본격 `StageDialog.tscn` 이름과 디자인 작업은 기존 StageDialog phase로 미룬다.

권장 명명:

```text
scenes/ui/StageResultOverlayStub.tscn
scripts/ui/StageResultOverlayStub.gd
```

이름에 `Stub`을 붙여 Phase 11/12의 본격 UI와 혼동을 줄인다.

#### 2.4 실패 판정 보강은 game-flow에 포함한다

리뷰 근거:
- 모든 개미가 사라졌는데 시간 초과까지 기다리는 상태는 "제대로 돌아가는 빌드"가 아니다.
- 사용자 의도는 스테이지 추가보다 기본 게임 루프 우선이다.

v2 반영:
- `AntSpawner.spawn_finished`
- living ants count
- `ScoreSystem.in_transit_pieces`
- `Candy.hp`

위 조건으로 `no_more_ants` 실패를 Phase 6에 포함한다.

### 수정해서 반영한 리뷰 지적

#### 2.5 "Phase 6 슬롯 swap"은 그대로 채택하지 않는다

리뷰 문서의 핵심 의도는 좋다. 전체 phase를 흔드는 비용을 줄이자는 방향은 타당하다.

하지만 리뷰 문서의 구체안에는 구조적 문제가 있다.

리뷰 문서 제안:

```text
phase06-input-pad-cursor.md -> phase07-input-pad-cursor.md
phase07-input-pause-step.md -> 그대로 유지
phase 8~19는 손대지 않음
```

문제:
- `phase07-input-pad-cursor.md`와 기존 `phase07-input-pause-step.md`가 동시에 존재하게 된다.
- `status.json`의 id 7이 무엇을 가리키는지 모호해진다.
- Notion phase 7 page가 pad인지 pause인지 결정되지 않는다.
- 결국 2개 page만 수정한다는 비용 계산이 성립하지 않는다.

v2 판단:
- "slot swap"은 문서상 좋은 의도였지만 실제 파일/상태 구조와 맞지 않는다.
- 계획을 바꾼다면 명시적으로 pending phase를 한 칸씩 미는 편이 더 안전하다.

## 3. 최종 추천 계획

### Stage 0. Phase 5 sweep hot-fix

상태:
- Phase 5는 완료된 상태로 유지
- 이 작업은 새 phase가 아니라 Phase 5 sweep hot-fix

목표:

```text
SceneFlow 도입 전에 ScoreSystem의 전역 signal 연결 누수를 제거한다.
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
- `ScoreSystem.stop()`에서 EventBus signal disconnect
- 중복 disconnect 안전 처리
- `StageRunner._exit_tree()`에서 `score_system.stop()` 호출
- stage reload 또는 StageRunner 재생성 시 카운트 중복이 없는지 테스트
- `phase05-impl-review.md`에 sweep round 기록

커밋 메시지 제안:

```text
fix: disconnect score system signals (phase 5 sweep)
```

완료 기준:
- 기존 Stage02/Stage03 headless test 통과
- 같은 stage를 두 번 로드해도 saved/lost/in_transit 카운트가 중복 증가하지 않음

### Stage 1. Phase 6 game-flow-foundation 신설

파일명:

```text
phases/mvp/phase06-game-flow-foundation.md
```

phase name:

```text
game-flow-foundation
```

목표:

```text
Stage01 직접 실행 구조를 벗어나 Main/SceneFlow가 stage 1~3 플레이 세션을 소유하게 한다.
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

구현 범위:
- `project.godot` main scene을 `res://scenes/Main.tscn`으로 변경
- `Main.tscn`에 `CurrentStageRoot`, `GlobalUI`, `SceneFlow` 역할 추가
- `SceneFlow.gd` 신규 생성
- Stage01/02/03 scene path는 코드 상수로 관리
- 실행 시 Stage01 로드
- `EventBus.request_replay` 수신 시 현재 stage 재시작
- `EventBus.request_next` 수신 시 다음 stage 로드
- 마지막 stage에서 `request_next`는 `request_menu` fallback 또는 no-op
- `EventBus.request_menu`, `EventBus.request_stage_select` 추가
- StageRunner는 scene load를 직접 하지 않고 결과 signal만 emit
- StageRunner 결과 payload는 Dictionary로 확정
- `no_more_ants` 실패 판정 추가
- 임시 결과 overlay는 `GlobalUI` 산하에 표시

SceneFlow API 제안:

```gdscript
class_name SceneFlow
extends Node

func start_game() -> void
func load_stage(stage_id: int) -> void
func replay_stage() -> void
func load_next_stage() -> void
func go_to_menu() -> void
```

비범위:
- 타이틀 화면
- StageSelect
- SaveData
- 최종 디자인 StageDialog
- stars UI
- gamepad virtual cursor
- typed `StageResult`

완료 기준:
- 실행 시 `Main.tscn`을 통해 Stage01 로드
- Stage01 clear 후 Next로 Stage02 이동 가능
- Stage02 fail 후 Replay로 Stage02 재시작 가능
- Stage03 clear 후 마지막 stage fallback 동작
- `no_more_ants` 실패가 시간 초과 전 발생
- 기존 Stage02/Stage03 직접 실행 headless test는 계속 통과
- 결과 Dictionary에 필수 키 8개가 모두 채워짐

### Stage 2. 기존 pending phase 번호 조정

v2는 번호 충돌을 피하기 위해 pending phase를 명시적으로 한 칸씩 뒤로 민다.

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

수정 대상:

```text
phases/mvp/status.json
phases/mvp/README.md
phases/mvp/notion-phase-ids.json
phase 파일명
phase 파일 내부 제목
필요 시 Notion phase page title/summary
```

주의:
- 이 작업은 비용이 크다.
- 하지만 phase 7 중복이나 Notion mapping 모호성을 남기지 않는다.
- 실제 적용 시에는 별도 커밋으로 분리하는 편이 좋다.

### Stage 3. Phase 7 input-pad-cursor

기존 Phase 6 내용을 새 Phase 7로 이동한다.

추가 검증만 더한다.

추가 검증:
- Stage01에서 cursor 움직임 발생
- request_next로 Stage02 이동
- 전환 직후 stale cursor payload가 skill assign에 사용되지 않음
- `InputRouter.clear_cursor_cache()` 또는 scene/canvas transform 기반 자동 무효화가 동작

나머지 내용은 기존 `phase06-input-pad-cursor.md` 계획을 유지한다.

### Stage 4. Phase 8 input-pause-step

기존 Phase 7 내용을 새 Phase 8로 이동한다.

조정:
- `restart_stage`는 직접 scene reload하지 않고 `EventBus.request_replay.emit()` 경로 사용
- pause/step/speed는 StageRunner 내부 simulation 상태로 유지
- 결과 overlay/dialog 표시 중에는 stage 입력보다 UI 입력이 우선

### Stage 5. Phase 12 StageDialog

기존 StageDialog phase는 새 번호 기준 Phase 12가 된다.

조정:
- Phase 6에서 만든 `StageResultOverlayStub`를 본격 `StageDialog`로 교체
- `EventBus.request_*` 신호와 결과 Dictionary 계약은 그대로 사용
- SceneFlow를 새로 만들지 않는다
- saved/lost/score/time/stars 표시와 버튼 UX에 집중한다

### Stage 6. Phase 13 Title/Menu

기존 Title/Menu phase는 새 번호 기준 Phase 13이 된다.

조정:
- 이미 존재하는 `SceneFlow`를 확장한다.
- TitleScene, MainMenu, StageSelect, SaveData를 연결한다.
- StageSelect는 `SceneFlow.load_stage(stage_id)`를 호출한다.
- SaveData는 Phase 6에서 확정한 결과 Dictionary를 사용한다.

### Stage 7. 빌드 검증 게이트

Stage 4~10 컨텐츠 확장 phase에 들어가기 전에, stage 1~3로 다음 루프를 반드시 검증한다.

게이트 위치:

```text
new Phase 13 ui-title-menu 완료 후
new Phase 14 stage4-hazard-water 진입 전
```

검증 항목:
- 첫 실행 시 Title 또는 Main 흐름으로 진입
- Stage01 플레이 가능
- Stage01 clear 후 Next로 Stage02 이동
- Stage02 fail 후 Replay로 같은 stage 재시작
- Stage03 clear 후 마지막 stage fallback
- `no_more_ants` 실패 경로가 결과 UI로 이어짐
- ScoreSystem signal 누수 없음
- restart/pause/dialog 입력 충돌 없음

게이트 정책:

```text
이 검증을 통과하지 못하면 stage4 이후 컨텐츠 phase에 들어가지 않는다.
```

## 4. 대안

### 대안 A. phase 번호를 거의 건드리지 않는 방식

방식:
- 기존 `phase06-input-pad-cursor.md`를 `phase06-game-flow-foundation.md`로 완전히 재정의
- pad cursor 계획은 `phase06-deferred-pad-cursor.md` 또는 README deferred 항목으로 이동
- 기존 phase07 이후는 그대로 유지

장점:
- 번호 재배열이 작다.
- Notion/status 수정이 적다.

단점:
- pad cursor가 정규 phase 목록에서 빠져 추적성이 떨어진다.
- 원래 Phase 6의 의미가 사라진다.
- 나중에 pad cursor를 다시 정규 phase로 넣을 때 또 조정이 필요하다.

추천도:
- Notion/phase 번호 변경 비용을 절대 피해야 한다면만 선택.
- 현재로서는 v2 최종 추천보다 덜 좋다.

### 대안 B. Phase 11 StageDialog를 앞당기는 방식

방식:
- 기존 StageDialog phase를 지금 시작하고, 그 안에 SceneFlow를 포함

장점:
- phase 번호 변경이 작다.

단점:
- UI phase가 구조 변경까지 떠안아 너무 커진다.
- input-pad-cursor, pause-step이 game-flow 없이 진행된다.
- "스테이지 확장보다 제대로 돌아가는 빌드"라는 사용자 의도와 덜 맞다.

추천도:
- 비추천.

## 5. v1 대비 변경점

v1:
- Phase 6 앞에 새 phase를 넣고 이후 전체 +1 추천
- StageResult 타입을 열어둠
- ScoreSystem stop을 game-flow 작업 후반에 배치
- StageDialog 위치를 optional GlobalUI로 둠

v2:
- Phase 5 sweep hot-fix를 game-flow 전에 분리
- 결과 payload는 MVP 동안 Dictionary 확정
- Phase 6은 game-flow-foundation으로 명확히 신설
- 이후 pending phase는 충돌 없이 한 칸씩 뒤로 이동
- Phase 6에서는 본격 StageDialog가 아니라 GlobalUI의 stub overlay만 만든다
- StageDialog 정식 UI는 새 Phase 12로 유지
- Title/Menu는 새 Phase 13에서 SceneFlow 확장으로 처리
- Stage4 진입 전 빌드 검증 게이트를 명시

## 6. 실제 반영 순서 제안

실제 파일을 수정한다면 다음 순서를 추천한다.

1. `ScoreSystem.stop()` sweep hot-fix를 먼저 구현한다.
2. `phase05-impl-review.md`에 sweep round를 기록한다.
3. `phase06-game-flow-foundation.md`를 새로 작성한다.
4. 기존 pending phase 파일을 한 칸씩 rename한다.
5. `status.json`을 새 번호에 맞게 정렬한다.
6. `notion-phase-ids.json`을 새 번호에 맞게 갱신한다.
7. `GAME_FLOW_PROPOSAL.md`는 v1로 보존하고, 본 문서 v2를 현재 결정안으로 사용한다.
8. 필요하면 Notion phase page title/summary를 갱신한다.

## 7. 최종 권고

지금 가장 중요한 것은 새 스테이지를 더 쌓는 것이 아니라, 이미 있는 stage 1~3이 하나의 게임처럼 시작되고 끝나고 이어지는 것이다.

따라서 다음 결정이 좋다.

```text
Phase 5 완료 인정
Phase 5 sweep으로 ScoreSystem leak 즉시 수정
Phase 6을 game-flow-foundation으로 신설
기존 pending phase는 한 칸씩 뒤로 이동
Stage4 이후 확장은 Title/Menu까지 닫힌 루프 검증 후 재개
```

이 안은 문서/Notion 정리 비용은 있지만, 구현 순서와 추적 상태가 가장 덜 모호하다.
