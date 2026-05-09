# Game Flow Proposal v2 — Adversarial Review

작성일: 2026-05-09
리뷰 대상: `docs/GAME_FLOW_PROPOSAL_V2.md`
근거 문서:
- `docs/GAME_FLOW_PROPOSAL.md` (v1)
- `docs/GAME_FLOW_PROPOSAL_REVIEW.md` (v1 리뷰)
리뷰어: Claude (self-review, codex 라운드 전 단계)
범위: v2 자체의 일관성, v1 리뷰 반영의 정합성, phase plan 적용 시 self-review 회차에서 흔들릴 수 있는 위험 지점
Verdict: **clean** (HIGH 0건) — 본 추천안 그대로 진행 가능. MEDIUM 4건 / LOW 4건 보강 권고

---

## 1. 요약 판정

| 항목 | 판정 |
|---|---|
| §2.1 ScoreSystem leak 선행 hot-fix | ✅ 채택 |
| §2.2 Dictionary 확정 | ✅ 채택 |
| §2.3 StageResultOverlayStub 명명 분리 | ✅ 채택 — `Stub` 접미사로 phase 11과 혼동 차단 |
| §2.4 `no_more_ants` 포함 | ✅ 채택 |
| §2.5 slot swap 거부 근거 | ✅ **타당** — v1 리뷰의 옵션 A를 정확히 교정 |
| §3 Stage 0~7 흐름 | ✅ 큰 골격 채택 |
| §3 Stage 2 mass-rename 안전성 | ⚠️ MEDIUM (F1) |
| §3 Stage 1 SceneFlow API 일관성 | ⚠️ MEDIUM (F2) |
| §3 Stage 1 Stub overlay 버튼 명시 | ⚠️ MEDIUM (F3) |
| §3 Stage 1 `no_more_ants` 식 | ⚠️ MEDIUM (F4) |
| Phase 6 직후 미니 게이트 | LOW (F5) |
| Headless test 호환성 근거 | LOW (F6) |
| "Stage 0" 명명 | LOW (F7) |
| MEMORY.md 갱신 누락 | LOW (F8) |

---

## 2. v2가 v1 리뷰를 정확히 교정한 부분

v1 리뷰가 옵션 A에서 "phase 6↔7 swap"을 제안했지만, 실제로는 swap이 불가능하다.

- 신규 phase 6 = game-flow-foundation
- 기존 phase 6 (input-pad-cursor) → phase 7로 이동
- 기존 phase 7 (input-pause-step)이 *id 7 슬롯에 이미 존재*

v2 §2.5가 정확히 이 충돌을 짚었다. swap은 환상이고, 실제로는 13개 mass-rename과 동일한 비용이 된다. v1 리뷰의 "비용 1/13" 비교표는 **잘못된 비교**였음. v2의 "비용을 받아들이되 명시적으로 한다"가 옳은 판단이다.

이 지점은 v1 리뷰가 v2에 의해 **올바르게 교정된** 항목으로 기록한다.

---

## 3. 발견 사항

### F1. mass-rename sequential 순서 미명시 — **MEDIUM**

**증상**: §3 Stage 2 / §6 4번이 "한 칸씩 뒤로 이동"이라고만 함.

**문제**:
- 파일명에 phase 이름이 붙어 있어 file path 자체는 충돌하지 않지만 (`phase07-input-pad-cursor.md`와 `phase07-input-pause-step.md`는 동시 존재 가능)
- `status.json`의 id 7 슬롯은 단일이고 Notion phase 7 페이지도 단일이므로, **id 7의 *의미*가 한 시점에 중복**되는 중간 상태가 생긴다
- 이 중간 상태에서 다른 자동화(예: notion sync)가 끼어들면 매핑이 꼬일 수 있다

**수정안**:

```
1. 파일 rename은 high → low 순으로:
   phase19-stage10-bomber-polish.md → phase20-...
   phase18-stage9-floater.md         → phase19-...
   ...
   phase06-input-pad-cursor.md       → phase07-input-pad-cursor.md
2. status.json은 마지막에 한 번에 재정렬 (id 부분 갱신은 atomic).
3. notion-phase-ids.json도 high → low 순으로 매핑 갱신.
4. 작업 중에는 notion sync 자동화를 일시 비활성화하거나 수동 모드로 둔다.
```

이걸 v2 §6에 못박아야 self-review 회차에서 흔들리지 않는다.

---

### F2. SceneFlow API와 EventBus signal 비대칭 — **MEDIUM**

**증상**: §3 Stage 1 구현 범위에 `EventBus.request_stage_select` 추가가 있으나, SceneFlow API 5개에는 `go_to_stage_select()`가 없다.

