# Phase 14 Plan — mechanic-adaptation-traits (v4)

**Status**: plan v4 (Round 3 needs-attention 대응 — ancestor-scoped builder resolution, group lookup 폐기)
**Phase frontmatter doc**: [phases/mvp/phase14-mechanic-adaptation-traits.md](../phase14-mechanic-adaptation-traits.md)
**1차 SoT 인용**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §2.1 / §3.1 (트레잇 보유) / §3.1.2 (전이 전제) / §3.1.4 (엣지) / §0.2 (어휘)
**관련 코드 SoT**: `scripts/ant/Ant.gd`, `scripts/ant/states/`, `scripts/skills/`, `scripts/core/SkillRegistry.gd`, `scripts/world/StageLayoutBuilder.gd`, `scripts/core/StageLayoutData.gd`, `scripts/core/StageRunner.gd`
**작성**: 2026-05-20

---

## 0. 한 줄 요약

Ant에 영구 트레잇(`Climber` / `Floater`) 보유 시스템을 도입한다. Climber 보유 개미는 벽 만남 시 새 `ClimberState`로 수직 등반 후 **결정적 mantle(턱넘기) substate + mandatory stall guard**를 거쳐 Walker/Carrying 복귀, Floater 보유 개미는 `FallerState`에서 중력 곱이 `FLOATER_GRAVITY_SCALE`로 감쇠. mantle 거리는 **runtime에 ant의 ancestor chain에서 StageLayoutBuilder를 찾아 layout.cell_size + 4로 동적 계산**(scope-safe, group lookup 미사용). 두 트레잇은 동시 보유 가능, 영구(=phase 14에서 해제 불가). 외부 인터페이스는 `Ant.set_trait(name)` / `has_trait(name)`로 단일 진입점화하여 phase 15가 동일 API로 확장한다. dev 검증 stage는 Stage02/03 패턴을 따라 **SkillToolbar 포함** + StageLayoutBuilder wiring 직접 명시.

---

## 0.1 v2→v3 변경 (Round 2 needs-attention 대응)

| 항목 | v2 | v3 | 사유 |
|---|---|---|---|
| mantle stall 처리 | §4.5에 "옵션" 명시, §4.2 skeleton에 미포함 | **§4.2 skeleton에 mandatory 포함** (`_mantle_stall_frames` + dx<0.1이 10 frame 연속이면 FallerState). 별도 §4.5 "옵션" 폐기 | Round 2 HIGH — 옵션이면 stall 시나리오에서 무한 mantling 가능 |
| mantle 거리 표현 | `const MANTLE_DISTANCE: float = 36.0` 하드코딩 | **`var mantle_distance: float = 36.0` instance var + Ant._ready()에서 stage_layout_builder 그룹 lookup으로 cell_size+4 runtime 계산**. 미발견 시 36.0 fallback (Stage01~03이 모두 cell_size=32라 fallback이 정확) | Round 2 MEDIUM — cell_size 변경 시 자동 적응 |
| StageLayoutBuilder | 무변경 | **`_ready()`에 `add_to_group("stage_layout_builder")` 1줄 추가** | runtime cell_size lookup 채널 제공 |
| TraitTest.tscn 구조 | Stage01 패턴 복제 (toolbar 없음) | **Stage02/03 패턴 복제** — SkillToolbar ext_resource + StageRunner.toolbar_path + `[node "SkillToolbar"]` 포함 | Round 2 MEDIUM — Stage01은 toolbar 없어서 스킬 부여 불가 |
| ClimberStallTest | 없음 | **신규 헤드리스 테스트** — 두꺼운 벽 / 막힌 corner 시나리오에서 mantle stall → FallerState 전이 검증 | Round 2 HIGH 권고 — stall guard 동작 증명 |

## 0.2 v3→v4 변경 (Round 3 needs-attention 대응 — MEDIUM only, plan-stage policy로는 진행 가능하지만 fix가 작아 inline 처리)

| 항목 | v3 | v4 | 사유 |
|---|---|---|---|
| mantle 거리 builder 해상 방식 | `get_tree().get_first_node_in_group("stage_layout_builder")` — global 그룹 lookup | **ancestor chain 스캔** — ant의 부모를 따라 올라가며 각 노드에서 `StageLayoutBuilder` 자식이 있는지 확인. 첫 매치된 builder의 layout.cell_size 사용. 미발견 시 36.0 fallback. | Round 3 MEDIUM — 그룹은 SceneTree 전역이라 stage 전환/헤드리스 다중 scene에서 다른 stage의 builder가 잡힐 수 있음. ancestor 스캔은 ant가 속한 stage subtree로 자동 scope됨 |
| StageLayoutBuilder.gd | `_ready()`에 `add_to_group("stage_layout_builder")` 추가 | **무변경 (v4에서 group 등록 폐기)** — ancestor 스캔이 group 없이도 동작하므로 builder 코드 자체는 손대지 않음 | Round 3 MEDIUM 권고대로 unscoped global lookup 제거. global 채널을 만들지 않는 것이 더 안전 |

---

