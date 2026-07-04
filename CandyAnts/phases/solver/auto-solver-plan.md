---
name: auto-solver
duration_estimate: 28800
verify: python scripts/run_test.py tests/DeterminismReplayTest.tscn && python scripts/run_test.py tests/DeterminismSpawnScheduleTest.tscn && python scripts/run_test.py tests/SkillMetadataDriftTest.tscn && python tools/solver/try_solve.py harness-test && python tools/solver/try_solve.py selftest && python tools/solver/analyze.py --verify && python tools/solver/try_solve.py diverse-verify && python tools/solver/try_solve.py rediscover-verify
large_change_ok: false
sot: phases/solver/auto-solver-plan.md
sot_aux: [scripts/core/SimConfig.gd, scripts/core/StageRunner.gd, scripts/core/SceneFlow.gd, scripts/core/ScoreSystem.gd, scripts/ant/Ant.gd, scripts/world/Home.gd, scripts/core/AntSpawner.gd, scripts/ui/SkillToolbar.gd, scripts/core/SkillRegistry.gd, scripts/core/SkillApplier.gd, scripts/core/PlanRunner.gd, scripts/core/SolverCapabilities.gd, scripts/run_test.py, scripts/run_plan.py, tests/SolverHarness.gd, tests/PlanReplayHarness.gd, tests/PlanReplayHarnessTest.gd, tests/SkillMetadataDriftTest.gd, data/solver/capabilities.tres, tools/solver/solve_spike.py, tools/solver/analyze.py, tools/solver/try_solve.py]
---

# 트랙: 스테이지 자동 솔버 → 레벨 생성 (auto-solver)

## 문서 구조 (리뷰·구현 범위)
이 문서는 **3층**이다. 적대적 리뷰와 구현은 *확정* 층만 대상으로 한다 — 로드맵은 방향 맥락이며 **feasibility 미검증을 결함으로 보지 않는다.**
- **비전(방향, 미확정)**: 북극성 + 비전 결정 D8~D9. "우리가 향하는 곳"이지 확정 범위 아님.
- **확정·완료(리뷰·구현 통과)**: 결정 D1~D7 + **Phase 0·1·2·3a**. falsifiable acceptance 충족.
- **강제 종료(2026-06-24, 사용자)**: **Phase 4(전술 라이브러리 — 속도 위한 전이)**. 4a 실측이 boost를 falsify + pruning-for-speed가 incompleteness 산물로 판명 → 속도 가설 기각. 본문 §Phase 4 = TERMINATED 배너(음성-입증 이력 보존). 살아남은 자산(볼트=해 설명 어휘)은 Phase 5로 이관.
- **확정·진행 중(in-track 현재)**: **Phase 5 — 솔버 고도화 및 재설계**. 솔버 가치를 *속도*가 아닌 **다양-해 발견 + 풀이법 보고서(designer-in-the-loop)**로 재정의. Phase 0~2 자산 위에 얹는 재설계. Item 1(배치/전략 축) 완료·게이트 그린.
- **확정·진행 중(병행 실험 트랙)**: **Phase R — 정식 RL 솔버**(2026-06-24 사용자 패러다임 결정). 목적=학습/실험 그 자체. Phase 5 휴리스틱 트랙과 코드·게이트 커플링 0으로 병행. 환경 spike 완료(`f637a24`) → R0 완료(S11 3/3 오버핏 `d7d3352`, S12 stretch FAIL `dc68a47`) → **R1 완료**(S12 2/3 seed `431fdd6` + impl 사후 리뷰 R6 approve, hot-fix 5커밋) → 스윕 S20~S25 취소(사용자, curriculum 전제) → **R2(영속 학습: 체크포인트+스테이지-불변 정책+curriculum+cell-target)가 설계 대상**(§R2, 사용자 지시 2026-07-04: 가중치 저장/로드 필수).
- **트랙 밖(별도 브랜치 · 다운스트림)**: (구 Phase 5)감사 오라클·(구 Phase 6)생성. 2026-06-20 사용자 결정 — 생성은 솔버 역할이 아니라 **솔버 산출(다양-해·풀이법 보고서)을 참조하는 별개 소비자**. in-track Phase 5가 "5" 슬롯을 차지하므로, 이 둘은 번호 없는 다운스트림으로 격리.

## 비전 / 북극성 (방향 — 확정 범위 아님, 사용자 정렬 2026-06-18)
**다양하고 비자명한(non-trivial) 레벨을 자동 생성**한다. 솔버는 그 자체가 목적이 아니라 **레벨 품질을 판정하는 적합도 오라클(fitness oracle)**이다.
- 동기: LLM(=Claude)에게 레벨을 맡기면 **풀이 역학 모델도 품질 기준도 없어** 단층·트리비얼 레벨만 나온다. 퍼즐(=올바른 도구를 올바른 타이밍·위치에 써야만 풀리는 비자명함)을 만들려면 **솔루션 공간을 이해**해야 하고, 이 트랙이 그 결핍(도구별 올바른 사용·난이도 판단)을 메운다.
- **정직한 경계**: 오라클은 *풀림·비자명·난이도·도구필요성·정합성*은 보장하지만 그 너머의 *재미/미감*은 지표로 다 못 잡는다. 이 시스템은 **바닥을 확실히 올리고**(트리비얼·단층 박멸, 목표 난이도 적중) 다양성의 큰 부분을 자동화하되, 최상급 디자인은 사람 큐레이션이 낫다. 생성 가설("학습→다양 생성")은 **가정하지 않고 일찍 실증**한다(Phase 6a).

이 문서는 plan SoT. 게임플레이 phase와 직교한 **툴링 트랙**이고, 산출 코드는 Godot 컨벤션대로 `scripts/`·`tests/`·`tools/`에, 트레일은 `codex-worklog/solver/STATUS.md`에 누적한다.

## 트랙 범위·게이트 갱신 (2026-06-20, 사용자 정렬)
**① 트랙 범위 축소 — Phase 5~6은 별도 브랜치.** 솔버의 책임 = **학습 결과(오라클) 생산**(풀이가능성 +
난이도 + 전술 라이브러리). 자동 레벨 생성은 솔버의 역할이 **아니며**, 구현 시 솔버의 학습 결과를 *참조하는
별개 시스템*이다. 따라서 Phase 5(감사 오라클)·Phase 6(생성)은 auto-solver 트랙에서 분리해 **별도 브랜치**로
진행한다. 본 트랙 범위 = Phase 0~5(솔버 산출 생산까지). **Phase 4는 강제 종료**(속도 가설 기각, 2026-06-24)되어,
생성기가 참조할 핵심 산출은 **Phase 5(다양-해 + 풀이법 보고서)**로 이관. 고도화 방침: **실제 레벨(미검증 스테이지)을
솔버가 풀어보며 함께 개선**(현 검증 범위 = S1~S4·S11~S17, 잔여 = S18·Ch2 sand_mound 계열).

**② 게이트 신뢰도 보강 — false-green 제거 + try_solve front-door.** 직전 게이트 약점: `PlanReplayHarnessTest`
(멀티런, >18000f 필요)를 bare `run_test.py`로 돌리면 `--quit-after` 안전망이 exit 0(=PASS와 동일)으로 끝나
**타임아웃이 통과로 위장**됐다(실측: 게이트-기본 호출이 ⑤에서 잘려도 exit 0). 신뢰도 문제라 해소.
- **분리 원칙(사용자)**: `run_test.py`는 **단일 테스트 씬 러너**로 기능 유지(솔버 전용 플래그 금지). "스테이지
  풀이/실행"은 **`tools/solver/try_solve.py`**(통합 front-door)로 분리.
- **try_solve.py** = replay/selftest/search/harness-test 단일 진입점. replay·selftest는 기존 `run_plan.py`,
  search는 `solve.py` 구현을 **import-위임**(동작·결정론 불변). 신규 `harness-test`는 `PlanReplayHarnessTest`를
  **exit-code가 아니라 PASS 마커로 판정**(+`--fixed-fps 60`·넉넉한 budget) → 안전망에 잘려 exit 0이어도
  마커 없으면 FAIL. **false-green 구조적 불가**. (가드 실증: budget=2000 축소 시 exit 0이지만 try_solve가 FAIL 반환.)
- **게이트(verify) 재구성**: Determinism×2 + SkillMetadataDrift는 run_test 유지(단발, 안전망 무관) /
  PlanReplayHarnessTest → `try_solve.py harness-test` / `run_plan --selftest` → `try_solve.py selftest`.
  전체 그린 재확인(261s, 회귀 0). `run_plan.py`는 back-compat로 유지(try_solve가 import).

## 핵심 결정

> **확정 결정 = D1~D7** (리뷰·구현 대상). **비전 결정 = D8~D9** (로드맵, 증거 후 재계획).

### 확정 · 토대 (D1~D4, 2026-06-18 초기 정렬)
- **D1 · 시뮬레이션 코어 = 실제 엔진 인-더-루프.** 별도 경량 모델을 재구현하지 않고 **진짜 Godot 게임을 헤드리스로 돌려** 시뮬한다. 충실도 100%, 스킬/상태 추가 시 효과 자동 동기화. 속도는 트리거-추상 행동공간으로 탐색량을 줄여 상쇄.
- **D2 · 빌드 순서 = 단계별 단독 가치.** 결정론 게이트 → 하니스/능력명세 → 탐색 → 인간-타당성/난이도 → 학습 → 감사 오라클 → 생성. 각 단계가 단독 검증 가능.
- **D3 · 행동공간 = 트리거-조건 단위(프레임-정확 아님).** 기존 `CampaignS11ClearTest`의 *"최전방 walker가 col20 도달 시 blocker"* 추상을 일반화. 후보가 수십~수백 개로 떨어져 인-더-루프 탐색이 현실적.
- **D4 · 정답 기준(ground truth) = 솔버가 실제 인벤토리로 달성하고 무수정 게임 코드(`StageRunner._conclude_stage`)가 판정한 클리어.** 기존 드라이버·주석·레벨 데이터의 가정은 신뢰하지 않는다. 비순환: verdict를 하니스가 아니라 **게임 본체가 emit**.

### 확정 · 심화 (D5~D7, 2026-06-18 심도 논의)
- **D5 · 타이밍 = 행동공간·난이도의 1급 차원.** 같은 스킬·같은 좌표라도 **언제** 쓰느냐로 성패가 갈린다(손코딩 좌표 드라이버가 11~18에서 실패한 근본 원인). 행동공간 트리거 어휘에 **타이밍**을 넣는다: `nth_by_spawn(i)`(어느 개미), 사건 기반(`at_frame`/`active_ants_le`/`picked_ge`/`ant_reaches_x`의 K번째), 개미 상태 순간(`ant_at_cliff`/`ant_on_wall`), 상대 타이밍(`<사건> 후 d프레임`), 프레임-윈도우 스윕.
- **D6 · 반응-윈도우 인간타당성 = 정합성+난이도의 척추.** (현재 게임에 **일시정지/슬로우 없음** → 실시간 입력 전제.)
  - **반응 윈도우** = 어떤 필수 명령에 대해 *그래도 클리어되는 (프레임·위치)의 연속 구간*. 경험적으로 스윕해 측정(게임 특유 역학까지 반영 = ground truth).
  - **기계 보정**: 솔버는 1프레임 윈도우도 맞추므로 "클리어함"으로 끝내지 않고 **윈도우 폭을 인간 임계 `T_human`과 비교**. 필수 명령 중 하나라도 윈도우 < `T_human` → **정합성 오류**(기계만 가능 = 플레이 불가, 재설계 신호). `T_human`은 놀란-반응이 아니라 **예측 실행 정밀도**(더 빡빡). 입력 행위 비용(스킬 선택+개미 탭)·**공간적 조준 난이도**(움직이는 무리 속 특정 개미 탭)도 윈도우에 반영.
  - **난이도 정의**: *레벨 난이도 = "가장 여유로운(=가장 쉬운) 유효 해법"의 가장 빡빡한 필수 윈도우.* → 솔버는 아무 클리어가 아니라 **max-margin 해**를 찾고, 그 해의 최소 윈도우가 난이도. 인간 임계 넘는 해가 0이면 = 플레이 불가.
  - 난이도 척도 = **절대·등급별**(1성/3성 분리, 전 레벨 비교가능 — 생성 채점에 필수).
- **D7 · 자동 동기화 = 솔버는 게임 지식을 하드코딩하지 않는다.** 게임-특화 지식은 세 출처에서만:
  1. **실엔진 인-더-루프**(D1) — 효과·`can_apply`·판정.
  2. **선언적 능력 명세** — 엔진이 코드로만 아는 걸 솔버가 읽게 노출. **스킬별 메타데이터는 스킬 자신에 선언**(self-describing: 타겟 방식 ant/cell, 어포던스 힌트 → `SkillRegistry`로 generic 열거). **전역 기능(pause/slow/입력수단/`T_human`)만 작은 별도 config**(`data/solver/capabilities.tres`).
  3. **학습된 전술 라이브러리**(D8).
  - **기존 하드코딩 맵 직시 (R1-HIGH-2)**: 현 코드는 `SkillRegistry.SKILL_SCRIPTS`(preload 배열)와 `SkillAffordance.SKILL_CATEGORY`(카테고리 맵)에 **신규 스킬마다 수동 1줄**을 요구한다. 자동 동기화 불변식을 정확히 진술하면 — **솔버-side 코드는 불변**(런타임 `SkillRegistry`라는 단일 권위 뷰에서 generic 열거)이고, 신규 스킬은 *레지스트리 등록 + 자기완결 메타*를 갖되 `SkillAffordance` 카테고리는 그 메타에서 파생/종속된다. **drift 가드 테스트**(`SkillMetadataDriftTest`, Phase 1)가 "등록·스테이지 스킬의 메타 완전성 + 솔버 열거==레지스트리"를 강제해 엔진/UI/솔버 3자 간 silent desync를 차단한다. → "솔버 코드 불변 + 게임-side 단일소스/가드"가 정확한 불변식(과거 "1항목"은 부정확).
  - 예: 미래에 pause 추가 → config flag → 난이도 모델이 반응-윈도우에서 계획-복잡도로 자동 전환(솔버 코드 불변).
### 비전 결정 (D8~D9, 로드맵 — 증거 후 재계획)
- **D8 · 누적 학습(전술 라이브러리, CBR/EBL)으로 스테이지마다 같은 시행착오 반복 금지.** (D2의 "백지 탐색"을 뒤집음.) 한 레벨을 풀면 해법을 *국소 기하+타이밍*으로 일반화한 전술로 저장 → 새 레벨에서 매칭·시드 → 롤아웃 급감. ML 가중치가 아니라 **구조화 사례 베이스**(해석가능, 난이도·스킬용법 설명 필요). ML은 나중 옵션(priors 대체).
- **D9 · 최종 소비자 = 레벨 생성(북극성).** 솔버+난이도+학습 = 적합도 오라클. 생성은 **생성-후-검증**(후보 레벨 → 오라클 채점 → 트리비얼 거부·난이도/도구필요 선택; 확신 높음)과 **전술 구성적 생성**(전술로 흥미 상황을 의도 배치; 업사이드·불확실)로 실현. 둘이 같은 토대를 써서 헛수고 없음. **처리량(속도)이 1급 제약** → 라이브러리의 탐색 가속이 *필수*.

## 진단 결과 (조사 2026-06-18, 코드 인용)
- **로직 결정론적**: 게임플레이 스크립트에 `randf/randi/randomize` 0건.
- **결정론 누수 = 게임플레이 시계**(스폰 grace 벽시계·스폰/리스폰 Timer·타임아웃 `_process` 누적) → Phase 0에서 물리-프레임화(완료).
- **무관(확인만)**: `PlantDebris.randf_range`는 시각 파편 전용. `InputRouter`/`SfxPlayer` 벽시계는 입력 디바운스·오디오(솔버는 입력 우회·헤드리스 무음).
- **이동은 delta 적분**, 헤드리스 `--fixed-fps 60`이면 delta=1/60 고정 → 재현 가능.
- **스킬 적용 경로**: `SkillToolbar._apply_skill`가 UI/SFX/terrain과 엉켜 헤드리스 직접호출 불가 → `SkillApplier` 추출 필요(Phase 1).
- **헤드리스 하니스 기존재**: `run_test.py` + `CANDYANTS_SAVE_PATH` pid 격리 → 병렬 안전.
- **Spike 실증 (2026-06-18, 상세 STATUS.md)**: `tests/SolverHarness.gd`(blocker 전용 플랜 리플레이) + `tools/solver/solve_spike.py`(랜드마크 후보 + 병렬 beam + 국소 정밀탐색)로 **S11 자동 클리어 재발견**(탐색 기계 검증) + **S12 자동 클리어 발견(saved 5/5)** — 손드라이버가 못 풀던 레벨을 솔버가 풀어 D4·접근 전체를 실증. 교훈: height-only 휴리스틱은 왕복을 가지치기 → **픽업+home 신호 필요**(D6 윈도우 측정의 전조); 거친 격자의 마지막 한 칸은 **국소 정밀탐색**이 닫음(D6 윈도우 스윕의 원형).

## 미정 파라미터 (기본값 + 캘리브레이션, Phase 3·5에서 확정)
- `T_human` 값·티어(제안: 편안 ≥~0.30s / 어려움 ~0.15s / 기계전용 <~0.10s), 입력수단별 분리 여부 → 사용자가 몇 레벨 라벨링해 가중치 보정.
- 다중 명령 난이도 합산식(최소 윈도우 vs 결합·손부담 포함).
- 인간 모델: 이진 임계 vs 확률(지터 σ → "몇 % 플레이어가 깸").
- 학습 코퍼스(캠페인 50?)·라이브러리 영속성(커밋 산출물)·게임 밸런스 변경 시 무효화 정책.

---

## Phase 0 — 결정론 + 속도 게이트 ✅ 완료 (2026-06-18)
같은 입력 → per-frame 동일 결과 보증 + 헤드리스가 실시간보다 충분히 빠른지(생성 처리량 전제). **완료**: `SimConfig` autoload(opt-in 결정론, 기본 동작 불변) + 게임플레이 시계 물리-프레임화 + `DeterminismReplayTest`(per-frame 일치) + `DeterminismSpawnScheduleTest`(스폰 드리프트 0) + 속도 게이트(`--fixed-fps`에서 ~24x 실시간, 롤아웃당 ~0.3s). 신규 회귀 0. 적대적 리뷰 R1→R2 approve. 상세: `codex-worklog/solver/STATUS.md`, `phases/solver/reviews/phase0-impl-review.md`. 커밋 `97ea271`/`985c7ae`/`f61704a`.
> 생성이 북극성이 되며 **속도가 1급 제약으로 승격**(D9): 후보 레벨 대량 채점 → 라이브러리 가속(Phase 4)·병렬이 더 중요.

## Phase 1 — 리플레이 하니스 + 능력 명세 (자동 동기화 토대) · **[확정] ✅ 완료 (2026-06-18, 게이트 그린 + 적대적 리뷰 R9 approve)**
> **산출**: `SkillApplier.gd`(순수 규칙 SoT, toolbar 위임) + 10 스킬 `SOLVER_META`(self-describing) + `SkillRegistry.skill_ids()/solver_meta()`(generic 열거) + `SolverCapabilities.gd`+`data/solver/capabilities.tres` + `PlanRunner.gd`(다중스킬·타이밍 트리거·인스턴스-스코프 verdict·단일활성런·결정론 복원) + `PlanReplayHarness.{gd,tscn}` + `run_plan.py`(--selftest) + `PlanReplayHarnessTest`(① 클리어 ②새인스턴스×2 ③음성 ④재사용+분리+출처 ⑤동시런거부 ⑥재진입거부 ⑦after-by-index ⑧repeat앵커 ⑨deterministic복원 ⑩취소복원) + `SkillMetadataDriftTest`(D7 가드). 골든 5종 `data/solutions/golden/`(S11/S12 클리어=spike 바이트동일 재현, S05 SIGN·S08 DEVICE effect-invariant 충실성, 빈 플랜 음성). **게이트(verify) 그린 + 게임 회귀 0**(S11/S13/sign·device·routing·toolbar PASS). **적대적 리뷰 종결**: codex R1 HIGH→…→R5 HIGH→R6~R8 MED→**R9 approve**(`phases/solver/reviews/phase01-impl-review.md`). 상세: `codex-worklog/solver/STATUS.md`.
### 목표
손코딩 `CampaignSxx*.gd` 드라이버를 **데이터(플랜)** 로 대체하고, 솔버가 게임 능력을 **읽어** 행동공간을 자동 구성하게 한다(D7).
### 작업
- **`scripts/core/SkillApplier.gd` 추출** (D7·CRITICAL-1): 인벤토리 차감 + `can_apply` + 설치 유효성 **순수 규칙**을 `SkillToolbar`의 UI/SFX/terrain 결합에서 분리. toolbar는 SkillApplier 위임 + UI/SFX만 덧붙이게 리팩터. 하니스/PlanRunner는 SkillApplier만 사용 → 규칙 SoT 1곳.
- **스킬 self-describing 메타데이터 + drift 가드** (D7·R1-HIGH-2): `Skill` 베이스/각 스킬에 타겟 방식(ant/cell)·어포던스 힌트 선언. `SkillRegistry`로 generic 열거 → 솔버가 **하드코딩 없이 자동 발견**(spike "blocker" 하드코딩 제거). **기존 하드코딩 맵 종속화**: `SkillAffordance.SKILL_CATEGORY`를 per-skill 메타에서 파생(또는 종속)시켜 단일 권위 뷰로 통일. **`SkillMetadataDriftTest`** 신설 — 등록(`SkillRegistry`)·스테이지 인벤토리에 나오는 모든 스킬이 완전한 솔버 메타를 갖는지 + 솔버 열거 == 런타임 레지스트리 뷰인지 단언, 누락/불일치 시 FAIL. → D7 불변식("솔버 코드 불변; 신규 스킬은 레지스트리 등록+자기완결 메타, drift 테스트가 완전성 보장") 강제.
- **전역 능력 명세** `data/solver/capabilities.tres`: pause/slow 유무·입력수단·`T_human` 티어. 난이도 모델·행동공간이 이걸 읽음.
- **`scripts/core/PlanRunner.gd`**: 플랜(JSON) → `_physics_process`마다 트리거 평가(스코프=활성 스테이지 루트, tie-break `(x, spawn_index, instance_id)`, repeat 규칙) → SkillApplier로 인벤토리-충실 적용 → `EventBus.stage_cleared/failed` 캐치 → 결과 dict. **타이밍 트리거(D5) 지원**: `nth_by_spawn`·`at_frame`·`active_ants_le`·`picked_ge`·`ant_at_cliff/on_wall`·상대지연·K번째. (spike `SolverHarness`를 일반화·다중스킬화한 것.)
- **`scripts/run_plan.py`**: 플랜 파일 → 헤드리스(`--fixed-fps`) 실행, 결과 JSON. `--selftest`(손작성 메커니즘 골든), 배치(씬 reload·상태누수 0).
### Acceptance — **실행 게이트 = 프론트매터 `verify` 단일 필드**(R2-HIGH, execute.py가 실제 실행하는 그것)
> 게이트 invocation 갱신(2026-06-20, §"트랙 범위·게이트 갱신"): 아래 항목의 *검증 내용은 불변*이나
> **호출은 `tools/solver/try_solve.py`를 거친다** — `PlanReplayHarnessTest`→`try_solve harness-test`(마커 판정,
> false-green 제거), `run_plan.py --selftest`→`try_solve selftest`. Determinism×2·SkillMetadataDrift는 run_test 유지.
- `PlanReplayHarnessTest` PASS(+배치 상태누수 0). 다중 스킬 손작성 골든이 게임 verdict대로(`run_plan.py --selftest`).
- `SkillMetadataDriftTest` PASS — 등록·스테이지 스킬 메타 완전성 + 솔버 열거==레지스트리 단언(자동 동기화 D7 강제).
- **Phase 1 완료의 정의 = 위 체크를 `verify` 프론트매터에 *반영*(결정론 테스트 && PlanReplayHarnessTest && SkillMetadataDriftTest && `run_plan.py --selftest`)하고 그 단일 `verify` 명령이 그린.** execute.py·`complete`가 실행하는 건 `verify` 하나뿐이므로(L809) 별도/inert 키를 두지 않는다 — `verify` 갱신 자체가 silent bypass를 막는 강제 계약. (Phase 1 작성 당시 주: `verify`엔 Phase 0만 반영돼 있었고 이 갱신 전엔 Phase 1 미완료였다 — **현재 `verify`는 Phase 0~3a 모두 반영**, 호출은 try_solve front-door, §"검증 방법" 참조.)

