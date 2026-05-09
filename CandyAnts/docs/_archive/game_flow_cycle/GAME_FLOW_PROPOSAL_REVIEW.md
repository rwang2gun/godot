# Game Flow Proposal — Adversarial Review

작성일: 2026-05-09
리뷰 대상: `docs/GAME_FLOW_PROPOSAL.md`
리뷰어: Claude (self-review, codex 라운드 전 단계)
범위: 진단 부분의 사실관계, 제안 부분의 일관성·비용·우선순위, 그리고 사용자 의도(“스테이지 무분별 확장보다 제대로 돌아가는 빌드 우선”)와의 정합성
Verdict: **needs-attention** — 진단은 채택, 제안 구조는 1개 HIGH·2개 MEDIUM 수정 후 옵션 B로 변경 채택

---

## 1. 요약 판정

| 영역 | 판정 |
|---|---|
| 진단 (현재 구조 4가지 결함) | ✅ 채택 — 코드와 일치 |
| 권장 구현 순서 (Step 1~6) | ✅ 큰 흐름 채택, Step 5/6은 분리 |
| 추천안 (phase 6 앞 신규 삽입 + 13개 phase 일괄 +1) | ❌ 비용 과다, 비추천 |
| 대안 A (phase 6 슬롯 교체) | ✅ 변형 채택 — phase 6↔7 swap 형태 |
| 대안 B (phase 11 확장) | ⚠️ 사용자 의도와 어긋남 — 빌드 검증을 늦춤 |
| `StageResult` 타입 결정 보류 | ❌ MVP 동안 Dictionary 확정 필요 |
| 실패 판정 보강을 game-flow에 묶음 | ✅ 사용자 의도와 일치, 묶어서 처리 |
| ScoreSystem.stop() 도입 시점 | ❌ phase 6 대기 금지 — 즉시 sweep |

---

## 2. 진단 부분 — 코드 대조

문서가 짚은 4가지는 모두 현재 코드에서 그대로 확인됨. 진단은 그대로 채택한다.

| 진단 | 근거 코드 | 상태 |
|---|---|---|
| 게임 흐름 소유자 부재 | [GameManager.gd:1-9](../scripts/core/GameManager.gd) — boot 검증 9줄, 흐름 책임 없음 | 일치 |
| 결과 화면이 진행 요청 못 만듦 | [StageRunner.gd:84-94](../scripts/core/StageRunner.gd) — `_hud.show_dialog()` 직접 호출, 일방향 | 일치 |
| 실패 판정 부족 | [StageRunner.gd:80-82](../scripts/core/StageRunner.gd) — `_time_left <= 0.0` 분기 1개 | 일치 |
| 전역 신호 수명 관리 약함 | [ScoreSystem.gd:15-17](../scripts/core/ScoreSystem.gd) — `EventBus` 3 signal connect만, disconnect 없음 | 일치, **즉시 위험** |
| Main.tscn 진입점 미사용 | `scenes/Main.tscn` 빈 Node 1개, project.godot main scene = Stage01.tscn | 일치 |

**진단 부분 verdict: clean.** 추가 발견 없음.

---

## 3. 제안 부분 — 발견 사항

### F1. 추천안의 phase 번호 일괄 +1 비용 과다 — **HIGH**

**증상**: 제안서 §최종 추천이 phase 6~19 13개를 모두 +1시킴.

**문제**:
- `phases/mvp/notion-phase-ids.json`에 22개 page_id가 phase 번호로 매핑됨. page_id를 보존하더라도 phase 번호와 페이지 슬러그가 어긋남
- `status.json` 13개 항목 재정렬, phase md 파일 13개 rename, 본문 내 cross-reference, README, MEMORY.md `candyants_phase_revision_2026-05-09` 갱신
- 이미 sync 정책이 `phase 진입 = 진행 중` / `verdict clean = 완료`로 *번호 기준* 운영 중 ([CLAUDE.md Notion 섹션](../CLAUDE.md))

**비교**: 제안서가 "대안 A는 번호 꼬임" 우려로 기각하지만, 추천안이 13개를 흔드는 비용 vs 대안 A가 1개 슬롯을 swap하는 비용의 비대칭이 평가에 반영되지 않음. 평가 일관성 결함.

**수정안**: phase 6↔7 한 쌍만 swap하는 변형으로 대체. (§4.2)

---

