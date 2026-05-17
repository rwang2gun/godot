# Phase 11 Plan — ui-hud-toolbar-replace (v2)

**Status**: plan v2 (rewrites v1 per user decision 2026-05-17, codex plan-review v1 reconciliation)
**v1 → v2 변경 사유**: codex plan-review v1 needs-attention (HIGH 3 / MED 3 / LOW 3). 사용자 결정 = "Plan을 SoT로 채택 + frontmatter 갱신". 본 v2가 단일 SoT.
**Frontmatter SoT 동기화**: `phases/mvp/phase11-ui-hud-toolbar-replace.md`는 v2 진입 시 slim pointer로 재작성 (본문 spec 모두 본 plan으로 이관, frontmatter `name/duration_estimate/verify/large_change_ok/sot/sot_aux` 5종은 그대로 보존 — execute.py validate 통과).
**Related SoT**: `docs/UI_GUIDE.md` §3 (atom catalog — §3.4 set_disabled_state freeze 확장 본 phase에서) · `docs/INPUT_PLAN.md` §4.1 (action ids) · `docs/design_handoff/README.md` (visual reference, §0.5 1인 개발 운영 모델 적용)
**Inputs frozen from prior phases**: Motion sig (phase 9 freeze), Theme (phase 9 freeze), GameAction REGISTRY (phase 5/7/8). atom API는 본 phase에서 `SkillSlot.set_disabled_state(b)` 1개 추가 (freeze 확장 — 기존 callers 무영향).

---

## 0. 한 줄 요약

`scenes/ui/HUD.tscn` + `scenes/ui/SkillToolbar.tscn`을 phase 10 atom 인스턴스 트리로 교체. 스크립트는 `@onready` 경로 갱신 + placeholder 노드를 atom 메서드 호출(`counter.set_value(n)` / `slot.set_count(n)` / `slot.set_selected(b)` / `slot.set_disabled_state(b)`)로 대체. EventBus는 phase 5~8에서 깐 `action_triggered` 버스를 그대로 재사용하며 **신규 시그널 0개**. 신규 atom API 1개(`SkillSlot.set_disabled_state`)는 UI_GUIDE §3.4 freeze에 추가.

---

## 1. 본 plan이 1차 SoT인 이유 (codex v1 HIGH-1 해결)

**과거 상태**: `phases/mvp/phase11-ui-hud-toolbar-replace.md`(이하 "구 frontmatter doc") 본문은 ① 신규 EventBus 시그널 3종(`release_rate_changed_request` / `pause_toggled_request` / `skill_empty`), ② 8 고정 슬롯 + `SkillRegistry.SKILL_ORDER`를 요구했다. 이는 실제 코드 사실(`EventBus.gd`에 위 시그널 부재, `SkillRegistry.gd`에 SKILL_ORDER 부재, stage 1~3의 `available_skills` 길이 1~2)과 충돌하며, 동시에 이미 깔린 `EventBus.action_triggered` 버스(phase 5~8)를 우회하는 패턴이었다.

**v2 결정 (사용자 2026-05-17)**: 본 plan을 단일 SoT로 격상. 구 frontmatter doc 본문은 본 plan으로 포인터화. 본 plan §2 이하 spec이 구현/리뷰의 단일 진실원천.

**플랜 정합성 원칙** (codex v1 HIGH-1 재발 방지):
- 구 frontmatter doc는 frontmatter 5종(name/duration_estimate/verify/large_change_ok/sot/sot_aux)과 **본 plan으로의 1줄 포인터**만 남긴다. 본문 spec 0줄.
- 향후 plan revision 시 두 문서를 동시 갱신하는 게 아니라 본 plan만 갱신 (단일 SoT).
- `phases/mvp/phase11-ui-hud-toolbar-replace.md`의 본문 변경은 본 phase commit에 포함.

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 교체 (.tscn)
| 파일 | 변경 |
|---|---|
| `scenes/ui/HUD.tscn` | 5개 placeholder Label + AcceptDialog → atom 인스턴스 트리 (§3.1) |
| `scenes/ui/SkillToolbar.tscn` | 빈 HBox → Panel(cream_200 + 3px ink_900 top border) + 중앙 HBox(빈 컨테이너, SkillSlot은 .gd가 동적 instantiate) |

### 2.2 신규 (.tscn)
| 파일 | 용도 |
|---|---|
| `scenes/ui/ReleaseRateStepper.tscn` | HBox + BtnMinus(CButton) + Value(Label) + BtnPlus(CButton) |

### 2.3 수정 / 신규 (.gd)
| 파일 | 변경 폭 |
|---|---|
| `scripts/ui/HUD.gd` | 풀-rewrite (Label 갱신 → Counter.set_value). 외부 API `update_time(seconds)` + `show_dialog(message)` 시그니처 보존 (show_dialog는 deprecated push_warning만, AcceptDialog 삭제) |
| `scripts/ui/SkillToolbar.gd` | `Button.new()` → `SkillSlot.instantiate()`, stylebox override 제거, atom 메서드 호출. EventBus 구독 lifecycle guard 추가 (codex v1 MED-3). `set_all_disabled(b)` 신규 메서드 |
| `scripts/ui/PauseBtn.gd` (신규) | CButton 확장. paused polling + icon swap. pressed → action_triggered(PAUSE_TOGGLE) |
| `scripts/ui/ReleaseRateStepper.gd` (신규) | HBoxContainer 확장. ± 버튼 → action_triggered(RELEASE_RATE_UP/DOWN). EventBus.release_rate_changed 구독 |
| `scripts/ui/atoms/SkillSlot.gd` | **atom API freeze 확장**: `set_disabled_state(b: bool)` 추가. `disabled = b` + `_update_visual()` 호출. 본 1 메서드 추가만 — 기존 시그니처 무영향 (codex v1 HIGH-3) |
| `scripts/core/StageRunner.gd` | ① `@export toolbar_path: NodePath` 추가, ② `_ready` 끝부분에 `_spawner.set_release_rate(stage_data.release_rate_initial)` 호출(직접 대입 교체, codex v1 MED-2), ③ `_on_action` 핸들러 추가(RELEASE_RATE_UP/DOWN 소비, codex v1 의 release_rate consumer 갭 해결), ④ stage_cleared/failed emit **직후** `_toolbar.set_all_disabled(true)` 직접 호출(codex v1 HIGH-2 — group lookup 제거), ⑤ `_exit_tree`에 disconnect 보강 |
| `scripts/ui/InputHintLabel.gd` | **무변경** (phase 8 산출 그대로) |

