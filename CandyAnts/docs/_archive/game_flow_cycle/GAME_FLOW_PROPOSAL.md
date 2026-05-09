# Game Flow Structure Proposal

작성일: 2026-05-09
상태: 제안 문서
범위: 기존 MVP phase/status 계획은 수정하지 않음

## 요약

현재 CandyAnts는 스테이지 단위의 시뮬레이션과 입력 기반은 일부 갖춰졌지만, 플레이어가 경험하는 게임의 기본 흐름은 아직 분리된 구조로 완성되어 있지 않다.

현재 구조는 대략 다음 상태다.

- `project.godot`가 `Stage01.tscn`을 직접 실행한다.
- `StageRunner`가 한 스테이지 안에서 클리어/실패 신호를 낼 수 있다.
- `HUD`가 간단한 결과 다이얼로그를 띄울 수 있다.
- `GameManager`는 전역 게임 진행을 관리하지 않고 부트 검증만 수행한다.
- 빈 `Main.tscn`은 아직 게임 진입점 역할을 하지 않는다.

따라서 지금은 "스테이지를 실행할 수 있음"에 가깝고, "게임으로 진행됨"에는 아직 도달하지 않았다.

## 현재 구조에서 확인된 핵심 문제

### 1. 게임 흐름의 소유자가 없다

현재 실행 진입점은 `res://scenes/stages/Stage01.tscn`이다. 이 구조에서는 타이틀, 메뉴, 스테이지 선택, 다음 스테이지, 재시도 같은 흐름을 중앙에서 다루기 어렵다.

필요한 책임:

- 현재 스테이지 번호 추적
- 스테이지 씬 로드/언로드
- 재시작
- 다음 스테이지 이동
- 메뉴 또는 스테이지 선택 화면 복귀
- 마지막 스테이지 처리

이 책임은 `GameManager` 또는 별도 `SceneFlow`가 소유하는 편이 좋다.

### 2. 결과 화면이 진행 요청을 만들지 못한다

현재 `StageRunner`는 `stage_cleared`/`stage_failed`가 발생하면 `HUD.show_dialog()`를 호출한다. 이 다이얼로그는 메시지를 보여줄 뿐이며, 다음 행동을 플레이어가 선택할 수 있는 구조가 아니다.

필요한 결과 화면:

- Clear/Failed 상태 표시
- saved / lost / score / 남은 시간 표시
- Replay
- Next Stage
- Menu 또는 Stage Select
- 마지막 스테이지에서 Next 숨김 또는 메뉴로 fallback

### 3. 실패 판정이 부족하다

현재 실패는 사실상 시간 초과 중심이다. 그러나 게임으로서는 다음 상태도 실패 또는 종료 후보가 되어야 한다.

- 모든 개미가 사라졌고 더 이상 사탕을 운반할 수 없음
- 스폰이 끝났고 클리어 조건 달성이 불가능함
- 남은 사탕 조각을 회수할 수 없는 상태

MVP에서는 정교한 solvability 분석까지는 필요 없지만, 최소한 다음 판정은 필요하다.

- spawner finished
- living ants count
- in_transit count
- candy_hp
- saved/lost count

이 조합으로 "더 이상 진행 불가능"을 판단할 수 있다.

### 4. 전역 신호 연결 수명 관리가 약하다

`ScoreSystem`은 `EventBus`에 연결되지만 명시적으로 해제하지 않는다. 현재는 스테이지 직접 실행에서는 큰 문제가 드러나지 않을 수 있으나, 씬 전환이 도입되면 이전 스테이지의 `ScoreSystem`이 신호를 계속 받을 위험이 있다.

권장:

- `ScoreSystem.start()`와 짝이 되는 `stop()` 추가
- `StageRunner._exit_tree()`에서 stop 호출
- 또는 ScoreSystem을 Node로 만들고 StageRunner 하위에 배치해 lifecycle을 SceneTree에 맡김

### 5. 입력 액션과 게임 진행 액션이 연결되어 있지 않다

`restart_stage`, `pause_toggle`, `release_rate_up/down` 같은 액션은 정의되어 있지만, 현재 게임 플로우 레벨의 소비자가 부족하다.

권장 소비자:

- `StageRunner`: release rate, pause, step, speed 등 스테이지 내부 액션
- `GameManager` 또는 `SceneFlow`: restart, next, menu 등 씬 흐름 액션
- `StageDialog`: 결과 화면에서 버튼 이벤트 발행

## 제안 구조

### 1. Main을 실제 게임 진입점으로 사용