## 1. Open decisions before implementation — 결정 (frontmatter doc §"Open decisions" 승격)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| D1 | 트레잇 보유 표현 | **Ant 노드 상의 `Dictionary` (`traits`)** — `set_trait(name)`/`has_trait(name)` API 1개. boolean 2개 분기 아님 | 확장성 — phase 15(능력 전이)가 동일 key 집합을 그대로 사용. 별도 컴포넌트 노드는 phase 14 시점엔 단일 책임(불 가짐 표시) 과대. dictionary는 `has(key)` 1회로 가벼움 |
| D2 | Climber 벽 감지 | **기존 `is_on_wall()` 분기** (RayCast2D 추가 안 함) | `WalkerState`가 이미 `is_on_wall()` 분기 보유. 1줄 분기 추가로 충분. RayCast 별도 노드는 `move_and_slide()` 결과와 단계 어긋남 위험. `test_move`는 ClimberState 내부 벽-끝 감지(mantle 진입 트리거)에만 사용 |
| D3 | Floater 낙하 변형 | **`FallerState` 안에서 gravity 곱셈 분기** (별도 fall 상태 분기 X) | `FLOATER_GRAVITY_SCALE: float = 0.3` const, 분기 1줄. 별도 FloaterFallState는 같은 transition graph 중복. 단순성 + 추후 phase 17 hazard 진입 처리 시 단일 FallerState 유지 |
| D4 | 트레잇 시각 표식 | **아이콘 overlay**(Sprite 위 Node2D + Sprite2D 2개. visible toggle) | sprite 색조는 phase 9 Theme/atom 정책상 다른 의미(disabled·selected) 예약. 24×24 svg(`assets/icons/skills/`) 재사용 가능. phase 15 분배자도 동일 패턴 확장 가능 |
| D5 | dev 검증 stage 위치 | **`scenes/stages/dev/`로 분리** + `data/stages/dev/` + `data/stage_layouts/`(공용 폴더, dev 접두) | 메인 stage progression(Stage01~03)과 직교. SaveData 영향 0. 메뉴 노출 0 (StageSelect는 `data/stages/stageNN.tres`만 스캔; impl §14-TBD-1로 검증). 헤드리스 + 에디터 수동 검증 전용 |
| D6 | ClimberState 꼭대기 처리 | **`_mantle_offset` 누적 substate + mandatory stall guard** — wall-end 감지 시 mantling 진입, 누적 거리가 `mantle_distance`(runtime cell_size + 4) 도달 시 결정적 전이. dx<0.1이 10 frame 연속이면 FallerState로 강제 탈출 | Round 1 HIGH + Round 2 HIGH 동시 대응. 1-frame velocity push로는 corner를 못 넘김 + stall이 무한 mantling 유발 가능 |
| D7 | dev stage runtime wiring | **TraitTest.tscn에 Stage02/03 패턴 적용** — World/StageLayoutBuilder 명시 + `layout = ExtResource(dev_trait_test_layout.tres)` + SkillToolbar ext_resource/node/StageRunner.toolbar_path. Home/Candy/Spawner의 `position`은 layout.cell_to_world(layout.home_cell/candy_cell)로 매핑되도록 scene에 직접 좌표 기록 | Round 1 MEDIUM + Round 2 MEDIUM. StageRunner는 stage_data.layout을 consume 안 함 + Stage01엔 SkillToolbar 없음 |
| D8 (v3→v4 갱신) | mantle 거리 runtime resolve | **Ant._ready()에서 ancestor chain 스캔** — 자기 자신부터 시작해 부모를 따라 올라가며 각 노드에서 자식 노드명 `StageLayoutBuilder`가 있는지 확인. 첫 매치된 builder의 layout.cell_size + 4 적용. layout이 null이면 다음 ancestor 시도. 미발견 시 36.0 fallback. | Round 2 MEDIUM + Round 3 MEDIUM 대응. ancestor scan은 ant가 속한 stage subtree로 자동 scope되어 stage 전환/다중 scene에서 잘못된 builder를 잡지 않음 |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)
| 파일 | 용도 |
|---|---|
| `scripts/ant/states/ClimberState.gd` | 새 state. 수직 등반 motion + mantle substate + mandatory stall guard (§4 명세) |
| `scripts/skills/ClimberSkill.gd` | ID "climber". `Ant.set_trait("climber")`. can_apply 조건 §6.1 |
| `scripts/skills/FloaterSkill.gd` | ID "floater". `Ant.set_trait("floater")`. can_apply 조건 §6.2 |

### 2.2 수정 (.gd)
| 파일 | 변경 |
|---|---|
| `scripts/ant/Ant.gd` | `var traits: Dictionary = {}` 추가. `set_trait(name: StringName) -> void`. `has_trait(name: StringName) -> bool`. `const FLOATER_GRAVITY_SCALE: float = 0.3` 추가. `const CLIMB_SPEED: float = 40.0` 추가. **`var mantle_distance: float = 36.0`** 추가(instance var, runtime 갱신). `_resolve_mantle_distance()` 헬퍼 — `_ready()`에서 호출, **ancestor chain 스캔으로** layout 보유 builder 발견 시 cell_size+4 적용, 미발견 시 36.0 유지. `_update_sprite()`에 `ClimberState → anim "climb"` 매핑 1줄(없는 anim은 fallback "walk"). `_update_trait_badges()` 신규 메서드 — `_physics_process` 끝에 호출 (sprite와 같은 시각-only) |
| `scripts/ant/states/WalkerState.gd` | `is_on_wall()` 분기에서 `has_trait("climber")`면 `ClimberState.new()` 전이, 아니면 기존 `flip()` 동일 |
| `scripts/ant/states/CarryingState.gd` | 동일 — `is_on_wall() + has_trait("climber")` 시 `ClimberState` 전이. 그 외 기존 `flip()`. `has_candy=true`는 보존 |
| `scripts/ant/states/FallerState.gd` | `velocity.y += a.gravity * delta` → `velocity.y += a.gravity * delta * (a.FLOATER_GRAVITY_SCALE if a.has_trait("floater") else 1.0)`. 단 1줄 변경 |
| `scripts/core/SkillRegistry.gd` | `SKILL_SCRIPTS` 배열에 `preload("res://scripts/skills/ClimberSkill.gd")` + `preload("res://scripts/skills/FloaterSkill.gd")` 2줄 추가 (CLAUDE.md CRITICAL — 자기등록 금지) |
| `scripts/world/StageLayoutBuilder.gd` | **v4 무변경** (v3에서 도입한 add_to_group은 v4에서 폐기 — ancestor 스캔으로 대체). 본 phase에서 builder 코드 자체는 손대지 않음. |

### 2.3 수정 (.tscn)
| 파일 | 변경 |
|---|---|
| `scenes/entities/Ant.tscn` | `TraitBadges` Node2D 자식 추가 (position=(0,-44), Sprite 위쪽). 자식 2개: `ClimberBadge` (Sprite2D, texture=climber.svg, scale=0.5, position=(-7,0), visible=false), `FloaterBadge` (Sprite2D, texture=floater.svg, scale=0.5, position=(7,0), visible=false). Z-index 시각 우선 |

