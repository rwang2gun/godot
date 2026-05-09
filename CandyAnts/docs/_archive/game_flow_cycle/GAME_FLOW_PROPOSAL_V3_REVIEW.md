# Game Flow Proposal v3 — Adversarial Review

작성일: 2026-05-09
리뷰 대상: `docs/GAME_FLOW_PROPOSAL_V3.md`
근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md` (v1)
- `docs/GAME_FLOW_PROPOSAL_REVIEW.md` (v1 리뷰)
- `docs/GAME_FLOW_PROPOSAL_V2.md` (v2)
- `docs/GAME_FLOW_PROPOSAL_V2_REVIEW.md` (v2 리뷰)
리뷰어: Claude (self-review, codex 라운드 전 단계)
Verdict: **needs-attention** — v2 리뷰의 8개 finding은 모두 잘 흡수. 단 v3가 도입한 의사코드에서 신규 HIGH 1건 / MEDIUM 4건 발생. HIGH 1건만 처리하면 clean

---

## 1. 요약 판정

### v2 리뷰 finding 흡수 결과 (8/8 모두 채택)

| v2 리뷰 finding | v3 처리 | 판정 |
|---|---|---|
| F1 mass rename 순서 | high → low 명시, status.json·notion 마지막에 atomic | ✅ 완전 채택 |
| F2 `request_stage_select` 일관성 | Phase 13으로 이동, Phase 6은 3 signal | ✅ 완전 채택 |
| F3 Stub overlay 버튼 | Replay/Next/Menu 3 버튼 + emit 매핑 명시 | ✅ 완전 채택 |
| F4 `no_more_ants` 식 | 코드 블록 + clear → no_more_ants → time_out 우선순위 | ✅ 완전 채택 |
| F5 게이트 중복 | "기반 검증 vs 통합 검증" 프레임으로 정리 | ✅ 채택 |
| F6 headless test 근거 | `run_test.py`가 scene path 직접 받음 명시 | ✅ 채택 |
| F7 Stage 0 명명 | `Pre-Phase 6 hot-fix`로 변경 | ✅ 채택 |
| F8 memory 갱신 | 3개 파일 명시, 권한 주의까지 추가 | ✅ 채택 |

v2 리뷰 finding은 **모두 깔끔하게 흡수**됨. v3는 v1/v2/리뷰 사이클의 자연스러운 종착점.

### v3에서 신규 발견 사항

| 식별자 | 영역 | 심각도 |
|---|---|---|
| N1 | EventBus signal 시그니처 vs Dictionary payload 불일치 | **HIGH** |
| N2 | Phase 6의 `request_menu` / `go_to_menu()` 동작 미정의 | MEDIUM |
| N3 | Stub overlay show/hide lifecycle (stage 전환 시) | MEDIUM |
| N4 | 결과 표시 중 stage process_mode/입력 우선순위 | MEDIUM |
| N5 | `_make_result()` helper 시그니처/위치 미정의 | MEDIUM |
| N6 | `start_game()` vs `load_stage(1)` 중복 | LOW |
| N7 | `tests/SceneFlowTest.gd 또는 GameFlowTest.gd` 양다리 | LOW |
| N8 | 결과 emit 후 AntSpawner stop 누락 가능성 | LOW |

코드 사실 확인 (review 진행 중 grep 검증):
- `AntSpawner.spawn_finished` signal — [AntSpawner.gd:3](../scripts/core/AntSpawner.gd) 존재 ✅
- Ant `"ants"` group 등록 — [Ant.gd:32](../scripts/ant/Ant.gd) 존재 ✅
- v3 §2.4 주의사항이 의존하는 두 메커니즘 모두 검증됨

---

## 2. 신규 발견 사항 상세

### N1. EventBus signal 시그니처 vs Dictionary payload 불일치 — **HIGH**

**증상**: v3 §2.4 의사코드:

```gdscript
EventBus.stage_cleared.emit(_make_result(true, ""))
EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))
EventBus.stage_failed.emit(_make_result(false, "time_out"))
```

하지만 현재 [EventBus.gd:8-9](../scripts/core/EventBus.gd):

```gdscript
signal stage_cleared(score: float)
signal stage_failed(reason: String)
```

**문제**:
- v3 의사코드가 Dictionary를 emit하려 하지만 signal 시그니처는 `float` / `String` 단일 인자
- GDScript signal은 시그니처가 명시된 경우 emit 인자 타입과 맞아야 함 (느슨한 검증이지만 connect 측에서 typed callback이면 에러)
- 더 큰 문제: 현재 [StageRunner.gd:84-90](../scripts/core/StageRunner.gd)이 `_on_stage_cleared(score: float)`, `_on_stage_failed(reason: String)`로 받음. v3 적용 시 *consumer 시그니처도 함께 변경*되어야 하는데 v3는 emit만 명시
- ScoreSystem과 SceneFlow 양쪽 다 영향받음
- phase 6 self-review에서 거의 확실히 흔들리는 지점

**수정 옵션**:

**A. 기존 signal 시그니처 변경 (권장)**
```gdscript
# EventBus.gd
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
```
- StageRunner의 emit 측 일관성 ↑
- StageDialog/SaveData 모두 result 1개 인자만 받음
- 단점: 기존 ScoreSystem이 score만 받던 패턴 변경 (현재 별 영향 없음)

**B. 새 signal 추가, 기존 보존**
```gdscript
signal stage_cleared(score: float)        # 기존, deprecate
signal stage_failed(reason: String)       # 기존, deprecate
signal stage_completed(result: Dictionary) # 새로 추가, cleared/failed 통합
```
- 두 signal 시스템이 공존 → MVP 동안 혼란
- 비추천

**C. 인자 2개**
```gdscript
signal stage_cleared(score: float, result: Dictionary)
signal stage_failed(reason: String, result: Dictionary)
```
- 정보 중복 (`result.score`, `result.reason`)
- 비추천

**권고**: 옵션 A. v3 §3.2 EventBus 추가 signal 블록에 다음을 명시:

```gdscript
# 기존 시그니처 변경 (Phase 6에서 수행)
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)

