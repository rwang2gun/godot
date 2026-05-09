# Game Flow Proposal v4 — Adversarial Review

작성일: 2026-05-09
리뷰 대상: `docs/GAME_FLOW_PROPOSAL_V4.md`
근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md` (v1)
- `docs/GAME_FLOW_PROPOSAL_REVIEW.md` (v1 리뷰)
- `docs/GAME_FLOW_PROPOSAL_V2.md` (v2)
- `docs/GAME_FLOW_PROPOSAL_V2_REVIEW.md` (v2 리뷰)
- `docs/GAME_FLOW_PROPOSAL_V3.md` (v3)
- `docs/GAME_FLOW_PROPOSAL_V3_REVIEW.md` (v3 리뷰)
리뷰어: Claude (self-review, codex 라운드 전 단계)
Verdict: **clean** (HIGH 0건). v3 리뷰의 HIGH/MEDIUM/LOW 8건 모두 흡수. 단 새로 도입된 lifecycle 명세에서 MEDIUM 3건 / LOW 6건 — phase 6 plan 작성 시 흡수 가능

---

## 1. 요약 판정

### v3 리뷰 finding 흡수 (8/8 모두 채택)

| v3 리뷰 finding | v4 처리 | 판정 |
|---|---|---|
| N1 EventBus signal signature (HIGH) | 옵션 A: `signal stage_cleared(result: Dictionary)` / `stage_failed(result: Dictionary)` | ✅ 완전 채택 |
| N2 Menu 버튼 동작 | Stage01 reload fallback (overlay.hide() + load_stage(1)) | ✅ 채택 |
| N3 Overlay show/hide lifecycle | SceneFlow가 단독 owner, 9단계 lifecycle 명시 | ✅ 채택 |
| N4 stage process_mode | `CurrentStageRoot.process_mode = DISABLED` + freeze/unfreeze helper | ✅ 채택 |
| N5 `_make_result()` helper | StageRunner에 위치, 8 키 Dictionary 반환 | ✅ 채택 |
| N6 `start_game()` wrapper | `start_game() = load_stage(1)` thin wrapper | ✅ 채택 |
| N7 Test 이름 | `tests/GameFlowTest.gd / .tscn`로 고정 | ✅ 채택 |
| N8 AntSpawner stop | process_mode DISABLED 채택으로 자동 해소 | ✅ 채택 |

v3 리뷰 finding은 모두 깔끔히 흡수됨. v4는 v3의 자연스러운 종착점.

### v4에서 새로 발견된 사항

| 식별자 | 영역 | 심각도 |
|---|---|---|
| M1 | `CurrentStageRoot` — 컨테이너 모델 vs 루트 교체 모델 모호 | **MEDIUM** |
| M2 | 마지막 stage `request_next` / Next 버튼 fallback 결정 누락 | **MEDIUM** |
| M3 | `living ants == 0` 카운트 메서드 — v3에서 v4로 이전되며 의사코드 누락 | **MEDIUM** |
| L1 | `_make_result` defensive null check가 CLAUDE.md 가이드 위반 | LOW |
| L2 | 헤드리스 테스트 2개 변경 대상에 명시적 나열 누락 | LOW |
| L3 | Stub overlay 표시 정보 범위 미정의 | LOW |
| L4 | 중복 클릭 방지 메커니즘 미명시 | LOW |
| L5 | GlobalUI 노드 타입(CanvasLayer 등) 미명시 | LOW |
| L6 | Stage01에서 Menu 클릭 = replay 동일 결과 명시 누락 | LOW |

코드 사실 확인 (review 진행 중 grep):

- `EventBus.stage_cleared(score: float)` 현재 connect 위치: **3곳** — `StageRunner.gd`, `tests/Stage02HeadlessTest.gd`, `tests/Stage03HeadlessTest.gd` ✅
- `HUD.gd`는 stage_cleared/failed를 *connect 안 함* — `candy_piece_picked / ant_saved / candy_piece_lost`만 ([HUD.gd:17-19](../scripts/ui/HUD.gd))
- 따라서 v4 §2.N1이 HUD를 영향 대상에서 뺀 것은 정확. signature 변경 영향 callback은 *정확히 3곳 6 메서드*

---

## 2. v3 리뷰 finding 처리 평가 — 세부

### N1 EventBus signal signature 변경 — 완전 채택, 호환성 정책까지 명시

v4 §2.N1이 옵션 A (Dictionary signature)를 채택하면서 **호환성 방침**까지 명시:

> Phase 6에서 기존 score/reason signal 호환을 유지하지 않는다.

이는 CLAUDE.md "Don't add error handling, fallbacks, or validation for scenarios that can't happen ... Don't use feature flags or backwards-compatibility shims when you can just change the code." 가이드와 정합. 내부 코드(MVP)에서 backward compat shim을 만들지 않는 결정은 옳다.

영향 callback 개수 검증 (코드 grep 결과):

```
StageRunner.gd:84  func _on_stage_cleared(score: float) -> void
StageRunner.gd:88  func _on_stage_failed(reason: String) -> void
Stage02HeadlessTest.gd:15-16  EventBus.stage_cleared/failed.connect(_on_cleared/_on_failed)
Stage03HeadlessTest.gd:22-23  EventBus.stage_cleared/failed.connect(_on_cleared/_on_failed)
```

총 3 파일, 6 메서드. v4 변경 대상 목록에 모두 포함되어 있는지 확인 시 LOW L2 발견 (아래).

### N2~N8

모두 plan 본문에 코드 블록·의사코드 수준으로 못박음. self-review 회차 추가 risk가 v3 대비 크게 줄음.

---

## 3. 신규 발견 사항 상세

### M1. `CurrentStageRoot` — 컨테이너 모델 vs 루트 교체 모델 모호 — **MEDIUM**

**증상**: v4 §3.2 Scene tree:

```text
Main
  SceneFlow
  CurrentStageRoot
  GlobalUI
    StageResultOverlayStub
