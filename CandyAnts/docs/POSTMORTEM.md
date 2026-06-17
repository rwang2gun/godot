# 포스트모템: CandyAnts (개발 시작 ~ 최근 빌드)

> 작성일 2026-06-17 · 대상 구간 2026-04-10(Init) ~ 2026-06-09(빌드 1.001) · 212 커밋
> 본 문서는 회고용 서사 기록이다. 결정의 *현재* 상태는 `docs/ADR.md`, 진행 상태는 `phases/*/`·`worklog/`가 SoT다. 여기엔 "어떻게 흘러왔고 무엇을 배웠는가"만 남긴다.

---

## 1. 한눈에 보기

| 항목 | 값 |
|------|----|
| 개발 기간 | 2026-04-10 ~ 2026-06-09 (약 2개월, 실작업 ~5주) |
| 총 커밋 | 212 (feat 63 / fix 32 / docs 27 / chore 26 / phase 40+) |
| GDScript | 96 파일 · 약 10,300 라인 |
| 테스트 | 헤드리스 테스트 267 스크립트 / 200 씬 |
| 발행 스테이지 | 10종 (Stage01~10) |
| 스킬 | 11종 구현 (Climber/Floater/Builder/Basher/Digger/Cutter/SandMound/LeafJump/Blocker 등) |
| ADR | 14건 |
| 워크로그 | 게임플레이 세션 11 + codex 협업 세션 16 |
| 현재 빌드 | 웹 1.001 (itch.io zip), Android 디버그 APK |
| 현재 상태 | campaign-50(5챕터×50스테이지) 재설계 Phase A 완료, 콘텐츠 저작 진행 중 |

**한 줄 요약**: 3D 전투 프로토타입을 접고 "레밍즈 × 사탕 운반"이라는 2D 퍼즐로 피벗, **docs-driven + Phase 분해 + codex 적대적 리뷰** 파이프라인 위에서 1인 개발로 플레이 가능한 10스테이지 빌드까지 도달했다. 강점은 규율과 검증, 약점은 *프로세스 자체의 잦은 재설계*와 *디바이스 간 동기화 누락*이었다.

---

## 2. 타임라인 — 5막 구조

### 막 0. BattlePrototype (2026-04-10 ~ 04-14) — 폐기된 출발점
3D 액션 전투 프로토타입으로 시작. State 10종, InputManager, SpringArm3D 카메라까지 갔으나 4월 중순 중단. 약 3주 공백 후 완전히 다른 게임으로 피벗.
- **회고**: 이 코드 자산은 `ADR-001`에 따라 **공유 불가**로 판단되어 사실상 버려졌다. 다만 "State 머신 + InputManager"라는 *설계 감각*은 CandyAnts 개미 상태머신으로 이어졌다. 버려진 프로토타입이 0의 가치는 아니었다.

### 막 1. CandyAnts 셋업 & MVP 코어 (2026-05-07 ~ 05-10)
프로젝트를 `BattlePrototype/` 하위로 정리하고 CandyAnts를 신규 셋업. 이 5일이 **프로젝트의 DNA를 결정**했다.
- docs-driven 워크플로우 + 자동 검증 가드 도입
- MVP를 11개 Phase로 분해, `execute.py` 상태 관리
- `/codex:adversarial-review` 게이트 + sweep 루프 표준화
- Phase 1~7: bootstrap → stage1-core → builder → blocker → input foundation → game-flow → pad-cursor
- 첫 sweep 버그들 등장: carrying state 유실, blocker bounce 비결정성(여러 번 재수정)

### 막 2. UI/아트/입력 레이어 (2026-05-16 ~ 05-25)
Phase 8~20. 게임을 "보이고 만질 수 있게" 만든 구간.
- 치비 캐릭터·캔디 스프라이트, codex painterly 배경, 쿠키 타일
- 스킬 토글 툴바 + 커스텀 마우스 커서, 한국어 i18n
- 레벨 에디터 v0 (map-editor codex 트랙 시작)
- **Phase 14가 최대 난관**: mechanic-adaptation-traits(Climber/Floater)가 codex 리뷰 Round 1~4를 돌며 `wip` 커밋만 7개. 방향 잠금·stall 테스트·mantle 진입 게이팅을 반복 수정.
- Phase 14~20을 "옵션 B"로 재설계 (PROPOSAL + MIGRATION_PLAN 2개 문서 산출)