### 2.4 신규 (자산)
| 파일 | 용도 |
|---|---|
| `assets/icons/ui/pause.svg` | 24×24, ink_900 fill, 토큰 hex 1:1 |
| `assets/icons/ui/play.svg` | 24×24, ink_900 fill, 토큰 hex 1:1 |

### 2.5 수정 (Stage 씬 — codex v1 HIGH-2 toolbar wiring)
| 파일 | 변경 |
|---|---|
| `scenes/stages/Stage02.tscn` | StageRunner 노드에 `toolbar_path = NodePath("SkillToolbar")` 1줄 추가 |
| `scenes/stages/Stage03.tscn` | 동일 1줄 추가 |
| `scenes/stages/Stage01.tscn` | 무변경 (Stage01은 SkillToolbar 없음, `toolbar_path = NodePath()` 빈 값으로 default — StageRunner null 가드 처리) |

### 2.6 수정 (UI_GUIDE — atom freeze 확장, codex v1 HIGH-3 SoT 동기)
| 파일 | 변경 |
|---|---|
| `docs/UI_GUIDE.md` | §3.4 "메서드: set_count, set_selected" 1줄 → "메서드: set_count, set_selected, **set_disabled_state**(b: bool) — phase 11 freeze 확장. atom-internal `disabled = b` 적용 + `_update_visual()` 호출. 외부에서 `Button.disabled = b` 직접 대입 금지" |

### 2.7 수정 (Phase frontmatter pointer-ize)
| 파일 | 변경 |
|---|---|
| `phases/mvp/phase11-ui-hud-toolbar-replace.md` | frontmatter 5종 보존 + 본문 전체를 1줄 포인터로 교체: "본 phase의 1차 SoT는 `phases/mvp/plans/phase11-plan.md` v2. 본 문서는 execute.py validate용 frontmatter만 보존" |

### 2.8 신규 tests
| 파일 | 검증 |
|---|---|
| `tests/HudCounterRegressionTest.{tscn,gd}` | HUD 인스턴스 → `EventBus.candy_piece_picked.emit(5)` → Counter[CANDY_HP] BigNumber.text == "5". 동일 패턴 saved/lost/in_transit. update_time(47.3) → Counter[TIME].text == "48" |
| `tests/HudPauseFreezeTest.{tscn,gd}` (codex v1 MED-1 회귀) | tree.paused=true 상태에서 Counter.set_value(5) 호출 → 1 process frame 후 BigNumber.scale != Vector2(1.08, 1.08) (caPop 진행 정지 확인 — Counter inherits, paused tree에서 tween 정지) |
| `tests/ReleaseRateStepperTest.{tscn,gd}` | Stepper 인스턴스 → BtnMinus.pressed → EventBus.action_triggered last name == RELEASE_RATE_DOWN. release_rate_changed.emit(15) → Value Label.text == "15" |
| `tests/PauseBtnIconSwapTest.{tscn,gd}` | PauseBtn 인스턴스 → tree.paused=true → 1 frame 후 icon == play. false → pause |
| `tests/StageRunnerReleaseRateActionTest.{tscn,gd}` | StageRunner + AntSpawner stub → action_triggered(RELEASE_RATE_UP) → spawner.release_rate += 5 |
| `tests/StageRunnerToolbarDisableTest.{tscn,gd}` (codex v1 HIGH-2 회귀) | StageRunner with toolbar_path → stage_cleared 또는 stage_failed emit → toolbar.disabled flag 전체 true + 모든 SkillSlot alpha 0.55 |
| `tests/SkillToolbarReentryTest.{tscn,gd}` (codex v1 MED-3 회귀) | SkillToolbar 1번째 인스턴스 free → 2번째 인스턴스 생성 → SKILL_ASSIGN action emit → inventory 정확히 1회 차감 (중복 connect 없음 검증) |
| `tests/test_HUD.gd` | TDD stub → 실제 atom 검증 hook |
| `tests/test_SkillToolbar.gd` | TDD stub → 실제 atom 검증 hook |
| `tests/SvgImportSmokeTest.gd` | PRODUCTION_SVGS 13→15 추가, 헤더 코멘트 + PASS 메시지 `PRODUCTION_SVGS.size()` 사용으로 자동 갱신 (codex v1 LOW-2) |
| `tests/test_SkillSlot.gd` | 기존 stub → `set_disabled_state(true)` 호출 → disabled==true + self_modulate.a == 0.55 검증 (codex v1 HIGH-3 회귀) |

### 2.9 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 시그널 추가/삭제 0건.
- `scripts/core/SkillRegistry.gd` — 무변경.
- `scripts/skills/*.gd` — 무관.
- `scripts/input/*` — phase 5~8 산출 그대로.
- `scripts/core/GameManager.gd`, `SceneFlow.gd`, `StepFrame.gd`, `AntSpawner.gd` — 무관 (StageRunner만 set_release_rate 호출 라인 1줄 교체).
- `scripts/ui/atoms/Counter.gd`, `Chip.gd`, `CButton.gd` — phase 10 freeze 그대로. (`SkillSlot.gd`만 freeze 확장 +1 메서드)
- `scripts/ui/Motion.gd`, `Tokens.gd` — phase 9 freeze.
- `theme/candyants.tres` — phase 9 freeze.

---

## 3. HUD 노드 트리

