# Phase 2 Plan: Stage 1 Vertical Slice (빌드 0.1)

## 목표 (1줄)
Stage 1을 스킬 0개로 풀 수 있도록 — 개미가 Home에서 자동 스폰 → 평지 보행 → Candy 픽업 + 180° 회전 → 0.78배 속도로 귀환 → Home 도착 시 Saved → Candy HP 소진 + in_transit=0 시점에 StageCompleteDialog 표시.

## 변경/추가 파일 목록

### Ant 시스템 (`scripts/ant/`)
- `Ant.gd` — `class_name Ant extends CharacterBody2D`. export: `walk_speed=60.0`, `gravity=900.0`, `carrying_speed_multiplier=0.78`, `spawn_grace_seconds=0.4`. 인스턴스 변수: `direction: int = 1`, `state_machine: AntStateMachine`, `has_been_carrying: bool = false`, `_grace_until: float`. 메서드: `is_carrying() -> bool`, `effective_speed() -> float`, `flip(): direction *= -1`.
- `AntStateMachine.gd` — `class_name AntStateMachine extends Node`. `current_state: AntState`, `ant: Ant`, `change_state(new_state)`, `update(delta)`. enter/exit 시 이전 상태 destroy 호출.
- `AntState.gd` — `class_name AntState extends RefCounted`. 베이스: `var ant: Ant`, `func enter()`, `func exit()`, `func update(delta: float)`. RefCounted라 GC 자동.
- `states/WalkerState.gd` — 진행 + 벽 충돌 시 flip + 절벽 끝에서 Faller 전이.
- `states/FallerState.gd` — 수평 속도 유지(또는 0) + 중력. 착지 시 Walker 복귀. 추락 거리 측정은 Phase 10 deferred.
- `states/CarryingState.gd` — Walker 동치 거동 + `effective_speed = walk_speed * 0.78`. enter()에서 ant.has_been_carrying = true.
- `states/SavedState.gd` — enter()에서 ant.queue_free(). visual은 그냥 사라짐.
- `states/DeadState.gd` — enter()에서 ant.queue_free(). carrying이었으면 EventBus.candy_piece_lost 발신은 Hazard 측 책임 (Phase 5). Phase 2에서는 그저 빈 셸.

### 씬: `scenes/entities/Ant.tscn`
```
Ant : CharacterBody2D                 (script: Ant.gd, layer=3, mask=1+2)
├── CollisionShape2D                   (RectangleShape2D 12x10)
├── Sprite : ColorRect                 (12x10, color=Color(0.2,0.1,0.05,1) 갈색)
└── StateMachine : AntStateMachine     (script: AntStateMachine.gd)
```
- Sprite를 ColorRect로 placeholder. position을 (-6, -10)으로 두어 origin이 발 밑.
- StateMachine 자식 노드 형태로 두고, Ant.gd `_ready()`에서 `state_machine = $StateMachine; state_machine.ant = self; state_machine.change_state(WalkerState.new())`.

### World 시스템 (`scripts/world/`)
- `Candy.gd` — `class_name Candy extends Area2D`. export: `hp: int = 10`. signal 핸들러 `_on_body_entered(body)`:
  ```
  if body is Ant and body.state_machine.current_state is WalkerState and not body.has_been_carrying:
      hp -= 1
      EventBus.candy_piece_picked.emit(hp)
      body.flip()
      body.state_machine.change_state(CarryingState.new())
      if hp <= 0:
          monitoring = false
          EventBus.candy_depleted.emit()
  ```
- `Home.gd` — `class_name Home extends Area2D`. export: `spawn_position_offset: Vector2 = Vector2(48, 0)`. signal 핸들러 (Codex HIGH 대응 — 2중 가드):
  ```
  if not body is Ant: return
  # 가드 1: 스폰 grace
  if Time.get_ticks_msec() / 1000.0 < body._grace_until: return
  # 가드 2: 한 번도 운반 안 한 fresh ant는 무시 (= 출발자, Home 위 통과 무방)
  var carrying := body.state_machine.current_state is CarryingState
  if not carrying and not body.has_been_carrying: return
  # 통과 = (a) 운반 중 귀환 또는 (b) 운반 후 빈손 귀환자(Phase 5+ 시나리오)
  EventBus.ant_saved.emit(body, carrying)
  body.state_machine.change_state(SavedState.new())
  ```
  - **가드 1**: 스폰 직후 0.4초간 Home 트리거 무시 (위치 겹침 방지).
  - **가드 2**: `has_been_carrying=false`인 fresh ant가 Home Area2D와 겹쳐도 Saved 안 됨. 운반자가 한 번이라도 Carrying 상태였으면 빈손 귀환도 Saved 처리(메모리 누수 방지) — 단 with_candy=false라 점수에는 미반영.