## Phase 2 — 탐색 솔버 (경험 생성) · **[근시일 계획] ✅ 완료 (2026-06-20, S11~S14 무힌트 자동 해결)**
> **산출**: `tools/solver/{model,solve}.py`(예측 닫힌-루프 — 베이스라인 관측→진단→개입 제안→엔진 검증, D10) +
> `tests/SolverMetaDump.{gd,tscn}`(D7 메타 브리지) + 스킬 `SOLVER_META.routing/purpose`(D11) + `PlanRunner`
> 궤적 트레이스 확장. **해 4종** `data/solutions/stage{11,12,13,14}.solve.json`: S11(2롤 blocker×1)·S12(11롤
> blocker×3)·S13(26롤 blocker×1+climber×5)·S14(40롤 blocker×3+climber×5), 전부 무수정 게임 verdict
> 100%(D4). **CI 게이트**: selftest(현 호출 `try_solve selftest`, 구 `run_plan.py --selftest`)가 solve.json까지 결정론 리플레이 검증(자동발견 해 회귀
> 방지). cap>10(S12 11·S13 26·S14 40)은 사용자 "해 찾으면 성공" 정책 하 허용. 상세: `codex-worklog/solver/STATUS.md`.
### 목표
스테이지+인벤토리 → **풀이 플랜 탐색**(없으면 "탐색범위 내 미해결"). 산출 = 해 + 탐색 트레이스(학습 원료).
### 설계
- 행동공간 enumeration: 능력 명세에서 스킬 자동 열거 × 대상 select × **타이밍 트리거(D5)** × 지형 랜드마크. 폭발 억제 = 랜드마크·사건 앵커.
- 전략: beam/greedy + rollout, **max-margin 해 우선**(D6 — 가장 여유로운 해). 휴리스틱: 경로 진척·픽업·home 근접·잔여 인벤토리·윈도우 폭. 각 후보 = Phase 1 하니스 실평가.
- 병렬 평가(다중 헤드리스, `CANDYANTS_SAVE_PATH` 격리). 예산/종료 cap. 탐색 순서 고정(결정성).
### 산출
- `tools/solver/solve.py`(오케스트레이터). 출력: 해 플랜 + 별점/saved, 또는 미해결 리포트.
### Acceptance
- 무힌트로 각 스테이지를 실제 인벤토리로 평가 → 클리어 가능하면 max-margin 유효 플랜(게임 verdict 클리어), 불가능하면 "불가" 리포트(D4). S11~S14 동일 잣대.

## Phase 3 — 반응-윈도우 & 인간 타당성 (정합성 + 난이도) · **[3a ✅ 완료 (2026-06-20, codex 14R→approve) · 3b ⛔ DEFERRED (2026-06-20, 실측 증거 — placement max-margin vacuous; Option C 채택)]**
> **3a 완료**: `tools/solver/analyze.py`(최소화 deletion-minimal + 시간 윈도우 at_frame_exact 스윕 +
> sampled 정직표기 + T_human provisional + `--verify` 게이트) + `data/solutions/stageNN.analysis.json`(S11~S14,
> 1-minimal=원해·stage_min 1.35~2.28s 전부 comfortable). 위치 윈도우는 bouncing 개미에 x-스윕이 근본 모호라
> informational `pos_hint`(시간윈도우+trace 파생)로 격하. **게이트 = `analyze.py --verify`(272체크) frontmatter
> 편입·그린**. 적대 리뷰 codex 14R(R1~R13 finding→R14 approve)+자체 15R. 트레일 `reviews/phase03-impl-review.md`.
> PlanRunner 가산①②는 선커밋 `02c2d43`. 상세: `codex-worklog/solver/STATUS.md`.
> **2-층 분리(2026-06-20 사용자 정렬)**: 범위를 **3a(확정·이번 구현 대상)**와 **3b(스케치·증거 후 재계획)**로
> 쪼갠다. 3a = 순수 측정 인프라(최소화 + 윈도우 측정), 캘리브레이션 불요·falsifiable. 3a가 산출한 윈도우
> 폭(초)을 본 뒤 3b를 재계획한다. plan "증거 후 재계획" 철학과 일치. **재계획 결과(2026-06-20, 사용자
> Option A) = §3b**: max-margin **local 대안 해 탐색**만 이번 범위; T_human 티어 보정·절대 난이도 점수는
> difficulty spread 확보까지 **추가 defer**(3a 증거 = S11~S14 전부 동일 티어).
> **v2(2026-06-20, plan-review R1 반영)**: codex R1이 "엔진 무변경" 주장을 반증(C1 f* 미노출 / C2 at_frame
> 재시도 / H1·H2 selector 불안정 / H3 cardinality / H4 max-margin 모순 / M1·M2·L1). → D12를 **엔진 가산
> opt-in 확장**(trace 패턴)으로 정직화. 트레일 `reviews/phase03-plan-review.md`.
> **v3(2026-06-20, plan-review R2+R3 반영)**: report_fired 전용 flag·spawn_index 변환 state 보존·incomplete=게이트 FAIL·cardinality opt-in·cell-bracket 교차검증·per_action.target 통일·baseline 1회 실행(report_fired+trace 동시).
### 목표
기계-클리어를 **인간-타당성**으로 거르고 난이도를 산출(D6).

### 측정 대상 = "발견된 해"(현 solve.json) — max-margin 아님 (R1-H4)
**3a는 현재 `data/solutions/stageNN.solve.json`(Phase 2가 발견한 첫 full-clear 해)의 윈도우를 측정**한다.
D6의 "가장 여유로운(max-margin) 해의 최소 윈도우 = 난이도" 정의는 **대안 해 탐색을 전제**하는데, 현
`solve.py`는 첫 full clear에서 즉시 저장·종료(`solve.py:188,238`)라 solve.json은 max-margin 해가 아니다.
→ 3a 산출은 정직하게 **"이 해의 윈도우 프로파일"**이다. **대안 해 탐색(max-margin local)은 3b**(§3b Option A)
에서 다룬다. 단 **절대 난이도 등급(가장 여유로운 해 기준 1성/3성 분리)은 difficulty spread 확보까지 추가
defer** — 3b도 max-margin을 *전역*으로 주장하지 않고 placement-local로 한정(모순 제거: 3a는 max-margin 미주장).

