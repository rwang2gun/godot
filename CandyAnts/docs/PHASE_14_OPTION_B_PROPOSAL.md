---
title: Phase 14~20 옵션 B 제안서
version: 0.2
date: 2026-05-18
status: 1차 persist 본 — codex adversarial-review (plan stage) 진입 직전
---

# Phase 14~20 옵션 B 제안서

> 본 문서는 phase 14~20을 **메카닉 기반**으로 재구성하는 "옵션 B"의 결정 사항과 신규 시스템 명세를 모은 1차 SoT다.
> migration plan `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md`이 본 문서를 인용한다.
>
> **버전 이력**
> - **0.2** (2026-05-18): 첫 persist 본. Bomber·Miner 삭제, Cutter·민들레씨 분배자·식물 지형 신규, §5.2 17 분할 결정 포함.
> - 0.1: 선행 채팅 세션의 비공식 원안 (파일 미보존).
>
> **TBD 정책**: 본 문서는 옵션 B의 **결정·매핑·정책**을 우선 확정한다. 신규 시스템의 상세 명세(§3) 중 일부는 각 phase 진입 시점의 `plans/phaseNN-plan.md`에서 구체화될 수 있도록 명시적 TBD 마커로 둔다. TBD 잔존이 migration plan 진행을 막지 않는다.

---

## 0. 컨텍스트 + 톤 폴리시

### 0.1 개발 모델
- 1인 + AI 페어(Claude Code + Codex) 협업.
- 본인 역할: 결정·검수·통합. AI 역할: 명세·코드·리뷰.

### 0.2 톤 폴리시 — 어휘 통일
대상 플레이어가 어린 플레이어이므로 사망 연출·폭력 묘사를 전면 배제한다.

- **페일 어휘**: "사탕 손실"로 통일.
- **금지 어휘** (코드·문서·UI 전부): `die()`, `DeadState`, "사망", "죽".
- **허용 어휘**: "정착", "임무 완수", "사탕 손실", "탈락".
- 새로 작성하는 phase 명세·코드는 §0.2 어휘만 사용. 기존 phase14 본문(`phase14-stage4-hazard-water.md`)에 남아 있는 §0.2 금지 어휘는 새 phase17 본문 작성 시 §0.2 정책 어휘로 일괄 치환 (단순 복붙 금지).

### 0.7 무게(잠정치) 처리

#### 0.7.0 wall-clock 환산 금지
- `duration_estimate` 필드의 수치는 **phase 간 상대 비교용 잠정치**다.
- 시간 단위로 환산하지 않는다. 여가 시간 개발이라 wall-clock 추정 자체가 무의미.
- 각 phase plan 단계에서 재조정 가능. 본 문서 §2.4 수치는 옵션 B v0.2 시점의 잠정치.

#### 0.7.5 100% 정착 → 회수 동선 설계 (§5.3 A안 부속 정책)
- 민들레씨 분배자가 100% 정착에 도달하면 능력 전이 자체는 완료이나, 사탕 회수 동선이 끊겨 puzzle이 막힌 상태가 될 수 있다.
- 이를 **회수 동선 재설계 요구**로 본다. puzzle 본질이 "분배자 정착 비율을 조절해 회수 동선을 살리는 것"이라는 신호.
- **제한 시간 도달까지 자연 종료 정책 (phase 15 plan review Round 1·2 대응, 2026-05-22 갱신)**:
  - 100% 정착 상태에서 즉시 트리거되는 별도 탈락 경로는 없다. SettledState 개미도 코드 식별자 `_living_ant_count`에 포함되어 코드 식별자 `stage_failed("no_more_ants")` 경로는 자연 차단된다.
  - 그러나 `StageRunner._time_left = 0` 도달 시 기존 `stage_failed("time_out")` 발화는 그대로 진행된다 — 즉 제한 시간 도달까지 진행한 뒤 사탕 손실로 자연 종료된다.
  - 플레이어가 보는 결과 메시지는 **§0.2 어휘 정책상 "사탕 손실"**로 표기되며 일반 제한 시간 도달과 동일 어휘를 사용한다. 100% 정착으로 인한 별도 "탈락" 어휘 분기는 두지 않는다.
- 별도 정착 전용 시그널/UI 분기는 phase 15 범위 외. phase 20 polish 시점의 정산 UI에서 코드 식별자 `stage_failed("time_out")`의 표현 variant를 추가할지는 polish phase plan 자율로 둔다.
- 4-카운터(ADR-002)도 무변화. 정착 개미는 코드 식별자 `in_transit_pieces`에서 제거되어 코드 식별자 `saved_pieces`/`lost_pieces` 어디에도 누적되지 않는다.

