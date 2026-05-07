# CandyAnts — 아키텍처 문서

> **상태**: v2 (2026-05-07) — Codex 어드버서리얼 리뷰 반영
> **연관 문서**: `DESIGN_CandyAnts.json` (설계), `REFERENCE_Lemmings.json` (원작 역기획)
> **렌더링 모드**: **2D side-view** (확정)
> **엔진**: Godot 4.6, GDScript
>
> **v2 변경사항**:
> - §4.2 스킬 등록을 명시적 preload 패턴으로 교체 (`_static_init` 자기등록 폐기)
> - §4.5 ScoreSystem 신설 — 사탕 조각 4-카운터 수명 추적 + 클리어/실패 술어 명시
> - §4.3 EventBus에 `candy_piece_picked` / `candy_piece_lost` 시그널 추가
> - §5.5 물리 충돌 마스크 설정 정정 (Ant mask에서 Area2D 레이어 제거)
> - §5.6 Area2D 트리거 계약 신설 — 엔티티별 layer/mask/handler 명시

---

## 1. 설계 원칙

빌드 누적형 개발 방식을 지원하기 위한 3가지 패턴:

1. **Vertical Slice** — Stage 1을 최소 시스템으로 End-to-End 완성, 이후 시스템을 확장
2. **Plugin/Registry** — 스킬, hazard가 자기 등록 → 새 콘텐츠 추가 시 코어 미변경
3. **Data-Driven Stage** — 스테이지 = `.tres` 데이터 + `.tscn` 레이아웃 → 스테이지 추가에 코드 수정 0

**누적 원칙**: 각 빌드는 이전 빌드를 깨지 않은 상태에서 새 시스템만 추가. 회귀 테스트 = 이전 스테이지 재클리어.

---

## 2. 시스템 계층

```
[Autoloads]
  ├─ GameManager      진행 상태 (잠금 해제, 완료, 점수 영구 저장)
  ├─ EventBus         signals 허브 (시스템 간 디커플링)
  └─ SkillRegistry    스킬 자기 등록 + ID 조회

[StageRunner]         한 스테이지 인스턴스의 런타임 오케스트레이터
  ├─ AntSpawner       Release Rate에 따라 스폰
  ├─ Candy            HP 자원
  ├─ Home             진입구 + 도착지 (동일 노드)
  ├─ Terrain          TileMap 기반, 파괴 가능/불가
  ├─ Hazards[]
  ├─ AvailableSkills[]    StageData에서 주입
  └─ ScoreSystem      조각 카운트, 클리어 판정

[Ant 인스턴스]         CharacterBody2D
  ├─ AntStateMachine
  │    └─ Walker / Faller / Carrying / Worker / Saved / Dead
  └─ SkillSlot        부여된 스킬의 활성 인스턴스
```

---

## 3. 폴더 구조

```
CandyAnts/
├── project.godot
├── scenes/
│   ├── Main.tscn                 # 셸 (메뉴, 스테이지 라우팅)
│   ├── stages/
│   │   ├── Stage01.tscn
│   │   └── ...
│   ├── entities/
│   │   ├── Ant.tscn
│   │   ├── Candy.tscn
│   │   ├── Home.tscn
│   │   └── hazards/
│   └── ui/
│       ├── HUD.tscn
│       ├── SkillToolbar.tscn
│       └── StageCompleteDialog.tscn
├── scripts/
│   ├── core/
│   │   ├── GameManager.gd        # Autoload
│   │   ├── EventBus.gd           # Autoload
│   │   ├── SkillRegistry.gd      # Autoload
│   │   ├── StageRunner.gd
│   │   ├── ScoreSystem.gd
│   │   └── AntSpawner.gd
│   ├── ant/
│   │   ├── Ant.gd                # CharacterBody2D 컴포지션 루트
│   │   ├── AntStateMachine.gd
│   │   ├── AntState.gd           # 베이스
│   │   └── states/
│   │       ├── WalkerState.gd
│   │       ├── FallerState.gd
│   │       ├── CarryingState.gd
│   │       ├── WorkerState.gd
│   │       ├── SavedState.gd
│   │       └── DeadState.gd
│   ├── skills/                   # 각 스킬 = 1 파일, 자기 등록
│   │   ├── Skill.gd              # 베이스 인터페이스
│   │   ├── BuilderSkill.gd
│   │   └── ...
│   ├── world/
│   │   ├── Candy.gd
│   │   ├── Home.gd
│   │   ├── Terrain.gd            # TileMap 래퍼
│   │   └── hazards/
│   │       ├── Hazard.gd
│   │       ├── WaterHazard.gd
│   │       └── ...
│   └── ui/
│       ├── HUD.gd
│       └── SkillToolbar.gd
├── data/
│   ├── stages/
│   │   ├── stage01.tres          # StageData Resource
│   │   └── progression.tres
│   └── skills/
│       └── skill_metadata.tres
├── assets/                        # 스프라이트, 사운드, 폰트
│   ├── sprites/
│   ├── tiles/
│   └── audio/
├── DESIGN_CandyAnts.json
├── REFERENCE_Lemmings.json
└── ARCHITECTURE_CandyAnts.md
```