### 2.4 신규 (검증 stage) — v3 명세 (Stage02/03 패턴 + SkillToolbar)
| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_trait_test_layout.tres` | StageLayoutData. cell_size=32. layout 셀 좌표는 §8.1 도식 → §8.4 cell 좌표표. home_cell, candy_cell, camera_cell, spawn_direction 포함 |
| `data/stages/dev/trait_test.tres` | StageData. id=901, display_name="dev-trait-test", available_skills=["climber","floater"], skill_inventory={"climber":3,"floater":3}, total_ants=6, candy_hp=6, time_limit=180, release_rate_initial=30. 메뉴 노출 X (id ≥ 900은 dev 예약 — `_about` 주석으로 명시). layout 필드는 StageData에 없으므로 scene-side StageLayoutBuilder가 SoT |
| `scenes/stages/dev/TraitTest.tscn` | Stage scene. **Stage02/Stage03 패턴 복제** — SkillToolbar ext_resource + node 포함. StageRunner.toolbar_path = NodePath("SkillToolbar"). World/StageLayoutBuilder가 dev_trait_test_layout.tres 직접 wiring (§8.3 노드 구조) |

### 2.5 신규 (tests/) — v3 ClimberStallTest 추가
| 파일 | 검증 |
|---|---|
| `tests/ClimberTraitTest.tscn/gd` | dev_trait_test_layout 사용(또는 별도 헤드리스 layout). 첫 ant에 ClimberSkill.apply → 벽 만나기 직전 has_climber=true → 벽 만나면 ClimberState 진입 → mantle 완료 후 WalkerState 복귀. PASS = 30초 내 ant.global_position.y가 wall 꼭대기 위로 도달 + ant.global_position.x가 mantle 방향으로 ≥ ant.mantle_distance 진행 + 마지막 3 frame 동안 state가 Walker 또는 Carrying 유지 (looping 방지) |
| `tests/FloaterTraitTest.tscn/gd` | 헤드리스. 첫 ant에 FloaterSkill.apply → 절벽 가장자리에서 FallerState 진입 → velocity.y 증가율 ≤ gravity*delta*0.4(허용 10% 마진) 5 frame 평균. PASS = velocity.y mean delta < threshold |
| `tests/TraitCombinedTest.tscn/gd` | 헤드리스. ant에 둘 다 부여 → 벽 등반 → 천장 도달 → Faller 진입 → 느린 낙하. PASS = climb 중 has_climber/has_floater 모두 true + faller에서 velocity.y delta < threshold |
| **`tests/ClimberStallTest.tscn/gd` (v3 신규)** | 헤드리스. 별도 stall_layout (두꺼운 벽 = 4 cell 두께, 벽 꼭대기에 ceiling overhang). climber ant가 wall 끝 감지 후 mantling 진입 → dx==0 stall 발생 → 10 frame 후 FallerState로 강제 전이. PASS = ClimberState 진입 30 frame 이내에 mantling으로 분기 + 10~20 frame 사이에 FallerState로 전이 (무한 stuck 아님). FAIL = 60 frame 이상 ClimberState에 머무름 |

### 2.6 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 신규 시그널 0건. 트레잇 부여 알림은 phase 14 범위 외(필요 시 phase 15에서 추가).
- `scripts/core/ScoreSystem.gd` — 트레잇은 4-카운터(ADR-002) 무영향. settled 카운터 신설 X (phase 15 plan 단계 재검토).
- `scripts/core/StageData.gd` — 필드 추가 0건. 기존 available_skills/skill_inventory가 climber/floater 문자열 ID 지원. layout 필드 신설 X — scene-side StageLayoutBuilder가 SoT.
- `scripts/core/StageRunner.gd` — 무변경. 기존 `toolbar_path` export가 TraitTest.tscn 와이어링에 그대로 사용됨.
- `scripts/ui/SkillToolbar.gd` — climber/floater 아이콘 + 라벨 매핑은 phase 9/11에서 이미 등록(`ICONS`/`KO_LABELS`). 무변경.
- `scripts/ui/HUD.gd` — 무변경.
- 기존 stages Stage01~03 / data/stages/stage0N.tres — 트레잇 미사용. 회귀 무영향.
- `scripts/skills/Skill.gd`, `BuilderSkill.gd`, `BlockerSkill.gd` — 무변경.
- `scripts/ant/states/SavedState.gd`, `DeadState.gd`, `WorkerState.gd` — 무변경. (※ DeadState/사망 어휘는 §0.2 위반 잔존이지만 PROPOSAL §7.5에 따라 본 phase 범위 외 — phase 17 hazard 본문 작성 시 일괄 처리)
- 기존 Stage 01~03 layout .tres 파일 — 무변경. cell_size=32 유지.

---

## 3. 트레잇 데이터 모델 (D1 / D8 구체)

### 3.1 Ant.gd 인터페이스 (v4 — ancestor-scoped mantle_distance resolve)
```gdscript
const FLOATER_GRAVITY_SCALE: float = 0.3
const CLIMB_SPEED: float = 40.0

# runtime-resolved. _ready()에서 ancestor chain 스캔으로 StageLayoutBuilder.layout.cell_size + 4 로 갱신.
# 미발견 시 36.0(=32+4) 유지. (Stage01~03이 모두 cell_size=32이므로 fallback이 정확.)
var mantle_distance: float = 36.0

var traits: Dictionary = {}   # StringName(name) → true. 빈 dict = 트레잇 없음.

func _ready() -> void:
    ...
    _resolve_mantle_distance()
    ...

func _resolve_mantle_distance() -> void:
    # ancestor chain 스캔 — global 그룹 lookup 미사용 (Round 3 MEDIUM 대응, scope-safe).
    # ant의 부모를 따라 올라가며 각 ancestor 노드 아래에 "StageLayoutBuilder" 자식이 있는지 확인.
    # 첫 매치된 builder의 layout.cell_size 사용. layout이 null이면 다음 ancestor 시도.
    var node: Node = self
    while node != null:
        var b: Node = node.get_node_or_null("StageLayoutBuilder")
        if b != null:
            var layout: Resource = b.get("layout") as Resource
            if layout != null:
                var cs: Variant = layout.get("cell_size")
                if typeof(cs) == TYPE_INT and int(cs) > 0:
                    mantle_distance = float(cs) + 4.0
                    return
        node = node.get_parent()
    # 모든 ancestor에서 builder 미발견 또는 layout null — default 36.0 유지.

func set_trait(name: StringName) -> void:
    if name == &"":
        return
    traits[name] = true

func has_trait(name: StringName) -> bool:
    return traits.has(name)
