# Phase 4 Plan: Stage 3 + Blocker 스킬 (빌드 0.3)

## 목표 (1줄)
Blocker 스킬을 도입해 Stage 3에서 양방향 release되는 개미들의 흐름을 단일 방향으로 funnel — Stage 1/2 회귀 없음, 운반 정보(`has_candy`/`has_been_carrying`) 보존 불변식 유지.

## 변경/추가 파일

### 신규 — Skill (`scripts/skills/`)
- `BlockerSkill.gd` — `class_name BlockerSkill extends Skill`, `const ID := "blocker"`.
  - `can_apply(ant)` — **단일 진실 출처(SoT). Codex HIGH(phase04-review §HIGH) 대응**:
    1. `ant == null or ant.state_machine == null` → false
    2. `not (ant.state_machine.current_state is WalkerState)` → false (CarryingState/FallerState/WorkerState/Saved/Dead 모두 거부)
    3. `not ant.is_on_floor()` → false
    4. `ant.has_candy == true` → false (**운반 중 Blocker화 = in_transit 영구 잔존 → 클리어 데드락. Builder와 달리 Blocker는 외부 해제 없이 영구 정지하므로 carrier-blocker 결합 절대 불가.**)
    5. 모두 통과 시 true
  - `apply(ant)`: `ant.state_machine.change_state(WorkerState.new("blocker"))`.
  - **불변식**: `apply` 호출 전 `can_apply` true 검증된 상태이므로 `has_candy=false`/`state==WalkerState` 보장.