```
HUD (CanvasLayer, layer=10, process_mode=PROCESS_MODE_INHERIT)   # ← codex v1 MED-1: 기본 INHERIT
└─ Root (Control, anchor preset full rect)
   ├─ TopLeft (HBoxContainer, anchor top-left, offset (32,32), separation 12)
   │  ├─ CounterCandyHp     (Counter atom — caPop inherits → pause 시 정지 ✓)
   │  ├─ CounterInTransit
   │  ├─ CounterSaved
   │  └─ CounterLost
   ├─ TopRight (HBoxContainer, anchor top-right, offset (-32,32), grow_left=2, separation 12)
   │  ├─ CounterTime
   │  ├─ ReleaseRateStepper (scene 인스턴스)
   │  └─ PauseBtn           (PROCESS_MODE_ALWAYS — pause 중에도 click + icon polling)
   └─ AlwaysBranch (Control, process_mode=PROCESS_MODE_ALWAYS, anchor bottom-stretch)
      └─ InputHintLabel (Label, anchor bottom-center, offset_top=-160, phase 8 산출, _ready에서 ALWAYS 재선언)
```

**process_mode 분기 (codex v1 MED-1 해결)**:
- HUD root = INHERIT → Counter caPop이 inherits → paused tree에서 tween 자동 정지 (UI_GUIDE §4 "in-game motion = INHERIT" 준수).
- PauseBtn = ALWAYS (explicit) → pause 중에도 click + icon swap polling 작동.
- InputHintLabel = ALWAYS (이미 `_ready`에서 설정, 본 phase 무변경).
- ReleaseRateStepper = INHERIT default → pause 시 ± 버튼 비활성화. **결정**: 의도된 동작 (pause 중 release rate 변경 막음 = UX 일관성). 만약 향후 "pause 중에도 release rate 조정 OK"로 정책 변경하면 Stepper만 ALWAYS로 바꾸면 됨. 본 phase는 INHERIT.

### 3.1 update_time 호출 빈도 보호 (per-second clamp)
```gdscript
var _last_time_int: int = -1

func update_time(seconds: float) -> void:
    var s := int(ceil(seconds))
    if s == _last_time_int:
        return
    _last_time_int = s
    _time_counter.set_value(s)
```

### 3.2 EventBus 구독 lifecycle (codex v1 MED-3 동일 패턴 HUD 적용)
```gdscript
func _ready() -> void:
    # ... atom @onready 캐시 ...
    if not EventBus.candy_piece_picked.is_connected(_on_picked):
        EventBus.candy_piece_picked.connect(_on_picked)
    if not EventBus.ant_saved.is_connected(_on_saved):
        EventBus.ant_saved.connect(_on_saved)
    if not EventBus.candy_piece_lost.is_connected(_on_lost):
        EventBus.candy_piece_lost.connect(_on_lost)
    _refresh_all()

func _exit_tree() -> void:
    if EventBus.candy_piece_picked.is_connected(_on_picked):
        EventBus.candy_piece_picked.disconnect(_on_picked)
    if EventBus.ant_saved.is_connected(_on_saved):
        EventBus.ant_saved.disconnect(_on_saved)
    if EventBus.candy_piece_lost.is_connected(_on_lost):
        EventBus.candy_piece_lost.disconnect(_on_lost)
```

### 3.3 Stage 종료 시 toolbar disable (codex v1 HIGH-2 해결)
HUD는 toolbar 라우팅 책임 X. **StageRunner가 직접 호출** (§5.3):
```gdscript
# scripts/core/StageRunner.gd 안에서
if score_system.is_cleared(candy_hp):
    _completed = true
    EventBus.stage_cleared.emit(_make_result(true, ""))
    _disable_toolbar()
    return
# 동일하게 stage_failed 분기 2곳
```
`_disable_toolbar()`는 `_toolbar`(StageRunner._ready에서 `get_node_or_null(toolbar_path)`) null 가드 후 `_toolbar.set_all_disabled(true)`.

---

## 4. SkillToolbar 노드 트리

```
SkillToolbar (CanvasLayer, layer=10, process_mode=PROCESS_MODE_ALWAYS)   # ← 그대로
└─ Panel (Control, anchor bottom + h-stretch, height=140)
   ├─ Background (ColorRect, full-rect, color = cream_200)
   ├─ TopBorder  (ColorRect, height=3, anchor top-stretch, color = ink_900)
   └─ HBoxContainer (centered, separation 14)
      └─ (SkillSlot 인스턴스들 — SkillToolbar.gd가 _ready에서 add_child)
```