---

## 1. 핵심 변경 요약 (v0.1 → v0.2)

| 종류 | 항목 | 비고 |
|---|---|---|
| 삭제 | Bomber | phase20 polish에서 빠짐 |
| 삭제 | Miner | phase17 (구 stage7-miner) 자체 삭제 |
| 신규 | Cutter | 식물 지형 절단. Bomber 자리 대체 |
| 신규 | 민들레씨 분배자 | 정착 시 후속 개미에 능력 전이 |
| 신규 | 식물 지형 클래스 | TileMap 신규 cell type |
| 신규 | 끈끈이 hazard | Water와 함께 phase17 mechanic-hazard에 포함 |
| 신규 | 별 시스템 / 정산 UI | phase20 polish |
| 분할 | Phase 14 → 14a/14b | 정수 id 14, 15 / 라벨로만 a/b 표기 |
| 분할 | Phase 17 → 17a/17b | 정수 id 18, 19 / 라벨로만 a/b 표기 |
| 유지 | ADR-002 4-카운터 | 변경 없음 (§3.5) |
| 유지 | PRD / ARCHITECTURE / ADR 큰 틀 | 페일 어휘 정책(§0.2) PRD 반영은 별도 작업 (§7.5) |

전체 phase 14~20 = **7 phase 구성**.

---

## 2. Phase 매핑

### 2.1 묶음 한 줄 요약

| id | 라벨 | 슬러그 | 한 줄 요약 |
|---|---|---|---|
| 14 | 14a | `mechanic-adaptation-traits` | Climber + Floater 트레잇 도입 (수직 적응 + 민들레씨 보유 트레잇) |
| 15 | 14b | `mechanic-adaptation-settlement` | Blocker + 민들레씨 분배자 + 정착 + 능력 전이 시스템 |
| 16 | 15  | `mechanic-creation` | Sand-mound(수직) + Bridge(수평) 생성 메카닉 |
| 17 | 16  | `mechanic-hazard` | Water + 끈끈이 + 사탕 손실 페일 룰 |
| 18 | 17a | `mechanic-destruction-earth` | Basher + Digger (흙 지형 동적 파괴) |
| 19 | 17b | `mechanic-destruction-plant` | Cutter + 식물 지형 신규 클래스 |
| 20 | 18  | `polish` | Release Rate + 별 시스템 + 정산 UI + 사운드 hook + 피날레 |

### 2.4 무게(잠정치) 합계

| phase | 무게 |
|---|---|
| 14 | 5400 |
| 15 | 7200 |
| 16 | 7200 |
| 17 | 7200 |
| 18 | 5400 |
| 19 | 5400 |
| 20 | 9000 |
| **합계** | **46800** |

- v0.1 합계(가상 원안)와 동일하게 유지. 17 분할(§5.2)로 분배만 재구성.
- 본 잠정치는 §0.7.0에 따라 wall-clock으로 환산하지 않는다.

---

## 3. 신규 시스템 명세

> 본 절은 옵션 B v0.2에서 새로 도입되는 시스템의 **개념·결정** 위주로 정리한다. 코드 수준 상세(스크립트 위치·노드 트리·시그널 contract 등)는 각 phase 진입 시점의 `plans/phaseNN-plan.md`에서 채운다. 본 문서의 TBD 마커가 그 시점까지 잔존해도 무방하다.

### 3.1 정착 + 능력 전이 시스템 (phase 15 = 14b)

#### 3.1.1 정착 개념
- 분배자(민들레씨 보유 개미)가 특정 조건에서 더 이상 움직이지 않는 상태.
- **TBD**: 정착 트리거 조건(타이머·위치·플레이어 입력 중 무엇), 정착 후 상태 머신(StateMachine 노드 추가? Behavior tree?), 정착 해제 가능 여부.

#### 3.1.2 능력 전이
- 분배자 정착 시 보유한 트레잇(Floater 등)이 후속 개미에 자동 부여.
- **TBD**: 전이 범위(반경/시간/직접 접촉), 시각화(파티클·아이콘 표시), 이미 트레잇을 가진 개미에 중복 부여 처리, 전이 가능 트레잇 화이트리스트(Floater만 vs 전체).

#### 3.1.3 분배자 사탕 UX (§5.3 A안)
- **A안 채택**: 분배자 정착에 경고 UI 없음. 플레이어는 100% 도달까지 자유롭게 정착 허용.
- 결과: 100% 정착 시 회수 동선 끊김 → §0.7.5 정책에 따라 puzzle 본질을 드러내는 신호로 처리.