`Main.tscn`은 게임의 루트가 되고, 실제 실행 씬은 `Main.tscn`으로 전환한다.

초기 MVP에서는 타이틀/메뉴를 생략하고 바로 Stage01을 로드해도 된다. 중요한 점은 Stage01을 직접 main scene으로 두지 않고, 흐름 소유자를 거쳐 로드하는 것이다.

예상 구조:

```text
Main
  SceneFlow
  CurrentStageRoot
  GlobalUI(optional)
```

### 2. SceneFlow 추가

`SceneFlow`는 씬 전환만 담당한다. 게임 규칙은 StageRunner가 계속 담당한다.

제안 API:

```gdscript
class_name SceneFlow
extends Node

func start_game() -> void
func load_stage(stage_id: int) -> void
func replay_stage() -> void
func load_next_stage() -> void
func go_to_stage_select() -> void
func go_to_menu() -> void
```

초기에는 `stage_id -> scene_path` 매핑을 코드 상수로 두어도 된다. 이후 `data/menu_layout.tres` 또는 progression data로 옮긴다.

### 3. EventBus에 진행 요청 신호 추가

결과 UI와 흐름 관리자 사이를 직접 참조로 묶지 않기 위해 요청 신호를 둔다.

```gdscript
signal request_replay
signal request_next
signal request_menu
signal request_stage_select
```

StageDialog는 이 신호를 emit하고, SceneFlow 또는 GameManager가 구독한다.

### 4. StageDialog를 HUD의 AcceptDialog 대신 사용

현재 `HUD.show_dialog(message)`는 임시 구현에 가깝다. 이를 별도 `StageDialog.tscn`/`StageDialog.gd`로 분리한다.

StageDialog 입력:

- result: clear 또는 failed
- stage_id
- saved_pieces
- lost_pieces
- original_hp
- score
- time_left
- fail_reason
- has_next_stage

StageDialog 출력:

- replay
- next
- menu 또는 stage_select

### 5. StageRunner는 스테이지 내부 결과만 책임진다

StageRunner의 책임은 다음으로 제한한다.

- StageData 적용
- Candy/Home/Spawner/HUD 연결
- ScoreSystem 시작/정리
- 스테이지 클리어/실패 판정
- 결과 payload 생성
- `EventBus.stage_cleared`/`stage_failed` emit

StageRunner가 직접 다음 씬을 로드하지는 않는다.

### 6. ScoreSystem은 결과 payload를 제공한다

현재 `stage_cleared(score: float)`만으로는 결과 화면과 SaveData에 필요한 정보가 부족하다.

선택지:

1. `stage_cleared(result: Dictionary)`로 확장
2. `StageResult` Resource 또는 RefCounted 추가
3. 기존 signal은 유지하고 `StageRunner.get_result()` 형태로 조회

권장안은 `StageResult` 또는 Dictionary다. MVP에서는 Dictionary가 빠르지만, 장기적으로는 타입이 있는 `StageResult`가 좋다.

예시:

```gdscript
{
  "stage_id": 2,
  "cleared": true,
  "saved": 8,
  "lost": 2,
  "original_hp": 10,
  "score": 0.8,
  "time_left": 43.2,
  "reason": ""
}
```

## 권장 구현 순서

### Step 1. 최소 SceneFlow 세우기

- `Main.tscn`을 실제 진입점으로 준비
- `SceneFlow.gd` 추가
- Stage01/02/03 씬 경로 매핑
- 현재 스테이지 로드/재시작/다음 스테이지 이동 구현

완료 기준:

- 게임 실행 시 SceneFlow가 Stage01을 로드한다.
- 코드에서 `load_next_stage()`를 호출하면 Stage02로 넘어간다.
- `replay_stage()`가 현재 스테이지를 다시 로드한다.

### Step 2. 결과 요청 신호 추가

- EventBus에 `request_replay`, `request_next`, `request_menu` 추가
- SceneFlow가 해당 신호를 구독
- 임시 버튼 또는 테스트 코드로 신호가 동작하는지 확인

완료 기준:

- `EventBus.request_next.emit()` 시 다음 스테이지로 이동한다.
- `EventBus.request_replay.emit()` 시 현재 스테이지가 재시작된다.

### Step 3. StageDialog 분리

- `HUD`의 임시 `AcceptDialog` 의존을 줄인다.
- 결과 UI를 `StageDialog`로 분리한다.
- Clear에서는 Next/Replay/Menu 표시
- Failed에서는 Replay/Menu 표시

완료 기준:

- 스테이지 클리어 후 결과 UI가 표시된다.
- Next 버튼으로 다음 스테이지가 로드된다.
- Replay 버튼으로 현재 스테이지가 재시작된다.