### 4.1 SkillToolbar.gd rewrite spec (codex v1 MED-3 lifecycle guard 포함)
```gdscript
class_name SkillToolbar extends CanvasLayer

const GameAction := preload("res://scripts/input/GameAction.gd")
const SkillSlotScene: PackedScene = preload("res://scenes/ui/atoms/SkillSlot.tscn")
const CLICK_RADIUS: float = 32.0
const ICONS: Dictionary = { ... }   # 현 8 SVG preload 그대로
const CURSOR_HOTSPOT: Vector2 = Vector2(32, 32)
const KO_LABELS: Dictionary = {
    "climber": "등반", "floater": "낙하산", "bomber": "폭탄", "blocker": "차단",
    "builder": "계단", "basher": "굴착", "miner": "채굴", "digger": "땅파기",
}

@export var stage_data: StageData = null
@export var hbox_path: NodePath

var _pending_skill_id: String = ""
var _inventory: Dictionary = {}
var _slots: Dictionary = {}        # id → SkillSlot
var _all_disabled: bool = false

func _ready() -> void:
    if stage_data == null:
        push_warning("[SkillToolbar] stage_data null"); return
    _inventory = stage_data.skill_inventory.duplicate(true)
    var hbox := get_node_or_null(hbox_path) as HBoxContainer
    if hbox == null:
        push_error("[SkillToolbar] hbox_path missing"); return
    var i := 0
    for id: String in stage_data.available_skills:
        var slot: SkillSlot = SkillSlotScene.instantiate()
        slot.skill_id = StringName(id)
        slot.hotkey = str(i + 1)
        slot.ko_label = KO_LABELS.get(id, id)
        slot.icon_texture = ICONS.get(id) as Texture2D
        slot.set_count(int(_inventory.get(id, 0)))
        hbox.add_child(slot)
        slot.pressed.connect(_on_slot_pressed.bind(id))
        _slots[id] = slot
        i += 1
    # codex v1 MED-3: lifecycle guard
    if not EventBus.action_triggered.is_connected(_on_action):
        EventBus.action_triggered.connect(_on_action)

func _exit_tree() -> void:
    Input.set_custom_mouse_cursor(null)
    # codex v1 MED-3: disconnect on exit
    if EventBus.action_triggered.is_connected(_on_action):
        EventBus.action_triggered.disconnect(_on_action)

func set_all_disabled(b: bool) -> void:
    _all_disabled = b
    for id in _slots:
        # codex v1 HIGH-3: atom API set_disabled_state 사용 — visual refresh 포함
        (_slots[id] as SkillSlot).set_disabled_state(b)
    if b:
        _clear_selection()

func _on_action(name: StringName, payload: Dictionary) -> void:
    if _all_disabled:
        return
    match name:
        GameAction.SKILL_ASSIGN:
            if not payload.get("position_valid", false): return
            _try_assign(payload.get("world_pos", Vector2.ZERO))
        GameAction.SKILL_CANCEL: _clear_selection()
        GameAction.SKILL_CYCLE_NEXT: _cycle(+1)
        GameAction.SKILL_CYCLE_PREV: _cycle(-1)
        _:
            var slot_idx: int = GameAction.SKILL_SELECT_BY_SLOT.find(name)
            if slot_idx >= 0: _select_by_slot(slot_idx)

func _on_slot_pressed(id: String) -> void:
    var count: int = int(_inventory.get(id, 0))
    if count <= 0:
        # phase 21 sound hook 자리 (현 phase 11 noop)
        return
    if _pending_skill_id == id:
        _clear_selection(); return
    _select(id)

func _select(id: String) -> void:
    if _pending_skill_id != "" and _slots.has(_pending_skill_id):
        (_slots[_pending_skill_id] as SkillSlot).set_selected(false)
    _pending_skill_id = id
    if _slots.has(id):
        (_slots[id] as SkillSlot).set_selected(true)
    var icon: Texture2D = ICONS.get(id) as Texture2D
    if icon != null:
        Input.set_custom_mouse_cursor(icon, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

func _clear_selection() -> void:
    if _pending_skill_id != "" and _slots.has(_pending_skill_id):
        (_slots[_pending_skill_id] as SkillSlot).set_selected(false)
    _pending_skill_id = ""
    Input.set_custom_mouse_cursor(null)

func _try_assign(world: Vector2) -> void:
    if _pending_skill_id == "": return
    var ant: Ant = _find_closest_ant(world)
    if ant == null: return
    var skill_script: Script = SkillRegistry.get_skill(_pending_skill_id)
    if skill_script == null: _clear_selection(); return
    var skill: Skill = skill_script.new() as Skill
    if skill == null or not skill.can_apply(ant): _clear_selection(); return
    var applied_id := _pending_skill_id
    skill.apply(ant)
    _inventory[applied_id] = int(_inventory[applied_id]) - 1
    (_slots[applied_id] as SkillSlot).set_count(int(_inventory[applied_id]))
    _clear_selection()

func _select_by_slot(slot_idx: int) -> void:
    if stage_data == null or slot_idx < 0 or slot_idx >= stage_data.available_skills.size(): return
    _on_slot_pressed(stage_data.available_skills[slot_idx])

func _cycle(step: int) -> void:
    if stage_data == null or stage_data.available_skills.is_empty(): return
    var ids: Array = stage_data.available_skills
    var cur: int = ids.find(_pending_skill_id) if _pending_skill_id != "" else -1
    _on_slot_pressed(ids[posmod(cur + step, ids.size())])

func _find_closest_ant(world: Vector2) -> Ant:
    var closest: Ant = null
    var best: float = CLICK_RADIUS
    for n in get_tree().get_nodes_in_group("ants"):
        var a: Ant = n as Ant
        if a == null: continue
        var d: float = a.global_position.distance_to(world)
        if d < best: best = d; closest = a
    return closest
```

차이 요약 (현 `SkillToolbar.gd:1-213` 대비):
- `Button.new()` + 4 stylebox override → `SkillSlotScene.instantiate()` + atom의 자체 styling.
- `btn.text = "× %d"` / `btn.disabled` → `slot.set_count(n)`.
- `set_pressed_no_signal(true/false)` → `slot.set_selected(true/false)`.
- `_buttons: Dictionary` → `_slots: Dictionary`.
- `set_all_disabled(b)` + `_all_disabled` 가드 신규 (codex v1 HIGH-3: `set_disabled_state` atom API 호출).
- EventBus connect/disconnect lifecycle guard 추가 (codex v1 MED-3).
- `add_to_group("skill_toolbars")` **제거** (codex v1 HIGH-2: group lookup 폐기, StageRunner direct ref 사용).
- 기존 EventBus 핸들러/cursor/_try_assign/_find_closest_ant는 무변경.

---

## 5. PauseBtn / ReleaseRateStepper / StageRunner 세부