### 막 3. 지형 시스템 대수술 (2026-05-26 ~ 06-01)
"보기엔 되는데 구조가 안 맞는" 문제를 정면돌파한 구간. **가장 많이 갈아엎은 곳**.
- 3-tier 지형(surface/under-surface/interior) 도입 → Stage 2,3 확장
- 리마스터 타일 텍스처 + StageLayoutBuilder 시각 레이어 재설계
- 모래 쌓기를 정사각 타일 → 지형 통합 막대과자 사다리로 교체
- **skill-tile-surface 트랙을 통째로 revert**: `revert-excavation-surface-caps` → `remove-surface-tier`. 한 번 만든 추상화를 도로 걷어냄.
- Stage 3 헤드리스 무한루프 버그 해결

### 막 4. 캠페인 콘텐츠 폭발 (2026-06-02 ~ 06-09)
하루 10~25커밋의 고밀도 구간. 게임이 "게임"이 된 시기.
- **S1~S10 정식 저작** (LEVEL_REDESIGN_STATUS 세션 1~11 핸드오프 누적)
- 각 스테이지가 새 메카닉 코어를 동반: 계단 보행등반, 사다리 수직통행, 불괴 cookie, basher 수평통로, cutter flood-fill, 물 표류(swim)
- 스킬 발동을 "설치형 표지판" 패러다임으로 통일 (F-12 ~ F-18)
- 어포던스/글로우/끈끈이 UX 폴리싱 (new-user-onboarding 트랙)
- **SFX 시스템**: 절차 합성(ADR-011) → 즉시 Kenney CC0로 교체(ADR-012) → BGM(ADR-013)
- 웹 빌드 + Android APK export
- **campaign-50 재설계 착수**: CampaignManifest로 순서/챕터를 씬 id에서 분리(ADR-014)

---

## 3. 잘된 것 (What Went Well)

### ✅ 검증 문화 — 테스트가 1급 시민
267개 헤드리스 테스트 스크립트는 1인 프로젝트로는 이례적이다. 거의 모든 메카닉 변경이 회귀 테스트를 동반했고, `tests/`가 코드베이스에서 churn 1위(1051)였다. "S5 마리수 교정", "K-10 stale 드라이버 해소" 같은 항목이 *테스트가 잡아낸* 결함이다.

### ✅ docs-driven + ADR — 결정의 추적성
14개 ADR이 *왜* 그렇게 했는지를 남겼고, 특히 ADR-011→012, ADR-007→010처럼 **superseded 관계를 명시**해 "왜 갈아엎었는지"까지 보존했다. 미래의 자신(또는 AI)이 컨텍스트를 잃지 않는 구조.

### ✅ 누적형 빌드 (ADR-008) — 항상 플레이 가능
Stage 1을 스킬 0개 튜토리얼로 두고 매 빌드가 이전을 깨지 않게 쌓았다. "회귀 = 코어 침범 신호"라는 원칙이 실제로 작동해, 새 메카닉이 기존 스테이지를 깨면 즉시 감지됐다.

### ✅ 트랙 분리 — 게임플레이와 툴링의 직교
맵 에디터·스프라이트 폴리싱 같은 장기 작업을 `codex-worklog/<track>/`로 분리(16세션)해 게임플레이 Phase 흐름을 오염시키지 않았다. codex에게 위임하고 STATUS.md로 SoT 관리한 협업 모델이 효과적이었다.

### ✅ 인터페이스 먼저, 구현 나중 (ADR-011의 실현)
SFX를 "절차 합성으로 일단 가청 확보 → 나중에 실제 음원으로 교체"한 사례는 *교체 가능 인터페이스* 약속이 실제로 게임 로직 0줄 수정으로 실현된 모범 사례다.

---

## 4. 어려웠던 것 (What Went Wrong)