### 수정 — Worker state (`scripts/ant/states/WorkerState.gd`)
- `_init(work_type: String = "builder")` — 인자 시그니처 그대로 유지.
- `enter()` 분기:
  - `_work_type == "builder"` → 기존 로직 (12 tile 다리 build).
  - `_work_type == "blocker"` → `_enter_blocker(a)`:
    - `a.velocity = Vector2.ZERO`.
    - `a.set_blocker_active(true)` 호출 (Ant.gd 신규 메서드).
    - **`has_candy`/`has_been_carrying` 절대 변경 안 함** (Codex HIGH #4 패턴 가드 재사용).
  - 기타 work_type → 기존 동작 유지(`_aborted = true`, Walker 복귀).
- `update(delta)`:
  - 첫 분기에 `_work_type == "blocker"` 체크 → `_update_blocker(a, delta)` 호출 후 즉시 return.
  - 그 외 (builder/abort) 기존 로직.
- `_update_blocker(a, delta)`:
  - 중력 적용 + `a.velocity.x = 0` + `move_and_slide()` (지면 유지).
  - `a.is_on_floor() == false` → `a.set_blocker_active(false)` + `change_state(FallerState.new())`.
  - 그 외엔 영구 정지 (자연 해제 없음 — 사망/외부 스킬로만 해제, 본 phase 미구현).
- `exit()` 신설:
  - `_work_type == "blocker"`이면 `a.set_blocker_active(false)` 멱등 호출 (FallerState/SavedState/DeadState 전이 시 안전 정리).

### 수정 — Ant 본체 (`scripts/ant/Ant.gd`, `scenes/entities/Ant.tscn`)
- `Ant.gd`:
  - `signal bumped_blocker(direction: int)` 추가 (관측용 — 본 phase에서 점수/UI에는 미사용).
  - `set_blocker_active(active: bool)` — 멱등:
    1. `_blocker_hitbox` 노드 lookup (`get_node_or_null("BlockerHitbox")`); null이면 push_error 후 return.
    2. `_blocker_hitbox.monitoring = active`.
    3. `CollisionShape2D` 자식의 `disabled = not active`.
    4. active=true이고 `body_entered` 미연결이면 `_on_blocker_body_entered` 연결.
  - `_on_blocker_body_entered(body: Node2D)`:
    - body == self → return (Area2D가 자기 부모를 감지하는 케이스 차단).
    - `body is Ant`가 아니면 return.
    - `var other: Ant = body as Ant`.
    - `other.state_machine.current_state is WorkerState` → return (Blocker끼리 무한 반전 차단 — 정지 상태 ant는 안 건드림).
    - `other` 위치 기반 direction 결정: `var rel_x: float = other.global_position.x - global_position.x`.
    - `other.direction = 1 if rel_x >= 0.0 else -1` (블로커로부터 멀어지는 방향으로 강제 — flip()이 아니라 절대 설정. double-bump 안전).
    - `bumped_blocker.emit(other.direction)`.
- `Ant.tscn`:
  - 자식 `BlockerHitbox: Area2D` 추가.
    - `collision_layer = 0` (다른 Area2D에 감지될 필요 없음).
    - `collision_mask = 4` (Ant Layer 3 = bit 3 = value 4 감지).
    - `monitoring = false` (기본 비활성).
    - `monitorable = false`.
  - `BlockerHitbox/CollisionShape2D` — RectangleShape2D 20x16 (ant 본체 12x10보다 좌우 +4px씩 넓혀 통과 ant 안정 감지). 초기 `disabled = true`.

### 수정 — SkillRegistry (`scripts/core/SkillRegistry.gd`)
- `SKILL_SCRIPTS` 배열에 `preload("res://scripts/skills/BlockerSkill.gd")` 1줄 추가 (CLAUDE.md CRITICAL 정책 준수, `_static_init` 자기등록 금지).

### 수정 — AntSpawner (`scripts/core/AntSpawner.gd`)
- export `spawn_direction: int = 1` (기본값 stages 1·2 호환 — 회귀 위험 0).
- export `spawn_direction_alternate: bool = false` — true 시 **0-based** 짝수 인덱스 ant는 `spawn_direction`, 홀수는 `-spawn_direction`.
- `_spawn_one()` 시퀀스 — **Codex MEDIUM(phase04-review §MEDIUM) 대응**: `_spawned` 증가 **전**에 zero-based index 캡처:
  ```gdscript
  var ant: Ant = ant_scene.instantiate() as Ant
  if ant == null:
      push_error(...); return
  ant.global_position = spawn_position
  var spawn_index: int = _spawned             # zero-based; 첫 ant=0
  var dir: int = spawn_direction
  if spawn_direction_alternate and (spawn_index % 2 == 1):
      dir = -spawn_direction
  ant.direction = dir                         # add_child 전 설정 → _ready의 WalkerState가 직후 사용
  _spawn_parent.add_child(ant)
  _spawned += 1
  ```
  - **명세**: `spawn_direction_alternate=true`, `spawn_direction=1`일 때 — index 0 → +1, index 1 → -1, index 2 → +1, index 3 → -1, ...
  - **검증**: 통합 테스트(§D) driver가 첫 4개 ant의 `direction`을 추적해 `[+1, -1, +1, -1]` 패턴 assert. 로그 검사가 아니라 코드로 강제.

### 신규 — Stage 3 (`scenes/stages/`, `data/stages/`)
- `Stage03.tscn` — 노드 구조는 Stage02와 동일 (StageRunner / World / Spawner / HUD / SkillToolbar).
  - **Geometry**:
    - `MainPlatform`: StaticBody2D, RectangleShape2D 1220×216, position=(1210, 988). Top edge y=880. x range 600..1820.
    - `Home`: position=(1700, 880). Area2D 32×32.
    - `Candy`: position=(700, 880). hp=10.
    - `Spawner`: spawn_position=(1652, 875), `spawn_direction=1`, `spawn_direction_alternate=true`, total=10, release_rate=30.
    - **죽음 지대**: 좌측 cliff x=600, 우측 cliff x=1820. Faller가 platform 아래로 떨어지면 floor 부재 → 영원히 추락 (Phase 5에서 Hazard 도입 시 명시적 lost 처리).
- `data/stages/stage03.tres`:
  ```
  id = 3
  display_name = "양갈래"
  total_ants = 10
  candy_hp = 10
  time_limit_seconds = 200.0
  available_skills = ["builder", "blocker"]
  skill_inventory = { "builder": 0, "blocker": 2 }
  release_rate_initial = 30
  release_rate_min = 1
  ```
  > Builder는 등록만 (count=0). Stage 3는 Blocker만 사용.

### 신규 — 자동화 테스트 (Phase 3 패턴 답습)
- `tests/Stage03HeadlessTest.gd` — 핵심 driver:
  - 첫 +1-direction ant가 x ≥ 1750에 도달하면 BlockerSkill 자동 적용 (UI 우회).
  - `EventBus.stage_cleared` 수신 시 score >= 0.85 → quit(0) PASS.
  - `EventBus.stage_failed` 또는 score < 0.85 → quit(1) FAIL.
  - 280초 시뮬 안전망 (= 16800 frames @ --fixed-fps 60).
- `tests/Stage03HeadlessTest.tscn` — 루트 Node + Stage03 instance + driver script.
- per-file TDD Guard 스텁: `tests/test_BlockerSkill.gd` 신규 (3줄).
- WorkerState/Ant/SkillRegistry/AntSpawner는 기존 stub 재사용 (변경만 해도 TDD Guard는 파일 존재 여부만 확인).

## 씬 트리 — Stage03.tscn (요약)

```
StageRunner : Node                  (script: StageRunner.gd, stage_data=stage03.tres)
├── World : Node2D
│   ├── MainPlatform : StaticBody2D  (RectangleShape2D 1220x216 @ (1210, 988))
│   ├── Terrain : Node2D             (Phase 4에서는 빈 셸 — Builder 미사용)
│   ├── Home : Area2D                (@ (1700, 880), spawn offset (-48, -32))
│   ├── Candy : Area2D               (@ (700, 880), hp=10)
│   └── Camera2D                     (@ (1210, 540), 카메라 가운데에)
├── Spawner : Node                   (spawn_position=(1652, 875), spawn_direction=1, spawn_direction_alternate=true)
├── HUD : CanvasLayer
└── SkillToolbar : CanvasLayer       (stage_data=stage03.tres → buttons: "builder × 0" disabled, "blocker × 2")
```

> Home의 spawn_position_offset 기본값은 `Vector2(48, -32)`이지만 Stage 3는 spawn을 Home **왼쪽**(직접 spawn_position 지정)으로 두기 위해 Spawner.spawn_position을 직접 설정 — StageRunner._ready의 fallback `_spawner.spawn_position == Vector2.ZERO` 분기는 발동 안 됨.

## 씬 트리 — Ant.tscn (Phase 4 수정분)

```
Ant : CharacterBody2D                 (layer=4, mask=3)
├── CollisionShape2D                   (RectangleShape2D 12x10)
├── Sprite : Polygon2D                 (12x10 갈색)
├── BlockerHitbox : Area2D             (NEW, layer=0, mask=4, monitoring=false)
│   └── CollisionShape2D                (RectangleShape2D 20x16, disabled=true)
└── StateMachine : AntStateMachine
```

## 시그널 흐름 (Phase 4 신규)

```
[SkillToolbar.Button "blocker × N" 클릭]
  → SkillToolbar._pending_skill_id = "blocker"
[좌클릭 → 가장 가까운 ant]
  → SkillRegistry.get_skill("blocker").new() = BlockerSkill 인스턴스
  → BlockerSkill.can_apply(ant): Walker/Carrying + on_floor 체크
  → BlockerSkill.apply(ant)
    → ant.state_machine.change_state(WorkerState.new("blocker"))
       → WorkerState.enter() : _work_type="blocker" → _enter_blocker(a)
         → a.velocity = Vector2.ZERO
         → a.set_blocker_active(true)
            → BlockerHitbox.monitoring = true
            → BlockerHitbox.body_entered ↔ Ant._on_blocker_body_entered

[다른 ant body가 BlockerHitbox 진입]
  → Ant._on_blocker_body_entered(other)
    → other가 자기 자신 / non-Ant / WorkerState ant이면 무시
    → other.direction = sign(rel_x)  (절대 설정, flip이 아님)
    → emit bumped_blocker(other.direction)

[Blocker가 절벽으로 추락]
  → WorkerState._update_blocker: is_on_floor()==false
    → set_blocker_active(false)
    → change_state(FallerState.new())
       → WorkerState.exit() : _work_type="blocker"이면 set_blocker_active(false) 멱등 재호출
```

EventBus 시그널 추가 없음 (`bumped_blocker`는 Ant 인스턴스 시그널 — observability 용, 점수 영향 없음).

## 핵심 결정

1. **방향을 flip이 아닌 절대 설정** — `other.direction = sign(rel_x)`로 항상 블로커에서 멀어지게. body_entered가 같은 ant에 대해 한 frame 내 2회 발화하더라도 결과 동일. double-bump 무한 루프 차단의 본질적 가드.
2. **WorkerState에 분기 추가** — Phase 3에서 `_init(work_type: String)`로 인터페이스만 잡혀있던 곳을 활성화. 새 work_type 추가 비용 = `_enter_<type>` + `_update_<type>` 2개 함수.
3. **운반 정보 보존 정책** — WorkerState("blocker")는 `has_candy`/`has_been_carrying`을 절대 건드리지 않음. **Carrying 상태 ant Blocker 적용은 `can_apply` 단일 진실 출처에서 거부**(§신규 Skill BlockerSkill.can_apply 5단 체크). 이유: Blocker는 외부 해제 없이 영구 정지 → 운반자 Blocker화 시 in_transit 영구 잔존 → 클리어 데드락. Lemmings 원작도 carrier+blocker 동시 불가.
4. **Spawner 양방향 옵션** — `spawn_direction_alternate`로 짝/홀 인덱스 분기. Stage 1·2의 default(false)는 변경 없음 → 회귀 0. Stage 3에서 Blocker 필요성을 토폴로지로 강제하기 위한 최소 추가 (≤10 LOC).
5. **Blocker 자체는 영구 정지** — Phase 4 범위에서는 외부 해제 메커니즘 미구현. cliff fall로만 자연 해제. Lemmings 원작에서도 Blocker는 사망 또는 nuke로만 해제.
6. **BlockerHitbox 크기 20×16** — ant 본체 12×10보다 +4/+3px씩 확장. 양 방향 ant가 16px/frame 이하 속도면 1 frame 누락 없이 감지. (현재 walker 60 px/s × 1/60 = 1px/frame, 안전.)
7. **stage03.tres에 builder × 0 명시 등록** — `available_skills` validate를 통과시키되 인벤토리 0 → 버튼 disabled. SkillToolbar 정책 점검 (count=0 시 button.disabled=true) 그대로 적용. 이는 후속 phase에서 Builder+Blocker 복합 사용 stage 도입 전 인터페이스 검증.

## 엣지 케이스 (필수, 7개)

1. **Blocker 적용 시 Faller** — `can_apply`가 false (`is_on_floor()` 가드) → 인벤토리 차감 안 됨, 모드 exit. Phase 3 Builder 패턴 동등.
2. **Blocker 적용 시 Carrying / has_candy=true** — `can_apply`의 단일 진실 출처에서 두 겹으로 거부: (a) `current_state is WalkerState`만 통과 → CarryingState 거부, (b) `has_candy=false`만 통과 → Faller→Walker 잠시 빠진 운반자 거부. 인벤토리 차감 0, 모드 즉시 exit. 통합 테스트 §D-2에서 carrying ant 대상 시도 시 false + 인벤토리 보존 자동 검증.
3. **Blocker 자기 자신 영역 진입** — `body == self` 체크로 무시. `monitorable=false`이므로 다른 BlockerHitbox에 감지되지도 않음.
4. **Blocker끼리 마주봄** — 두 정지 ant의 BlockerHitbox가 겹쳐도 둘 다 `current_state is WorkerState`라 핸들러가 무시. 무한 루프 차단.
5. **Blocker가 절벽 끝에 서면** — `_update_blocker`가 `is_on_floor()` 검사 → false 시 FallerState 전이. exit() 멱등 호출로 BlockerHitbox 비활성. 추락 후 floor 없으면 영원히 Faller (Phase 5 Hazard에서 명시적 lost 처리 예정).
6. **Carrying 운반 ant가 Blocker에 부딪힘** — 핸들러가 direction만 절대 설정. CarryingState 유지, has_candy=true 유지, effective_speed=0.78× 유지. 다음 update에서 `velocity.x = direction * effective_speed`로 새 방향 진행. 운반 정보 보존 가드 그대로 작동.
7. **WorkerState("blocker")가 SavedState/DeadState로 직접 전이** — 본 phase에서는 발생 경로 없음 (Saved는 Carrying→Home 트리거에서만, Dead는 Hazard에서만). 그러나 미래 phase 대비 `WorkerState.exit()`이 멱등 `set_blocker_active(false)`로 정리 — 어떤 경로로 빠져나가든 BlockerHitbox 항상 비활성.

## 검증 시나리오

### A. Stage 1 회귀 (필수)
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 4500 res://scenes/stages/Stage01.tscn 2>&1 | Tee-Object stage1-regression.log
```
기대: `cleared score=1.0`, errors 0건, picked 10건, saved 10건, **`spawn_direction_alternate=false` 기본값으로 모든 ant direction=1**.

### B. Stage 2 회귀 (필수)
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 12000 res://tests/Stage02HeadlessTest.tscn 2>&1 | Tee-Object stage2-regression.log
```
기대: `[Phase3Test] PASS`, exit 0, score >= 0.6.

### C. Stage 3 — 스킬 미사용 → 절반 손실 보장
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 16800 res://scenes/stages/Stage03.tscn 2>&1 | Tee-Object stage3-noskill.log
```
기대:
- 280초 시뮬, `picked` ≈ 5건 (홀수 인덱스 -1 ant만 candy 도달).
- 첫 ant 출력 `direction=`이 -1인지 확인 (`spawn_direction_alternate` 검증 — _spawned는 +1 후 1이므로 첫 ant=홀수 인덱스).
- `[StageRunner] failed reason=time_out` 또는 `cleared score≈0.5` (5명 saved).
- errors 0건.

### D. Stage 3 — Blocker 자동 적용 통합 테스트 (필수)
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 16800 res://tests/Stage03HeadlessTest.tscn 2>&1 | Tee-Object stage3-blocker-auto.log
```
driver는 단일 시나리오 안에 **세 가지 코드 단계 assertion**을 직렬로 수행:

**§D-1 (alternation 패턴 강제)** — Codex MEDIUM 대응:
- driver가 첫 4개 ant의 `direction` 값을 spawn 직후(첫 frame) 캡처.
- 기대 패턴 `[+1, -1, +1, -1]`. 불일치 시 즉시 `print("FAIL alternation=", arr); quit(1)`.
- 로그 검사가 아니라 in-process assert.

**§D-2 (carrying ant Blocker 거부)** — Codex HIGH 대응:
- candy를 픽업한 첫 carrying ant(`has_candy=true`)에 대해 `BlockerSkill.new().can_apply(ant)` 호출.
- 기대 결과: `false` 반환. 만약 true면 `quit(1) FAIL`.
- 추가 검증: `inventory["blocker"]` 사전/사후 값 동일 (직접 호출이라 SkillToolbar 차감 경로 거치지 않음 — can_apply 거부 의미만 확인).

**§D-3 (정상 Blocker 적용 → clear)**:
- 첫 +1-direction ant가 x ≥ 1750에 도달하면 `BlockerSkill.new().apply(ant)` 자동 호출 (UI 우회).
- `EventBus.stage_cleared` 수신 시 `score >= 0.85` → `quit(0) PASS`.
- `EventBus.stage_failed` 또는 score 미달 → `quit(1) FAIL`.

종합 기대:
- `[Phase4Test] PASS`, exit 0.
- `[StageRunner] cleared score≈1.0` (10/10 saved) 또는 ≥ 0.85.
- `SCRIPT ERROR` 0건, `EventBus.stage_failed` 발화 0건.
- 통합 검증 항목:
  - SkillRegistry.validate_stage(stage03) — `[StageRunner] SkillRegistry errors:` 부재
  - BlockerSkill.can_apply 동작 — Walker + on_floor + has_candy=false에서만 true
  - WorkerState("blocker") 진입 — `_enter_blocker` 호출 확인
  - BlockerHitbox monitoring=true 활성 — body_entered 핸들러 발화
  - +1-direction ants 모두 candy 경유 후 Home으로 saved

### E. TDD Guard 통과
```powershell
if (Test-Path scripts/hooks/.tdd_bypass) { throw "FAIL: bypass present" }
@("BlockerSkill") | ForEach-Object {
  if (-not (Test-Path "tests/test_$_.gd")) { throw "FAIL: tests/test_$_.gd missing" }
}
```

### F. (수동, 선택) 에디터 플레이
1. project.godot main_scene 임시 변경: `res://scenes/stages/Stage03.tscn`.
2. F5. SkillToolbar 좌하단에 "builder × 0 (disabled)", "blocker × 2".
3. blocker 클릭 → 첫 +1 ant(spawn 직후 우측 이동) 우상단 위치에서 click → 정지.
4. 우측 cliff 직전(~x=1750)에 blocker 잘 잡혔는지 확인. 후속 ants flip → 좌행 → candy → 귀환 → saved.

## 비포함 (deferred / 후속 phase)

| 항목 | 처리 |
|------|------|
| Hazard 시스템 (cliff 추락 시 명시적 lost) | Phase 5 stage4-hazard-water |
| Blocker 외부 해제 (예: Bomber 적용으로 blocker→bomber) | Phase 11 stage10-bomber-polish |
| Blocker 시각적 인디케이터 (좌우 화살표 표시) | Phase 11 폴리싱 |
| Spawner의 spawn_direction을 모든 stage에 명시 | wontfix — default=1 호환성 충분 |
| Blocker가 운반 ant 통과 시 운반 정보 보존 통합 테스트 | Phase 5 Hazard 도입 후 강화 검토 (현재는 핸들러 설계 가드로 차단) |
| `bumped_blocker` 시그널을 EventBus로 격상 | YAGNI — 점수/UI에 미사용 |
| 운반 중 Blocker 적용 가능화 (현재 can_apply 거부) | wontfix — Lemmings 원작도 carrier+blocker 동시 불가, 데드락 위험 |

## 리스크

- **AntSpawner `_spawned` 인덱싱 오프셋** — Codex MEDIUM에서 사전 차단. 본 plan에서는 zero-based `spawn_index = _spawned` 캡처 후 `_spawned += 1`로 명세 확정. 통합 테스트 §D-1이 첫 4개 ant direction 패턴을 코드로 assert해 회귀 차단.
- **BlockerHitbox vs Home/Candy 동시 트리거**: BlockerHitbox(layer=0, mask=4)는 Ant만 감지. Home(layer=32)/Candy(layer=16)와 layer 충돌 없음. 검증 시 추가 trigger 발화 없는지 확인.
- **Stage03 timing — Blocker 적용 타이밍**: 첫 +1 ant가 x=1750에 도달하기 전(약 t=3.0s)에 driver가 Blocker를 적용해야 함. 너무 늦으면 ant가 x=1820 cliff에 도달하기 전 BlockerSkill.can_apply의 `is_on_floor()` 통과 + 위치 안전구간(1740..1810) 확인.
- **Carrying ant가 Home(1700) 직전에 Blocker(≈1750)를 통과하는가?**: carrying 방향=+1로 700→1700 이동. Home Area2D 32x32 (x=1684..1716) 진입 시 saved → state 변경 → free. Blocker hitbox(x≈1740..1760) 미도달. 검증 §D에서 carrying 통과 시 spurious flip 없는지 확인.
- **Blocker가 spawn 직후 ant에 트리거**: spawn_position=(1652, 875), Blocker가 적용된 ant는 그 시점 위치(약 1750). 신규 spawn ants(1652)는 Blocker(1750)와 100px 거리, 즉시 충돌 없음 — Walker가 right 방향 이동 후 1.6s 뒤 도달.
- **WorkerState.exit() 신설로 Phase 3 builder 동작 영향**: Builder의 exit()는 빈 함수 → 변경 영향 0. 검증 §B(Stage 2 회귀)로 확인.