#### 3.1.4 엣지 케이스
- **TBD**: 분배자 정착 중 사탕과 충돌, 능력 전이를 받는 개미가 이미 다른 트레잇 보유, 정착 직후 hazard 진입으로 사탕 손실 처리.

### 3.2 생성 메카닉 (phase 16 = 15)

#### 3.2.1 Sand-mound (수직)
- 개미가 모래를 쌓아 위로 올라갈 수 있는 발판 생성.
- **TBD**: 쌓는 속도(tick 기반/거리 기반), 최대 높이, 다른 개미와의 충돌, 자연 무너짐 여부.

#### 3.2.2 Bridge (수평)
- 갭을 가로지르는 수평 발판 생성.
- **TBD**: 수평 거리 한계, 갭 자동 감지 vs 수동 시작/끝, 미완성 다리(개미가 사탕 손실 처리될 때) 잔재 처리.

#### 3.2.3 엣지 케이스
- **TBD**: Sand-mound와 Bridge가 겹치는 좌표, hazard(Water·끈끈이) 위 생성 시도, 식물 지형 위 생성 가능 여부.

### 3.3 Hazard (phase 17 = 16)

#### 3.3.1 Water
- 페일 처리: 사탕 손실. 개미 본체는 fade-out + 카운터 `lost++` 갱신. (§0.2 어휘 정책 준수 — 금지된 직접 API 호출·상태 정의는 사용하지 않는다.)
- **TBD**: Water 깊이·전파 속도, 다른 hazard와의 상호작용(끈끈이 위 Water).

#### 3.3.2 끈끈이
- 개미 진입 시 이동 속도 감소 또는 일시 정지.
- **TBD**: 해방 메커니즘(시간 경과 자동 vs Cutter 등 외부 개입), 정착·능력 전이와의 상호작용, 시각·사운드 후처리(phase 20 polish 영역).

#### 3.3.3 엣지 케이스
- **TBD**: Water 위에 Bridge 생성, 끈끈이 위 분배자 정착, hazard 위에서 능력 전이 발생.

### 3.4 파괴 메카닉 (phase 18, 19 = 17a, 17b)

#### 3.4.1 Basher + Digger (흙 지형, 17a)
- 기존 phase15/16 명세를 흡수.
- **TBD**: 흙 동적 파괴 후 위쪽 개미의 fall-through 처리, chain reaction, 파괴 가능 영역 시각화.

#### 3.4.2 Cutter + 식물 지형 (17b)
- Bomber 자리 대체. 식물 지형은 신규 TileMap cell type.
- **TBD**: Cutter 작동 범위(인접 셀 1칸 vs 라인), 식물 지형 vs 흙 지형 구분 기준, 절단 후 잔여물(파편·아이템) 처리, 식물 지형의 hazard·생성 메카닉과의 상호작용.

### 3.5 ADR-002 4-카운터 — 변경 없음
- `original_hp / saved / in_transit / lost` 4-카운터 그대로 적용.
- 페일 = `lost++`, 임무 완수 = `saved++`.
- 정착 시 추가 카운터(`settled` 등) 도입 여부는 **TBD** — 본 문서에서는 필요 없다고 간주, phase 15 plan 단계에서 재검토.

---

## 5. 결정 사항 (잔여 5건 모두 확정)

> 본 절은 옵션 B 확정 절차(§8)의 1번 단계 산출물이다. 각 결정 행은 migration plan §1에서 동일하게 인용된다.

### 5.1 Phase 14 분할 14a/14b
- **결정**: 분할 채택.
- **근거**:
  - §7.1 정수 id 정책 위반 없이 라벨로 분할 가능.
  - 14b(정착 + 능력 전이)에 시스템 부담이 집중되어 단일 phase로 묶으면 무겁다.
  - 학습 곡선 측면에서 트레잇 도입(14a)과 능력 전이(14b) 분리가 자연스러움.

### 5.2 Phase 17 (파괴) 분할 17a/17b
- **결정**: 17a/17b 분할 채택.
- **근거**:
  - 식물 지형 신설(신규 TileMap cell type + Cutter 작동 명세)이 흙 파괴(Basher+Digger)와 동시 진행되면 phase 무게 과적.
  - codex 리뷰에서 HIGH 위험(테스트 범위 폭증·rollback 어려움) 회피.
- **결과**: phase 14~20 = 7 phase 구성.

### 5.3 분배자 사탕 UX
- **결정**: A안 — 경고 없이 정착 허용.
- **근거**:
  - §3.1.3.
  - 100% 도달 = 회수 동선 끊김 = puzzle 본질 신호 (§0.7.5).
  - B안(경고 UI)은 어린 플레이어에게 노이즈로 작용하고, 정착 자체가 페일이 아니라는 §0.2 톤 폴리시와 충돌.