- `Terrain.gd` — `class_name Terrain extends Node2D`. 빈 셸. Phase 6에서 TileMap 래핑 채움.

### 씬
- `scenes/entities/Candy.tscn` — Area2D (layer=5, mask=3, monitoring=true) + CollisionShape2D RectangleShape2D 24x16 + ColorRect 24x16 노란색 (Color(1,0.9,0.2,1)).
- `scenes/entities/Home.tscn` — Area2D (layer=6, mask=3, monitoring=true) + CollisionShape2D RectangleShape2D 32x32 + ColorRect 32x32 갈색 (Color(0.4,0.25,0.1,1)).

### Core (`scripts/core/`)
- `StageData.gd` — `class_name StageData extends Resource`. export: id:int, display_name:String, scene:PackedScene, total_ants:int=10, candy_hp:int=10, time_limit_seconds:float=120.0, available_skills:Array[String]=[], skill_inventory:Dictionary={}, release_rate_initial:int=50, release_rate_min:int=1.
- `ScoreSystem.gd` — `class_name ScoreSystem extends RefCounted`. (Autoload 아님.) 변수 `original_hp`, `saved_pieces`, `in_transit_pieces`, `lost_pieces`, `candy: Candy`. 메서드: `start(candy, total_hp)`, `is_cleared() -> bool`, `score() -> float`, `_assert_invariant()`. 시그널 구독은 외부에서.
- `AntSpawner.gd` — `class_name AntSpawner extends Node`. export: `ant_scene: PackedScene`, `spawn_position: Vector2`, `total: int`, `release_rate: int = 50`. 내부 Timer 사용. interval = `lerp(2.0, 0.05, (rate-1)/98.0)`. 매 spawn 시 Ant 인스턴스 생성 + `_grace_until = Time.get_ticks_msec()/1000.0 + ant.spawn_grace_seconds` 설정 + 부모 씬에 add_child.
- `StageRunner.gd` — `class_name StageRunner extends Node`. export: `stage_data: StageData`, NodePath들 (candy_path, home_path, spawner_path, hud_path). _ready()에서 검증 + ScoreSystem 인스턴스 생성 + EventBus 구독 + AntSpawner 시작 + 시간 카운트다운 시작. clear/fail 다이얼로그 호출.

### UI
- `scripts/ui/HUD.gd` — `class_name HUD extends CanvasLayer`. Labels 5개를 NodePath로 export. `_ready()`에서 EventBus.candy_piece_picked / ant_saved / candy_piece_lost 구독. `update_time(t: float)`는 StageRunner가 직접 호출.
- `scenes/ui/HUD.tscn` — CanvasLayer + Control + VBoxContainer + Label×5 (Time / Out / Saved / Lost / Candy).
- `scenes/ui/StageCompleteDialog.tscn` — AcceptDialog + Label "Score: NN%". `popup_centered()`으로 호출.

### Stage 1
- `scenes/stages/Stage01.tscn` — 루트: `StageRunner : Node`. 자식:
  - `World : Node2D`
    - `Terrain : Node2D` (placeholder; ColorRect 큰 회색 사각형 1920x200을 화면 하단 평지로)
    - 정확히는 평지를 ColorRect 대신 StaticBody2D + CollisionShape2D + ColorRect로. layer=1, mask=0.
  - `Home` (인스턴스, position 좌측 (200, 880))
  - `Candy` (인스턴스, position 우측 (1700, 880))
  - `Spawner : AntSpawner` (spawn_position = Home.position + Vector2(48, -32) = (248, 848) — Home Area2D 32x32 외부 우측. 그대로 떨어져 평지 위로 안착)
  - `HUD` (인스턴스)
  - `Camera2D` (position (960, 540), zoom 1, limits)
