# Phase 13 Plan — ui-title-menu (v2)

**Status**: plan v2 (Round 1 codex review HIGH 2 + MEDIUM 4 + LOW 1 모두 반영. v1 → v2 diff = §1의 Δ9~Δ11 신규 + §3.5/3.6/3.9 수정 + §5.1 테스트 케이스 추가)
**Plan-as-SoT 채택**: phase 11~12 lesson 그대로 적용. 본 plan이 1차 SoT, `phases/mvp/phase13-ui-title-menu.md`(이하 "구 frontmatter doc")는 plan stabilize 후 slim pointer로 격하 가능.
**Related SoT**: `docs/UI_GUIDE.md` §3.5·§3.6 (LogoPanel/StageSlotCard atom — phase 13에서 작성) · §5 (SaveData 스키마, migration hook) · §5.3 (`Scoring.compute_stars` freeze, phase 12 owner, 본 phase에서 호출만) · §6 (카피 가이드). `docs/INPUT_PLAN.md` §1·§4 (Esc / back_menu — **본 phase에서 dialog-local 채택 확정, InputMap entry 추가 안 함**). `docs/design_handoff/README.md` (logo·illustration 시각 reference).
**Inputs frozen from prior phases**:
- Motion sig (phase 9): `caPop / boop / idle_bob / fade_in(pause_safe) / fade_out(pause_safe)`
- Theme (phase 9): `theme/candyants.tres`, Tokens.gd
- CButton/Chip/Counter/SkillSlot atom API (phase 10)
- Scoring.compute_stars (phase 12 owner) — SaveData가 호출만
- EventBus 시그널: `stage_cleared/stage_failed/request_replay/request_next/request_menu/sfx_request/action_triggered/input_mode_changed`
- SceneFlow.gd (phase 6 + phase 12 sweep): `load_stage/load_next_stage/replay_stage/go_to_menu` + `_on_stage_result` overlay 라우팅 + `_freeze/_unfreeze` + RESTART_STAGE 액션 라우터
- InputRouter / GameAction.gd (phase 5~8): **본 phase에서 무수정 (codex review MEDIUM-D — Esc dialog-local 채택)**

---

## 0. 한 줄 요약

Main.tscn 부트 흐름을 `auto-load Stage01` → `TitleScene → MainMenu → StageSelect → Stage(1~3)` 로 바꾼다. 신규 atom 2종(LogoPanel, StageSlotCard) + 신규 씬 3종(TitleScene, MainMenu, StageSelect) + SaveData Autoload + menu_layout.tres + UI 아이콘 SVG. **SceneFlow가 single orchestrator**(=phase 6/12 pattern 유지): screen state enum(`TITLE/MAIN_MENU/STAGE_SELECT/STAGE`)을 노출하고, 각 UI 씬은 `EventBus.request_*` / 새 `EventBus.request_main_menu / request_stage_select / request_play_stage(id) / request_title`로만 전이 요청. project.godot `[application]/run/main_scene`은 **그대로 `res://scenes/Main.tscn` 유지** (외부 부트 경로 단일). SaveData는 EventBus.stage_cleared (→record_clear) + stage_failed (→record_attempt) **둘 다 직접 구독** (strict contract), GameManager는 무수정. **Esc/back은 dialog-local만** (InputRouter 무수정, project.godot `back_menu` entry 미추가). **screen 전환 시 `_unload_current_screen()`은 `remove_child + queue_free` 일괄 적용**으로 stale emit/공존 frame 차단.

---

## 1. 본 plan이 구 frontmatter doc 본문과 다른 지점 + codex Round 1 fix (v2)

| # | 구 doc 본문 / v1 위치 | 본 plan v2 결정 | 근거 |
|---|---|---|---|
| Δ1 | "`project.godot` — main scene을 `Main.tscn` → `TitleScene.tscn`으로 변경" | **`run/main_scene` 무변경**. Main.tscn의 SceneFlow가 부트 시 TitleScene을 `CurrentStageRoot`의 자식으로 instantiate. | GameFlowTest.gd가 Main.tscn을 driver scene 아래 `$Main`으로 인스턴스화 + SceneFlow/StageDialog 노드 lookup에 의존. main_scene 변경 시 회귀 발생. Main.tscn = single entry 보존 |
| Δ2 | "scripts/core/GameManager.gd — SaveData Autoload 사용, 클리어 시 `SaveData.record_clear(...)` 호출" | **GameManager 무수정**. SaveData가 `EventBus.stage_cleared` + `stage_failed` 둘 다 직접 구독. **Strict contract**: stage_cleared → `record_clear` only / stage_failed → `record_attempt` only. cleared=false인 stage_cleared emit은 호출자(StageRunner) 측 위반 — SaveData는 stage_cleared를 받으면 무조건 cleared=true로 record. | GameManager는 phase 1부터 print/validate만. SaveData EventBus subscriber 패턴이 SceneFlow ↔ EventBus precedent과 일관. **codex Round 1 MED-A 응답**: 두 시그널 모두 구독하되 시그널 ↔ recorder 매핑을 엄격 1:1로 |
| Δ3 | "SaveData 스키마 코드 블록의 `record_clear` body" | **본 plan §3.4가 1차 SoT**. UI_GUIDE §5와 충돌 시 본 plan 채택 | `last_played_stage` 갱신을 `record_clear`/`record_attempt` 양쪽에서. Quit 시 `_notification`만 save() — 진행 중 Quit은 stage_progress 무변경 (PRD 스테이지 단위 저장과 호환) |
| Δ4 | "Continue 버튼 disabled" 조건 | 확장: `SaveData.last_played_stage > 0 AND SceneFlow.STAGE_SCENES.has(id) AND SaveData.is_unlocked(id)` 셋 다 만족 시에만 enabled | 향후 stage4~10 점진 추가 + schema downgrade 가능성 + 손상 후 reset 시나리오 대응 |
| Δ5 | "셀렉트 슬롯 10개 중 4~10은 placeholder(잠금)" | 본 plan 명시: `coming_soon` state (잠금과 시각 다름 "준비 중"). `SaveData.is_unlocked`는 순수 progression. slot 사용 가능 여부는 `menu_layout.tres.slots[i].available` flag로 별도. **시각 4 state**: `playable / cleared / locked / coming_soon` | progression unlock과 content existence를 분리해야 stage4 추가 phase가 menu_layout entry toggle 1줄만 |
| Δ6 | "패드 포커스 잃음 — 첫 버튼 자동 grab_focus, 1 frame await" | 매 screen 전이 시 `_swap_screen` 후 새 scene의 `_ready` → `await get_tree().process_frame` → `_grab_initial_focus()` (각 screen 자기 책임) | 패드 모드 포커스 없으면 dead end. mouse 모드에도 focus는 invisible 유지 (focus halo는 hover에만 표시) |
| Δ7 | "InputModeTracker 재사용 → InputHintLabel 사용" | TitleScene 내부 별도 Label + `EventBus.input_mode_changed` 직접 구독. InputHintLabel atom은 HUD 컨텍스트 전용이라 재사용 안 함 | atom 시맨틱 보존 |
| Δ8 | "Settings/Credits stub" | 버튼 enabled + 클릭 시 ComingSoonOverlay show (Card + caPop + 확인 버튼). 새 EventBus signal 없음 (local toggle) | UX 일관성 — 비활성 회색보다 명시적 피드백 |
| **Δ9** ★v2 신규 | v1 §3.5.3 `_unload_current_screen()` = `for child: queue_free()` | **각 자식을 `remove_child(child)` 후 `child.queue_free()` 일괄**. 본 헬퍼는 새 child add 직전에 호출. SceneFlow의 모든 전이 함수(`go_to_*`, `load_stage`)에서 `_swap_screen`/`_unload_current_screen` 호출 직후 즉시 `add_child(new)` 호출 → tree 상 옛 자식·새 자식 공존 frame 0. | **codex Round 1 HIGH-1**: `queue_free()`는 deferred deletion이라 다음 frame까지 tree에 남음. `_unfreeze_current_stage()`가 그 사이 process_mode를 INHERIT으로 풀면 frozen 옛 StageRunner의 `_process`가 1 frame 동안 깨어나 stale `stage_cleared/failed` emit 가능. `remove_child`는 즉시 tree에서 분리 → `_process` 중단 보장. 회귀 가드: `SceneFlowSwapNoStaleEmitTest` |
| **Δ10** ★v2 신규 | v1 §3.6.4 GameFlowTest 회귀 처리 (두 옵션 병기) | **단일 결정**: GameFlowTest/StageDialogEscTest는 `_ready`의 첫 `await get_tree().process_frame` 직후 `_scene_flow.load_stage(1)` + 추가 process_frame×2 await로 stage instantiation 보장. `boot_to_stage_id` export는 **SceneFlowBootBypassTest 전용**(= add_child(main) **전**에 export 설정 후 add_child). GameFlowTest는 export 사용 안 함. | **codex Round 1 HIGH-2**: v1 plan 내 두 경로 병기로 구현자 혼란. 단일 경로 통일. boot_to_stage_id는 export 자체는 유지하되 production 부트는 0, 테스트는 export 검증 전용 1개 |
| **Δ11** ★v2 신규 | v1 §3.9 Esc 라우팅 (InputMap entry 추가 + InputRouter 무수정 — self-contradictory) | **Dialog-local 채택**: `project.godot [input] back_menu` entry **추가 안 함**. InputRouter / GameAction 무수정. 각 screen(TitleScene/MainMenu/StageSelect/ComingSoonOverlay)이 자체 `_unhandled_input`에서 `KEY_ESCAPE`만 직접 처리. StageDialog Esc는 phase 12 산출 그대로 유지. | **codex Round 1 MED-D**: v1 §0/§5의 "InputMap 도입" 언급과 §3.9 "dead placeholder" 결정이 모순. 통일. phase 5~8 freeze 위반 위험 차단. 회귀 가드: `EscNotInActionTriggeredTest` (Esc press → action_triggered emit 0회) |
| **Δ12** ★v2 신규 | v1 §2.6 SaveDataRecordClearTest의 "cleared==false 결과 emit → record_attempt" | **수정**: cleared=false 검증은 `EventBus.stage_failed.emit(result)`로 변경. stage_cleared는 cleared=true 케이스만. SaveData contract와 일치 | codex MED-A 응답. EventBus signal 의미와 1:1 매칭 |
| **Δ13** ★v2 신규 | v1 §3.4.6 test 격리 "_save_path 직접 대입" | **확장**: 본 plan §3.4.7에서 `SaveData._test_reset(path: String)` 헬퍼 + 매 SaveData*Test가 `_ready` 시작 시 호출 + `_exit_tree`에서 cleanup. autoload singleton 오염 0 보장. | codex MED-B 응답. 명시적 setup/teardown |
| **Δ14** ★v2 신규 | v1 §3.6 request_menu vs request_main_menu 경계 미명시 | **명시 + 회귀 가드**: Title/MainMenu/StageSelect의 `.gd`에서 `request_menu` literal 0회 (grep static check). 오직 StageDialog만 legacy `request_menu` emit. SceneFlow는 둘 다 받아 `_on_request_menu = alias of _on_request_main_menu`. 새 테스트: `SceneFlowEmitContractTest` — 각 UI scene의 `.gd` 파일을 `FileAccess`로 읽어 `request_menu` literal 미존재 검증 | codex MED-C 응답 |
| **Δ15** ★v2 신규 | v1 SlotState 분기 테스트가 priority case 누락 | **추가 케이스**: stage1~3 모두 cleared + stage4 available=false → slot4 state == COMING_SOON (PLAYABLE/CLEARED로 fallback 금지). `StageSelectUnlockTest`에 본 케이스 추가 | codex Round 1 LOW |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.tscn)
| 파일 | 용도 |
|---|---|
| `scenes/ui/atoms/LogoPanel.tscn` | UI_GUIDE §3.5. wordmark.svg + mascot.svg 합성. Control wrapping `TextureRect Wordmark + TextureRect Mascot`. idle_bob loop |
| `scenes/ui/atoms/StageSlotCard.tscn` | UI_GUIDE §3.6. 200×140 Card. ShadowBG + Main(cream_100 + 3px ink + 16 radius) + VBox(StageNumber + StarRow + ScoreText + StateBadge) |
| `scenes/ui/TitleScene.tscn` | Control(full anchor). Background + LogoPanel(center) + HintLabel(bottom) + FocusAnchor |
| `scenes/ui/MainMenu.tscn` | Control + VBox 6 버튼 (CButton 인스턴스) + ComingSoonOverlay 인스턴스 |
| `scenes/ui/StageSelect.tscn` | Header(BackBtn+Title) + GridContainer(10 StageSlotCard) + Footer(TotalStars) + ComingSoonOverlay |
| `scenes/ui/ComingSoonOverlay.tscn` | Backdrop + Card(320×160) + Title + Subtitle + CloseBtn |

