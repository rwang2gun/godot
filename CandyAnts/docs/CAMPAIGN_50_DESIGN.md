# CandyAnts 캠페인 50 — 5챕터 × 10스테이지 설계 문서

작성: 2026-06-09 · **이 문서가 50스테이지 캠페인 재설계의 1차 SoT(설계 정렬용).**
선행 문서: `docs/LEVEL_REDESIGN_STATUS.md`(기존 9스테이지 저작 이력) · `docs/DOMAIN_MAP.md`(파일 인덱스) · `docs/PRD.md`/`ARCHITECTURE.md`/`ADR.md`(설계 정본).

> ⚠ **상태: 설계 정렬 단계 (pre-phase).** 본 문서는 컨셉·스킬 언락 케이던스·인프라/UI 계획·Phase 분할을 확정하기 위한 문서다.
> 각 스테이지의 정밀 지오메트리(셀 좌표·타일 배치)는 **해당 Phase 저작 시점**에 확정한다(여기선 컨셉 1줄 + 스킬 + 기믹 + 해저드만).
> Phase 시작 전 `docs/` 3개 문서(PRD/ARCHITECTURE/ADR) 필독 규칙은 그대로 적용.

---

## 0. 한 줄 요약

캠페인을 **5챕터 × 10스테이지 = 50스테이지**로 확장한다. 스킬 10종을 챕터가 올라갈수록 새로 해제(누적)하여 **Ch4까지 전 스킬 학습 완료**, **Ch5는 신규 없이 전 스킬 종합 마스터리**. 기존 S1~S9는 같은 스킬을 가르치는 검증된 자산이므로 Ch1~Ch4에 **재배치·재활용**한다.

---

## 1. 확정 결정 (사용자 정렬, 2026-06-09)

1. **구조**: 5챕터 × 10스테이지 = 50.
2. **스킬 언락 매핑** (3+3+2+2 = 10, Ch4에 전부 학습 완료):

   | 챕터 | 테마 | **새로 해제되는 스킬** | 입력 모델(§DOMAIN_MAP 2.1) |
   |---|---|---|---|
   | **Ch1 기초** | 통행·제어 | `climber` · `blocker` · `floater` | ③무장 / ②정착·이탈 |
   | **Ch2 건설** | 다리·계단·사다리 | `bridge` · `builder` · `sand_mound` | ③무장 / ①푯말 |
   | **Ch3 파괴** | 굴착 | `basher` · `digger` | ①푯말 |
   | **Ch4 장치·숙련** | 식물 절단·점프대 | `cutter` · `leaf_jump` | ①푯말 / ④장치 |
   | **Ch5 종합** | 마스터리 | (신규 없음) | 전 4종 모델 |

3. **누적 스킬 풀 (CRITICAL)**: 각 챕터는 *그 챕터 신규 스킬 + 이전 챕터 모든 스킬*을 자유롭게 사용한다. 상위 챕터일수록 사용 가능 스킬 폭이 넓어지는 것이 난이도 곡선의 핵심. (예: Ch3는 basher/digger뿐 아니라 Ch1·Ch2의 7종도 퍼즐에 섞을 수 있다.)
4. **기존 S1~S9 처리**: Ch1~Ch4에 재배치/재활용 (스킬이 일치하는 검증된 레벨). §4 재번호 맵 참조.
5. **첫 산출물**: 본 50스테이지 전체 설계 문서(현재 문서).
6. **챕터 선택 UI**: 본 문서에 포함, 저작 초반(Phase A 인프라)에 구축.
7. **복층 구조**: 새 코어 없이 데이터 저작만으로 지원(§2.5, S6 선례). **수직 이동 어휘는 챕터별 성장** — 복층 난이도를 그 어휘에 맞춰 스케일한다(§2.5.3). **Ch1 복층은 "계단식 열린 단"만**(사용자 결정 2026-06-09 — climber 열린 벽면 + floater 하강, 밀폐 스택 룸은 Ch2부터). 경사 램프는 채택 안 함.
8. **여백 = 물**: 플레이 영역 밖 도달 가능한 빈 공간은 `water`로 채운다(§2.2.1, 사용자 결정 2026-06-09).
9. **캠페인 매니페스트**: *캠페인 순서/챕터 배치*를 *씬 id*와 분리하는 매핑 계층을 Phase A에서 구축(§5.0, 사용자 결정 2026-06-09). 씬 id는 불변, 재배치는 매니페스트 배열 편집으로만 — 재번호·파일 rename 0건.

---

## 2. 난이도 곡선 · 챕터 내 케이던스

### 2.1 챕터 내 10스테이지 표준 케이던스
각 챕터는 아래 리듬을 따른다(엄격 규칙 아님, 가이드):

| 슬롯 | 역할 |
|---|---|
| 1~2 | 신규 스킬 A를 **단독**으로 깔끔하게 교육 (다른 변수 최소) |
| 3~4 | 신규 스킬 B 단독 교육 (또는 A 심화) |
| 5~6 | 신규 스킬 C 교육 / A+B 첫 조합 |
| 7~8 | 챕터 신규 스킬 + **이전 챕터 스킬 누적** 조합 |
| 9 | 고난도 통합 |
| 10 | **캡스톤** — 챕터 종합, 타이트한 별3 임계, 다음 챕터 게이트 |

