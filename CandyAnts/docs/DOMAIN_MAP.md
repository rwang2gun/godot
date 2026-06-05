# DOMAIN MAP — 객체 · 스킬 · 레벨별 파일 인덱스

> 목적: "이 객체/스킬/레벨을 만지려면 어떤 파일들을 봐야 하나"를 한눈에. 코드는 레이어(`scripts/{core,ant,skills,world,ui}`)
> 기준으로 배치돼 있어 도메인별로 흩어진다. 이 문서가 그 흩어진 파일들을 도메인 축으로 모아 보여주는 **인덱스**다.
>
> **물리적으로 모은 것**: dev 테스트 레벨 → `dev_stages/<slug>/` (씬+stage.tres+layout.tres 한 폴더). `dev_stages/README.md` 참조.
> **인덱스만 (이동 안 함)**: 스크립트(헌법상 `scripts/` 고정), 메인 스테이지(레벨툴 애드온·SceneFlow 경로 락), 엔티티 씬(23곳 참조). 사유는 맨 아래 "이동하지 않은 것" 참조.
>
> 유지보수: 수동. 객체/스킬/레벨/에셋을 추가하면 해당 섹션 한 줄 갱신.

---

## 1. 객체 타입 (Object Types)

| 객체 | 코드(스크립트) | 씬 | 스프라이트/에셋 |
|---|---|---|---|
| **Ant(개미)** | `scripts/ant/Ant.gd`, `AntState.gd`, `AntStateMachine.gd`, `scripts/ant/states/*.gd` | `scenes/entities/Ant.tscn` | `assets/sprites/characters/ant_pajama_girl/` (`AntFrames.tres` + idle/walk/carry/climb/dig/build/blocker/fall/victory) |
| **Candy(사탕)** | `scripts/world/Candy.gd` | `scenes/entities/Candy.tscn` | `assets/sprites/candy/` (`CandyFrames.tres` + candy_00~05.png) |
| **Home(집)** | `scripts/world/Home.gd` | `scenes/entities/Home.tscn` | `assets/sprites/spawners/ant_hole.png` (집/배달 목표 스프라이트 — `Home.tscn` 직접 참조). ⚠️ `home.svg`는 **미사용 orphan**(import 스모크 테스트만 참조) |
| **Terrain(지형)** | `scripts/world/Terrain.gd`, `CookiePlatformVisual.gd`, `StageLayoutBuilder.gd` | (씬 내 노드) | `assets/sprites/terrain/`, `assets/sprites/terrain/usable_square/` · 규칙: `docs/TERRAIN_TILE_RULES.md` |
| **Hazard: Water(소다물)** | `scripts/world/hazards/WaterHazard.gd`, `HazardBase.gd` | `scenes/entities/hazards/Water.tscn` | `assets/sprites/terrain/soda_water.png` |
| **Hazard: Sticky(캐러멜)** | `scripts/world/hazards/StickyHazard.gd`, `HazardBase.gd` | `scenes/entities/hazards/Sticky.tscn` | `assets/sprites/terrain/sticky_caramel.png` |
| **SettlementMarker(정착)** | `scripts/world/SettlementMarker.gd` | `scenes/world/SettlementMarker.tscn` | — |
| **PlacementPreview** | `scripts/world/PlacementPreview.gd` | (씬 내 노드) | — |

상태 머신: `scripts/ant/states/` = Walker / Faller / Carrying / Worker / Climber / Saved / Settled / Lost / Dead.

---

## 2. 스킬 (Skills)

등록: `scripts/core/SkillRegistry.gd` 의 `SKILL_SCRIPTS` 배열(명시 preload). **새 스킬 = 이 배열에 preload 1줄 추가** (CLAUDE.md CRITICAL).
공통 베이스: `scripts/skills/Skill.gd`. 아이콘: `assets/icons/skills/<id>.png`, 커서: `assets/icons/skills/cursors/<id>.png`.