### 2.2 신규 (.gd)
| 파일 | 변경 폭 |
|---|---|
| `scripts/ui/atoms/LogoPanel.gd` | `class_name LogoPanel extends Control`. export `wordmark/mascot: Texture2D` + `bob_enabled/bob_amplitude/bob_period`. `_ready()` → texture 설정 + bob_enabled 시 `Motion.idle_bob(_mascot_node, ...)` |
| `scripts/ui/atoms/StageSlotCard.gd` | `class_name StageSlotCard extends Button`. **enum SlotState{PLAYABLE,CLEARED,LOCKED,COMING_SOON}**. export `stage_id/slot_state`. 메서드: `set_progress(entry)`, `set_state(s)`. 시각: locked→cream_300+자물쇠, coming_soon→cream_300+"준비 중", playable→cream_100, cleared→cream_100+별점. pressed signal만 emit (외부 라우팅은 StageSelect.gd) |
| `scripts/ui/TitleScene.gd` | `class_name TitleScene extends Control`. `_ready()` → FocusAnchor.grab_focus + InputModeTracker.mode 기반 hint + EventBus.input_mode_changed 구독. `_unhandled_input(event)` → Key/MouseButton/JoypadButton + pressed + !echo → 1회 `EventBus.request_main_menu.emit()` (generation token으로 double-fire 차단). **ESC 무시** (Δ11 — 어차피 아무 키나 진입) |
| `scripts/ui/MainMenu.gd` | `class_name MainMenu extends Control`. `_ready()` → 버튼 connect + `_refresh_continue_state()` + 1 frame await + `_grab_initial_focus()`. 핸들러: Play→`request_play_stage(1)`, Continue→`request_play_stage(last_played)`, StageSelect→`request_stage_select`, Settings/Credits→`_show_coming_soon`, Quit→`get_tree().quit()`. Continue 가드 = Δ4. **ESC 무시** (Δ11 — 실수 종료 방지). **`request_menu` literal 0회 — `request_main_menu`만 사용** (Δ14) |
| `scripts/ui/StageSelect.gd` | `class_name StageSelect extends Control`. `_ready()` → menu_layout.tres 로드 → 10 슬롯 state 결정 + bind + Footer 갱신 + BackBtn grab_focus. 슬롯 pressed: PLAYABLE/CLEARED→`request_play_stage(id)`, LOCKED→`sfx_request(&"sfx:locked")`, COMING_SOON→ComingSoonOverlay.show. BackBtn→`request_main_menu`. **ESC → `request_main_menu` (BackBtn alias, dialog-local)** (Δ11) |
| `scripts/ui/ComingSoonOverlay.gd` | `class_name ComingSoonOverlay extends Control`. show()/hide() API + Motion.fade_in/caPop. CloseBtn pressed → hide. **ESC → hide** (Δ11) |
| `scripts/core/SaveData.gd` | **Autoload**. UI_GUIDE §5 + §3.4. `_ready()` → load_or_init + `EventBus.stage_cleared.connect(_on_stage_cleared)` + `EventBus.stage_failed.connect(_on_stage_failed)`. 메서드: load_or_init/save/record_clear/record_attempt/is_unlocked/get_stage_entry/total_stars/_migrate/_populate_from/_init_fresh. `_notification(WM_CLOSE_REQUEST)` → save. **`_test_reset(path)` test-only 헬퍼** (Δ13) |
| `scripts/core/MenuLayout.gd` | Resource subclass. `class_name MenuLayout extends Resource` + `@export var slots: Array[Dictionary] = []` (length=10 검증 헬퍼) |

### 2.3 수정 (.gd / .tscn / 설정)
| 파일 | 변경 |
|---|---|
| `scripts/core/EventBus.gd` | 4 signal 추가: `request_main_menu / request_stage_select / request_play_stage(stage_id: int) / request_title`. 기존 `request_menu`는 유지 (StageDialog legacy alias, Δ14) |
| `scripts/core/SceneFlow.gd` | (a) `enum ScreenState{TITLE,MAIN_MENU,STAGE_SELECT,STAGE}` + `current_screen` + `@export var boot_to_stage_id: int = 0`. (b) `_ready()`의 `start_game()` → `_boot()`. boot_to_stage_id>0 + STAGE_SCENES.has(id) 시 `load_stage(id)`, 아니면 `go_to_title()`. (c) `_unload_current_screen()` = **`for child: _current_stage_root.remove_child(child); child.queue_free()` 일괄** (Δ9). (d) 신규 핸들러: `_on_request_main_menu/_on_request_stage_select/_on_request_play_stage(id)/_on_request_title`. (e) `go_to_menu()` → `go_to_main_menu()` 호출. (f) screen 전이 4종: `go_to_title/go_to_main_menu/go_to_stage_select/load_stage` + `_swap_screen(new_node, new_state)` 헬퍼. (g) RESTART_STAGE 가드: `current_screen != STAGE` 시 noop |
| `scenes/Main.tscn` | 노드 트리 변경 없음. SceneFlow `current_stage_root_path` 의미 확장 (스테이지+메뉴 공통 컨테이너) — `CurrentStageRoot` 노드 이름 보존 |
| `project.godot` | `[autoload]`에 `SaveData="*res://scripts/core/SaveData.gd"` 1줄 추가 (위치: EventBus 다음, InputRouter 앞 — `_ready` 순서 보장). `[input]` 미변경 — `back_menu` entry 추가 안 함 (Δ11). `run/main_scene` 무변경 |
| `tests/GameFlowTest.gd` | `_ready` 첫 `await process_frame` 직후 `_scene_flow.load_stage(1)` + 2 frame await 추가 (Δ10) |
| `tests/StageDialogEscTest.gd` | 동상 |