### 2.2 파라미터 진행 가이드 (SoT 아님 — 저작 시 실측 조정)
- **candy_hp / total_ants**: Ch1 hp4~5 → Ch5 hp6~8. 마리수는 hp 이상으로 여유.
- **⚠ Ch1 한정 고정 지침 (사용자 결정 2026-06-10 — 위 일반 가이드를 Ch1에서 override)**:
  - **candy_hp = 5 고정** (Ch1 전 스테이지).
  - **total_ants = 5 + 영구 소비 설치물 수** — *여분 개미 0*. 영구 소비 = 개미가 설치물이 되어 은퇴하는 스킬(blocker 정지, floater 분배자 정착). 예: climber-only=5 / blocker 1=6 / floater 분배자 1=6.
  - **소비형 스킬 인벤토리 = 필요 수 그대로** (초과분은 "한 마리 더 정착 → 운반자 부족 → 클리어 불능" 자충수가 되므로 금지). 트레잇형(climber)은 운반자 수만큼.
  - **함의**: ①개미 수 자체가 퍼즐을 서술한다("사탕 5, 개미 6 → 한 마리는 길막이가 된다") ②보라별(100%)=무손실 플레이 ③운반 중 손실(carrier death)은 부분 클리어로 강등(★ 등급), *빈손 사망*은 그 조각 회수 불능 → no_more_ants 실패 — 짧은 교육 스테이지라 fail-retry 루프가 저렴해 허용.
  - 기존 슬롯 정합화: stage11~14는 적용 완료. **stage01(total 8)·stage02(total 7)는 B2 sweep에서 정합화**(B1 범위 락 — stage02 이름 rename과 동일 묶음).
- **time_limit**: 초반 90~120s, 후반 캡스톤 150s+.
- **스킬 인벤토리 희소도(scarcity)**: 챕터가 오를수록 *정밀 배치 강요*(Lemmings 패턴). 교육 스테이지는 넉넉, 캡스톤·Ch5는 극소량.
- **별점**: **전역 규칙 고정**(saved≥1=★1 / 50%=★2 / 80%=★3, `Scoring.compute_stars`). **스테이지별 임계값은 schema v3에서 폐지** — `StageData`에 star_thresholds 필드 없음, 저작 시 신경 쓸 것 없음. 난이도는 지오메트리·인벤토리·시간으로만 조절.

### 2.2.1 ⚠ 저작 컨벤션 — 여백 = 물 채우기 (CRITICAL, 사용자 결정 2026-06-09)

**모든 스테이지의 "여백 구간"(플레이 영역 밖 도달 가능한 빈 공간)은 `water`(소다물, 즉사 lost)로 채운다.** 떨어지면 어디서든 일관되게 손실 → 경계가 명확하고 캔디 테마(소다물)와 통일.

- **대상**: ① 플레이 바닥 *아래* 행들(지형 밑), ② 플레이 영역 *좌/우 바깥* 열들(화면 가장자리까지), ③ 의도된 치명적 갭/구덩이.
- **구현**: 레이아웃 `hazard_map`에 해당 셀들을 `"water"`로 채움(+ 필요 시 `Water.tscn` Area2D 인스턴스). 기존 선례 = `stage06_layout`의 `hazard_map`(좌 col −9~−1, 우 col 24~31, rows 10~17). 신규 50스테이지 전부 이 패턴 적용.
- **예외**: S3류 "호수" 퍼즐처럼 물을 *경로 중앙*에 의도 배치하는 경우는 여백이 아니라 설계 요소(다리 필수). 여백 규칙과 별개로 추가.
- **주의**: 복층(§2.5)에서 *하층 바닥 아래*도 여백이면 물. 단 상층↔하층 사이의 의도된 빈 공간(공동·낙하 구간)은 floater/digger로 통과하는 *플레이 공간*이므로 물 금지 — "도달 가능하지만 경로 밖"만 물.

### 2.3 해저드 도입 케이던스
- **water(소다물, 즉사 lost)**: 전 스테이지 보편 경계(가장자리·바닥). Ch1에서 *구덩이*로 가볍게, Ch2 "호수"에서 *퍼즐화*(다리 필수).
- **cookie(불괴 벽)**: Ch3 굴착에서 *파괴 불가 경계*로 도입(통로 한정).
- **plant(식물, cutter 전용 파괴)**: Ch4 cutter 도입과 함께.
- **sticky(캐러멜, 3초 감속·lost 아님)**: Ch4에서 도입(leaf_jump로 건너뛰는 동기).

---

## 2.5 복층(Multi-floor) 구조 — 가능성 검증 + 설계 가이드

> 사용자 요청(2026-06-09): "복층 구조를 활용하고 싶다." **결론: 새 코어 없이 데이터 저작만으로 가능. 엔진이 이미 받쳐준다.**