```

그리고 freeze/unfreeze helper:

```gdscript
func _freeze_current_stage() -> void:
    if _current_stage_root != null:
        _current_stage_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_current_stage() -> void:
    if _current_stage_root != null:
        _current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
```

그리고 lifecycle:

```text
overlay.hide()
-> current stage unload
-> target stage load
-> CurrentStageRoot.process_mode = INHERIT
```

**문제**: `CurrentStageRoot`가 두 가지로 해석 가능:

| 해석 | 의미 | unload 동작 | freeze 효과 | unfreeze 필요성 |
|---|---|---|---|---|
| **A. 컨테이너 모델** | `Main.tscn`의 빈 Node, 자식으로 stage scene을 add | 자식만 free, 컨테이너 보존 | 컨테이너에 적용, 자식 stage가 inherit으로 disable | **필수** (다음 stage가 같은 컨테이너에 들어가므로 disable이 그대로 상속됨) |
| **B. 루트 교체 모델** | `CurrentStageRoot` 자체가 stage scene으로 매번 교체 | 노드 자체 free | 새 stage scene 자체에 적용 | **불필요** (새 stage 인스턴스는 default INHERIT) |

v4의 freeze/unfreeze 코드는 컨테이너 모델 가정(같은 노드를 toggle), 그런데 lifecycle 텍스트의 "current stage unload"는 루트 교체 모델 가정(노드 free). **두 모델이 섞여 있음**.

**수정안**: 컨테이너 모델로 통일. v4 §3.2에 다음을 명시:

```gdscript
# Main.tscn 구조
Main (Node)
├── SceneFlow (Node)
├── CurrentStageRoot (Node)        # 빈 컨테이너, 자식으로 stage scene을 추가
└── GlobalUI (CanvasLayer)
    └── StageResultOverlayStub (Control)

# SceneFlow 동작
func load_stage(stage_id: int) -> void:
    _unload_current_stage()                    # 자식 free
    var scene: PackedScene = load(STAGE_SCENES[stage_id])
    var stage_node: Node = scene.instantiate()
    _current_stage_root.add_child(stage_node)  # 컨테이너에 add
    _current_stage_id = stage_id

func _unload_current_stage() -> void:
    for child in _current_stage_root.get_children():
        child.queue_free()