### 2.4 신규 assets (SVG, hand-authored, token-only)
| 파일 | 내용 |
|---|---|
| `assets/icons/ui/lock.svg` | 24×24, 자물쇠 polygon+rect, fill ink_900 |
| `assets/icons/ui/unlock.svg` | 24×24, 열린 자물쇠 |
| `assets/icons/ui/arrow_left.svg` | 24×24, 좌측 화살표 polygon |
| `assets/icons/ui/arrow_right.svg` | 24×24, 우측 화살표 |
| `assets/icons/ui/settings.svg` | 24×24, 톱니바퀴 |
| `assets/icons/ui/close.svg` | 24×24, X polygon |

**§0.5 운영 모델**: hand-authored, oklch/class/<style> 미사용 → normalize_svg.py 우회 가능. `SvgImportSmokeTest._PRODUCTION_SVGS` 배열에 6개 추가 (sanity check만).

### 2.5 신규 data (.tres)
| 파일 | 내용 |
|---|---|
| `data/menu_layout.tres` | MenuLayout resource. slots Array[Dictionary] length=10. 1~3 available=true, 4~10 available=false |

### 2.6 신규 tests (.tscn + .gd)
| 파일 | 검증 |
|---|---|
| `tests/SaveDataMigrationTest.{tscn,gd}` | 임시 v0 cfg 작성 → SaveData._test_reset(path) → load → migrate v0→v1 → schema_version==1 + 데이터 보존. _test_reset cleanup |
| `tests/SaveDataCorruptedTest.{tscn,gd}` | (a) garbage cfg → _init_fresh + warn + crash 0. (b) cfg 정상 but stage_progress.1만 garbage → 그 stage entry 0/false reset, stage_progress.2 유지 |
| `tests/SaveDataRecordClearTest.{tscn,gd}` | (a) `EventBus.stage_cleared.emit({saved:8,...,cleared:true,stage_id:1})` → record_clear. best monotonic + attempts. (b) **cleared=false 검증은 `EventBus.stage_failed.emit(result)` 호출 → record_attempt** (Δ12). (c) 중복 emit (같은 stage 두 번 clear) → attempts +1, best monotonic |
| `tests/SaveDataIsUnlockedTest.{tscn,gd}` | stage1 항상 unlocked, N+1은 N.cleared 시. |
| `tests/MenuLayoutResourceTest.{tscn,gd}` | menu_layout.tres 로드 → 10 슬롯 + 1~3 available + 4~10 unavailable |
| `tests/TitleSceneInputTest.{tscn,gd}` | Key/MouseButton/JoypadButton press → request_main_menu emit 1회. 두 번째 입력은 ignore. InputEventMouseMotion은 emit 0회. InputEventKey + echo=true는 emit 0회 |
| `tests/MainMenuNavTest.{tscn,gd}` | 6 버튼 → 적절한 EventBus emit / ComingSoonOverlay show |
| `tests/MainMenuContinueGuardTest.{tscn,gd}` | last_played=0 / 99(미존재) / 2(unlocked) / 2(locked) 4 케이스 |
| `tests/StageSelectUnlockTest.{tscn,gd}` | 4 state 검증 + **stage1~3 cleared + stage4 unavailable → slot4 == COMING_SOON 보호** (Δ15) |
| `tests/SceneFlowScreenStateTest.{tscn,gd}` | Main.tscn 인스턴스 (boot_to_stage_id=0) → TITLE → request_main_menu → MAIN_MENU → request_stage_select → STAGE_SELECT → request_play_stage(1) → STAGE → request_menu → MAIN_MENU |
| `tests/SceneFlowBootBypassTest.{tscn,gd}` | Main.tscn pack instantiate → **add_child 전에 `_scene_flow.boot_to_stage_id = 2` 설정** → add_child → 1 frame → current_screen==STAGE + stage_id==2 (Δ10 명시) |
| `tests/SceneFlowSwapNoStaleEmitTest.{tscn,gd}` | **★HIGH-1 회귀 가드 (Δ9)**. boot_to_stage_id=1 → stage1 진입 → `EventBus.stage_cleared` / `stage_failed` 카운터 0 초기화 → `EventBus.request_main_menu.emit()` → 5 frame await → carryover stale emit 0회 assert. 추가: 같은 흐름에서 process_mode 검증 — 메뉴 진입 후 `_current_stage_root.process_mode == PROCESS_MODE_INHERIT` + 자식 0 |
| `tests/SceneFlowEmitContractTest.{tscn,gd}` | **★MED-C (Δ14)**. `FileAccess.get_file_as_string("res://scripts/ui/TitleScene.gd")` 등 3 파일에서 literal `"request_menu"` 미포함 검증 (split 후 token level — `request_main_menu` 같은 superstring은 통과). 양성 케이스: `scripts/ui/StageDialog.gd`에서 `request_menu` 발견 (legacy 보존 검증) |
| `tests/EscNotInActionTriggeredTest.{tscn,gd}` | **★MED-D (Δ11)**. Main.tscn 부트 + boot_to_stage_id=1 → action_triggered 구독 카운터 → `Input.parse_input_event(InputEventKey(KEY_ESCAPE, pressed=true))` → action_triggered 시그널에 `back_menu`/`skill_cancel` 등 ESC 관련 액션 emit 0회 assert |
| `tests/LogoPanelBobTest.{tscn,gd}` | LogoPanel + bob_enabled=true → 1 frame 후 tween loops_left == -1 (infinite) |
| `tests/StageSlotCardStateTest.{tscn,gd}` | 4 state별 시각 invariant + 자물쇠 visible/hidden |
| `tests/ComingSoonOverlayTest.{tscn,gd}` | show/hide 토글 + caPop 발동 + CloseBtn / ESC 동작 |
| `tests/test_SaveData.gd` (TDD stub) | autoload 존재 + API ping |

### 2.7 회귀 테스트 — 기존 PASS 보존
- `Stage02HeadlessTest.tscn`, `Stage03HeadlessTest.tscn`, `BlockerOverlapTest.tscn` — Main.tscn 미경유 → **무영향**
- `GameFlowTest.tscn` — Main.tscn 경유 → **GameFlowTest.gd._ready에 1줄 추가** (Δ10)
- `StageDialog*Test`들 — 대부분 직접 인스턴스. **`StageDialogEscTest.tscn`만 Main.tscn 경유 → 1줄 추가**
- 모든 Input* / atom / Motion* / Score* / Cursor* 테스트 — 무영향

### 2.8 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/StageRunner.gd`, `ScoreSystem.gd`, `GameManager.gd`, `Scoring.gd`
- `scripts/ui/Motion.gd`, `Tokens.gd`, `StageDialog.gd`, `HUD.gd`, `SkillToolbar.gd`, `PauseBtn.gd`, `ReleaseRateStepper.gd`
- `scripts/ui/atoms/{CButton,Chip,Counter,SkillSlot}.gd`
- `theme/candyants.tres`
- **`scripts/input/*` 전부** (Δ11 — InputRouter/InputModeTracker/CoordSpace/GameAction 등 phase 5~8 산출 freeze)
- `data/stages/*.tres`
- `project.godot [input]` 섹션 (Δ11 — back_menu entry 추가 안 함)

---

## 3. 상세 설계

### 3.1 씬 트리 — TitleScene

```
TitleScene (Control, full anchor, mouse_filter=PASS, PROCESS_MODE_INHERIT)
├─ Background (TextureRect stage_bg.svg, full anchor, expand_mode=KEEP_ASPECT_COVERED, modulate.a=0.4)
├─ Center (CenterContainer, full anchor)
│  └─ VBox (separation 32)
│     ├─ LogoPanel atom (custom_minimum_size 480×280, bob_enabled=true)
│     └─ HintLabel (Label, font Jua 24, color INK_700, text default "아무 키나 눌러 주세요")
└─ FocusAnchor (Control, focus_mode=ALL, custom_minimum_size 1×1, invisible)
   # 패드 _unhandled_input 디스패치 보장. TitleScene._ready에서 grab_focus.
```