### 5.4 상대 무게 재산정
- **결정**: 잠정치 유지 (§2.4 합계 46800).
- **근거**: §0.7.0. 각 phase plan 단계에서 재조정 가능. wall-clock 환산 금지.

### 5.5 Phase 1~13 콘텐츠 재설계
- **결정**: 별도 트랙 분리 (a 옵션).
- **근거**:
  - 본 옵션 B 작업 범위는 phase 14~20 한정.
  - phase 1~13 재설계는 `codex-worklog/` 트랙 또는 v1.1 phase로 후속 처리.
  - 본 작업과 동시 진행 시 status.json·notion-phase-ids 등 SoT 충돌 위험 큼.

---

## 7. 정책

### 7.1 정수 id 정책
- `execute.py:462,654`는 정수 id만 허용.
- 14a/14b/17a/17b는 **README 라벨로만 표기**. 파일명 prefix는 정수(`phase14-`, `phase15-`, `phase18-`, `phase19-` …)로 유지.
- `execute.py:111`이 `sorted(glob("phase*.md"))`로 파일명 알파벳 순 정렬해 id 자동 부여.

### 7.2 git mv 정책
- v0.1 phase 파일(stage 기반) → v0.2 phase 파일(메카닉 기반)은 본문 유사도가 낮다(톤 폴리시·신규 시스템·통합 흡수로 거의 처음부터 작성).
- git이 자동으로 rename 인식하지 않을 가능성 높음.
- `execute.py:743-748`이 rename 감지 시 complete를 hard reject.
- **결론**: `git mv` 사용 안 함. `git rm` + 새 파일 `git add` 패턴. history는 migration plan + REVISION 노트로 보존.

### 7.5 PRD / ARCHITECTURE / ADR 영향
- 큰 틀은 그대로.
- `docs/PRD.md`에 §0.2 페일 어휘 정책(기존 페일 어휘 → "사탕 손실" 통일) 명시 갱신은 **별도 작업**으로 분리. 본 옵션 B migration commit과 묶지 않음.
- `docs/ADR.md` ADR-002 4-카운터 — 변경 없음 (§3.5).

---

## 8. 확정 절차

1. **잔여 결정 5건 확정** (§5.1~§5.5). ✅ 본 문서 v0.2 시점에서 모두 확정 완료.
2. **본 PROPOSAL.md 1차 작성** ✅ (본 commit).
3. **migration plan과 cross-reference 정합 self-review** — 본 문서 §1·§2·§3·§5·§7 인용이 migration plan에서 정합하는지 확인.
4. **codex adversarial-review (plan stage)** — `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` + 본 PROPOSAL.md 동시 대상.
5. review HIGH 0건 → migration plan §4 Commit 3 phase 파일 재구성 진행.
6. review HIGH 1건 이상 → CLAUDE.md plan stage 정책에 따라 즉시 중단 + 사용자 결정. 자동 재리뷰 사이클 X.

---

## TBD 인덱스

본 문서는 옵션 B의 **결정·매핑·정책**을 확정한다. 다음 항목은 명시적 TBD이며 phase 진입 시점의 `plans/phaseNN-plan.md`에서 구체화한다. 각 항목은 phase plan의 **Open decisions before implementation** 체크리스트에 그대로 옮길 수 있도록 한 결정만 담는다.

### Phase 15 / 14b — 정착 + 능력 전이
- §3.1.1 정착 트리거는 타이머, 위치 조건, 플레이어 입력 중 무엇인가?
- §3.1.1 정착 후 상태 머신은 기존 StateMachine 노드 확장인가, 별도 settlement controller인가?
- §3.1.1 정착 해제를 허용하는가?
- §3.1.2 전이 범위는 반경, 시간, 직접 접촉 중 무엇인가?
- §3.1.2 전이 시각화는 파티클, 아이콘 표시, 둘 다, 없음 중 무엇인가?
- §3.1.2 이미 트레잇을 가진 개미의 중복 부여를 무시, 갱신, 스택 중 어떻게 처리하는가?
- §3.1.2 전이 가능 트레잇은 Floater만인가, 전체 트레잇인가, 별도 화이트리스트인가?
- §3.1.4 분배자 정착 중 사탕과 충돌하면 운반/정착/회수 판정을 어떻게 우선순위화하는가?
- §3.1.4 능력 전이를 받는 개미가 이미 다른 트레잇을 가진 경우 §3.1.2 중복 정책과 같은 규칙을 적용하는가?
- §3.1.4 정착 직후 hazard 진입으로 사탕 손실 처리되는 경우 전이 완료/취소/지연 중 무엇으로 처리하는가?
- §3.5 정착 개미를 별도 카운터(`settled`)로 추적할 필요가 있는가, 아니면 기존 4-카운터만 유지하는가?

