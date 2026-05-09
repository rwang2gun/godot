# Game Flow Proposal v5 — Adversarial Review

작성일: 2026-05-09
리뷰 대상: `docs/GAME_FLOW_PROPOSAL_V5.md`
근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md` (v1) ~ `docs/GAME_FLOW_PROPOSAL_V4.md` (v4)
- 각 버전별 리뷰 4개 (`*_REVIEW.md`, `*_V2_REVIEW.md`, `*_V3_REVIEW.md`, `*_V4_REVIEW.md`)
리뷰어: Claude (self-review, codex 라운드 전 단계)
Verdict: **clean** (HIGH 0건). v4 리뷰의 MEDIUM 3건 / LOW 6건 모두 흡수. 사이클 수렴 — v5를 결정안으로 채택 권고

---

## 1. 요약 판정

### v4 리뷰 finding 흡수 (9/9 모두 채택)

| v4 리뷰 finding | v5 처리 | 판정 |
|---|---|---|
| M1 `CurrentStageRoot` 컨테이너 모델 | §2.4에서 컨테이너 모델 명시 + load/unload/freeze 코드 | ✅ 완전 채택 |
| M2 마지막 stage Next fallback | §2.7 `LAST_STAGE_ID := 3` + Next disabled + load_next_stage fallback | ✅ 완전 채택 |
| M3 `_living_ant_count()` 메서드 | §2.9 helper 코드 + `is_instance_valid()` | ✅ 완전 채택 |
| L1 `_make_result` defensive null 제거 | §2.3 fail-fast 방침 명시 + null check 제거된 helper | ✅ 채택 |
| L2 헤드리스 테스트 변경 대상 | §2.1 / §3.2 변경 대상에 명시 | ✅ 채택 |
| L3 stub overlay 표시 범위 | §2.6에서 cleared/score/reason 3개로 한정 | ✅ 채택 |
| L4 중복 클릭 방지 메커니즘 | §2.6 첫 클릭 시 모든 버튼 disabled + hide 시 reset | ✅ 채택 |
| L5 GlobalUI 노드 타입 | §2.4 `CanvasLayer (layer = 10)` 명시 | ✅ 채택 |
| L6 Stage01 Menu = Replay race | §2.8에서 명시적 허용 | ✅ 채택 |

v4 리뷰의 9개 finding이 **모두 깔끔히 흡수**. v5는 사이클 수렴의 자연스러운 종착점.

### v5에서 새로 발견된 사항

| 식별자 | 영역 | 심각도 |
|---|---|---|
| C1 | `load_stage()`와 lifecycle (§2.4 vs §2.5) 책임 중첩 — `_hide_result_overlay()` 호출 위치 | **MEDIUM** |
| C2 | `_hide_result_overlay()` / `replay_stage()` 함수 본문 미명시 | LOW |
| C3 | `_current_stage_id` 초기값 미명시 | LOW |
| C4 | `tests/GameFlowTest.tscn` 검증 항목 리스트 미명시 | LOW |
| C5 | stage scene의 process_mode default 가정 미명시 | LOW |

코드 사실 확인 (review 진행 중):
- 모든 `.tscn` 파일에 `process_mode` 명시 설정 없음 → default `INHERIT` ✅
- v5의 컨테이너 freeze 모델이 모든 stage scene에서 안전하게 동작
- C5는 plan 본문에 가정만 명시하면 self-review에서 한 번 덜 흔들림

---

## 2. v4 리뷰 finding 처리 평가 — 세부

### M1 CurrentStageRoot — 완전 해소

v5 §2.4가 컨테이너 모델로 명확히 결정:

```gdscript
func load_stage(stage_id: int) -> void:
    _hide_result_overlay()
    _unload_current_stage()
    _current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
    var scene: PackedScene = load(STAGE_SCENES[stage_id])
    var stage_node: Node = scene.instantiate()
    _current_stage_root.add_child(stage_node)
    _current_stage_id = stage_id

func _unload_current_stage() -> void:
    for child in _current_stage_root.get_children():
        child.queue_free()
```

`CurrentStageRoot` 자체가 stage가 아니라 **항상 존재하는 빈 컨테이너**임을 §2.4 주의에서 못박음:

> `CurrentStageRoot` 자체를 stage scene으로 교체하지 않는다.
> stage scene은 `CurrentStageRoot`의 자식으로만 add/remove한다.

이 결정이 freeze/unfreeze의 의미를 일관되게 만듦.

### M2 마지막 stage fallback — 완전 해소

v5 §2.7이 두 단계 방어로 결정:

1. UI 측: `result.stage_id == LAST_STAGE_ID`이면 Next 버튼 disabled (사용자 시각 신호)
2. SceneFlow 측: `STAGE_SCENES.has(next_id) == false`이면 `go_to_menu()` fallback

```gdscript
func load_next_stage() -> void:
    var next_id := _current_stage_id + 1
    if not STAGE_SCENES.has(next_id):
        go_to_menu()
        return
    load_stage(next_id)