> `_unhandled_input` 도달 보장: FocusAnchor.grab_focus → InputEventJoypadButton 등 패드 입력이 focused Control 경유로 routes. mouse motion 이벤트도 viewport input chain의 마지막 (UI Control이 input을 안 받음) → TitleScene._unhandled_input 도달.
> hint 텍스트: `_on_mode_changed(mode)` → mode==&"pad" 시 "버튼을 눌러 주세요", 그 외 "아무 키나 눌러 주세요".

### 3.2 씬 트리 — MainMenu

```
MainMenu (Control, full anchor, PROCESS_MODE_INHERIT)
├─ Background (TextureRect stage_bg.svg, modulate.a=0.3)
├─ Center (CenterContainer)
│  └─ VBox (separation 16)
│     ├─ LogoPanel atom (scale 0.7, bob_enabled=true)
│     ├─ Spacer (Control, custom_minimum_size 0×32)
│     ├─ PlayBtn        (CButton kind=PRIMARY,   text="새 게임",       custom_minimum_size 280×56)
│     ├─ ContinueBtn    (CButton kind=PRIMARY,   text="이어 하기",     custom_minimum_size 280×56)
│     ├─ StageSelectBtn (CButton kind=SECONDARY, text="스테이지 선택", custom_minimum_size 280×56)
│     ├─ SettingsBtn    (CButton kind=GHOST,     text="설정",          custom_minimum_size 280×48)
│     ├─ CreditsBtn     (CButton kind=GHOST,     text="크레딧",        custom_minimum_size 280×48)
│     └─ QuitBtn        (CButton kind=GHOST,     text="종료",          custom_minimum_size 280×48)
└─ ComingSoonOverlay (instance, visible=false)
```

### 3.3 씬 트리 — StageSelect

```
StageSelect (Control, full anchor, PROCESS_MODE_INHERIT)
├─ Background (TextureRect stage_bg.svg, modulate.a=0.3)
├─ MarginContainer (margin 32)
│  └─ VBox (separation 24)
│     ├─ Header (HBox separation 12)
│     │  ├─ BackBtn (CButton kind=GHOST, text="← 메뉴", custom_minimum_size 120×48)
│     │  ├─ Spacer (Control, h_expand)
│     │  ├─ Title (Label Jua 32, INK_900, "스테이지 선택")
│     │  └─ Spacer2 (Control, h_expand)
│     ├─ SlotGrid (GridContainer, columns=5, h_separation 16, v_separation 16)
│     │  └─ StageSlotCard × 10 (instantiated in _ready)
│     └─ Footer (HBox alignment CENTER)
│        └─ TotalStarsLabel (Label Jua 18, INK_700, "수확한 별 ★ 0 / 30")
└─ ComingSoonOverlay (instance, visible=false)
```

### 3.4 SaveData 스키마 + 메서드 (Δ2 strict contract)

#### 3.4.1 ConfigFile (위치 `user://save.cfg`)

```ini
[meta]
schema_version = 1
last_played_stage = 2
created_at = "2026-05-18T10:30:00"
last_saved_at = "2026-05-18T11:45:21"

[stage_progress.1]
cleared = true
best_saved = 8
best_score = 0.80
stars = 2
attempts = 3

[stage_progress.2]
cleared = false
attempts = 1
```

#### 3.4.2 클래스 (autoload, contract strict)

```gdscript
extends Node

const SAVE_PATH := "user://save.cfg"
const CURRENT_SCHEMA := 1

var schema_version: int = CURRENT_SCHEMA
var last_played_stage: int = 0
var stage_progress: Dictionary = {}
var created_at: String = ""
var last_saved_at: String = ""
var _save_path: String = SAVE_PATH

func _ready() -> void:
    load_or_init()
    # Strict contract (codex Round 1 MED-A 응답):
    #   - stage_cleared (cleared=true 정상)  → record_clear
    #   - stage_failed  (cleared=false 정상) → record_attempt
    # 호출자(StageRunner)가 cleared=false인 stage_cleared를 emit하면 본 record_clear가
    # 그대로 받아 cleared=true로 기록 — 이는 StageRunner의 invariant 위반이고, SaveData가
    # 시그널 의미를 자체 검증하지 않는다 (Decoupling).
    EventBus.stage_cleared.connect(_on_stage_cleared)
    EventBus.stage_failed.connect(_on_stage_failed)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        save()

func _on_stage_cleared(result: Dictionary) -> void:
    var stage_id: int = int(result.get("stage_id", 0))
    if stage_id <= 0: return
    record_clear(stage_id, int(result.get("saved", 0)), int(result.get("original_hp", 0)))

func _on_stage_failed(result: Dictionary) -> void:
    var stage_id: int = int(result.get("stage_id", 0))
    if stage_id <= 0: return
    record_attempt(stage_id)

func load_or_init() -> void:
    var cfg := ConfigFile.new()
    var err := cfg.load(_save_path)
    if err != OK:
        if err != ERR_FILE_NOT_FOUND:
            push_warning("[SaveData] cfg load failed err=%d, init fresh" % err)
        _init_fresh()
        save()
        return
    var v: int = int(cfg.get_value("meta", "schema_version", 0))
    if v < CURRENT_SCHEMA:
        _migrate(cfg, v, CURRENT_SCHEMA)
    elif v > CURRENT_SCHEMA:
        push_warning("[SaveData] future schema_version=%d > current=%d, init fresh in-memory" % [v, CURRENT_SCHEMA])
        _init_fresh()
        return
    _populate_from(cfg)

func save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("meta", "schema_version", CURRENT_SCHEMA)
    cfg.set_value("meta", "last_played_stage", last_played_stage)
    cfg.set_value("meta", "created_at", created_at)
    last_saved_at = Time.get_datetime_string_from_system(false, true)
    cfg.set_value("meta", "last_saved_at", last_saved_at)
    for stage_id in stage_progress.keys():
        var section := "stage_progress.%d" % int(stage_id)
        var entry: Dictionary = stage_progress[stage_id]
        for k in entry.keys():
            cfg.set_value(section, str(k), entry[k])
    var err := cfg.save(_save_path)
    if err != OK:
        push_warning("[SaveData] save failed err=%d" % err)

func record_clear(stage_id: int, saved: int, original_hp: int) -> void:
    var stars: int = Scoring.compute_stars(saved, original_hp)
    var score: float = 0.0 if original_hp <= 0 else float(saved) / float(original_hp)
    var entry: Dictionary = _get_or_init_entry(stage_id)
    entry["cleared"] = true
    entry["best_saved"] = max(int(entry.get("best_saved", 0)), saved)
    entry["best_score"] = max(float(entry.get("best_score", 0.0)), score)
    entry["stars"]      = max(int(entry.get("stars", 0)), stars)
    entry["attempts"]   = int(entry.get("attempts", 0)) + 1
    stage_progress[stage_id] = entry
    last_played_stage = stage_id
    save()

func record_attempt(stage_id: int) -> void:
    var entry: Dictionary = _get_or_init_entry(stage_id)
    entry["attempts"] = int(entry.get("attempts", 0)) + 1
    stage_progress[stage_id] = entry
    last_played_stage = stage_id
    save()

func is_unlocked(stage_id: int) -> bool:
    if stage_id <= 1:
        return true
    var prev: Dictionary = stage_progress.get(stage_id - 1, {})
    return bool(prev.get("cleared", false))

func get_stage_entry(stage_id: int) -> Dictionary:
    return stage_progress.get(stage_id, {}).duplicate()

func total_stars() -> int:
    var sum: int = 0
    for entry in stage_progress.values():
        sum += int(entry.get("stars", 0))
    return sum

func _get_or_init_entry(stage_id: int) -> Dictionary:
    if not stage_progress.has(stage_id):
        stage_progress[stage_id] = {
            "cleared": false, "best_saved": 0, "best_score": 0.0, "stars": 0, "attempts": 0,
        }
    return stage_progress[stage_id]

func _init_fresh() -> void:
    schema_version = CURRENT_SCHEMA
    last_played_stage = 0
    stage_progress = {}
    created_at = Time.get_datetime_string_from_system(false, true)
    last_saved_at = created_at

func _populate_from(cfg: ConfigFile) -> void:
    schema_version = CURRENT_SCHEMA
    last_played_stage = int(cfg.get_value("meta", "last_played_stage", 0))
    created_at = str(cfg.get_value("meta", "created_at", Time.get_datetime_string_from_system(false, true)))
    last_saved_at = str(cfg.get_value("meta", "last_saved_at", created_at))
    stage_progress = {}
    for section in cfg.get_sections():
        if not section.begins_with("stage_progress."):
            continue
        var id_str := section.substr("stage_progress.".length())
        if not id_str.is_valid_int():
            push_warning("[SaveData] invalid section %s, skip" % section)
            continue
        var id := id_str.to_int()
        stage_progress[id] = {
            "cleared":    bool(cfg.get_value(section, "cleared", false)),
            "best_saved": int(cfg.get_value(section, "best_saved", 0)),
            "best_score": float(cfg.get_value(section, "best_score", 0.0)),
            "stars":      int(cfg.get_value(section, "stars", 0)),
            "attempts":   int(cfg.get_value(section, "attempts", 0)),
        }

func _migrate(cfg: ConfigFile, from_v: int, to_v: int) -> void:
    for v in range(from_v, to_v):
        match v:
            0: _migrate_0_to_1(cfg)
    cfg.set_value("meta", "schema_version", to_v)
    cfg.save(_save_path)

func _migrate_0_to_1(_cfg: ConfigFile) -> void:
    # v0 = schema_version 키 부재. v0 → v1은 schema_version 추가만 (_migrate 본체에서).
    pass

# ─── test-only (Δ13) ───
func _test_reset(path: String) -> void:
    # Δ13: 테스트에서만 사용. autoload singleton의 _save_path를 임시 격리 경로로 바꾸고
    # in-memory state를 초기화 → load_or_init 호출. 테스트 종료 시 동일 함수로 SAVE_PATH 복귀.
    _save_path = path
    schema_version = CURRENT_SCHEMA
    last_played_stage = 0
    stage_progress = {}
    created_at = ""
    last_saved_at = ""
    load_or_init()
```

