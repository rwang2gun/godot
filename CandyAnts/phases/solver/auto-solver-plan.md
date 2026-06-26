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
  다양-해 코퍼스 확보. sand_mound(cell-up) routing 등 미커버 메커니즘 추가는 여기서.

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