**문제**:
- signal은 추가하지만 consumer가 없음 → dead signal
- phase 13 Title/Menu에서 추가한다면 phase 6에서 signal만 *예약*하는 셈
- 일관성 위해 다른 request 신호도 미리 예약하지 않은 이유가 약함

**수정안 A (권장)**: `request_stage_select`를 phase 13으로 미루고 phase 6에는 3개(replay/next/menu)로 축소.

**수정안 B**: SceneFlow API에 `go_to_stage_select()` no-op stub 추가, phase 13에서 본 구현.

A가 일관성 측면에서 더 깔끔하다. v2 본문에서 한 줄 결정 필요.

---

### F3. StageResultOverlayStub의 버튼 유무 미정의 — **MEDIUM**

**증상**: §3 Stage 1에서 "GlobalUI 산하에 임시 결과 overlay"라고만 하고 버튼 유무가 명시되지 않음.

**문제**:
- 완료 기준 "Stage01 clear 후 Next로 Stage02 이동 가능"을 어떻게 검증하는가?
- 키보드 입력만으로 검증한다면 phase 7 input-pad-cursor와 phase 8 input-pause-step의 `restart_stage` 액션은 아직 phase 6 시점에 미존재
- 헤드리스 테스트에서 `EventBus.request_next.emit()` 직접 호출만으로 검증한다면 stub에 버튼은 불필요

**수정안**: phase 6 완료 기준에 다음을 명시:
- Stub overlay는 Replay / Next / Menu 3 버튼을 가진다
- 버튼 클릭 시 해당 `EventBus.request_*` signal emit
- 헤드리스 테스트는 signal emit + 버튼 클릭 둘 다 검증

이 결정이 phase 6 완료 검증 가능성을 결정한다.

---

### F4. `no_more_ants` 판정 boolean 식 미명시 — **MEDIUM**

**증상**: §2.4가 조건 4개(`AntSpawner.spawn_finished`, living ants count, `in_transit_pieces`, `Candy.hp`)를 나열만 한다.

**수정안**: phase 6 plan에 식을 코드 블록으로 못박는다.

```gdscript
# StageRunner._process(delta) 매 tick:
# 1) clear 판정 우선
if score_system.is_cleared(_candy.hp if _candy != null else 0):
    _completed = true
    EventBus.stage_cleared.emit(score_system.score())
    return

# 2) no_more_ants 판정 (clear 이후에만 평가)
if (_spawner_finished
    and _living_ants == 0
    and score_system.in_transit_pieces == 0
    and _candy != null and _candy.hp > 0):
    _completed = true
    EventBus.stage_failed.emit("no_more_ants")
    return

# 3) time out
if _time_left <= 0.0:
    _completed = true
    EventBus.stage_failed.emit("time_out")
```

추가 명시 필요 사항:
- `_living_ants` 추적 방법 (spawner 카운터 vs group count)
- `_spawner_finished`는 `AntSpawner.spawn_finished` signal 구독 후 boolean으로 보존
- clear 우선 / fail 후순위: 식 순서로 race 차단

이걸 phase 6 본문에 박아야 self-review에서 한 번 덜 흔들린다.

---

### F5. Phase 6 직후 미니 게이트 부재 — **LOW**

**증상**: §3 Stage 7 게이트가 phase 13 끝에만 있다.

**판정**:
- phase 6 자체 완료 기준에 이미 검증 항목이 7개 들어가 있어 사실상 미니 게이트 역할 수행
- phase 7 input-pad-cursor의 cursor cache invalidation 검증도 부분 게이트 역할
- 별도 미니 게이트는 불필요

**보강 제안**: §3 Stage 7 게이트 항목에 "phase 6 완료 시점의 검증과 중복되는 항목은 *재실행*"이라고 명시. 누적된 코드 위에서 동일 항목이 여전히 통과하는지 확인하는 의미.

---

### F6. headless test 호환성 근거 부족 — **LOW**

**증상**: §3 Stage 1 완료 기준에 "기존 Stage02/Stage03 직접 실행 headless test는 계속 통과"가 있지만 *왜* 통과하는지 근거가 없다.

**근거 보강**: `scripts/run_test.py`는 scene path를 직접 인자로 받으므로 project.godot의 main scene 변경과 무관. 이 한 줄을 v2 §3 Stage 1 비고에 명시하면 self-review 회차에서 의심 한 번 덜 발생한다.

---

### F7. "Stage 0" 명명 모호성 — **LOW**

**증상**: §3 Stage 0이 sweep hot-fix인데 다른 Stage 1~7은 phase 단위.

**수정안**: `Stage 0` → `Pre-Phase 6 hot-fix` 또는 `Phase 5 sweep`로 명명 변경. 작은 문제.

---