#### 3.4.3 Scoring.compute_stars 호출만 — 자체 threshold 없음

UI_GUIDE §5.3 freeze 그대로.

#### 3.4.4 EventBus strict contract (Δ2)

| Signal | Receiver | 호출 |
|---|---|---|
| `stage_cleared(result)` | `_on_stage_cleared` | `record_clear(id, saved, original_hp)` |
| `stage_failed(result)` | `_on_stage_failed` | `record_attempt(id)` |

stage_id<=0 가드만 양쪽 공통. 그 외 시그널 의미 검증은 SaveData 책임 아님.

#### 3.4.5 Quit 시 저장

`NOTIFICATION_WM_CLOSE_REQUEST` → `save()`. 진행 중 stage는 stage_progress 무변경 (스테이지 단위 저장).

#### 3.4.6 테스트 격리 (Δ13)

각 `SaveData*Test._ready()`:

```gdscript
const TEST_PATH := "user://test_savedata_<TEST_NAME>.cfg"
var _orig_path: String

func _ready() -> void:
    _orig_path = SaveData._save_path
    # cleanup any leftover
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    SaveData._test_reset(TEST_PATH)
    await _run_test()
    _cleanup()
    get_tree().quit(0 if not _failed else 1)

func _cleanup() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    SaveData._test_reset(_orig_path)
```

오염 0 보장. 시그널 connect/disconnect는 SaveData._ready/_exit_tree가 처리 (autoload는 게임 동안 살아있으므로 disconnect 호출 안 함 — _test_reset은 in-memory state만 리셋, signal connection 무변경).

### 3.5 SceneFlow screen state 머신 (Δ9 race fix 포함)

#### 3.5.1 state enum

```gdscript
enum ScreenState { TITLE, MAIN_MENU, STAGE_SELECT, STAGE }
var current_screen: ScreenState = ScreenState.TITLE
@export var boot_to_stage_id: int = 0   # SceneFlowBootBypassTest 전용 (Δ10)
```

#### 3.5.2 _ready 흐름

```gdscript
func _ready() -> void:
    _current_stage_root = get_node(current_stage_root_path)
    _overlay = get_node(overlay_path)
    if not virtual_cursor_path.is_empty():
        var cursor: Control = get_node_or_null(virtual_cursor_path) as Control
        if cursor != null:
            InputRouter.set_virtual_cursor(cursor)
    if not cursor_targeting_resolver_path.is_empty():
        _resolver = get_node_or_null(cursor_targeting_resolver_path)

    EventBus.stage_cleared.connect(_on_stage_result)
    EventBus.stage_failed.connect(_on_stage_result)
    EventBus.request_replay.connect(_on_request_replay)
    EventBus.request_next.connect(_on_request_next)
    EventBus.request_menu.connect(_on_request_menu)
    EventBus.request_main_menu.connect(_on_request_main_menu)
    EventBus.request_stage_select.connect(_on_request_stage_select)
    EventBus.request_play_stage.connect(_on_request_play_stage)
    EventBus.request_title.connect(_on_request_title)
    EventBus.action_triggered.connect(_on_action_triggered)

    _boot()

func _boot() -> void:
    if boot_to_stage_id > 0 and STAGE_SCENES.has(boot_to_stage_id):
        load_stage(boot_to_stage_id)
    else:
        go_to_title()
```

#### 3.5.3 screen 전이 함수 + race-free unload (Δ9)

```gdscript
const TITLE_SCENE := "res://scenes/ui/TitleScene.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const STAGE_SELECT_SCENE := "res://scenes/ui/StageSelect.tscn"

func go_to_title() -> void:
    _swap_screen(load(TITLE_SCENE).instantiate(), ScreenState.TITLE)

func go_to_main_menu() -> void:
    _swap_screen(load(MAIN_MENU_SCENE).instantiate(), ScreenState.MAIN_MENU)

func go_to_stage_select() -> void:
    _swap_screen(load(STAGE_SELECT_SCENE).instantiate(), ScreenState.STAGE_SELECT)

func load_stage(stage_id: int) -> void:
    _unload_current_screen()
    _last_result = {}
    if not STAGE_SCENES.has(stage_id):
        push_error("[SceneFlow] unknown stage_id %d" % stage_id); return
    var scene: PackedScene = load(STAGE_SCENES[stage_id])
    var stage_node: Node = scene.instantiate()
    _current_stage_root.add_child(stage_node)
    _current_stage_node = stage_node
    _current_stage_id = stage_id
    current_screen = ScreenState.STAGE
    if _resolver != null and _resolver.has_method("set_active_stage_root"):
        _resolver.set_active_stage_root(stage_node)

func _swap_screen(new_node: Node, new_state: ScreenState) -> void:
    _unload_current_screen()
    _current_stage_node = null
    _current_stage_id = 0
    _last_result = {}
    _current_stage_root.add_child(new_node)
    current_screen = new_state

# Δ9 — race fix: remove_child 즉시 분리 후 queue_free. 옛 자식의 _process가
# 다음 frame에 다시 깨어나 stale emit하는 것 차단. CurrentStageRoot 자체의
# process_mode는 INHERIT 복귀 (모든 자식 분리 후라 safe).
func _unload_current_screen() -> void:
    var children: Array = _current_stage_root.get_children()
    for child in children:
        _current_stage_root.remove_child(child)
        child.queue_free()
    _current_stage_node = null
    # process_mode 복귀 — _freeze_current_stage()로 DISABLED 됐을 수 있음 (stage_cleared 후 StageDialog 표시 중)
    _current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
    if _resolver != null and _resolver.has_method("set_active_stage_root"):
        _resolver.set_active_stage_root(null)
```

#### 3.5.4 핸들러

```gdscript
func _on_request_main_menu() -> void:
    _overlay.hide_overlay()   # idempotent
    go_to_main_menu()

func _on_request_stage_select() -> void:
    _overlay.hide_overlay()
    go_to_stage_select()

func _on_request_play_stage(stage_id: int) -> void:
    _overlay.hide_overlay()
    load_stage(stage_id)

func _on_request_title() -> void:
    _overlay.hide_overlay()
    go_to_title()

func _on_request_menu() -> void:
    # Δ14: legacy alias. StageDialog만 호출. 의미 = main menu 복귀.
    _on_request_main_menu()

func _on_request_next() -> void:
    if not _last_result.get("cleared", false):
        return
    _overlay.hide_overlay()
    load_next_stage()

func _on_request_replay() -> void:
    _overlay.hide_overlay()
    if current_screen == ScreenState.STAGE and _current_stage_id > 0:
        replay_stage()

func load_next_stage() -> void:
    var next_id: int = _current_stage_id + 1
    if not STAGE_SCENES.has(next_id):
        go_to_main_menu()
        return
    load_stage(next_id)

func go_to_menu() -> void:
    go_to_main_menu()
```

> `_freeze_current_stage()`는 phase 12 산출 그대로 (`_overlay.show_result` 호출자가 사용). `_unfreeze_current_stage()`는 메뉴 전이에선 호출 안 함 (대신 `_unload_current_screen()`가 process_mode를 INHERIT으로 복귀하면서 동시에 모든 자식 분리). **명시적 `_unfreeze_current_stage()` 호출은 replay/next/menu fallback 시점만** — 즉 `_on_request_replay/next/menu`에서. 메뉴/select 전이는 unload가 그 책임을 수렴.
>
> 추가 안전: `_unload_current_screen`을 모든 전이 함수가 첫 호출로 사용 → frozen/unfrozen 상태 무관 (process_mode INHERIT 강제 복귀).