### 5.1 PauseBtn.gd
```gdscript
class_name PauseBtn
extends CButton

const PAUSE_ICON := preload("res://assets/icons/ui/pause.svg")
const PLAY_ICON  := preload("res://assets/icons/ui/play.svg")
const GameAction := preload("res://scripts/input/GameAction.gd")

var _last_paused: bool = false
var _icon_rect: TextureRect

func _ready() -> void:
    kind = ButtonKind.GHOST
    custom_minimum_size = Vector2(56, 56)
    process_mode = PROCESS_MODE_ALWAYS
    super._ready()  # CButton._ready (boop wiring)
    _icon_rect = TextureRect.new()
    _icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    _icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
    _icon_rect.custom_minimum_size = Vector2(24, 24)
    _icon_rect.mouse_filter = MOUSE_FILTER_IGNORE
    _icon_rect.anchor_left = 0.5; _icon_rect.anchor_top = 0.5
    _icon_rect.anchor_right = 0.5; _icon_rect.anchor_bottom = 0.5
    _icon_rect.offset_left = -12; _icon_rect.offset_top = -12
    _icon_rect.offset_right = 12; _icon_rect.offset_bottom = 12
    add_child(_icon_rect)
    if not pressed.is_connected(_on_pressed_emit):
        pressed.connect(_on_pressed_emit)
    _refresh_icon()

func _process(_delta: float) -> void:
    var tree := get_tree()
    if tree == null: return
    if tree.paused != _last_paused:
        _last_paused = tree.paused
        _refresh_icon()

func _on_pressed_emit() -> void:
    EventBus.action_triggered.emit(GameAction.PAUSE_TOGGLE, {})

func _refresh_icon() -> void:
    _icon_rect.texture = PLAY_ICON if _last_paused else PAUSE_ICON
```

**`super._ready()` 검증** (codex v1 (d) Godot 4.6 specifics): GDScript에서 `class_name PauseBtn extends CButton`의 자식 `_ready` 안에서 `super._ready()` 호출은 표준 패턴 (Godot 공식 문서). CButton._ready(`scripts/ui/atoms/CButton.gd:20-23`)이 `pressed.connect(_on_pressed)` 실행 → boop motion wiring 활성화. 본 PauseBtn은 그 위에 `_on_pressed_emit` 추가 connect. pressed 시그널은 multi-connect 가능 (Godot signal contract), 두 핸들러 모두 호출됨.

### 5.2 ReleaseRateStepper.tscn + .gd
**.tscn 구조**:
```
ReleaseRateStepper (HBoxContainer, theme_override_constants/separation = 6)   # ← .tscn 안에서 그대로 OK (gate broaden 후)
├─ BtnMinus (CButton, kind=GHOST, custom_minimum_size=(28,28), text="−")
├─ Value (Label, font_size=24, theme_override_colors/font_color=ink_900, custom_minimum_size=(40,28), horizontal_alignment=center)
└─ BtnPlus (CButton, kind=GHOST, custom_minimum_size=(28,28), text="+")
```

**.gd**:
```gdscript
class_name ReleaseRateStepper
extends HBoxContainer

const GameAction := preload("res://scripts/input/GameAction.gd")

@onready var _btn_minus: CButton = $BtnMinus
@onready var _value_label: Label = $Value
@onready var _btn_plus: CButton = $BtnPlus

func _ready() -> void:
    if not _btn_minus.pressed.is_connected(_emit_down):
        _btn_minus.pressed.connect(_emit_down)
    if not _btn_plus.pressed.is_connected(_emit_up):
        _btn_plus.pressed.connect(_emit_up)
    if not EventBus.release_rate_changed.is_connected(_on_rate_changed):
        EventBus.release_rate_changed.connect(_on_rate_changed)

func _exit_tree() -> void:
    if EventBus.release_rate_changed.is_connected(_on_rate_changed):
        EventBus.release_rate_changed.disconnect(_on_rate_changed)

func _emit_down() -> void:
    EventBus.action_triggered.emit(GameAction.RELEASE_RATE_DOWN, {})

func _emit_up() -> void:
    EventBus.action_triggered.emit(GameAction.RELEASE_RATE_UP, {})

func _on_rate_changed(new_rate: int) -> void:
    _value_label.text = str(new_rate)
```

**초기값 데이터 경로 (codex v1 MED-2 해결)**:
- StageRunner._ready: `_spawner.set_release_rate(stage_data.release_rate_initial)` (직접 대입 교체). AntSpawner.set_release_rate가 `EventBus.release_rate_changed.emit(rate)` 발화 → Stepper의 `_on_rate_changed`가 받음 → Value Label 정확히 갱신.
- 노드 _ready 순서: 자식 먼저 (depth-first). Stage02.tscn에서 HUD(자식 Stepper 포함) → SkillToolbar → StageRunner(scene root) 순서로 _ready. Stepper.connect는 StageRunner의 set_release_rate 호출 이전에 완료 → emit 미스 없음.
- `.tscn` 기본 Value text는 빈 문자열로 둠 (signal로 초기화 강제). 기본 "50" 같은 placeholder 표시 risk 0 (codex v1 MED-2 의 정확한 해결).

### 5.3 StageRunner.gd patches
```gdscript
# 신규 import
const GameAction := preload("res://scripts/input/GameAction.gd")
const RR_STEP: int = 5

# 신규 export
@export var toolbar_path: NodePath    # codex v1 HIGH-2: direct ref 라우팅

# 신규 멤버
var _toolbar: Node = null

func _ready() -> void:
    # ... 기존 코드 (stage_data null check, candy/home/spawner 캐시 등) ...
    _toolbar = get_node_or_null(toolbar_path)    # Stage01은 null 가능

    # 기존: _spawner.release_rate = stage_data.release_rate_initial  ← 교체
    # codex v1 MED-2: 직접 대입 → set_release_rate → release_rate_changed emit → Stepper 동기
    if _spawner != null:
        _spawner.set_release_rate(stage_data.release_rate_initial)

    # ... 기존 spawner.spawn_finished connect, score_system.start, _time_left init ...

    # 신규: action_triggered 구독 (RELEASE_RATE_UP/DOWN 소비)
    if not EventBus.action_triggered.is_connected(_on_action):
        EventBus.action_triggered.connect(_on_action)

func _process(delta: float) -> void:
    # ... 기존 코드 ...
    if score_system.is_cleared(candy_hp):
        _completed = true
        EventBus.stage_cleared.emit(_make_result(true, ""))
        _disable_toolbar()        # codex v1 HIGH-2 — direct ref, group lookup 없음
        return
    # no_more_ants
    if (_spawner_finished and ...):
        _completed = true
        EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))
        _disable_toolbar()
        return
    # time_out
    if _time_left <= 0.0:
        _completed = true
        EventBus.stage_failed.emit(_make_result(false, "time_out"))
        _disable_toolbar()

func _disable_toolbar() -> void:
    if _toolbar != null and _toolbar.has_method("set_all_disabled"):
        _toolbar.set_all_disabled(true)

func _on_action(name: StringName, _payload: Dictionary) -> void:
    if _completed or _spawner == null: return
    # codex v2 NEW-M1: pause 중 release_rate KB/pad 입력 차단 (Stepper INHERIT 일관성).
    # PAUSE_TOGGLE은 StepFrame 소비 → 본 핸들러는 RELEASE_RATE_UP/DOWN 만 처리하므로 blanket guard 안전.
    var tree := get_tree()
    if tree != null and tree.paused: return
    if name == GameAction.RELEASE_RATE_UP:
        _spawner.set_release_rate(_spawner.release_rate + RR_STEP)
    elif name == GameAction.RELEASE_RATE_DOWN:
        _spawner.set_release_rate(_spawner.release_rate - RR_STEP)

func _exit_tree() -> void:
    # ... 기존 score_system.stop() ...
    if EventBus.action_triggered.is_connected(_on_action):
        EventBus.action_triggered.disconnect(_on_action)
```

