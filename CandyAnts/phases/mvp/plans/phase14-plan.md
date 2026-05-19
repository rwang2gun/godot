# Phase 14 Plan — mechanic-adaptation-traits (v1)

**Status**: plan v1 (initial draft for plan-stage codex review)
**Phase frontmatter doc**: [phases/mvp/phase14-mechanic-adaptation-traits.md](../phase14-mechanic-adaptation-traits.md)
**1차 SoT 인용**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §2.1 / §3.1 (트레잇 보유) / §3.1.2 (전이 전제) / §3.1.4 (엣지) / §0.2 (어휘)
**관련 코드 SoT**: `scripts/ant/Ant.gd`, `scripts/ant/states/`, `scripts/skills/`, `scripts/core/SkillRegistry.gd`
**작성**: 2026-05-20

---

## 0. 한 줄 요약

Ant에 영구 트레잇(`Climber` / `Floater`) 보유 시스템을 도입한다. Climber 보유 개미는 벽 만남 시 새 `ClimberState`로 수직 등반, Floater 보유 개미는 `FallerState`에서 중력 곱이 `FLOATER_GRAVITY_SCALE`로 감쇠. 두 트레잇은 동시 보유 가능, 영구(=phase 14에서 해제 불가). 외부 인터페이스는 `Ant.set_trait(name)` / `has_trait(name)`로 단일 진입점화하여 phase 15(정착·능력 전이)가 동일 API로 확장한다.

---

## 1. Open decisions before implementation — 결정 (frontmatter doc §"Open decisions" 승격)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D1 | 트레잇 보유 표현 | **Ant 노드 상의 `Dictionary` (`traits`)** — `set_trait(name)`/`has_trait(name)` API 1개. boolean 2개 분기 아님 | 확장성 — phase 15(능력 전이)가 동일 key 집합을 그대로 사용. 별도 컴포넌트 노드는 phase 14 시점엔 단일 책임(불 가짐 표시) 과대. dictionary는 `has(key)` 1회로 가벼움 |
| D2 | Climber 벽 감지 | **기존 `is_on_wall()` 분기** (RayCast2D 추가 안 함) | `WalkerState`가 이미 `is_on_wall()` 분기 보유. 1줄 분기 추가로 충분. RayCast 별도 노드는 `move_and_slide()` 결과와 단계 어긋남 위험. test_move는 ClimberState 내부 벽-끝 감지에만 사용 |
| D3 | Floater 낙하 변형 | **`FallerState` 안에서 gravity 곱셈 분기** (별도 fall 상태 분기 X) | `FLOATER_GRAVITY_SCALE: float = 0.3` const, 분기 1줄. 별도 FloaterFallState는 같은 transition graph 중복. 단순성 + 추후 phase 17 hazard 진입 처리 시 단일 FallerState 유지 |
| D4 | 트레잇 시각 표식 | **아이콘 overlay**(Sprite 위 Node2D + Sprite2D 2개. visible toggle) | sprite 색조는 phase 9 Theme/atom 정책상 다른 의미(disabled·selected) 예약. 24×24 svg(`assets/icons/skills/`) 재사용 가능. phase 15 분배자도 동일 패턴 확장 가능 |
| D5 | dev 검증 stage 위치 | **`scenes/stages/dev/`로 분리** + `data/stages/dev/` | 메인 stage progression(Stage01~03)과 직교. SaveData 영향 0. 메뉴 노출 0 (StageSelect는 `data/stages/stageNN.tres`만 스캔). 헤드리스 + 에디터 수동 검증 전용 |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)
| 파일 | 용도 |
|---|---|
| `scripts/ant/states/ClimberState.gd` | 새 state. 수직 등반 motion. transition 명세는 §4 |
| `scripts/skills/ClimberSkill.gd` | ID "climber". `Ant.set_trait("climber")`. can_apply 조건 §6.1 |
| `scripts/skills/FloaterSkill.gd` | ID "floater". `Ant.set_trait("floater")`. can_apply 조건 §6.2 |