- `data/stages/stage01.tres` — StageData. id=1, display_name="첫 외출", total_ants=10, candy_hp=10, time_limit=120.0, release_rate_initial=50.

### Tests (TDD Guard 우회 토큰)
- `scripts/hooks/.tdd_bypass` — Phase 2 동안만 존재. Phase 1과 동일 3중 가드 (.gitignore + exit gate + deferred 금지).
- `tests/.gitkeep`은 이미 있음. 이 phase는 실제 단위 테스트를 작성하지 않고, Phase 12(별도 후속) 또는 deferred로 미룬다.

## 씬 트리 — Stage01.tscn

```
StageRunner : Node                              (script: StageRunner.gd, stage_data=stage01.tres)
├── World : Node2D
│   ├── Ground : StaticBody2D                   (layer=1, mask=0)
│   │   ├── Sprite : ColorRect (1920x200, Color(0.3,0.25,0.2,1) 흙색)
│   │   └── CollisionShape2D (RectangleShape2D 1920x200)
│   ├── Home : Area2D                           (instance, position=(200, 880))
│   ├── Candy : Area2D                          (instance, position=(1700, 880), hp=10)
│   └── Camera2D (position=(960,540))
├── Spawner : AntSpawner                        (ant_scene=Ant.tscn, spawn_position=(248,848), total=10, release_rate=50)
├── HUD : CanvasLayer                           (instance)
└── _ScoreSystem : Node                         (no script — ScoreSystem is RefCounted, owned by StageRunner)
```

> Ground는 1920x200, position=(960, 980) → 화면 하단에 평지. y=880이 평지 윗면.

## 시그널 흐름

```
[AntSpawner.timeout]
  → AntSpawner._spawn_one() : Ant 인스턴스화, _grace_until 설정, World/Spawner에 add_child
                              → Ant._ready() → state_machine.change_state(WalkerState.new())

[Ant.body_entered Candy]
  → Candy._on_body_entered(ant)
    → ant.flip() + change_state(CarryingState.new())
    → EventBus.candy_piece_picked.emit(remaining_hp)
       → ScoreSystem._on_picked()  : in_transit += 1
       → HUD._on_picked()          : Label "Candy HP" + "In transit" 갱신
    → if hp == 0: EventBus.candy_depleted.emit()
       → StageRunner._on_depleted(): clear 조건 검사 트리거 등록 (이후 매 frame 체크)

[Ant.body_entered Home]
  → Home._on_body_entered(ant)
    → if grace 미경과: skip
    → carrying = ant.state_machine.current_state is CarryingState
    → EventBus.ant_saved.emit(ant, carrying)
       → ScoreSystem._on_saved(carrying):
           if carrying: saved += 1; in_transit -= 1
       → HUD._on_saved(): Label "Saved" 갱신
    → ant.state_machine.change_state(SavedState.new()) → ant.queue_free()

[StageRunner _process]
  → 매 frame: time_left -= delta
  → if ScoreSystem.is_cleared():
       EventBus.stage_cleared.emit(score)
       StageCompleteDialog.popup_centered()
  → if time_left <= 0 and not is_cleared():
       EventBus.stage_failed.emit("time_out")
       FailDialog 또는 StageCompleteDialog (실패 메시지)
```

## 핵심 결정