### Phase 16 / 15 — 생성 메카닉
- §3.2.1 Sand-mound 쌓기 속도는 tick 기반인가, 거리 기반인가?
- §3.2.1 Sand-mound 최대 높이는 고정값인가, stage 데이터 override인가?
- §3.2.1 Sand-mound 생성 중 다른 개미와 충돌하면 통과, 밀림, 중단 중 무엇인가?
- §3.2.1 Sand-mound는 자연 무너짐을 가지는가?
- §3.2.2 Bridge 수평 거리 한계는 고정값인가, stage 데이터 override인가?
- §3.2.2 Bridge 시작/끝은 갭 자동 감지인가, 플레이어 수동 지정인가?
- §3.2.2 미완성 Bridge 상태에서 개미가 사탕 손실 처리되면 잔재를 유지, 제거, 즉시 완성 중 무엇으로 처리하는가?
- §3.2.3 Sand-mound와 Bridge가 겹치는 좌표에서는 어느 생성물이 우선하는가?
- §3.2.3 hazard 위 생성 시도를 허용, 차단, 조건부 허용 중 어떻게 처리하는가?
- §3.2.3 식물 지형 위 생성 가능 여부와 우선순위는 어떻게 정하는가?

### Phase 17 / 16 — Hazard
- §3.3.1 Water 깊이는 단일 레벨인가, 여러 단계인가?
- §3.3.1 Water 전파 속도는 고정값인가, stage 데이터 override인가?
- §3.3.1 Water와 끈끈이가 겹치면 어느 hazard 판정이 우선하는가?
- §3.3.2 끈끈이 해방 메커니즘은 시간 경과 자동인가, Cutter 등 외부 개입인가, 둘 다인가?
- §3.3.2 끈끈이 위에서 정착을 허용하는가?
- §3.3.2 끈끈이 상태에서 능력 전이를 허용하는가?
- §3.3.2 끈끈이 시각·사운드 후처리는 phase 17 최소 구현에 포함하는가, phase 20 polish로 넘기는가?
- §3.3.3 Water 위 Bridge 생성을 허용, 차단, 조건부 허용 중 어떻게 처리하는가?
- §3.3.3 hazard 위에서 능력 전이가 발생하면 전이 완료/차단/지연 중 무엇으로 처리하는가?

### Phase 18 / 17a — 흙 지형 파괴
- §3.4.1 흙 동적 파괴 후 위쪽 개미의 fall-through 판정은 즉시 재계산인가, 다음 physics tick인가?
- §3.4.1 Basher/Digger 파괴가 chain reaction을 만들 수 있는가?
- §3.4.1 파괴 가능 영역 시각화는 preview overlay, cursor hint, 없음 중 무엇인가?

### Phase 19 / 17b — Cutter + 식물 지형
- §3.4.2 Cutter 작동 범위는 인접 셀 1칸인가, 라인인가?
- §3.4.2 식물 지형과 흙 지형의 구분 기준은 TileMap layer, terrain set, custom data 중 무엇인가?
- §3.4.2 절단 후 잔여물은 파편, 아이템, 즉시 제거 중 무엇인가?
- §3.4.2 식물 지형은 hazard와 어떤 우선순위를 가지는가?
- §3.4.2 식물 지형 위 생성 메카닉을 허용, 차단, 조건부 허용 중 어떻게 처리하는가?

**TBD 처리 정책** (Round 2/3 codex review 반영):
- 각 TBD는 해당 phase plan(`plans/phaseNN-plan.md`)의 **Open decisions before implementation** 결정 항목으로 승격되어 채워진다.
- phase 명세 파일(`phaseNN-<slug>.md`)에는 TBD 본문을 **직접 복사하지 않는다** — 결정 대기 항목 목록(짧은 한 줄)으로만 요약 표기 (migration plan §2.6 step 7 참조).
- 결정 권한: phase plan 작성·검수 시점에 사용자가 결정. 본 PROPOSAL.md 본문은 결정 후에도 갱신하지 않음(역사 보존). 후속 의사결정 추적은 phase plan 또는 후속 REVISION 노트로.

TBD 잔존은 migration plan 진행을 차단하지 않는다 — migration plan은 phase **명세 파일 재구성**까지가 범위이고, 시스템 상세는 각 phase plan에서 채우는 구조다.