### 2.2 수정 (.gd)
| 파일 | 변경 |
|---|---|
| `scripts/ant/Ant.gd` | `var traits: Dictionary = {}` 추가 (StringName→true). `set_trait(name: StringName) -> void`. `has_trait(name: StringName) -> bool`. `const FLOATER_GRAVITY_SCALE: float = 0.3` 추가. `const CLIMB_SPEED: float = 40.0` 추가. `_update_sprite()`에 `ClimberState → anim "climb"` 매핑 1줄(없는 anim은 fallback "walk"). `_update_trait_badges()` 신규 메서드 — `_process` 끝에 호출 (sprite와 같은 시각-only) |
| `scripts/ant/states/WalkerState.gd` | `is_on_wall()` 분기에서 `has_trait("climber")`면 `ClimberState.new()` 전이, 아니면 기존 `flip()` 동일 |
| `scripts/ant/states/CarryingState.gd` | 동일 — `is_on_wall() + has_trait("climber")` 시 `ClimberState` 전이. 그 외 기존 `flip()`. `has_candy=true`는 보존 |
| `scripts/ant/states/FallerState.gd` | `velocity.y += a.gravity * delta` → `velocity.y += a.gravity * delta * (a.FLOATER_GRAVITY_SCALE if a.has_trait("floater") else 1.0)`. 단 1줄 변경 |
| `scripts/core/SkillRegistry.gd` | `SKILL_SCRIPTS` 배열에 `preload("res://scripts/skills/ClimberSkill.gd")` + `preload("res://scripts/skills/FloaterSkill.gd")` 2줄 추가 (CLAUDE.md CRITICAL — 자기등록 금지) |

### 2.3 수정 (.tscn)
| 파일 | 변경 |
|---|---|
| `scenes/entities/Ant.tscn` | `TraitBadges` Node2D 자식 추가 (position=(0,-44), Sprite 위쪽). 자식 2개: `ClimberBadge` (Sprite2D, texture=climber.svg, scale=0.5, position=(-7,0), visible=false), `FloaterBadge` (Sprite2D, texture=floater.svg, scale=0.5, position=(7,0), visible=false). Z-index 시각 우선 — 트레잇 시각 표식이 다른 시각보다 위 |

### 2.4 신규 (검증 stage)
| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_trait_test_layout.tres` | StageLayoutData. 절벽(높이 6셀) + 절벽 위 평지 + 절벽 우측 낙하 갭(폭 4셀, 깊이 5셀) + 사탕 + Home. Stage01_layout 패턴 참조 |
| `data/stages/dev/trait_test.tres` | StageData. id=901, display_name="dev-trait-test", available_skills=["climber","floater"], skill_inventory={"climber":3,"floater":3}, total_ants=6, candy_hp=6, time_limit=180, release_rate_initial=30. 메뉴 노출 X (id ≥ 900은 dev 예약 — `_about` 주석으로 명시) |
| `scenes/stages/dev/TraitTest.tscn` | Stage scene. `Stage03.tscn` 구조 복제. StageRunner.stage_data → trait_test.tres, SkillToolbar 포함, TileMap는 layout 인스턴스 |

### 2.5 신규 (tests/)
| 파일 | 검증 |
|---|---|
| `tests/ClimberTraitTest.tscn/gd` | Stage02 헤드리스 패턴. 첫 ant에 ClimberSkill.apply → 벽 만나기 직전 has_climber=true → 벽 만나면 ClimberState 진입 → 꼭대기 도달 후 WalkerState 복귀. PASS = 30초 내 ant.global_position.y가 wall 꼭대기 위로 도달 |
| `tests/FloaterTraitTest.tscn/gd` | 헤드리스. 첫 ant에 FloaterSkill.apply → 절벽 가장자리에서 FallerState 진입 → velocity.y 증가율 ≤ gravity*delta*0.4(허용 10% 마진) 5 frame 평균. PASS = velocity.y mean delta < threshold |
| `tests/TraitCombinedTest.tscn/gd` | 헤드리스. ant에 둘 다 부여 → 벽 등반 → 천장 도달 → Faller 진입 → 느린 낙하. PASS = climb 중 has_climber/has_floater 모두 true + faller에서 velocity.y delta < threshold |

### 2.6 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 신규 시그널 0건. 트레잇 부여 알림은 phase 14 범위 외(필요 시 phase 15에서 추가).
- `scripts/core/ScoreSystem.gd` — 트레잇은 4-카운터(ADR-002) 무영향. settled 카운터 신설 X (phase 15 plan 단계 재검토).
- `scripts/core/StageData.gd` — 필드 추가 0건. 기존 available_skills/skill_inventory가 climber/floater 문자열 ID 지원.
- `scripts/ui/SkillToolbar.gd` — climber/floater 아이콘 + 라벨 매핑은 phase 9/11에서 이미 등록(`ICONS`/`KO_LABELS`). 무변경.
- `scripts/ui/HUD.gd`, `StageRunner.gd` — 트레잇은 stage data flag 차원에서만 노출되어 toolbar에서 흘러감. 무변경.
- 기존 stages Stage01~03 / data/stages/stage0N.tres — 트레잇 미사용. 회귀 무영향.
- `scripts/skills/Skill.gd`, `BuilderSkill.gd`, `BlockerSkill.gd` — 무변경.
- `scripts/ant/states/SavedState.gd`, `DeadState.gd`, `WorkerState.gd` — 무변경. (※ DeadState/사망 어휘는 §0.2 위반 잔존이지만 PROPOSAL §7.5에 따라 본 phase 범위 외 — phase 17 hazard 본문 작성 시 일괄 처리)

---

## 3. 트레잇 데이터 모델 (D1 구체)

### 3.1 Ant.gd 인터페이스
```gdscript
const FLOATER_GRAVITY_SCALE: float = 0.3
const CLIMB_SPEED: float = 40.0