1. **`Ant`/`Candy`/`Home`은 `class_name` 등록**: EventBus 시그널 시그니처를 좁힐 수 있게 됨. `signal candy_piece_picked(remaining_hp: int)`는 그대로, 그러나 `signal ant_saved(ant: Node, with_candy: bool)` → Phase 2에서 `signal ant_saved(ant: Ant, with_candy: bool)`로 좁히기. EventBus.gd에 `class_name Ant`가 forward declared 되어야 하므로, Ant.gd가 EventBus보다 먼저 로드되어야 안전. Godot은 모든 class_name을 사전 등록하므로 OK. → **Phase 1 deferred 항목 해소**.
2. **ScoreSystem은 RefCounted**: Autoload 아님. StageRunner가 인스턴스화 + 시그널 구독. 스테이지 종료 시 자동 GC.
3. **운반자 사망 인터페이스만 노출** (Phase 5에서 발화): EventBus.candy_piece_lost는 선언만. ScoreSystem._on_lost()도 메서드 정의 + 구독 + 카운터 증가 로직만 마련. 발화는 없음.
4. **`has_been_carrying` 플래그**: 한 번이라도 운반한 ant는 다시 사탕 픽업 못함. Stage 1에선 의미 적지만, Phase 5+에서 운반자가 어떤 이유로 Walker 복귀 시 이중 픽업 차단의 안전망.
5. **스폰 grace period 0.4초**: Home 트리거 위에서 스폰 → 즉시 Home._on_body_entered 발화 → grace 체크로 무시. Ant._grace_until 사용.
6. **Walker 절벽 감지**: `is_on_floor()`가 false면 Faller로 전이. 추락거리 추적은 Phase 10에 (deferred).
7. **벽 충돌 처리**: `is_on_wall()` 시 `direction *= -1`. CharacterBody2D가 wall_min_slide_angle 기본값으로 좌우 벽 인식.
8. **AntSpawner interval 공식**: `interval = lerp(2.0, 0.05, (rate-1)/98.0)`. rate=50 → ~1초/마리. rate=99 → 0.05초/마리(Stage 1엔 과함). 단순한 선형. 후속 phase에서 튜닝.
9. **TileMap vs TileMapLayer**: ARCHITECTURE는 TileMap. Godot 4.6은 둘 다 지원. Phase 2에선 평지=StaticBody2D 단일로 처리하고, 실제 TileMap은 Phase 6 Basher에서 도입(deferred).
10. **StageCompleteDialog**: AcceptDialog 사용. confirmed 시그널 → `get_tree().reload_current_scene()` 또는 메뉴로(Phase 후반).

## 엣지 케이스 (필수, 6개)

1. **Walker 귀환 Candy 재픽업**: `has_been_carrying` 플래그 + Candy.gd의 가드 (`if body.state is WalkerState and not body.has_been_carrying`). 운반자가 어떤 이유로 Walker로 복귀(현재 phase는 없음)해도 사탕 다시 안 집음.
2. **스폰 직후 Home 즉시 Saved + Home 위 fresh ant 통과** (Codex HIGH): 2중 가드:
   - **a. grace**: 스폰 후 0.4초 동안 Home 트리거 무시 (Ant._grace_until).
   - **b. has_been_carrying 가드**: 한 번도 운반 안 한 fresh ant는 Home Area2D와 겹쳐도 Saved 안 됨 (Home.gd에서 `if not carrying and not body.has_been_carrying: return`).
   - **c. 스폰 위치 분리**: spawn_position을 Home 우측 +48px로 두어 Home Area2D 32x32와 물리적으로 비겹침. 가드 a/b가 실패해도 geometry에서 1차 차단.
3. **운반자 사망 인터페이스**: candy_piece_lost 시그널과 ScoreSystem._on_lost() 메서드는 phase 2에서 구현 + 구독, 발화는 phase 5(Hazard)에서. 인터페이스 미리 잡지 않으면 phase 5에 코어 침범.
4. **Candy hp=0 후 잔여 통과 ant**: Candy.monitoring=false 처리. 이후 Candy 위 통과 ant는 무시. ColorRect 색을 회색으로 변경하면 시각 피드백 (선택, 폴리싱).
5. **`is_cleared()` 트리거 누락 방지**: ScoreSystem.is_cleared()는 매 frame StageRunner에서 평가. 시그널 기반으로만 하면 마지막 ant_saved 직후 candy_depleted를 놓치는 경합 가능. 매 frame 평가가 단순하고 안전.
6. **시그널 중복 구독**: HUD.gd, ScoreSystem 모두 EventBus의 같은 시그널 구독. queue_free()된 노드의 핸들러가 호출되지 않도록 `is_instance_valid()` 가드 (Saved/Dead 후 ant 참조 안전 처리).
7. **Faller 즉시 Walker 복귀 깜박임**: Walker는 `is_on_floor()` 체크가 약간 지연됨(첫 frame). 첫 frame에 Faller로 전이되었다가 다음 frame Walker 복귀하는 깜박임 가능. → enter() 직후 한 frame은 무조건 update 진행, 그 다음 frame부터 floor 체크.
8. **direction의 0 가능성**: 초기값 `direction: int = 1`. 어떤 경로로도 0이 되면 ant 정지. flip은 `*= -1`이라 안전.