#### 3.5.5 RESTART_STAGE 가드

```gdscript
func _on_action_triggered(name: StringName, _payload: Dictionary) -> void:
    if name != GameAction.RESTART_STAGE:
        return
    if current_screen != ScreenState.STAGE:
        return    # 메뉴에서 Ctrl+R 무시 (NEW guard)
    if InputRouter != null and InputRouter.has_method("are_pause_actions_blocked") \
            and InputRouter.are_pause_actions_blocked():
        return
    EventBus.request_replay.emit()
```

### 3.6 시그널 흐름 — 전체 라우팅

| 발화자 | 시그널 | 수신자 | 결과 |
|---|---|---|---|
| TitleScene._unhandled_input | request_main_menu | SceneFlow._on_request_main_menu | TitleScene free + MainMenu instantiate |
| MainMenu.PlayBtn | request_play_stage(1) | _on_request_play_stage(1) | Stage01 load |
| MainMenu.ContinueBtn | request_play_stage(last_played) | 동상 | last_played load |
| MainMenu.StageSelectBtn | request_stage_select | _on_request_stage_select | StageSelect 인스턴스 |
| MainMenu.Settings/CreditsBtn | (local) | `_show_coming_soon()` | overlay visible |
| MainMenu.QuitBtn | (local) | `get_tree().quit()` | exit |
| StageSelect.BackBtn | request_main_menu | _on_request_main_menu | MainMenu 복귀 |
| StageSelect.StageSlotCard (PLAYABLE/CLEARED) | request_play_stage(id) | 동상 | stage load |
| StageSelect.StageSlotCard (LOCKED) | sfx_request(&"sfx:locked") | (phase 21 receiver, 본 phase는 hook만) | 무반응 |
| StageSelect.StageSlotCard (COMING_SOON) | (local) | `_show_coming_soon()` | overlay |
| StageRunner.stage_cleared | stage_cleared(result) | SceneFlow._on_stage_result + **SaveData._on_stage_cleared** (Δ2) | dialog show + record_clear |
| StageRunner.stage_failed | stage_failed(result) | SceneFlow._on_stage_result + **SaveData._on_stage_failed** (Δ2) | dialog show + record_attempt |
| StageDialog.MenuBtn | request_menu | SceneFlow._on_request_menu = alias → _on_request_main_menu | main menu 복귀 |
| StageDialog.NextBtn | request_next | _on_request_next | cleared 검사 후 load_next_stage. last stage clear 시 go_to_main_menu |
| StageDialog.ReplayBtn | request_replay | _on_request_replay | replay_stage |
| InputRouter Ctrl+R | action_triggered(RESTART_STAGE) | _on_action_triggered | current_screen==STAGE 검사 후 request_replay emit |

**Emit 소유권 (Δ14)**:
- `request_menu`: **StageDialog만**. TitleScene/MainMenu/StageSelect/ComingSoonOverlay/SceneFlow에서 emit 금지.
- `request_main_menu`: TitleScene/MainMenu(StageSelectBtn 외)/StageSelect.BackBtn/StageSelect._unhandled_input ESC.
- `request_stage_select`: MainMenu.StageSelectBtn만.
- `request_play_stage(id)`: MainMenu.Play/Continue, StageSelect.StageSlotCard.
- `request_title`: (본 phase 코드에서 발화자 없음 — 향후 phase 추가용 reserved signal)
- `request_replay/next`: StageDialog만 (phase 12 산출).

`SceneFlowEmitContractTest`가 `scripts/ui/TitleScene.gd`, `MainMenu.gd`, `StageSelect.gd`, `ComingSoonOverlay.gd` 4 파일에서 `request_menu` literal 미존재 + `scripts/ui/StageDialog.gd`에서 존재 검증.

#### 3.6.1 TitleScene 입력 처리 (Δ11 ESC dialog-local 채택)

```gdscript
var _input_consumed: bool = false

func _ready() -> void:
    $FocusAnchor.grab_focus()
    _update_hint(_current_mode())
    EventBus.input_mode_changed.connect(_on_mode_changed)

func _unhandled_input(event: InputEvent) -> void:
    if _input_consumed:
        return
    # ESC는 명시적으로 무시 (Δ11). 그 외 키/마우스버튼/조이패드버튼 + pressed + !echo
    if event is InputEventKey and event.keycode == KEY_ESCAPE:
        return
    if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
        return
    if not event.pressed:
        return
    if event is InputEventKey and event.echo:
        return
    _input_consumed = true
    get_viewport().set_input_as_handled()
    EventBus.request_main_menu.emit()

func _current_mode() -> StringName:
    return InputModeTracker.mode if InputModeTracker else &"keyboard"

func _update_hint(mode: StringName) -> void:
    var label: Label = $Center/VBox/HintLabel
    label.text = "버튼을 눌러 주세요" if mode == &"pad" else "아무 키나 눌러 주세요"

func _on_mode_changed(mode: StringName) -> void:
    _update_hint(mode)
```

#### 3.6.2 MainMenu (Continue 가드 + ESC 무시)

```gdscript
func _ready() -> void:
    _connect_buttons()
    _refresh_continue_state()
    await get_tree().process_frame
    _grab_initial_focus()

func _refresh_continue_state() -> void:
    var last_id := SaveData.last_played_stage
    var can_continue := last_id > 0 \
        and SceneFlow.STAGE_SCENES.has(last_id) \
        and SaveData.is_unlocked(last_id)
    $Center/VBox/ContinueBtn.disabled = not can_continue

func _grab_initial_focus() -> void:
    var first: CButton = $Center/VBox/PlayBtn
    if first.is_inside_tree():
        first.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
    # Δ11: ESC는 MainMenu에서 무시 (실수 종료 방지).
    pass

func _show_coming_soon() -> void:
    $ComingSoonOverlay.show()
```

**Δ14 정적 보호**: 본 파일은 `request_menu` literal 미존재. 그 외 `request_*` signal만 emit.

#### 3.6.3 StageSelect (ESC = BackBtn alias)

```gdscript
const LAYOUT_PATH := "res://data/menu_layout.tres"

func _ready() -> void:
    var layout: MenuLayout = load(LAYOUT_PATH) as MenuLayout
    for i in 10:
        var slot_card: StageSlotCard = $.../SlotGrid.get_child(i)
        var meta: Dictionary = layout.slots[i]
        var stage_id: int = int(meta["stage_id"])
        slot_card.stage_id = stage_id
        var entry := SaveData.get_stage_entry(stage_id)
        var state: int = _resolve_slot_state(meta, stage_id, entry)
        slot_card.set_state(state)
        slot_card.set_progress(entry)
        slot_card.pressed.connect(func(): _on_slot_pressed(stage_id, state))
    $.../Footer/TotalStarsLabel.text = "수확한 별 ★ %d / 30" % SaveData.total_stars()
    $.../Header/BackBtn.pressed.connect(func(): EventBus.request_main_menu.emit())
    await get_tree().process_frame
    $.../Header/BackBtn.grab_focus()

func _resolve_slot_state(meta: Dictionary, stage_id: int, entry: Dictionary) -> int:
    # Δ15: priority — coming_soon은 cleared/playable보다 우선.
    if not bool(meta.get("available", false)):
        return StageSlotCard.SlotState.COMING_SOON
    if entry.get("cleared", false):
        return StageSlotCard.SlotState.CLEARED
    if SaveData.is_unlocked(stage_id):
        return StageSlotCard.SlotState.PLAYABLE
    return StageSlotCard.SlotState.LOCKED

func _on_slot_pressed(stage_id: int, state: int) -> void:
    match state:
        StageSlotCard.SlotState.PLAYABLE, StageSlotCard.SlotState.CLEARED:
            EventBus.request_play_stage.emit(stage_id)
        StageSlotCard.SlotState.LOCKED:
            EventBus.sfx_request.emit(&"sfx:locked")
        StageSlotCard.SlotState.COMING_SOON:
            $ComingSoonOverlay.show()

func _unhandled_input(event: InputEvent) -> void:
    # Δ11: ESC = BackBtn alias.
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        EventBus.request_main_menu.emit()
```

#### 3.6.4 GameFlowTest 회귀 처리 (Δ10 단일 결정)