### Step 4. StageRunner 결과 payload 정리

- ScoreSystem에서 saved/lost/in_transit/original_hp를 조회 가능하게 한다.
- StageRunner가 결과 payload를 생성한다.
- StageDialog는 문자열 하나가 아니라 결과 데이터를 받아 렌더링한다.

완료 기준:

- 결과 화면에 score 외에 saved/lost/original_hp가 표시된다.
- SaveData 도입 시 같은 payload를 재사용할 수 있다.

### Step 5. 실패 판정 보강

- AntSpawner의 `spawn_finished`를 StageRunner가 구독
- living ants count를 확인
- 더 이상 클리어 가능성이 없으면 `stage_failed("no_more_ants")` emit

완료 기준:

- 모든 개미가 사라졌고 클리어되지 않은 경우 시간 제한까지 기다리지 않고 실패한다.

### Step 6. ScoreSystem 수명 정리

- `ScoreSystem.stop()` 추가
- EventBus disconnect 처리
- StageRunner exit 시 정리

완료 기준:

- 스테이지를 여러 번 재시작해도 카운트가 중복 증가하지 않는다.

## 기존 계획과의 관계

이 제안은 기존 phase 문서를 직접 수정하지 않는다.

다만 현재 phase 목록상 `phase11-ui-stage-dialog`와 `phase12-ui-title-menu`에 이미 유사한 의도가 들어 있으므로, 다음 중 하나로 반영할 수 있다.

- 기존 phase 11/12 전에 "Game Flow Foundation" 선행 작업으로 삽입
- phase 11의 범위를 StageDialog뿐 아니라 최소 SceneFlow까지 포함하도록 해석
- phase 12의 title/menu는 유지하되, 그 전에 Main/SceneFlow/StageResult만 먼저 구현

개인적으로는 별도 선행 작업을 추천한다. 입력 체계를 더 확장하기 전에 게임 흐름의 중심축을 세우는 편이 이후 작업의 기준점이 된다.

## Game Studio 플러그인 활용 관점

현재 프로젝트는 Godot이므로 Game Studio 플러그인의 브라우저 런타임 도구가 직접 맞아떨어지지는 않는다. 하지만 다음 기준은 그대로 유용하다.

- 첫 화면에서 플레이 가능한가
- 플레이 세션이 명확히 시작/종료되는가
- 성공/실패가 즉시 이해되는가
- 실패 후 재시도 루프가 빠른가
- 성공 후 다음 도전으로 자연스럽게 이어지는가
- 입력, HUD, 결과 화면이 서로 같은 게임 상태를 바라보는가

이번 제안의 핵심은 이 기준을 Godot 구조에 맞게 옮기는 것이다.

## 최종 권고

다음 구현 작업의 초점은 입력 체계 확장보다 게임 플로우 기반을 먼저 세우는 것이 좋다.

우선순위:

1. `Main.tscn` + `SceneFlow.gd`
2. `EventBus` 진행 요청 신호
3. `StageDialog`
4. `StageResult` 또는 결과 Dictionary
5. 실패 판정 보강
6. `ScoreSystem` disconnect/lifecycle 정리

이 순서로 진행하면 현재의 스테이지 구현과 입력 구현을 버리지 않고, 그 위에 "게임으로 플레이되는 구조"를 얹을 수 있다.

## 개발 계획 수정 제안

이 섹션은 실제 `phases/mvp` 계획을 어떻게 바꾸면 좋을지에 대한 구체안이다. 현재 문서는 제안일 뿐이며, 아래 변경을 아직 실제 phase 파일에 반영하지는 않는다.

### 추천안: Phase 6 앞에 Game Flow Foundation을 삽입

가장 권장하는 방식은 현재 완료된 Phase 5와 예정된 Phase 6 사이에 새 선행 phase를 하나 넣는 것이다.

현재 흐름:

```text
Phase 5: input-action-foundation
Phase 6: input-pad-cursor
Phase 7: input-pause-step
Phase 8: ui-theme-assets
...
Phase 11: ui-stage-dialog
Phase 12: ui-title-menu
```

제안 흐름:

```text
Phase 5: input-action-foundation
Phase 6: game-flow-foundation
Phase 7: input-pad-cursor
Phase 8: input-pause-step
Phase 9: ui-theme-assets
...
Phase 12: ui-stage-dialog
Phase 13: ui-title-menu
```

이유:

- 입력 확장 전에 입력이 소비될 게임 상태와 씬 흐름을 먼저 세울 수 있다.
- `restart_stage`, `pause_toggle`, `request_next` 같은 액션의 목적지가 명확해진다.
- StageDialog와 Title/Menu phase가 과도하게 커지는 것을 막을 수 있다.
- 이후 phase 번호가 밀리는 불편은 있지만, 구조적으로는 가장 깨끗하다.

### 새 Phase 6 초안

파일명 제안:

```text
phases/mvp/phase06-game-flow-foundation.md
```

phase 이름:

```text
game-flow-foundation
```

목표:

```text
스테이지 직접 실행 구조를 벗어나 Main/SceneFlow가 플레이 세션을 소유하도록 한다.
Stage clear/fail 이후 Replay/Next/Menu 요청을 처리할 수 있는 최소 게임 루프를 만든다.
```

변경 대상:

```text
scenes/Main.tscn
scripts/core/SceneFlow.gd
scripts/core/GameManager.gd
scripts/core/EventBus.gd
scripts/core/StageRunner.gd
scripts/core/ScoreSystem.gd
project.godot
tests/GameFlowTest.gd 또는 tests/SceneFlowTest.gd
```

구현 범위:

- `project.godot`의 main scene을 `res://scenes/Main.tscn`으로 변경
- `Main.tscn`에 `SceneFlow` 배치
- `SceneFlow`가 Stage01/02/03 씬 경로를 관리
- 게임 시작 시 Stage01 로드
- `request_replay` 수신 시 현재 스테이지 재시작
- `request_next` 수신 시 다음 스테이지 로드
- 마지막 스테이지에서 `request_next`는 menu 또는 no-op fallback
- `EventBus`에 `request_replay`, `request_next`, `request_menu`, `request_stage_select` 추가
- `StageRunner`가 stage clear/fail 후 직접 씬 전환하지 않고 결과 신호만 emit
- `ScoreSystem.stop()` 추가 및 StageRunner 종료 시 disconnect

검증 기준:

- 게임 실행 시 `Main.tscn`을 통해 Stage01이 로드된다.
- `EventBus.request_next.emit()` 후 Stage02가 로드된다.
- `EventBus.request_replay.emit()` 후 같은 stage가 새로 로드된다.
- Stage01 clear 이후에도 이전 ScoreSystem 연결이 남아 중복 카운트하지 않는다.
- 기존 `Stage02HeadlessTest`, `Stage03HeadlessTest`는 직접 stage scene 실행 경로로 계속 통과한다.

비범위:

- 타이틀 화면
- 스테이지 선택 화면
- 저장 데이터
- 최종 디자인이 적용된 결과 모달
- 게임패드 가상 커서

### 기존 Phase 6 이후 번호 조정안

새 phase를 삽입한다면 기존 pending phase는 다음처럼 밀린다.

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

이 경우 `phases/mvp/status.json`, `phases/mvp/README.md`, `notion-phase-ids.json`도 함께 정리해야 한다.

### Phase 7 input-pad-cursor 수정 제안

기존 `input-pad-cursor`는 새 Game Flow 기반 위에서 진행한다.

수정할 목표:

```text
패드 커서 입력을 구현하되, 씬 전환/스테이지 재시작 후 cursor cache와 virtual cursor가 안전하게 초기화되는지 검증한다.
```

추가 검증:

- Stage01에서 커서를 움직인 뒤 request_next로 Stage02 전환
- 전환 직후 stale cursor payload가 skill assign에 사용되지 않음
- SceneFlow 전환 시 `InputRouter.clear_cursor_cache()` 호출 또는 동등한 자동 무효화 확인

### Phase 8 input-pause-step 수정 제안

기존 `input-pause-step`은 StageRunner 단독 기능이 아니라 SceneFlow/Stage state와 맞물려야 한다.

수정할 목표:

```text
StageRunner가 pause, step, speed, restart 입력을 처리하되, 결과 다이얼로그와 씬 전환 상태에서는 입력 충돌이 없게 한다.
```

구현 범위 보강:

- `pause_toggle`: 현재 stage simulation pause
- `step_frame`: pause 상태에서 1 physics frame 진행
- `speed_toggle`: stage simulation speed 변경
- `restart_stage`: `EventBus.request_replay.emit()`으로 위임
- 결과 화면 표시 중에는 pause/step/speed 무시 또는 dialog 우선 처리

추가 검증:

- pause 중 stage clear가 발생하면 StageDialog 또는 임시 결과 UI가 정상 표시
- restart 입력이 SceneFlow의 replay 경로를 탄다
- scene reload 후 pause 상태가 이전 stage에서 누수되지 않는다

### Phase 12 ui-stage-dialog 수정 제안