## 검증 시나리오 (Godot 에디터)

### A. Headless smoke (자동, 5초 quit)
```powershell
$godot --headless --path . --quit-after 600 res://scenes/stages/Stage01.tscn 2>&1 | Tee-Object headless.log
```
기대 출력:
- `[GameManager] ready` (Phase 1)
- `[StageRunner] starting Stage 1` (새 로그)
- `[ScoreSystem] start total_hp=10` (새 로그)
- 5초 동안 ant_saved 발화 로그 다수
- 종료 시 `[ScoreSystem] cleared score=1.0` 또는 진행 중 단계
- `SCRIPT ERROR` 0건

### A2. Home 즉시 Saved 회귀 가드 (Codex HIGH 대응)
1. headless 1초 quit으로 짧게 실행 → 첫 ant 스폰 직후 Home 위에 있더라도 Saved 발화하지 않아야 함.
2. 검증 단언:
   - 1초 동안 `ant_saved` 시그널 발화 0건 (Candy까지 도달할 시간이 없음).
   - 1초 동안 `candy_piece_picked` 시그널 발화 0건 (1초 내 Candy 도달 불가).
3. 1초 시점에서 ScoreSystem 카운터: saved=0, in_transit=0, lost=0.
4. 만약 이 검증에서 saved>0이 나오면 가드 a/b/c 중 어느 하나가 실패한 것 → 즉시 plan 재검토.

### B. 에디터 플레이 (사용자 수동)
1. F5 → Stage01 진입.
2. ant가 Home에서 1초 간격으로 출현.
3. ant가 평지를 우측으로 보행 → Candy 도달 → 색 노란→연노란 변화 + ant 색 변화(선택, 폴리싱) + 180° 회전.
4. ant가 좌측으로 0.78배 속도 귀환.
5. Home 도착 시 ant 사라짐 + HUD Saved +1.
6. 10번째 ant 귀환 시 Candy HP=0 + in_transit=0 → StageCompleteDialog "Score 100%".
7. **§5.6 4단계 점검**: Candy 위로 ant가 처음 지나갈 때 _on_body_entered 발화? Output에 `[Candy] picked by ant#xxx hp=9` 같은 로그 확인.
8. 시간 초과 테스트: stage_data.time_limit_seconds를 5.0으로 임시 변경 후 F5. 5초 내 클리어 못하면 stage_failed 다이얼로그.

### C. Exit gate (`.tdd_bypass` 제거 + Phase 1과 동일 패턴)
```bash
rm -f scripts/hooks/.tdd_bypass
test ! -e scripts/hooks/.tdd_bypass && echo "BYPASS_REMOVED"
git status --porcelain scripts/hooks/.tdd_bypass    # 빈 출력
```

## 비포함 (다음 Phase)
- 스킬 시스템 활성화 (Phase 3 Builder부터)
- WorkerState (Phase 3)
- Hazard / 운반자 사망 발화 (Phase 5)
- TileMap 동적 파괴 (Phase 6 Basher)
- 추락거리 측정 → Floater splat (Phase 10)
- 단위 테스트 (deferred — Phase 12 신설 또는 phase별 추가)

## 리스크
- **씬 데이터 작성량 큼**: Ant.tscn / Candy.tscn / Home.tscn / HUD.tscn / StageCompleteDialog.tscn / Stage01.tscn 6종을 텍스트로 작성. 각 .tscn은 Godot이 자동 생성하는 형식을 따라야 함. 잘못된 RID/UID로 import 실패 가능 → 가능하면 최소 형태로 작성하고 import 시 Godot이 자동 채우도록 둠.
- **물리 충돌 마스크**: Ant mask=Layer 1+2 (Terrain), Candy/Home mask=Layer 3 (Ant). 한 군데라도 잘못되면 트리거 발화 안 함 → §5.6 4단계 점검을 검증 시나리오 A의 headless 로그로 확인 가능.
- **상태 전이 race**: ant_saved 발화 직후 Saved.enter() → queue_free()가 같은 frame에 일어나면 EventBus 시그널 핸들러가 invalid instance 참조. → `is_instance_valid()` 가드 또는 시그널 발화를 queue_free 직전으로 강제.
- **CRLF/LF**: Phase 1처럼 git이 CRLF 변환 경고 출력. 동작에 영향 없음.