var traits: Dictionary = {}   # StringName(name) → true. 빈 dict = 트레잇 없음.

func set_trait(name: StringName) -> void:
    if name == &"":
        return
    traits[name] = true

func has_trait(name: StringName) -> bool:
    return traits.has(name)
```

### 3.2 키 화이트리스트
- 본 phase 시점 허용 key: `&"climber"`, `&"floater"`.
- 화이트리스트 enforcement는 코드 레벨에서 강제하지 않는다(가벼움). 잘못된 key는 단순히 `has_trait(...) == false` 결과만 내며, 시뮬레이션은 정상.
- phase 15에서 분배자 + 정착 트레잇 추가 시 같은 dictionary 재사용.

### 3.3 직렬화/지속 (phase 14 시점 무관)
- 본 phase는 트레잇을 spawn 후 set만 한다. 영구. 해제 API 없음.
- SaveData(phase 13)는 ant runtime 트레잇을 저장 안 함(stage progress만 저장). 무영향.

---

## 4. ClimberState 명세

### 4.1 transition graph
```
WalkerState | CarryingState
   │ is_on_wall() && ant.has_trait("climber")
   ↓
ClimberState
   ├── is_on_ceiling() ─────► FallerState (천장 닿음, 등반 불가)
   ├── 벽 끝 도달 (test_move(direction*2,0) == false) ─► WalkerState 또는 CarryingState (has_candy로 분기)
   └── (continuing climb) ───► self (loop)
```

### 4.2 코드 골격
```gdscript
class_name ClimberState extends AntState

func enter() -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    a.velocity = Vector2.ZERO

func update(delta: float) -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    a.velocity.x = 0.0
    a.velocity.y = -a.CLIMB_SPEED
    a.move_and_slide()

    if a.is_on_ceiling():
        a.state_machine.change_state(FallerState.new())
        return

    # 벽 끝 도달 — 1 cell 안쪽 step 후 ground state 복귀.
    var wall_probe: Vector2 = Vector2(float(a.direction) * 2.0, 0.0)
    if not a.test_move(a.transform, wall_probe):
        # 옆으로 1 step push (벽 꼭대기에 올라서기). move_and_slide로 1 frame 적용.
        a.velocity = Vector2(float(a.direction) * a.effective_speed(), 0.0)
        a.move_and_slide()
        if a.has_candy:
            a.state_machine.change_state(CarryingState.new())
        else:
            a.state_machine.change_state(WalkerState.new())