```

**ancestor scan 동작 보장**:
- ant.\_ready()는 spawn 시점에 실행. spawn 직전 `_spawn_parent.add_child(ant)`로 ant가 World 아래에 추가됨.
- World 아래에 StageLayoutBuilder 자식이 존재(§8.3 참조). World가 ant의 직접 부모이므로 첫 ancestor 시도(=self)에서 자식 찾기는 실패하고, 두 번째 시도(parent = World)에서 StageLayoutBuilder 자식 발견.
- 헤드리스 다중 scene 또는 stage 전환 중간에 ant가 spawn되더라도 그 ant의 World 부모 = 그 stage의 World이므로 항상 자기 stage의 builder가 잡힘.
- World 위 ancestor(StageRunner의 부모 등)에 다른 builder가 끼어 있을 가능성은 현 코드 구조상 없음(각 stage scene이 독립).

### 3.2 키 화이트리스트
- 본 phase 시점 허용 key: `&"climber"`, `&"floater"`.
- 화이트리스트 enforcement는 코드 레벨에서 강제하지 않는다(가벼움). 잘못된 key는 단순히 `has_trait(...) == false` 결과만 내며, 시뮬레이션은 정상.
- phase 15에서 분배자 + 정착 트레잇 추가 시 같은 dictionary 재사용.

### 3.3 직렬화/지속 (phase 14 시점 무관)
- 본 phase는 트레잇을 spawn 후 set만 한다. 영구. 해제 API 없음.
- SaveData(phase 13)는 ant runtime 트레잇을 저장 안 함(stage progress만 저장). 무영향.

### 3.4 StageLayoutBuilder.gd — v4 무변경
v3에서 `add_to_group("stage_layout_builder")` 추가를 계획했으나, v4에서 ancestor scan으로 전환하면서 group 등록 자체가 불필요. **StageLayoutBuilder.gd는 본 phase에서 손대지 않음.** Round 3 MEDIUM 권고대로 global 채널을 만들지 않는 것이 더 안전.

- ant.\_resolve_mantle_distance()는 ancestor의 자식 노드명 `StageLayoutBuilder`를 직접 찾는다 — `get_node_or_null("StageLayoutBuilder")`.
- 노드명 의존이지만, 본 프로젝트 모든 stage scene에서 builder는 `World/StageLayoutBuilder` 경로의 명시적 노드명을 가짐(Stage01.tscn line 33 검증). 노드명 컨벤션 위반은 별도의 일관성 검증으로 잡힘 (impl 단계 first-run에서 Stage01~03 + dev scene 회귀로 확인).

---

## 4. ClimberState 명세 (v3 — mandatory stall guard 통합)

### 4.1 transition graph
```
WalkerState | CarryingState
   │ is_on_wall() && ant.has_trait("climber")
   ↓
ClimberState (climbing phase, _mantle_offset == -1.0)
   ├── is_on_ceiling() ─────► FallerState (천장 닿음, 등반 불가)
   ├── wall 끝 감지 (test_move(direction*4, 0) == false) ─► mantling phase 진입 (_mantle_offset = 0.0)
   └── (continuing climb) ───► self (loop)

ClimberState (mantling phase, _mantle_offset ≥ 0.0)
   ├── 매 frame: dx = abs(new_x - pre_x). _mantle_offset += dx.
   ├── dx >= STALL_DX_THRESHOLD (0.1) ─► _mantle_stall_frames = 0
   ├── dx <  STALL_DX_THRESHOLD       ─► _mantle_stall_frames += 1
   ├── _mantle_stall_frames >= MANTLE_STALL_LIMIT (10) ─► FallerState (강제 탈출, 무한 stuck 방지)
   ├── _mantle_offset < ant.mantle_distance ─► self (horizontal push 계속)
   ├── _mantle_offset ≥ ant.mantle_distance && is_on_floor() ─► WalkerState 또는 CarryingState (has_candy 분기)
   └── _mantle_offset ≥ ant.mantle_distance && !is_on_floor() ─► FallerState
```

### 4.2 코드 골격 (v3 — mandatory stall guard 통합)
```gdscript
class_name ClimberState extends AntState

# substate flag — -1.0 == climbing(수직 등반), >= 0.0 == mantling(꼭대기 horizontal push)
var _mantle_offset: float = -1.0

# mandatory stall guard — dx==0이 연속 발생하면 FallerState로 강제 탈출.
const STALL_DX_THRESHOLD: float = 0.1   # px/frame. 0.1 미만은 사실상 정지로 본다.
const MANTLE_STALL_LIMIT: int = 10      # frame. 60fps에서 ~0.17s.
var _mantle_stall_frames: int = 0

func enter() -> void:
    var a: Ant = ant as Ant
    if a == null:
        return
    a.velocity = Vector2.ZERO
    _mantle_offset = -1.0
    _mantle_stall_frames = 0

func update(delta: float) -> void:
    var a: Ant = ant as Ant
    if a == null:
        return

    if _mantle_offset < 0.0:
        _update_climbing(a, delta)
    else:
        _update_mantling(a, delta)

func _update_climbing(a: Ant, _delta: float) -> void:
    a.velocity.x = 0.0
    a.velocity.y = -a.CLIMB_SPEED
    a.move_and_slide()

    if a.is_on_ceiling():
        a.state_machine.change_state(FallerState.new())
        return

    # 벽 끝 감지 — 4px 전방 미충돌이면 mantle 진입.
    var wall_probe: Vector2 = Vector2(float(a.direction) * 4.0, 0.0)
    if not a.test_move(a.transform, wall_probe):
        _mantle_offset = 0.0
        _mantle_stall_frames = 0

func _update_mantling(a: Ant, _delta: float) -> void:
    # mantle: 결정적 horizontal push. CLIMB_SPEED 고정(carrying 페널티 무관).
    a.velocity.x = float(a.direction) * a.CLIMB_SPEED
    a.velocity.y = 0.0
    var pre_x: float = a.global_position.x
    a.move_and_slide()
    var dx: float = abs(a.global_position.x - pre_x)
    _mantle_offset += dx

    # MANDATORY stall guard — Round 2 HIGH 대응
    if dx < STALL_DX_THRESHOLD:
        _mantle_stall_frames += 1
        if _mantle_stall_frames >= MANTLE_STALL_LIMIT:
            # 막혀서 mantle 진행 불가 — FallerState로 fall-through.
            a.state_machine.change_state(FallerState.new())
            return
    else:
        _mantle_stall_frames = 0

    # mantle 완료 검사
    if _mantle_offset >= a.mantle_distance:
        if a.is_on_floor():
            if a.has_candy:
                a.state_machine.change_state(CarryingState.new())
            else:
                a.state_machine.change_state(WalkerState.new())
        else:
            a.state_machine.change_state(FallerState.new())