| 스킬 | 스크립트 | dev 테스트 레벨 (`dev_stages/`) | 추가 레이아웃 fixture (`data/stage_layouts/`) | 헤드리스 테스트(`tests/`) |
|---|---|---|---|---|
| **builder** | `BuilderSkill.gd` | `builder_chain/` | — | `tests/*Builder*` |
| **blocker** | `BlockerSkill.gd` | — | — | `tests/*Blocker*` |
| **climber** | `ClimberSkill.gd` | — | — | `tests/Climber*` |
| **floater** | `FloaterSkill.gd` | — | — | `tests/Floater*` |
| **distributor** | `DistributorSkill.gd` | — | — | `tests/Distributor*` |
| **sand_mound** | `SandMoundSkill.gd` | `sand_mound/`, `sand_bridge_overlap/` | — | `tests/SandMound*` |
| **bridge** | `BridgeSkill.gd` | `bridge/`, `bridge_over_overlap/`, `bridge_over_water/`, `bridge_reject/`, `bridge_too_long/`, `sand_bridge_overlap/` | — | `tests/Bridge*` |
| **basher** | `BasherSkill.gd` | `basher_wall/`, `basher_digger_chain/` | `dev_basher_edge_stop_layout.tres`, `dev_earth_plant_separation_layout.tres` | `tests/Basher*` |
| **digger** | `DiggerSkill.gd` | `digger_pillar/`, `basher_digger_chain/` | — | `tests/Digger*` |
| **cutter** (전방 1열씩 최대 5열 march) | `CutterSkill.gd`, `WorkerState.gd`(`_update_cutter`/`_cut_cutter_column`, `Terrain.shatter_plant_column`) | `cutter_vine/` | `dev_cutter_edge_stop_layout.tres`, `dev_cutter_over_hazard_layout.tres`, `dev_earth_plant_separation_layout.tres`, `dev_cutter_shatter_vine_layout.tres`, `dev_cutter_wide_vine_layout.tres` | `tests/Cutter*` |
| **leaf_jump** (설치형·재사용 점프대) | `LeafJumpSkill.gd`, `scripts/ant/states/LeafJumpState.gd`(포물선 비행·낙하 모션) (+`scripts/world/SkillSign.gd` 재사용 발동, `Ant.leaf_jump_launch`/`leaf_landing_cell`/`is_jump_immune`/`end_leaf_jump`) | `leaf_jump/` | — | `tests/LeafJumpSignTest*` |

> "추가 레이아웃 fixture"는 씬이 없고 `tests/*.gd`가 `preload`로 직접 로드하는 레이아웃이라 `data/stage_layouts/`에 잔류(클러스터 아님).

---

## 3. 레벨 (Levels)

### 3.1 메인 스테이지 — ⚠️ 경로 락 (이동 금지)
`SceneFlow.gd`의 `STAGE_SCENES` dict + 레벨툴 애드온(`addons/candyants_level_tool/level_tool_dock.gd`)이 `stage%02d` 패턴으로 하드코딩. 폴더 이동 시 둘 다 깨짐.

| 레벨 | 씬 | StageData | Layout |
|---|---|---|---|
| Stage01 | `scenes/stages/Stage01.tscn` | `data/stages/stage01.tres` | `data/stage_layouts/stage01_layout.tres` |
| Stage02 | `scenes/stages/Stage02.tscn` | `data/stages/stage02.tres` | `data/stage_layouts/stage02_layout.tres` |
| Stage03 | `scenes/stages/Stage03.tscn` | `data/stages/stage03.tres` | `data/stage_layouts/stage03_layout.tres` |

라우팅/진행: `scripts/core/SceneFlow.gd`. 레벨 에디터(Godot dock): `addons/candyants_level_tool/` — `run_level_editor.bat`(또는 `python scripts/run_editor.py`)로 프로젝트를 에디터로 열어 하단 패널 `CandyAnts Level` 사용. (구 Node 웹 에디터 `tools/map_editor/`는 9종 스킬 미지원으로 데이터 유실을 일으켜 제거됨 — 스테이지 편집은 Godot dock만 사용)