```gdscript
# tests/GameFlowTest.gd, _ready 시작부
func _ready() -> void:
    Engine.time_scale = 8.0
    _main = $Main
    _scene_flow = _main.get_node("SceneFlow")
    _current_stage_root = _main.get_node("CurrentStageRoot")
    _overlay = _main.get_node("GlobalUI/StageDialog") as Control
    if _scene_flow == null or _current_stage_root == null or _overlay == null:
        _fail("missing nodes in Main"); return
    # Δ10: SceneFlow._ready가 자식 _ready 순서로 본 _ready보다 먼저 실행됨 →
    # 이 시점에 TitleScene이 이미 add_child됨. process_frame 후 load_stage(1)로 우회.
    await get_tree().process_frame   # SceneFlow._ready / _boot() 완료 대기
    _scene_flow.load_stage(1)         # title 우회, stage1 직행
    await get_tree().process_frame   # TitleScene remove_child + queue_free
    await get_tree().process_frame   # Stage01 instantiation + StageRunner._ready
    await _run_scenarios()
    ...
```

`StageDialogEscTest.gd`도 동일 패턴.

`boot_to_stage_id` export는 보존. `SceneFlowBootBypassTest`만 사용:

```gdscript
# tests/SceneFlowBootBypassTest.gd
func _ready() -> void:
    var main_scene: PackedScene = load("res://scenes/Main.tscn")
    var main: Node = main_scene.instantiate()
    var sf: Node = main.get_node("SceneFlow")
    sf.boot_to_stage_id = 2   # ★ add_child 전 export 설정 — _ready가 본 값으로 부트
    add_child(main)
    await get_tree().process_frame   # SceneFlow._ready / _boot()
    await get_tree().process_frame   # Stage02 instantiation
    if sf.current_screen != sf.ScreenState.STAGE:
        _fail("not in STAGE"); return
    if sf._current_stage_id != 2:
        _fail("not stage 2"); return
    print("[SceneFlowBootBypassTest] PASS")
    get_tree().quit(0)
```

### 3.7 ComingSoonOverlay 디자인

```
ComingSoonOverlay (Control, full anchor, visible=false, mouse_filter=STOP, PROCESS_MODE_ALWAYS)
├─ Backdrop (ColorRect, color=Color(0.20,0.13,0.07,0.55))
└─ CardWrapper (CenterContainer)
   └─ Card (PanelContainer, custom_minimum_size 320×160, Theme.Panel)
      └─ VBox (separation 16, margin 24)
         ├─ Title (Label Jua 24, INK_900, "준비 중")
         ├─ Subtitle (Label Gaegu 14, INK_700, "다음 업데이트에서 만나요")
         └─ CloseBtn (CButton kind=PRIMARY, text="확인")
```

API:
```gdscript
func show() -> void:
    visible = true
    Motion.fade_in($Backdrop, 0.18, true)
    Motion.caPop($CardWrapper/Card)
    await get_tree().process_frame
    $CardWrapper/Card/VBox/CloseBtn.grab_focus()

func hide() -> void:
    var t := Motion.fade_out(self, 0.15, true)
    await t.finished
    visible = false
    modulate.a = 1.0

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        hide()
```

CloseBtn pressed → hide.

### 3.8 menu_layout.tres

```
[gd_resource type="Resource" script_class="MenuLayout" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/core/MenuLayout.gd" id="1"]
[resource]
script = ExtResource("1")
slots = [
    {"stage_id": 1, "display_name": "햇살 정원", "available": true},
    {"stage_id": 2, "display_name": "다리 공사", "available": true},
    {"stage_id": 3, "display_name": "차단 미로", "available": true},
    {"stage_id": 4, "display_name": "준비 중", "available": false},
    ...
    {"stage_id": 10, "display_name": "준비 중", "available": false},
]
```

### 3.9 Esc 라우팅 정책 (Δ11 dialog-local 통일)

**결정**: InputRouter / GameAction / project.godot `[input]` 모두 무수정. 각 Control이 자체 `_unhandled_input`에서 ESC 처리:

| Control | ESC 동작 |
|---|---|
| TitleScene | 무시 (Δ11) |
| MainMenu | 무시 (실수 종료 방지) |
| StageSelect | `EventBus.request_main_menu.emit()` (BackBtn alias) |
| ComingSoonOverlay (visible=true) | `hide()` |
| StageDialog (phase 12 산출, visible=true) | `_dismiss_then_emit(request_menu)` (기존 동작 유지) |
| Stage 진행 중 (StageDialog hidden) | ESC 미바인딩 → 무반응 |

**회귀 가드**: `EscNotInActionTriggeredTest` — 어떤 상태에서 ESC press 후에도 `EventBus.action_triggered`가 ESC 관련 이름(`back_menu`, `skill_cancel` 등)으로 emit되지 않음 확인.

post-MVP: phase 22(input-advanced)에서 game state machine 도입 시 InputRouter BACK_MENU 액션 재논의 가능.

### 3.10 Motion 호출 위치

- LogoPanel._ready → `Motion.idle_bob(_mascot_node, 1.03, 1.6)`
- ComingSoonOverlay.show → `Motion.fade_in(Backdrop, 0.18, true)` + `Motion.caPop(Card)`
- ComingSoonOverlay.hide → `Motion.fade_out(self, 0.15, true)`
- 신규 Motion 시그니처 추가 없음

---

## 4. 엣지 케이스 (필수, v2 갱신)

1. save.cfg 손상/누락 — fresh init + save (assert/crash 0). `SaveDataCorruptedTest`.
2. schema future version — fresh in-memory + 파일 보존 (downgrade 호환).
3. stage_progress 개별 손상 — 0/false 폴백 (`SaveDataCorruptedTest` §b).
4. 스테이지 클리어 도중 Quit — record_clear/attempt 호출 없으면 stage_progress 무변경. `_notification`만 save (last_saved_at 갱신).
5. 패드 포커스 잃음 — 매 전이 후 1 frame await + 첫 가능 Control grab_focus.
6. 미해금 슬롯 클릭 — `sfx:locked` + 무반응.
7. 미존재 stage 슬롯 — ComingSoonOverlay show.
8. TitleScene 입력 필터 — Key/MouseButton/JoypadButton만. ESC 명시 무시.
9. TitleScene input mode 즉시 변경 — `EventBus.input_mode_changed` 구독.
10. StageSelect hover/focus 동시 — Button 자체 hover + grab_focus 양립.
11. Continue 가드 — Δ4 3 조건 AND.
12. 별점 단일 SoT — `Scoring.compute_stars`만.
13. 메뉴 진입 시 StageDialog 잔여 — `_overlay.hide_overlay()` 우선.
14. ComingSoonOverlay 입력 캡처 — mouse_filter=STOP + ESC dialog-local.
15. Motion idle_bob 누수 — Tween 자동 stop.
16. **autoload sibling order** — `GameManager / EventBus / SkillRegistry / SaveData / InputRouter / InputModeTracker / StepFrame` 순서. SaveData는 EventBus 다음(connect 가능) + InputRouter 앞(InputRouter가 SaveData를 직접 참조하지 않으므로 의존 없음).
17. **screen swap stale emit (Δ9 HIGH-1 회귀)** — `_unload_current_screen()`이 `remove_child + queue_free` 일괄. 옛 자식의 `_process`는 즉시 정지. `SceneFlowSwapNoStaleEmitTest`.
18. **boot_to_stage_id race (Δ10 HIGH-2 회귀)** — production 부트는 0 → TITLE. 테스트는 export 사용 시 반드시 `add_child` 전 설정. GameFlowTest는 load_stage(1) 직접 호출.
19. HUD/Toolbar 누수 — 메뉴 씬은 HUD 미인스턴스. stage 씬 free 시 자동 정리.
20. STAGE 도중 ESC — InputMap 미바인딩 → 무반응 (Δ11).
21. Title `aspect=expand` background — TextureRect KEEP_ASPECT_COVERED.
22. PROCESS_MODE_INHERIT 메뉴 — pause 영향 없음 (메뉴 진입 시 tree.paused=false 보장 by `_unload_current_screen` process_mode 복귀).
23. **`request_menu` 오발화 (Δ14)** — Title/Menu/Select 코드에서 literal 0회. `SceneFlowEmitContractTest`.
24. **SlotState priority (Δ15)** — coming_soon > cleared > playable > locked. stage1-3 cleared + stage4 unavailable → slot4 == COMING_SOON.
25. **autoload disconnect 불필요** — SaveData는 게임 동안 alive. `_test_reset`은 in-memory state만 reset, signal 연결 유지.

---

## 5. 검증 시나리오 (수동 + 자동)

### 5.1 자동 (헤드리스)