```

### 4.3 의도 (codex Round 3 대응 ready)
- **climbing phase (`_mantle_offset < 0`)**: 벽에 평행 등반. velocity.x = 0, velocity.y = -CLIMB_SPEED.
- **mantling phase (`_mantle_offset >= 0`)**: 결정적 horizontal push. `dx = global_position.x` 변화량을 직접 누적해 collision/slide 결과를 신뢰. velocity.x*delta 계산은 슬라이드/충돌 보정과 어긋날 수 있어 신뢰 X.
- **mandatory stall guard (`_mantle_stall_frames >= 10`)**: dx==0이 10 frame 연속이면 막혀 있어서 더 못 나아간다는 신호. FallerState로 강제 전이해서 무한 mantling 방지. **선택 옵션이 아니라 §4.2 skeleton에 항상 포함** — Round 2 HIGH 직접 대응.
- **wall-end 감지에 `test_move`**: 4px 전방 미충돌 → mantle 진입. RayCast2D 별도 노드 0개.
- **`ant.mantle_distance` (instance var)**: runtime에 `_resolve_mantle_distance()`가 stage_layout_builder 그룹에서 cell_size+4로 갱신. cell_size=32면 36, cell_size=64면 68. cell_size 변경 시 자동 적응. Round 2 MEDIUM 직접 대응.
- **mantle 완료 시 `is_on_floor()` 확인**: corner 직후 floor가 있으면 Walker(or Carrying), 없으면 Faller. 결정적이고 cliff 위 평지/갭 둘 다 자연 처리.
- **has_candy 분기**: Climber 도중 carrying 상태 유지.
- **effective_speed 대신 CLIMB_SPEED 사용**: carrying(0.78×) 페널티가 mantle 시간을 변화시키면 검증이 어려워짐. mantle 시간 결정적.

### 4.4 검증 가능성
- 정상 mantle: cell_size=32일 때 ~0.9초 (36/40 = 0.9s), 60fps × ~54 frame.
- stall mantle: 10 frame stall 검출 후 즉시 FallerState. 60fps × ~10 frame = ~0.17s. 정상 mantle보다 충분히 빠르게 탈출.
- final position 검증: ant.global_position.x가 wall_start_x로부터 (direction × ≥ant.mantle_distance)px 이동했음 + state가 Walker/Carrying/Faller(stall) 중 하나면 PASS.

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
- 현 코드에 fall damage 룰 없음. Floater 도입으로 fall 사망이 회피되어야 한다는 spec(PRD §4 / PROPOSAL §3.1.1)은 phase 17 hazard 룰 도입 시 함께 검증.
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
    # 시각 전용 — 로직 무영향. _physics_process 끝에서 호출.
    if _climber_badge != null:
        _climber_badge.visible = has_trait(&"climber")
    if _floater_badge != null:
        _floater_badge.visible = has_trait(&"floater")
```

### 7.3 _physics_process 갱신
`_update_sprite()` 호출 직후 `_update_trait_badges()` 호출. 둘 다 시각-only.

### 7.4 SVG 자산
- climber.svg / floater.svg는 `assets/icons/skills/`에 phase 9에서 이미 임포트됨. 본 phase는 자산 신규 X.
- `tests/SvgImportSmokeTest.gd`의 `PRODUCTION_SVGS` 갱신 — impl 단계에서 확인 후 누락 시 1줄 추가.

---

## 8. dev 검증 stage (D5 / D7) — v3 명세 (Stage02/03 패턴 + SkillToolbar)

### 8.1 레이아웃 개념도
```
   ┌──────────────┐  <- 절벽 위 평지 (사탕 위치)
   │  Candy   ┌──┴
   │          │ ◀ 절벽 (높이 6셀, 32px*6=192px)
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
[gd_resource type="Resource" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/core/StageData.gd" id="1"]
[resource]
script = ExtResource("1")
id = 901
display_name = "dev-trait-test"
total_ants = 6
candy_hp = 6
time_limit_seconds = 180.0
available_skills = ["climber", "floater"]
skill_inventory = { "climber": 3, "floater": 3 }
release_rate_initial = 30
release_rate_min = 1
# NOTE: StageData에는 layout 필드 없음. dev_trait_test_layout.tres는
# scenes/stages/dev/TraitTest.tscn 안의 World/StageLayoutBuilder.layout으로 직접 wiring.
```

### 8.3 scenes/stages/dev/TraitTest.tscn — 노드 구조 (Stage02/03 패턴 + StageLayoutBuilder)
```
[gd_scene format=3]

ext_resource id=1  → scripts/core/StageRunner.gd
ext_resource id=2  → scripts/core/AntSpawner.gd
ext_resource id=3  → scenes/entities/Home.tscn
ext_resource id=4  → scenes/entities/Candy.tscn
ext_resource id=4_mx7fg → scripts/world/Terrain.gd
ext_resource id=5  → scenes/entities/Ant.tscn
ext_resource id=6  → scenes/ui/HUD.tscn
ext_resource id=6_hwgo4 → scripts/world/Home.gd
ext_resource id=7  → data/stages/dev/trait_test.tres
ext_resource id=8  → scenes/ui/SkillToolbar.tscn          # ← v3 MEDIUM fix (Stage02/03 패턴)
ext_resource id=8_s25jr → scripts/world/Candy.gd
ext_resource id=9  → scenes/world/StageBackground.tscn
ext_resource id=12_mcttg → scripts/ui/HUD.gd
ext_resource id=13_layout_builder → scripts/world/StageLayoutBuilder.gd
ext_resource id=14_dev_layout → data/stage_layouts/dev_trait_test_layout.tres

[node "StageRunner" Node]
  script = ExtResource(1)
  stage_data = ExtResource(7)                # dev trait_test.tres
  candy_path = NodePath("World/Candy")
  home_path = NodePath("World/Home")
  spawner_path = NodePath("Spawner")
  hud_path = NodePath("HUD")
  toolbar_path = NodePath("SkillToolbar")    # ← v3 MEDIUM fix
  ant_scene = ExtResource(5)
  spawn_parent_path = NodePath("World")

[node "World" Node2D]
  [node "StageLayoutBuilder" Node2D]         # ← v2/v3 MEDIUM fix (layout wiring)
    script = ExtResource(13_layout_builder)
    layout = ExtResource(14_dev_layout)
  [node "Terrain" Node2D]
    script = ExtResource(4_mx7fg)
  [node "Home" Area2D instance=ExtResource(3)]
    position = Vector2(home_x, home_y)       # §8.4 cell_to_world 결과
    script = ExtResource(6_hwgo4)
  [node "Candy" Area2D instance=ExtResource(4)]
    position = Vector2(candy_x, candy_y)
    script = ExtResource(8_s25jr)
    hp = 6
  [node "Camera2D" Camera2D]
    position = Vector2(camera_x, camera_y)

[node "StageBackground" CanvasLayer instance=ExtResource(9)]
  layer = -100

[node "Spawner" Node]
  script = ExtResource(2)
  spawn_position = Vector2(home_x, home_y - 5)
  total = 6

[node "HUD" CanvasLayer instance=ExtResource(6)]
  layer = 10
  script = ExtResource(12_mcttg)

[node "SkillToolbar" parent="." instance=ExtResource(8)]   # ← v3 MEDIUM fix (Stage02/03 패턴)
```