새 Game Flow Foundation이 들어가면 StageDialog phase의 범위는 줄어든다. 이 phase는 씬 전환 기반을 새로 만들지 않고, 이미 있는 request 신호와 SceneFlow를 사용해 결과 UI만 고도화한다.

수정할 목표:

```text
임시 결과 표시를 실제 StageDialog UI로 교체하고, Replay/Next/Menu 버튼이 기존 SceneFlow request 신호를 emit하도록 한다.
```

변경 대상:

```text
scenes/ui/StageDialog.tscn
scripts/ui/StageDialog.gd
scripts/ui/HUD.gd
scripts/core/StageRunner.gd
scripts/core/Scoring.gd
```

삭제하거나 줄일 범위:

- `SceneFlow.gd` 신규 생성은 Phase 6으로 이동
- `EventBus.request_*` 신규 정의도 Phase 6으로 이동
- `GameManager`의 기본 request wiring도 Phase 6으로 이동

이 phase의 핵심 산출물:

- 결과 모달 UI
- saved/lost/score/time 표시
- stars 계산
- Replay/Next/Menu 버튼
- 결과 중복 클릭 방지

### Phase 13 ui-title-menu 수정 제안

Title/Menu phase는 SceneFlow와 SaveData를 확장하는 역할로 두는 편이 좋다.

수정할 목표:

```text
이미 존재하는 SceneFlow에 Title, MainMenu, StageSelect, SaveData를 연결한다.
```

변경 대상:

```text
scenes/ui/TitleScene.tscn
scenes/ui/MainMenu.tscn
scenes/ui/StageSelect.tscn
scripts/ui/TitleScene.gd
scripts/ui/MainMenu.gd
scripts/ui/StageSelect.gd
scripts/core/SaveData.gd
scripts/core/SceneFlow.gd
data/menu_layout.tres
project.godot
```

범위 조정:

- `Main.tscn` 자체 도입은 Phase 6에서 이미 완료
- Stage01 자동 시작을 TitleScene 시작으로 변경
- StageSelect에서 `SceneFlow.load_stage(stage_id)` 호출
- SaveData는 StageDialog 결과 payload를 받아 기록

### 대안 A: 번호를 밀지 않고 Phase 6 내용을 바꾸기

phase 번호를 유지하고 싶다면 기존 `phase06-input-pad-cursor.md`를 `phase06-game-flow-foundation.md`로 교체하고, input-pad-cursor를 새 phase로 뒤에 추가한다.

장점:

- 지금 당장 다음 작업이 명확해진다.
- 번호 재배열의 부담이 비교적 작다.

단점:

- 기존 Notion phase ID와 이름이 꼬일 수 있다.
- 이미 공유된 phase06 의미가 바뀐다.

이 방식은 Notion/외부 추적과 강하게 연결되어 있지 않을 때만 추천한다.

### 대안 B: Phase 11을 앞당기기

`phase11-ui-stage-dialog`를 현재 다음 작업으로 앞당기고, 그 안에 SceneFlow를 포함하는 방식도 가능하다.

장점:

- 기존 문서에 이미 StageDialog/SceneFlow 의도가 있으므로 새 phase를 덜 만든다.

단점:

- UI phase가 구조 변경까지 떠안아 너무 커진다.
- input-pad-cursor, pause-step이 여전히 플로우 기반 없이 계획되어 있다.
- Title/Menu와 StageDialog 사이의 책임 경계가 흐려진다.

이 방식은 권장하지 않는다.

### 최종 추천

실제 계획 반영은 다음 순서가 가장 좋다.

1. `phase06-game-flow-foundation.md`를 새로 만든다.
2. 기존 pending phase 번호를 하나씩 뒤로 민다.
3. `status.json`의 phase 목록을 새 번호와 파일명으로 정렬한다.
4. `phase11-ui-stage-dialog` 내용을 새 번호 `phase12`에 맞게 줄이고, SceneFlow/EventBus request 생성 범위를 Phase 6으로 이동했다고 명시한다.
5. `phase12-ui-title-menu`를 새 번호 `phase13`으로 밀고, "SceneFlow 확장" phase로 재정의한다.
6. Notion 연동이 있다면 `notion-phase-ids.json`은 기존 ID를 보존하되, rename/update 기준으로 정리한다.

즉, 핵심은 "입력 확장 → UI 확장 → 메뉴" 전에 "게임 플로우 기반"을 끼워 넣는 것이다. 이 변경이 들어가면 이후 모든 phase가 어느 상태에서 동작해야 하는지 훨씬 분명해진다.
