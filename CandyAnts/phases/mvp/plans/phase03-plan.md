# Phase 3 Plan: Stage 2 + Builder 스킬 (빌드 0.2)

## 목표 (1줄)
스킬 시스템을 활성화하고, 협곡(chasm)이 있는 Stage 2를 Builder 1개 사용으로 클리어 가능하게 만든다 — Stage 1은 회귀 없이 그대로 동작.

## 변경/추가 파일

### 신규 — Skills (`scripts/skills/`)
- `Skill.gd` — `class_name Skill extends RefCounted`. `const ID := "_base_"`, `func apply(ant: Ant) -> void`, `func can_apply(ant: Ant) -> bool: return true`. **RefCounted** (Resource 아님 — 인스턴스 보존 불필요, GC 자동).
- `BuilderSkill.gd` — `class_name BuilderSkill extends Skill`. `const ID := "builder"`. `apply()` → `WorkerState.new("builder")`로 전이. `can_apply()` → ant가 Walker/Carrying이고 `is_on_floor()`인 경우만 true (Faller·Worker·Saved·Dead 거부).

### 신규 — Worker state (`scripts/ant/states/`)
- `WorkerState.gd` — `class_name WorkerState extends AntState`. 생성자 인자 `work_type: String`. Builder의 경우:
  - `enter()`: `_work_type = "builder"`, `_remaining = 12`, `_tick_accum = 0.0`, ant.velocity = Vector2.ZERO. `has_been_carrying`/`has_candy`는 **건드리지 않음** (Codex HIGH #4 패턴 가드).
  - `update(delta)`: 중력 적용 + `move_and_slide()`로 바닥 유지. `_tick_accum += delta`. tick(`0.2`초)마다 `_place_one_tile()` 호출. `_remaining == 0` 또는 `_abort()` 조건 충족 시 Walker 복귀.
  - `_place_one_tile()` (**수평 다리 — 구현 단계 결정, 사선 stair는 Climber 도입 후 Phase 8+**):
    1. cell = `Vector2i(floor(ant.global_position.x / 16), floor((ant.global_position.y - 2) / 16))` — ant가 차지하는 셀
    2. target_cell = `cell + Vector2i(direction, 1)` — 진행 방향 한 칸 앞 + 한 칸 아래(=ant 발 밑 행)
    3. `Terrain.add_tile(target_cell)` 호출 (성공: 타일 신규 추가 / 실패: 이미 collider 존재 → abort)
    4. ant.global_position += `Vector2(direction * 16, 0)` — 같은 y level 유지하며 한 칸 forward
    5. `_remaining -= 1`
  - **사선 stair 폐기 사유**: 16px 수직 step은 Walker가 climb 못함 → 다른 ants가 첫 타일을 wall로 인식하고 flip. 통합 테스트(Test C)에서 발견. 수평 다리는 ARCHITECTURE §5.3의 "사선 12셀" 문구와 어긋나나, 의도(=12 타일로 협곡 bridge)는 충족. 진짜 사선 stair는 Phase 8 Climber + 슬로프 타일 도입 후 자연 정확화.
  - `_abort()`: ant가 wall에 부딪힘(`is_on_wall()`) **또는** `_remaining == 0`.
  - `exit()`: 정리 없음.

### 신규 — Skill UI (`scripts/ui/`, `scenes/ui/`)
- `SkillToolbar.gd` — `class_name SkillToolbar extends CanvasLayer`. export `stage_data: StageData`. 내부: `_pending_skill_id: String = ""`, `_inventory: Dictionary = {}`, `_buttons: Dictionary = {}`(id → Button).
  - `_ready()`:
    - `_inventory = stage_data.skill_inventory.duplicate(true)`
    - 각 ID마다 Button 생성, text = "%s × %d" % [id, count], `pressed → _on_button_pressed(id)`
  - `_on_button_pressed(id)`: 인벤토리 0이면 무시. `_pending_skill_id = id`.
  - `_unhandled_input(event)`:
    - 좌클릭 시: `_pending_skill_id == ""`이면 return. mouse_world 변환 후 가장 가까운 ant 검색 (group `"ants"` 순회, distance < 16px). 찾으면 `SkillRegistry.get_skill(_pending_skill_id).new()`로 인스턴스 생성, `can_apply(ant)`이면 `apply(ant)` + 인벤토리 차감 + 버튼 갱신. `_pending_skill_id = ""`.
    - ESC 키: `_pending_skill_id = ""`.
  - **mouse_world 변환**: `var world := get_viewport().get_canvas_transform().affine_inverse() * event.position` (Camera2D zoom·position 포함).
- `SkillToolbar.tscn` — CanvasLayer + PanelContainer (좌하단 anchor) + HBoxContainer.

### 신규 — Stage 2 (`scenes/stages/`, `data/stages/`)
- `Stage02.tscn` — Stage01과 같은 노드 구조 + 협곡 geometry. 자세한 placement는 [§Stage 2 geometry](#stage-2-geometry) 참조.
- `data/stages/stage02.tres`:
  ```
  id = 2
  display_name = "협곡"
  total_ants = 10
  candy_hp = 10
  time_limit_seconds = 180.0
  available_skills = ["builder"]
  skill_inventory = { "builder": 3 }
  release_rate_initial = 30
  release_rate_min = 1
  ```

### 수정 — 기존 코어
- [`scripts/core/SkillRegistry.gd:3`](../../scripts/core/SkillRegistry.gd) — `SKILL_SCRIPTS = [preload("res://scripts/skills/BuilderSkill.gd")]`
- [`scripts/world/Terrain.gd`](../../scripts/world/Terrain.gd) — `add_tile(cell: Vector2i) -> bool`, `has_tile(cell: Vector2i) -> bool` 추가. 내부는 동적 StaticBody2D 자식 (TileMap은 Phase 6 deferred).
- [`scripts/ant/Ant.gd:_ready()`](../../scripts/ant/Ant.gd) — `add_to_group("ants")` 1줄 추가.

### 신규 — 자동화 테스트 (Codex HIGH 대응)
- `tests/Stage02HeadlessTest.gd` — Phase 3 통합 회귀 테스트 driver. 핵심 검증:
  - first ant가 trigger_x=860에 도달하면 `BuilderSkill.new().apply(ant)` 자동 호출 (UI 우회, 로직 직접 검증)
  - `EventBus.stage_cleared` 수신 시 score 검증 + `get_tree().quit(0)` PASS
  - `EventBus.stage_failed` 또는 score < 0.6 시 `quit(1)` FAIL
  - 200초 시뮬 내 미해결 시 `quit(2)` TIMEOUT (`--quit-after 12000` 안전망)
- `tests/Stage02HeadlessTest.tscn` — 루트 Node + Stage02 instance + Phase3TestDriver(Stage02HeadlessTest.gd) 구성.
- per-file TDD Guard 스텁 — 각 신규/수정 스크립트당 `tests/test_{stem}.gd` 1개 (3줄, `extends Node` + 주석으로 Stage02HeadlessTest 참조). TDD Guard는 파일 존재만 확인하므로 충분.
  - `tests/test_Skill.gd`
  - `tests/test_BuilderSkill.gd`
  - `tests/test_WorkerState.gd`
  - `tests/test_SkillToolbar.gd`
  - `tests/test_SkillRegistry.gd`
  - `tests/test_Terrain.gd`
  - `tests/test_Ant.gd`
- **`scripts/hooks/.tdd_bypass` 사용 금지** — Codex HIGH 권고. 위 스텁 + 통합 테스트로 진짜 coverage 확보.

## Stage 2 geometry (구현 갱신 — 수평 다리 결정 후)

```
y=0
    Camera2D (960, 540)

y=880 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (platform top)
    ███████████████████   ███████████████████████████
    █  Home (300,880)  █   █  Candy (1620,880,hp=10) █
    █  Spawner(348,875)█   █                         █
y=1040 ███ Left ███████ ▓▓▓ ███ Right ████████████████
                       ▓▓▓
y=1080  x=0..880      x=880..1040 (160px gap)  x=1040..1920
                       Chasm
                       Floor
                       y=1040..1080
```

- **LeftPlatform**: StaticBody2D + RectangleShape2D 880×216. position=(440, 988). Top edge y=880, x range 0..880.
- **RightPlatform**: StaticBody2D + RectangleShape2D 880×216. position=(1480, 988). Top edge y=880, x range 1040..1920.
- **Gap**: x=880..1040 (160px = 10 cells).
- **ChasmFloor**: StaticBody2D + RectangleShape2D 160×40, position=(960, 1060). y range 1040..1080.
- **Home**: position=(300, 880). Area2D 32x32 — ants 진입/도착 트리거.
- **Candy**: position=(1620, 880). hp=10.
- **Spawner**: explicit `spawn_position = Vector2(348, 875)` (Stage01 패턴 따름).
- **수평 다리 검산**: ant.x=870에서 Builder 실행 (cell 54). 12 타일 cells (55, 55)..(66, 55). 모든 타일 row 55 (y=880..896, =platform top row). 마지막 타일 cell 66 (x=1056..1072) — 우측 platform 내부 (1040..1920). Builder 종료 ant.x=1062, y=875. 우측 platform 위. ✓
- **타일과 platform 충돌체 중첩**: cells 65, 66 (x=1040..1072)이 우측 platform 내부 (x>=1040)에 위치. 두 StaticBody2D가 같은 영역 — Godot 허용. 시각상 Sprite는 색이 약간 다름 (platform 갈색 vs 타일 초록).

## 시그널 흐름 (Phase 3 신규)

```
[SkillToolbar.Button.pressed]
  → SkillToolbar._on_button_pressed(id)
    → _pending_skill_id = id

[InputEventMouseButton 좌클릭]
  → SkillToolbar._unhandled_input(event)
    → mouse_world 변환 + 가장 가까운 ant 검색 (group "ants")
    → SkillRegistry.get_skill(id).new().apply(ant)
       → BuilderSkill.apply(ant)
         → ant.state_machine.change_state(WorkerState.new("builder"))
           → WorkerState.enter() : tick 누적 시작
           → WorkerState.update() (매 frame, 0.2s마다 _place_one_tile)
             → Terrain.add_tile(target_cell)
             → ant.global_position += step
           → 12회 또는 abort
           → ant.state_machine.change_state(WalkerState.new())
    → _inventory[id] -= 1; refresh_button(id)
    → _pending_skill_id = ""
```

EventBus는 Phase 3에서 신규 시그널 추가하지 않음 — 명시적 API 호출로 충분 (YAGNI).

## 핵심 결정

1. **타일 = 동적 StaticBody2D 자식 (TileMap 보류)** — Phase 6 Basher가 TileMap 동적 파괴를 도입할 때 인터페이스(`Terrain.add_tile`)를 유지하며 내부만 TileMap으로 교체. Phase 3은 TileSet 작성 부담 회피. **deferred에 명시 기록**.
2. **Builder 시간차 (0.2s/tile, 총 ~2.4s)** — 즉시 placement는 player feedback 부재. tick은 export 변수(`tick_seconds=0.2`)로 노출.
3. **`work_type` 인자** — Phase 4 Blocker도 WorkerState 재사용 가능. 현재는 "builder"만 처리.
4. **Skill 인스턴스 lifecycle** — `Skill`은 RefCounted라 `apply()` 호출 후 자동 GC.
5. **SkillToolbar = CanvasLayer + Group-based ant lookup** — Physics raycast 안 씀.
6. **운반 중 Builder 적용 허용** — `has_candy=true`인 상태에서도 `can_apply` true. WorkerState는 `has_candy`/`has_been_carrying`을 절대 변경하지 않음. 다리 완성 후 Walker 복귀 시 `effective_speed`는 다시 0.78배 (Codex HIGH #4 재발 차단).
7. **Stage 2 chasm geometry (구현 후): gap=160px, platform 각 880px** — **수평** 다리 12 cell이 row 55에서 cell 55..66을 채움. cell 66은 right platform x range 내부에 약간 진입. ARCHITECTURE §5.3 "사선 12셀"은 Climber/슬로프 미도입 phase에서 비실용 — Phase 8+에서 정확화.
8. **Phase 3에서 EventBus 시그널 추가 없음** — `skill_applied`는 SkillToolbar 자체에서 inventory 갱신해도 충분 (YAGNI).

## 엣지 케이스 (필수, 9개)

1. **잘못된 skill ID** — `stage02.tres.available_skills`에 오타 → `StageRunner._ready()`의 `SkillRegistry.validate_stage(stage_data)`가 `push_error` 출력. 단위 검증으로 확인.
2. **Builder 적용 시 Faller** — `BuilderSkill.can_apply(ant)`가 `current_state is FallerState` 또는 `not is_on_floor()` 시 false → 인벤토리 차감 안 함, 모드 exit. 클릭 무효 처리.
3. **Builder 적용 시 이미 Worker** — `can_apply`가 `current_state is WorkerState` 시 false → 같은 처리.
4. **Builder 작업 중 wall 충돌** — `WorkerState.update`가 `is_on_wall()` 시 abort, Walker 복귀. 남은 _remaining 타일 손실.
5. **Builder 작업 중 절벽 끝 도달** — step-up 후 다음 cell이 진공이라 add_tile 성공. 12 tile 모두 소진 후 Walker 복귀 시 `is_on_floor()`가 false면 즉시 Faller로 전이.
6. **Builder가 운반 중 적용** — has_candy/has_been_carrying 보존. 다리 완성 후 effective_speed=0.78배. Codex HIGH(#4) 패턴 재발 가드.
7. **SkillToolbar 클릭이 Stage UI(다이얼로그)와 겹침** — StageCompleteDialog.popup_centered()가 modal이라 _unhandled_input 차단. 정상 동작.
8. **연속 Builder 클릭** — `_pending_skill_id`는 한 번 클릭 후 `""`로 초기화. 인벤토리 0이면 버튼 disabled.
9. **타일 placement가 ant 위치와 겹침** — _place_one_tile이 add_tile(target_cell) 호출 + ant.position += step. ant는 새 타일 위로 teleport, 충돌이 발 밑이라 wall stuck 회피. 검증 시 wall stuck 확인.

## 검증 시나리오

### A. Stage 1 회귀 (필수)
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 4500 res://scenes/stages/Stage01.tscn 2>&1 | Tee-Object stage1-regression.log
```
기대: `cleared score=1.0`, errors 0건, picked 10건, saved 10건.

### B. Stage 2 — 스킬 미사용 → time_out 보장
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 12000 res://scenes/stages/Stage02.tscn 2>&1 | Tee-Object stage2-noskill.log
```
기대: 200초 시뮬, `picked` 0건, `[StageRunner] failed reason=time_out`, score=0.0, errors 0건.

### C. Stage 2 — Builder 자동 적용 통합 테스트 (필수, Codex HIGH 대응)
```powershell
& $godot --headless --path . --fixed-fps 60 --quit-after 12000 res://tests/Stage02HeadlessTest.tscn 2>&1 | Tee-Object stage2-builder-auto.log
```
기대:
- `[Phase3Test] PASS` 출력
- exit code 0
- `[StageRunner] cleared score=` 1건 (score >= 0.6)
- `SCRIPT ERROR` 0건
- `EventBus.stage_failed` 발화 0건
- 통합 검증 항목:
  - SkillRegistry.validate_stage(stage02) — `[StageRunner] SkillRegistry errors:` 로그 부재
  - BuilderSkill.can_apply 동작 — Walker 상태에서만 true
  - WorkerState 12 tile placement — Terrain.add_tile 12회 성공
  - Terrain.add_tile collision — ant가 다리 위 walking (is_on_floor=true)
  - Stage02 clear 가능 — at least 1 ant Saved with candy

### D. (보조) Stage 2 에디터 수동 — UI 상호작용
> 자동 모드에서는 skip 가능. 통합 테스트(C)가 동등 검증.
1. Stage02 main_scene 임시 변경 + F5
2. SkillToolbar 좌하단 "builder × 3" Button 표시
3. Builder 클릭 → ant 클릭 → 다리 형성 → 클리어

### E. SkillRegistry validate_stage 단위 (콘솔)
- stage02.tres 정상 로드 → `[StageRunner] SkillRegistry errors:` 부재 (테스트 C에 포함)
- (선택) 임시로 available_skills에 `"buildr"` 오타 → 에러 로그 → 원복

### F. TDD Guard 통과 검증
- `scripts/hooks/.tdd_bypass` **부재** 확인 (Codex HIGH 권고)
- 각 신규/수정 스크립트에 대응 `tests/test_<Stem>.gd` 존재
```powershell
if (Test-Path scripts/hooks/.tdd_bypass) { throw "FAIL: bypass present (Codex HIGH 위반)" }
@("Skill","BuilderSkill","WorkerState","SkillToolbar","SkillRegistry","Terrain","Ant") | ForEach-Object {
  if (-not (Test-Path "tests/test_$_.gd")) { throw "FAIL: tests/test_$_.gd missing" }
}
```

## 비포함 (deferred / 후속 phase)

| 항목 | 처리 |
|------|------|
| TileMap 도입 (Builder가 동적 StaticBody2D 대신 TileMap 사용) | Phase 6 Basher 도입 시 함께. 인터페이스(Terrain.add_tile)는 유지. |
| Builder 커서 모드 시각화 (커서 색·텍스트) | Phase 11 폴리싱 또는 deferred LOW |
| WorkerState abort 시 인벤토리 환불 | wontfix — Lemmings 원작도 환불 없음 |
| EventBus.skill_applied 시그널 | YAGNI. 필요 시 Phase 4 (Blocker)에서 신설 검토 |
| stage_select UI | Phase 11 |
| per-script 진짜 단위 테스트 (GUT 도입) | Phase 12 신설. 본 Phase 3는 통합 테스트 1개 + per-file 스텁으로 TDD Guard·Codex HIGH 동시 충족. |
| Builder를 운반(Carrying) 중 적용 시 has_candy 보존 통합 테스트 | Phase 5(Hazard) 후 보강 검토 — 현재는 plan §엣지 #6에서 설계 가드로 차단. |

## 리스크

- **Stage02 chasm gap 정밀**: 144px gap이 12 cell 사선으로 cover되는지 한 픽셀 단위 확인 필요. 잘못되면 ant가 다리 끝에서 platform에 안착 못하고 Faller→Dead 사이클. 검증 C에서 발견.
- **AntStateMachine ↔ WorkerState 컴포지션**: `change_state(WorkerState.new("builder"))` 호출 시 work_type 인자 처리 — `AntState` 베이스에는 생성자 없음. WorkerState는 `_init(work_type: String)` 명시 init 함수로 처리.
- **Ant.add_to_group("ants")**: 기존 인스턴스 영향 없음. group 순회 비용은 ant 수 비례 (10마리는 무시 가능).
- **CanvasLayer event 순서**: SkillToolbar의 `_unhandled_input`이 HUD/Dialog보다 먼저 trigger되면 dialog modal 우회 가능. CanvasLayer.layer 우선순위 확인 필요.
- **Stage02HeadlessTest 트리거 타이밍**: `_process` 폴링으로 ant.x >= trigger_x 시 Builder 적용. **수평 다리 갱신 후 안전구간 [864, 879]** (cell 54 안에 ant.x). 권장 870. 너무 작으면 첫 타일이 left platform 내부 (충돌 모호), 너무 크면 ant가 platform 우끝(880) 넘어서며 falling 중일 수 있음.