---

## 4. 핵심 추상화

### 4.1 StageData (Resource) — 스테이지 추가 = 데이터 추가

```gdscript
class_name StageData extends Resource

@export var id: int                              # 1, 2, 3...
@export var display_name: String                 # "스테이지 1: 첫 외출"
@export var scene: PackedScene                   # 레이아웃 씬
@export var total_ants: int                      # N
@export var candy_hp: int                        # K (≤ N)
@export var time_limit_seconds: float
@export var available_skills: Array[String]      # ["builder", "blocker"]
@export var skill_inventory: Dictionary          # { "builder": 5, "blocker": 2 }
@export var release_rate_initial: int = 50
@export var release_rate_min: int = 1
```

→ Stage N 추가 = `stageNN.tres` + `StageNN.tscn`. **기존 코드 0줄 수정**.

### 4.2 Skill Plugin — 명시적 등록 패턴

> ⚠️ **`_static_init` 자기등록은 사용 안 함**: Godot에서 `_static_init`은 스크립트가 로드(preload/load/참조)될 때만 실행됨. 어디서도 참조 안 된 스킬 파일은 **레지스트리에 등록되지 않은 채 침묵**. StageData가 ID를 참조해도 null이 반환되어 조용히 실패.

대신 **SkillRegistry가 알려진 스킬 목록을 명시적으로 preload + 검증**.

```gdscript
# skills/Skill.gd (베이스)
class_name Skill extends RefCounted

const ID: String = "_base_"  # 서브클래스에서 반드시 오버라이드

func apply(ant: Ant) -> void: pass
func can_apply(ant: Ant) -> bool: return true
```

```gdscript
# skills/BuilderSkill.gd
class_name BuilderSkill extends Skill

const ID: String = "builder"

func apply(ant: Ant) -> void:
	ant.state_machine.change_state(WorkerState.new("builder"))
```

```gdscript
# core/SkillRegistry.gd (Autoload)
extends Node

const SKILL_SCRIPTS: Array[Script] = [
	preload("res://scripts/skills/BuilderSkill.gd"),
	preload("res://scripts/skills/BlockerSkill.gd"),
	# 새 스킬은 여기에 1줄 추가 (유일한 코어 터치 지점)
]

var _skills: Dictionary = {}

func _ready() -> void:
	for script: Script in SKILL_SCRIPTS:
		var id: String = script.ID
		assert(id != "_base_", "Skill must override ID")
		assert(not _skills.has(id), "Duplicate skill ID: %s" % id)
		_skills[id] = script

func get_skill(id: String) -> Script:
	return _skills.get(id)

func validate_stage(stage: StageData) -> Array[String]:
	var errors: Array[String] = []
	for id: String in stage.available_skills:
		if not _skills.has(id):
			errors.append("Unknown skill in available_skills: %s" % id)
	for id: String in stage.skill_inventory.keys():
		if not _skills.has(id):
			errors.append("Unknown skill in skill_inventory: %s" % id)
	return errors
```

→ 새 스킬 추가 = (1) 새 .gd 파일 + (2) `SKILL_SCRIPTS`에 preload 1줄. **유일한 코어 터치 지점은 1줄**.

**StageRunner는 시작 시 반드시 호출**: `var errors := SkillRegistry.validate_stage(stage_data); if not errors.is_empty(): push_error(...)` — 잘못된 ID는 즉시 실패하도록.

**향후 확장**: 스킬 수가 늘어나면 `SKILL_SCRIPTS` 배열을 `data/skills/skill_manifest.tres` 데이터 파일로 분리 → .gd 0줄 수정.

### 4.3 EventBus — 시스템 간 디커플링