### 8.4 dev_trait_test_layout.tres — cell 좌표표
cell_size = 32. 좌상단 (0,0) 기준 cell 좌표. impl 단계 first-run에서 §8.1 도식 기반으로 정확한 좌표 fine-tune 가능(plan에서는 spec 정확도가 핵심, exact 좌표는 ±2 cell 허용).

| 항목 | cell | world position |
|---|---|---|
| Home (좌측 평지) | (4, 22) | (144, 720) |
| Candy (절벽 위 평지) | (28, 16) | (912, 528) |
| Camera | (16, 19) | (528, 624) |
| 좌측 평지 (Home 영역) | (2,22)~(7,22) | y=22 line |
| 1번 갭 | (8,22)~(11,22) 비움 | (갭) |
| 절벽 하단 | (12,22)~(20,22) | y=22 line, 절벽 base |
| 절벽 우측 벽 | (20,16)~(20,22) | x=20 column, y=16~22 (높이 6셀) |
| 절벽 위 평지 (Candy 영역) | (20,16)~(34,16) | y=16 line |
| 우측 추락 절벽 | (35,16) 비움, drop to (35,22)~ | floater 검증 갭 |
| 우측 평지 | (36,22)~(42,22) | 귀환로 |

### 8.5 메뉴 노출 0 검증 — impl TBD-1
- StageSelect(phase 13)가 `data/stages/`만 스캔하는지 vs `data/stages/dev/`도 재귀 스캔하는지 — impl 첫 task로 코드 확인.
- 만약 재귀 스캔이면, dev/ 폴더 또는 id ≥ 900을 무시하는 1줄 패턴 추가.

---

## 9. 시그널 흐름

### 9.1 본 phase 신규 시그널 = 0개
- EventBus 무변경. 트레잇 부여는 ant.set_trait() 직접 호출 — 시그널 불필요.

### 9.2 기존 시그널 재사용
- `EventBus.action_triggered(name: StringName)` — SkillToolbar가 슬롯 click 시 발화 → StageRunner._on_action → `_try_assign(skill_id)` → SkillRegistry.get_skill(id).new().apply(ant).
- climber/floater도 동일 경로 진입. 별도 hook 0개.

### 9.3 _physics_process 흐름 (Ant)
```
_physics_process(delta):
  state_machine.update(delta)        # 기존
  _update_sprite()                   # 기존
  _update_trait_badges()             # 신규 — 시각-only
```

### 9.4 _ready() 초기화 흐름 (Ant)
```
_ready():
  _grace_until = ...
  add_to_group("ants")
  state_machine = $StateMachine
  state_machine.ant = self
  _blocker_hitbox = get_node_or_null("BlockerHitbox") as Area2D
  _sprite = get_node_or_null("Sprite") as AnimatedSprite2D
  _trait_badges = get_node_or_null("TraitBadges") as Node2D
  ...badge nodes
  _resolve_mantle_distance()         # 신규 (v4) — ancestor chain scan
  state_machine.change_state(WalkerState.new())
```

---

## 10. 엣지 케이스 (PROPOSAL §3.1.4 + 본 plan 분석)