```

### 4.3 의도 (codex 리뷰 대응 ready)
- **velocity.x = 0**: 벽에 평행 등반. horizontal drift 0.
- **벽 끝 감지에 `test_move`**: physics tick 결과(`is_on_wall()`)와 다음 tick의 예측이 어긋날 수 있으므로 다음 tick 충돌을 직접 시뮬. RayCast2D 별도 노드 0개로 끝.
- **꼭대기 1 step push**: 벽 꼭대기 corner를 부드럽게 넘기. push 없으면 next frame에 다시 `is_on_wall()` true가 되어 영구 등반 위험.
- **has_candy 분기**: Climber 도중 carrying 상태 유지. has_candy 보존(Ant.gd:14 spec과 일관).

---

## 5. FallerState Floater 변형 (D3)

### 5.1 변경 diff (개념)
```gdscript
# Before
a.velocity.y += a.gravity * delta
# After
var gscale: float = a.FLOATER_GRAVITY_SCALE if a.has_trait("floater") else 1.0
a.velocity.y += a.gravity * delta * gscale
```

### 5.2 terminal velocity 처리
- 본 phase에서 별도 terminal velocity cap 도입 안 함. gravity 자체가 0.3배라 무한 가속이라도 short fall 거리에선 문제 없음.
- 만약 매우 긴 fall(예: stage 높이 1000px)에서 velocity.y가 비현실적으로 커지면 phase 17 hazard 진입 처리에서 별도 cap 검토.

### 5.3 hazard 진입 처리 (phase 14 범위 외)
- 현 코드에 fall damage 룰 없음(`DeadState.enter()` = queue_free()만, fall-distance 체크 0). Floater 도입으로 fall 사망이 회피되어야 한다는 spec(PRD §4 / PROPOSAL §3.1.1)은 phase 17 hazard 룰 도입 시 함께 검증.
- 본 phase는 Floater = "느린 낙하"라는 시각/물리 차원만 검증. 페일 회피 효과 확인은 phase 17.

---

## 6. 신규 스킬

### 6.1 ClimberSkill.gd
```gdscript
class_name ClimberSkill extends Skill

const ID: String = "climber"

func can_apply(ant: Ant) -> bool:
    if ant == null or ant.state_machine == null:
        return false
    var s: AntState = ant.state_machine.current_state
    # Walker 또는 Carrying만 허용. Faller/Worker(blocker/builder)/Saved 거부.
    if not (s is WalkerState or s is CarryingState):
        return false
    if ant.has_trait("climber"):
        return false
    return true

func apply(ant: Ant) -> void:
    if ant == null:
        return
    ant.set_trait(&"climber")
```

### 6.2 FloaterSkill.gd
```gdscript
class_name FloaterSkill extends Skill

const ID: String = "floater"

func can_apply(ant: Ant) -> bool:
    if ant == null or ant.state_machine == null:
        return false
    if not ant.is_alive():
        return false
    if ant.has_trait("floater"):
        return false
    return true

func apply(ant: Ant) -> void:
    if ant == null:
        return
    ant.set_trait(&"floater")
```

- **Floater는 Faller 중에도 부여 가능** (Lemmings 정통 행동 — 떨어지는 동안 펼치는 낙하산). is_alive() 통과면 OK.
- **이미 트레잇 보유 시 거부** — 중복 부여로 인벤토리 낭비 방지(can_apply에서 차단). SkillToolbar는 can_apply=false면 시각적으로 거부 cue(이미 phase 11 atom 처리).

### 6.3 SkillRegistry.gd 갱신
```gdscript
const SKILL_SCRIPTS: Array[Script] = [
    preload("res://scripts/skills/BuilderSkill.gd"),
    preload("res://scripts/skills/BlockerSkill.gd"),
    preload("res://scripts/skills/ClimberSkill.gd"),    # ← 신규
    preload("res://scripts/skills/FloaterSkill.gd"),    # ← 신규
]
```

---

## 7. 트레잇 시각 표식 (D4)

### 7.1 Ant.tscn 노드 트리 (수정 후)
```
Ant (CharacterBody2D)
├─ CollisionShape2D
├─ Sprite (AnimatedSprite2D)        # 기존
├─ BlockerHitbox (Area2D)            # 기존
├─ StateMachine                      # 기존
└─ TraitBadges (Node2D, pos=(0,-44), z_index=1)   # 신규
   ├─ ClimberBadge (Sprite2D, texture=climber.svg, scale=0.5, position=(-7,0), visible=false)
   └─ FloaterBadge (Sprite2D, texture=floater.svg, scale=0.5, position=(7,0), visible=false)
```

### 7.2 Ant.gd 갱신
```gdscript
var _trait_badges: Node2D = null
var _climber_badge: Sprite2D = null
var _floater_badge: Sprite2D = null

func _ready() -> void:
    ...
    _trait_badges = get_node_or_null("TraitBadges") as Node2D
    if _trait_badges != null:
        _climber_badge = _trait_badges.get_node_or_null("ClimberBadge") as Sprite2D
        _floater_badge = _trait_badges.get_node_or_null("FloaterBadge") as Sprite2D