```gdscript
# core/EventBus.gd (Autoload)
extends Node

signal candy_depleted
signal candy_piece_picked(remaining_hp: int)
signal candy_piece_lost(by_ant: Ant)
signal ant_died(ant: Ant, was_carrying: bool)
signal ant_saved(ant: Ant, with_candy: bool)
signal stage_cleared(score: float)
signal stage_failed(reason: String)
signal release_rate_changed(new_rate: int)
```

ScoreSystem은 `ant_saved`를 구독, UI는 `stage_cleared`를 구독. 서로의 존재를 모름.

### 4.4 AntStateMachine — 상태 추가에 열려있음

```gdscript
class_name AntStateMachine extends Node

var current_state: AntState
var ant: Ant

func change_state(new_state: AntState) -> void:
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.ant = ant
	current_state.enter()

func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)
```

스킬 부여 = `change_state(WorkerState.new("builder"))`. 종료 시 이전 상태 복귀.

### 4.5 ScoreSystem — 사탕 조각 수명 추적

ScoreSystem은 4개 카운터로 사탕 조각의 흐름을 명시적으로 추적. **모호한 클리어/실패 판정을 차단**.

| 카운터 | 의미 | 갱신 시점 |
|--------|------|-----------|
| `original_hp` | 스테이지 시작 시 사탕 총 HP | 스테이지 시작 1회 (불변) |
| `saved_pieces` | 무사 귀환한 조각 수 | `ant_saved(with_candy=true)` 수신 시 +1 |
| `in_transit_pieces` | 운반 중인 조각 수 | `candy_piece_picked` 시 +1, 귀환/사망 시 -1 |
| `lost_pieces` | 운반 중 사망으로 영구 소실 | `candy_piece_lost` 수신 시 +1 |

**불변식** (구현 시 assert로 보장):
```
saved_pieces + in_transit_pieces + lost_pieces ≤ original_hp
saved_pieces + lost_pieces == (original_hp - candy.hp - in_transit_pieces)
```

**클리어 술어** (Boolean):
```gdscript
func is_cleared() -> bool:
	return candy.hp == 0 and in_transit_pieces == 0
```
→ HP 소진 + 운반 중인 개미 0명. 죽은 운반자의 조각이 있어도 클리어 가능 (점수만 낮아짐).

**조기 실패 술어** (선택, MVP 이후 추가 가능):
```gdscript
func is_unrecoverable() -> bool:
	# 살아있는 개미 + 진행 중 조각이 부족해 더 이상 클리어 불가
	var max_reachable := saved_pieces + in_transit_pieces + remaining_living_ants
	return max_reachable < original_hp and remaining_living_ants == 0
```

**시간 종료 처리**:
```
시간 만료 + is_cleared()  → stage_cleared(score)
시간 만료 + 그 외          → stage_failed("time_out")
```

**점수 계산**:
```
score = saved_pieces / original_hp
```

→ Stage 1 빌드(0.1)부터 이 카운터/술어 모두 구현. Hazard가 없는 Stage 1에서도 `lost_pieces`는 0으로 흐르고, 후속 빌드에서 자연스럽게 채워짐.

---

## 5. 2D 렌더링 / 물리 결정

### 5.1 좌표계
- **Godot 2D 표준**: +X 오른쪽, **+Y 아래** (BattlePrototype의 3D Y-up과 다름 — 주의)
- 회전: 라디안, 시계 방향이 양수
- 개미 진행 방향은 `velocity.x` 부호로 표현 (+1 오른쪽, -1 왼쪽)

### 5.2 노드 베이스
| 엔티티 | 노드 타입 | 비고 |
|--------|----------|------|
| Ant | `CharacterBody2D` | `move_and_slide()` + 자체 AI 로직 |
| Candy | `Area2D` | 트리거 감지, 물리 충돌 없음 |
| Home | `Area2D` | 동일 |
| Terrain | `TileMap` | MVP 단순성 — Layer 0 파괴 가능 / Layer 1 파괴 불가 |
| Hazard | `Area2D` | 충돌 감지로 사망 트리거 |
| Camera | `Camera2D` | 스무스 팬, 줌, 한계(limits) |

### 5.3 지형 파괴 — TileMap 기반 (MVP)
- **타일 단위 파괴**: 굴착 스킬이 셀 좌표를 받아 `tile_map.erase_cell(layer, coord)` 호출
- **타일 사이즈**: 16x16 px (개미 한 마리 약 12x10 px 기준)
- **두 레이어**:
  - Layer 0: `destructible` — Basher/Miner/Digger로 제거 가능
  - Layer 1: `indestructible` — 스틸 블록, 어떤 스킬로도 제거 불가