### ⚠️ 프로세스 자체를 너무 자주 재설계했다
가장 큰 비용은 게임이 아니라 **하니스(개발 절차)에 들었다**.
- `Harness_Refine_Plan` v1 → v3 (절차 자체를 3번 개정)
- game-flow plan **v1~v5** (CLAUDE.md가 직접 증언: *"무제한 재리뷰 → 라운드 폭증 + usage limit 소진"*)
- adversarial-review 정책을 2026-05-09 → 05-25 두 번 갱신 (단일-shot 중단이 너무 빡빡해 3-round cap으로 완화)
- **교훈**: 좋은 프로세스를 *찾는* 비용이 컸다. 결국 "plan stage 3-round cap + impl stage clean까지 반복"으로 수렴했지만, 거기 도달하기까지 여러 Phase가 plan 재작성에 소모됐다.

### ⚠️ 만들고 바로 갈아엎기 (Build-then-Replace)
- **skill-tile-surface 트랙 전체 revert**: surface-tier 추상화를 만들었다가 2일 만에 `remove-surface-tier`로 철거.
- **SFX 절차 합성**(Phase 21)을 Phase 22에서 즉시 폐기. ADR-011은 의도된 임시였지만, 합성 코드를 짜고 테스트까지 붙인 뒤 버린 건 사실.
- **DistributorSkill 은퇴**, cutter flood-fill → march 재작성, 모래 쌓기 두 번 교체.
- **회고**: 누적형 빌드(ADR-008)가 "인터페이스를 미리 잡아야 함"을 요구했는데, 지형/스킬 쪽은 인터페이스를 *충분히 탐색하기 전에* 구현으로 들어가 되돌리는 일이 잦았다. 코어 메카닉은 종이 프로토타이핑이 더 쌌을 것.

### ⚠️ Phase 14 — 한 Phase에 4 라운드가 갈렸다
mechanic-adaptation-traits 하나가 `wip` 커밋 7개 + codex Round 1~4를 소모했다. 방향 잠금·stall·mantle 진입이 서로 얽혀 한 번에 안 잡혔다. **교훈**: Climber+Floater+Blocker 상호작용처럼 *상태 전이가 교차하는* 메카닉은 Phase를 더 잘게 쪼갰어야 했다.

### ⚠️ 헤드리스의 사각지대
`--headless`가 셰이더 GPU 컴파일·tween 시각·오디오 가청을 검증 못 한다는 걸 **반복해서 다시 배웠다**(F-20 글로우, F-21 땀방울, ADR-012 jingle 적합성). 비-headless 실렌더 캡처가 필요한 항목을 매번 사후에 깨달았다.

### ⚠️ 웹 빌드 폰트 두부 (F-22/F-23)
데스크톱 OS 폴백에 가려져 있던 비-ASCII 글리프 두부가 웹에서 한꺼번에 터졌다. fontTools cmap 전수 스캔으로 6종을 뒤늦게 발견. **교훈**: 표시 문자열은 타깃 폰트 cmap 대조를 *CI 가드로* 넣었어야 했다(현재는 1회성 스캔).

### ⚠️ 디바이스 간 동기화 누락 (현재진행형)
다른 디바이스에서 작업한 ~18스테이지 분량이 **어느 원격 브랜치에도 push되지 않았다**(현재 최대: campaign-50-ch1-front 14스테이지). 트랙이 6개로 분산된 구조가 "어디서 뭘 했는지"를 흐리게 만든 부작용. **교훈**: 세션 종료 시 push 체크리스트, 또는 디바이스별 작업 시작 전 `git fetch --all` 강제.

---

## 5. 기술적 결정 회고 (ADR 하이라이트)

| ADR | 결정 | 사후 평가 |
|-----|------|----------|
| 001 | 2D 사이드뷰 | ✅ MVP 도달 속도 정답. 3D 자산 포기는 감수할 만했음 |
| 002 | 4-카운터 ScoreSystem | ✅ "운반 중 영구 손실"을 first-class로 — 클리어/실패 술어가 모호하지 않음 |
| 003 | 명시적 SkillRegistry preload | ✅ "0줄 수정" 약속을 포기한 대신 조용한 실패를 차단. 옳은 트레이드오프 |
| 007→010 | cell 파괴 → StaticBody2D registry | ⚠️ TileMap 레이어 추상화를 포기하고 string kind로 — 타입 안전성 ↓, 하지만 atomic destroy엔 최단 |
| 008 | 누적형 빌드 | ✅ 프로젝트의 척추. 단 인터페이스 선설계 부담을 과소평가 |
| 011→012 | 절차 SFX → Kenney CC0 | ◐ 인터페이스 약속은 실현됐으나 합성 코드는 결국 버려짐 |
| 013 | BGM 시스템 | ✅ SFX 패턴 재사용으로 신규 추상화 0 |
| 014 | CampaignManifest | ✅ "순서=씬id=세이브키" 결합을 끊어 재배치를 배열 편집 1회로 — 재설계의 정답 |