func _update_trait_badges() -> void:
    # 시각 전용 — 로직 무영향. 실패해도 시뮬레이션 진행. _physics_process 끝에서 호출.
    if _climber_badge != null:
        _climber_badge.visible = has_trait(&"climber")
    if _floater_badge != null:
        _floater_badge.visible = has_trait(&"floater")
```

### 7.3 _physics_process 갱신
`_update_sprite()` 호출 직후 `_update_trait_badges()` 호출. 둘 다 시각-only로 try-catch 무관(null guard).

### 7.4 SVG 자산
- climber.svg / floater.svg는 `assets/icons/skills/`에 phase 9에서 이미 임포트됨 (SkillToolbar.ICONS에서 preload 확인됨). 본 phase는 자산 신규 X.
- `tests/SvgImportSmokeTest.gd`의 `PRODUCTION_SVGS` 갱신 — 두 svg는 이미 포함되어 있을 가능성 높음. impl 단계에서 확인 후 누락 시 1줄 추가.

---

## 8. dev 검증 stage (D5)

### 8.1 레이아웃 개념도
```
   ┌──────────────┐  <- 절벽 위 평지 (사탕 위치)
   │  Candy   ┌──┴
   │          │ ◀ 절벽 (높이 6셀, 16px*6=96px)
   │  ┌───────┘
   │  │ 갭(폭 4셀, 깊이 5셀)  Home (스폰 + 도착)
   │  │   ┌────┐    ┌───┐