### F8. MEMORY.md `candyants_phase_revision_2026-05-09` 갱신 누락 — **LOW**

**증상**: §3 Stage 2 수정 대상에 MEMORY 파일들이 없다.

**문제**:
- 현재 MEMORY 인덱스의 `candyants_phase_revision_2026-05-09.md`가 19 phase 구조 기준
- `candyants_phase5_lessons.md`도 "phase 6 첫 액션 가이드"를 포함
- mass-rename 후 두 파일 모두 갱신 필요

**수정안**: §3 Stage 2 수정 대상에 추가:

```
C:\Users\code1412\.claude\projects\D--claude-godot\memory\candyants_phase5_lessons.md
C:\Users\code1412\.claude\projects\D--claude-godot\memory\candyants_phase_revision_2026-05-09.md
C:\Users\code1412\.claude\projects\D--claude-godot\memory\MEMORY.md (인덱스 description 갱신)
```

---

## 4. 받아들일 수 있는 결정 (HIGH 0건)

v2의 다음 결정은 그대로 좋다. 추가 논의 없이 진행 가능하다.

- Phase 5 sweep hot-fix를 phase 6 진입 전에 분리
- Dictionary 확정, typed `StageResult` Resource는 post-MVP
- `StageResultOverlayStub` 명명 (`Stub` 접미사로 phase 11과 분리)
- `no_more_ants` 판정을 phase 6에 포함
- mass-rename 비용을 명시적으로 받아들임 (slot swap 환상보다 정직함)
- Stage4 진입 전 빌드 검증 게이트 (phase 13 끝)
- 대안 A/B 모두 비추천 결정
- v1은 보존, v2를 현재 결정안으로 사용

---

## 5. v1 리뷰 → v2 → 본 리뷰 변화 요약

| 영역 | v1 | v1 리뷰 | v2 | 본 리뷰 |
|---|---|---|---|---|
| ScoreSystem stop 위치 | game-flow Step 6 | 선행 hot-fix | 선행 hot-fix | 채택 |
| StageResult 타입 | 3안 양다리 | Dictionary 확정 | Dictionary 확정 | 채택 |
| StageDialog 위치 | optional GlobalUI | GlobalUI 산하 + lifecycle 명시 | GlobalUI Stub | 채택 (F3로 버튼 보강) |
| no_more_ants | Step 5 | game-flow에 포함 | game-flow 포함 | 채택 (F4로 식 보강) |
| phase 번호 변경 | 13개 +1 | swap 1개 (오류) | 13개 +1 (mass-rename) | 채택 (F1로 순서 보강) |
| 빌드 검증 게이트 | 없음 | phase 12 끝 (잘못된 번호) | phase 13 끝 | 채택 (F5로 보강) |

---

## 6. 최종 권고

**v2 그대로 진행 가능.** 단 phase 6 plan을 작성할 시점에 다음 MEDIUM 4건을 본문에 못박을 것:

1. **F1**: mass-rename은 high → low 순, status.json은 마지막에 atomic 재정렬, notion sync 일시 비활성화 — §6에 명시
2. **F2**: `request_stage_select` 한 줄을 phase 13으로 명시 이동 (수정안 A 권장)
3. **F3**: Stub overlay에 Replay / Next / Menu 3 버튼 포함, 클릭 시 `EventBus.request_*` emit — 완료 기준에 명시
4. **F4**: `no_more_ants` boolean 식을 코드 블록으로 못박기 + clear/fail 평가 순서 명시

LOW 4건(F5~F8)은 plan 문서 작업 중 자연스럽게 흡수 가능.

---

## 7. 미해결 결정 사항 (사용자 입력 필요)

1. **F2 처리 방식**:
   - A: `request_stage_select`를 phase 13으로 완전히 미루기 (권장)
   - B: SceneFlow에 `go_to_stage_select()` no-op stub 추가
2. **본 리뷰 반영 방식**:
   - A: v2 본문을 in-place 수정 (v2 단일 결정안 유지)
   - B: v2는 보존, 본 리뷰 + v2를 합쳐 `phase06-game-flow-foundation.md` plan을 바로 작성
3. **선행 작업 순서**:
   - A: Phase 5 sweep hot-fix 먼저 → 이후 phase 6 plan 작성
   - B: phase 6 plan 작성 먼저 → sweep는 phase 6 진입 직전
   - 둘 다 가능하지만 A가 baseline을 깨끗하게 함

---

## 8. Verdict

- v2 자체: **clean** (HIGH 0건, MEDIUM 4건은 phase 6 plan 작성 시 흡수)
- v1 → v2 진화: 적절한 방향, v1 리뷰의 옵션 A 결함을 정확히 교정
- 다음 행동: §7의 결정 후 phase 6 plan 작성 또는 v2 in-place 보강