### F2. `input-pad-cursor`를 game-flow 뒤로 미루는 근거 부재 — **MEDIUM**

**증상**: 제안서 §개발 계획 §Phase 7 input-pad-cursor 수정 제안이 "SceneFlow 위에서 진행"을 전제로 cursor cache invalidation 검증을 추가.

**문제**:
- phase 5 InputRouter는 stage scene scope에서 정상 동작 중. 패드 가상 커서도 단일 stage로 완결되는 작업
- 실제로 SceneFlow가 *선행*해야 할 의존은 "stage 전환 시 cursor cache 무효화 검증"뿐인데, 이건 phase 6 결과물에 *후속 검증*으로 추가하면 되는 것이지 phase 6의 *전제*가 아님
- "입력 확장 전에 입력이 소비될 게임 상태"라는 표현이 phase 5 결과물(InputRouter + EventBus.action_triggered)이 이미 stage 안에서 소비되고 있다는 사실과 충돌

**영향**: F1과 결합되면 13개 phase 밀기를 정당화하는 핵심 근거가 흔들림.

**수정안**: input-pad-cursor와 game-flow는 의존 방향이 약하므로 둘 중 어느 쪽이 phase 6에 와도 무방. 사용자 의도(빌드 우선)를 따라 **game-flow가 phase 6**, **input-pad-cursor가 phase 7**로 swap.

---

### F3. `StageResult` 타입 결정 양다리 — **MEDIUM**

**증상**: 제안서 §6 ScoreSystem 결과 payload가 Dictionary / typed Resource / `get_result()` 3안을 나열만 하고 결정 안 함.

**문제**: phase 6에서 결정 안 하면 phase 11 ui-stage-dialog와 phase 12 ui-title-menu(SaveData 연결)가 다시 흔들림. 두 phase 모두 "이 페이로드 모양을 받는다"가 입력 조건임.

**수정안**: MVP 범위(stage 1~10) **Dictionary 확정**. typed `StageResult` Resource는 post-MVP-3 (SaveData/통계) 시점에 도입. 근거:
- MVP에서 결과 payload 소비자가 StageDialog와 (선택적으로) SaveData 2곳뿐
- field 수가 8개 이하로 작아 Dictionary 키 오타 위험 낮음
- post-MVP에서 typed로 옮길 때 호출부가 한정적

---

### F4. StageDialog lifecycle 미정의 — **MEDIUM**

**증상**: 제안서 §1 Main 트리에서 `Main → SceneFlow + CurrentStageRoot + GlobalUI(optional)`로 두면서 StageDialog가 어디 사는지 명시 안 함.

**문제**:
- StageDialog가 stage scene 산하면 `request_next` 클릭 → SceneFlow가 stage unload → dialog까지 같이 사라짐 → 클릭 직후 race
- GlobalUI 산하면 dialog가 살아남지만, 어떤 stage의 결과인지 식별이 payload에만 의존
- phase 11에서 다시 결정해야 한다면 phase 6의 `request_*` signal 인터페이스가 한 번 더 흔들릴 수 있음

**수정안**: phase 6에서 다음을 *못박는다*:
- StageDialog는 **GlobalUI(=Main의 자식)** 산하
- `request_*` signal은 인자 없음 (현재 stage는 SceneFlow 내부 상태에서 조회)
- StageDialog 표시 중에는 SceneFlow가 stage unload 보류, dialog의 버튼 응답 후 unload→load

---

### F5. 실패 판정 보강이 별도 phase 후보로도 등장 — **LOW**

**증상**: 제안서 Step 5가 `spawn_finished` + living ants 0 → 조기 실패. 이걸 phase 6에 묶을지 별도 sweep로 뺄지 모호.

**판정**: 사용자가 "제대로 돌아가는 빌드" 우선이라고 명시했으므로, **game-flow phase에 묶음**. 게임이 시간 초과까지 기다려야 fail하는 건 "제대로 돌아가지 않는" 상태의 일부이기 때문. 이 항목은 사용자 의도와 정합.

---

### F6. ScoreSystem leak — phase 6 대기는 부적절 — **HIGH**

**증상**: 제안서 Step 6이 `ScoreSystem.stop()`을 phase 6의 마지막 단계로 둠.