| # | 시나리오 | 처리 결정 | 검증 위치 |
|---|---|---|---|
| E1 | Climber + Floater 동시 보유. 벽 등반 중 천장 닿음 → Faller 진입 → Floater 효과로 느린 낙하 | climbing phase의 `is_on_ceiling()` 시 FallerState 전이. FallerState가 has_trait("floater") 확인 | TraitCombinedTest |
| E2 | Carrying 상태에서 climber 부여 → 벽 만남 → ClimberState. has_candy 보존 → 꼭대기 mantle 후 CarryingState 복귀 | ClimberState mantle 완료 시 has_candy 분기 | ClimberTraitTest (carry variant) |
| E3 | 벽 등반 도중 has_trait("climber")가 빠지면? | 본 phase에서 트레잇 해제 API 없음 (영구). | (N/A) |
| E4 | Floater 부여 시점이 Faller 도중 | can_apply는 is_alive() 통과면 허용. 다음 tick부터 gravity 0.3배 적용 | FloaterTraitTest (apply-mid-fall variant) |
| E5 | climber 부여한 ant가 spawn_grace 중 벽 만남 | WalkerState `_frame > 1`까지 idle. grace 끝나고 첫 wall 충돌 시 정상 전이 | ClimberTraitTest (spawn-near-wall variant) |
| E6 | climber ant가 등반 중 다른 ant와 충돌 | Ant끼리 layer 4로 무시. 영향 없음 | (코드 검증) |
| E7 | climber ant가 등반 도중 blocker hit | ClimberState velocity.x=0이라 direction flip 무영향 | (코드 검증) |
| E8 | floater ant가 Home 위 자유낙하로 직접 도달 | FallerState는 is_on_floor() 시 WalkerState. Home Area2D trigger되면 SavedState. floater는 gravity만 0.3배 | (Stage 02/03 회귀 PASS로 간접 검증) |
| E9 | 트레잇 시각 표식이 sprite 위 z-order 충돌 | TraitBadges z_index=1, Sprite=0 | 에디터 수동 확인 |
| E10 | release rate 슬라이더 + 트레잇 부여 인터럽트 | release_rate는 spawn 간격만 제어. 트레잇은 spawn 이후 부여. 무관 | (기존 회귀로 간접 검증) |
| E11 | mantle 진행 중 ant가 다시 wall에 부딪힘 (두께 2 cell 벽 꼭대기) | climber trait 유지 → mantling 완료 → Walker/Carrying → 다음 frame `is_on_wall()` true → 재 ClimberState 진입. 정상 | (이론적 검증) |
| E12 | mantle 도중 dx==0 무한 (벽이 너무 두꺼워 mantling 중 wall에 다시 막힘) | **§4.2 mandatory stall guard**: dx<0.1이 10 frame 연속이면 FallerState로 강제 탈출. 무한 stuck 불가능 | **ClimberStallTest** (v3 신규) |
| E13 (v3 신규) | dev/main 외 layout이 cell_size != 32로 추가됨 (phase 15+) | Ant._resolve_mantle_distance()가 runtime에 cell_size+4로 mantle_distance 갱신. cell_size=64면 mantle_distance=68 자동 적용 | (이론적, phase 15+에서 검증) |
| E14 (v3 신규 / v4 갱신) | ant의 ancestor에 StageLayoutBuilder가 없음 (예: stage가 builder 없이 직접 collision body 배치) | _resolve_mantle_distance() 모든 ancestor 시도 실패 → mantle_distance=36.0 default 유지. cell_size=32 stage라면 정확, 다른 cell이면 부정확. 현 코드의 모든 stage가 World/StageLayoutBuilder + cell_size=32 사용하므로 안전 | (Stage01~03 회귀 PASS로 간접 검증) |
| E15 (v4 신규) | ant가 헤드리스 다중 scene 환경에서 spawn (예: 두 stage가 동시에 SceneTree에 존재) | ancestor scan은 ant의 직접 부모를 따라가므로 자기 stage의 builder만 발견. 다른 stage의 builder는 ancestor가 아니라 스캔 범위 밖. Round 3 MEDIUM 직접 대응 | (이론적 — 현 코드는 단일 stage scene만 사용) |

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
python scripts/run_test.py tests/ClimberStallTest.tscn          # 신규 (v3) — mandatory stall guard 증명
```

### 11.2 헤드리스 신규 — PASS 기준 (v3)
- **ClimberTraitTest**: 30초 내
  1. 첫 climber ant의 global_position.y가 wall 꼭대기 위로 도달
  2. ant의 global_position.x가 wall 진입 시점 대비 (direction × ≥ ant.mantle_distance) 이동
  3. 마지막 3 physics frame 동안 state가 Walker 또는 Carrying 유지 (looping 방지)
- **FloaterTraitTest**: 첫 floater ant가 Faller 진입 후 5 frame velocity.y 평균 증가율 ≤ `gravity * delta * 0.4`
- **TraitCombinedTest**: ant 한 마리에 climber+floater 부여 → 등반 중 천장 도달 → Faller 진입 → velocity.y 평균 증가율 ≤ 0.4× gravity
- **ClimberStallTest (v3 신규)**: 두꺼운 벽(4 cell 두께, 벽 꼭대기에 ceiling overhang 가까이) 시나리오. climber ant가 wall 끝 감지 후 mantling 진입 → dx==0 stall 발생 → 10 frame 후 FallerState 전이. **PASS = ClimberState 진입 후 ≤ 30 frame 안에 mantling phase 진입 (_mantle_offset >= 0) + 10~25 frame 사이에 FallerState 전이 + 최종적으로 ant가 ClimberState에 남아있지 않음. FAIL = 60 frame 이상 ClimberState 유지**
  - 헤드리스 layout: `data/stage_layouts/dev_stall_test_layout.tres` (별도) — 4 cell 두께 + 천장이 mantle 진행을 막는 형태
  - 또는: ClimberStallTest scene 안에 인라인 collision body로 구성 (별도 layout 없이)
  - impl 단계에서 결정 — 어느 쪽이든 PASS 기준만 충족

### 11.3 에디터 수동
```
1. scenes/stages/dev/TraitTest.tscn 열고 F6 실행
2. SkillToolbar에 climber/floater 아이콘 표시 + 인벤토리 카운트 확인
3. ClimberSkill 1회 부여 → ant가 절벽 등반 → mantle → 평지에 안정 착지
4. FloaterSkill 1회 부여 → ant가 갭 추락 시 느린 낙하 + 일정 위치 착지
5. 두 스킬 부여한 ant → 절벽 등반 + 평지 끝 추락 시 느린 낙하 + Home 도착 → Saved
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
- **본 phase 신규 코드는 ban 단어 0건**. ClimberSkill/FloaterSkill/ClimberState/Ant.gd/StageLayoutBuilder.gd 변경 모두 ant motion/visual/layout 묘사만 — 페일 어휘 무관.
- **기존 코드 잔존 ban (DeadState 등)**: PROPOSAL §7.5에 따라 본 phase 미수정. phase 17 hazard 본문 작성 시 일괄 처리.
- impl 단계에서 `python scripts/check_tone_policy.py --commit3` 실행 — 본 phase 변경 파일 한정으로 PASS 확인.

---

## 13. 자체 적대적 리뷰 — Plan v3 self-check

> CLAUDE.md plan-stage 정책상 plan 자체 적대적 리뷰는 의무 X (impl stage 한정). 그러나 codex plan-stage 재호출 전 미리 점검.

### 13.1 점검 차원
- **변경 폭**: 신규 3 .gd + 수정 5 .gd + .tscn 1 + dev stage 3 + tests 4. 적정.
- **회귀 위험**: WalkerState/CarryingState 분기 추가 1줄씩. has_trait("climber") false면 기존 코드 fall-through. Stage01~03 회귀 무영향(트레잇 dict 빈 dict + mantle_distance 36 default가 cell_size=32에 정확).
- **CLAUDE.md CRITICAL 준수**: SkillRegistry.SKILL_SCRIPTS preload 추가 OK. `scripts/{core,ant,skills,world,ui}/` 위치 준수. Area2D mask 변경 없음.
- **4-카운터 무영향**: 트레잇 부여는 ScoreSystem 카운터 외. ADR-002 spec 보존.
- **cross-doc 일관성**: PROPOSAL §3.1 / §3.1.2 / §3.1.4 모두 인용. phase 15에서 같은 traits dict + mantle_distance 채널 재사용 약속.
- **숨은 가정 표면화 (v3)**:
  - (A) StageSelect가 `data/stages/dev/`를 스캔하지 않는다 — impl §14-TBD-1 첫 검증.
  - (B) climber.svg/floater.svg가 ant 시각 표식에 24×24 적정 크기로 보임 — 에디터 수동 확인.
  - (C) cell_size = 32 invariant — Stage01~03 + dev 모두 32. fallback 36.0이 정확. cell_size 변경 시 runtime resolve.
  - (D) TraitTest.tscn StageLayoutBuilder가 layout을 받고 _ready()에서 build() 호출 시 collision body 생성 — Stage01.tscn 패턴 검증됨.
  - (E) (v3 신규) builder._ready()가 ant._ready()보다 먼저 실행 — scene tree depth-first 순서로 World가 Spawner보다 먼저, builder가 World 안에 있고 Spawner 안의 Ant들은 spawn 후에 add_child되므로 항상 builder 우선. 안전. (v4: ancestor scan은 group 등록 타이밍 무관, builder 노드의 존재만 확인하므로 더욱 안전)
  - (F) (v3 신규) ClimberStallTest의 "막힌 corner geometry"가 실제 mantle stall 시나리오를 재현 — impl 단계 first-run 시 stall이 실제 발생하는지 확인. 발생 안 하면 layout fine-tune.
  - (G) (v4 신규) 모든 stage scene에서 builder 노드명이 정확히 "StageLayoutBuilder"인지 — Stage01.tscn line 33 검증됨. dev scene도 §8.3에 명시. Stage02/03도 동일 노드명 가정(impl first-run에서 grep 확인). 노드명이 다르면 fallback 36.0 적용되므로 cell_size=32 stage라면 정상 동작, cell_size 다른 stage가 추가되면 그때 발견 가능.