- **Builder 추가 타일**: Layer 0에 사선으로 12셀 추가
- **확장 경로**: 픽셀 단위 정밀도가 필요해지면 BitMap 클래스로 교체 (인터페이스만 유지)

### 5.4 해상도 / 카메라
- **베이스 해상도**: 1920x1080 (project settings의 `display/window/size/viewport_width`)
- **stretch_mode**: `canvas_items`, `aspect`: `expand` (해상도 유연성)
- **카메라**: `Camera2D` with `position_smoothing_enabled=true`, 마우스 우클릭 드래그 또는 미니맵 클릭으로 팬

### 5.5 물리 / 충돌

- **CharacterBody2D**: `move_and_slide()`, 중력은 자체 적용 (개미별 독립)
- **레이어 할당**:
  - Layer 1: Terrain — 파괴 가능
  - Layer 2: Terrain — 파괴 불가 (스틸)
  - Layer 3: Ant 바디
  - Layer 4: Hazard (Area2D)
  - Layer 5: Candy (Area2D)
  - Layer 6: Home (Area2D)

**Ant (CharacterBody2D) 설정**:
- `collision_layer = Layer 3`
- `collision_mask = Layer 1 + 2` — **벽 충돌만**

> ⚠️ Ant mask에 Area2D 레이어(4/5/6)를 넣지 않음. Area2D 감지는 Area2D 쪽이 책임 (§5.6 참조).

### 5.6 Area2D 트리거 계약

> ⚠️ **Godot의 Area2D는 능동적 모니터링**: 바디의 mask만으로는 발화 안 함. 각 Area2D는 자기 mask에 Ant 바디 레이어(3)를 포함시켜야 `body_entered` 시그널이 발화함.

| 엔티티 | `collision_layer` | `collision_mask` | `monitoring` | 시그널 핸들러 |
|--------|-------------------|------------------|--------------|----------------|
| Candy  | Layer 5 | Layer 3 (Ant) | true | `Candy.gd::_on_body_entered(body: Node2D)` → 사탕 HP -1, `EventBus.candy_piece_picked` 발신, ant 상태를 Carrying으로 전이 |
| Home   | Layer 6 | Layer 3 (Ant) | true | `Home.gd::_on_body_entered(body: Node2D)` → ant가 Carrying이면 `ant_saved(with_candy=true)`, Walker(빈손 귀환)면 `ant_saved(with_candy=false)` |
| Hazard | Layer 4 | Layer 3 (Ant) | true | `Hazard.gd::_on_body_entered(body: Node2D)` → ant 상태를 Dead로, Carrying이었다면 `candy_piece_lost` 발신 |

**시그널 연결 위치**: 각 엔티티 `.tscn` 안에서 `body_entered → _on_body_entered`를 인스펙터로 연결 (스크립트에서 connect()도 가능하나 시각적 가독성을 위해 인스펙터 권장).

**핵심 통합 테스트** (Stage 1 빌드 0.1에서 가장 먼저 검증):
> "개미가 Candy 위로 걸어갔을 때 `body_entered`가 실제로 발화하는가?"
>
> 발화 안 하면: (1) Candy의 monitoring 활성화? (2) Candy mask에 Layer 3 포함? (3) Ant collision_layer = 3? (4) CollisionShape2D 존재? — 4가지 항목 순서대로 점검.

---

## 6. Stage 1 — Vertical Slice (MVP 최소 구현)

**목표**: 스킬 0개로 풀 수 있게 설계 → 스킬 시스템 구현 부담 없이 코어 검증.

### 필요 시스템
- ✅ Ant 상태머신 (Walker/Faller/Carrying/Saved/Dead)
- ✅ Candy HP + 픽업 처리 + `candy_piece_picked` 발신
- ✅ Home (진입구 = 도착지) + 빈손/사탕보유 분기 처리
- ✅ Terrain (TileMap, 파괴 없음)
- ✅ Area2D 트리거 계약 검증 (§5.6 4단계 점검 통과)
- ✅ StageRunner + 클리어/실패 판정 (§4.5 술어 사용)
- ✅ ScoreSystem 4-카운터 (original_hp / saved / in_transit / lost)
- ✅ HUD (Time / Out / Saved / Lost / Candy HP)
- ✅ EventBus, GameManager (스켈레톤 수준)
- ✅ SkillRegistry (빈 `SKILL_SCRIPTS` 배열, `validate_stage()` 동작 확인)
- ⬜ Hazard (Stage 4부터)