### 2.5.1 가능성 근거 (코드 실측)
1. **지형 = 자유 셀 그리드**: `StageLayoutData.tile_map`이 `"x,y": kind` 딕셔너리. 솔리드 셀을 천장·오버행 등 *임의 위치*에 배치 가능. `StageLayoutBuilder._add_cell`이 셀마다 `StaticBody2D + RectangleShape(48×48)` 생성 → **천장 셀이 실제 충돌체**(아래에서 머리 부딪힘). 좁은 `== TILE_SOLID` 해석이 아니라 셀 존재 자체가 SoT.
2. **실증 선례**: `stage06`(땅굴)이 이미 **3층 수직 구조** — 흙 캡 지붕(rows 2–5) / 공동(rows 6–12) / 쿠키 챔버(rows 13–17). 복층은 신규 개념이 아니라 *기존 검증된 패턴의 확장*.
3. **화면 세로 여유**: 뷰포트 `1644×1080`(`project.godot`), `cell_size=48` → 한 화면 **≈34열 × 22.5행** 가시. 기존 스테이지는 24열 × 16~18행만 사용 → 세로로 **5~6층 여유**. 카메라는 스테이지별 고정(`World/Camera2D` at `camera_cell` 중심, zoom 미사용=1.0). 더 높은 레벨은 `Camera2D.zoom`을 낮춰(예: 0.8) 더 넓게 담을 수 있음(스프라이트는 작아짐 — 트레이드오프).
4. **층간 이동 동사 8종 보유**: ↑ climber(벽)·sand_mound(수직 사다리)·builder(대각 계단)·leaf_jump(점프대 발사) / ↓ digger(바닥 구멍)·floater(안전 낙하) / ↔ bridge(갭)·basher(벽 관통). **"층 사이를 무엇으로 넘나"가 그대로 퍼즐 축**이 된다.

### 2.5.2 설계 가이드라인 (저작 시 준수)
- **헤드룸 ≥ 2행**: 한 층의 보행면(솔리드 윗면)과 위층 천장 사이에 **빈 행 2개 이상**(개미 몸통 1 + 클리어런스 1). 1행이면 개미가 천장에 끼일 위험.
- **총 높이 ≤ ~20행** @ zoom 1.0(여백 포함). 초과 시 `camera_cell` 재배치 + `zoom` 하향. 한 화면에 안 들어오는 스크롤형은 **범위 외**(카메라 follow는 신규 코어 — 현재 미지원, 필요 시 별도 Phase).
- **층간 연결을 스킬로 게이팅 = 복층이 퍼즐이 됨**: 예) 위층 사탕은 `sand_mound`/`builder`/`climber`로만 도달, 아래층 귀가는 `digger`/`floater`로만. "어느 층을 어느 스킬로 잇나"가 핵심 결정.
- **수직 운반 주의 (기존 갭)**: `CarryingState`는 일부 상승 통행(StairClimb/LadderClimb) 미적용 — *사탕을 들고 위층으로 올라가는* 동선은 현재 제약. **하강 운반은 안전**(S4·S6 선례). 복층 설계 시 *위층에서 사탕 회수 → 아래로 운반 귀가* 방향을 기본으로(상승 운반이 꼭 필요하면 해당 Phase에서 코어 보강 — S4 step-up·S5 ladder 패턴).
- **천장 시각**: 천장 셀도 일반 솔리드 렌더(`_solid_texture_for_cell`이 "위 칸 존재→solid family"). 별도 작업 불필요.

### 2.5.3 ⚠ 수직 이동 어휘 = 챕터별 성장 (복층 난이도는 어휘에 맞춰 스케일)

> **핵심 제약 (코드 실측, 2026-06-09)**: walker는 경사·1칸 턱을 *자동으로 못 오른다* — `WalkerState`는 climber/stair/ladder 게이트가 아니면 벽에서 `flip`. 경사 타일 자동 보행도 미검증(45°=floor_max_angle epsilon 리스크, DOMAIN_MAP §1 노트). **climber는 임의 높이 벽을 끝까지 올라 mantle하지만, 머리 위가 천장이면**(`ClimberState.is_on_ceiling`) **등반 실패·낙하** → *위가 열린 벽면만* 오른다.
>
> ⟹ **"수직 연결을 만드는 스킬"은 챕터마다 자란다. 복층 야망을 그 어휘에 맞춰라.** (스킬 매핑 변경 불필요 — Ch2=건설 테마와 정합.)

| 챕터 | 위로(↑) 어휘 | 아래로(↓) 어휘 | 가능한 복층 형태 |
|---|---|---|---|
| **Ch1** | climber(*기존* 열린 벽면) | floater · 안전낙하 | **계단식 열린 단(ledge)만.** 플레이어가 연결 생성 불가. 천장 막힌 밀폐 방 ❌ |
| **Ch2** | +builder(대각 계단) · sand_mound(수직 사다리) | +bridge(수평) | **플레이어가 ↑연결 건설** → 밀폐 상층 진입. 복층이 주 테마로 |
| **Ch3** | +basher(수평 터널) | +digger(바닥 구멍 ↓) | **↓연결·수평 자작** → 밀폐 복층 미로 완전 자유 |
| **Ch4+** | +leaf_jump(발사 ↑) | (동일) | 점프 기반 수직 추가 |