# 새로 추가
signal request_replay
signal request_next
signal request_menu
```

그리고 Phase 6 변경 대상에 다음을 명시적으로 추가:
- `scripts/core/StageRunner.gd` — `_on_stage_cleared(result: Dictionary)`, `_on_stage_failed(result: Dictionary)` 시그니처 변경
- 헤드리스 테스트가 두 signal을 구독한다면 그 callback도 변경 (현재 [Stage02HeadlessTest.gd](../tests/Stage02HeadlessTest.gd) / [Stage03HeadlessTest.gd](../tests/Stage03HeadlessTest.gd) 확인 필요)

---

### N2. Phase 6의 `request_menu` / `go_to_menu()` 동작 미정의 — **MEDIUM**

**증상**: v3 §3.2 완료 기준:

> Menu 버튼은 현재 Phase 6 범위에서 no-op 또는 로그 fallback으로 안전 처리

그리고 `SceneFlow.go_to_menu()` API는 정의됨. 하지만 Phase 13까지 Title/Menu scene 없음.

**문제**:
- Stub overlay의 Menu 버튼 클릭 → `EventBus.request_menu.emit()` → SceneFlow.go_to_menu() 호출
- 그런데 menu scene이 없으니 `go_to_menu()`는 무엇을 하는가?
  - 옵션 ①: no-op (overlay만 닫음)
  - 옵션 ②: 로그만 찍음, overlay 그대로
  - 옵션 ③: Stage01로 돌아가기
- "no-op 또는 로그 fallback"으로 두 옵션을 양다리. 결정 안 됨

**수정안**: Phase 6에서는 다음으로 못박는다:
- Phase 6: `go_to_menu()`는 로그 + overlay.hide() + Stage01 reload (current stage 무관하게 시작점 복귀)
- Phase 13: `go_to_menu()`를 실제 menu scene 전환으로 교체

근거: 사용자 의도("제대로 돌아가는 빌드")에 부합. Stage 도중 Menu 클릭 → Stage01로 복귀가 "메뉴 임시 대용"으로 가장 자연스러움.

또는 더 단순하게: Phase 6의 Menu 버튼은 *비활성화* (visible이지만 disabled). Phase 13에서 활성화. 이쪽이 더 보수적.

어느 쪽이든 v3 §3.2에 한 줄 못박을 것.

---

### N3. Stub overlay show/hide lifecycle — **MEDIUM**

**증상**: v3 §3.2 "stage scene unload와 함께 사라지지 않는다." 하지만 다음 상황의 동작 명시 안 됨:

- Stage01 clear → overlay 표시 → user가 Next 클릭 → `request_next` emit → SceneFlow가 Stage02 load
- 이 사이에 overlay는 언제 hide?
  - SceneFlow.load_next_stage() 시작 시?
  - Stage02 ready 후?
  - emit 직후?
- hide 안 하면 Stage02 시작 시점에도 Stage01 결과 화면이 보이는 race

**수정안**: Phase 6 plan에 다음을 명시:

```text
SceneFlow가 request_replay / request_next / request_menu 수신 시
1. overlay.hide() 호출
2. 현재 stage scene unload
3. 새 stage scene load (replay는 같은 stage)
```

추가로:
- StageRunner의 `stage_cleared` / `stage_failed` emit 시 SceneFlow가 overlay.show(result) 호출
- show/hide의 trigger는 *SceneFlow가 단독 소유* (StageRunner는 emit만, overlay는 buttons만)

이 lifecycle은 `request_*` signal 인터페이스 결정만큼 중요.

---

### N4. 결과 표시 중 stage process_mode / 입력 우선순위 — **MEDIUM**

**증상**: v3 §3.5 New Phase 8: "결과 overlay/dialog 표시 중에는 UI 입력이 stage 입력보다 우선." 그런데:
- Phase 6에서 stub overlay가 표시되는 동안 stage simulation이 계속 도는가?
- StageRunner가 `_completed = true`로 분기하지만 candy/ants/spawner는 그대로 process
- 결과 화면 떠 있는데 개미가 계속 움직이고 candy hp가 변하면 시각적 race

**현재 코드 상태** ([StageRunner.gd:67-82](../scripts/core/StageRunner.gd)): `_completed = true` 후 `_process` 첫 줄에서 early return. spawner와 ant 자체는 stop 안 함.

**수정안**: Phase 6에서 다음 중 하나를 결정:
- 옵션 A: `_completed = true` 시 SceneFlow가 CurrentStageRoot.process_mode = PROCESS_MODE_DISABLED 설정
- 옵션 B: StageRunner에 `_freeze_stage()` 메서드 추가, stage 안의 모든 자식을 disable
- 옵션 C: 그대로 둠 (시각적으로 ants가 계속 움직이지만 Phase 6 범위에서는 허용)

Phase 6의 비범위가 "stars / motion / 본격 dialog"이므로 옵션 C도 허용 가능. 단 plan에서 *명시적으로 허용*해야 self-review에서 "왜 안 멈추냐"로 흔들리지 않음.

권고: 옵션 A (process_mode 토글)가 가장 단순. Phase 8에서 pause/step과 통합.

---

### N5. `_make_result()` helper 시그니처 미정의 — **MEDIUM**

**증상**: v3 §2.4 의사코드가 `_make_result(true, "")` 호출하지만 함수 정의 없음.

**수정안**: Phase 6 plan에 helper 명시:

```gdscript
# StageRunner.gd
func _make_result(cleared: bool, reason: String) -> Dictionary:
    return {
        "stage_id": stage_data.id if stage_data != null else 0,
        "cleared": cleared,
        "saved": score_system.saved_pieces,
        "lost": score_system.lost_pieces,
        "original_hp": score_system.original_hp,
        "score": score_system.score(),
        "time_left": _time_left,
        "reason": reason,
    }