| # | 테스트 | 검증 항목 |
|---|---|---|
| 1 | Stage02HeadlessTest | 회귀 |
| 2 | Stage03HeadlessTest | 회귀 |
| 3 | BlockerOverlapTest | 회귀 |
| 4 | GameFlowTest | Scenario A/B/C PASS (Δ10 우회) |
| 5 | SaveDataMigrationTest | v0 → v1 migration + 데이터 보존 + cleanup |
| 6 | SaveDataCorruptedTest | (a) garbage → fresh + crash 0. (b) 개별 stage 손상 → 그 stage만 reset |
| 7 | SaveDataRecordClearTest | (a) stage_cleared → record_clear + best monotonic. (b) stage_failed → record_attempt만 (Δ12). (c) 중복 emit attempts +1 |
| 8 | SaveDataIsUnlockedTest | stage1 항상 unlock, N+1은 N.cleared 시 |
| 9 | MenuLayoutResourceTest | 10 슬롯 + 1~3 available |
| 10 | TitleSceneInputTest | Key/Mouse/Joypad press → emit 1회. 두 번째 ignore. Motion ignore. ESC ignore (Δ11) |
| 11 | MainMenuNavTest | 6 버튼 → emit / overlay 분기 |
| 12 | MainMenuContinueGuardTest | 4 케이스 (last=0/99/2-unlocked/2-locked) |
| 13 | StageSelectUnlockTest | 4 state + **stage1-3 cleared + slot4 COMING_SOON 보호** (Δ15) |
| 14 | SceneFlowScreenStateTest | TITLE→MENU→SELECT→STAGE→MENU 라우팅 |
| 15 | SceneFlowBootBypassTest | add_child 전 export=2 → STAGE/stage_id=2 (Δ10 export 경로 검증) |
| 16 | **SceneFlowSwapNoStaleEmitTest** ★HIGH-1 회귀 | stage1 진입 → counter init → request_main_menu → 5 frame await → stale stage_cleared/failed emit 0회 + process_mode==INHERIT + 자식==MainMenu |
| 17 | **SceneFlowEmitContractTest** ★MED-C | scripts/ui/{TitleScene,MainMenu,StageSelect,ComingSoonOverlay}.gd `request_menu` literal 0. StageDialog.gd에서 `request_menu` 발견 (legacy 보존) |
| 18 | **EscNotInActionTriggeredTest** ★MED-D | Main.tscn boot stage1 + action_triggered 카운터 → ESC parse → ESC 관련 액션 emit 0회 |
| 19 | LogoPanelBobTest | tween loops_left==-1 |
| 20 | StageSlotCardStateTest | 4 state 시각 invariant |
| 21 | ComingSoonOverlayTest | show/hide + caPop + CloseBtn/ESC |
| 22 | SvgImportSmokeTest | 신규 6 SVG PASS |
| 23 | StageDialogEscTest | Δ10 우회 후 회귀 PASS |
| 24 | MotionPauseSafeTest | 회귀 |
| 25 | AtomShowcaseTest | 회귀 |

### 5.2 수동 (에디터 플레이 테스트)

| # | 시나리오 | 기대 |
|---|---|---|
| M1 | 새 사용자 | F5 → Title(bob) → 스페이스 → MainMenu(Play 포커스) → Play → Stage01 자연 clear → 2별 dialog → 다음 단계 → Stage02 unlock → clear → 메뉴로 → Continue 활성 |
| M2 | Continue | F5 → Title → Menu → Continue → 마지막 stage 직행 |
| M3 | StageSelect | Menu → 스테이지 선택 → 1 cleared+별, 2 cleared, 3 playable, 4-10 coming_soon |
| M4 | save 손상 | save.cfg에 garbage → 재진입 → crash 0, warn + fresh |
| M5 | save 누락 | save.cfg 삭제 → 재진입 → fresh, Continue disabled |
| M6 | 패드 네비 | 패드만으로 Title→Menu→Select→Stage→Dialog→Menu→Quit |
| M7 | KB 네비 | KB만으로 동상 (Tab/Enter/Esc) |
| M8 | 마우스 | 마우스만으로 동상 |
| M9 | 마지막 stage clear | Stage03 clear → Next visible+disabled → Menu → Continue=stage3 |
| M10 | LOCKED 슬롯 | stage2 LOCKED 클릭 → 무반응 (sfx hook only) |
| M11 | COMING_SOON | stage 4~10 클릭 → ComingSoonOverlay |
| M12 | Settings/Credits | ComingSoonOverlay |
| M13 | HUD 회귀 | Stage 진입 → HUD/Toolbar 정상 |
| M14 | **screen swap visual** | request_main_menu emit 시 stage frame 0개 (옛 stage 시각 잔존 0) — Δ9 검증 |

---

## 6. 비-범위 (post-MVP / 다른 phase)

- BGM/SFX 실재생: phase 21
- Settings/Credits 실내용: 디자이너 후속
- 별점 stage별 override: stage4~10에서 v0.2
- stage 진입 시 record_attempt: stage4~10에서
- StageSlotCard hover 미리보기: 폴리싱
- 키 리매핑 UI: phase 22
- ESC InputRouter 액션 변환 (`back_menu`): post-MVP (Δ11)
- 메뉴 화면 트랜지션 fade: post-MVP

---

## 7. 해결된 Open Questions (codex Round 1)

| # | 질문 | v2 결정 |
|---|---|---|
| Q1 | boot_to_stage_id vs load_stage 직접 | Δ10: GameFlowTest = load_stage 직접, SceneFlowBootBypassTest만 export 사용 |
| Q2 | request_menu vs request_main_menu | Δ14: StageDialog만 request_menu emit, 나머지 ui scene은 request_main_menu만 |
| Q3 | TitleScene ESC | 무시 (Δ11) |
| Q4 | MainMenu ESC | 무시 (Δ11) |
| Q5 | Settings/Credits | ComingSoonOverlay (Δ8) |
| Q6 | stage 진입 시 record_attempt | 안 함 (stage_failed에서만) |
| Q7 | future schema | 메모리만 fresh, 파일 보존 |
| Q8 | display_name 한국어 | 한국어 |
| Q9 | SaveData test 격리 | _test_reset 헬퍼 + setup/teardown (Δ13) |

---

## 8. 산출물 요약

```
신규 (.tscn):
  scenes/ui/atoms/LogoPanel.tscn
  scenes/ui/atoms/StageSlotCard.tscn
  scenes/ui/TitleScene.tscn
  scenes/ui/MainMenu.tscn
  scenes/ui/StageSelect.tscn
  scenes/ui/ComingSoonOverlay.tscn

신규 (.gd):
  scripts/ui/atoms/LogoPanel.gd
  scripts/ui/atoms/StageSlotCard.gd
  scripts/ui/TitleScene.gd
  scripts/ui/MainMenu.gd
  scripts/ui/StageSelect.gd
  scripts/ui/ComingSoonOverlay.gd
  scripts/core/SaveData.gd            ← Autoload
  scripts/core/MenuLayout.gd          ← Resource

신규 (assets):
  assets/icons/ui/{lock,unlock,arrow_left,arrow_right,settings,close}.svg

신규 (data):
  data/menu_layout.tres

수정 (.gd):
  scripts/core/EventBus.gd            ← 4 signal
  scripts/core/SceneFlow.gd           ← screen state + race-free unload

수정 (설정):
  project.godot                       ← [autoload] SaveData만 (back_menu entry 추가 X)

수정 (tests):
  tests/GameFlowTest.gd               ← load_stage(1) 우회 1줄 (Δ10)
  tests/StageDialogEscTest.gd         ← 동상
  tests/SvgImportSmokeTest.gd         ← _PRODUCTION_SVGS에 6개 추가

신규 tests (.tscn + .gd):
  SaveDataMigrationTest, SaveDataCorruptedTest, SaveDataRecordClearTest,
  SaveDataIsUnlockedTest, MenuLayoutResourceTest, TitleSceneInputTest,
  MainMenuNavTest, MainMenuContinueGuardTest, StageSelectUnlockTest,
  SceneFlowScreenStateTest, SceneFlowBootBypassTest,
  SceneFlowSwapNoStaleEmitTest ★HIGH-1,
  SceneFlowEmitContractTest ★MED-C,
  EscNotInActionTriggeredTest ★MED-D,
  LogoPanelBobTest, StageSlotCardStateTest, ComingSoonOverlayTest,
  test_SaveData.gd (TDD stub)
```

---

## 9. Stage4~10 phase에 남기는 인터페이스 (계약)

본 phase 완료 후 후속 stage phase가 사용:

- `SaveData.record_clear(stage_id, saved, original_hp)` — 클리어 기록
- `SaveData.is_unlocked(stage_id)` — progression
- `SaveData.total_stars()` / `get_stage_entry(stage_id)` — UI 표시
- `data/menu_layout.tres`의 stage_id N entry: available=true + display_name 갱신 (1줄)
- `SceneFlow.STAGE_SCENES`에 `N: "res://scenes/stages/StageNN.tscn"` 1줄 추가
- (선택) Schema bump 시 `SaveData._migrate`에 case 추가
- `EventBus.request_play_stage.emit(N)` — 외부 트리거

---

## 10. 표준 절차

plan/review/deferred는 `phases/mvp/README.md`. 명세 SoT는 `docs/UI_GUIDE.md` §3.5·§3.6·§5·§6 + 본 plan.

After completion: `python scripts/execute.py mvp complete 13`.