- `_completed` 가드 → stage 종료 후 release_rate 입력 무시 (race safety).
- `has_method` 가드 → toolbar null/stub일 때 안전.
- AntSpawner.set_release_rate 자체에 `clampi(rate, 1, 99)` 있음 → 경계 무한 누적 방지.

### 5.4 SkillSlot atom freeze 확장 (codex v1 HIGH-3 해결)
`scripts/ui/atoms/SkillSlot.gd` 추가 1 메서드:
```gdscript
# UI_GUIDE §3.4 freeze 확장 (phase 11). Button.disabled 직접 대입 금지.
# 외부 호출자(SkillToolbar.set_all_disabled)는 본 메서드만 사용.
func set_disabled_state(b: bool) -> void:
    disabled = b
    if is_inside_tree():
        _update_visual()
```

- 기존 `set_count` / `set_selected` 시그니처 무변경.
- `_update_visual()` 호출로 alpha 0.55 fade 즉시 반영 (`SkillSlot.gd:179-189`의 `faded := is_empty or disabled` 분기 정상 동작).
- atom isolation 유지 (EventBus import 없음).

UI_GUIDE §3.4 갱신 (Edit 적용):
```
- 메서드: `set_count(n: int)`, `set_selected(b: bool)`, `set_disabled_state(b: bool)` (phase 11 freeze 확장 — 외부에서 `Button.disabled = b` 직접 대입 금지)
```

---

## 6. 산출물 요약 (execute.py whitelist + size guard 사전 검증)

```
scenes/ui/HUD.tscn                              [REPLACE]
scenes/ui/SkillToolbar.tscn                     [REPLACE]
scenes/ui/ReleaseRateStepper.tscn               [NEW]
scenes/stages/Stage02.tscn                      [PATCH +1 line — toolbar_path]
scenes/stages/Stage03.tscn                      [PATCH +1 line]
scripts/ui/HUD.gd                               [REWRITE]
scripts/ui/SkillToolbar.gd                      [REWRITE]
scripts/ui/PauseBtn.gd                          [NEW]
scripts/ui/ReleaseRateStepper.gd                [NEW]
scripts/ui/atoms/SkillSlot.gd                   [PATCH +5 lines — set_disabled_state]
scripts/core/StageRunner.gd                     [PATCH +30 lines]
assets/icons/ui/pause.svg                       [NEW, ~250 bytes]
assets/icons/ui/play.svg                        [NEW, ~250 bytes]
tests/HudCounterRegressionTest.{tscn,gd}        [NEW]
tests/HudPauseFreezeTest.{tscn,gd}              [NEW — codex v1 MED-1 회귀]
tests/ReleaseRateStepperTest.{tscn,gd}          [NEW]
tests/PauseBtnIconSwapTest.{tscn,gd}            [NEW]
tests/StageRunnerReleaseRateActionTest.{tscn,gd} [NEW]
tests/StageRunnerToolbarDisableTest.{tscn,gd}   [NEW — codex v1 HIGH-2 회귀]
tests/SkillToolbarReentryTest.{tscn,gd}         [NEW — codex v1 MED-3 회귀]
tests/test_HUD.gd                               [REPLACE stub]
tests/test_SkillToolbar.gd                      [REPLACE stub]
tests/test_SkillSlot.gd                         [PATCH — set_disabled_state 회귀]
tests/SvgImportSmokeTest.gd                     [PATCH — PRODUCTION_SVGS 13→15, count auto from size()]
docs/UI_GUIDE.md                                [PATCH — §3.4 set_disabled_state freeze 추가]
phases/mvp/phase11-ui-hud-toolbar-replace.md    [PATCH — pointer-ize]
phases/mvp/reviews/phase11-impl-review.md       [APPEND impl review rounds]
```

**execute.py whitelist 검증 (codex v1 LOW-3 + INFO)**:
- `scenes/**`, `scripts/**`, `assets/**`, `tests/**`, `docs/**/*.md`, `phases/{task}/phase*.md`, `phases/{task}/reviews/*.md` 모두 `execute.py:311-340` whitelist 매칭.
- `phases/mvp/plans/*.md`는 phase11-plan.md 위치라 whitelist 매칭 (line 334).
- 신규 .uid/.import는 line 324-325 패턴 매칭.
- 22~28 candidates → 100개 large guard 통과. svg 2장 × ~250B → size guard 통과.

---

## 7. 검증 (verify) — execute.py complete 차단 조건