---

## 6. 프로세스 진화

```
2026-05-08  docs-driven + execute.py + codex 게이트 도입
2026-05-09  자체 적대적 리뷰 사이클 정책 추가 (codex 연속 호출 금지)
2026-05-10  Harness Plan v3 — metadata SoT, safe staging
2026-05-09→05-25  adversarial-review 정책 2회 갱신
            └ 단일-shot 중단(너무 빡빡) → plan 3-round cap + impl clean-loop
2026-06-02  codex-worklog 트랙 분리 정착
2026-06-09  campaign-50 — 매니페스트 기반 확장 구조로 전환
```

핵심은 **"규율을 세우고 → 너무 빡빡하면 완화 → SoT를 코드/메타로 수렴"** 의 반복. 최종 형태(plan 3-round cap, impl은 self-review→codex 재리뷰 clean까지)는 효율과 품질의 합리적 절충점에 안착했다.

---

## 7. 핵심 교훈 (Lessons Learned)

1. **프로세스 튜닝에도 예산을 정해라.** 절차 v1~v5 같은 무한 개정은 그 자체가 usage limit을 태운다. "2회 수정 + 1회 검증" 같은 *하드 캡*을 일찍 박았어야 했다.
2. **코어 메카닉은 코드보다 종이가 싸다.** 상태 전이가 교차하는 스킬(Climber×Blocker×Floater)은 구현 전 상호작용 매트릭스를 먼저 그렸어야 Phase 14의 4라운드를 피했다.
3. **헤드리스가 못 보는 3종(셰이더·tween·오디오)은 체크리스트로 못박아라.** 매번 사후에 "아 이건 실렌더로 봐야지"를 재발견했다.
4. **표시 문자열은 폰트 cmap 가드를 CI에 넣어라.** 두부는 항상 다른 환경(웹)에서 터진다.
5. **멀티 디바이스 = push 규율.** 트랙이 많을수록 "안 올린 작업"의 비용이 커진다.
6. **인터페이스 먼저(ADR-011 패턴)는 강력하다.** 단, "임시 구현을 짜는 비용"과 "추상화를 못 잡고 구현부터 하는 비용"을 구분해서 적용할 것.

---

## 8. 미해결 / 기술 부채

- **[현재] 18스테이지 미push 작업분** — 다른 디바이스에 있음, 어느 원격에도 없음. 회수 필요.
- **K-12 잔여** 등 BUGFIX_POLISH_LOG의 Known Issues 항목 (대부분 해소, 잔여는 로그 참조)
- **헤드리스 미검증 튜닝값**: 땀방울 위치(F-21), jingle 승/패 적합성(ADR-012) — 게임 청취/창모드로 미세조정 대기
- **범위 밖으로 미룬 것**: 스테이지별 개별 BGM, 결과화면 덕킹, 볼륨/음소거 UI, 챕터별 카메라 follow·경사 램프
- **string kind 타입 안전성**(ADR-010): "earth"/"plant" 문자열 분류의 타입 안전성 부재

---

## 9. 다음 단계

1. **미push 18스테이지 회수** — 다른 디바이스에서 `git status`/`stash list` 확인 → push → 머지
2. **campaign-50 Phase B** — 5챕터×50스테이지 콘텐츠 저작 (인프라는 Phase A 완료)
3. 회수한 스테이지를 CampaignManifest 배열에 append (ADR-014 누적 확장 경로)
4. 헤드리스 미검증 튜닝값 일괄 창모드 검수 1회
5. BGM/오디오 폴리싱 잔여 (클리어 징글 적합성 등)

---

*이 포스트모템은 git 히스토리(212커밋)·ADR(14건)·BUGFIX_POLISH_LOG·LEVEL_REDESIGN_STATUS·worklog(27세션)를 1차 자료로 작성됨.*