### Stage 1 디자인
- 단순 평지 또는 완만한 계단
- 개미가 자동으로 사탕 도달 + 귀환
- 플레이어 = 관찰자 — 메카닉 학습
- 사탕 HP = 개미 수와 동일 → 100% 클리어 가능

### 본 빌드 산출물
- `Stage01.tscn` 플레이 가능
- 클리어 시 `StageCompleteDialog` 표시 (점수 100%)
- 실패 시 (시간 초과) "Stage Failed" 표시

---

## 7. 누적 빌드 로드맵

| 빌드 | 스테이지 | 추가 시스템 | 도입 스킬 |
|------|---------|------------|---------|
| 0.1 | Stage 1 | 코어 (Ant/Candy/Home/HP/Score/HUD) | — |
| 0.2 | Stage 2 | SkillRegistry 활성화, SkillToolbar UI, WorkerState | Builder |
| 0.3 | Stage 3 | (스킬만 추가) | Blocker |
| 0.4 | Stage 4 | Hazard 시스템 (Water 우선) | — |
| 0.5 | Stage 5 | TileMap 동적 파괴 | Basher |
| 0.6 | Stage 6 | (Digger는 수직 굴착 변형) | Digger |
| 0.7 | Stage 7 | (Miner는 대각선 변형) | Miner |
| 0.8 | Stage 8 | 등반 처리 (벽 감지 + 수직 이동) | Climber |
| 0.9 | Stage 9 | 낙하 변형 (우산, 추락사 면역) | Floater |
| 1.0 | Stage 10 | 폭발 시스템 (TileMap 원형 파괴), 폴리싱 | Bomber |

각 빌드는 **회귀 없이 누적**. 새 빌드에서 이전 스테이지가 깨지면 코어 침범 신호.

---

## 8. 코딩 규약

BattlePrototype의 규약을 그대로 계승:

- GDScript 4 스타일: `snake_case` (함수/변수), `PascalCase` (클래스/노드)
- 타입 힌트 필수: `var speed: float = 6.0`, `func foo(x: int) -> void:`
- `const`는 `UPPER_SNAKE_CASE`: `const MAX_SPEED := 6.0`
- 시그널: 과거형 (`candy_depleted`, `ant_saved`)
- 들여쓰기: 탭
- `untyped Array/Dictionary`에서 값 꺼낼 때 `:=` 금지 → `var x: Type = arr[i]`
- Autoload 프로퍼티, `Dictionary.get()`, `$NodePath` 접근도 Variant 반환 → `:=` 금지
- 새 스크립트는 폴더 구조(`scripts/core/`, `scripts/ant/states/` 등) 준수

---

## 9. 사전 결정 / 향후 검토

### 결정됨
- ✅ 2D side-view
- ✅ TileMap 기반 지형 (MVP)
- ✅ 좌표계 +Y 아래 (Godot 2D 기본)
- ✅ Y-up 아닌 Y-down — 개미 점프/낙하 부호 처리 시 주의

### 향후 검토
- 시간 흐름: 실제 초 vs 게임 틱 (Speed-up 토글)
- 저장: `user://save.cfg` (Godot 표준) 권장 — 스테이지별 클리어 + 최고 점수
- 스테이지 라우팅: 메뉴 → 선택 → 인게임 → 결과 → 메뉴
- 픽셀 단위 지형 파괴로 업그레이드 시점 (BitMap 전환)
- 페로몬 기반 귀환 경로 (현재: 단순 180°)
- 개미 종류별 차별화 (현재: 1마리 = 1 HP 고정)

---

## 10. 다음 액션 (Stage 1 빌드 0.1 시작 시)

1. `project.godot` 생성 (Godot 4.6, 2D, 1920x1080)
2. 폴더 구조 스켈레톤 작성 (`scripts/core/`, `scripts/ant/`, `data/stages/` 등)
3. Autoload 3종 빈 셸 등록 (GameManager, EventBus, SkillRegistry)
4. `Ant.tscn` + 상태머신 + Walker/Faller/Carrying/Saved/Dead
5. `Candy.tscn` + HP 시스템
6. `Home.tscn`
7. `StageRunner.gd` + Stage 1 클리어/실패 판정
8. `Stage01.tscn` 레이아웃 + `stage01.tres`
9. `HUD.tscn`
10. 플레이 테스트 → 빌드 0.1 완료