### 7.1 자동 (헤드리스)
```
python scripts/run_test.py tests/Stage02HeadlessTest.tscn        # 기존 회귀
python scripts/run_test.py tests/Stage03HeadlessTest.tscn        # 기존
python scripts/run_test.py tests/InputRouterTest.tscn            # 기존
python scripts/run_test.py tests/PadInputTest.tscn               # 기존
python scripts/run_test.py tests/PausedAssignTest.tscn           # 기존
python scripts/run_test.py tests/GameFlowTest.tscn               # 기존
python scripts/run_test.py tests/AtomShowcaseHeadless.tscn       # phase 10 회귀
python scripts/run_test.py tests/SvgImportSmokeTest.tscn         # 15장 PASS
python scripts/run_test.py tests/HudCounterRegressionTest.tscn   # 신규
python scripts/run_test.py tests/HudPauseFreezeTest.tscn         # 신규 (MED-1 회귀)
python scripts/run_test.py tests/ReleaseRateStepperTest.tscn     # 신규
python scripts/run_test.py tests/PauseBtnIconSwapTest.tscn       # 신규
python scripts/run_test.py tests/StageRunnerReleaseRateActionTest.tscn  # 신규
python scripts/run_test.py tests/StageRunnerToolbarDisableTest.tscn     # 신규 (HIGH-2 회귀)
python scripts/run_test.py tests/SkillToolbarReentryTest.tscn    # 신규 (MED-3 회귀)
```
모두 exit 0.

### 7.2 코드 정합성 grep 게이트 (codex v1 LOW-1 broaden 후, codex impl-review R1 M1 layout exception 명시)
**확장된 ban 패턴** (caller `.gd` code만 — atom internal 제외):
```
grep -rn -E "add_theme_(stylebox|color|font|font_size|icon)_override" \
    scripts/ui/HUD.gd scripts/ui/SkillToolbar.gd
# 0건 기대 — stylebox/color/font 오버라이드 금지 (style drift 방지)
```
> `add_theme_constant_override`는 layout (separation/margin)에 한해 atom-like wrapper에서 허용 — gate 패턴에서 의도적으로 제외.

**Scene 파일 layout 예외** (codex impl-review R1 M1 명시):
- `scenes/ui/HUD.tscn`, `scenes/ui/SkillToolbar.tscn`에 `theme_override_constants/separation` 발견 OK — HBoxContainer 자식 간 spacing은 layout 결정 사항이며 atom 시각 일관성에 영향 X.
- `theme_override_styles/*`, `theme_override_colors/*`, `theme_override_fonts/*`는 동일 scene 파일에서도 금지 (stylebox/color drift).
- `scripts/ui/atoms/*`, `scripts/ui/PauseBtn.gd`, `scripts/ui/ReleaseRateStepper.gd`, `scenes/ui/ReleaseRateStepper.tscn` — atom + atom-like wrapper로 분류, 모든 override 면제.

**EventBus 무변경 검증**:
```
git diff scripts/core/EventBus.gd
# diff 0 라인 기대
```

### 7.3 수동
1. Stage01~03 마우스 플레이 — 카운터 4개 caPop, 스킬 부여/취소/사이클, Stepper ± 동작, PauseBtn icon swap.
2. Stage01~03 패드 플레이 — focus halo, B 취소, LB/RB 사이클.
3. Stepper 1/99 경계 — clamp 시 Label 변동 0.
4. PauseBtn 클릭 → ant 정지, icon = play, Counter caPop 정지 (MED-1 시각 검증).
5. Stage clear → toolbar 슬롯 전체 alpha 0.55, click 무반응 (HIGH-2/HIGH-3 시각 검증).
6. RESTART_STAGE 후 새 toolbar = interactive (HIGH-2 race-free 검증).
7. 1280×720 해상도 시각 — HUD/Stepper/Toolbar 가시.

### 7.4 운영 모델 §0.5
- AI 생성 자산 pause/play.svg는 strict 1:1 토큰 hex 매핑 (literal `#3A2A1C` = ink_900). svg_color_map.json 갱신 불필요.
- 토큰 hex 일치 + Theme inspector 일치만 강제. 추가 해상도 캡처 deferred.

---

## 8. 엣지 케이스 (필수)

| 케이스 | 처리 |
|---|---|
| VirtualCursor z-order | HUD/Toolbar layer=10, VirtualCursor layer=100 (phase 7) |
| Stage 종료 → toolbar disable | StageRunner direct ref → toolbar.set_all_disabled(true). group race 0. selection 자동 clear. |
| Counter set_value(0) | "0" + caPop. 빈 문자열 X. |
| update_time 같은 정수 반복 | `_last_time_int == s` skip → caPop 0건 |
| update_time(0.4) | int(ceil)=1 → "1" 표시 |
| SkillSlot count=0 클릭 | early return. phase 21 sound hook 주석. |
| stage_data null | warning + 빈 toolbar |
| stage_data.available_skills 빈 배열 | HBox 빈 → toolbar 빈 띠. _cycle early return |
| Stepper 빠른 클릭 | 매 click action emit → StageRunner consume → set_release_rate → release_rate_changed → Label 갱신. 동기 처리 race 0 |
| Pause 중 stepper 클릭 | Stepper INHERIT → pause 시 input disabled (의도) |
| Pause 중 KB(F1/F2) / pad(D-Pad↑↓) release_rate | StageRunner._on_action에서 `tree.paused` 가드 (codex v2 NEW-M1). Stepper INHERIT와 일관 — pause = 모든 release_rate 입력 차단. StageRunnerReleaseRateActionTest에 paused 케이스 1개 추가 |
| Pause 중 skill 부여 | PausedAssignTest 회귀 유지 |
| HUD/Toolbar paused tree 동작 | HUD INHERIT + PauseBtn ALWAYS, Toolbar ALWAYS (그대로) |
| _exit_tree 시그널 leak | HUD/SkillToolbar/Stepper/StageRunner 모두 disconnect 보강 |
| Theme override gate | 확장 grep + atom-like whitelist 명시 |
| Stage scene 변경 | Stage02/Stage03 1줄 toolbar_path만. Stage01은 무변경 |
| AcceptDialog 삭제 영향 | show_dialog는 push_warning만. 호출자 grep으로 검증 (impl 첫 단계) |
| Stepper Value Label 초기 빈 문자열 | StageRunner set_release_rate가 첫 frame에 호출 → emit → 즉시 "30" 표시. ".tscn 기본 ''"는 0-frame 잔존만 |
| RESTART_STAGE 1-frame overlap | 옛/새 toolbar 동시 존재해도 StageRunner direct ref라 각자 자기 toolbar만 disable. race 0 |
| HUD INHERIT 중 PauseBtn ALWAYS | Godot 4 process_mode 명시 override가 부모 INHERIT 무시 — pause 중에도 PauseBtn._process 호출 보장 |