**저작 규칙**:
- **Ch1 복층 = "계단식 열린 단"만** (climber로 오를 수 있게 각 상층 진입 벽면을 *위로 열어둔다* — 천장 금지). 밀폐 스택 룸은 Ch2부터.
- 밀폐/복잡 복층은 **수직 연결을 그 챕터 신규 스킬로 게이팅**(예: Ch2 상층은 사다리/계단으로만, Ch3 하층은 digger 구멍으로만). 이게 곧 퍼즐.
- Ch1에서 더 풍부한 수직이 필요하면 옵션: ① 열린 climber 벽면 다단 배치(검증됨), ② 경사 타일 램프(**미검증** — 쓰려면 Phase A에서 walker 경사 보행 검증 선행).

### 2.5.4 복층 쇼케이스 스테이지 (본 시트에 반영)
복층을 *주 기믹*으로 쓰는 스테이지를 챕터별로 분산 배치한다(아래 §3 시트의 해당 행이 이 가이드를 따름):
- **Ch2** #16 탑과 다리(사다리로 위층 → 다리로 건너), #19 건너고 또 건너(다단 단차)
- **Ch3** #23 땅굴(기존 3층), #24 깊은 우물(깊은 수직 다층), #28 미로 굴착(수평·수직 복층 미로)
- **Ch4** #40 사탕 공방(다층 공방)
- **Ch5** #44 공중 정원(다단 플랫폼), #46 깊고 높은(지하층+고층 동시), #50 사탕 왕국(최대 복층)

---

## 3. 50스테이지 전체 시트