```

이 경우 freeze/unfreeze는 컨테이너에 적용 → 자식 stage가 inherit으로 disable → 다음 stage load 후 unfreeze 호출이 *반드시 필요*.

phase 6 self-review에서 거의 확실히 짚이는 지점이므로 v4 본문에 못박는 게 좋음.

---

### M2. 마지막 stage `request_next` / Next 버튼 fallback 결정 누락 — **MEDIUM**

**증상**: v4 §3.2 완료 기준 중:

> Stage03 clear 후 마지막 stage fallback 동작

"fallback 동작"이 무엇인지 명시 없음. v3에서 v4까지 동일 표현 유지.

**옵션**:
- A: `STAGE_SCENES.has(next_id) == false`이면 SceneFlow가 `go_to_menu()` 호출 (Phase 6에서는 Stage01 reload)
- B: overlay.show(result) 시 result.stage_id가 마지막 stage이면 Next 버튼을 hide 또는 disabled
- C: Next 버튼은 항상 활성, request_next 클릭 → SceneFlow가 마지막 감지 후 Menu로 fallback

**권고 — 옵션 A + B 조합**:
- overlay 측: 마지막 stage이면 Next 버튼 disabled (사용자 시각 신호)
- SceneFlow 측: 그래도 request_next가 들어오면 (테스트/오작동) `go_to_menu()` fallback

이걸 v4 §3.2 SceneFlow lifecycle 또는 overlay 명세에 명시. 결정 안 하면 phase 6 self-review에서 "Stage03 clear 후 Next는 어떻게 되나" 질문이 들어옴.

---

### M3. `living ants == 0` 카운트 메서드 누락 — **MEDIUM**

**증상**: v3 §2.4 의사코드는 `_living_ant_count() == 0`과 주의사항으로 `get_tree().get_nodes_in_group("ants")` 기반 + invalid node 제외를 명시했지만, **v4 §3.2에서 의사코드와 주의사항이 모두 빠짐**. 텍스트로만 "living ants == 0".

**문제**:
- 카운트 방법이 group 기반인지 spawner 카운터 기반인지 결정 안 됨
- invalid node (queue_free 후 invalid가 된 노드) 제외 처리 누락
- v3보다 명세가 *후퇴*

**확인된 코드 사실**: Ant.gd:32에서 `add_to_group("ants")` 자동 등록 ([Ant.gd:32](../scripts/ant/Ant.gd)). group 기반 카운트가 그대로 동작.

**수정안**: v4 §3.2 `no_more_ants` 판정에 v3 의사코드 + 주의사항 재인용:

```gdscript
func _living_ant_count() -> int:
    var count: int = 0
    for n in get_tree().get_nodes_in_group("ants"):
        if is_instance_valid(n):
            count += 1
    return count

# _process tick:
if (_spawner_finished
    and _living_ant_count() == 0
    and score_system.in_transit_pieces == 0
    and _candy != null and _candy.hp > 0):
    _completed = true
    EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))
    return
```

`is_instance_valid(n)` 체크는 ant가 queue_free 직후 group에 잠시 남아 있는 race를 방지.

---

### L1. `_make_result` defensive null check가 CLAUDE.md 가이드 위반 — **LOW**

**증상**: v4 §2.N5 helper 구현:

```gdscript
"stage_id": stage_data.id if stage_data != null else 0,
"saved": score_system.saved_pieces if score_system != null else 0,
"lost": score_system.lost_pieces if score_system != null else 0,
"original_hp": score_system.original_hp if score_system != null else 0,
"score": score_system.score() if score_system != null else 0.0,
```

**문제**: CLAUDE.md 가이드:
> Don't add error handling, fallbacks, or validation for scenarios that can't happen. Trust internal code and framework guarantees. Only validate at system boundaries.

`_make_result`는 StageRunner._process 내부에서만 호출됨. StageRunner._process는 [StageRunner.gd:67-68](../scripts/core/StageRunner.gd)에서 이미 `if _completed or stage_data == null: return`으로 stage_data null을 차단. score_system은 [StageRunner.gd:45-46](../scripts/core/StageRunner.gd)에서 `_ready` 시점에 항상 instantiate. _process 진입 후에는 둘 다 non-null 보장.

따라서 5개 null check는 모두 dead branch. 사양 초과.

**수정안**: defensive null check 제거.

```gdscript
func _make_result(cleared: bool, reason: String) -> Dictionary:
    return {
        "stage_id": stage_data.id,
        "cleared": cleared,
        "saved": score_system.saved_pieces,
        "lost": score_system.lost_pieces,
        "original_hp": score_system.original_hp,
        "score": score_system.score(),
        "time_left": _time_left,
        "reason": reason,
    }