---

## 9. 비-범위 (defer)

| 항목 | 처리 |
|---|---|
| StageDialog (win/loss 모달) | phase 12 |
| skill_empty sound hook | phase 21 (SkillToolbar._on_slot_pressed count<=0 분기에 주석 자리만) |
| SKILL_ORDER 글로벌 const | phase 15 이상 |
| SaveData / 별점 | phase 12/13 |
| Pause backdrop / 모달 veil | phase 12 |
| 1920×1080 추가 해상도 캡처 | post-MVP 폴리싱 |

---

## 10. v2 self-adversarial-review (codex 재리뷰 전 사전 점검)

본 plan 작성자가 codex v2 리뷰 전 미리 점검한 위험:

1. **StageRunner._on_action 중복 connect**: `_ready`에서 `is_connected` 가드 + `_exit_tree` disconnect. ✓
2. **StageRunner _disable_toolbar 호출 시점**: emit 직후 → toolbar는 stage_cleared/failed signal을 EventBus로 받은 다른 listener와 race 없음 (synchronous emit). ✓
3. **Stage01 toolbar_path empty**: `get_node_or_null` null → `_disable_toolbar` no-op. ✓
4. **PauseBtn super._ready + pressed multi-connect**: Godot signal 표준 다중 connect 허용. CButton의 _on_pressed (boop)와 PauseBtn의 _on_pressed_emit 둘 다 호출. 순서 무관(emit은 동기 fan-out). ✓
5. **HUD INHERIT + Counter inherit + paused**: Godot 4 tween bound to node — node process_mode INHERIT + tree paused → tween 정지. UI_GUIDE §4 준수 + HudPauseFreezeTest로 회귀 보장. ✓
6. **Stepper INHERIT pause 중 input**: Button._on_pressed가 input processing이라 paused 시 비활성화. 의도. ✓
7. **set_disabled_state freeze 확장 호환성**: 기존 atom callers는 set_count/set_selected만 사용 (`scripts/ui/SkillToolbar.gd` 그대로 + 테스트 1군데). 새 메서드 추가는 backwards-compatible. ✓
8. **SkillSlot.disabled getter는 그대로**: Godot Button.disabled property 변경 X. `_update_visual` 분기 `disabled` 참조 그대로 동작. ✓
9. **UI_GUIDE §3.4 freeze 확장 = SoT 단일 갱신**: 본 plan §5.4 + UI_GUIDE §3.4 1줄 추가만. 다른 atom doc 영향 0. ✓
10. **AtomShowcaseTest 회귀**: showcase는 atom 시각/단독 테스트 — SkillSlot set_disabled_state 추가는 기존 시각/메서드 변경 X. 회귀 위험 0. (추가 보강: showcase에서 새 메서드 1회 호출 시각 검증 — defer phase 11 not required) ✓
11. **Toolbar reentry**: 같은 stage RESTART 시 toolbar free → 새로 생성 → EventBus connect는 `is_connected` 가드라 중복 0. SkillToolbarReentryTest로 회귀 보장. ✓
12. **show_dialog 호출자 검증**: impl 첫 단계 `grep -rn "show_dialog" scripts/ tests/`. 호출자 0이면 메서드 자체 제거 (deprecated alias 불필요). ✓
13. **AcceptDialog scene 삭제 시 .uid 잔존**: HUD.tscn replace 시 AcceptDialog 노드 자체 사라짐 → ext_resource 없음. .uid 영향 0. ✓
14. **CButton subclass 검증**: GDScript `extends CButton` 표준 동작. CButton의 export `kind: ButtonKind`도 상속됨. PauseBtn `kind = ButtonKind.GHOST` 정상. ✓
15. **HBoxContainer + Counter(Control) 자식**: Counter는 custom_minimum_size=(110,84) Control. HBox는 minimum_size 존중. 사이즈 보존. ✓
16. **HBoxContainer + SkillSlot(Button) 자식**: SkillSlot custom_minimum_size=(88,88). HBox separation 14. 동일. ✓
17. **ColorRect TopBorder 3px**: ColorRect는 단순 fill. 3px height anchor top stretch면 toolbar 상단 ink_900 띠 표시. border가 아니라 평면 ColorRect로 구현. ✓

---

## 11. 진행 절차

1. self-review 1차 (§10) — 본 plan v2 자체.
2. codex plan-review v2 (`/codex:adversarial-review` — 사용자 직접 결정 후 재호출이라 자동 사이클 정책 위배 아님. 단 v2도 HIGH 발견 시 STOP+user).
3. clean이면 impl 진입 → §2 파일 작성 → §7.1 모든 헤드리스 PASS → §7.2 grep 게이트 → §7.3 수동.
4. impl self-review → codex impl-review → clean까지 self/codex 교차.
5. `python scripts/execute.py mvp complete 11` → Notion 완료 전환 → commit `phase 11: ui-hud-toolbar-replace`.

---

## 부록 A — 신규 자산 SVG 인라인

`assets/icons/ui/pause.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="#3A2A1C">
  <rect x="6" y="4" width="4" height="16" rx="1"/>
  <rect x="14" y="4" width="4" height="16" rx="1"/>
</svg>
```

`assets/icons/ui/play.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="#3A2A1C">
  <polygon points="6,4 20,12 6,20"/>
</svg>
```

토큰 hex 직접 (`#3A2A1C` = ink_900). svg_color_map.json 갱신 불필요. SvgImportSmokeTest sanity invariant PASS (토큰 hex 1:1).