> 표기: **[NEW: x]** = 그 챕터 신규 스킬 첫 등장. *used* = 그 스테이지에서 쓰는 스킬(누적 풀에서 선택). 해저드 별도 표기. *(S#)* = 기존 스테이지 재활용 출처.

### CHAPTER 1 — 기초 (Stages 1–10) · 신규: climber · blocker · floater

| # | 이름 | 신규/사용 스킬 | 컨셉 · 기믹 | 해저드 |
|---|---|---|---|---|
| 1 | 첫 나들이 | **[NEW: climber]** | 중앙 1칸 분지 왕복으로 climber 최소 동작 학습 *(S1)* | — |
| 2 | 담을 넘어 | climber | 3칸 벽을 climber 반복으로 등반, 직선 경로 | — |
| 3 | 낭떠러지 끝 | **[NEW: blocker]** | 가장자리 물구덩이로 빠지는 무리를 blocker로 차단 | water |
| 4 | 방향 전환 | blocker, climber | blocker 충돌-반전으로 무리를 안전 갈래로 유도 | water |
| 5 | 높은 곳에서 | **[NEW: floater]** | 6칸+ 낙하=기절(lost), floater로 안전 강하 학습 | — |
| 6 | 오르막 | climber, floater, blocker | climber 등반 + 복귀 6칸 낙하 floater *(S2)* | — |
| 7 | 두 길 | blocker, floater | blocker로 길 막아 우회 + floater 강하 조합 | water |
| 8 | 물웅덩이 사이 | climber, blocker | 물구덩이 여럿, 정밀 blocker 배치로 통과 | water |
| 9 | 좁은 발판 | climber, blocker, floater | 3종 모두 동원하는 다층 발판 퍼즐 | water |
| 10 | **개미 언덕** (캡스톤) | climber, blocker, floater | Ch1 종합 — 다층 지형, 3종 정밀 운용 | water |

### CHAPTER 2 — 건설 (Stages 11–20) · 신규: bridge · builder · sand_mound · (+Ch1 누적)

| # | 이름 | 신규/사용 스킬 | 컨셉 · 기믹 | 해저드 |
|---|---|---|---|---|
| 11 | 사탕 호수 | **[NEW: bridge]** | 갭 위 수평 다리(무장→낭떠러지 자동 건설) *(S3)* | water |
| 12 | 긴 강 | bridge, blocker | 다리 길이 제한(8칸) 학습, 배치 위치 정밀 | water |
| 13 | 계단 공사 | **[NEW: builder]** | builder 대각 상승 계단 *(S4)* | — |
| 14 | 올라가고 내려가고 | builder, floater | builder 상승 + 반대편 floater 하강 | water |
| 15 | 막대과자 탑 | **[NEW: sand_mound]** | 수직 사다리로 고립 플랫폼 등반 *(S5)* | — |
| 16 | 탑과 다리 | sand_mound, bridge | 사다리로 오른 뒤 다리로 건너기 (건설 2종 연계) | water |
| 17 | 계단과 강 | builder, bridge | 계단으로 올라 호수를 다리로 건너기 | water |
| 18 | 세 갈래 공사 | bridge, builder, sand_mound | 건설 3종을 각 1회씩, "어느 갭에 무엇을" 판단 | water |
| 19 | 건너고 또 건너 | bridge, builder, sand_mound, blocker | 다단 갭·단차, 건설 3종 + blocker 길 제어 | water |
| 20 | **과자 공사장** (캡스톤) | 건설 3종 + climber/floater | Ch2 종합, Ch1 보조 누적 | water |

### CHAPTER 3 — 파괴 (Stages 21–30) · 신규: basher · digger · (+Ch1·2 누적)

| # | 이름 | 신규/사용 스킬 | 컨셉 · 기믹 | 해저드 |
|---|---|---|---|---|
| 21 | 옆파기 | **[NEW: basher]** | 흙 벽 수평 굴착 통로, 왕복 친화 *(S7)* | — |
| 22 | 벽 너머 | basher | 두꺼운 흙 벽 관통, cookie 불괴 벽이 통로 경계 | cookie |
| 23 | 땅굴 | **[NEW: digger]** | 수직 굴착 + 공동 floater 강하 *(S6)* | — |
| 24 | 깊은 우물 | digger, floater | 깊은 수직 하강 + 챔버, floater 분배 | cookie |
| 25 | 파고 건너 | digger, basher | 내려가 옆 통로로 (파괴 2종 연계) | cookie |
| 26 | 무너진 계단 | basher, builder | 벽 뚫고 계단으로 상승 (파괴+건설 교차) | water |
| 27 | 굴과 다리 | digger, bridge | 지하로 내려가 갭을 다리로 건너기 | water |
| 28 | 미로 굴착 | basher, digger | 수평·수직 굴착으로 막힌 미로 뚫기, cookie 경계 | cookie |
| 29 | 건설과 파괴 | basher, digger, bridge, sand_mound, blocker | Ch2+Ch3 종합 응용 *(S9 재구성)* | water |
| 30 | **과자 광산** (캡스톤) | basher, digger + 건설/통행 보조 | Ch3 종합, 누적 풀 다수 | water·cookie |

### CHAPTER 4 — 장치·숙련 (Stages 31–40) · 신규: cutter · leaf_jump · (+전 챕터 누적, "전 스킬 학습 완성")

| # | 이름 | 신규/사용 스킬 | 컨셉 · 기믹 | 해저드 |
|---|---|---|---|---|
| 31 | 박하 덤불 | **[NEW: cutter]** | plant 벽 절단(전방 열 march) *(S8 일부)* | plant |
| 32 | 넝쿨 숲 | cutter | 다열 plant 미로, cutter 정밀 절단 | plant |
| 33 | 나뭇잎 점프대 | **[NEW: leaf_jump]** | 재사용 점프대 장치로 무리 반복 발사 | — |
| 34 | 끈끈이 늪 | leaf_jump, floater | sticky 감속 도입, 점프대로 sticky 건너뛰기 *(S8)* | sticky·water |
| 35 | 점프와 절단 | leaf_jump, cutter | 장치형 2종 연계 (점프대+넝쿨) | plant·sticky |
| 36 | 통행 마스터 | climber, floater, leaf_jump | 통행 3종 집중 복습 | water |
| 37 | 건설 마스터 | bridge, builder, sand_mound | 건설 3종 집중 복습 | water |
| 38 | 파괴 마스터 | basher, digger, cutter | 파괴 3종 집중 복습 | plant·cookie |
| 39 | 제어와 응용 | **전 10종 등장** | blocker 중심 + 전 카테고리 1종씩 — *학습 완성 체크포인트* | water·sticky |
| 40 | **사탕 공방** (캡스톤) | 10종 전부 가용, cutter/leaf_jump 핵심 | Ch4 종합 | plant·sticky·water |

### CHAPTER 5 — 종합 (Stages 41–50) · 신규 없음 · 전 10종 + 전 해저드, 최고 난이도

| # | 이름 | 사용 스킬 | 컨셉 · 기믹 | 해저드 |
|---|---|---|---|---|
| 41 | 귀환 | 통행+건설 위주 | 종합 워밍업, 익숙한 지형의 복합 버전 | water |
| 42 | 사탕 협곡 | 건설+파괴 대규모 | 큰 갭/벽, 다리·계단·굴착 동시 | water·cookie |
| 43 | 끈끈한 광산 | 파괴 3종 + leaf_jump | sticky 늪 + 굴착, 점프대 우회 | sticky·cookie |
| 44 | 공중 정원 | 통행 3종 + leaf_jump | 다단 점프대·고지대, 정밀 낙하 | water |
| 45 | 이중 호수 | bridge·builder + blocker | 호수 2개, blocker로 무리 분기 | water |
| 46 | 깊고 높은 | digger·sand_mound·floater | 깊은 하강 + 높은 상승, floater 분배 | cookie·water |
| 47 | 넝쿨 미로 | cutter·basher | 식물+흙 미로, 제한 인벤토리 | plant·cookie |
| 48 | 희소 자원 | 전 10종 극소량 | scarce 인벤토리 강제 정밀 배치 (Lemmings) | 전부 |
| 49 | 대장정 | 전 10종 골고루 | 긴 경로·다수 마리, 지구전 | 전부 |
| 50 | **사탕 왕국** (파이널) | 전 10종 총동원 | 최종 보스 스테이지, 최대 난이도 | 전부 |

---

## 4. 기존 S1~S9 챕터 배치 맵 (매니페스트 기반 — 재번호 없음)

> **§5.0 매니페스트 도입으로 "재번호"가 사라졌다.** S1~S9는 **씬 id를 그대로 둔다**(`Stage01~09.tscn` 불변, 테스트 경로 참조 무파손). 어느 챕터의 몇 번째에 놓을지는 *매니페스트 배열*로만 결정한다. 아래는 그 *배치 의도*(콘텐츠 → 챕터)다 — 실제 순서 인덱스는 매니페스트가 SoT이고 언제든 배열 편집으로 조정.

> **실측 (2026-06-09)**: 현재 캠페인은 **10 스테이지**(`data/stages/stage01~10.tres`). 아래는 실제 이름·스킬. (LEVEL_REDESIGN_STATUS §0.6 표는 stale — 본 표가 권위.)

| 기존 씬 | 이름 | 스킬 | 씬 id (불변) | → 배치 챕터 |
|---|---|---|---|---|
| Stage01 | 첫 나들이 | climber | 1 | **Ch1** |
| Stage02 | 절벽 아래로 | climber+floater+blocker | 2 | **Ch1** |
| Stage03 | 웅덩이 넘기 | bridge | 3 | **Ch2** |
| Stage04 | 높은 곳에 닿으려면 | builder | 4 | **Ch2** |
| Stage05 | 과자 사다리 | sand_mound+floater | 5 | **Ch2** |
| Stage06 | 숨겨진 사탕 | digger+climber | 6 | **Ch3** |
| Stage07 | 벽 너머로 | basher | 7 | **Ch3** |
| Stage08 | 귀찮은 식물들 | cutter+leaf_jump | 8 | **Ch4** |
| Stage09 | 고지로! | bridge+basher+blocker+sand_mound | 9 | **Ch5**(콤보) |
| Stage10 | 보물찾기! | builder+digger+cutter+leaf_jump+climber | 10 | **Ch5**(콤보) |

> **Phase A 초기 매니페스트 = 위 순서 그대로** `[1,2][3,4,5][6,7][8][9,10]` → 전역 순서 [1..10] 보존(회귀 최소). 신규 스테이지 저작(B1~F2) 시 각 챕터 배열에 append하며 §3 시트의 50-구성으로 확장. 그 과정에서 §3 시트의 컨셉 이름(예: "사탕 호수")과 실제 씬 이름(예: "웅덩이 넘기")은 자연 수렴시킨다(씬 display_name 갱신 또는 시트 표기 정렬 — 저작 시 결정).

**효과 (재번호 리스크 소멸)**:
- 씬 파일·테스트 경로 불변 → `tests/CampaignS#*Test.tscn`·`GameFlowTest` 등 **씬 경로 참조는 안 깨진다**. 변경은 *매니페스트 배열* + *순서 의존 단언*(언락/Next 순서를 검사하는 일부 테스트)뿐.
- 신규 스테이지(Ch1 #3~5·#7~10, Ch2 나머지, …)는 **다음 빈 씬 id**로 저작(`Stage10.tscn`~) 후 매니페스트 배열에 끼워 넣는다.
- 나중 스테이지 분배·순서 조정 = **매니페스트 배열 편집 한 번** (사용자 요청의 핵심 — Phase A에서 이 기능 자체를 먼저 구축).
- 메인 스테이지 경로 락(`Stage%02d` + 레벨툴 애드온)은 그대로 — 씬 id가 곧 파일 번호라 자연 호환. 애드온 슬롯 상한만 Phase A에서 확인.

---

## 5. 인프라 · UI 계획 (Phase A에서 구축)

### 5.0 캠페인 매니페스트 — 스테이지 순서 ↔ 씬 id 분리 (재배치 용이, 사용자 결정 2026-06-09)

**문제**: 현 구조는 *캠페인 순서 = 씬 id = 세이브 키*가 한 덩어리(`Stage%02d` + `load_next=id+1` + 언락 `N-1`). 스테이지를 챕터 간 재배치/조정하려면 파일을 재번호해야 하고 테스트·배선이 줄줄이 깨진다(§4 리스크).

**해법**: **"캠페인 위치 → 씬 id" 매핑 계층(매니페스트)을 도입**해 둘을 분리한다.
- **씬 id** = 레벨의 *불변 정체성*. `StageNN.tscn` 파일 번호 = 그 레벨의 영구 id. 한 번 저작하면 절대 안 옮긴다(예: bridge 레벨은 영원히 `Stage03.tscn`/scene_id 3). 테스트는 *씬 경로*로 참조하므로 안 깨진다.
- **캠페인 순서·챕터 배치** = 매니페스트 *배열* 편집으로 결정. 재배치 = 배열 원소 이동(파일 rename 0건).

**리소스 설계** (`scripts/core/CampaignManifest.gd` + `data/campaign_manifest.tres`):
```gdscript
class_name CampaignManifest extends Resource
# chapters[c] = { "title": String, "theme": String, "stage_ids": Array[int] }
#   stage_ids = 그 챕터에 들어갈 씬 id들의 "순서대로" 나열 (재배치 = 이 배열 편집)
@export var chapters: Array[Dictionary] = []
```
파생 헬퍼(단일 SoT): `ordered_stage_ids()`(전체 챕터 평탄화=캠페인 순서) · `chapter_of(scene_id)` · `next_stage_id(scene_id)`(없으면 0=마지막) · `position_of(scene_id)`(전역 1..N) · `stage_ids_in_chapter(c)` · `chapter_count()`.

**통합 지점** (Phase A에서 SceneFlow/SaveData 코어 변경 — 기존 하드닝 유지하며 SoT만 교체):
- **SceneFlow**: `PUBLISHED_STAGE_IDS` = (씬 파일 존재) ∩ (매니페스트에 등재) — *menu_layout.available 대신 매니페스트 등재가 published 게이트*. `LAST_STAGE_ID` = `ordered_stage_ids().back()`. `load_next_stage()` = `manifest.next_stage_id(current)`(±1 산술 폐지). fail-closed(매니페스트 누락/무효 시 캠페인 닫기)는 기존 정책 계승.
- **SaveData 언락**: scene_id로 키 유지(불변). `is_unlocked(scene_id)` = *매니페스트 순서상 첫 스테이지거나, 직전 스테이지가 cleared*. 직전 = `ordered_stage_ids()`에서 한 칸 앞(±1 산술 아님). → 얇은 `Campaign` 헬퍼(autoload 또는 static)가 매니페스트+SaveData를 합성해 ordering/unlock 파생을 제공(SaveData는 순수 저장 유지).
- **챕터 언락**: 챕터 N = 직전 챕터 마지막 스테이지 cleared 시 해제(매니페스트 챕터 경계로 도출).
- **menu_layout 대체**: 기존 `MenuLayout`(10슬롯 평면)은 매니페스트가 **포섭**(챕터 그룹 + 순서 + published 등재). Phase A에서 매니페스트로 이관, `MenuLayout`/`MenuLayoutResourceTest`는 매니페스트 기반으로 교체 또는 폐기.

**효과**: §4 재배치 맵의 "재번호"가 사라진다 — S1~S9는 *현재 씬 id 그대로 두고*(Stage01~09.tscn 불변), 매니페스트에서 챕터 배열에 원하는 순서로 끼워 넣기만 한다. 신규 스테이지는 *다음 빈 씬 id*로 저작(`Stage10.tscn`~) 후 매니페스트 배열에 배치. **나중 스테이지 분배·순서 조정이 배열 편집 한 번**으로 끝난다.

> ⚠ **§5.1·§5.2는 §5.0(매니페스트)이 SoT다 (codex R1 HIGH-2 정정).** 아래는 §5.0 모델 하의 *세부 마이그레이션*이며, 구 "MenuLayout 10→50 확장 / SaveData 선형 언락 / `chapter=(id-1)/10+1` 파생"은 **폐기**됐다(매니페스트가 캠페인 순서·챕터·published를 단일 SoT로 가짐). 캠페인 순서 = 씬 id 결합을 다시 들이지 말 것.

### 5.1 현재 인프라가 그대로 재사용되는 부분 (매니페스트 모델 하)
- **SceneFlow 스캔**: `Stage%02d` 1~99 스캔(파일 존재)은 불변 — Stage11~50 파일만 추가하면 자동 인식. 단 **published 게이트는 `menu_layout.available`이 아니라 §5.0 매니페스트 등재**(`PUBLISHED_STAGE_IDS = 씬 ∩ manifest.ordered_stage_ids`), `LAST_STAGE_ID` = 매니페스트 순서상 마지막 published.
- **SaveData 저장**: scene_id별 `cleared/stars` 저장은 불변(스키마 bump 불요). **언락 파생만 Campaign로 이관**(§5.0) — SaveData는 ordering 무지(ADR 디커플링).
- **별점**: 전역 규칙 — 스테이지 추가/재배치에 무영향.

### 5.2 변경/신설이 필요한 부분 (매니페스트 기준)
1. **menu_layout 폐기 + 매니페스트 이관** (구 "MenuLayout 확장"을 대체). **단일 경로 — 아래 caller/test를 전부 매니페스트로 이동한 뒤** `data/menu_layout.tres`·`scripts/core/MenuLayout.gd` 삭제:
   - `SceneFlow.ensure_stage_scan`(published 계산) · `StageSelect`(슬롯 소스) · `MainMenu._refresh_continue_state`(Continue 가드, published 경유 간접) · 테스트 `StageSelectUnlockTest`/`MenuLayoutResourceTest`/`SceneFlowStageScanTest`.
   - 챕터 *제목/테마*는 매니페스트 `chapters[].title/theme`가 SoT(별도 `ChapterInfo` 테이블 불요).
2. **챕터 선택 화면 신설** (`scenes/ui/ChapterSelect.tscn` + script)
   - 5개 챕터 카드. **챕터 번호 1-based**(codex R1 MED-1). 잠금 = `Campaign.is_chapter_unlocked(ch)`(직전 비어있지 않은 챕터 last cleared). 각 카드에 챕터 누적 별점(`/`스테이지수×3).
   - 흐름: MainMenu → **ChapterSelect** → StageSelect(선택 챕터의 스테이지들) → Stage.
3. **SceneFlow 화면 상태 추가**: `ScreenState.CHAPTER_SELECT` + `go_to_chapter_select()` + `EventBus.request_chapter_select`. StageSelect는 "현재 챕터"(1-based) 컨텍스트를 받는다.
4. **StageSelect 챕터 인식**: 평면 나열 대신 `manifest.stage_ids_in_chapter(현재 챕터)`만 표시(가변 개수). "뒤로 → ChapterSelect".
5. **Campaign 헬퍼**(구 "SaveData 선형 헬퍼" 대체): `chapter_stars(ch)`·`is_chapter_unlocked(ch)`·`next_unlocked_stage()`·`total_stars` — 매니페스트 순서 위 파생(§5.0). SaveData는 순수 저장 유지.

### 5.3 UI 와이어 (텍스트)
```
MainMenu
  └ [모험 시작] → ChapterSelect
                    ├ Ch1 기초    (★ a/30)   [해제]
                    ├ Ch2 건설    (★ b/30)   [Ch1 캡스톤 클리어 시 해제]
                    ├ Ch3 파괴    (잠김 🔒)
                    ├ Ch4 장치    (잠김 🔒)
                    └ Ch5 종합    (잠김 🔒)
        선택 → StageSelect(해당 챕터 10슬롯, 선형 언락) → Stage
```

---

## 6. Phase 분할 (제안 — `execute.py`로 등록)

> CLAUDE.md 규칙: 한 Phase 완료 후에만 커밋, Phase 완료 직전 `/codex:adversarial-review`. 10스테이지를 한 Phase에 담으면 리뷰 단위가 과대 → **챕터를 2 서브-Phase로 쪼갠다**(전반 5 / 후반 5+캡스톤). 정확한 phase 수·메타는 `phases/{task}/metadata.json`이 SoT.

| Phase | 범위 | 산출물 |
|---|---|---|
| **A. 인프라** | **CampaignManifest(§5.0) + 챕터 UI + SceneFlow CHAPTER_SELECT + Campaign 언락 헬퍼 + 매니페스트 기반 published/Next** + 테스트. (menu_layout→매니페스트 이관, 애드온 슬롯 상한·walker 경사 보행은 확인만) | 매니페스트 배열로 챕터·순서가 결정되는 50스테이지/챕터 골격이 동작(미등재 슬롯 잠김). **스테이지 재배치 = 배열 편집** 가능 상태 확보 |
| **B1. Ch1 전반** | Stage 1~5 (S1·S2 재배치 포함) | climber·blocker·floater 교육 |
| **B2. Ch1 후반** | Stage 6~10 캡스톤 | Ch1 완성 |
| **C1/C2. Ch2** | Stage 11~20 (S3·S4·S5 재배치) | 건설 3종 |
| **D1/D2. Ch3** | Stage 21~30 (S6·S7·S9 재배치) | 파괴 2종 |
| **E1/E2. Ch4** | Stage 31~40 (S8 분리 재배치) | cutter·leaf_jump + 전 스킬 학습 완성 |
| **F1/F2. Ch5** | Stage 41~50 | 종합 마스터리 + 파이널 |

각 스테이지 = `scenes/stages/StageNN.tscn` + `data/stages/stageNN.tres` + `data/stage_layouts/stageNN_layout.tres` + `tests/CampaignSNN*Test.tscn`(클리어 + 핵심 스킬 필수성 negative). 새 코어 메커니즘이 필요하면 그 Phase에서 코어 1건 동반(기존 S4 step-up·S5 ladder 패턴).

---

## 7. 열린 질문 (저작 중 확정)

1. 챕터별 BGM/테마 색 분기 여부(현재 BGM 에셋 미배치 — `audio-polish-deferred`).
2. 신규 코어 메커니즘 예상: 현 10종은 기존 9스테이지에서 코어 완비. 신규 스테이지는 **대부분 순수 데이터 저작** 예상(조합 난이도는 지오메트리로). 단 캡스톤급에서 "운반 중 상승 통행"(CarryingState 미적용 영역) 같은 갭이 재등장할 수 있음 — 발견 시 해당 Phase에서 코어 보강.
3. Ch5 "희소 자원"(48)의 정확한 인벤토리 수치 — 플레이테스트 의존.
4. 레벨툴 애드온(`addons/candyants_level_tool/`)의 슬롯 상한이 50을 견디는지 확인(Phase A).
```