```

`LAST_STAGE_ID` 상수화도 stage 추가 시 한 줄만 갱신하도록 일관됨.

### M3 living ants count — 완전 해소

v5 §2.9가 v3 의사코드를 복원:

```gdscript
func _living_ant_count() -> int:
    var count: int = 0
    for n in get_tree().get_nodes_in_group("ants"):
        if is_instance_valid(n):
            count += 1
    return count
```

`is_instance_valid()` 사용 근거까지 §2.9 끝에 명시:
> `is_instance_valid()`는 queue_free 직후 남아 있을 수 있는 stale reference를 피하기 위한 방어다.

### L1~L6 — 모두 본문 승격

v5 §2.3 (defensive null 제거), §2.6 (stub 표시 범위 + 중복 클릭), §2.4 (`CanvasLayer layer=10`), §2.8 (Replay/Menu 동일 결과 명시적 허용)에서 모두 plan 본문 결정으로 승격됨. v4 리뷰가 "phase 6 plan 작성 시 흡수"로 미뤘던 항목들이 v5에서 *선결*됨.

---

## 3. 신규 발견 사항 상세

### C1. `load_stage()`와 overlay lifecycle 책임 중첩 — **MEDIUM**

**증상**: v5에서 두 곳이 hide 책임을 동시에 가짐.

**§2.4 load_stage 함수 본문**:
```gdscript
func load_stage(stage_id: int) -> void:
    _hide_result_overlay()      # ← hide 책임 ①
    _unload_current_stage()
    _current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
    ...
```

**§2.5 Lifecycle 텍스트**:
```text
User clicks Replay / Next / Menu
Overlay disables all buttons
Overlay emits request_*
SceneFlow hides overlay        # ← hide 책임 ②
SceneFlow unloads current stage child
SceneFlow loads target stage child
SceneFlow unfreezes CurrentStageRoot
```

**문제**:
- request_* signal handler에서 `SceneFlow hides overlay` 후 `load_stage()`를 호출하면, `load_stage()` 내부의 `_hide_result_overlay()`가 *재호출*됨
- idempotent하면 안전하지만, hide 책임이 lifecycle handler와 load_stage 양쪽에 분산되어 mental model이 흐려짐
- `start_game()` → `load_stage(1)` 첫 호출 시점에는 overlay가 아직 없으므로 `_hide_result_overlay()`가 dummy call이 됨

**책임 분리 옵션**:

**옵션 A (권장)**: `load_stage()`는 *순수 stage 교체*만 담당. hide/freeze는 caller(request handler) 책임.

```gdscript
# request_replay handler
func _on_request_replay() -> void:
    _hide_result_overlay()
    _unfreeze_current_stage()
    load_stage(_current_stage_id)  # 순수 교체

func load_stage(stage_id: int) -> void:
    _unload_current_stage()
    var scene: PackedScene = load(STAGE_SCENES[stage_id])
    var stage_node: Node = scene.instantiate()
    _current_stage_root.add_child(stage_node)
    _current_stage_id = stage_id
```

**옵션 B**: `load_stage()`가 모든 lifecycle 단계 흡수. lifecycle 텍스트는 단순히 load_stage 호출로 단축.

```text
User clicks Replay/Next/Menu
Overlay disables all buttons
Overlay emits request_*
SceneFlow calls load_stage()  # hide + unload + load + unfreeze 일괄
```

**판정**: 옵션 A가 책임 분리 측면에서 깔끔. 단 v5 §2.4 코드는 옵션 B에 가까운 형태로 작성됨. 결정 필요.

phase 6 plan 작성 시 옵션 A/B 중 택일하여 lifecycle 텍스트와 `load_stage` 코드를 일관되게 만들 것.

---

### C2. `_hide_result_overlay()` / `replay_stage()` 함수 본문 미명시 — **LOW**

**증상**:
- §2.4 `load_stage`에서 `_hide_result_overlay()` 호출하지만 정의 없음
- SceneFlow API에 `replay_stage()` 선언만 있고 §2.7~§2.9 어디에도 본문 없음

**추정 본문**:
```gdscript
func _hide_result_overlay() -> void:
    if _result_overlay != null:
        _result_overlay.hide()
        _result_overlay.reset_buttons()  # 중복 클릭 방지 reset