### 설계 결정 (D12 v3 — 윈도우 측정 = 엔진 가산 opt-in 확장, 트리거 자연축 스윕)
- **"엔진 무변경"은 성립 안 함(R1-C1/C2 직시)** → **엔진 가산 opt-in 확장**으로 수정. PlanRunner에 **trace와
  동형의 opt-in 기능**(plan flag로만 켜짐, 미설정 시 기존 동작·verdict·결정론·바이트동일성 불변)을 2개 더한다.
  Phase 2가 trace를 같은 방식으로 가산 확장한 선례와 동일 패턴(STATUS "PlanRunner 가산 확장"). D10("엔진=
  진실") 위반 0, 회귀 게이트(`run_plan --selftest`·`SkillMetadataDriftTest`·결정론 2종) 그린 유지가 **impl
  입증 대상**.
  1. **(가산①) fired-action 보고**: plan `report_fired:true`(전용 flag; **solve.py 저장 경로는 trace 동반 금지**, analyze.py baseline은 예외적으로 trace 동시 사용)일 때 `SOLVER_RESULT`에
     `fired_actions:[{index,label,skill,target_kind:"ant"|"cell",frame,spawn_index?,target_pos?,target_cell?}]` 포함(ant=spawn_index/target_pos, cell=target_cell — place_on_cell `{placed,cell,reason}`에서; spawn_index는 ant 전용 optional) — 각 액션이 **실제 발화한
     프레임·대상 개미 spawn_index·위치**. analyze.py가 baseline에서 `f*`·대상 ID를 깨끗이 획득(R1-C1·H2
     해소; stdout regex 불요, duplicate climber 5개도 index로 구분). 솔버 산출 안정성: `solve.py._save`는 결과에서 `trace`·`fired_actions` **둘 다 제외**(solve.json 바이트동일 불변, R2-H1).
  2. **(가산②) `at_frame_exact{frame}` 트리거**: `_frame == frame`인 **그 프레임에만** 평가(미충족 시
     재시도 없이 그 액션 영영 미발화). 기존 `at_frame`(>=, 재시도)은 불변 — 신규 트리거 타입 추가(가산).
     R1-C2 해소: 정확 프레임 발화 = 인간의 "한 순간 탭"과 1:1.
- **시간 윈도우 측정 = spawn_index 고정 + at_frame_exact 스윕(통일·1급)**: 각 필수 액션을 baseline fired
  `(spawn_index*, f*)`로 측정한 뒤 **`{target:{...원본 target 필터 보존(특히 `state`; 없으면 `"any"` 명시 — 기본 `"walker"`면 carrying 개미 미선택·S13 깨짐, R2-H2), select:"spawn_index", spawn_index:si*},
  trigger:{type:"at_frame_exact", frame:f}}`로 변환**해 f를 격자 스윕 → **그 개미를 그 프레임에** 명령하는
  시간 윈도우를 정확·재현적으로 측정(R1-H1 selector 불안정 해소 = 고정-ID 측정이 1급 산출). f가 일러 그
  개미가 아직 부적격이면 미발화→클리어 깨짐=하한, 늦어 이미 막힘이면 상한.
- **위치 윈도우(공간 차원, `ant_reaches_x` 한정·보조)**: 원본 트리거 `ant_reaches_x.x`를 격자 스윕 → 위치
  구간 `[x_lo,x_hi]`. baseline trace(cell 변화 시만 기록 = cell-bracket 정밀도)로 그 개미가 x 지나는 frame을 **cell-bracket 교차검증**(프레임 정확 복원 아님; 정밀 필요 시 report_fired를 authority로, R2-M3). **analyze.py baseline은 report_fired+trace를 둘 다 켜 1회 실행**(둘 다 가산 보고 → 게임 거동 byte-identical; analyze는 `_save` 미사용이라 solve.json 무관 — "동반 금지"는 solve.py 경로 한정[R2-H1]). f*·target은 report_fired에서, cell bracket은 trace에서(R3-M1). 위치는 blocker류 보조 차원,
  시간 윈도우가 모든 액션 공통 1급.
- **스윕 가정 검증(R1 의미가정)**: ① 한 액션 축 스윕 중 **다른 액션은 baseline 그대로 고정** = "그 액션
  단독 여유"(크레딧 할당과 정합). ② 윈도우가 **단일 연속 구간이라는 보장 없음** → 거친 격자로 도메인 전체를
  평가해 **비연속(gap) 검출** 시 interval 리스트로 기록(가정 위반 직시). 정밀 스윕은 각 경계 양쪽만.

### 3a · 최소화 + 윈도우 측정 (확정 v3 · 이번 구현)
산출 = **`tools/solver/analyze.py`**(순수 오케스트레이터) + **PlanRunner 가산①②**(위) + 스테이지별
`data/solutions/stageNN.analysis.json`.
- **(A) 최소화 = 1-minimal (R1-H3 정직화)**: 현재 candidate plan에서 액션을 **고정 순서로 하나씩 제거**(제거 확정 시 candidate에서 빼고 진행 — 대체가능 A/B를 둘 다 redundant로 오분류하는 동시제거 함정 회피, **deletion-minimal=1-minimal** 보장)하고 나머지 그대로 `run_plan` 롤아웃 →
  여전히 full clear면 **잉여**, 깨지면 **필수**. 산출 = **1-minimal 플랜**(각 액션이 개별 필수) + 잉여 목록.
  **cardinality-minimal은 1-pass가 보장 못 함**을 명시 — 액션 수 ≤ `MINIMIZE_SUBSET_CAP`(기본 8, 현 최대)
  이고 **`--prove-cardinality`(opt-in·기본 off·verify 미포함)** 지정 시 부분집합 브루트포스(작은 부분집합부터 크기순 조기종료, plan-hash 캐시·`--workers` 병렬)로 cardinality-minimal 승격·증명, 미지정/초과면
  1-minimal로 정직 보고(`minimal_kind:"1-minimal"|"cardinality-minimal"`). 최소 액션 수 = 난이도 "최소 스킬"
  proxy. 액션 간 의존(carry 연쇄)은 제거 시 클리어가 깨져 필수로 잡힌다.
- **(B) 윈도우 측정**: 1-minimal 플랜의 각 필수 액션에 위 D12 스윕(시간 윈도우 폭 초 = 1급; 위치 윈도우 =
  ant_reaches_x 한정). 거친 격자로 경계 괄호+gap 검출, 경계 정밀 스윕(spike 국소 정밀탐색 일반화). **결정론**
  (고정 격자·순서). **스윕 예산 cap**(액션당 롤아웃 상한) 초과 시 `incomplete:true`(하한만) 정직 보고 —
  silent 절단 금지. **cell-target(SIGN/DEVICE) 액션**: cell 고정이라 위치 차원 없음 → at_frame_exact 시간 윈도우만(spawn_index 불요). 현 S11~S14 4해엔 cell-target 필수 액션 없어 실측 대상 외(스키마만 준비, R2-M1 연계).
- **(C) T_human 분류 = provisional (R1-L1 격하)**: 각 필수 액션 시간 윈도우 폭을 `capabilities.tres`
  T_human 티어와 비교 → 티어 분류 + 스테이지 최소 윈도우. 단 현 티어는 **미보정 하드 기본값**이라
  `tier_source:"default_uncalibrated"` 명시 + 최소 윈도우 < 기계전용 임계 = **`provisional_machine_only_flag`**
  (정합성 "오류" 확정 아님 — 최종 판정은 3b 보정 후). 3a는 분류·플래그·리포트만.
- **(D) 리포트**: `analysis.json` = {solution_ref, minimal_plan, minimal_kind, redundant[],
  per_action[{index, label, trigger_axis, target:{kind:"ant",spawn_index,target_pos?}|{kind:"cell",target_cell}, time_window:{lo,hi,width_s,intervals,gaps,incomplete}, pos_window?, tier, provisional_flags}], stage_min_window_s, sweep_meta:{grid,cap,rollouts,domain}}. 콘솔 요약.
- **(E) 게이트 = `analyze.py --verify` (R1-M1 강화)**: 풀 측정은 비싸(액션당 수십 롤아웃) verify에 안 넣고,
  저장된 analysis.json을 재검증: 먼저 **`minimal_plan.actions`↔`per_action` index/label 1:1 coverage**(index 기준 전체 커버리지·duplicate index 0·label 일치·모든 필수 액션 window 존재)를 선검증(버그난 analyze.py의 per_action 누락으로 incomplete 검사 우회 차단, R3-M2), 그 뒤 **경계 주장을 싸게 재검증** — 액션별 **각 interval 내부 1점=clear + 양 끝 밖 1점=fail
  + 각 gap 내부 1점=fail** 리플레이(비연속까지 핀) + 1-minimal 플랜 자체 클리어(D4). `incomplete:true`(cap
  초과) 액션이 필수 액션 중 하나라도 있으면 **게이트 FAIL**(미완 측정을 통과로 위장 금지 — "제외" 아닌 "실패"). 탐색·재현용 `--allow-incomplete`만 incomplete 허용(R2-H3). verify 프론트매터 편입은 **3a 완료
  시**(게이트 그린 후) — Phase 1/2 정책(verify 갱신 자체가 강제 계약) 동일.
- **(F) 직관 대조 = 정보 산출, 게이트 아님 (R1-M2 격하)**: 측정된 S11~S14 스테이지 최소 윈도우 폭 순위와
  **사용자 체감 난이도 라벨을 대조** — Spearman 순위상관·불일치 쌍 수를 리포트에 기록, 불일치 시 `flags`에
  원인 분석. **pass/fail 게이트 아님**(사후 해석 방지). 라벨은 가능하면 **측정 전 pre-register**(사용자가
  S11~S14 난이도 순위를 먼저 제시)해 반증 가능성 확보. 이 데이터는 3b T_human 보정 1차 입력(보정 자체는
  difficulty spread 확보까지 defer — §3b Option A).

### 3b · max-margin 대안 해 탐색 (⛔ DEFERRED — 증거 기반, 2026-06-20 · Option C 채택)

> **⛔ 보류 결정 (2026-06-20, 실측 증거 + 사용자 Option C).** 아래는 placement coordinate-ascent 설계의
> *완성 초안*이고 codex plan-review R1까지 거쳤으나, **구현 전 실측 probe가 핵심 전제를 반증**해 **구현 보류**한다.
> 설계 본문은 미래 재진입(특히 cross-structure 확장) 대비 보존.
>
> **실측 반증 (probe, 엔진 D4, 2026-06-20):** 두 스테이지·서로 다른 binding 타입에서 placement 변형이
> **binding 윈도우를 전혀 못 움직임** — 3a binding이 이미 placement-local max-margin.
> | 스테이지 | binding | 변형(3 knob ×±3셀) | 클리어 | **binding 넓어짐** |
> |---|---|---|---|---|
> | S12 | blocker#2 (81f) | 18 | 9 | **0** (다른 knob·자기 knob 모두 81f 불변) |
> | S14 | climber#3 (86f) | 18 | 9 | **0** (blocker 재배치 간접완화 가설 거짓) |
>
> **근본 원인:** 난이도(binding 윈도우)는 *placement가 아니라 구조/메커닉*이 결정 — carrying 개미 climb 가능
> 구간·blocker 반전 타이밍은 개미 물리가 정하고, 클리어되는 placement 범위(±1~3셀) 안에선 robust. 따라서
> placement-only coordinate-ascent는 S11~S14에서 vacuous(codex R1-H4 "빈 탐색"이 가설 아닌 현실). **3b의 다른
> 축(T_human 보정)도 4개 동일-티어 spread 0으로 막힘.** → **두 축 모두 "4개 동일·유사 스테이지" 제약에 막힌
> 것이고, max-margin/보정에 의미가 생기려면 *다른 구조의 레벨들*이 먼저 필요**(Option C).
>
> **결정 = Option C (사용자):** 3b 보류. **미검증 실제 레벨(S1~S9 재설계·S15~S18·ch2 등)을 `try_solve search`로
> 풀어** difficulty spread + 새 해 구조를 먼저 생성한다. 그 코퍼스가 생기면 3b(max-margin·T_human 보정)가
> 비로소 의미를 갖고, 솔버 일반성도 개선되며(현 휴리스틱은 S11~S14 튜닝), 북극성(레벨 생성 오라클) 커버리지도
> 전진한다. STATUS "고도화 = 실제 레벨 풀기" 경로. **재진입 시 우선 = cross-structure 대안(placement 아닌
> 다른 스킬 multiset)** — placement는 실측상 무효라 그쪽이 진짜 headroom.
>
> 트레일: codex plan-review R1 + probe = `reviews/phase03b-plan-review.md`. verify 프론트매터 무변경(maxmargin.py
> 미구현). 아래 설계는 **참고용 보존**(확정 아님).

#### (보존) 측정 대상 재정의: 발견된 해 → max-margin 해 — *원래 의도, vacuous 판명*
3a는 정직하게 **"발견된 해(solve.json)의 윈도우 프로파일"**만 측정했다(R1-H4: `solve.py`는 첫 full clear에서
종료라 그 placement는 임의 — 최여유 보장 아님). 3b는 D6 정의(*레벨 난이도 = "가장 여유로운 해"의 최소 윈도우*)로
한 발 나아가 **같은 해 구조의 대안 placement를 탐색해 max-margin(가장 여유로운) 해를 고르고, 그 binding 윈도우를
권위 난이도로** 산출한다. 3a "이 해 윈도우 프로파일"을 발판(analysis.json 불변).

#### 정직한 범위 경계 (over-claim 방지 — 3a sampled/pos 교훈)
- **max-margin = "발견된 해 구조의 placement-변형 공간 내 coordinate-ascent local 최적"**, **전역(다른 스킬
  multiset·다른 구조) 최적도 joint-exhaustive 최적도 아님**. cross-structure max-margin·joint 동시 완화는 **명시
  defer**. 근거: 전 구조 열거·joint 곱공간은 intractable, value/cost 빈약. 3b가 답하는 질문 = "이 도구로 이
  레벨을 **가장 관대하게** 푸는 placement는?"(난이도-관련 핵심 질문). 리포트는
  `max_margin_scope:"coordinate_ascent_placement_local"`로 경계 명시 표기(3a `tier_source`/`sampled` 선례).
- **3a 증거 직시(가정 정정)**: binding 액션이 **항상 blocker가 아니다** — S11(blocker `ant_reaches_x ge`)·
  S12(blocker `le`)·S13(blocker `ge`)는 binding=position-triggered blocker지만 **S14 binding=climber#3
  (`picked_ge n=1`, carry, width 1.43s)** 로 **공간축이 없다**. 따라서 "binding 액션의 x-landmark를 직접
  스윕"은 S14에 미적용. → 올바른 모델: **placement-variable 액션(=position-triggered ant-target: blocker류)을
  control knob으로 변형**해 **전 필수 액션의 min-window(binding)를 최대화**. binding 액션 자신이 placement-
  variable이 아니어도(S14 climber) **knob(blocker) 재배치가 궤적 타이밍을 바꿔 climber 윈도우를 간접 완화**
  (S14에서 binding 1.43s가 blocker 재배치로 넓어질 수 있음 — S11~S13는 직접, S14는 간접). 모든 변형마다
  **전 필수 액션 윈도우를 재측정해 min을 취함**(knob 이동이 다른 액션을 더 빡빡하게 만들면 min에 포착).

#### 설계 결정 (D13 — max-margin = placement coordinate-ascent, 엔진 무변경)
산출 = **`tools/solver/maxmargin.py`**(순수 오케스트레이터; analyze.py 기계 재사용 — `Rollouter` 병렬 +
`measure_time_window` + `make_sweep_target`·`sweep_time_plan`) + 스테이지별 `data/solutions/stageNN.maxmargin.json`
(**analysis.json 불변·별 파일** = 3a "발견 해 프로파일" 층 보존, 3b = 권위 난이도 층).
- **(A) seed = 발견 해**: `stageNN.analysis.json`의 1-minimal 플랜 로드(sha256 바인딩). **placement-variable knob
  집합** 식별 = position-triggered ant-target 액션(`trigger.type=="ant_reaches_x"` + `select:max_x/min_x`).
  cell-target(SIGN/DEVICE)·event-triggered(`picked_ge`/`at_frame`) 액션은 knob 아님(placement 축 없음). **seed의
  binding(=전 필수 액션 min-window)을 maxmargin 자신의 격자·cap으로 재측정**(아래 C) → `found_binding`. ⚠
  **apples-to-apples**: `found_binding`은 analysis.json width를 신뢰하지 않고 **maxmargin이 동일 격자/cap으로
  재측정한 값**(analysis.json width는 informational cross-ref). 측정 해상도 차이로 불변식이 거짓 위반되는 것 방지.
- **(B) placement 격자 도메인(R1-H1 구체화)**: knob의 x-landmark 후보 = **baseline에서 그 knob이 실제 발화한
  대상 개미(spawn_index)의 trace traversed x-범위**에서 뽑은 **셀-중심 x 목록**(`measure_time_window`이 쓰는 것과
  동일한 trace 출처). 즉 `model.parse_layout`만으로 "도달가능 셀"이 안 나오므로(parse_layout은 occupied/kinds/
  candy/home만 — codex R1-H1) **개미 trace의 점유 x-범위를 권위**로 삼고, layout 셀-중심으로 양자화 + stage
  bounds clip + 원본 `cmp`·`y_min`·`y_max` 보존(=같은 개미·같은 방향 선택 유지). 후보 목록·해시를
  `search_meta.domain`에 정확 기록(결정론·재현). cap = `MAXMARGIN_PLACEMENT_CAP`(기본값 plan-review 확정).
- **(B') coordinate-ascent over knobs**: seed에서 시작, **고정 순서로 각 knob 1개씩** 위 도메인을 스윕. 각 후보
  변형은 그 knob만 바꾸고 나머지는 현재 best 유지. **min-window가 개선되면 새 best로 채택**(seed에서 단조 비감소)
  → 다음 knob. **`--passes`(기본 1)** = knob 전체 1회 순회(3a deletion-minimal 1-pass와 동형, 결정론·bounded).
  knob 0개(placement-variable 액션 없는 퇴화)면 max-margin=seed(정직 보고, FAIL 아님) — 현 S11~S14는 blocker knob ≥1.
- **(C) 변형 평가 = candidate-local 재발화 필수(R1-H3) + 2단 필터**: ① 각 변형 **1롤아웃 full-clear 필터**(D4,
  `Rollouter` 병렬) — 안 풀리면 탈락. ② **클리어 변형은 반드시 `report_fired+trace`로 재실행해 그 변형 자신의
  `fired_actions`(candidate-local f*·spawn_index)를 먼저 획득** — knob 이동이 downstream(예: S14 `picked_ge`
  climber)을 재타이밍하므로 seed의 f*·spawn_index를 재사용하면 틀린다. **전 필수 액션이 정확히 발화(covered)** 안
  되면 그 변형 탈락(측정 불가). ③ 그 candidate-local target으로 **현 binding 액션 윈도우를 먼저 측정**(싼 admissible
  proxy: min ≤ 임의 단일 액션 윈도우 → 직전 binding 액션 폭이 현 best 이하면 개선 불가, 스킵); **초과 변형만 전
  필수 액션 min-window를 full 측정**(`measure_time_window`)해 새 binding 확정(다른 액션이 새 binding 됐는지 확인).
  스테이지당 롤아웃 cap 초과 시 `incomplete:true` **정직 보고**(silent 절단 금지 — 3a 동일).
- **(D) max-margin 선택**: coordinate-ascent 종료 시 best = max-margin 해. 동률 채택은 결정론 tie-break(knob
  순서·placement x 오름차순). 고정 격자·고정 순서 = 결정론. **local 최적**(joint·global 아님 — 위 경계 명시).
- **(E) 리포트** `maxmargin.json` = {schema_version, analysis_ref, analysis_sha256, max_margin_scope,
  alternative_search_status:"resolved"|"no_alternative_cleared", indirect_improved(bool), knobs[],
  found_binding:{action,width_s,measured_by:"maxmargin_grid"}, max_margin_binding:{action,width_s},
  max_margin_plan, **max_margin_per_action[전 필수 액션 {index,label,target,time_window:{lo,hi,width_s,intervals,
  gaps,gap_check_stride,gap_verified,incomplete}}]**(verify가 coverage·재계산·경계리플레이에 필요), variants_evaluated,
  variants_cleared, variants_cleared_excluding_seed, passes, search_meta:{grid,cap,rollouts,domain}, incomplete}.
  콘솔 요약(found→max-margin binding 향상 폭).
- **(F) 게이트 = `maxmargin.py --verify`(analyze --verify 와 동형 fail-closed, R1-H2)**: 저장된 maxmargin.json을
  권위 출처에서 재검증 — 저장값 신뢰 금지, solve.json·analysis.json·엔진 리플레이에서 재도출:
  - ① **analysis.json canonical 로드 + sha256 바인딩**(stale 차단) + ② **schema_version 가드**.
  - ③ **`max_margin_per_action` coverage**(analyze `_coverage_check` 동형): max_margin_plan 필수 액션 ↔ per_action
    index/label **1:1 전수**(누락·duplicate·label 불일치 FAIL) + **incomplete 필수 액션 0**(미완 통과 위장 금지,
    `--allow-incomplete`만 예외).
  - ④ **binding 재계산**: `max_margin_binding = min(per_action.width_s)`를 다시 계산해 저장값과 **정확히 일치**
    확인(저장 binding 액션·폭 변조 FAIL).
  - ⑤ **불변식 max_margin_binding ≥ found_binding**(둘 다 maxmargin 격자 재측정값; 위반 FAIL).
  - ⑥ **전 필수 액션 경계 결정론 리플레이**(binding뿐 아니라 모든 액션): 각 interval 내부 1점=clear / 양 끝 밖
    =fail / 각 gap 내부=fail(analyze verify와 동일 interval/gap 핀, tri-state fail-closed).
  - ⑦ **max_margin_plan game-verdict full clear**(D4) + ⑧ **`alternative_search_status`·`variants_cleared` 정합**
    (status=resolved면 variants_cleared_excluding_seed ≥ 1 강제, 아니면 FAIL — 빈 탐색이 resolved 위장 금지, R1-H4).
  - verify 프론트매터 편입은 **3b 완료 시**(게이트 그린 후 — Phase 1/2/3a 정책 동일, verify 갱신 자체가 강제 계약).

#### Acceptance — 3b (falsifiable)
- **대안 탐색**: S11~S14 각각 **knob ≥1**(전부 blocker 보유) → coordinate-ascent가 seed 외 **≥1 변형 평가**
  (`variants_evaluated > 1`). knob 0개 퇴화 스테이지는 그 사실 리포트(FAIL 아님)하되 S11~S14는 knob>0 실증.
- **max-margin**: 각 스테이지 max-margin 해 선택 + **max_margin_binding_s ≥ found_binding_s**(불변식, 둘 다 동일
  격자 재측정·seed 시작 단조라 보장) + max-margin 해 **game verdict full clear**(D4). (S14는 binding=climber가
  blocker knob 재배치로 간접 완화되는지 실증 — 개선 0이어도 불변식·정직 보고 충족.)
- **경계 검증**: max-margin binding 윈도우 경계 결정론 리플레이(interval 내=clear / 밖=fail) — `maxmargin.py
  --verify` 그린.
- **회귀 0**: `maxmargin.py`는 신규 툴(엔진·PlanRunner·analyze.py·solve.py **무변경**) → 기존 verify 전부 그린
  + solve.json·analysis.json **바이트동일**.
- **게이트**: `maxmargin.py --verify`를 verify 프론트매터에 편입·그린(3b 완료 정의).

#### Defer (증거 후 재계획 — 명시)
T_human 티어 보정(difficulty spread 코퍼스 필요) · 절대 난이도 등급 점수(1성/3성 분리) · 다중 명령 합산식 ·
인간 모델(이진 vs 확률 σ) · 공간 조준 난이도 점수(움직이는 무리 속 select 탭) · cross-structure max-margin(다른
스킬 multiset/구조) · joint multi-action 동시 완화. 모두 **미검증 스테이지 다수 풀이로 difficulty spread 확보 후
재진입**(STATUS "고도화 = 실제 레벨 풀기" 경로와 합류).

### Acceptance — 3a (falsifiable)
- **최소화**: S11~S14 각 해의 1-minimal 플랜 + 잉여 액션 식별(S11=1액션; S12~S14 다액션 잉여 0/목록) +
  `minimal_kind` 정직 명시(`--prove-cardinality` 지정 시에만 cardinality-minimal 증명; **기본 3a 게이트는 1-minimal만 요구**, R3-H1). 1-minimal 플랜이 game verdict로 full clear(D4).
- **윈도우**: 각 필수 액션의 시간 윈도우 폭(초)(+ ant_reaches_x는 위치 윈도우) + intervals·gaps 산출.
  경계가 결정론 리플레이로 검증(interval 내=clear / 밖=fail / gap 내=fail) — `analyze.py --verify` 그린.
- **정합성(provisional)**: T_human 기계전용 임계 미만 윈도우를 `provisional_machine_only_flag` 표기
  (`tier_source` 동반). 확정 판정 아님.
- **직관 대조(정보)**: S11~S14 최소 윈도우 순위 vs 사용자 라벨 Spearman·불일치 기록(게이트 아님).
- **가산 확장 회귀 0**: PlanRunner 가산①②가 기존 plan(미설정)·verdict·결정론 불변 — `run_plan --selftest`
  (golden5+solve4) + `SkillMetadataDriftTest` + 결정론 2종 그린, solve.json 바이트동일 재현 유지.
- **게이트**: `analyze.py --verify`를 verify 프론트매터에 편입하고 그린(3a 완료 정의 = 게이트 갱신+그린).

## Phase 4 — 전술 라이브러리 (누적 학습, CBR/EBL) · **⛔ [강제 종료 — TERMINATED (2026-06-24, 사용자)]**
> ### ⛔ 강제 종료 배너 (2026-06-24, 사용자 결정)
> **Phase 4의 핵심 가설("학습 전술 전이로 같은 해를 *더 적은 롤아웃*에"=속도)이 실측으로 기각됐다.** 두 메커니즘 모두 falsify:
> 1. **boost(seed)** — `propose()` 휴리스틱이 이미 같은 순서를 내 롤아웃 0 감소(S12 OFF=ON=8롤, NO-TRANSFER).
> 2. **vault-pruning** — 겉보기 이득(S12 8→4·S13 26→22)은 **완전성 희생의 산물**이었고, 완전성 강화 시 OFF보다 나빠짐
>    (S12 9롤·S13 미클리어). 현 휴리스틱이 이미 후보를 올바르게 랭킹 → 재랭킹/prune의 **sound 속도 이득 0**.
> **결론**: rigor가 환상을 제거함(de-risk 성공 = 잘못된 하위목표 'pruning-for-speed'를 죽임). 살아남은 자산:
> 볼트(`knowledge/`)는 *해 설명 어휘*로 **Phase 5로 이관**, `tactics.py`·`vault_fn` pruning·`transfer-bench`는 **historical
> 아카이브**(음성-입증 인프라, 게이트에 inert=None로 무해 — 삭제는 5a에서 결정). 아래 본문은 **종료된 설계의 이력 기록**이다.
>
> 2026-06-24: Phase 2~3a 증거(S1~4·S11~17 해 + solve.json 트레이스)가 확보돼 D8을 구체 계획으로 승격.
> 검증 가능한 단일 가설로 좁힘: **"S11에서 추출한 전술이 S12/S13으로 전이돼, 동일 난이도 해를 *더 적은 롤아웃*으로 찾는다."** 전이 효과가 측정 안 되면 CBR 가설 자체가 기각 — 그래서 **de-risk(4a)를 가장 먼저·작게** 둔다.
> **딥러닝 아님(D8 재확인)**: 전술 = 사람이 읽는 구조체(스킬·국소패턴·서브골), ML 가중치가 아니다. 해석가능성은 D9 생성 오라클의 전제.

> ### ⚠ 재설계 (2026-06-24, 4a de-risk 실측 후 — 이 절이 현재 설계, 아래 "boost" 원안은 falsified 이력)
> **4a 실측이 boost 메커니즘을 falsify**: "학습 전술로 일치 후보를 boost/reorder"는 `propose()` 휴리스틱이
> 이미 같은 순서를 내므로 롤아웃을 못 줄였다(S12 OFF=ON=8롤, byte-identical, 결정적 액션=fallback = NO-TRANSFER).
> 진짜 레버 = 휴리스틱이 낭비하는 **형제 후보 pruning**.
>
> **사용자 결정 — 지식 볼트 + 위기-인덱스**: 각 액션의 "사용 시 고려 요소"를 **Obsidian 볼트**(마크다운+위키링크)로
> 관리하고, 솔버는 `diagnose → 위기 상황(crisis) 식별 → 그 위기에 링크된 도구·요소 조회 → 적용`으로 **스스로**
> 답을 찾는다(레벨마다 백지 재탐색·손 시드 ✗, 조회·적용 ✓). plan의 "스킬·상황 이중 인덱싱"의 상황 측 구현.
>
> - **볼트** `tools/solver/knowledge/`: `crises/`(frontmatter `detect:`로 diagnose 신호 연결) + `skills/`/`factors/`/
>   `subgoals/`/`stages/`. **파서** `knowledge.py`(순수): resolve(위기→도구·요소) / vault_prune(형제 pruning).
> - **메커니즘**: 위기[water-drowning]→요소[[backpath-offset]] 조회 → 물-가장자리 reverse 후보의 형제(off>=1) prune.
>   solve.py `vault_fn` 훅(기본 None=기존 byte-identical, 게이트 안전).
> - **귀속 변경**(boost의 seed-provenance → pruning 모델): ON 클리어 AND 롤아웃<OFF AND **OFF와 동일 해(final_plan)**
>   AND vault_pruned>0. "같은 답을 더 적은 롤아웃으로, 감소는 볼트가 prune한 형제로 설명"(same-solution이 fallback의 우연한 다른 해를 배제).
> - **실측(transfer-bench --mode vault)**: S12 8→4롤, S13 26→22롤, 둘 다 same해·TRANSFER-OK. 게이트 selftest 16/16 PASS.
>   같은 볼트 지식으로 두 스테이지 개선(레벨별 손 시드 0).
>
> 아래 "측정·귀속 계약"의 seed-provenance 서술은 boost 원안 기준(plan-review R1~R3 approve가 그 설계였음). 재설계로
> **메커니즘·귀속이 바뀌었으므로 plan-stage 적대적 리뷰를 재실행**해 새 설계를 재검증해야 종결한다.

### 목표
스테이지마다 같은 시행착오 반복 금지(D8) + 스킬-사용 프로파일 산출.

### 핵심 설계 원칙 (기존 자산 보존)
- **검증 루프 불변**: 엔진=진실(D4), `solve.py`의 닫힌 루프 그대로. CBR는 `model.propose()` **앞단에 시드를 꽂는 층**이지 대체가 아니다.
- **거짓 양성 0(해의 *유효성* 한정)**: 틀린 전이는 엔진이 잡는다 — 비용은 낭비 롤아웃뿐. **단, 엔진 검증은 "해가 유효함"만 증명하지 "그 해가 전이된 전술에서 나왔음"은 증명하지 않는다**(R1 HIGH-2). 전이 *효과* 증명은 아래 측정 계약이 책임진다.
- **자연 통합 ≠ 측정 혼입**: 전술 매칭은 `propose()`의 기존 `_w`에 **시드 보너스**를 더하는 방식이되, **모든 후보 액션이 생성 시 source-tag(`seeded:<tactic_id>` / `fallback`)를 보유**한다. 보너스로 랭킹에 섞이되 채택 해의 결정적 액션의 *출처*가 추적된다. ON 경로의 롤아웃 감소가 *전이(seeded-origin)* 때문인지 *랭킹 왜곡/fallback* 때문인지 provenance로 구분 가능해야 한다(R1 HIGH-1·R2 HIGH-1).

### 측정·귀속 계약 — **vault, 현행** (re-review R1 HIGH-1·HIGH-2)
전이 효과를 *증명*하려면 "더 적은 롤아웃으로 풀렸다"만으로 부족하다. vault-pruning 메커니즘의 귀속:
- **A/B 하니스 (동일 경로)**: OFF=볼트 비활성, ON=`vault_fn` 주입. 두 경로는 pruning 외 후보 생성·랭킹·budget이
  byte-identical. 결정론(`CANDYANTS_DETERMINISTIC=1`)이라 '동일 seed' 반복 성립. solve.json 미기록(save=False).
- **분리 계측**: `{rollouts, vault_pruned, final_plan, tried_log, pruned_log}`를 OFF/ON 각각 기록.
- **귀속 = same-solution + 반사실 정당성 (R1 HIGH-2)**: 전이 성공 = ON 클리어 AND 롤아웃<OFF AND **OFF와 동일
  해(final_plan)** AND vault_pruned>0 AND **pruning_justified**. `pruning_justified` = ON이 prune한 각 후보가
  **OFF에서 같은 base로 롤아웃돼 미클리어**였음(반사실). prune이 클리어 후보를 지웠거나 OFF가 평가 안 한 후보를
  지웠으면 정당화 실패 → fail. "건너뛰고 같은 답"(최적화)을 "비-유효 형제만 버림"(지식)으로 격상.
- **fail-open 완전성 (R1 HIGH-1)**: solve가 pruning으로 정체하면 `vault_fn` OFF로 재propose해 prune 형제를
  복원·평가 → **ON 완전성 ≥ OFF**(pruning은 롤아웃 절약만, 해 손실 0). off=0이 진척하면 이 분기 미발동(cost-free).
- **fail 조건**: 위 귀속 항목 중 하나라도 미충족 시 `transfer-bench` fail(마커 파싱, false-green 차단).

### 측정·귀속 계약 — boost 원안 **[HISTORICAL · 4a에서 falsified]**
> 아래는 plan-review R1~R3 approve를 받은 *boost(seed) 설계* 기준. 4a 실측이 falsify(S12 OFF=ON=8롤). 현행은 위 vault 계약.
전이 효과를 *증명*하려면 "더 적은 롤아웃으로 풀렸다"만으로는 부족하다(휴리스틱 분산·라이브러리 순서·부분 fallback로도 그렇게 보일 수 있음). 그래서:
- **A/B 하니스 (동일 경로)**: OFF = tactics **완전 비활성**, ON = tactics 격리·귀속. 두 경로는 **tactics 주입 외 모든 후보 생성·랭킹·budget이 byte-identical**. 동일 seed·동일 deadline·동일 max-rollouts로 결정론 반복.
- **분리 계측**: 매 run마다 `{seeded_attempts, seeded_successes, fallback_successes, rollouts}` + 채택 해의 **origin 태그**(seeded-origin / fallback-origin)를 별도 기록. "롤아웃 합계"만 보지 않는다.
- **귀속 기준 = provenance, NOT content (R2 HIGH-1)**: "전이 성공"의 정의는 *해가 seeded 바인딩을 포함*(content)이 아니라 **채택 해의 결정적 액션이 seeded source-tag에서 생성됨**(provenance)이다. 각 후보 액션은 생성 시 source-tag(`seeded:<tactic_id>` vs `fallback`)를 달고, 채택 plan의 전술-담당 액션이 그 source-tag를 보유해야만 전이로 카운트. **같은 모양의 바인딩이라도 fallback-origin이면 전이 실패로 회계**(시드가 랭킹만 흔들고 일반 탐색이 우연히 같은 형태를 낸 경우를 배제). 마커가 seeded-origin 채택 해와 fallback-origin 채택 해를 구별 출력.
- **fail 조건**: ON이 OFF보다 롤아웃이 적어도, 그 감소가 **seeded-origin 채택**으로 설명되지 않으면(= fallback-origin이 푼 것) `transfer-bench` **fail**(false-green 차단). 즉 게이트는 "롤아웃 감소 + seeded-origin provenance"를 **둘 다** 요구한다.

### 끼워넣는 지점 (코드 레벨, 현행 vault)
```
solve.py: diagnose(trace) → knowledge.resolve(위기→링크 도구·요소) → vault_prune(형제 후보 prune) →
          propose 후보 → 엔진 검증 → (정체 시) fail-open 재propose → 반복
```
- `tools/solver/knowledge/`(Obsidian 볼트) + `knowledge.py`(파서: load_vault/detect_crises/resolve/vault_prune, 순수).
- `solve.py` `vault_fn` 훅(기본 None=기존 byte-identical, 게이트 안전). `tactics.py`(boost seed)는 historical 보존.
> **[HISTORICAL · boost 원안]**: `tactics.seed`로 propose `_w`에 시드 보너스 가산 → 4a falsified(휴리스틱이 이미 동순위).

### 전술 데이터 모델 (D8 정의)
`Tactic = (skill, precondition=국소패턴, relative_placement=상대배치, timing_anchor, subgoal, success_history)`.
solve.json 액션이 이미 `{skill, target, trigger}` 구조라 **리프팅 = 절대좌표를 국소 특징 기준 상대값으로 치환**이 핵심. 스킬·상황 이중 인덱싱.

### 리프팅 계약 (R1 MEDIUM — 모호성 차단, 구현 전 확정)
두 구현이 같은 plan을 만족하면서 호환 불가 라이브러리·S11 좌표 은닉 오버피팅을 내는 것을 막기 위해, 리프팅을 결정론 함수로 못박는다:
- **기준 프레임(앵커)**: 국소 특징은 *해당 액션이 작용하는 낙하 가장자리/반전 타깃 셀*을 원점으로 한다(diagnose가 이미 산출하는 `reverse_targets[].cell`·`backpath`). 허용 앵커 = {가장 가까운 hazard, 가장 가까운 ladder/sand_mound, 낙하 가장자리, candy, home}. 그 외 절대 셀 참조 금지.
- **좌표 변환**: `target`의 `y_min/y_max`·`trigger`의 `x`는 앵커 셀 기준 **(Δcol, Δrow) 정수 오프셋 + cell_size 배수**로만 저장. 픽셀 절대값 금지(레이아웃 cell_size 달라도 재구성 가능).
- **개미 식별 제거**: `select`(min_x/max_x/spawn_index)·`state`(carrying 등)는 **역할(role)** 로 보존하되 특정 spawn_index 절대값은 리프팅 시 *서수*(n번째 픽업 등 timing_anchor와 결합)로 일반화. 절대 spawn_index 직접 저장 금지.
- **타이밍앵커 의미**: `picked_ge n`·`ant_reaches_x`는 **이벤트 상대**(스폰/픽업/도달)로 보존 — 프레임 절대값 저장 금지. 다단계 플랜은 각 액션의 앵커를 독립 보존(layout 변형에도 순서·조건 유지).
- **리프팅 거부 조건**: 액션이 위 앵커 중 어느 것으로도 모호성 없이 표현 안 되면(예: 앵커 후보 2개 등거리, 절대 좌표 필수) **전술로 추출하지 않고 거부**(silent 오버피팅 대신 명시적 누락). 거부는 4a 로그에 카운트.

### 작업 (de-risk 우선, 현행 vault)
- **4a · de-risk (완료, 2026-06-24)**: ① boost(seed) 실증 → **NO-TRANSFER**(falsified). ② 재설계 = 지식 볼트 + 위기-인덱스
  pruning → `transfer-bench --mode vault`로 S12 8→4롤·S13 26→22롤, same해·pruning_justified·**TRANSFER-OK**. 게이트 그린.
- **4b · 자동 추출**: solve.json → 리프팅(절대좌표·특정 개미 치환) + 서브골 추론 → 볼트 노트(스킬/요소/위기) 자동 생성·갱신.
  현재 4a는 볼트 노트를 *수동* 저작 → 4b가 자동화. 리프팅 계약(아래)이 그 결정론 함수.
- **4c · 추가 pruning factor**: 물-가장자리 backpath 외 요소로 확장 — 예: [[carry-timing]] 기반 climber 탐색 pruning
  (S13의 22롤 중 다수가 carry 탐색). 각 factor는 fail-open + 반사실 정당성 게이트를 통과해야 채택.
- **4d · 성장·영속**: 새 레벨 해결 시 새 위기/요소 노트 추가(볼트는 커밋 산출물). 재실행 시 로드, held-out 스테이지 회귀.
- **4e · 스킬-사용 프로파일**: 스킬별 "정답이었던 맥락"(=위기→도구 링크 누적) = 도구의 올바른 사용(D9 생성 어휘).

### 게이트 (현행 vault)
- `try_solve.py transfer-bench --mode vault` → **측정·귀속 계약(vault)** 구현: 동일 seed·budget OFF/ON 결정론 반복,
  `{rollouts, vault_pruned, same_solution, pruning_justified}` 마커 출력, 판정 = **롤아웃 감소 AND same해 AND
  pruned>0 AND pruning_justified(반사실)**. 마커 파싱(exit-code 아님)으로 false-green 차단. 기존 게이트(결정론·
  하니스·selftest·analyze --verify) 전부 그린 유지(`vault_fn=None` 기본 경로 byte-identical). knowledge.py selftest 추가.

### 리스크
- **R1 (pruning이 해 삭제)**: off>=1 형제를 잘못 버려 미해결 → **fail-open**(정체 시 형제 복원)으로 완전성 보장. held-out 회귀.
- **R2 (overfit pruning false-green)**: → **반사실 정당성**(prune 후보가 OFF서 미클리어) 게이트로 차단.
- **R3 (off 선택 규칙 미학습)**: 현재 off=0-only는 stage11/12 근거의 잠정 규칙 → 4c에서 국소-패턴 predicate로 학습. fail-open이 그 전까지 안전망.

### Acceptance
- 같은 볼트 지식으로 S12/S13이 **동일 해를 더 적은 롤아웃**으로 — 그 감소가 **반사실 정당화된 pruning**으로 설명됨
  (`transfer-bench --mode vault`: 롤아웃 감소 AND same해 AND pruning_justified). ✅ 달성(S12 8→4, S13 26→22).
  볼트 영속·성장 + held-out 스테이지 회귀 무파손.

## Phase 5 — 솔버 고도화 및 재설계 (다양-해 발견 + 풀이법 보고서) · **[확정 · 진행 중 (2026-06-24~)]**
> Phase 4(속도 위한 전술 전이)가 강제 종료되며, 솔버의 가치를 사용자가 재정의(2026-06-24): *속도*가 아니라
> **한 스테이지를 스스로 다양한 방법(플레이어가 찾을 법한 의도-외 해 포함)으로 풀어 디자이너에게 중립 보고**하는
> 데 있다(designer-in-the-loop). 이 페이즈가 그 재설계의 in-track 홈이며 **Phase 0~2 자산(결정론·하니스·닫힌-루프
> 솔버) 위에 얹는다** — 코어 솔버는 불변, 다양성은 opt-in 층(forbid/inv_override)이다.

### 목표
미검증 실제 스테이지를 솔버가 스스로 다양하게 풀어, 각 해의 {도구·수량·배치·전략·위기 맥락}을 **중립 풀이법
보고서**로 산출한다. **의도 판단·조절 의견 제시 없음**(중립 발견·보고만) — 디자이너가 인정/레벨·도구 조절을 결정.
= 트랙 밖 다운스트림(감사 오라클·생성)의 핵심 입력.

### 핵심 설계 원칙 (기존 자산 보존)
- **검증 루프 불변**: 엔진=진실(D4), `solve.py` 닫힌 루프 그대로. 다양성 메커니즘(`forbid`/`inv_override`)은 **opt-in 층**
  이지 코어 대체가 아니다 — 기본값이면 베이스와 **byte-identical**(게이트 안전, selftest 16/16로 강제).
- **속도 가설 폐기 명문화**: 재랭킹/prune의 sound 이득 0(휴리스틱이 이미 올바르게 랭킹, Phase 4 실측). 솔버의 가치는
  *다양성 발견*과 *해 설명*이지 롤아웃 절약이 아니다.
- **죽은 메커니즘 격리**: boost(`tactics.py`)·pruning(`vault_fn`)·`transfer-bench`는 historical(음성-입증 아카이브, inert).
  볼트(`knowledge/`)는 *해 설명 어휘*(diagnose→위기 맥락)로 **존속**(`diverse_report`가 `knowledge.resolve`로 사용).

### 하위 단계
- **5a · 재설계 정립 (✅)**: Phase 4 강제 종료 + 방향 재정의 명문화. **dead 메커니즘 = 아카이브 보존**(사용자
  결정 2026-06-24, 삭제 안 함): `tactics.py`/`solve.py vault_fn·seed_fn`/`transfer-bench`에 ⛔ARCHIVED 배너 +
  매니페스트 `tools/solver/ARCHIVE.md`. in-place 보존(라이브 코드와 얽혀 이동 시 회귀 위험, 이미 None-safe inert).
- **5b · 다양성 축 (✅ revised 구현 — 가능성-공간)**: §5b 계약 구현 = `tools/solver/diverse.py`(4요소 시그니처 +
  placement range-sweep + solution-class + 4요소 forbid 술어). `solve.solve(forbid=)`가 callable 술어 허용.
  좌표 ±시프트는 검증 구역에 흡수돼 **1 solution-class로 병합**(S12 naive 2해→1, 실측). 자체 리뷰 clean·⏳codex.
- **5c · 보고서 영속 + 게이트 (✅ range 스키마 + 게이트 편입)**: `data/solutions/stageNN.diverse.json` = **range
  스키마**(class별 reference_plan + 슬롯 검증 구역 intervals/gap_verified). 게이트 `try_solve diverse-verify`
  (reference clear + 각 cell_x 슬롯 interval 전 셀·도메인-내부 경계 밖 fail·gap fail, analyze --verify 동형,
  fail-closed) → **`verify` frontmatter 편입 완료**. 영속 보고가 엔진/스킬 변경에 깨지면 잡힘.
- **5d · 고도화 (미검증 스테이지)**: Ch1~5 잔여(S18·Ch2 sand_mound 계열 S5/19/21~25 등)를 풀어보며 솔버 개선 +
  다양-해 코퍼스 확보. sand_mound(cell-up) routing 등 미커버 메커니즘 추가는 여기서. **5d② = sand_mound 벽-반전
  cell-up(S19 100%, 종결)**.
- **5e · 리스크-구동 다중-도구 분기 (S21~25, ⏳plan-review)**: sand_mound를 목표-위 *절벽*에도 연결(선결 D1) +
  한 리스크에 경쟁하는 routing 후보의 _w burial 해소(검색 breadth D2) → dead-end 탈출·다양-해를 한 메커니즘으로.
  하드 게이트 = S22 단순해(bridge+sand_mound) 100%(de-risk로 witness 입증). §"5e 계약" 참조.

### 5b 계약 — 가능성-공간 다양-해 (revised, 2026-06-24 사용자)
> 솔버 산출물의 단위 질문 = "해가 몇 개"가 아니라 **"어디에 놓으면 클리어되나(가능성 공간)"**. 위치 변화는 클리어
> 가능 범위를 알려주므로 무의미하지 않으나, 좌표 조합을 일일이 나열하면 노이즈(±1타일 시프트)가 다양성으로
> 위장된다 — **S12 실측**: `@24/888/312` vs `@72/840/360` = 3 blocker가 **일제히 정확히 1타일 시프트**(트리거 간격
> =1셀) = 같은 전략. 현 naive distinctness(액션 집합 정확 일치)는 이를 2해로 오보. 본 계약이 그 결함을 해소한다.

- **표현 = 검증된 연속 구역 범위**: 스킬별로 각 배치 인스턴스를 **연속 클리어 구간**으로 묶어 range로 보고
  (예 `blocker×3 → col[0–1]·[6–7]·[17–18]`). 단 "연속"은 **선언된 stride(`gap_check_stride`)로 검증된** 구간일 때만
  병합 근거가 된다(아래 R2-HIGH).
- **solution-class 동치(병합) = 4요소 모두 동일** (R2-MEDIUM — placement만으론 부족, D5 타이밍 1급):
  (i) **스킬 multiset**(종류·횟수), (ii) 각 슬롯 배치가 같은 **검증된 연속 구역** 내, (iii) **target role/state**
  (`select`=min_x/max_x/spawn_index·`state`=carrying 등), (iv) **trigger/timing 의미**(`trigger` type·cmp·`picked_ge`
  서수·subgoal 앵커). 넷 다 같을 때만 한 해(구역 내부 시프트만 무시).
- **분리(다른 solution-class)**: 위 4요소 중 **하나라도 다르면** 새 해 — 비연속 구역 배치 OR 스킬 횟수 변화 OR
  **target role/state 차이** OR **trigger/timing 차이**. (같은 배치라도 타이밍·역할이 다르면 다른 전략이므로 분리.)
- **범위 발견 = 독립 축 스윕 + 연속성 검증** (R2-HIGH — 병합은 *검증된* 연속에만): 각 인스턴스 위치를 *나머지를
  한 클리어 기준배치로 고정*한 채 **선언된 `gap_check_stride` 해상도로 스윕**, 엔진 검증(D4) → `{sampled_points,
  gap_check_stride, intervals, gaps, gap_verified}` 산출(**`analyze.py` `_reconstruct_runs` + Phase 3 R12 gap_verified/
  gap_coverage 정직표기 재사용**). 슬롯 정체성 = 좌→우 정렬 순서.
  - **연속 병합은 구간이 stride 해상도로 `gap_verified`일 때만.** 미검증(stride 사이 미샘플) 구간은 `provisional:true`로
    표기하고 **확정 solution-class 병합에 쓰지 않는다**(불확실 구간은 따로 보고) — hidden fail-island를 병합으로 숨겨
    "비연속=별개 해" 규칙을 위반하지 않도록.
- **분리-해 탐색 (forbid = 4요소 시그니처, placement 구역만 아님 — R3 MEDIUM)**: 발견한 solution-class를 **그 4요소
  시그니처**(skill multiset + 검증 구역 + role/state + trigger/timing)로 forbid한다. 2단계로 same-placement 변형을
  놓치지 않음:
  - (a) **구역-내 role/timing 변형 스윕 먼저**: 같은 검증 placement 구역에서 `select`/`state`·trigger/timing/subgoal을
    바꾼 클리어를 탐색(같은 배치·다른 전략 = 별개 class). 이걸 구역 forbid보다 *앞에* 두어, placement만 같고 role/
    timing이 다른 class가 분류 전에 필터되지 않게 한다.
  - (b) 그 다음 **구역 밖 배치** 탐색(비연속 구역 = 별개 class). forbid가 4요소 시그니처 단위라 placement 동일·role/
    timing 상이 class는 (a)에서 이미 포착돼 (b)의 구역 forbid에 묻히지 않는다.
  반복(추가 탐색 캡 예산 내, `search_capped` 정직 표기).
- **정직 경계 (over-claim 방지 — 3a sampled/pos·R12 교훈)**:
  - **sampled@stride**: range는 `gap_check_stride` 해상도 스윕이지 전수 아님 → `range_sampled:true` + `gap_check_stride`
    + `gap_verified`(그 해상도에서 내부 연속 확인됨) 명시. 미검증 구간 = `provisional`.
  - **축별 독립(joint 미검증)**: 보고 range는 *나머지 고정 시* 각 축의 클리어 span(cross-section)이며 **모든 조합의
    곱공간이 클리어함을 주장하지 않는다** → `axis_independent:true` + note. (전수 joint 검증은 조합 폭발.)
  - **informational(authoritative 아님)**: placement 발화가 `ant_reaches_x`라 trace 의존(3a R7~R10 bouncing-ant
    모호성 동류). 난이도 권위 측정 아님. 단 **경계 + 선언된 stride의 내부/gap 샘플 점이 엔진 리플레이로 재검증**
    (interval 점=clear, gap 점=fail)돼 *그 해상도까지* authoritative(analyze.py --verify와 동형).

### 게이트
- **현 `verify` 그린 유지**: 다양성 메커니즘이 opt-in(`forbid=None`/`inv_override=None`)이라 기본 경로 불변
  (Item 1 후 selftest 16/16·frame byte-identical 확인). inert 키 금지(R2-HIGH) — 5c 전까지 `verify` 무변경.
- **5c 완료 시**: selftest가 `stageNN.diverse.json`의 각 보고 range를 결정론 리플레이로 **fail-closed 검증** —
  **경계(min/max) + 선언된 `gap_check_stride`의 내부/gap 샘플 점**(interval 점=clear, gap 점=fail, **analyze.py
  --verify와 동형**) → `verify` 편입. 이로써 "보고된 contiguous 병합 = stride 해상도로 gap_verified"가 강제돼
  hidden fail-island 병합이 차단된다(R2-HIGH). `provisional`(미검증) 구간은 확정 병합 금지라 게이트 대상도 경계뿐.

### Acceptance (falsifiable)
- **병합 정확성(4요소 동치)**: 스킬 multiset·검증된 연속 구역·target role/state·trigger/timing이 **모두 같을 때만**
  1 solution-class로 병합. 회귀 기준 = **S12의 `@24/888/312`·`@72/840/360`**(role/timing 동일·인접 구역)이 1 class
  (`blocker×3 → col[0–1]·[6–7]·[17–18]` 형태)로 병합돼야 함(현 naive 2해 = 본 계약이 해소하는 결함). 4요소 중
  하나라도 다르면(비연속·횟수·role·timing) 분리.
- **연속성 falsifiable(R2-HIGH)**: 보고된 각 contiguous 병합이 **`gap_check_stride` 해상도로 gap_verified**이고,
  5c 게이트가 **경계 + 내부/gap 샘플 점**을 리플레이(interval=clear, gap=fail, analyze.py --verify 동형)로 재검증해
  hidden fail-island 병합을 차단. 미검증 구간은 `provisional`로 확정 병합 금지.
- **정직 보고**: 미검증 스테이지에서 과대주장 0 — `range_sampled`/`gap_check_stride`/`gap_verified`/`axis_independent`/
  `provisional`/`search_capped` 플래그 정직 표기.

### 5d② 계약 — sand_mound (cell-up) routing **[설계 · plan-review 대상, 2026-06-26]**
> 5d 우산("sand_mound(cell-up) routing 등 미커버 메커니즘 추가는 여기서")의 첫 코드-변경 항목. 5d①(코퍼스 확장)은
> 데이터 생성이라 리뷰 불요였으나, 본 항목은 `model.py`(+`solve.py` 게이트)에 **신규 routing 분기**를 추가 = plan-review
> + impl-review 대상. 엔진/PlanRunner/게임 코드 무변경(솔버 휴리스틱 + selftest EXPECTED만).

**문제(현 결함, 실측 재현)**: cell-target SIGN 스킬(sand_mound)은 `model.propose`에 **어떤 분기도 없다** — ① 루프는
target=ant routing(reverse/safe_fall/cross)만, ② 루프는 `up`이되 ANT_ARMED(climber/slide)만(line 341 가드로
non-ANT_ARMED skip). 결과: sand_mound 인벤토리 스테이지에서 propose가 **후보 0개**.
- **S19 베이스라인 실측**(`search 19`, empty-plan trace): 5마리 전원 home(1,10)→우측보행→col5에서 좌측블록 끝나
  **추락**(row10→14)→계곡 바닥 row14 착지→우측 (15,14)에서 **우측 tower(col16) 벽 막힘 반전**→좌측 (5,14)
  좌측블록 막힘 반전→**col5↔15 무한 왕복**, **retired=0(낙하·물 0)·time_out**. candy(16,6)는 우측 tower 위
  row7 → 계곡(row14)에서 **+7~8칸 상승** 필요. **낙하사·물 신호가 없어** 기존 `reverse_targets`(낙하 가장자리)는
  완전 blind → "제안할 개입 후보 없음"으로 즉시 정지.

**검증된 메커니즘(엔진 소스 실독)**:
- 개미는 스킬 없이 **어떤 단차도 자동 못 올라감** — 같은 row 전방 셀이 solid면 벽으로 보고 **반전(flip)**(WalkerState/
  CarryingState `is_on_wall`→`flip`), 전방 바닥 없으면 **추락**(FallerState).
- **sand_mound = 수직 사다리 최대 5칸**(`WorkerState.SAND_MOUND_MAX_HEIGHT=5`). 위가 막히면 ledge **cap + 개미를
  2칸 위 ledge로 텔레포트**. 건설한 개미가 즉시 타고 오르며, 깔린 사다리는 **영구 지형** → 이후 개미도 그 기둥을
  `ladder_climb_ahead`로 탄다. 사인은 **one-shot**(첫 개미 1마리에 발동 후 queue_free) → **사인 1개 = 모두를 위한
  사다리 1개**(인벤토리 sand_mound 개수 = 깔 수 있는 사다리 수와 직접 대응).
- **추종 개미도 천장 레지를 넘는다**(`LadderClimbState` 꼭대기 종료 실독 — plan-review R2 조사로 *수정*): cap =
  **위 칸=점유(레지) AND 위-위 칸=빔**이면 레지 위로 올라서고 보행 복귀. blocked = 위·위-위 둘 다 막힘일 때만.
  ⚠ 따라서 "cap은 건설자 전용"이 **아님** — 영구 사다리를 뒤따르는 walker도 동일 cap으로 위층 진입(S19 5/5
  실측, ant1~4 전부 candy 도달).
- **⚠ 배치 위상 제약(stacking, S19 6×4 스윕 + 코드로 입증)** — 두 사다리를 쌓을 때:
  - **(T1) 다른 열 필수**: 같은 col에 쌓으면 ladder2 바닥 rung이 ladder1 cap의 **"위-위=빔" 조건을 채워** 깨뜨려
    추종자가 ladder1 꼭대기서 막힘(같은-col 전부 1/5). ladder2 col ≠ ladder1 col.
  - **(T2) ladder2는 ladder1보다 진행방향(벽/목표) 쪽**: 개미가 ladder1로 상위 표면에 올라선 뒤 **벽 방향으로
    걸어가다** ladder2 사인을 만나야 함. 반대편이면 못 만나거나 가장자리서 추락(스윕: L2col≤L1col 전부 0~1).
  - **(T3) ladder1은 벽에서 떨어뜨려(off≥1) 사이에 ladder2 공간 확보**: 벽에 딱 붙은 반전-셀(off=0)에 ladder1을
    두면 그 위 표면에서 ladder2를 둘 곳이 벽까지 없음(L1=벽열 전부 ≤1). off≥1 backpath 셀이라야 (T2) 공간이 남.
- **cell 액션 스키마**(golden s05 선례·PlanRunner._fire_cell 실독): `{"skill":"sand_mound","target":{"mode":"cell",
  "cell":[col,row]},"trigger":{"type":"at_frame","frame":0}}`. **cell=[col,row]=표면 위 빈 보행 셀**(SignPlacement가
  아래로 snap, **점유 셀이면 MAX 반환=무효**). 사인은 그 셀에 들어온 floor 위 개미에 발동. **at_frame=0 = 사인을
  시작에 *배치*(셀이 그때 유효 지형이어야)하고 *발동*은 개미 도달 시** — S19 두 타깃은 모두 기존 플랫폼 위라
  frame-0 유효(snap 무해, R2 HIGH 경험 반증).

**설계**:
- **D1 · `diagnose` 신규 `wall_targets`** (reverse_targets의 *상승판*): **벽-반전**을 검출한다 — 트레이스에
  `ant.direction` 필드가 없으므로(셀 변화 + carry/state만) **방향 d를 명시적으로 "진입(incoming) 세그먼트
  방향"으로 정의**(plan-review R1-HIGH 해소). 절차: 연속 grounded 샘플에서 **수평 이동이 +→− 또는 −→+로
  뒤집히는 국소 극점(반전 셀) (cx,cy)** 를 찾고, 그 직전 진입 방향 `d_in`(반전 전 마지막 수평 이동 부호)을
  취한다. **soundness 게이트 = 전방 셀 `(cx+d_in, cy)`가 occupied**(=실제 벽에 부딪혀 반전; 허공에서 도는
  반전·절벽 추락은 배제). 추가로 **목표가 더 위**(goal_row < cy; 목표=미픽업이면 candy, 운반이면 home)일 때만
  채택. 기록 = 벽-기저 셀 (cx,cy)(=개미가 선 빈-위-바닥 셀, 사인 유효 셀) + `d_in` + 목표진척(이 col 상승 시
  goal 거리 감소량) + backpath(진입측 보행 grounded 타일, off 변형 lead-time).
  - **two-wall valley 명시**(S19): 계곡 바닥서 좌·우 벽 둘 다 d_in·전방-solid를 만족하면 **둘 다 후보로 emit**,
    **목표 거리 감소량 desc 정렬**(candy 쪽으로 가까워지는 벽 우선; S19 우측벽 col15→candy col16). 엔진 verdict가
    최종 판정 — 가중은 순서만. dedup·정렬 키 완전 결정론(좌표·진척, 안정 tie-break).
  - **단위 selfcheck(prove-it, fail-closed)**: `model._selfcheck_wall_targets()` — 합성 grid + 합성 trace로
    ⓐ right-wall(d_in=+1, 전방 solid → 검출) ⓑ left-wall(d_in=−1) ⓒ two-wall valley(둘 다 검출·목표 근접 정렬)
    ⓓ 허공 반전(전방 비-solid → 미검출) ⓔ 목표가 아래(미검출)를 단언. rediscover-verify에 편입(reverse_targets
    동형 검증 패턴). **이 selfcheck로 방향 규약을 박제** — 구현이 d 규약을 어기면 FAIL.
- **D2 · `propose` 신규 ③ SIGN cell-up 분기 (후보 column-sweep, 엔진 판정 — A안)**: 인벤토리 중
  **meta.target=="cell" AND routing=="up"** 스킬(현재 sand_mound만; 일반키)에 대해, 각 wall_target마다 **단일
  반전-셀이 아니라 진입측 backpath를 따라 off=0..K cell-up 후보를 펼쳐** emit(at_frame 0). **위상 제약(T1~T3)을
  솔버가 직접 인코딩하지 않고 후보 다양성 + 엔진 verdict로 해소**(기존 "후보 제안→엔진 판정" 철학):
  - off=0(벽 붙음)은 (T3) 위반이라 단독 실패 → 검색이 off≥1 backpath 셀(벽에서 떨어진)을 이어서 평가. **backpath
    깊이 K를 reverse(3)보다 늘려**(예 off=0..5) S19 valley(col15→col10 = 5칸)까지 닿게 한다. 가중 = `_note_w*8 +
    목표진척 + (2-off 약화)` — off=0 우선이되 실패 시 off≥1 자연 진행.
  - **(T1) 같은-col 회피**: base plan에 이미 cell-up 사다리가 col C에 있으면, **col C 후보를 exclude**(다른 backpath
    off로 강제) — 같은 열 재스택을 원천 차단. 이건 cell-up 분기 내부 결정론 필터(① reverse exclude와 별개).
  - exclude(tried)는 cell 라벨 단위. **① ant-loop·② up-loop와 완전 분리**(routing 키로 격리).
- **D3 · 닫힌-루프 stacking (위상 의존 명시)**: 매 라운드 trace는 현재 도달 표면의 벽 막힘을 보임 → cell-up 후보
  펼침 → 엔진이 (T1~T3) 만족 조합을 verdict로 선별 → 다음 라운드 한 단 위. **S19 = 2단**(valley→row11 플랫폼→
  row7), **off≥1 + 다른-col + 우향** 조합을 검색이 찾음(증거: 손배치 (10,14)+(12,10) saved=5/5). LA2 lookahead가
  off·col 조합 + bridge/blocker(S21~25) 보조. ⚠ **naive greedy(off=0만)는 (T3) 위반으로 실패** — 검색 breadth가
  off-변형을 실제 탐색해야 하므로 cap/LA2 예산이 충분해야 함(S19 acceptance가 이를 박제).
- **(볼트 crisis 노트 = 본 plan에서 제외, plan-review R1-MEDIUM 해소)**: `detect: wall_targets` 노트는 `knowledge.
  detect_crises`가 하드코딩 토큰만 발화해 **코드 없이는 dead text**이고, 발화시키면 아카이브 `vault_prune` 표면을
  건드린다. 따라서 본 routing plan은 **knowledge.py/볼트 무변경**(LIVE 서술 어휘 그대로). 신규 위기의 볼트 편입이
  필요해지면 **별도 doc-only 변경**(regression: `knowledge.resolve`/`vault_prune` 출력 wall_targets에 대해 불변
  단언)으로 분리한다.

**정직 경계 / inert(byte-identical) 불변식**:
- **인벤토리에 up-cell 스킬이 없으면**(기존 S1/S4/S11~17/S20·golden 전부) 신규 diagnose 필드·propose 분기 모두
  **미발화 → 후보 집합·순서 byte-identical**. wall_targets는 ① 루프에 누출 금지.
- analyze.py는 이미 cell-target 액션(`kind=="cell"`) 처리 → diverse/verify 호환.
- 본 분기는 **단일 routing 클래스(up-cell)**만 추가 — break/down/jump cell 디바이스(Basher/Cutter/Digger/LeafJump)는
  **미커버 유지**(스코프 밖, 정직 표기).

**스코프 / Acceptance (falsifiable) — S19 100% = 하드 게이트** (plan-review R1-HIGH 해소, escape hatch 제거):
- **본 변경의 하드 acceptance = `solve.solve(19)`가 sand_mound×2로 S19를 100%(saved=5/5) 클리어**. "primitive만
  되고 진척만 보이면 통과"라는 출구를 **제거** — 닫힌-루프 stacking이 실제로 작동함을 *유일한 정준 증명*인 S19
  클리어로 박제한다. **달성 가능성 = 경험적 입증**(손배치 witness): `[sand_mound@(10,14), sand_mound@(12,10)]`
  → **saved=5/5, frame 1586**(5마리 전원 픽업·귀환). 즉 하드 게이트는 미입증 약속이 아니라 *존재가 확인된 해*를
  솔버가 자동 발견하는 것.
- **S19를 실행 가능 `verify` 게이트에 실편입**(plan-review R2-MEDIUM 해소 — 산문 acceptance만으론 회귀 못 잡음):
  `rediscover-verify`에 **stage19 케이스 추가**(`solve.solve(19, save=False)` 재발견 → cleared saved=5/5 + 액션
  시그니처 = sand_mound×2 단언). solve 시 `stage19.solve.json` 영속 + selftest EXPECTED 편입(frame byte-identical).
  → `verify` frontmatter가 sand_mound routing 회귀(검출·후보·위상)를 잡는 단일 정준 게이트가 된다.
- **만약 구현 중 S19가 cap·합리적 휴리스틱으로 100% 불가로 판명되면**: silent defer **금지**. S18식으로 **불가
  근거를 실측 입증**(어떤 휴리스틱 한계인지, saturation 트레이스)한 뒤 **사용자에게 STOP·에스컬레이트** — 사용자가
  재설계/재스코프/취소를 결정한다. (S18·S20 선례 = 사용자 오케스트레이터 결정.) 즉 S19는 "통과 OR 명시적
  에스컬레이트"이지, 조용히 빠질 수 없다.
- **S21~25(조합)·S5(sand_mound+floater)** = stretch(본 게이트 아님). S19 통과 후 별도 시도, 추가 routing 상호작용
  필요할 수 있음. 이들은 명시적으로 본 변경의 acceptance에서 제외(정직 표기).
- **회귀 게이트**: selftest **byte-identical**(기존 17 plan, 기존 solve.json git 무변경) + `verify` frontmatter 그린 +
  `_selfcheck_wall_targets` PASS. wall_targets 결정론 정렬(reverse_targets 동형).

**리스크(plan-review 타깃)**:
- 벽 검출 과발화(목표가 위가 아닌 벽까지 라더) → 예산 낭비. **완화=목표-위 게이트**.
- 사인 셀 점유/무효(SignPlacement MAX) → no-op. **완화=개미가 선 grounded 빈 셀(cx,cy) 배치**.
- **stacking 위상 실패**(R2 조사로 식별·해소): 같은-col 재스택은 ladder1 추종-cap을 깨고(T1), 벽-붙은 off=0은
  ladder2 공간을 막음(T3). **완화 = (T1) 같은-col exclude + (T3) backpath off≥1 후보 펼침 + 엔진 verdict 선별**.
  ⚠ 잔여: naive greedy(off=0만)는 실패 → **검색 breadth(off·col 조합 탐색) 필수**. 이게 cap 예산에 민감하면 S19
  acceptance에서 드러남(미달 시 사용자 에스컬레이트, escape 아님).
- 결정론: wall_targets 정렬 키 + cell-up 후보 off/col 순서 완전 결정론(좌표·진척, tie-break 안정).

**구현 바인딩 요구 (plan-review R3 incorporate — 사용자 "반영 후 구현 진입" 결정 2026-06-26, impl-stage 검증)**:
plan-stage 3-round cap에서 R3 HIGH×1+MED×1이 나와 STOP→사용자가 "두 finding은 접근 무효 아닌 *테스트가능성
요구*이므로 plan에 바인딩 후 구현, impl-stage 적대 리뷰로 검증"으로 결정. 아래 둘은 **구현·게이트 필수 조건**:
- **R3-H1 · 같은-col exclude가 LA2에서도 적용 (solve.py plumbing 필수)**: T1(같은-col 회피)을 `model.propose`
  내부에만 두면 안 됨 — 기존 `_propose`는 `model.propose(plan=plan)`로 **closed-over 확정 plan**만 넘기고 LA2는
  speculative `base2`를 따로 받는다(solve.py:223-228·326). 확정 plan만 보면 **LA2 2nd-step(speculative 첫
  sand_mound 후) 제안에 필터 미적용** → 유일 조합검색 경로가 같은-col 재스택(1/5 poison)을 제안. ∴ **cell-up
  exclude는 speculative base(LA2의 base2 포함)를 봐야 한다** — early-chain closure 의미를 깨지 않도록 cell-up
  전용 인자(`cellup_base`/`accepted_actions`)를 `propose`에 추가하고 `_propose`/LA2 경로가 각자의 base를 전달.
  **regression(fail-closed)**: LA2가 speculative 첫 sand_mound 후 2번째를 제안할 때 **같은-col 후보가 부재**함을 단언.
- **R3-M1 · off=K witness emit 증명(reverse depth cap 비재사용)**: S19 유일 해는 ladder1=col10=우측벽서 **off=5**.
  현 reverse는 backpath 4 hard-cap(model.py:129)·제안 `min(3,len(bp))`(model.py:304) → 이를 미러하면 D1
  selfcheck를 통과하면서 **witness col을 영영 미emit**, S19 실패가 비싼 rediscover서 모호 진단으로만 표면화.
  ∴ **wall-target backpath collector는 reverse의 depth-4 cap을 재사용하지 말 것**(≥6 수집), cell-up 제안은
  off=0..K(K≥5) emit. **fixture(fail-closed)**: S19형 우측벽 wall_target이 **backpath ≥6 보유** + `propose`가
  롤아웃 전에 **off=5 후보 (10,14)를 실제 emit**함을 단언(`_selfcheck_wall_targets` 또는 별도 S19 fixture).

### 5e 계약 — 리스크-구동 다중-도구 분기 (S21~25) **[설계 · plan-review 대상, 2026-06-26]**
> 5d 우산의 후속. 5d②가 *벽-반전*에 sand_mound를 연결했다면, 5e는 **(i) sand_mound를 목표-위 *절벽*에도 연결**
> (선결)하고 **(ii) 한 리스크에 경쟁하는 여러 routing 후보가 _w 랭킹에 묻혀 롤아웃조차 안 되던 결함**을 푼다.
> 사용자 합의 방향("리스크 발견 시 다양한 도구를 넣고 해를 찾기") = **dead-end 탈출 + 다양-해 발견을 한 메커니즘**
> 으로. `model.py`(diagnose/propose) + `solve.py`(검색 breadth) + selftest/게이트만 — 엔진/게임 무변경.

**de-risk 실측 (2026-06-26, S22 정준 — 본 plan은 가설이 아니라 *재현된* 결함 위에 선다)**:
- **베이스라인**: S22는 리스크 시퀀스 = ① 접근 절벽 (4,2)→우(candy 아래-우, 추락) → (bridge로 전원 픽업
  reached=7) → ② **귀환 절벽 (8,6)→좌**(운반 7마리가 row7 플랫폼 좌단서 추락, lost=7). candy=(20,6) home=(0,2).
- **선결 프로토타입(reverse_targets→cell-up, 목표-위 필터) = witness 후보를 실제 emit**: bridge 채택 후 진단이
  귀환 절벽 (8,6) dir=−1 backpath `[(8,6),(9,6),(10,6),(11,6)]`를 내고, return-phase goal=home(0,2)이 위 →
  cell-up 후보 sand_mound@(8/9/**10**/11,6) emit. **손배치 검증**: `bridge + sand_mound@(10,6)` → **saved=7/7
  lost=0**(유일 — off=2만 유효; (8,6)/(9,6)/(11,6)=0/7). 즉 **후보 풀에 정답이 들어 있다.**
- **그러나 선결 단독 불충분 — _w 랭킹 burial이 진짜 병목**(핸드오프 "slideR 락온"의 정확한 메커니즘): 같은
  리스크(귀환)에 **carry-arm 무장(slideL/slideR, routing=up·ANT_ARMED) _w≈220**(return_phase carry_base)와
  **cell-up(sand_mound) _w≈10**이 경쟁한다. `propose`가 top-`max_n`(=6)만 반환 → carry-arm이 6칸을 독점,
  sand_mound는 **롤아웃조차 안 됨**(cap 30·LA2로도 정체, 22롤서 STOP). carry-arm은 _w 1위인데 **클리어 못 함**
  (reached=7/saved=0), cell-up은 _w 꼴찌인데 **클리어함**(7/7) = 전형적 cross-routing 랭킹 burial.
- **결론**: 선결(D1)은 *필요·witness 생성*이나 *불충분*. 단순해 발견조차 **리스크별 routing-breadth 보장(D2)**
  이 있어야 — 어떤 routing이 그 리스크를 푸는지 **_w가 아니라 엔진 verdict가 결정**하게.

**검증된 메커니즘(5d② 실독 + 본 de-risk)**: sand_mound cell 액션 스키마·one-shot 영구 사다리·추종자 cap·배치
위상(T1~T3)은 5d② §"검증된 메커니즘" 그대로. 신규 확인 = **목표-위 fall-edge에서도 cell-up이 유효**(witness
(10,6)=귀환 절벽 backpath off=2, 운반 개미를 row7 위로 들어올려 home 경로 확보). off≥1 backpath가 정답이라
**reverse_targets backpath depth-4 cap이 (10,6)=off2까지는 닿음**(S19 valley off=5와 달리 S22는 얕음).

**설계**:
- **D1 · 선결: `propose` ③ cell-up이 *목표-위 fall-edge*도 후보로** (reverse_targets→cell-up 연결): 현 ③는
  `wall_targets`만 순회 → fall-edge(추락 가장자리)엔 blocker/floater/bridge(①)만 나고 sand_mound는 빠진다.
  **추가**: cell-up 루프가 `wall_targets` + **목표-위 reverse_targets**(해당 phase 목표가 그 셀보다 위 —
  미픽업이면 candy, 운반이면 home; 5d② per-sample 목표 규약과 정합)를 함께 순회해 backpath off=0..K cell-up
  후보를 emit. **soundness**: fall-edge는 전방이 비-solid(추락)라 wall_targets의 "전방 solid" 게이트와 배타 →
  중복 emit 없음(dedup은 5d② `seen_cells`로). **selfcheck 확장**: `_selfcheck_wall_targets`에 *목표-위
  fall-edge → cell-up 후보 emit / 목표-아래 fall-edge → 미emit* 케이스 추가(fail-closed 박제).
- **D2 · 검색 breadth: 리스크별 intervention-class *evaluated-prefix* 보장** (burial 해소 — 본 plan의 핵심,
  plan-review R1-HIGH 반영): 한 라운드에 진단된 리스크가 **여러 intervention class**(= 구별되는 (routing,
  target-class) — 예 reverse / safe_fall / cross / up-armed / **up-cell**)를 가질 때, `min(evaluated)` commit/정체
  판정 *전에* **각 class의 평가 프리픽스(evaluated-prefix)를 결정론 순서로 소진**한다. **단순 "class top 1롤"은
  불충분**(R1-HIGH): cross-routing burial은 막아도 **intra-class burial**은 안 막는다 — S22 up-cell은 backpath
  off로 갈리는데 현 _w가 `+off`(큰 off 선호)라 top=off3=(11,6)=**0/7**, 유일 witness off2=(10,6)은 2순위 →
  "top 1롤"이면 (11,6)만 굴리고 (10,6)을 stall/cap 전에 영영 안 굴릴 수 있다. 따라서 **프리픽스 = class의 *구별
  차원* 전체**:
  - **up-cell**: 활성 fall-edge/wall의 **backpath offset 전부**를 *결정론 오름차순(off↑)*으로 commit/stall 판정
    전 평가(현 `+off` _w 선호와 무관하게 offset 차원을 빠짐없이 커버). 프리픽스 인덱스 = **`off ∈
    range(min(N, len(bp)))`**(= off 0…min(N,len(bp))−1, 기존 ③ `range(min(6,len(bp)))`·① `range(min(3,len(bp)))`
    컨벤션과 동일). N = backpath 수집 *개수* 상한(reverse=4·wall=6, 5d② R3-M1; off-by-one 없음). S22 귀환
    절벽 len(bp)=4 → off 0..3 = 4롤로 유일 witness (10,6)=off2 보장 포함.
  - **ant-routing(reverse/safe_fall/cross)**: 기존 ① off=0..2 backpath 프리픽스 그대로(이미 결정론).
  - _w는 **프리픽스 *내부* 평가 순서**와 프리픽스 소진 후 잔여 예산 순서만 결정 — class *간* 독점도, class
    *내* offset 누락도 금지.
  - **구현 방향(권고, plan-review 정련)**: `solve._propose`/`eval_cands`가 후보를 (risk, class) 키로 묶어 각
    그룹의 offset-프리픽스를 인터리브 평가. **결정론**: (risk 좌표, class 키, off↑) 완전 사전식. **inert**:
    단일-class·단일-offset 리스크(기존 전 스테이지 대부분)면 프리픽스=항등 → 후보 집합·순서 byte-identical.
  - **이게 dead-end 탈출과 다양-해를 통합**: 한 class(carry-arm)가 정체해도 다른 class(cell-up)의 프리픽스가
    같은 라운드에 평가돼 greedy lock-on이 풀린다. 동시에 **여러 class/offset이 각자 클리어하면 = 다양-해**(D3 수집).
- **D3 · 다양-해 수집 (기존 forbid 재사용, 신규 메커니즘 0)**: D1+D2로 *첫* 해를 안정 발견하면, 다양-해는 기존
  `diverse.py`(5b/5c) forbid 루프가 그대로 처리 — class 발견→4요소 forbid→재탐색. **D2의 breadth가 forbid 하
  재탐색에서도 작동**해 같은 리스크의 *다른* routing 해(예 bridge+sand_mound vs floater→slide 경로)를 별 class로
  발견. 즉 다양-해는 D2의 자연 산물이지 별도 코드가 아니다. S22 의도-해(5종)는 이 경로로 *발견 시도*(stretch).
- **리스크 분류·도구 매핑 = 메타 routing 기반(하드코딩 0)**: intervention class = `_skills_by_routing` + target
  (ant/cell) 조합. 신규 도구는 메타만으로 자동 편입(D11 불변). 리스크 종류(fall/wall)는 diagnose 산출
  (reverse_targets/wall_targets) 그대로 — 새 리스크 분류기 신설 없음.

**정직 경계 / inert(byte-identical) 불변식**:
- **D1**: 인벤토리에 up-cell 스킬 없으면 미발화(byte-identical). 목표-위 fall-edge cell-up은 wall_targets와 배타
  (전방 solid 여부) → ① reverse 후보에 누출 금지.
- **D2**: 단일 intervention-class 리스크(기존 거의 전부)면 라운드-로빈=항등 → 후보 집합·순서 불변. **회귀 기준
  = selftest byte-identical**(기존 plan/solve.json git 무변경) + 기존 S19(5d②) 재발견 불변.
- break/down/jump cell 디바이스(Basher/Cutter/Digger/LeafJump) = 미커버 유지(스코프 밖, 정직 표기).

**스코프 / Acceptance (falsifiable) — S22 단순해 100% = 하드 게이트** (5d② S19 선례):
- **하드 acceptance = `solve.solve(22)`가 bridge+sand_mound로 S22를 100%(saved=7/7) 클리어.** 달성 가능성 =
  **본 de-risk로 입증**(witness `[bridge, sand_mound@(10,6)]` → 7/7 frame 2158, 후보 풀에 (10,6) 존재 확인).
  즉 하드 게이트는 *존재가 확인된 해*를 솔버가 burial 없이 자동 발견하는 것.
- **`rediscover-verify`에 stage22 추가**(산문 acceptance만으론 회귀 못 잡음, 5d② R2-MED 선례): `solve.solve(22,
  save=False)` 재발견 → cleared saved=7/7 + 액션에 cell-up(sand_mound) 포함 단언. solve 시 `stage22.solve.json`
  영속 + selftest EXPECTED 편입(frame byte-identical).
- **witness-rolled fixture(fail-closed, R1-HIGH 박제)**: D2 프리픽스가 *미명시 intra-class 랭킹 가정*에 기대지
  않음을 증명 — bridge 채택 상태에서 up-cell 프리픽스가 **stop/commit 판정 전에 `sand_mound@(10,6)`(off=2,
  유일 클리어)을 실제 롤아웃**함을 단언(현 `+off` _w라면 top=off3=(11,6)만 보장돼 누락 = FAIL). cap 예산
  내(off0..3 = 4롤)에 witness가 평가 프리픽스에 듦을 박제. 단순 "후보 풀에 (10,6) 존재"가 아니라 "평가됨"을 검사.
- **만약 cap·합리적 휴리스틱으로 100% 불가로 판명되면**: silent defer **금지** — S18식 실측 입증(어느 burial/cap
  한계인지) 후 **사용자 STOP·에스컬레이트**(재설계/재스코프/취소 결정).
- **stretch(본 게이트 아님)**: S21·S23·S24·S25 클리어 + S22 다양-해(의도-해 5종 등 ≥2 distinct class). D3로 시도
  하되 추가 routing 상호작용(slideL/slideR 경로·floater 안전낙하 체인)이 필요할 수 있어 acceptance에서 제외(정직).
- **회귀 게이트**: selftest byte-identical + `verify` frontmatter 그린 + `_selfcheck_wall_targets`(D1 확장) PASS +
  S19 재발견 불변. D2 class 인터리브 결정론(키·_w·사전식).

**리스크(plan-review 타깃)**:
- **D2 breadth ↔ 10-롤아웃 cap 긴장**: S22는 2-리스크 시퀀스(접근+귀환)라 breadth가 롤아웃을 더 쓴다. 본 de-risk가
  cap 30서도 *burial*로 실패(예산 아님)했으나, breadth 적용 시 필요 롤아웃이 cap을 넘으면 acceptance에서 드러남
  → 사용자 에스컬레이트(escape 아님). cap은 리스크 시퀀스 깊이에 맞춰야(정직 표기).
- **D2 과발화(class 폭증)**: 리스크마다 모든 routing class를 롤아웃하면 폭증. **완화 = 진단된 리스크에 *적용
  가능한* class만**(fall-edge → reverse/safe_fall/cross/up; wall → up). cap/forbid로 폭 제어가 설계 핵심.
- **D1 과발화**: 목표-위 아닌 fall-edge까지 cell-up → 예산 낭비. **완화 = per-phase 목표-위 게이트**(5d② 규약).
- **결정론**: D1 cell-up 후보 순서 + D2 class 인터리브 키 완전 결정론(좌표·진척·사전식 tie-break).
- **미결(plan-review 또는 impl 중 입증)**: 의도-해(floater→slideR→bridge→sand_mound→slideL, 5종)가 현 routing
  으로 *표현 가능*한지 손배치 미검증(slideL/slideR routing=up·ANT_ARMED). stretch라 하드 게이트엔 무영향.

---

### 5f 계약 — per-risk 보호 일반화 (S23 대표 hard-gate 승격, S21/24/25 stretch 유지) **[⛔ SUPERSEDED by §5g (2026-06-27)]**
> **⛔ SUPERSEDED 배너 (2026-06-27, 5g Round-1 HIGH-1 해소)**: 5f의 핵심 가설(F1 = cross-class burial 일반화가
> S23 mis-commit의 원인)이 **impl 스파이크로 반증**됐다(plan §"5f F1 스파이크"·STATUS: 후보 생성≠병목, greedy
> score 근시안이 병목). 따라서 **5f의 S23 hard-gate·F1 구현·§4 witness matrix·F-pre0~3 바인딩·rediscover[23]은
> 더 이상 구현 대상이 아니다** — S23 hard-gate는 **§5g(탐험-보상 plateau-crossing)로 이관**. 5f 본문은 *음성-입증
> 이력*(burial≠병목 확인 경로)으로 보존하되 **확정 구현 계약은 §5g가 유일 SoT**. 5f F1(burial) 자산은 미래에
> 실제 cross-class burial 레벨이 등장하면 재진입 가능(현 캠페인 부재 = latent). 아래 5f 본문은 이력 기록이다.
>
> 5e가 S22(귀환 cell-up burial)를 풀고 **S21·S23·S24·S25를 "추가 routing 상호작용 필요 가능"으로 stretch
> defer**했다(§5e Acceptance line "stretch"). 트리아지(cap40)로 그 defer가 확증됨 — **4개 전부 reached=0**(개미가
> candy 픽업조차 못 함, cap 부족 아님). 5f는 그중 **S23 하나만 실측 grounding 위에서 대표 hard-gate로 승격**하고
> (S22-동형 cross/reverse burial을 정준 사례로), **S21/24/25는 stretch 유지**(R1-MEDIUM 정정 — 제목·Acceptance·
> STATUS 일치). `model.py`/`solve.py`/selftest만 — 엔진/PlanRunner/게임 무변경(5e와 동일 계약면).

**0. 실측 grounding (S23 정준, 엔진 D4 trace — 가설 아닌 재현된 결함)**
S23 "부서진 배"(file23) 권위 grid(`parse_layout`):
```
       0....5....1....5....2....5   (col)
 row6  ...............###########   우측 overhang cols15-25
 row7  ####..######........######   좌 cols0-3 / 중앙 cols6-11 / 우 cols20-25 (갭 cols4-5·cols12-19)
 row15 ##################........   바닥 cols0-17
```
- home=(10,6) 중앙 플랫폼(표면 row7) 위. candy=(22,5)=우측 overhang(row6) 꼭대기 보행면 row5.
- **spawn_direction=−1(좌향)**, 9마리, candy_hp=7. 인벤토리 blocker2/bridge2/floater1/sand_mound2.
- **리스크 시퀀스**: ① 좌측 절벽(col6→col5 좌향, 물갭 cols4-5) — 좌향 spawn이라 *먼저* 도달, 물 익사. 해결=
  blocker(reverse, candy 쪽 우향 전환). ② 우측 갭(col11→col12, 갭 8칸). 해결=bridge(cross). ③ 우측 overhang
  climb(bridge 끝 col14서 col15 row6 **벽**, candy 보행면은 그 위 row5). 해결=(추정) sand_mound climb.
- **실측 failure(trace)**: blocker(col6)+bridge(col11) → 개미가 **col6↔col14 무한왕복**(`(6,6)…(14,6)…(6,6)`),
  best_min_y=row6.8 고정, picked=0, time_out. blocker+bridge+sand_mound@(14,6)도 동일(climb 미작동).
- **현 솔버**(트리아지): best plan=`['blocker','sand_mound']` reached=0 — ①blocker는 옳으나 **②에서 bridge 대신
  sand_mound로 mis-commit**. = bridge(cross)가 ②에서 burial/mis-commit된 직접 증거.

**1. 진단 — 5e D2가 안 잡는 두 결함**
- **(A) cross-class burial(5e D2 범위 밖)**: 5e `_class_prefix_protect`는 **`up_cell`만** 보호(impl: `if "up_cell"
  not in classes…`). S23 ②는 **cross(bridge)** 가 **reverse(blocker, 물-우선 water_w)** 에 _w로 눌리는 *다른*
  class 쌍 → 5e 미보호. burial은 up_cell 한정이 아니라 **임의 class 경쟁**에서 발생.
- **(B) 다중-리스크 합성**: 3+순차 리스크(①②③)에서 한 리스크 mis-commit이 하행 리스크를 trace에서 가린다
  (reached=0→②③ 안 보임). 닫힌-루프 점진 노출은 원리상 되나 (A) burial이 차단. **(A) 해소가 (B)의 상당 부분
  자동 해결**(엔진이 전진 도구 선택).

**2. 설계 (5e D1~D3 위 가산 — 신규 계약면 0)**
- **F1 · 5e D2 `_class_prefix_protect` 일반화**: up_cell 전용 게이트를 **generic non-top class 보호**로 확장 —
  한 라운드 절단(top-max_n)에서 밀린 *어느* applicable intervention class(cross·safe_fall·up_cell)의 evaluated-
  prefix를 보호. 엔진 verdict가 도구 결정.
  - **⚠ 그룹핑 = `risk × class` (R2-HIGH-2)**: 5e quota는 `_src_rank`(risk)만으로 그룹화·off↑ 정렬이라, 같은
    risk에 여러 class가 경쟁하면(S23 한 절벽에 safe_fall+cross+up_cell) off-우선 정렬이 **한 class에 quota를 몰아주고
    다른 class를 prefix 밖에 남길 수 있다**(cross starve). → 보호 quota를 **(risk, class) 2-키 그룹**으로 묶고,
    **각 (risk, applicable class)가 off=0 슬롯 1개를 먼저 받은 뒤** 라운드-로빈으로 off를 깊게 — *같은 risk의 모든
    class가 최소 1 prefix 평가*를 보장(class 간 공정).
    - **⚠ overflow 규칙 (R3-MED-2)**: "모든 class 최소 1 prefix" + "bounded ≤max_n"은 **전제: 활성 (risk×class)
      슬롯 수 ≤ max_n**일 때만 동시 성립한다. **초과 시**(슬롯>max_n) 모든 class에 1 prefix 불가 → 절대보장
      아님: **fail-closed = cap 부족 명시 경고(CHECKPOINT, F-pre3)·해당 라운드 미보장 class 정직 표기**,
      필요 시 사용자 cap 상향 승인(5e R8 cap contract). 즉 보장은 *조건부*이고 위반은 silent 아님.
    - bounded quota ≤max_n·결정론((risk좌표, class키, off↑) 사전식)·5e 라운드-로빈은 유지. **F-pre0 selfcheck가
      `reverse+safe_fall+cross` 합성 경쟁에서 cross가 실제 평가 prefix에 듦을 단언**(off-우선만이면 FAIL = prove-it).
  - **⚠ 메타데이터 선결(R1-HIGH-1)**: 현 보호 함수는 `_src_rank`/`_off`에 의존하고 그 필드는 **up_cell 후보만**
    보유(model.py:544). ①(reverse/safe_fall/cross) 후보는 `_class`/`_w`만(model.py:442). → **F-pre0(바인딩
    요구)**: ①·② 후보에도 `_risk`(=가장자리 좌표·종류)/`_off`(backpath offset)/`_src_rank`(diagnose 정렬순)
    부여 후에만 generic 보호 가능. 부여 전에는 보호 대상에서 제외(현 up_cell 한정과 동일 = inert).
  - **⚠ inert 좁히기(R1-HIGH-2)**: 5e inert는 "up_cell 없으면 보호 완전 off"(model.py:570) 가드에 기댄다.
    class-agnostic화는 S13/S14/S20(multi-class·up_cell-absent: reverse+up_armed)을 보호 발동 대상으로 만들 수
    있어 byte-identical과 충돌. → **보호 발동 조건을 명시 협소화**: ⓐ ≥2개 *서로 다른 applicable class*가 경쟁
    AND ⓑ 그중 한 class의 후보가 **전부** top-max_n 절단 밖(=완전 burial)일 때만. carry-chain(up_armed)이 자기
    _w로 절단 안에 들면 보호 무발동. **이래도 S13/S14/S20에서 발동하면 설계 오류** → F-pre2가 합성 selfcheck +
    solve.json git diff로 강제 검출(발동 시 plan 재설계, silent 통과 금지).
  - 5e 3중 가드(절단 없음/단일 class/대상 부재)를 class-agnostic으로 유지.
- **F2 · 다중-리스크 cap (구체화, R1-MEDIUM-2)**: 3+도구 합성(S13 26롤·S14 40롤 선례)을 위해 S23 hard-gate의
  **고정 command·cap**을 §5 Acceptance에 못박는다(탄력 cap 금지 — 회귀 게이트 성립). cap은 S14 선례
  **max_rollouts=40 상한**으로 고정; 그 안에 풀려야 게이트 PASS(초과 필요 시 = cap 부족 입증 후 사용자 승인,
  silent 상향 금지). F1로 mis-commit 제거 후 잔여가 순수 cap이면 입증, 휴리스틱/capability 갭이면 §3 escalate.
- **F3 · 다양-해**: 5b/5c forbid 그대로(신규 0). 풀린 스테이지 `diverse --save`.

**3. ⚠ 미확정 = overhang climb capability (정직 박제, 5f 핵심 리스크)**
S23 ③(bridge 끝 col14 row6 → overhang 꼭대기 row5 climb)이 **현 sand_mound cell-up routing으로 표현 가능한지
미검증**. 손배치 sand_mound@(14,6) 개미 미상승(best_min_y 불변). 두 갈래: **(가) 배치/메커니즘 문제**(witness
존재 → F1만으로 충분, S23 정준 게이트) / **(나) capability 갭**(witness 부재 → overhang 진입은 신규 routing
필요 = F1 밖, **본 plan STOP·사용자 escalate**). 현 솔버가 cap40서도 reached=0인 게 (나) 가능성을 배제 못 함.

**4. 구현 1단계 = S23 witness de-risk (하드 선결, falsifiable matrix — R1-HIGH-3)**
witness 확립을 impl **첫 작업**으로. 검색은 **유한 matrix**로 못박아 "불가"가 falsifiable하게 한다(엔진 변경 0,
`try_solve.py replay` 손배치):
- **고정 액션**: blocker reverse @ 좌측 절벽(`select=min_x`, `ant_reaches_x le x=312`=col6) + bridge cross @
  우측 절벽(`select=max_x`, `ant_reaches_x ge x=528`=col11). (de-risk로 발화·동선 확인됨: 개미 col6↔col14 왕복.)
- **스윕 변수 = sand_mound 배치 (결정론 finite set, R2-MED-1)**:
  - **단일 30변형**: cell `(col,row)` for `col ∈ {11,12,…,20}` × `row ∈ {5,6,7}`, **(col asc, row asc) 사전식**,
    at_frame 0.
  - **2-조합 12쌍**(단일 30 전부 `no-reach`/`no-save`일 때, 인벤토리=sand_mound2): `(c1,6)+(c2,6)` for
    **`c1 ∈ {13,14,15}` × `c2 ∈ {16,17,18,19}`**(데카르트곱 = 정확히 12쌍, `c1<c2` 항상 성립), `(c1 asc, c2 asc)`
    사전식. (c1=bridge 끝 부근 ladder1, c2=overhang 진입 ladder2 — T2 우향. row6 고정.) **총 42변형**(30+12) 고정.
- **고정 예산**: `deadline_frames=9000`, 변형당 replay 1회.
- **결과 exhaustive 분기 (R2-HIGH-1)** — 변형마다 엔진 verdict를 4-way 분류(붕 뜨는 케이스 0):
  - **`saved-witness`**: `saved≥1`(이상적 7/7) → **(가) 확정**. 첫 발견 변형을 hard-gate witness로(§5).
  - **`reach-only`**: `picked_total>0 AND saved=0` → overhang 진입은 *되나* 완주(귀환) 미확립 = **hard-gate 미충족
    이되 capability 갭 아님**. → silent 통과·STOP 둘 다 금지: **부분 진척으로 보고 + 사용자 escalate**(추가 도구/
    배치 필요 판단은 사용자).
  - **`no-reach`**: `picked_total=0`(현 baseline과 동일) → 이 변형에서 capability 미입증.
  - **`engine/error`**: replay 비정상(비-PASS·크래시) → fail-closed(재시도 1회, 지속 시 abort·보고).
- **종합 판정 (engine/error 격리 — R3-HIGH-1)**: 우선순위 순:
  1. 한 변형이라도 `saved-witness` → **(가) 확정**.
  2. `engine/error`가 **1개라도** 남으면(재시도 1회 후에도) → capability gap 판정 **금지**: **fail-closed abort +
     사용자 escalate**(미완 측정이 (나)로 둔갑 차단). gap 결론은 **42개 모두 정상 replay**가 전제.
  3. (42개 모두 정상 replay 전제) `saved-witness` 0 AND `reach-only` ≥1 → 부분 capability 입증·완주 미확립 →
     사용자 escalate.
  4. (42개 모두 정상 replay 전제) **42변형 전부 `no-reach`** → **(나) capability 갭 입증** → silent defer 금지
     (5d② R1) → 사용자 STOP·escalate(overhang routing 신설/재스코프/취소는 사용자 결정).
- **artifact**: 각 변형 `scratchpad/s23_witness_<spec>.plan.json` + 결과표(변형·saved·picked·reason·분류)
  `phases/solver/reviews/phase05-impl-review.md`(`## 5f witness de-risk` 헤더)에 전수 박제(투명).

**5. Acceptance (falsifiable)**
- **하드 게이트(고정 command·cap, R1-MEDIUM-2)**: §4 witness `(가)` 확정 후 **`try_solve.py search 23
  --max-rollouts 40`** → `solve.solve(23)` **saved=7/7**(F1 burial-fix 자동발견, cap40 상한 내) →
  `stage23.solve.json` 영속 + **selftest EXPECTED에 23 편입**(frame byte-identical) + **rediscover[23]**(재발견
  cleared+액션 시그니처 일치). witness 미확립 시 §3 escalate(게이트 보류, 사용자 결정).
- **stretch(게이트 아님)**: S21/24/25 자동발견 + 다양-해(F3). 미해결은 정직 보고(reached/picked·burial vs cap vs
  capability 구별).
- **inert(회귀 0, F1 협소화 검증)**: 기존 S11~S22 solve.json **byte-identical**(F1 발동 조건 ⓐⓑ 미충족 → 무발동).
  특히 **S13/S14/S20(multi-class·up_cell-absent)에서 F1 무발동을 명시 검증**(R1-HIGH-2). selftest/analyze/diverse/
  rediscover 전 게이트 그린·EXIT 0. 5e inert 실측(S19 8롤·S13 26·S14 40·S20 31 git diff 0) 재확인.

**6. 구현 바인딩 요구 (plan-review 산출 선반영)**
- **F-pre0(메타데이터+공정성, R1-HIGH-1·R2-HIGH-2)**: ①(reverse/safe_fall/cross)·② 후보에 `_risk`/`_off`/
  `_src_rank` 부여 후에만 generic 보호 적용(메타 부재면 보호 불가 = inert). **fail-closed selfcheck 2종**:
  ⓐ S23 synthetic(cross가 reverse _w에 눌려 top-max_n 밖)에서 cross의 risk/off prefix가 **실제 평가 프리픽스에
  듦** 단언(메타 부여 전엔 FAIL = prove-it). ⓑ **3-class 공정성**: 같은 risk에 `reverse+safe_fall+cross`가
  경쟁하고 cross가 _w 꼴찌일 때, `risk × class` 그룹핑이 cross에 off=0 슬롯을 보장(off-우선 정렬만이면 cross
  starve = FAIL). 두 selfcheck PASS가 F1 구현의 acceptance 일부.
- **F-pre1(witness)**: §4 finite matrix(**42변형 = 30단+12쌍**)를 impl 1단계 강제. **판정은 §4 4-way 종합 판정**
  (saved-witness/reach-only/no-reach/engine-error)을 그대로 따른다(요약하지 않음 — reach-only·engine/error 보존).
  witness JSON + 엔진 verdict 첨부. saved-witness 0 시 §4 종합 판정대로 escalate/STOP(hypothetical acceptance
  HIGH 선반영, falsifiable).
- **F-pre2(F1 inert prove-it, R1-HIGH-2)**: 일반화가 byte-identical 안 깸 — ⓐⓑ 발동 조건 합성 입력 selfcheck
  (단일-class·carry-chain 절단-안 케이스 무발동) + **S11~S22 solve.json git diff 0**(특히 S13/S14/S20 multi-class·
  up_cell-absent 무발동 명시). **발동 검출 시 plan 재설계**(silent 통과 금지). up_cell→generic 확장이라 회귀 표면 큼.
- **F-pre3(bounded quota 충분성)**: 다중-class·다중-risk 동시 경쟁 cap 부족 명시 경고(5e R8 cap contract), starve
  합성 입력 selfcheck 박제.

**정직 경계**: break/down/jump cell 디바이스 미커버 유지. S18(별 휴리스틱 트랙)·S20(carry-mirror latent) 무관.
5f는 5e 계약면(model.py/solve.py/selftest) 동일 — 엔진/게임 무변경.

### 5g 계약 — 탐험-보상 plateau-crossing 검색 (S23 anti-greedy 해 자동발견) **[구현 de-risk 후 S23 재스코프 — 2026-06-28]**
> **⚠ 재스코프 배너 (2026-06-28, 사용자 결정 — de-risk 6회 후)**: plan-stage는 R1→R3 STOP→사용자 "완화 후 구현
> 진입"으로 종결. 구현 1단계(S23 자동발견 de-risk)에서 ②+③ beam(skill-diverse + progress-aware stepping-stone rank)
> + placement refinement를 6회 정련했으나 **S23 정확한 생존-배치 witness 자동발견 실패**(picked=7 전원 candy 도달
> "모양"엔 도달하나 picked=7-alive 정확 배치 미조립, picked=7-die 국소최적 지배 = 솔버 capability 한계). **레벨은
> 풀림**(witness `stage23.witness.json` 엔진검증 saved=7/7). → **사용자 결정 = S23 hard-gate 철회·재스코프**:
> ① **S23 = stretch(자동발견 open 하드문제), hard-gate 아님**. 오라클 목적("풀리는가")엔 witness 채택으로 충분.
> ② **②+③ beam 개선은 보존**(inert: Phase A clear 스테이지는 Phase B 미진입 → byte-identical, 다른 미해결
> 스테이지엔 도움 가능). ③ 트레일 = `reviews/phase05-impl-review.md ## 5g de-risk 진행`(6회 progression 박제).
> 아래 §1~6 설계 본문은 *시도된 메커니즘의 이력*으로 보존(특히 §5 "하드 게이트"는 철회됨 — S23은 stretch).
> 5f F1(burial 일반화)은 **필요·불충분**으로 판명(스파이크: 후보 생성 ≠ 병목, greedy score 근시안이 병목, plan
> §"5f F1 스파이크"·STATUS). 사용자 결정(AskUserQuestion 2026-06-27) = 검색 전략 재설계 중 **"② 구조-탐험 보상
> score"**. 5g는 그 ②의 정식 계약이다. `model.py`/`solve.py`/selftest만 — 엔진/PlanRunner/게임 무변경(5e/5f 계약면 동일).
> **타깃 = `data/solutions/stage23.witness.json`**(엔진 검증 saved=7/7, anti-greedy 5액션 — floater→blocker→
> sand_mound×2→bridge)을 솔버가 자동 발견.

**0. 실측 grounding (de-risk 스파이크, 엔진 D4 — 2026-06-27, 가설 아닌 재현된 측정)**
S23 baseline `search 23`(무seed): 솔버가 표면 경로 `blocker(6,6)+bridge(11,6)`에 greedy-commit 후 정지
(reached=0). ⚠ **이 경로에서 제안된 sand_mound 후보는 전부 좌측/중앙 표면(col2~11)** — witness 셀 (15,14)·
(19,10)은 **미노출**. 추가 seed 스파이크 2건(임시 env-gated seed, 측정 후 revert·solve.py git clean):
- **(S0) floater seed → 닫힌-루프가 witness 셀 전부 노출**: `search 23`에 floater seed 시 rollout 17에
  `sand_mound@(15,14)`, rollout 23에 `sand_mound@(19,10)`, rollout 6에 `blocker@(0,14)` **전부 제안**. → **후보
  생성은 floater 분기 위에서 완비**(STATUS "후보 완비"는 witness 분기 한정이 맞음; greedy 표면 분기에선 미노출).
- **(S1) witness prefix gradient (cells_explored = visited cell 합집합 크기)**:
  | prefix | picked | saved | goal_dist | highest_row | **cells_explored** |
  |---|---|---|---|---|---|
  | `[]` | 0 | 0 | 13 | 6 | 14 |
  | `floater` | 0 | 0 | **13(평평)** | 6 | **24** |
  | `floater,blocker` | 0 | 0 | **13(평평)** | 6 | **30** |
  | `+sand(15,14)` | 0 | 0 | 8 | 6 | **42** |
  | `+sand(19,10)` | **7** | 0 | 5 | **5** | **74** |
  → **`goal_dist`는 첫 2단계(floater·blocker) 평평(13) → greedy·LA2(frontier=goal_dist) 거부**. 반면
  **`cells_explored`는 단조 증가**(14→24→30→42→74) = witness 체인을 가리키는 결정론 gradient. **②의 신호 = 탐험
  프론티어**임이 실증.
- **(S2) 분기점 문제**: floater는 round 7에서 blocker(국소 goal_dist 우월)에 밀려 거부; 일단 표면 blocker로
  commit하면 개미가 좌측 갭(cols4-5)에 도달 못 해 **floater 경로가 영영 차단**(surface-commit 분기는 좌측-하강
  route 미도달). → **stall-only-from-best 복구 불가**(stall 시점 best=표면 분기). floater를 *분기에서* 살리려면
  greedy를 벗어난 **breadth(백트래킹/best-first)**가 필요.

**1. 진단 = 3중 결함 (5f F1로 안 풀리는 이유)**
- **(A) plateau**: witness는 goal_dist 평평한 **2-step 구간**(floater→blocker)을 건너야 gradient(sand)가 나타남.
  greedy(1-step)·LA2(2-step, frontier=goal_dist)로는 평평 구간을 못 넘음.
- **(B) 분기 commit**: floater는 stall이 아니라 **정상 greedy 진행 중** blocker에 밀려 거부됨(round 7) →
  stall-시점 복구로는 도달 불가. 분기를 살리는 breadth 필요.
- **(C) 신호 부재**: 현 score(saved>retired>picked>trapped>goal_dist)·LA frontier(goal_dist)는 **탐험 진척
  (frontier 확장)을 0 보상** → 평평 구간의 디딤돌과 헛 배치를 구별 못 함.

**2. 설계 — 탐험-우선 fallback 검색 (inert overlay, 2-phase)**
> 핵심 = **메인 greedy+LA2 루프 불변**(Phase A, solved 스테이지 byte-identical) + **clear 없이 종료 시에만**
> 발동하는 **탐험-우선 best-first fallback**(Phase B). 5e/5f의 "기존 경로 inert + 신규 조건부 층"과 동형.
- **탐험 신호 `frontier(trace)`**(model.py 신규, 순수): 트레이스 전 개미 visited cell `{(cx,cy)}` 합집합 크기.
  결정론·좌표 비의존. ⚠ **격하(R1-LOW)**: frontier는 *전역 품질 metric이 아니라* **S23 de-risk에서 유효성이
  실증된(§0 단조 14→24→30→42→74) Phase B 전용 bounded tie-break 신호**다 — `score`를 대체·우선하지 않으며
  Phase A는 frontier를 **전혀 안 본다**(inert). 왕복/루프가 frontier를 키울 수 있음은 알려진 한계(§5 stretch 구별
  보고) → Phase B의 *탐색 순서* heuristic이지 해의 *품질* 판정이 아님(품질=엔진 verdict).
- **Phase A (decision/rollout semantics 불변 + passive harvest, R3-HIGH-1 해소)**: ⚠ R3-HIGH-1 정확 — Phase B
  seed 풀은 Phase A가 평가한 미채택 후보(frontier 확장분)를 **수집(harvest)**해야 하므로 "literally 코드 미변경"은
  불가능한 과장(seed harvest와 모순). → 정직한 계약 = **Phase A의 *결정·롤아웃 의미*(후보 생성·순서·tie-break·
  accept 조건·rollout 수·채택 plan·`_main_cap`·`LA2_RESERVE`·`tried`·`break`)는 byte-identical로 불변**하되, 그 위에
  **read-only passive harvest side-channel** 허용: `eval_cands`가 **이미 계산한** `res`에 대해 `frontier(res.trace)`를
  *읽어* seed 풀에 append만 한다(추가 롤아웃 0, Phase A 어떤 분기·순서·채택에도 영향 0). harvest는 부수효과 없는
  순수 관찰 → byte-identical은 "코드 미변경 trivially"가 아니라 **G-pre1 solve.json git diff 0으로 실증**(엄밀화).
  clear면 `_Clear`.
- **Phase A → Phase B 인계 (예산 = 별도 가산, R1-HIGH-2 + R2-HIGH-1 해소)**: ⚠ R2-HIGH-1이 정확히 지적 —
  Phase A를 `max_rollouts - PHASE_B_RESERVE`로 **split하면** `_main_cap`/`LA2_RESERVE`(solve.py:39~67)와 이중
  차감·잠식 충돌해 solved stage Phase A 거동이 바뀐다(inert 깨짐). → **split 폐기. Phase B는 Phase A와 분리된
  *별도 가산 예산* `PHASE_B_BUDGET`(고정 상수, §5)**: Phase A는 종전대로 `max_rollouts`를 **그대로** 쓰고(어떤
  종료 경로든 — (i) no-progress break solve.py:408 OR (ii) `rollouts>=max_rollouts` 소진), **clear 없이 끝나면**
  Phase B가 **별도 `PHASE_B_BUDGET` 롤아웃**으로 이어받는다. → `_main_cap`/`LA2_RESERVE`와 **무간섭**(Phase A 산식
  불변), Phase A는 **byte-identical trivially**(코드 미변경). 총 롤아웃 상한 = `max_rollouts + PHASE_B_BUDGET`
  (콘솔에 두 phase 예산 분리 보고 — `--max-rollouts`는 종전 의미[Phase A cap] 유지, Phase B는 신규 상수). solved
  스테이지는 Phase A서 `_Clear` → Phase B 미진입(예산 0 소비).
- **Phase B (신규, fallback best-first)**: `PHASE_B_BUDGET` 예산 내 탐험-우선 검색. **node = `(plan, trace,
  frontier_size, score, local_excluded)`**:
  - **seed 풀 = novel-reject + baseline**: "novel-reject" 정의 명확화(R1-HIGH-5) = **Phase A의 `eval_cands`가
    평가했으나 `score`로 미채택된 후보** 중 **`frontier(res.trace) > frontier(그 평가 시점 base.trace)`**(=프론티어
    확장)인 것을 `(base_plan, action, res_frontier, score)`로 기록. floater(round7)는 base=[] 대비 frontier 14→24
    확장이라 **반드시 기록됨**(G-pre4 prove-it로 박제). 기록은 main eval·LA2 eval 양쪽(평가된 전 후보 대상).
  - **seed pool deterministic bound (R2-MED-2 — pool noise 억제)**: novel-reject는 unsolved stage의 루프/왕복
    trace로도 부풀 수 있다. → **`SEED_POOL_CAP` = `(base_plan_sig, _class)`별 frontier desc 상위 K**(고정값 §5,
    결정론 정렬: frontier desc·score asc·action 사전식)만 seed 풀에 보존. floater 같은 고-frontier 디딤돌은 보존
    되는 경향이나 **"항상 살림"을 수학 증명하지 않는다(R3 격하)** — 대신 **G-pre4가 S23 floater 시드 부재 시 FAIL**로
    박제. noise tail은 cap. seed count·class histogram을 G-pre4 산출물에 박제(pool 폭발 가시화).
  - **best-first 큐**: 우선순위 = ⓐ clear ⓑ frontier_size desc ⓒ score asc ⓓ 결정론 tie-break(plan-signature 사전식).
  - **expand**: pop → 그 plan 재진단 → propose·평가(엔진 D4, 1롤/후보, `PHASE_B_BUDGET` 차감) → clear면 즉시
    save·종료 / 아니면 frontier 확장 후보만 큐 push(확장 0 미push).
  - **branch-local exclude (R1-HIGH-3)**: Phase B는 **Phase A 전역 `tried`를 상속하지 않는다**(다른 branch 동일
    label suppress 방지). 각 node가 자체 `local_excluded`(그 plan에서 이미 expand한 action label) 보유 + **canonical
    plan-signature memo**(전역, 순서무관 multiset sig)로 **중복 plan expand 차단**(loop 방지 근거를 `tried`가 아닌
    plan-sig memo로 이전). Phase A `tried`는 Phase B에서 seed provenance로만(미상속).
    - **⚠ memo vs floater-first signature 비충돌 (R2-MED-1)**: memo는 순서무관 multiset이라 "같은 multiset이 다른
      order로 먼저 memo 처리되면 floater-first가 suppress될까" 우려가 있으나 — best-first 큐가 **frontier desc 우선**
      이고 floater seed가 base=[]에서 frontier 최고 디딤돌이라 **floater-first 노드가 등가 multiset의 다른 order보다
      먼저 pop·expand**된다(클리어 발견 시 그 노드의 construction provenance가 저장). memo는 *재방문*만 막지 *첫
      발견 경로*를 못 바꾼다. → floater-first signature는 construction artifact가 아니라 best-first 탐색 순서의 산물
      (G-pre5가 provenance로 단언).
  - **종료성 (R1-HIGH-4, frontier ≠ 주 증거)**: 3중 경계 — (1) **`PHASE_B_BUDGET` 롤아웃 cap**(주 경계, 단독으로
    유한 종료 성립) (2) **explicit depth cap `MAX_PLAN_LEN`**(= Σ inventory action 수, plan 길이 상한 — completeness/
    sequence 폭발 억제) (3) **canonical plan-sig memo**(중복 expand 0). frontier 단조는 push *pruning heuristic*이지
    종료 증거 아님(R1-HIGH-4 직시). (1) 단독으로 유한 보장, (2)(3)은 효율·완전성.
  - **결정론**: 큐 우선순위·tie-break·propose·memo·seed-cap 순서 전부 결정론(5e/5f 동일 기준).
- **inert 불변식**: Phase B는 Phase A가 **clear 없이 종료**(break OR max_rollouts 소진)할 때만 발동. 기존 solved
  스테이지(S11~S22)는 Phase A서 `_Clear` → Phase B 미진입 → **solve.json byte-identical**. ⚠ **R2-HIGH-1 해소**:
  예산 split 없음(별도 가산) → `_main_cap`/`LA2_RESERVE` 무간섭(이중차감 부재). **R3-HIGH-1 해소**: harvest는
  read-only(Phase A 결정·순서·롤아웃 불변)라 byte-identical 유지 — 단 "trivially"가 아니라 **G-pre1 solve.json git
  diff 0으로 실증**(harvest가 결정에 누출되면 git diff로 검출 → STOP). Phase A의 frontier 읽기는 채택에 미참여.

**3. ⚠ 미확정 = Phase B가 cap 내 witness를 조립하는가 (5g 핵심 리스크, 정직 박제)**
de-risk가 입증한 것: ① witness 존재(saved=7/7) ② 후보 완비(floater 분기) ③ frontier 단조 gradient. **미입증**:
best-first가 **유한 cap 내** floater→blocker→sand(15,14)→sand(19,10)→bridge **조합을 실제 조립**하는지(프론티어
풀 폭발 가능성). → **구현 1단계 = S23 자동발견 de-risk(하드 선결)**: 합리적 cap(아래 §5 고정값)에서 saved=7/7
재현. 불가 판명 시 **silent defer 금지**(5d② R1 정책) → 실측 입증(어느 단계서 cap·풀 폭발) 후 **사용자 STOP·
escalate**(beam 폭·cap·휴리스틱 재설계는 사용자 결정).

**4. 구현 1단계 = S23 자동발견 de-risk (하드 선결, falsifiable)**
- `try_solve.py search 23 --max-rollouts <N>`(N = §5 고정) → `solve.solve(23)` **saved=7/7** 자동발견.
  Phase B가 frontier-우선으로 floater 분기를 살려 witness(또는 동치 클리어 해) 조립. 콘솔에 Phase B 진입·
  frontier 풀 크기·채택 경로 박제.
- **결과 분기(정직)**: ⓐ saved=7/7 → 하드 게이트 충족(§5). ⓑ saved<7 cap 소진 → §3 escalate(프론티어 풀
  크기·미조립 단계 트레이스 첨부). ⓒ engine/error → fail-closed(재시도 1회, 지속 시 abort·보고).
- artifact: 자동발견 해 + 엔진 verdict를 `phases/solver/reviews/phase05-impl-review.md`(`## 5g …` 헤더)에 박제.

**5. Acceptance (falsifiable)**
- **고정 상수 (구현 전 명시 — R2-HIGH-1·R2-MED-2)**: `PHASE_B_BUDGET = 60`(Phase A `max_rollouts`와 별도 가산;
  witness 5액션 best-first 조립 여유, S23 de-risk로 충분성 입증 — impl 1단계가 falsify) / `SEED_POOL_CAP = 8`
  ((base_sig,_class)별 frontier-top K) / `MAX_PLAN_LEN = Σ inventory action 수`(S23=blocker2+bridge2+floater1+
  sand_mound2 = 7). 전부 falsifiable gate 상수 — 부족 입증 시 사용자 승인(silent 상향 금지).
- **⚠ S23 하드 게이트 = 철회됨(2026-06-28 재스코프, §5g 헤더 배너)**: 아래 "하드 게이트" 서술은 de-risk 전 설계
  의도이며 **S23은 stretch로 강등**(자동발견 미달, witness로 풀림 입증). 실제 구현 상수도 de-risk로 갱신됨(PHASE_B_BUDGET
  360·BEAM_WIDTH 10·REFINE_BUDGET 160 — 위 60은 초기 추정). beam은 **inert 보존 자산**(아래 inert 항목)으로 잔류.
- **(이력) 하드 게이트(고정 command)**: `try_solve.py search 23 --max-rollouts 40` **+ Phase B 별도 가산** → saved=7/7.
  cap = **product acceptance threshold이지 설계 충분성 근거 아님(R1-MEDIUM-2)** — de-risk가 falsify(needle 미조립).
  - **메커니즘 signature 단언(R1-MEDIUM-1·R2-MED-1 — 우연 greedy clear 오인 차단, 결정론 predicate)**: 단순
    "saved=7/7"이 아니라 코드-판정 가능 predicate 동시 충족 — **(a) `phase_b_entered == true`**(Phase A clear 실패 후
    Phase B가 푼 것, 결과 dict flag) AND **(b) Phase B seed provenance: 채택 해의 Phase B 시드 노드가
    `seed.plan == [] AND seed.action.skill == "floater"`**(=floater-first 디딤돌에서 출발) AND **(c) 최종 plan
    multiset = `{floater:1, sand_mound:2, bridge:≥1}` 포함**. **(b)는 construction order가 아니라 best-first 시드
    provenance**(memo-suppression 무관, R2-MED-1) — floater가 *어느* bottom-route보다 앞임을 시드 출발점으로 박제.
    byte-동일 불요(5d②/5e 선례, witness=존재증명·회귀 기준)이나 메커니즘 signature는 필수(plateau-crossing 검증).
  - 영속: `stage23.solve.json` + **selftest EXPECTED[23]**(frame byte-identical) + **rediscover-verify[23]**(재발견
    cleared + 위 (a)(b)(c) signature 단언).
- **inert(회귀 0)**: 기존 S11~S22 solve.json **byte-identical**(Phase B 미발동). selftest/analyze/diverse/
  rediscover 전 게이트 그린·EXIT 0. 5e/5f inert 실측(S19 8롤·S13 26·S14 40·S20 31·S22 16 git diff 0) 재확인.
- **종료성(falsifiable, R1-HIGH-4)**: Phase B가 **3중 경계**(PHASE_B_BUDGET 롤아웃 cap·MAX_PLAN_LEN depth cap·
  canonical plan-sig memo)로 유한 종료 — frontier 단조는 push pruning일 뿐 종료 주증거 아님. **selfcheck**: ⓐ
  frontier 확장 0인 합성 입력서 push 없이 즉시 종료 + ⓑ depth cap 합성 입력서 MAX_PLAN_LEN 초과 plan 미expand +
  ⓒ memo가 중복 plan-sig 재expand 차단.
- **실패 시 최소 진단(R1-MEDIUM-2)**: saved<7 cap 소진 시 **Phase B seed count·popped nodes·depth별 frontier max·
  witness-prefix 최근접 node·cap 소진 위치**를 로그·박제(§3 escalate 근거). silent defer 금지(§4 ⓑ).
- **stretch(게이트 아님)**: S21/24/25 자동발견 + 다양-해(5b/5c forbid 재사용, 신규 0). 미해결은 정직 보고
  (frontier 풀 폭발 vs cap vs capability 구별).

**6. 구현 바인딩 요구 (plan-review 산출 선반영 슬롯)**
- **G-pre0(frontier 함수 결정론·일반성)**: `frontier(trace)` 순수·결정론 selfcheck(동일 trace → 동일 set;
  좌표 비의존). S23 비특화 — 합성 trace로 단조성 단언.
- **G-pre1(inert prove-it, R1-HIGH-2·R2-HIGH-1·R3-HIGH-1)**: Phase B 미발동 + harvest read-only = byte-identical —
  ⓐ Phase A clear 합성 입력서 Phase B 미진입 selfcheck + ⓑ **S11~S22 solve.json git diff 0**(특히 다중-액션
  S13/S14/S20/S22). ⚠ 예산 split 없음(별도 가산)이라 `_main_cap`/`LA2_RESERVE` 무간섭(R2-HIGH-1); harvest는
  read-only라 Phase A 결정·롤아웃 불변(R3-HIGH-1) — 단 **"trivially" 주장 폐기, ⓑ git diff 0이 byte-identical의
  유일 권위 증거**(harvest가 결정에 누출되면 diff로 검출). drift 검출 시 plan 재설계(silent 통과 금지).
- **G-pre2(종료성 3중 경계, R1-HIGH-4)**: §5 종료성 selfcheck ⓐⓑⓒ(frontier 확장 0 즉시 종료 / MAX_PLAN_LEN
  depth cap / canonical plan-sig memo 중복 차단) + cap 경계 박제.
- **G-pre3(branch-local state 계약, R1-HIGH-3)**: Phase B node가 **branch-local exclude + canonical plan-sig
  memo**를 쓰고 **Phase A 전역 `tried` 미상속**임을 selfcheck로 박제 — 합성: 두 branch가 같은 label 후보를 각자
  expand 가능(전역 `tried` 상속이면 한 branch가 suppress = FAIL) + 같은 plan-sig 재방문은 memo가 차단.
- **G-pre4(floater seed prove-it, R1-HIGH-5)**: "novel-reject" 정의(§2: Phase A 평가됐으나 score 미채택 AND
  frontier 확장)가 **S23 floater(round7, base=[] 대비 14→24)를 실제 pool에 넣음**을 **S23 de-risk 로그로 단언**
  (합성 trace보다 실패 모드 직격) — Phase B seed pool에 floater action 부재 시 FAIL. §4 de-risk 산출물에 pool 내용 박제.
- **G-pre5(witness de-risk + 메커니즘 signature predicate, R1-MEDIUM-1·R2-MED-1)**: §4 하드 선결을 impl 1단계
  강제. saved=7/7 + §5 메커니즘 signature 결정론 predicate (a)`phase_b_entered` (b)Phase B 시드 provenance
  `seed.plan==[] AND seed.action.skill=="floater"` (c)multiset `{floater:1,sand_mound:2,bridge≥1}` 동시 충족.
  (b)는 best-first 시드 provenance라 memo-suppression 무관(construction order 아님). 미달 시 §3·§4 종합 판정대로
  escalate/STOP(hypothetical acceptance HIGH 선반영, falsifiable).

**정직 경계**: break/down/jump cell 디바이스 미커버 유지. S18(별 휴리스틱)·S20(carry-mirror latent) 무관. 5g는
5e/5f 계약면(model.py/solve.py/selftest) 동일 — 엔진/PlanRunner/게임 무변경. **5f F1(burial 일반화)과의 관계**:
5f는 *후보가 절단에 밀리는* burial을 풀고, 5g는 *후보는 평가되나 score가 평평 구간서 거부하는* 근시안을 푼다 —
직교(5f는 본 스파이크로 burial≠병목 확인돼 보류, 5g가 실병목 타깃). 둘 다 동일 계약면이라 충돌 없음.

---

## Phase R — 정식 RL 솔버 (병행 실험 트랙) **[설계 · plan-review 대상, 2026-07-03]**

> **배경(사용자 결정 2026-06-24)**: 휴리스틱 closed-loop 솔버(Phase 2~5)와 별개로 **정식 강화학습(RL)** 경로를
> 연다. 목적 = **학습/실험 그 자체**(비효율 감수) — 오라클 생산 실용성은 Phase 5 휴리스틱 트랙이 계속 담당하고,
> Phase R은 "이 도메인에서 학습이 되는가/어떻게 되는가"를 실험한다. LLM-기반·경량 셀시뮬 재구현은 검토 후 기각
> (sim-to-real gap = D1 위반). 환경 관문(throughput)은 spike로 해소 완료: **persistent Godot 환경(커밋
> `f637a24`)** — `tests/PlanServerHarness.gd`(TCP NDJSON 서버) + `tools/solver/env.py`(`GodotEnv` reset/step),
> persistent 6회+단발 byte-identical · warm 0.46s/롤아웃 · free-port+pid격리 save = 병렬 env 구조 확보.

### 계약면 (기존 자산 보존 — Phase 5와 직교)
- **신규 = `tools/solver/rl/` 전용 패키지**(학습 코드). **엔진/PlanRunner/게임/env.py 무변경**(env.py 가산이
  꼭 필요하면 byte-identical 회귀 조건으로 최소 허용).
- `model.py`/`solve.py`/`try_solve.py`/게이트(verify 프론트매터) **무변경** — RL은 휴리스틱 솔버와 코드·게이트
  커플링 0. 단, 레이아웃 파싱은 `model.py`의 파서를 **read-only import 재사용**(중복 구현 금지).
- RL 산출 plan은 `data/solutions/stageNN.rl.json`(witness 계열 명명) — selftest glob(`*.solve.json`) **비대상**.
  학습은 확률적이라 게이트 편입 부적합; 산출 best plan의 결정론 replay 검증은 R0 acceptance에 포함하되 게이트 밖.
- 의존성: **PyTorch**(2.12.1, Python 3.14 설치 확인 완료) — auto-solver 트랙 한정 dev 의존성(게임 빌드 무관).
  `rl/`은 torch를 **lazy import**(미설치 환경에서 기존 도구 무영향).

### MDP 정의 (R0 확정)
**에피소드 = plan 구성(construction) MDP.** 스텝마다 partial plan에 액션 1개를 추가하거나 SUBMIT을 고른다
(스텝 0의 SUBMIT은 마스킹 = 최소 plan 길이 1 — 빈 plan은 유효 해가 아니며, 보상 0의 빈 plan이 음수-보상
탐험을 이기는 collapse attractor가 됨을 스모크로 실측).
SUBMIT(또는 인벤토리 소진·길이 상한) 시 완성 plan을 GodotEnv 롤아웃 1회로 평가 → **terminal reward**. 중간
스텝은 Godot 호출 0 (에피소드당 롤아웃 1회 = warm 0.46s → 단일 env ~7k eps/h, N병렬 ×N).

- **관측 s_t**: ① 레이아웃 그리드 one-hot(H×W×C — 타일 종류 + candy/home/spawn 마커) ② 인벤토리 잔량 벡터
  ③ partial plan 인코딩(슬롯 K × 액션 피처). 단일 스테이지 오버핏에선 ①이 상수지만 R1(일반화) 대비 아키텍처에 포함.
- **액션 a_t (factored discrete)**: `(skill, trigger_type, cmp, param, y_row, select, state)` 독립 categorical
  head + SUBMIT. R0 어휘(의도적 축소, D5 트리거-추상 유지): skill ∈ 스테이지 인벤토리 / trigger ∈
  {`ant_reaches_x`(x=col×48+24 — **셀 센터**; known S11·S12 해의 x값 4개 전부 이 격자에 정확 일치, 구현 시 확인)
  , `picked_ge`(n)} / **cmp ∈ {ge, le}**(R1-H2 — S12 해가 le×2 요구) / param ∈
  col 0..W-1 또는 n 1..hp_stage / **y_row ∈ {any} ∪ {0..H-1}**(row→`y_min/y_max` 밴드 변환; S12 해가 3개 밴드
  요구) / select ∈ {max_x, min_x} / **state ∈ {any, walker, carrying}**(PlanRunner 기본 state=walker 정합).
  **ant-target 스킬만**(cell-target·나머지 트리거 어휘 = R1). joint log-prob = Σ head log-prob(parameterized
  action space 표준 처리). 무효 조합(발화 실패)은 페널티가 아니라 낮은 reward로 자연 도태(엔진이 안전 무시 —
  golden 음성 플랜 선례). y_row 밴드 변환식 = `y_min=row×48, y_max=(row+1)×48`(1행 밴드). 기존 임의 밴드 →
  row 변환은 결정론(R3-M): **원 밴드와 겹침(overlap) 최대 row, 동률이면 낮은 row** 선택 + 선택 row 기록.
  **문법 커버리지
  검사(R1-H2·R2 정밀화)**: known S11·S12 해(solve.json)를 이 문법의 **가장 가까운 격자 인코딩**으로 변환한 plan이
  엔진 리플레이에서 **클리어(saved==hp_stage)** 되는지 검증(스테이지당 롤아웃 1회 — known 해의 y밴드가 문법
  격자와 정확히 일치하지 않을 수 있으므로 byte-단위 인코딩이 아니라 엔진-등가로 판정). 미클리어 = 문법이 목표
  해를 표현 못 함 = 학습 이전에 FAIL.
- **보상(terminal — 형태 확정, 계수만 R0 튜닝 자유; acceptance는 결과로만 판정)**:
  `R = 2·cleared + (saved + 0.3·picked_total − 0.2·lost)/hp_stage − 0.02·len(plan)`, timeout/error verdict 시
  cleared·saved 항 0 + 고정 timeout 페널티(−0.1), picked shaping은 유지.
  **정규화 분모 = `hp_stage`(스테이지 상수, env 셋업 시 StageData에서 1회 확정) — result의 `hp` 필드 미사용**
  (R1-H1: PlanRunner가 deadline verdict를 `hp=-1`로 보고 → 음수 분모 오염 차단).
  saved/picked_total/lost는 SOLVER_RESULT 필드 그대로(trace 불요 = 롤아웃 경량 유지). 주의(R1-M1): 이는
  `solve.score`의 신호 계열과 **유사하나 등가 아님** — score()는 trace 파생 `retired`/`goal_dist`를 쓰고,
  `lost`(ScoreSystem 카운터)는 retired/trapped와 다른 집계다. R0는 의도적으로 trace-free 경량 신호만 쓴다.
- **알고리즘**: **REINFORCE + 러닝 평균 baseline**(손수 구현 — 학습 목적에 부합) → 불안정 실측 시 PPO-clip 승격
  (fallback 명시, 사전 결정). 네트워크 = MLP(그리드 flatten + 벡터 concat)로 시작, CNN 인코더는 R1.
  seed 기록(환경은 결정론이므로 같은 seed → 학습 곡선 재현).
- **병렬화**: `GodotEnv` N개(free-port 격리) + 스레드 수집(step이 소켓 블로킹 I/O라 GIL 무관).
  **병렬 preflight(R1-M3, spike 미증명 갭)**: spike는 단일 persistent env 반복만 증명 → R0 구현 1단계에서
  N=4 env 동시 부팅 + 동일 plan 각 2회 = **전부 byte-identical** 확인 후에만 병렬 수집 사용. `_free_port`
  race(소켓 close 후 Godot re-bind)는 부팅 실패(listen err → quit(2) → `exited during boot`) 감지 시
  **클라이언트-측 새 포트 재시도**(env.py 무변경, rl/ 쪽 wrapper)로 흡수. preflight 실패 시 N=1 폴백(정직 보고).

### R0 — 파이프라인 증명 (S11 오버핏 + S12 stretch) **[✅ 완료 2026-07-03 — S11 3/3 seed 오버핏(`d7d3352`), S12 stretch 0/3 정직 FAIL(`dc68a47`) → §R1]**
- 산출: `tools/solver/rl/`(mdp/정책/학습 루프 — 파일 분할은 구현 재량, 과분할 금지) + **`requirements.txt`**
  (torch 핀, R1-L1) + 학습 곡선(json), `data/solutions/stage11.rl.json`(best plan + expect + seed·하이퍼·에피소드 수).
- 학습용 `deadline_frames`는 축소 cap(S11 clear=1562f → 3000f) — 무의미 plan이 deadline까지 도는 낭비 절감.
  주의: cap은 **학습 중에만** — acceptance 판정 replay는 표준 deadline(7000f)으로 실행(축소 cap 거짓음성 차단).
- **Acceptance (falsifiable — 고정 커맨드/설정, R1-H3·R2 정밀화)**:
  1. **무힌트**(휴리스틱 `model.propose` 미사용 — 후보 시드 0) RL 학습이 **S11 클리어 정책** 도달.
     **고정 실행(단일 커맨드, R2-H)**: `python tools/solver/rl/train.py --stage 11 --seeds 0,1,2 --envs 4
     --max-episodes 20000 --max-wall 7200` — seed당 순차 학습(예산은 **seed당** 각각 적용) + 집계 판정까지
     train.py가 수행해 pass/fail exit code로 보고. **pass predicate**: 3 seed 중 **≥2**가 예산 내에서
     greedy(argmax) 정책 plan이 엔진 verdict **saved==hp_stage(=4)** 도달. 미달 = FAIL(원인 분석 후 사용자
     보고 — silent 재스코프 금지).
     **effective-config manifest(R2-M1)**: 학습 산출물(`stage11.rl.json`)에 seed·envs·에피소드 수·wall과
     **전체 하이퍼파라미터(effective config)** 를 동봉 — train.py 기본값이 바뀌면 manifest가 달라져 산출물로
     추적 가능(acceptance 타깃의 silent drift 차단).
     **N 폴백 계약(R2-M2)**: `--envs 4`는 상한 — preflight 실패 시 train.py가 **자동 N=1 강등**(동일 seed당
     예산 유지)하고 manifest에 `envs_effective` 기록. R0 pass는 N과 무관(병렬성은 처리량 편의지 acceptance
     대상 아님) — 단 강등 발생은 정직 보고.
  2. **자체 검증 커맨드(fail-closed, R1-M2·R2-M3 확장)**: `python tools/solver/rl/train.py --verify-r0` =
     ① `stage11.rl.json` 존재 + **manifest 완전성**(seeds 3개·seed별 예산 준수·no-hint 플래그·envs_effective·
     effective config 전체) ② manifest의 seed별 결과로 **3-seed ≥2 predicate 재판정** ③ best plan replay ×2
     **byte-identical** + **saved==hp_stage**(try_solve replay의 saved≥1보다 강함). 하나라도 미달 = exit 1.
     메인 verify 게이트엔 **비편입 유지**(커플링 0 원칙 — RL 트랙 로컬 게이트).
  3. 문법 커버리지 검사 PASS(known S11·S12 해의 격자 인코딩이 엔진 리플레이 클리어 — MDP 정의 참조).
  4. 병렬 preflight PASS(N=4 × 각 2회 byte-identical) 또는 N=1 강등 manifest 기록.
  5. 기존 verify 게이트 전체 그린(엔진 무변경 → 회귀 0).
  6. (stretch — 실패해도 R0 자체는 성공) S12(blocker×3, 다단 credit assignment) 동일 예산·동일 predicate
     (saved==hp_stage(=5)) 오버핏.
- **정직 경계**: R0는 "파이프라인이 학습한다"의 증명이지 휴리스틱 대비 성능 주장이 아니다. 일반화(미학습
  스테이지) 주장 없음. S11은 1-액션 레벨이라 사실상 bandit — 다단 신뢰할당 증거는 S12 stretch부터.

### R1 — trace-피드백 보상 shaping (S12 다단 credit assignment 돌파) **[구현 대상, 2026-07-03]**

> **배경(R0 stretch 실증, `dc68a47` 박제)**: S12(blocker×3 계단)는 pinned 예산 3 seed 전부 20k eps 소진
> 미클리어, **bestR=-0.02 = 양성 신호(픽업 1회조차) 0**. 원인 = terminal 보상의 신호원(saved/picked/lost)이
> 전부 "3개가 다 맞아야" 비로소 0에서 벗어나는 계단 구조 → 보상이 **plan 공간에서 flat** → REINFORCE
> 기울기 부재(정책은 "1액션+SUBMIT" 최소-페널티로 수렴). 주의: 이건 에피소드 *내* 시간적 credit assignment
> 문제가 아니다(에피소드=plan 구성, 평가는 어차피 terminal 롤아웃 1회) — **보상 함수의 정보 부족**이다.
> 따라서 R1 = 보상에 **trace-파생 진척 신호**를 가산해 "부분적으로 맞은 plan"이 구별되게 만든다.

**핵심 근거(가설 아님 — 휴리스틱 트랙 실증)**: 휴리스틱 솔버는 S12를 greedy 11롤에 풀었고, 그 score가 쓴
신호가 정확히 trace-파생 `best_goal_dist`(픽업 전=candy·픽업 후=home 접근 최소 맨해튼)와 `count_retired`다
(solve.score, model.py). 즉 **S12에서 blocker 1개가 맞을 때마다 단조 개선되는 *합성* 신호(goal_dist+retired —
단독 아님, 아래 probe)의 존재가 이미 실증**돼 있다 — R1은 그 신호를 greedy 대신 정책 기울기에 먹인다.
**prefix 단조성 실측(2026-07-03 probe, 엔진 D4 — known 해 prefix별 표준 deadline 롤아웃)**: S12(W=32 H=17
D0=49 ants=8) shaped bonus가 엄격 단조: 빈 plan `goal_d=19 retired=8 → +0.206` / blocker#1 `goal_d=6
retired=7 → +0.351` / #1+#2 `goal_d=6 retired=0 → +0.439` / #1+#2+#3 `goal_d=1 → +0.490 + cleared`.
주목: #2 구간은 goal_d 정체(6→6)를 **retired(7→0)가 구별** — `w_retired` 항은 옵션이 아니라 **필수**
(goal 단독이면 #2에서 plateau 재발). 두 신호 합으로 기울기 사다리가 3단 전 구간에 존재.

**설계 (엔진/PlanRunner/게이트 무변경 — R0 계약면 유지)**
- **trace 획득 = 기존 opt-in**: 학습 롤아웃 plan에 `"trace": true`(PlanRunner D10 가산 경로, 셀-변화 압축
  샘플이라 payload 경량 — PlanServerHarness는 plan dict를 그대로 PlanRunner에 전달하므로 신규 배선 0).
  trace 파싱은 `model.best_goal_dist`/`model.count_retired` **read-only import 재사용**(중복 구현 금지).
- **shaped 보상 (형태 확정 — 계수만 튜닝 자유, R0 보상 계약과 동일 방식)**:
  `R_r1 = R_r0 + w_goal·(1 − min(goal_d, D0)/D0) − w_retired·(retired_total/ants_total)`
  - `goal_d = model.best_goal_dist(trace, layout)` / `retired_total = model.count_retired(trace, layout)["total"]`.
  - **분모 = 레이아웃/스테이지 상수**: `D0 = W+H`(셀 맨해튼 상한), `ants_total = stage_meta.total_ants`
    — R0 H1(hp=-1 음수 분모 오염) 교훈 계승, result 파생 분모 금지.
  - **fail-safe**: trace 부재/빈 trace(개미 스폰 전 종료 등) → `goal_d=D0`(shaping 0)·`retired=0`. error
    verdict도 동일(기존 timeout 페널티 경로 불변).
  - 기본 계수 `w_goal=0.5, w_retired=0.1` — **shaping 총합 상한 < cleared(2.0)** 유지(클리어 지배 불변).
    effective config manifest에 전량 박제(R2-M1 계약 계승).
  - **acceptance 왜곡 없음**: shaping은 학습 신호만 바꾼다 — pass 판정은 여전히 엔진 verdict
    `saved==hp_stage`의 표준 deadline replay(보상 해킹이 있어도 게이트를 못 통과).
- **opt-in 플래그**: `train.py --shaping {none,trace}` 기본 `none` → **R0 고정 커맨드 의미·verify-r0 재현성
  불변**. `--shaping trace`일 때만 학습 plan에 trace 요청(none 경로 payload 불변). manifest에 `shaping` 기록.
- **greedy 평가·acceptance replay는 trace 불요**(verdict만 판정) — 기존 경로 그대로.
- **학습 deadline 상향(자기-발견 함정, 2026-07-03 실측)**: 격자-인코딩 S12 해의 클리어 frame=2981 —
  R0 학습 cap 3000f와 19프레임 차. 근사-해 변형이 학습 중 timeout으로 읽혀 **최적점 근방에서 cleared
  보너스가 굶는다** → `--train-deadline`(학습-전용 knob, CLI 노출) 신설, R1 pinned 커맨드는 `4500` 사용.
  acceptance replay deadline은 표준 7000f 불변(판정 계약 무관 — R0 "축소 cap은 학습 중에만" 원칙 유지).
- **trace-on preflight (R1-M2 — 처리량·결정론을 주장 아닌 실측으로)**: `--shaping trace`일 때 병렬
  preflight를 **trace:true plan으로 실행**(digest + trace 필드까지 전부 identical 요구 — trace 자체의
  결정론도 게이트) + preflight wall을 manifest에 `preflight_trace_wall_s`로 기록. 학습 로그에 배치당
  eps/s 포함(기존 wall 로그) — trace payload가 처리량을 눈에 띄게 깎으면 산출물에서 정직하게 보인다.
  wall 예산(7200s/seed)은 pinned 그대로 — 예산 내 미클리어면 FAIL(하드웨어-민감성은 R0과 동일 지위,
  wall이 아니라 에피소드 예산이 주 경계: S11 실측 0.13s/eps×trace 오버헤드 여유 큼).
- **엔트로피 스케줄 = R0 그대로 (R1-M3 — 사전 결정 박제)**: 0.03→0.005 감쇠 유지. shaped bonus 규모
  (probe 실측 +0.21~+0.49)는 len_penalty(−0.02)·timeout(−0.1)보다 크고 러닝 baseline이 평균 흡수 —
  스케일 재조정은 fallback 1(계수 튜닝) 관할, 선제 튜닝 금지. 진단 가시성: 배치 로그에 **base 보상과
  shaped bonus 평균을 분리 출력**(meanR 외 meanShape) — 신호가 죽었는지/포화했는지 산출물로 판별.

**Acceptance (falsifiable — 고정 커맨드/설정, R0 스타일)**
1. **S12 무힌트 오버핏**: `python tools/solver/rl/train.py --stage 12 --seeds 0,1,2 --envs 4
   --max-episodes 20000 --max-wall 1800 --shaping trace --train-deadline 4500` — pass predicate: 3 seed 중 **≥2**가 예산 내
   greedy plan 표준 deadline(7000f) replay에서 **saved==hp_stage(=5)**. 미달 = FAIL(원인 분석 후 사용자
   보고, silent 재스코프 금지). **wall 예산 = 1800s/seed(사용자 지시 2026-07-04: "최대 30분 기준" —
   R0의 7200s에서 하향; 에피소드 예산 20000은 유지, wall이 주 경계로 교체)**. **음성 대조**: 동일
   `shaping none` 0/3 FAIL 박제(`dc68a47`)가 대비 실험 — 단 그 실행은 wall 7200s였으므로 "예산 동일"
   주장은 하지 않는다(20k eps 소진 기준으로는 동일 — seed당 48분에 20k eps 완주였음. 1800s에서 눈금은
   에피소드 수로 비교, 정직 표기).
2. **`--verify-r1`(fail-closed 로컬 게이트)**: `stage12.rl.json` 존재 + **R1_PIN 명시 상수 전량 강제
   (R1-H1 — R0_PIN 교훈 계승)**: `stage_id=12`·`seeds=[0,1,2]`·`envs_requested=4`·`max_episodes=20000`·
   `max_wall=1800`(사용자 지시 2026-07-04)·`replay_deadline=7000`·`shaping="trace"`·**shaping 계수 `{goal:0.5, retired:0.1}`**·
   **`train_deadline=4500`(R2-H — 3000f cap이 최적점 근방을 굶긴다고 본 plan이 명시했으므로 material
   학습 파라미터; stale 3000f 산출물이 통과하면 안 됨)**
   (계수 튜닝은 fallback 1에서만 — 그때 R1_PIN도 같은 커밋에서 갱신 = drift가 산출물·코드 diff로 가시화)
   + manifest 완전성(seed별 예산 준수·no_hint·envs_effective·effective config 전량 + **trace preflight
   증거 `preflight_trace` 필드(R2-M): `{ok, wall_s, runs}` 존재 필수, `envs_effective>1`이면 `ok=true`
   강제** — N=1 강등 시 ok=false 허용은 R0 N-폴백 계약과 동형·정직 기록) + 3-seed ≥2 predicate
   재판정 + best plan replay ×2 byte-identical + saved==hp_stage. 메인 verify 게이트 비편입 유지(커플링 0).
   pinned 검증 커맨드: `python tools/solver/rl/train.py --verify-r1 --stage 12`.
3. **S11 shaping 비파괴 스모크**: `--stage 11 --seeds 0 --envs 4 --max-episodes 5000 --max-wall 1800
   --shaping trace --no-save` greedy 클리어(S11은 shaping 하에서도 학습됨 — shaping이 기존 성공 사례를
   퇴행시키지 않음의 저비용 반증 시도). **`--no-save` = 산출물 미저장**(stage11.rl.json·verify-r0 보존;
   판정은 stdout 집계줄).
4. **verify-r0 여전히 PASS**(stage11.rl.json 불변) + **기존 verify 게이트 전체 그린**(엔진 무변경 → 회귀 0).
5. 문법 커버리지는 R0 item 3에서 S12 포함 기검증(재실행만 확인).

**⚠ 1차 실행 FAIL → 진단-기반 수정 (2026-07-04, plan-approve 후 amendment — impl-리뷰 대상)**
r0.1 문법+entropy_min 0.005로 pinned 실행 = **0/3 FAIL**(bestR=0.231 = "b1+SUBMIT" 길이-1 국소최적의
정확한 값 — 1단은 발견됐으나 2단 탐험 사멸). probe 실측(세션 로그 F4): 마지막 단 needle = **#3 y밴드만
필수**, b1/b2 밴드 불요, 중간신호(b3 col5 = picked5 +0.376) 존재. 수정 2건(F5):
① **문법 r1.1** — y_row 어휘 = any + layout-파생 surface rows(S12 head 18→5; D7-충실·어휘 무손실,
  커버리지 PASS 재확인). GRAMMAR_VERSION 승격 → 기존 stage11.rl.json(r0.1) stale = **R0 pinned 커맨드로
  재생성**(verify-r0 grammar pin의 정직 절차).
② **entropy_min 0.005→0.02**(fallback 1 관할 하이퍼 — 길이-1 수렴 차단, manifest 추적).
acceptance predicate·pinned 커맨드·R1_PIN 불변(하이퍼·문법은 pin 비대상 — grammar_version은 manifest
기록으로 추적). 상세 = `codex-worklog/solver/2026-07-04-rl-r1-campaign.md` F4·F5.
**→ fallback 1 probe FAIL**(bestR 0.447 정체 = 희소 고보상 에피소드가 배치 평균에 희석, 로그 F6) →
**fallback 2 = self-imitation 채택·실증**(`--sil`: top-8 buffer, (R−baseline)+ 가중 재모방, sil_coef 0.1
— seed0 probe **S12 클리어 saved 5/5 frame 2130(known 해 2981보다 빠름), 4320 eps**, 로그 F7). 계약대로
**pinned 커맨드에 `--sil` 편입 + R1_PIN에 sil/sil_buffer/sil_coef 동일-커밋 갱신**. fallback 3(per-prefix
dense)·4(PPO)는 미사용 잔여 사다리로 보존.

**fallback 사다리 (사전 명시 — R0 "PPO 승격" 계약 계승, 순서 고정·건너뛰기 금지)**
1. 계수 튜닝(형태 불변, manifest로 시도 추적) →
2. self-imitation(최고-보상 에피소드 buffer 재사용 — 발견 희소성 완화, off-policy 가산) →
3. per-prefix dense shaping(각 prefix 롤아웃 Δφ 중간보상 + **결정론 memo 캐시**(같은 prefix=같은 결과) —
   에피소드당 롤아웃 ≤ len+1로 비용 상한) →
4. PPO-clip 승격.
전 단계 실패 시 정직 FAIL 박제 + 사용자 STOP(에스컬레이션).

**정직 경계**: R1은 "trace-shaped 보상이 다단 조합을 발견 가능하게 한다"의 증명이다. S12는 **합성 신호
(goal_dist+retired)의 known-prefix 단조성**이 실증된 스테이지(goal 단독은 #2에서 plateau — probe 참조) —
신호가 비단조/기만적인 스테이지(S23류 placement-needle)에 대한 주장 없음. 탐험 경로 전반의 단조성 주장
없음(known 해 prefix 한정 실측). 휴리스틱 대비 성능 주장 없음(20k eps vs greedy 11롤 — 학습/실험 목적).
일반화 주장 없음.

### R1-스윕 — 캠페인 S13~S25 순차 공략 (사용자 지시 2026-07-04, 탐사·비게이트) **[⛔ S20~S25 취소 — 2026-07-04 후속 세션 사용자 결정]**
> **⛔ 재스코프 배너(2026-07-04 후속)**: 캠페인 스테이지는 **단계별 학습을 전제로 설계된 커리큘럼**이라
> from-scratch per-stage 스윕은 구조적으로 불리한 시험 — "전체 스테이지" 성능 시험은 §R2(curriculum)의
> 관할로 이관(사용자). 스윕은 **S18 재실행까지만** 완료하고 S20~S25는 취소(4/6은 sand_mound 필수 = 문법
> 비표현 기지). 실측된 S13~S18 결과는 §R2의 from-scratch 베이스라인으로 유효(잔여는 온디맨드 재측정).
> 사용자 방향: "stage25까지 클리어 할 수 있도록 계속 진행". S12 acceptance와 별개의 **탐사 트랙** —
> per-stage `--seeds 0 --max-wall 1800 --shaping trace`(단일 seed, 30분 cap)로 순차 시도하고 결과를
> **세션 로그(`codex-worklog/solver/2026-07-04-rl-r1-campaign.md`)에 스테이지별 박제**(클리어/에피소드
> 수/실패 모드/문법 비표현 여부). 산출 plan은 `stageNN.rl.json`(클리어 시, pinned 예산과 다르므로
> verify-r1 비대상 — sweep 여부는 manifest의 `seeds=[0]`·예산 기록으로 식별, 별도 플래그 없음).
- **문법 한계 정직 선언**: R0/R1 어휘 = **ant-target 스킬만**. cell-target(sand_mound SIGN·leaf_jump
  DEVICE 등)이 필수인 스테이지는 **표현 불가 = 시도 전 SKIP 기록**(어휘 확장은 R2 후보). 인벤토리에
  cell-target이 있어도 ant-target만으로 풀리면 클리어 가능 — 시도는 한다. **구현**: StageMDP가 스킬
  head를 메타 덤프(target=="ant", D7 하드코딩 0) 기반으로 필터 — ant-target 0이면 명시 에러(=SKIP 근거).
  전부-ant 스테이지(S11~S18 등)는 필터 no-op = 기존 산출물·verify 영향 0.
- **`--max-len` 슬롯 상한 CLI**: 기본 6(R0 그대로 — R1_PIN 비대상, S12 known=3). S14(known 해 8액션)·
  S15(7)·S18(8)·S20(7)·S25(ant 8)처럼 인벤토리 합>6 스테이지는 기본 cap이 known-해 길이를 **표현 못
  하는 함정** → 스윕에서 스테이지별 `min(ant 인벤토리 합, 8)`로 상향(manifest 기록).
- **휴리스틱 트랙 실증 대비**: S21/23/24/25는 휴리스틱 beam도 미돌파(witness 수기)·S24 needle은
  sand_mound 필수 — RL 30분 단일 seed가 못 풀어도 기대 위반 아님(정직 기록이 산출물).
- 게이트 무관(메인 verify·verify-r0/r1 비커플링). 실패는 FAIL이 아니라 데이터.

### R2 — 영속 학습: 체크포인트 + 스테이지-불변 정책 + curriculum + cell-target **[설계 초안 · plan-review 대상, 2026-07-04]**

> **사용자 지시 2건(2026-07-04)이 스코프의 뼈대**: ① "강화학습 결과를 저장/로드하지 않으면 제대로 된
> 강화학습이 아니다" — **가중치 영속화 = R2 필수 요건**. ② "스테이지는 단계별 학습을 전제로 설계 —
> 전체 스테이지를 풀어보는 시험은 R2 이후" — 캠페인 수준 시험은 R2 curriculum의 관할.
> **R1 실증이 남긴 병목과 처방의 대응**(전부 실측 근거): 5액션+ carry 연쇄 미조립(S13/S14/S15, 30분
> from-scratch) ← curriculum·영속화 / cell-target 비표현(S19 SKIP·S23/S24 needle) ← 어휘 확장.
> **현 구조의 정직 진단**: R0/R1 정책망은 obs_dim·head 크기가 스테이지 파생(레이아웃·인벤토리) —
> 가중치를 저장해도 **타 스테이지 로드가 차원 불일치로 불가능**. 영속화가 자산이 되려면 스테이지-불변
> 아키텍처가 선결. 이것이 P1(저장)과 P2(불변화)를 한 phase로 묶는 이유다.

**선결 계약 — 레거시 게이트 격리 (plan-R1 CRITICAL-2)**
R2는 문법을 **r2로 승격**(전역 어휘+마스킹)하되, **verify-r0/r1의 grammar pin을 모듈 상수에서 리터럴
`"r1.1"`로 동결**하고 StageMDP를 **버전 인자로 구성 가능**하게 유지(r1.1 경로 보존) — stage11/12 pinned
산출물은 r1.1 문법으로 영원히 검증 가능(r0.1→r1.1 때처럼 재생성 강제하는 stale 처리 금지; 이번엔 인증
이력이 게이트 자산이므로). verify-r0/r1은 정책 가중치를 로드하지 않음(산출물=plan JSON) — 체크포인트
포맷 변경과 무관. 신규 산출물/체크포인트는 verify-r2 관할.
**§R1 원칙 개정 명시(plan-R2 LOW-1)**: §R1의 "학습-전용 knob는 pin 비대상, grammar/hyper는 manifest
추적" 문구 중 **grammar_version은 R2부터 이 동결 계약이 우선**(우선순위: §R2 선결 계약 > §R1 해당 문구).
§R1 텍스트는 이력으로 보존하되 구현 기준은 여기다.

**구조 4축 (P1~P4 — 세부 설계는 구현 전 확정, 아래는 계약 수준)**
- **P1 · 체크포인트(영속화, 사용자 필수 요건)**: **로드 2모드 분리(plan-R2 HIGH-2 — 동일-스테이지 재개와
  스테이지-간 전이는 다른 계약)**:
  - `--resume-ckpt`(**exact resume, 동일 스테이지**): 전 상태 복원 — stage_id·레이아웃 digest·문법·모델
    shape **전부 일치 요구**(불일치 = fail-closed 거부). 재개 등가성(acceptance 1)의 대상.
  - `--transfer-ckpt`(**curriculum 전이, 타 스테이지**): policy+optimizer 가중치만 이월, 스테이지-파생
    상태(마스크·entropy 스케줄=리셋·SIL buffer=비움)는 새 스테이지에서 재구성, RNG는 새 seed 계약.
    **digest 계약 분리(plan-R3 HIGH-1)**: 레이아웃·per-stage 마스크 digest는 **면제**(불일치가 전이의
    정의)이되, **전역 어휘/head-시맨틱 digest**(전역 스킬 사전 순서·트리거 어휘·격자 어휘 크기·at_frame
    bin — head 인덱스→의미 매핑의 전부)는 **fail-closed 일치 요구** — shape만 같고 시맨틱이 다른
    가중치의 silent 오매핑 차단. manifest 재개 사슬에 mode 기록.
  **직렬화 대상 전수(plan-R1 MED-1)**: policy state_dict + optimizer + entropy 스케줄 카운터(batch_i) +
  **학습이 사용하는 모든 RNG**(현 코드 = torch 단일; 구현에서 python random/numpy 사용 추가 시 그것도 —
  "사용하는 RNG 전수" 가 계약) + **SIL buffer 내용·순서** + 누적 에피소드/배치 카운터 + grammar_version +
  stage_id·**레이아웃 digest**·어휘/마스크 digest + 모델 config(hidden 등)·dtype. **verify-r2가 재개 전
  비호환을 mode별 규칙으로 fail-closed 거부**. manifest에 **재개 사슬**(ckpt 출처 해시·mode·
  구간별 에피소드/배치) 기록 — **예산 회계는 구간별(plan-R2 MED-4): 각 acceptance의 예산은 해당 스테이지
  구간에만 적용**되고 verify-r2가 구간 카운터로 검증(사슬 전체 합산 아님).
- **P2 · 스테이지-불변 정책**: 공유 CNN 인코더(가변 H×W 그리드 → 고정 임베딩) + **액션 어휘 통일**.
  **정규화 아님 — 이산 전역 어휘 + per-stage 마스킹**(plan-R1 MED-2: 연속 정규화는 셀-센터/表面행 시맨틱의
  정확한 역변환이 불가해 기존 유효 plan을 충실히 방출 못 함): skill head = 전역 스킬 사전(SkillRegistry
  메타 파생, D7 하드코딩 0) + 인벤토리 마스크 / col·row 계열 head = 전역 최대 격자 크기 + 스테이지 범위
  마스크. **전역 최대 W/H의 권위(plan-R2 MED-1) = campaign_manifest 등재 스테이지 레이아웃 전수 스캔
  파생**(하드코딩 0); 이후 등재 스테이지가 최대를 초과하면 **명시 에러 + 어휘 버전 승격**(silent 확장
  금지 — 기존 체크포인트와 head shape 비호환이므로). **행 head 이원화**: ant의 y_row 마스크 = surface
  rows(r1.1 계승), cell의 row 마스크 = 스테이지 전 행(설치 후보) — 같은 전역 row head를 kind별 다른
  마스크로 공유. **r2 문법 커버리지 게이트**: known S11·S12(ant)·S19(cell) 해가 r2 인코딩→디코드→엔진
  클리어(R0 coverage 패턴 계승) — 같은 가중치 파일이 임의 스테이지에 로드 가능해야 P1이 의미를 갖는다.
- **P3 · cell-target 어휘 — sum-type 액션 계약(plan-R1 HIGH-2)**: 액션에 **`target_kind ∈ {ant, cell}`
  1급 판별자 head** 신설. kind별 유효 head를 **마스킹으로 강제**(무효 조합은 페널티가 아니라 표현 불가):
  ant → (select, state, y_row) + trigger / cell → **(col, row) head** + trigger. **트리거 직교 계약
  (plan-R2 MED-2)**: 트리거는 "언제"·target은 "무엇에"로 직교 — **cell도 ant와 동일 트리거 어휘 전부
  유효**(PlanRunner 시맨틱 그대로: 트리거 발화 시 셀에 적용; `picked_ge`+cell = "n개 픽업 시점에 설치").
  kind별 마스크 대상은 target 계열 head(select/state/y_row vs col/row)뿐, 트리거 head는 공용. **트리거
  어휘에 `at_frame` 추가** — S19 known 해(`sand_mound cell(10,14)/(11,10) @ at_frame 0`,
  stage19.solve.json 실측)가 요구. **at_frame head(plan-R2 MED-1) = 양자화 격자**(0 포함, 상한 =
  train_deadline 마스크; 격자 간격 상수는 impl 확정하되 head 존재·마스킹·라운드트립 포함이 계약).
  JSON lowering 규칙(head → PlanRunner 액션) 명문화 + encode/decode 라운드트립 검사를 r2에도 유지
  (verify-r2 편입).
- **P4 · curriculum**: **`data/campaign_manifest.tres`가 순서 SoT**(plan-R1 HIGH-4 — 챕터별 ordered
  stage id; 솔버는 read-only 파싱, 하드코딩 0). 클리어한 스테이지의 체크포인트에서 다음 스테이지
  **이어서 학습**(from-scratch 금지). **entropy 스케줄은 스테이지 경계에서 리셋**(plan-R1 MED-3 —
  전 스테이지의 감쇠된 entropy가 새 스테이지 탐험을 질식시키는 것 차단; 전역 카운터(누적 에피소드)는
  계속 누적, 체크포인트에 둘 다 보존). 회귀 방지(mixed replay 등)는 P4 구현 시 확정(미확정 명시).
  verify-r2는 curriculum 산출물의 스테이지가 manifest에 없거나 순서 모순이면 FAIL.

**Acceptance (falsifiable — 고정 커맨드·predicate, plan-R1 CRITICAL-1·HIGH-1·HIGH-3 반영)**
1. **재개 등가성(P1)**: 같은 seed·**배치 수 기준**(wall 아님 — wall은 운영 한도일 뿐 등가성 판정 밖):
   `--max-batches 2N 무중단` vs `--max-batches N --save-ckpt` 후 `--resume-ckpt --max-batches N` 의
   **최종 정책 파라미터·학습 곡선(배치별 meanR 시퀀스) 일치**. **결정론 배치 계약(plan-R2 MED-3)**:
   ⓐ 에피소드 샘플링 = 메인 스레드 순차·단일 RNG 스트림(현 구조 유지) ⓑ 평가 결과 = pool.evaluate
   인덱스-순서 보존(현 계약) ⓒ env 부팅/포트 재시도는 학습 RNG 비소비(현 구조) ⓓ **등가성 시험 중
   wall 조기중단 비활성**(--max-batches 모드는 배치 수만 종료 조건). 성립 조건 = 사용 RNG 전수 직렬화 +
   SIL 내용·순서 직렬화 — env 결정론 위에서 성립. 불일치 = P1 FAIL(부분 직렬화 은폐 금지).
2. **curriculum 최소 증명(P4)**: **체크포인트 출처 pin(plan-R2 HIGH-1) + per-seed 실행 계약(plan-R3
   HIGH-2)** — acceptance는 **seed별 독립 커맨드 ×3**으로 실행(복수 --seeds에 단수 ckpt를 주는 실행
   불능 pin 금지; seed→ckpt 해석이 커맨드 라인에 명시적). **공통 구간 예산(plan-R3 MED — 사슬 전 구간
   동일 pin)**: `--envs 4 --max-episodes 20000 --max-wall 1800 --shaping trace --train-deadline 4500
   --sil` (S11/S12/S13 구간 각각 적용). seed s ∈ {0,1,2}별 **pinned 사슬**:
   - ① `--stage 11 --seeds s <공통 예산> --save-ckpt` (r2 문법, from-scratch) 클리어 → ckpt_s11(s)
   - ② `--stage 12 --seeds s <공통 예산> --transfer-ckpt ckpt_s11(s) --save-ckpt` 클리어 → ckpt_s12(s)
   - ③ **acceptance**: `--stage 13 --seeds s <공통 예산> --transfer-ckpt ckpt_s12(s)`
   cherry-pick 불가(각 seed는 자기 사슬의 ckpt만 — 재개 사슬 manifest가 출처 해시로 무결 증명·verify-r2
   검증). 사슬 앞단(①②)이 미클리어인 seed는 그 seed FAIL로 집계(사슬 자체가 결과). **predicate =
   3 seed 중 ≥2가 ③에서 greedy 클리어(saved==hp)**(R1과 동일 형식). 예산은 구간별 회계(P1). 대조 =
   from-scratch 동일 예산 실측(R1-스윕 S13 seed0 FAIL bestR 0.660; seeds 1,2 from-scratch 추가 측정으로
   3-seed 대조 완성). "유의 상회" 같은 통계 술어 금지 — 클리어 predicate가 유일 판정. FAIL = 정직 박제 +
   사용자 escalate(전이가 안 되는 것도 결과 — R0 stretch 선례).
3. **어휘 증명(P3) — 학습과 분리(plan-R1 HIGH-3)**: ⓐ **결정론 커버리지**(학습 무관): S19 known 해의
   r2 인코딩→디코드→엔진 replay 클리어 = 어휘 계약 증명. ⓑ **학습 발견(pinned, plan-R2 LOW-2)**:
   `--stage 19 --seeds 0,1,2 --envs 4 --max-episodes 20000 --max-wall 1800 --shaping trace
   --train-deadline 4500 --sil` (r2 문법, **from-scratch 단독** — S19는 2-액션 cell 배치라 curriculum
   불요 가정; predicate = ≥2/3 seed 클리어). ⓐ 실패 = 문법 결함 / ⓑ만 실패 = 탐색 문제 — 구별 가능,
   각각 정직 박제.
4. **verify-r2 계약(plan-R1 MED-4)**: `python tools/solver/rl/train.py --verify-r2 --stage NN` —
   R1 게이트 전체 계승(pinned 예산·문법 라운드트립·live preflight·trace 재생·pass 시맨틱) + **체크포인트
   메타 검증**(재개 사슬 무결 + **mode별 digest 계약 적용**(plan-R4 MED): exact resume =
   stage/레이아웃/per-stage 마스크 digest 일치 요구, transfer = 레이아웃/마스크 면제·전역 어휘/head-시맨틱
   digest fail-closed — P1 계약과 동일 문구, 이원 해석 금지) + curriculum manifest 정합. 세부
   pin 상수는 impl 커밋에서 §R2에 동봉(R0/R1 선례).
5. 기존 게이트 전체 그린(엔진/PlanRunner 무변경 유지) + **verify-r0/r1이 r1.1 동결 pin으로 계속 PASS**
   (선결 계약 실증).
6. (비게이트 탐사, plan-R1 LOW) acceptance 후 **R2-스윕**: curriculum 체크포인트 기준 캠페인 순차 시험
   (S14/S15 carry-연쇄 포함) — R1-스윕 from-scratch 실측과 대비표 박제. 결과 무관 acceptance 성립.

**정직 경계**: 스테이지-불변 인코더의 전이 효과는 미지 — R2는 "영속·전이가 되는가"의 실험이지 캠페인
전 스테이지 클리어 보장이 아니다. acceptance 2/3ⓑ의 FAIL 가능성은 설계에 내재(그 경우 원인 분석 후
사용자 보고 — silent 재스코프 금지).

### 로드맵 (미확정 — 증거 후 재계획)
- **R3 후보**: trace-피드백 refinement MDP(상태에 직전 롤아웃 trace 인코딩 = 휴리스틱 closed-loop의
  학습판) / dense per-prefix shaping / PPO 승격. R2 증거 확보 후 선택.

### 리스크
- sparse reward: ~~클리어 희소 → shaping 항(picked/lost)으로 완화~~ **R0가 반증**(2026-07-03, `dc68a47`):
  picked/lost 항은 S11(1액션)만 커버, S12 계단에선 전부 0으로 flat → **R1 trace-파생 shaping
  (goal_dist+retired)이 대체**(§R1). S11 탐색 공간 ~10³ 오버핏 무난 예상은 적중(3/3 seed).
- 학습 불안정(REINFORCE 고분산): baseline+배치 크기로 1차 방어, PPO 승격 경로 사전 명시.
- 세션 간 재현: 학습 산출물에 seed·하이퍼파라미터·에피소드 수 동봉(재현 스크립트 1줄).

---

## (트랙 밖 · 별도 브랜치 다운스트림 — 구 Phase 5) 난이도·설계 감사 오라클
> 2026-06-20 사용자 결정으로 auto-solver 트랙에서 분리(§"트랙 범위·게이트 갱신"). in-track Phase 5(고도화·재설계)가
> "5" 슬롯을 차지하므로 번호 없는 다운스트림으로 격리. 아래는 방향 맥락으로 보존.
### 목표
Phase 2~4를 **레벨 품질 오라클**로 패키징(생성의 적합도 함수).
### 산출
- `tools/solver/audit_level.py`: 입력 레벨 → `{풀림, 트리비얼?(스킬0 빈 플랜 클리어), 최소스킬 수·종류, 난이도(절대·등급별), 해 다양성, 정합성 오류, 스킬 오용/잉여 인벤토리}`.
### Acceptance
- 기존 스테이지에 리포트가 직관과 일치(트리비얼 검출·필수 스킬 식별·정합성 경고). 캘리브레이션 루프.

## (트랙 밖 · 별도 브랜치 다운스트림 — 구 Phase 6) 생성 (북극성)
> 생성은 솔버 역할이 아니라 솔버 산출(다양-해·풀이법 보고서)을 *참조하는 별개 소비자*(§"트랙 범위·게이트 갱신"). 방향 맥락 보존.
### 6a · 생성 가설 실증 (de-risk, 먼저)
기존 레벨을 변형(타일 길이·인벤토리·구조)해 후보 생성 → Phase 5 오라클로 채점 → **트리비얼/비자명을 실제로 가려내고 난이도가 의도대로 움직이는지** 확인. (S12 spike가 솔버를 실증했듯 *생성 루프*를 실증.) 여기서 "오라클이 좋은 레벨을 골라낸다"가 보여야 본격 진입.
### 6b · 생성-후-검증 PCG (확신 높음)
후보 레벨 생성(기하·인벤토리 변형/조합) → 오라클 적합도(풀림·비자명·목표난이도·도구필요·정합성) → 통과분 채택. 트리비얼·단층 박멸은 적합도 함수가 보장.
### 6c · 전술 구성적 생성 (업사이드·불확실)
전술 라이브러리를 역으로 써서 흥미로운 도구-사용 상황을 의도 배치 → 연결. "디자인된 느낌" 다양성. 연구 영역 — 6a/6b 성과 보고 진행 결정.
### Acceptance
- 6a: 오라클이 트리비얼 후보를 거부하고 난이도 정렬이 직관과 일치. 6b: 생성기가 비자명·목표난이도 레벨을 산출(사람 검수로 "단층 뻔함" 탈피 확인).

---

## 검증 방법 (게이트 = 프론트매터 `verify` 단일 필드)
> execute.py가 실행하는 게이트는 `verify` 하나뿐(L809). 그래서 **각 단계 완료 = `verify`를 그 단계 게이트로 갱신하고 그린**(R2-HIGH). inert 키 금지. 현재 `verify` = Phase 0+1+2+3a(아래 1+2 + selftest + `analyze.py --verify`). **게이트 invocation은 2026-06-20부터 `tools/solver/try_solve.py` front-door를 거친다**(§"트랙 범위·게이트 갱신" — false-green 제거): 검증 *내용*은 불변, *호출*만 이동.
1. **결정론(✅, `verify`)**: `DeterminismReplayTest`(per-frame) + `DeterminismSpawnScheduleTest`(스폰 드리프트 0) — **`run_test.py`로 실행**(단발, `--quit-after` 안전망 무관).
2. **하니스/자동동기화(`verify` 편입)**: `PlanReplayHarnessTest`(+배치 누수 0)는 **`python tools/solver/try_solve.py harness-test`**(exit-code 아닌 PASS 마커로 판정 → false-green 제거) / 손작성+자동발견 골든 검증은 **`python tools/solver/try_solve.py selftest`**(구 `run_plan.py --selftest`은 back-compat·비-게이트로 잔류) / `SkillMetadataDriftTest`(스킬 메타 완전성·솔버 열거==레지스트리, D7 강제)는 **`run_test.py`로 실행**.
3. **기존 회귀 무파손**: `CampaignS11~S14`·`GameFlow`·`StageRunnerBeginGate` 등(SkillApplier 리팩터·시계 프레임화에도 플레이 불변).
4. **솔버/난이도(현 게이트=3a)**: `analyze.py --verify`가 *발견된 해*(solve.json, 1-minimal)의 반응-윈도우를 결정론 리플레이로 재검증(interval 내=clear/밖·gap=fail). **max-margin 대안 해·권위 난이도는 Phase 3b로 아직 게이트 밖**(본문 §3a "측정 대상=발견된 해, max-margin 아님" R1-H4와 정합).
5. **다양-해(Phase 5)**: 5c 완료 시 `stageNN.diverse.json` 각 해를 결정론 리플레이로 fail-closed 재검증해 `verify` 편입.
   (구 "학습=전이 롤아웃 감소"는 Phase 4 강제 종료로 폐기. **생성**=트랙 밖 다운스트림: 오라클 선별력 → 비자명 레벨 산출.)

## 회귀 주의 (사전 식별)
- **시계 의미 불변(✅ Phase 0)**: 프레임화가 플레이 불변임을 회귀로 입증 완료.
- **속도 가정**: 생성 처리량이 여기 의존 → 라이브러리 가속·병렬 필수(D9).
- **스킬 적용 인벤토리-충실(CRITICAL-1)**: `Skill.new().apply()` 직접 호출 금지, `SkillApplier` 경유. 드라이버·주석은 ground truth 아님(D4).
- **자동 동기화(D7)**: 솔버에 게임 지식 하드코딩 금지(spike의 blocker 하드코딩 = 제거 대상). 스킬 self-describing + `SkillAffordance` 종속화 + `SkillMetadataDriftTest`로 엔진/UI/솔버 desync 차단. 전역기능은 명세 config.
- **셀렉터 결정성**: 활성 스테이지 루트 스코프 + `(x, spawn_index, instance_id)` tie-break. 전역 `ants` 그룹 직접 순회 금지.
- **드라이버 병행**: 기존 GDScript 드라이버 삭제 안 함(회귀 안전망), 솔버 정답 기준으로는 비참조.

## 산출물 위치
- GDScript: `scripts/core/{SimConfig(✅),SkillApplier,PlanRunner}.gd`. 능력 config `data/solver/capabilities.tres`.
- Python 오케스트레이터: `tools/solver/{solve,try_solve,model,analyze}.py` (+ spike `solve_spike.py`). diverse front-door = `try_solve.py diverse`.
- 하니스/회귀 씬: `tests/{SolverHarness(spike),PlanReplayHarness,SkillMetadataDriftTest}.{gd,tscn}`. 골든·해 플랜: `data/solutions/`(solve.json + 영속 시 `stageNN.diverse.json`).
- 볼트(해 설명 어휘): `tools/solver/knowledge/` + `knowledge.py`(파서). **historical(Phase 4 종료, inert)**: `tactics.py`·`solve.py` `vault_fn` pruning 경로·`try_solve.py transfer-bench`. 트랙 트레일: `codex-worklog/solver/STATUS.md`.