**문제**:
- 현재 [ScoreSystem.gd:15-17](../scripts/core/ScoreSystem.gd)이 `EventBus.candy_piece_picked / ant_saved / candy_piece_lost` 3 signal을 connect만 하고 disconnect 없음
- 단일 stage 직접 실행에서는 노출되지 않지만, *phase 6 작업 중* SceneFlow가 reload하는 즉시 이중 카운트 발생
- CLAUDE.md sweep 정책상 "사후 리뷰 HIGH는 즉시 hot-fix"가 원칙. 이건 *사후*가 아니라 *현재 알려진* HIGH

**수정안**: phase 6 진입 *전에* phase 5 sweep hot-fix로 분리:
```
fix: ScoreSystem disconnect on stop (phase 5 sweep)
```
- `ScoreSystem.stop()` 추가
- `StageRunner._exit_tree()`에서 호출
- 헤드리스 검증: 같은 stage 2회 reload 후 saved/lost 카운트가 1회분만 누적되는지

---

### F7. `pause_toggle`을 SceneFlow에 결합하는 제안 과도 — **LOW**

**증상**: 제안서 §Phase 8 input-pause-step 수정 제안이 SceneFlow와의 입력 충돌까지 phase 8 범위에 포함.

**판정**: pause/step/speed는 stage simulation 내부 상태. SceneFlow의 dialog 표시 여부에 따른 입력 우선순위는 phase 8 자체 범위에서 자연스럽게 풀림 (dialog open 시 stage process_mode = DISABLED). 별도 결합 설계 불필요. 단순화.

---

## 4. 최선의 제안

### 4.1 핵심 원칙

사용자 의도("스테이지 확장보다 제대로 돌아가는 빌드 먼저") = stage 1~3로 첫화면→플레이→clear/fail→replay/next→마지막 stage 처리 루프가 **닫혀야** stage 4~10 컨텐츠 추가의 의미가 생김. 따라서:

1. 게임 플로우 기반은 **phase 6에 즉시 진입**
2. phase 13~19 (stage 4~10)는 **빌드 검증 게이트 이후**로 보류, 단 일정·번호는 손대지 않음
3. 알려진 HIGH 결함(ScoreSystem leak)은 phase plan 결정과 독립적으로 **선행 hot-fix**

### 4.2 단계별 작업

#### Stage 0 — phase 5 sweep hot-fix (즉시, 별도 커밋)

근거: F6.

작업:
- `ScoreSystem.stop()` 추가, `EventBus` 3 signal disconnect
- `StageRunner._exit_tree()` 호출
- 헤드리스 회귀: stage reload 2회 후 카운트 누수 없음
- `phases/mvp/reviews/phase05-impl-review.md`에 sweep round 누적 (CLAUDE.md sweep 정책)
- 커밋: `fix: ScoreSystem disconnect on stop (phase 5 sweep)`

#### Stage 1 — Phase 6 슬롯 swap (notion-phase-ids 보존)

근거: F1, F2.

작업:
- `phase06-input-pad-cursor.md` → `phase07-input-pad-cursor.md` rename
- `phase07-input-pause-step.md` → 그대로 유지 (이름 충돌 방지 위해 rename은 sequential하게)
- 새 `phase06-game-flow-foundation.md` 작성
- `status.json`에서 6↔7 swap (id 6 = game-flow-foundation, id 7 = input-pad-cursor)
- `notion-phase-ids.json`은 page_id **보존**, phase 번호 ↔ page_id 매핑만 swap
- Notion 페이지 2개는 `notion-update-page`로 타이틀·요약 갱신
- phase 8~19는 *손대지 않음*

#### Stage 2 — Phase 6 game-flow-foundation 본 작업

근거: F3, F4, F5.

범위 (확정):
- `Main.tscn`을 진입점화 (project.godot main scene 변경)
- `scripts/core/SceneFlow.gd` 신규 — `start_game / load_stage / replay_stage / load_next_stage / go_to_menu` (5 API)
- Stage01/02/03 경로 매핑은 코드 상수
- `EventBus.request_replay / request_next / request_menu / request_stage_select` (4 signal, 인자 없음 — F4)
- StageDialog는 **Main.GlobalUI 산하**로 배치, stage unload는 dialog 응답 후 (F4)
- 임시 결과 UI는 기존 `HUD.show_dialog` 위에 Replay/Next 버튼만 부착 (본격 StageDialog는 phase 11)
- StageRunner 결과 payload = **Dictionary** 확정 (F3), 키: `stage_id, cleared, saved, lost, original_hp, score, time_left, reason`
- ScoreSystem `saved_pieces / lost_pieces / in_transit_pieces / original_hp` 4 카운터 노출 (CLAUDE.md 4-카운터 필수 규칙 유지)
- 실패 판정 보강 (F5): `AntSpawner.spawn_finished` 구독, `living_ants == 0 and in_transit == 0 and candy_hp > 0` → `stage_failed("no_more_ants")`
- StageRunner는 **씬 직접 로드 안 함**, signal만 emit
- 마지막 stage `request_next` → `request_menu` fallback