```

만약 _ready 실패 등 abnormal flow가 있다면 그쪽에서 fail-fast (push_error + return). _make_result는 정상 flow 가정.

---

### L2. 헤드리스 테스트 2개 변경 대상에 명시적 나열 누락 — **LOW**

**증상**: v4 §3.2 변경 대상 목록:

```
project.godot
scenes/Main.tscn
scripts/core/SceneFlow.gd
scripts/core/GameManager.gd
scripts/core/EventBus.gd
scripts/core/StageRunner.gd
scripts/core/ScoreSystem.gd
scripts/ui/StageResultOverlayStub.gd
scenes/ui/StageResultOverlayStub.tscn
tests/GameFlowTest.gd
tests/GameFlowTest.tscn
```

`Stage02HeadlessTest.gd`, `Stage03HeadlessTest.gd`가 빠짐. v4 §2.N1 변경 대상 텍스트에는 "stage result signal을 구독하는 headless tests"로 추상적 언급 있음.

**수정안**: §3.2 변경 대상 목록에 명시:

```
tests/Stage02HeadlessTest.gd  # _on_cleared/_on_failed signature 변경
tests/Stage03HeadlessTest.gd  # _on_cleared/_on_failed signature 변경
```

---

### L3. Stub overlay 표시 정보 범위 미정의 — **LOW**

**증상**: v4 §3.2 StageResultOverlayStub 명세:
- 위치, 버튼, 클릭 동작은 명시
- 어떤 정보를 표시하는지는 미명시
- Phase 12에서 saved/lost/score/time/stars 표시 명시

**문제**:
- stub이 단순 버튼만 가지면 사용자가 결과 차이 못 알아봄 (clear vs failed)
- 본격 dialog는 Phase 12로 미루고 stub은 어디까지 표시?

**권고**: stub은 다음 3개만 표시:
- `cleared` (Cleared / Failed 텍스트)
- `score` (퍼센트)
- `reason` (failed일 때만)

stars / motion / saved/lost 분리 표시는 Phase 12. 이걸 phase 6 plan에 한 줄 명시.

---

### L4. 중복 클릭 방지 메커니즘 미명시 — **LOW**

**증상**: v4 §3.2 "결과 표시 중 중복 클릭을 막는다"고만 명시.

**옵션**:
- A: 버튼 클릭 즉시 `_button_disabled = true` flag, overlay.hide() 후 false로 reset
- B: overlay.show() 시 Mouse Filter STOP 모드, hide() 시 IGNORE
- C: 첫 클릭 시 `set_buttons_disabled(true)` 호출, hide()에서 reset

**권고**: 옵션 C — 모든 버튼 disable + hide. 명시적이고 디버깅 쉬움. plan에 한 줄.

---

### L5. GlobalUI 노드 타입 미명시 — **LOW**

**증상**: v4 §3.2 Scene tree에 `GlobalUI` 노드 타입 미명시.

**판정**: stub overlay가 화면 좌표에 떠야 하므로 CanvasLayer가 자연스러움. 단 Stage scene 안의 HUD ([HUD.gd:1](../scripts/ui/HUD.gd) — `class_name HUD extends CanvasLayer`)와 z-order 충돌 가능. CanvasLayer.layer 번호로 분리 (stage HUD = 1, GlobalUI = 10 등).

**수정안**: phase 6 plan에 명시:
```
GlobalUI (CanvasLayer, layer = 10)
└── StageResultOverlayStub (Control)
```

---

### L6. Stage01에서 Menu 클릭 = replay 동일 결과 명시 누락 — **LOW**

**증상**: v4 §2.N2 Menu fallback:
```
Menu -> EventBus.request_menu.emit()
SceneFlow.go_to_menu()
  -> overlay.hide()
  -> load_stage(1)