───┴──┘   └────┘────┘   └────
```

- 좌→우 진행: Home(스폰) → 갭 1개 → 절벽(climber 검증) → 평지 → Candy → 180° 회전 → 평지 → 절벽 추락(floater 검증) → 갭 → Home(귀환).
- climber 없으면 절벽 앞에서 flip. floater 없으면 추락 후 빠르게 떨어짐.
- 두 트레잇 모두 있으면 절벽 등반 + 추락 시 느린 낙하 + 정상 귀환.

### 8.2 data/stages/dev/trait_test.tres
```
[gd_resource type="Resource" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/core/StageData.gd" id="1"]
[ext_resource type="Resource" path="res://data/stage_layouts/dev_trait_test_layout.tres" id="2"]
[resource]
script = ExtResource("1")
id = 901
display_name = "dev-trait-test"
layout = ExtResource("2")
total_ants = 6
candy_hp = 6
time_limit_seconds = 180.0
available_skills = ["climber", "floater"]
skill_inventory = { "climber": 3, "floater": 3 }
release_rate_initial = 30
release_rate_min = 1
```

### 8.3 메뉴 노출 0 확인
- StageSelect(phase 13)는 `data/stages/`만 스캔. `data/stages/dev/`는 별도 폴더라 자동 노출 X.
- StageSelect 코드 확인 → dev/ 폴더 무시 패턴이 명시되어 있지 않으면 impl 단계에서 검토. (현재 SaveData / 메뉴 코드를 본 phase plan에서 다 보지 못함 — impl 단계 첫 작업)

---

## 9. 시그널 흐름

### 9.1 본 phase 신규 시그널 = 0개
- EventBus 무변경. 트레잇 부여는 ant.set_trait() 직접 호출 — 시그널 불필요.
- SkillToolbar → 선택된 스킬 ID → ant에 apply → set_trait. 기존 phase 11 흐름 그대로.

### 9.2 기존 시그널 재사용
- `EventBus.action_triggered(name: StringName)` — SkillToolbar가 슬롯 click 시 발화 → StageRunner._on_action → `_try_assign(skill_id)` → SkillRegistry.get_skill(id).new().apply(ant).
- climber/floater도 동일 경로 진입. 별도 hook 0개.

### 9.3 _physics_process 흐름 (Ant)
```
_physics_process(delta):
  state_machine.update(delta)        # 기존
  _update_sprite()                   # 기존
  _update_trait_badges()             # 신규 — 시각-only, 무조건 호출
```

---

## 10. 엣지 케이스 (PROPOSAL §3.1.4 + 본 plan 분석)

| # | 시나리오 | 처리 결정 | 검증 위치 |
|---|---|---|---|
| E1 | Climber + Floater 동시 보유. 벽 등반 중 천장 닿음 → Faller 진입 → Floater 효과로 느린 낙하 | 정상 — 자연스러운 transition. ClimberState→FallerState는 `is_on_ceiling()` 시 자동. FallerState가 has_trait("floater") 확인 | TraitCombinedTest |
| E2 | Carrying 상태에서 climber 부여 → 벽 만남 → ClimberState. has_candy 보존 → 꼭대기 도달 → CarryingState 복귀 | ClimberState exit에서 `has_candy` 분기 (§4.2). has_been_carrying/has_candy 둘 다 보존 | ClimberTraitTest (carry variant) |
| E3 | 벽 등반 도중 has_trait("climber")가 빠지면? | 본 phase에서 트레잇 해제 API 없음 (영구). 빠질 일 없음. impl assert로 방어 가능하지만 미도입 (단순성). phase 15+에서 해제 패턴 등장 시 재검토 | (N/A, 본 phase) |
| E4 | Floater 부여 시점이 Faller 도중 | can_apply는 is_alive() 통과면 허용 (§6.2). 다음 _physics_process tick부터 gravity 0.3배 적용 | FloaterTraitTest (apply-mid-fall variant) |
| E5 | climber 부여한 ant가 spawn_grace 중 벽 만남 | WalkerState는 `_frame > 1`까지 idle (grace). 그 동안 is_on_wall() false라면 분기 안 됨. grace 끝나고 첫 wall 충돌 시 정상 ClimberState 전이 | ClimberTraitTest (spawn-near-wall variant 확인) |
| E6 | climber ant가 등반 중 다른 ant와 충돌 | Ant.collision_mask=3 (벽). Ant끼리는 layer 4로 서로 무시. ClimberState도 동일. 영향 없음 | (코드 검증 — collision matrix 확인) |
| E7 | climber ant가 등반 도중 blocker hit | BlockerHitbox는 ant collision layer 4를 감시. ClimberState 중 ant.velocity.x=0이지만 blocker 영향 받음? — blocker는 walker direction을 flip. ClimberState는 horizontal motion 0이라 direction flip 무영향 (다음 walker 복귀 시 그 direction으로 진행). 정상 | (코드 검증 — BlockerHitbox 안에서 climber state 통과 확인) |
| E8 | floater ant가 Home 위 자유낙하로 직접 도달 | FallerState exit는 `is_on_floor()` 시 WalkerState. Home Area2D가 trigger되면 SavedState. floater는 gravity만 0.3배, transition graph 무변경 | (Stage 02/03 회귀 PASS로 간접 검증) |
| E9 | 트레잇 시각 표식이 sprite 위 z-order 충돌 | TraitBadges Node2D z_index=1 (Sprite는 기본 0). 위로 그려짐. ant 자체 z_index가 stage z layer와 충돌하지 않는지 — 기존 Ant.tscn에 z_index 설정 없음(=0). stage TileMap z_index도 보통 0 → ant·badges 모두 같은 layer지만 child 순서로 결정 | 에디터 수동 확인 |
| E10 | release rate 슬라이더 + 트레잇 부여 인터럽트 | release_rate는 spawn 간격만 제어. 트레잇은 spawn 이후 부여. 무관 | (기존 회귀로 간접 검증) |

---

## 11. 검증 시나리오

### 11.1 헤드리스 자동 (필수 PASS)
```
python scripts/run_test.py tests/Stage02HeadlessTest.tscn       # 회귀 — phase 3 PASS 유지
python scripts/run_test.py tests/Stage03HeadlessTest.tscn       # 회귀 — phase 4 PASS 유지
python scripts/run_test.py tests/BlockerOverlapTest.tscn        # 있으면 회귀
python scripts/run_test.py tests/ClimberTraitTest.tscn          # 신규
python scripts/run_test.py tests/FloaterTraitTest.tscn          # 신규
python scripts/run_test.py tests/TraitCombinedTest.tscn         # 신규
```

### 11.2 헤드리스 신규 — PASS 기준
- **ClimberTraitTest**: 30초 내 첫 climber ant의 global_position.y가 wall 꼭대기 위로 도달 + 해당 ant가 다시 WalkerState 또는 CarryingState로 복귀. quit(0) on PASS.
- **FloaterTraitTest**: 첫 floater ant가 Faller 진입 후 5 frame velocity.y 평균 증가율 ≤ `gravity * delta * 0.4` (FLOATER_GRAVITY_SCALE 0.3 + 마진 0.1). quit(0) on PASS.
- **TraitCombinedTest**: ant 한 마리에 climber+floater 부여 → 등반 중 천장 도달 → Faller 진입 → velocity.y 평균 증가율 ≤ 0.4× gravity. quit(0) on PASS.

### 11.3 에디터 수동
```
1. scenes/stages/dev/TraitTest.tscn 열고 F6 실행
2. ClimberSkill 1회 부여 → ant가 절벽 등반하는지
3. FloaterSkill 1회 부여 → ant가 갭 추락 시 느린 낙하 + 일정 위치 착지
4. 두 스킬 부여한 ant → 절벽 등반 + 평지 끝 추락 시 느린 낙하 + Home 도착 → Saved
5. SkillToolbar에 climber/floater 아이콘 정상 표시 + 인벤토리 카운트 감소
6. Stage01/02/03 회귀 — 트레잇 미부여 시 기존 동작 동일
```

### 11.4 회귀 점검 (CLAUDE.md "한 Phase 완료 후 회귀 확인")
- Stage01 (튜토리얼, 스킬 0개) 완주 가능 — climber/floater 미사용
- Stage02 (builder) — Builder 동작 회귀
- Stage03 (blocker) — Blocker 동작 회귀
- 회귀 헤드리스(Stage02/03 HeadlessTest) PASS

---

## 12. 톤 폴리시 (§0.2) 점검

- 신규 코드/주석/UI 메시지 어휘 ban list:
  - 금지: `die()`, `DeadState`, "사망", "죽"
  - 허용: "정착", "임무 완수", "사탕 손실", "탈락"
- **본 phase 신규 코드는 ban 단어 0건**. ClimberSkill/FloaterSkill/ClimberState/Ant.gd 변경 모두 ant motion/visual 묘사만 — 페일 어휘 무관.
- **기존 코드 잔존 ban (DeadState 등)**: PROPOSAL §7.5에 따라 본 phase 미수정. phase 17 hazard 본문 작성 시 일괄 처리.
- impl 단계에서 `python scripts/check_tone_policy.py --commit3` 실행 — 본 phase 변경 파일 한정으로 PASS 확인.

---

## 13. 자체 적대적 리뷰 — Plan v1 self-check

> CLAUDE.md plan-stage 정책상 plan에 대한 자체 적대적 리뷰 사이클은 의무 X (impl stage 한정). 그러나 codex plan-stage 1회 호출 전에 미리 점검.

### 13.1 점검 차원
- **변경 폭**: 신규 3 .gd + 수정 5 .gd + .tscn 1 + dev stage 3 + tests 3. 적정.
- **회귀 위험**: WalkerState/CarryingState 분기 추가 1줄씩. has_trait("climber") false면 기존 코드 fall-through. Stage01~03 회귀 무영향(트레잇 dict 빈 dict).
- **CLAUDE.md CRITICAL 준수**: SkillRegistry.SKILL_SCRIPTS preload 추가 OK. `scripts/{core,ant,skills,world,ui}/` 위치 준수. Area2D mask 변경 없음.
- **4-카운터 무영향**: 트레잇 부여는 ScoreSystem 카운터 외. ADR-002 spec 보존.
- **cross-doc 일관성**: PROPOSAL §3.1 (정착 보유 트레잇), §3.1.2 (전이 전제), §3.1.4 (엣지) 모두 본 plan에 인용. phase 15에서 같은 traits dict 재사용 약속.
- **TBD 잔존**: PROPOSAL §3.1 "정착 트리거" 등은 phase 15 plan에서 결정. 본 plan에는 정착 어떤 부분도 도입 안 함.
- **숨은 가정 표면화**:
  - (A) StageSelect가 `data/stages/dev/`를 스캔하지 않는다는 가정 — impl 단계 첫 검증 (코드 직접 확인).
  - (B) climber.svg/floater.svg가 ant 시각 표식에 24×24 적정 크기로 보임 — 에디터 수동 확인.
  - (C) ClimberState 꼭대기 step push가 0.5 cell 이내 — `effective_speed()` × 1 frame ≈ 60*0.0167 ≈ 1px. 1 cell = 16px라 multiple frame 누적 필요. impl 단계에서 `velocity.x = direction * effective_speed() * 4` 등 boost 검토(또는 직접 transform translate). codex 리뷰가 이 부분 challenge할 가능성.

### 13.2 self-found risks
| sev | 항목 | 처리 |
|---|---|---|
| MED | ClimberState 꼭대기 step push가 1 frame 부족할 수 있음 (위 (C)) | impl 단계 첫 fix — direct `position.x += direction * 8.0` (0.5 cell) 적용. ClimberState 안에 1줄. |
| MED | StageSelect가 dev/ 스캔하면 메뉴에 노출됨 | impl 첫 작업으로 코드 확인. 노출되면 dev/ 스킵 로직 추가 (StageSelect 1줄). |
| LOW | TraitBadges가 ant flip(flip_h)에 따라 좌우 반대로 보일 수 있음 | TraitBadges는 Sprite 자식 아닌 Ant 자식. Sprite.flip_h만 적용 → badges 무관. 정상. |
| LOW | floater 부여 ant가 Worker(builder/blocker) 상태에서 set_trait 받음 → 작업 끝 후 fall 진입 시 정상 적용 | FallerState가 매 frame has_trait 체크. 정상. |

---

## 14. TBD (impl 단계에서 첫 검증)

1. StageSelect.gd가 `data/stages/dev/`를 자동 스캔하는지 — impl 첫 task로 코드 확인. 노출되면 무시 로직 추가.
2. SvgImportSmokeTest.PRODUCTION_SVGS에 climber/floater 이미 포함 여부 확인 — 누락 시 추가.
3. ClimberState 꼭대기 step push 정확한 크기 — impl 단계 first-run에서 시각 확인 후 fine-tune (0.5 cell ~ 1 cell 범위).
4. dev stage layout cell 좌표 — `data/stage_layouts/stage01_layout.tres` 형식 확인 후 동일 포맷으로 작성. impl 단계 첫 작업.

---

## 15. 산출물 요약 (complete 직전 git status 예측)

```
신규:
  scripts/ant/states/ClimberState.gd
  scripts/skills/ClimberSkill.gd
  scripts/skills/FloaterSkill.gd
  data/stage_layouts/dev_trait_test_layout.tres
  data/stages/dev/trait_test.tres
  scenes/stages/dev/TraitTest.tscn
  tests/ClimberTraitTest.tscn / .gd
  tests/FloaterTraitTest.tscn / .gd
  tests/TraitCombinedTest.tscn / .gd
  phases/mvp/plans/phase14-plan.md (본 문서)
  phases/mvp/reviews/phase14-review.md (codex plan stage)
  phases/mvp/reviews/phase14-impl-review.md (codex impl stage + self-review rounds)

수정:
  scripts/ant/Ant.gd
  scripts/ant/states/WalkerState.gd
  scripts/ant/states/CarryingState.gd
  scripts/ant/states/FallerState.gd
  scripts/core/SkillRegistry.gd
  scenes/entities/Ant.tscn
  phases/mvp/notion-phase-ids.json (phase 14 진입 동기화 — 이미 commit 직전 단계)
  phases/mvp/status.json (execute.py 자동 갱신)
  (조건부) scripts/ui/StageSelect.gd — dev/ 스킵 (impl TBD 1 결과에 따라)
  (조건부) tests/SvgImportSmokeTest.gd — PRODUCTION_SVGS 추가 (impl TBD 2 결과에 따라)
```

deny-list 매치 없음(.git/.godot 제외). large_change_ok=false 유지 — 변경 파일 수 < 100, 단일 5MB / 합계 25MB 한참 이하.

---

## 16. 다음 단계 (impl 시작 전)

1. **codex plan-stage adversarial-review** — 사용자 데스크톱에서 `/codex:adversarial-review --wait "phase 14 plan: climber+floater traits via dict, ClimberState, FallerState gravity scale"`
2. HIGH 0건 → impl 진입. HIGH 1건 이상 → 즉시 중단 + 사용자 결정 (CLAUDE.md plan-stage policy).
3. impl 시작 순서:
   - TBD 1 (StageSelect dev/ 스킵) 확인
   - Ant.gd 인터페이스 (traits dict + const)
   - SkillRegistry 등록 (preload 2줄)
   - ClimberState + ClimberSkill
   - FloaterSkill + FallerState diff
   - Ant.tscn TraitBadges + Ant.gd _update_trait_badges
   - dev stage layout + StageData + scene
   - 헤드리스 테스트 3종
   - 회귀 헤드리스 PASS 확인
   - 에디터 수동 검증
   - codex impl-stage 리뷰 사이클