비범위 (phase 6에서 *명시적으로* 빠지는 항목):
- 타이틀 화면 (phase 12)
- StageSelect (phase 12)
- SaveData (phase 12)
- 본격 StageDialog UI (phase 11)
- 패드 가상 커서 (phase 7)
- typed `StageResult` Resource (post-MVP-3)

#### Stage 3 — phase 7~10 입력/UI 진행 (변경 없음)

근거: F2. SceneFlow 위에서 자연스럽게 동작. 다만 phase 7 input-pad-cursor의 검증 항목에 다음만 추가:
- stage 전환 후 cursor cache가 stale 상태로 skill assign에 사용되지 않음
- `InputRouter.clear_cursor_cache()` 또는 동등한 자동 무효화

#### Stage 4 — phase 11 ui-stage-dialog 본 작업

근거: phase 6에서 `request_*` signal과 Dictionary payload가 확정되어 있으므로, phase 11은 *UI만* 다룸.

범위: 결과 모달 UI / saved·lost·score·time 표시 / stars 계산 / 버튼 / 중복 클릭 방지.

#### Stage 5 — phase 12 ui-title-menu 본 작업

범위: TitleScene / MainMenu / StageSelect / SaveData. SceneFlow는 *확장*만, 신규 생성 없음.

#### **빌드 검증 게이트 (phase 12 종료 시점)**

stage 1~3만으로 다음을 수동 + 헤드리스 검증한다. 통과 못 하면 **phase 13 진입 금지**.

- 첫 실행 시 Title 진입
- Title → Stage01 자동 로드
- Stage01 clear → Next → Stage02 reload (수동 재시작 없이)
- Stage02 fail → Replay → 같은 stage 재시작, ScoreSystem 카운트 누수 0
- Stage03 clear → 마지막 stage fallback (Menu 복귀 또는 종료)
- 시간 초과 외 실패(`no_more_ants`) 경로도 dialog 호출
- pause/restart 입력이 dialog 표시 중 충돌 없음

#### Stage 6 — phase 13~19 stage 확장 (게이트 통과 후)

빌드 검증 게이트 통과 시점의 코드 상태 보고 phase 13~19 범위·난이도 재평가. 지금 시점에 일정 조정 안 함.

---

## 5. 근거 정리

### 5.1 왜 옵션 B (slot swap) 인가

| 비교 항목 | 추천안 (13개 +1) | 옵션 A 변형 (6↔7 swap) | 대안 B (phase 11 확장) |
|---|---|---|---|
| status.json 변경 | 13 항목 재정렬 | 2 항목 swap | 1 항목 범위 확장 |
| 파일 rename | 13개 | 1개 | 0개 |
| Notion page 갱신 | 13개 (내용+슬러그) | 2개 (내용만) | 1개 |
| 빌드 검증 게이트 도달까지 phase 수 | 7 (6→12) | 7 (6→12) | 6 (6→11) |
| 사용자 의도 정합 | 보통 | **높음** | 낮음 (입력/UI phase가 game-flow 없이 진행됨) |
| MEMORY.md 갱신 | 큼 | 작음 | 거의 없음 |
| 실수 위험 | 높음 | 낮음 | 낮음 |

대안 B가 변경 비용은 가장 적지만, phase 7~10 (입력/UI plumbing)이 game-flow 없이 먼저 진행되어 "빌드 우선"과 어긋남. 옵션 A 변형이 비용·정합성 균형점.

### 5.2 왜 ScoreSystem hot-fix가 phase 6 대기가 아닌 선행인가

- phase 6 첫 작업 = SceneFlow가 stage reload를 *발생시키는* 코드. leak이 발현되는 순간 = phase 6 진행 중
- CLAUDE.md sweep 정책상 알려진 HIGH는 다음 phase 진입 차단
- 분리하면 phase 6 self-review에서 "leak이 노출됐다 / 안 됐다"의 잡음 없이 깨끗한 베이스라인에서 시작 가능