func replay_stage() -> void:
    load_stage(_current_stage_id)
```

**수정안**: phase 6 plan에서 본문 명시. 큰 문제 아님.

---

### C3. `_current_stage_id` 초기값 미명시 — **LOW**

**증상**: v5에서 `_current_stage_id` 변수가 §2.4 / §2.7에 등장하지만 초기값 미명시.

**문제**:
- 0 / -1 / 1 중 어느 값?
- `start_game()` 호출 전에 `load_next_stage()` 호출되면? (`_current_stage_id + 1` = ?)

**판정**: 실제 흐름상 `start_game()`이 항상 먼저 호출되므로 초기값이 무엇이든 큰 문제 없음. 단 plan에 한 줄 명시:

```gdscript
var _current_stage_id: int = 0  # start_game() 전에는 invalid
```

---

### C4. GameFlowTest 검증 항목 리스트 미명시 — **LOW**

**증상**: v5 §3.2 완료 기준에 "tests/GameFlowTest.tscn 통과"가 있지만 그 테스트가 무엇을 검증하는지 명시 없음.

**판정**: v5의 다른 섹션에서 명세 깊이를 늘리는 방향으로 일관되게 갔으므로, 이 항목도 같이 명시하면 일관됨. 단 phase 6 plan에서 자연스럽게 흡수 가능.

**권고 검증 항목** (plan 작성 시 참고):
- start_game() 후 Stage01이 CurrentStageRoot의 자식으로 add됨
- stage_cleared(result) emit 시 CurrentStageRoot.process_mode == DISABLED, overlay visible
- request_next emit 시 다음 stage가 같은 컨테이너의 자식으로 교체됨
- request_replay emit 시 같은 stage가 새로 instantiate됨
- LAST_STAGE_ID stage에서 request_next → go_to_menu fallback (Stage01 reload)
- _make_result Dictionary 8 키 모두 채워짐
- no_more_ants 판정이 time_out 전에 발생

---

### C5. stage scene process_mode default 가정 미명시 — **LOW**

**증상**: v5 §2.4 컨테이너 freeze 모델은 stage scene의 process_mode가 INHERIT(default)이라는 가정에 의존.

**확인된 코드 사실**: 모든 `.tscn` 파일에 `process_mode` 명시 설정 없음 → default INHERIT. 가정 성립.

**수정안**: plan에 한 줄 명시:
> 모든 stage scene은 process_mode = INHERIT(default)를 유지한다. CurrentStageRoot 컨테이너의 freeze가 자식에게 inherit으로 전파된다.

향후 stage scene이 명시적으로 다른 process_mode를 설정하지 않도록 하는 가드. 큰 문제 아님.

---

## 4. v1 → v5 진화 요약

| 영역 | v1 | v2 | v3 | v4 | v5 | 본 리뷰 |
|---|---|---|---|---|---|---|
| Phase 6 신설 | ✓ | ✓ | ✓ | ✓ | ✓ | 채택 |
| ScoreSystem stop | game-flow Step 6 | 선행 | Pre-Phase 6 | Pre-Phase 6 | Pre-Phase 6 | 채택 |
| Result payload | 3안 양다리 | Dict | Dict 8 키 | Dict 8 키 | Dict 8 키 + fail-fast 명시 | 채택 |
| EventBus signal | 미명시 | 미명시 | request_* 3개 | + Dict signature | + 호환 shim 없음 | 채택 |
| no_more_ants | Step 5 | game-flow 포함 | 코드 블록 | 텍스트로 후퇴 | helper + is_instance_valid | 채택 |
| process_mode | — | — | — | DISABLED | DISABLED + container 모델 | 채택 (C5) |
| `_make_result` | — | — | — | StageRunner | + null check 제거 | 채택 |
| Menu 동작 | — | — | "no-op or 로그" | Stage01 reload | + Replay 동일 허용 | 채택 |
| Overlay lifecycle | — | — | "unload와 분리" | 9단계 명시 | + 책임 분리 (StageRunner/Overlay/SceneFlow) | 채택 (C1 책임 중첩) |
| Last stage Next | — | "fallback" | "fallback" | "fallback" | LAST_STAGE_ID + 두 단계 방어 | 채택 |
| Renumber 순서 | — | 미명시 | high→low | high→low | high→low | 채택 |
| Build gate | 없음 | phase 12 끝 | phase 13 끝 | phase 13 끝 | phase 13 끝 | 채택 |
| Stub 표시 범위 | — | — | — | — | cleared/score/reason | 채택 |
| Stub 중복 클릭 | — | — | — | — | 첫 클릭 시 disabled | 채택 |
| GlobalUI 타입 | — | — | — | — | CanvasLayer layer=10 | 채택 |
| `LAST_STAGE_ID` 상수화 | — | — | — | — | ✓ | 채택 |

5번의 사이클 끝에 사실상 모든 plan-level 결정이 코드/의사코드 수준으로 명시됨.

---

## 5. 권고

### 5.1 사이클 종료 권고

v5를 **결정안으로 채택** + 사이클 종료. 근거:

- v4 리뷰 finding 9개 모두 흡수 — finding 잔존 0건
- 신규 발견 MEDIUM 1건은 phase 6 plan 작성 시 옵션 A/B 결정만 하면 해소
- 신규 발견 LOW 4건은 plan 본문 작성 단계에서 자연스럽게 흡수 가능
- v6 발행 시 한계 효용 매우 낮음 — 추가 사이클이 plan 진입을 늦추는 비용이 더 큼

### 5.2 phase 6 plan 작성 시 결정 사항 (1건)

- **C1 옵션 A vs B**:
  - A (권장): `load_stage()`는 순수 stage 교체. lifecycle 단계는 caller가 hide/freeze/unfreeze 관리
  - B: `load_stage()`가 모든 단계 흡수. lifecycle 텍스트 단축
  - 권고: 옵션 A. 책임 분리 명확

### 5.3 plan 작성 중 흡수 (4건)

- C2: `_hide_result_overlay()`, `replay_stage()` 본문 명시
- C3: `_current_stage_id` 초기값 명시
- C4: GameFlowTest 검증 항목 7개 명시 (위 §3.C4 권고 참고)
- C5: stage scene process_mode INHERIT 가정 한 줄 명시

### 5.4 다음 작업 순서 권고

```text
1. v5를 결정안으로 채택 (이 리뷰 후 in-place 보강 없이 진행)
2. Pre-Phase 6 hot-fix 구현 → commit 1
3. phase plan renumbering (high → low) → commit 2
4. phase 6 plan 작성 (C1 옵션 A 결정 + C2~C5 흡수) → C3 plan 단계
5. phase 6 implementation → commit 3
6. codex 적대적 리뷰 (CLAUDE.md 정책)
```

---

## 6. Verdict

- v1 → v2 → v3 → v4 → v5 사이클: **수렴 완료**. 5번의 자체 적대적 리뷰 사이클 끝에 사실상 모든 plan-level 결정이 코드 수준으로 못박힘
- v5 자체: **clean** (HIGH 0건)
- 다음 행동:
  1. v5를 결정안으로 채택
  2. 사이클 종료 (v6 비추천)
  3. Pre-Phase 6 hot-fix 진행 또는 phase 6 plan 작성 진입
  4. C1 옵션 A/B는 plan 작성 단계에서 결정

### 미해결 결정 사항 (사용자 입력 필요)

1. **v5 in-place 보강 필요 여부**:
   - A (권장): 보강 없이 v5 채택, plan 작성 단계에서 C1~C5 흡수
   - B: C1만 v5 본문에 in-place 보강 (옵션 A 결정 반영)
   - C: C1~C5 모두 in-place
2. **다음 작업**:
   - A: Pre-Phase 6 hot-fix 구현부터
   - B: phase plan renumbering부터
   - C: phase 6 plan 작성부터 (renumbering은 plan 후)
3. **사이클 종료 여부**: v5로 마무리 / v6로 한 번 더

---

## 7. 사이클 회고 — 1줄 메모

| 라운드 | 핵심 변화 | finding 수 (HIGH/MEDIUM/LOW) |
|---|---|---|
| v1 | 최초 진단 + 추천안 (13개 phase +1) | — |
| v1 review | 진단 채택, slot swap 옵션 제시 (오류) | 0 / 1 / 1 |
| v2 | swap 오류 교정, mass-rename 채택 | — |
| v2 review | mass-rename 안전성 보강 | 0 / 4 / 4 |
| v3 | 의사코드 도입 | — |
| v3 review | EventBus signature 충돌 발견 | 1 / 4 / 3 |
| v4 | signature 결정, lifecycle 명시 | — |
| v4 review | lifecycle 모호성 발견 | 0 / 3 / 6 |
| v5 | 모든 plan-level 결정을 본문 승격 | — |
| **v5 review** | **사이클 수렴** | **0 / 1 / 4** |

각 라운드에서 HIGH가 점차 줄어들고 MEDIUM/LOW도 phase 6 plan 작성으로 흡수 가능한 범위로 수렴. v5 → v6는 한계 효용 낮음. plan 진입 권고.