```

소유자: StageRunner (현재 score_system 변수가 여기 있으므로). ScoreSystem에 노출 메서드 추가하지 않고도 가능.

이 시그니처는 N1과 짝이 됨 — N1을 옵션 A로 결정하면 `EventBus.stage_cleared.emit(_make_result(true, ""))`가 자연스럽게 동작.

---

### N6. `start_game()` vs `load_stage(1)` 중복 — **LOW**

**증상**: v3 §3.2 SceneFlow API 5개 중 `start_game()`과 `load_stage(1)`이 Phase 6 시점에 동일 동작 (Title 없음).

**판정**: Phase 13 Title/Menu에서 `start_game()`이 "Title → Stage1"로 변하므로 결국 다른 의미가 됨. Phase 6에서는 둘 다 두되 `start_game()`이 내부적으로 `load_stage(1)` 호출하는 thin wrapper. 큰 문제 아님. plan에 한 줄 ("Phase 6에서 start_game() = load_stage(1) wrapper") 명시면 충분.

---

### N7. `tests/SceneFlowTest.gd 또는 GameFlowTest.gd` 양다리 — **LOW**

**증상**: v3 §3.2 변경 대상에 둘 중 하나로 표기.

**수정안**: `tests/GameFlowTest.gd`로 확정. 근거: SceneFlow는 단일 컴포넌트지만 Phase 6 검증 범위는 SceneFlow + StageRunner result + EventBus request signal + overlay까지. "GameFlow" 명칭이 검증 범위와 정합.

---

### N8. 결과 emit 후 AntSpawner stop 누락 가능성 — **LOW**

**증상**: v3 의사코드가 `_completed = true` 설정 후 spawner stop 호출 없음.

**문제**:
- stage_cleared 후에도 spawner timer가 계속 돌아 다음 ant spawn 가능
- N4 옵션 A (process_mode = DISABLED)를 채택하면 timer도 같이 멈추므로 자동 해결
- N4 옵션 C (그대로 둠)를 채택하면 spawner가 계속 도는 명시적 위험

**판정**: N4 결정에 종속. N4를 옵션 A로 결정하면 LOW 자동 해소. 옵션 C라면 plan에 "spawner는 spawn_finished까지 계속 돈다, 결과 표시와 무관" 명시.

---

## 3. v1 → v2 → v3 진화 요약

| 영역 | v1 | v2 | v3 | 본 리뷰 |
|---|---|---|---|---|
| ScoreSystem stop | game-flow Step 6 | 선행 hot-fix | Pre-Phase 6 hot-fix | 채택 |
| StageResult 타입 | 3안 양다리 | Dictionary | Dictionary 8 키 명시 | 채택 |
| StageDialog 위치 | optional | GlobalUI Stub | GlobalUI Stub + 3 버튼 | 채택 (N3 lifecycle 보강) |
| no_more_ants | Step 5 | game-flow 포함 | 코드 블록 + 우선순위 | 채택 (N5 helper 보강) |
| phase 번호 | 13개 +1 | 13개 +1 | 13개 +1 + high→low 순서 | 채택 |
| 빌드 게이트 | 없음 | phase 13 끝 | "기반 vs 통합" 분리 | 채택 |
| EventBus signal | 명시 안 함 | 명시 안 함 | request_* 3개 | **N1 시그니처 미해결** |
| Menu 버튼 동작 | — | — | "no-op or 로그" 양다리 | **N2 결정 필요** |
| Overlay lifecycle | — | — | "unload와 분리" | **N3 보강 필요** |

---

## 4. 권고

### 4.1 즉시 처리 (HIGH)

**N1 EventBus signal 시그니처**:
- 옵션 A 채택: `signal stage_cleared(result: Dictionary)` / `signal stage_failed(result: Dictionary)`
- v3 §3.2 EventBus 블록에 기존 signal 시그니처 변경 명시
- Phase 6 변경 대상에 StageRunner consumer 시그니처 변경 추가
- 헤드리스 테스트 callback 시그니처 영향 사전 확인

### 4.2 Phase 6 plan 작성 시 본문에 못박기 (MEDIUM)

- **N2**: Menu 버튼 = Stage01 reload (또는 disabled). 결정 후 plan 명시
- **N3**: SceneFlow가 overlay show/hide trigger 단독 소유, request_* 수신 시 hide → unload → load 순서
- **N4**: process_mode = DISABLED를 stub overlay 표시 기간에 적용 (옵션 A 권장)
- **N5**: `_make_result()` helper를 StageRunner에 정의, 시그니처 코드 블록으로 명시

### 4.3 Plan 문서 작업 중 흡수 (LOW)

- **N6**: `start_game()` = `load_stage(1)` thin wrapper 한 줄 명시
- **N7**: `tests/GameFlowTest.gd`로 확정
- **N8**: N4 결정에 따라 자동 해소 또는 명시적 허용

---

## 5. v3 그대로 진행 가능 여부

- v2 리뷰 finding 8개 모두 흡수 — v3는 v2의 자연스러운 종착점
- 단 v3가 의사코드로 한 단계 깊이 들어가면서 코드 수준 결정 5개(N1~N5)가 추가로 필요해짐
- N1만 처리하면 verdict clean. N2~N5는 phase 6 plan 작성 시 흡수 가능
- N1을 v3 본문에서 결정 못 박지 않으면 phase 6 self-review에서 거의 확실히 1라운드 추가됨

---

## 6. Verdict

- v1 → v2 → v3 사이클: **수렴 양호**. v3는 v2 리뷰를 빠짐없이 흡수
- v3 자체: **needs-attention** — N1 (HIGH) 처리 후 clean
- 다음 행동:
  1. v3 본문에 N1 옵션 A 결정 반영 (in-place 수정 또는 v4 발행)
  2. N2~N5는 phase 6 plan 작성 단계로 이월
  3. Pre-Phase 6 hot-fix는 v3 결정과 독립적으로 진행 가능

### 미해결 결정 사항 (사용자 입력 필요)

1. **N1 옵션**: A (signal 시그니처 변경) / B (새 signal 추가) / C (인자 2개) — A 권장
2. **N2 옵션**: Phase 6의 Menu 버튼 = Stage01 reload / disabled / no-op — Stage01 reload 또는 disabled 권장
3. **N4 옵션**: 결과 표시 중 stage process_mode = DISABLED / 그대로 둠 — DISABLED 권장
4. **본 리뷰 반영 방식**: v3 in-place 수정 / v4 발행 / phase 6 plan에 직접 반영