### 5.3 왜 Dictionary 확정인가

- MVP 소비자 2곳 (StageDialog, 선택적 SaveData)
- field 수 8개 이하, 키 오타 위험 낮음
- post-MVP-3 SaveData phase에서 typed Resource로 옮길 때 호출부가 한정적
- 지금 typed 도입 시 phase 6 범위가 비대해지고 phase 11 UI 작업이 schema 변경에 묶임

### 5.4 왜 stage 4~10 일정을 지금 손대지 않는가

- 게이트 통과 시점의 빌드 상태가 stage 디자인에 영향 (예: 결과 dialog의 stars 기준이 stage data에 들어감)
- 지금 일정 조정 = 게이트 통과 *전* 의사결정 = 정보 부족
- status.json 항목 보존 = "stage 4~10이 plan에 있다"는 사실을 잃지 않으면서, 진입은 게이트 의존

---

## 6. 적용 시 작업 체크리스트

```text
[즉시] phase 5 sweep hot-fix
  - ScoreSystem.stop() + disconnect
  - StageRunner._exit_tree() hook
  - 헤드리스 reload 회귀 테스트
  - phases/mvp/reviews/phase05-impl-review.md sweep round 누적
  - 커밋: fix: ScoreSystem disconnect on stop (phase 5 sweep)

[Stage 1] phase 6 슬롯 swap
  - phase06-input-pad-cursor.md → phase07-input-pad-cursor.md
  - phase06-game-flow-foundation.md 신규
  - status.json 6↔7 swap
  - notion-phase-ids.json 매핑 swap (page_id 보존)
  - Notion 페이지 2개 update_page

[Stage 2] phase 6 본 작업 (game-flow-foundation)
  - Main.tscn 진입점화
  - SceneFlow.gd 5 API
  - EventBus.request_* 4 signal (인자 없음)
  - StageDialog Main.GlobalUI 산하 결정
  - StageRunner 결과 Dictionary 확정
  - 실패 판정 보강 (no_more_ants)
  - 헤드리스 회귀: Stage02HeadlessTest / Stage03HeadlessTest 통과
  - 자체 적대적 리뷰 → codex 적대적 리뷰

[Stage 3~5] phase 7→11→12 순차 진행 (변경 없음)

[Gate] 빌드 검증 게이트 — 통과 못 하면 phase 13 진입 금지

[Stage 6] phase 13~19 (게이트 후 재평가)
```

---

## 7. 비범위 / 연기 항목

- 타이틀/메뉴 디자인 — phase 12
- SaveData persistence — phase 12
- typed `StageResult` Resource — post-MVP-3
- pause/dialog 입력 우선순위 정교화 — phase 8 자체 범위
- 패드 가상 커서 — phase 7
- 본격 StageDialog UI/stars — phase 11
- 솔버빌리티 분석 (회수 불가능 사탕 감지) — post-MVP

---

## 8. 검증 기준 (phase 6 완료 시)

- [ ] `Main.tscn`이 main scene이고 실행 시 Stage01 로드
- [ ] `EventBus.request_next.emit()` → Stage02 로드
- [ ] `EventBus.request_replay.emit()` → 현재 stage 재시작
- [ ] 마지막 stage `request_next` → `request_menu` fallback
- [ ] stage reload 2회 후 ScoreSystem 카운트 누수 0
- [ ] `AntSpawner.spawn_finished` 후 living ants 0이면 시간 초과 전 fail
- [ ] StageRunner가 Dictionary payload emit, 키 8개 모두 채워짐
- [ ] `Stage02HeadlessTest`, `Stage03HeadlessTest` 직접 실행 경로 회귀 없음
- [ ] StageDialog Main.GlobalUI 산하 + dialog 응답 후에만 stage unload
- [ ] Notion phase 6/7 페이지 상태 = `진행 중` / `완료` 동기화

---

## 9. Verdict

- 제안서 진단: **clean**
- 제안서 구현 순서: **needs-attention** — F1/F6 HIGH, F2/F3/F4 MEDIUM 수정 후 채택
- 위 §4 “최선의 제안”으로 대체하여 진행 권고
- 사용자 의도("스테이지 확장보다 빌드 먼저") 정합성: **높음** — 옵션 A 변형 + 빌드 검증 게이트가 의도를 직접 반영