```

Stage01에서 Menu 클릭 시 → Stage01 unload → Stage01 load → 사용자에겐 Replay와 구별 불가. Phase 6 임시 동작이므로 허용 가능하지만 명시 없음.

**수정안**: plan에 한 줄. "Phase 6 시점 Menu 클릭은 Stage01 reload이므로 Stage01 도중 Menu = Replay와 같은 결과. Phase 13에서 실제 menu scene으로 차별화."

---

## 4. v1 → v4 진화 요약

| 영역 | v1 | v2 | v3 | v4 | 본 리뷰 |
|---|---|---|---|---|---|
| Phase 6 신설 | ✓ | ✓ | ✓ | ✓ | 채택 |
| ScoreSystem stop 위치 | game-flow Step 6 | 선행 | Pre-Phase 6 | Pre-Phase 6 | 채택 |
| Result payload | 3안 양다리 | Dict | Dict 8 키 | Dict 8 키 | 채택 |
| EventBus signal | 미명시 | 미명시 | request_* 3개 | + Dict signature | 채택 |
| no_more_ants | Step 5 | game-flow 포함 | 코드 블록 | 텍스트로 후퇴 | **M3 보강 필요** |
| process_mode | — | — | — | DISABLED | 채택 (M1 구조 보강) |
| `_make_result` | — | — | — | StageRunner | 채택 (L1 simplify) |
| Menu 동작 | — | — | "no-op or 로그" | Stage01 reload | 채택 (L6 명시) |
| Overlay lifecycle | — | — | "unload와 분리" | 9단계 명시 | 채택 (M1 구조 보강) |
| Last stage Next | — | "fallback" | "fallback" | "fallback" | **M2 결정 필요** |
| Renumber 순서 | — | 미명시 | high→low | high→low | 채택 |
| Build gate | 없음 | phase 12 끝 | phase 13 끝 | phase 13 끝 | 채택 |

---

## 5. 권고

### 5.1 Phase 6 plan 작성 시 본문에 못박기 (MEDIUM 3건)

- **M1**: `CurrentStageRoot`를 컨테이너 모델로 명시 (빈 Node, stage scene을 자식으로 add/remove). freeze/unfreeze가 필수 의미를 가짐
- **M2**: 마지막 stage Next 버튼 = disabled, request_next fallback = `go_to_menu()` (옵션 A+B 조합)
- **M3**: `_living_ant_count()` helper 코드 블록을 v3 의사코드로 복원, `is_instance_valid` 체크 포함

### 5.2 Plan 작업 중 흡수 (LOW 6건)

- **L1**: `_make_result`의 defensive null check 5개 제거 (CLAUDE.md 가이드 정합)
- **L2**: 변경 대상 목록에 `tests/Stage02HeadlessTest.gd`, `tests/Stage03HeadlessTest.gd` 명시
- **L3**: stub overlay 표시 정보 = cleared / score / reason 3개로 한정
- **L4**: 중복 클릭 방지 = 버튼 disable + hide
- **L5**: `GlobalUI`를 `CanvasLayer (layer=10)`로 명시
- **L6**: "Phase 6 Menu = Stage01 reload" race를 plan에 명시

### 5.3 v4 본문에 즉시 반영 권장 사항 (선택)

- M1 구조 명시 (가장 self-review 흔들림 큰 항목)
- M3 의사코드 복원 (v3에서 v4로 후퇴한 항목)

M2/L1~L6는 phase 6 plan 작성 단계에서 자연스럽게 흡수 가능.

---

## 6. v4 그대로 진행 가능 여부

- v3 리뷰 finding 8개 모두 흡수 — v4는 v3 리뷰의 자연스러운 종착점
- HIGH 0건, MEDIUM 3건은 phase 6 plan 작성 시 결정 가능한 범위
- 사이클 종료 권고: v5 발행 없이 **v4를 결정안으로 채택** + phase 6 plan 작성 단계에서 M1~M3 결정 통합

---

## 7. Verdict

- v1 → v2 → v3 → v4 사이클: **수렴 완료**. v4는 v3 리뷰를 빠짐없이 흡수하면서 plan-level 결정까지 모두 코드/의사코드 수준으로 못박음
- v4 자체: **clean** (HIGH 0건)
- 다음 행동:
  1. v4를 결정안으로 채택 (in-place 보강 또는 v5 없이)
  2. M1, M3는 v4 본문에 한 줄 추가하면 더 안전 (선택)
  3. Pre-Phase 6 hot-fix 진행
  4. phase 6 plan 작성 단계에서 M2, L1~L6 흡수
  5. 이후 codex 적대적 리뷰 (CLAUDE.md 정책)

### 미해결 결정 사항 (사용자 입력 필요)

1. **v4 in-place 보강 방식**:
   - A: M1 + M3만 본문에 추가 (가장 self-review risk 큰 항목)
   - B: M1~M3 + L1~L6 모두 in-place (가장 안전, 변경량 큼)
   - C: 보강 없이 v4 채택, phase 6 plan에서 흡수
2. **사이클 종료 시점**:
   - v4를 마지막으로 채택 → phase 6 plan 작성 진입
   - 또는 v5로 한 번 더
3. **선행 작업 순서**: Pre-Phase 6 hot-fix vs phase plan renumbering 중 어느 것 먼저