### 3.2 dev 테스트 레벨 — ✅ 콜로케이트됨 (`dev_stages/<slug>/`)
각 폴더 = `씬.tscn` + `stage.tres`(StageData) + `layout.tres`(StageLayoutData). 실행: `python scripts/run_test.py dev_stages/<slug>/<Scene>.tscn`.

| slug | 씬 | 주 도메인 |
|---|---|---|
| `basher_wall` | BasherWallTest.tscn | basher |
| `basher_digger_chain` | BasherDiggerChainTest.tscn | basher · digger |
| `digger_pillar` | DiggerPillarTest.tscn | digger |
| `cutter_vine` | CutterVineTest.tscn | cutter |
| `builder_chain` | BuilderChainStage.tscn | builder (계단 끝 낭떠러지 체인 건설) |
| `bridge` | BridgeTest.tscn | bridge |
| `bridge_over_overlap` | BridgeOverOverlapTest.tscn | bridge |
| `bridge_over_water` | BridgeOverWaterTest.tscn | bridge · water |
| `bridge_reject` | BridgeRejectTest.tscn | bridge |
| `bridge_too_long` | BridgeTooLongTest.tscn | bridge |
| `sand_mound` | SandMoundTest.tscn | sand_mound |
| `sand_bridge_overlap` | SandBridgeOverlapTest.tscn | sand_mound · bridge |
| `water` | WaterTest.tscn | water hazard |
| `water_after_candy` | WaterAfterCandyTest.tscn | water hazard |
| `water_sticky_overlap` | WaterStickyOverlapTest.tscn | water · sticky |
| `leaf_jump` | LeafJumpTest.tscn | leaf_jump · sticky (점프대로 끈끈이 넘기) |
| `sticky` | StickyTest.tscn | sticky hazard |
| `sticky_settle` | StickySettleTest.tscn | sticky · settlement |
| `settle` | SettleTest.tscn | settlement |
| `settle_race` | SettleRaceTest.tscn | settlement |
| `settle_stuck` | SettleStuckTest.tscn | settlement |
| `trait` | TraitTest.tscn | trait adaptation |

> 레벨 재설계 rev2 **S1 "첫 마실"은 `scenes/stages/Stage01.tscn`(stage01 슬롯)으로 통합**됨(구 dev 초안 `campaign_s1_first_outing` 삭제). 검증은 `tests/CampaignS1{Clear,NoClimber}Test.tscn`(→ Stage01.tscn instance). 진척 SoT는 `docs/LEVEL_REDESIGN_STATUS.md`.

> 주의: 같은 메커니즘을 여러 `tests/*.tscn` 헤드리스 테스트가 위 dev 씬을 인스턴스로 재사용한다(예: `tests/TraitCombinedTest.tscn` → `dev_stages/trait/TraitTest.tscn`). dev 씬을 옮기거나 이름 바꾸면 `tests/`의 `ext_resource` 경로도 함께 갱신해야 한다.

---

## 이동하지 않은 것 (사유)

| 대상 | 사유 |
|---|---|
| `scripts/**` | CLAUDE.md CRITICAL — 신규 스크립트는 `scripts/{core,ant,skills,world,ui}/` 고정. autoload 7종·`SkillRegistry` preload가 경로 의존. |
| 메인 스테이지 3종 | 레벨툴 애드온 + `SceneFlow.gd`가 `stage%02d` 패턴 하드코딩. 애드온은 별도 codex 트랙(`codex-worklog/map-editor/`). |
| 엔티티 씬 (`scenes/entities/`) | 각 23개 스테이지 씬이 `res://` 절대경로로 참조. 이동 시 23+곳 재작성 위험 대비 이득 낮음(스크립트는 어차피 `scripts/`에 잔류). |
| `theme/`, `project.godot` autoload, `data/menu_layout.tres` | 엔진/프로젝트 설정에 경로 하드코딩. |
| orphan dev 레이아웃 4종 | 씬 없이 `tests/*.gd` preload 전용 → `data/stage_layouts/`에 잔류(§2 참조). |