### 13.2 self-found risks (v3)
| sev | 항목 | 처리 |
|---|---|---|
| LOW | StageSelect가 dev/ 스캔하면 메뉴에 노출 | impl §14-TBD-1로 검증, 노출되면 dev/ 또는 id ≥ 900 skip 1줄 추가. |
| LOW | TraitBadges가 ant flip(flip_h)에 따라 좌우 반대 | TraitBadges는 Sprite 자식 아닌 Ant 자식. flip_h 무관. 정상. |
| LOW | floater 부여 ant가 Worker 상태에서 set_trait → 작업 끝 후 fall 진입 시 정상 적용 | FallerState 매 frame has_trait 체크. 정상. |
| LOW | dev_trait_test_layout cell 좌표가 §8.4 표와 실제 시각이 다를 수 있음 | impl first-run에서 시각 확인 후 ±2 cell tune. |
| LOW | ClimberStallTest layout 설계가 실제 stall을 못 트리거 | impl first-run에서 검증. dx==0 stall이 안 일어나면 벽 두께/천장 위치 조정. PASS 기준은 "stall→Faller 전이"이므로 stall 자체가 안 일어나면 테스트 의미 X. |
| LOW | builder ancestor가 발견되어도 layout이 null일 수 있음 | _resolve_mantle_distance() null guard 있음, 다음 ancestor 시도. 모두 실패 시 fallback 36.0. |
| LOW (v4 신규) | Stage02/03 noted-but-not-verified — builder 노드명 일관성 | impl first-run에서 grep으로 Stage01~03 + dev 모두 "World/StageLayoutBuilder" 노드명 사용 확인. 일관 안 되면 별도 fix. |

---

## 14. TBD (impl 단계에서 첫 검증)

1. StageSelect.gd가 `data/stages/dev/`를 자동 스캔하는지 — impl 첫 task로 코드 확인. 노출되면 무시 로직 추가.
2. SvgImportSmokeTest.PRODUCTION_SVGS에 climber/floater 이미 포함 여부 확인 — 누락 시 추가.
3. dev_trait_test_layout cell 좌표 §8.4 표를 stage01_layout 포맷으로 작성 후 에디터에서 시각 확인 → ±2 cell tune.
4. ClimberStallTest의 stall geometry 설계 — impl first-run에서 dx==0 실제 발생 확인 → 발생 안 하면 벽 두께/천장 거리 fine-tune.

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
  tests/ClimberStallTest.tscn / .gd                                    # v3 신규
  (조건부) data/stage_layouts/dev_stall_test_layout.tres               # v3 신규 — 외부 layout 선택 시
  phases/mvp/plans/phase14-plan.md (본 문서)
  phases/mvp/reviews/phase14-review.md (codex plan stage Round 1+2+3)
  phases/mvp/reviews/phase14-impl-review.md (codex impl stage + self-review rounds)

수정:
  scripts/ant/Ant.gd
  scripts/ant/states/WalkerState.gd
  scripts/ant/states/CarryingState.gd
  scripts/ant/states/FallerState.gd
  scripts/core/SkillRegistry.gd
  scenes/entities/Ant.tscn
  # v4: scripts/world/StageLayoutBuilder.gd 무변경 (ancestor scan 채택, group 등록 폐기)
  phases/mvp/notion-phase-ids.json (phase 14 진입 동기화)
  phases/mvp/status.json (execute.py 자동 갱신)
  (조건부) scripts/ui/StageSelect.gd — dev/ 스킵 (impl TBD 1 결과에 따라)
  (조건부) tests/SvgImportSmokeTest.gd — PRODUCTION_SVGS 추가 (impl TBD 2 결과에 따라)
```

deny-list 매치 없음(.git/.godot 제외). large_change_ok=false 유지 — 변경 파일 수 < 100, 단일 5MB / 합계 25MB 한참 이하.

---

## 16. 다음 단계 (impl 시작 전)

1. **codex plan-stage adversarial-review Round 4** — `/codex:adversarial-review --wait "phase 14 plan v4: ancestor-scoped builder resolution replaces group lookup; StageLayoutBuilder.gd untouched; all other v3 fixes intact"`
2. HIGH 0건 → impl 진입. HIGH 1건 이상 → 즉시 중단 + 사용자 결정 (CLAUDE.md plan-stage policy).
3. impl 시작 순서:
   - TBD 1 (StageSelect dev/ 스킵) 확인
   - (v4: StageLayoutBuilder 무변경 — skip)
   - Ant.gd 인터페이스 (traits dict + const 2개 + mantle_distance var + _resolve_mantle_distance ancestor scan)
   - SkillRegistry 등록 (preload 2줄)
   - ClimberState + ClimberSkill
   - FloaterSkill + FallerState diff
   - Ant.tscn TraitBadges + Ant.gd _update_trait_badges
   - dev layout + StageData + TraitTest.tscn (StageLayoutBuilder + SkillToolbar wiring 확인)
   - 헤드리스 테스트 4종 (ClimberStallTest 포함)
   - 회귀 헤드리스 PASS 확인
   - 에디터 수동 검증
   - codex impl-stage 리뷰 사이클
