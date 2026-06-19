---
name: auto-solver
duration_estimate: 28800
verify: python scripts/run_test.py tests/DeterminismReplayTest.tscn && python scripts/run_test.py tests/DeterminismSpawnScheduleTest.tscn && python scripts/run_test.py tests/PlanReplayHarnessTest.tscn && python scripts/run_test.py tests/SkillMetadataDriftTest.tscn && python scripts/run_plan.py --selftest
large_change_ok: false
sot: phases/solver/auto-solver-plan.md
sot_aux: [scripts/core/SimConfig.gd, scripts/core/StageRunner.gd, scripts/core/SceneFlow.gd, scripts/core/ScoreSystem.gd, scripts/ant/Ant.gd, scripts/world/Home.gd, scripts/core/AntSpawner.gd, scripts/ui/SkillToolbar.gd, scripts/core/SkillRegistry.gd, scripts/core/SkillApplier.gd, scripts/core/PlanRunner.gd, scripts/core/SolverCapabilities.gd, scripts/run_test.py, scripts/run_plan.py, tests/SolverHarness.gd, tests/PlanReplayHarness.gd, tests/PlanReplayHarnessTest.gd, tests/SkillMetadataDriftTest.gd, data/solver/capabilities.tres, tools/solver/solve_spike.py]
---

# 트랙: 스테이지 자동 솔버 → 레벨 생성 (auto-solver)

## 문서 구조 (리뷰·구현 범위)
이 문서는 **3층**이다. 적대적 리뷰와 구현은 *확정* 층만 대상으로 한다 — 로드맵은 방향 맥락이며 **feasibility 미검증을 결함으로 보지 않는다.**
- **비전(방향, 미확정)**: 북극성 + 비전 결정 D8~D9 + Phase 4~6. "우리가 향하는 곳"이지 확정 범위 아님.
- **확정(리뷰·구현 대상)**: 결정 D1~D7 + **Phase 1**. falsifiable acceptance를 가진다.
- **근시일 계획(스케치)**: Phase 2~3. 방향은 정했으나 상세는 Phase 1 산출 후 확정.
- **로드맵(증거 후 재계획)**: Phase 4~6. 앞 단계 증거가 나온 뒤 상세 계획·진입 여부 결정. Phase 6a(생성 가설 실증)가 6b/6c의 게이트.

## 비전 / 북극성 (방향 — 확정 범위 아님, 사용자 정렬 2026-06-18)
**다양하고 비자명한(non-trivial) 레벨을 자동 생성**한다. 솔버는 그 자체가 목적이 아니라 **레벨 품질을 판정하는 적합도 오라클(fitness oracle)**이다.
- 동기: LLM(=Claude)에게 레벨을 맡기면 **풀이 역학 모델도 품질 기준도 없어** 단층·트리비얼 레벨만 나온다. 퍼즐(=올바른 도구를 올바른 타이밍·위치에 써야만 풀리는 비자명함)을 만들려면 **솔루션 공간을 이해**해야 하고, 이 트랙이 그 결핍(도구별 올바른 사용·난이도 판단)을 메운다.
- **정직한 경계**: 오라클은 *풀림·비자명·난이도·도구필요성·정합성*은 보장하지만 그 너머의 *재미/미감*은 지표로 다 못 잡는다. 이 시스템은 **바닥을 확실히 올리고**(트리비얼·단층 박멸, 목표 난이도 적중) 다양성의 큰 부분을 자동화하되, 최상급 디자인은 사람 큐레이션이 낫다. 생성 가설("학습→다양 생성")은 **가정하지 않고 일찍 실증**한다(Phase 6a).

이 문서는 plan SoT. 게임플레이 phase와 직교한 **툴링 트랙**이고, 산출 코드는 Godot 컨벤션대로 `scripts/`·`tests/`·`tools/`에, 트레일은 `codex-worklog/solver/STATUS.md`에 누적한다.

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
- `PlanReplayHarnessTest` PASS(+배치 상태누수 0). 다중 스킬 손작성 골든이 게임 verdict대로(`run_plan.py --selftest`).
- `SkillMetadataDriftTest` PASS — 등록·스테이지 스킬 메타 완전성 + 솔버 열거==레지스트리 단언(자동 동기화 D7 강제).
- **Phase 1 완료의 정의 = 위 체크를 `verify` 프론트매터에 *반영*(결정론 테스트 && PlanReplayHarnessTest && SkillMetadataDriftTest && `run_plan.py --selftest`)하고 그 단일 `verify` 명령이 그린.** execute.py·`complete`가 실행하는 건 `verify` 하나뿐이므로(L809) 별도/inert 키를 두지 않는다 — `verify` 갱신 자체가 silent bypass를 막는 강제 계약. (지금 `verify`는 산출물 미존재라 Phase 0만; 갱신 전엔 Phase 1 미완료.)

## Phase 2 — 탐색 솔버 (경험 생성) · **[근시일 계획] ✅ 완료 (2026-06-20, S11~S14 무힌트 자동 해결)**
> **산출**: `tools/solver/{model,solve}.py`(예측 닫힌-루프 — 베이스라인 관측→진단→개입 제안→엔진 검증, D10) +
> `tests/SolverMetaDump.{gd,tscn}`(D7 메타 브리지) + 스킬 `SOLVER_META.routing/purpose`(D11) + `PlanRunner`
> 궤적 트레이스 확장. **해 4종** `data/solutions/stage{11,12,13,14}.solve.json`: S11(2롤 blocker×1)·S12(11롤
> blocker×3)·S13(26롤 blocker×1+climber×5)·S14(40롤 blocker×3+climber×5), 전부 무수정 게임 verdict
> 100%(D4). **CI 게이트**: `run_plan.py --selftest`가 solve.json까지 결정론 리플레이 검증(자동발견 해 회귀
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

## Phase 3 — 반응-윈도우 & 인간 타당성 (정합성 + 난이도) · **[근시일 계획 · 스케치]**
### 목표
기계-클리어를 **인간-타당성**으로 거르고 난이도를 산출(D6).
### 작업
- **윈도우 측정 모듈**: max-margin 해의 각 필수 명령에 대해 적용 (프레임·위치)를 스윕 → 클리어 유지 연속 구간 = 윈도우(시간·공간). spike 국소 정밀탐색을 일반화.
- **최소화/크레딧 할당**: 액션을 하나씩 빼 재실행 → 잉여 제거 → 필수 최소 플랜(난이도 "최소 스킬"도 산출).
- **`T_human` 필터**: 윈도우 < 임계 = **정합성 오류**(기계전용). 공간 조준 난이도·입력 행위 비용 반영.
- **난이도 점수**: 가장 여유로운 해의 최소 윈도우 + 최소스킬·시퀀스 의존성·margin·대안 해 수 → 절대·등급별 점수. 사용자 라벨로 캘리브레이션.
### Acceptance
- 기존 스테이지에 대해 난이도/정합성 리포트가 직관과 일치(짧은 사다리-후-구간 = 빡빡 윈도우 = 고난이도; 인간 불가 구간 = 정합성 오류 플래그).

## Phase 4 — 전술 라이브러리 (누적 학습, CBR/EBL) · **[로드맵 · 미확정, Phase 3 증거 후 재계획]**
> 검증 가능한 단일 가설로 좁힘: *"한 레벨에서 추출한 전술이 다른 레벨로 전이돼 동일 난이도 해를 더 적은 롤아웃으로 찾는다."* 리프팅·서브골 추론의 구체 메커니즘은 Phase 2~3 산출(해 트레이스·윈도우 데이터)을 본 뒤 설계 — 지금은 미확정.
### 목표
스테이지마다 같은 시행착오 반복 금지(D8) + 스킬-사용 프로파일 산출.
### 작업
- **추출**: 최소 필수 플랜을 *국소 특징*(가장 가까운 위험물/사다리/간격/웨이브 방향)에 상대적으로 **리프팅**(절대좌표·특정 개미 치환) + **서브골 추론**(반전/한 층 상승/간격 건넘). 전술 = `(스킬, 전제=국소패턴, 상대배치, 타이밍앵커, 서브골, 성공이력)`. 스킬·상황 이중 인덱싱.
- **시드 탐색**: 새 레벨을 국소 특징 분해 → 전술 매칭·슬롯 바인딩 → 고우선 후보부터 → 롤아웃 급감. 폴백 탐색에서 성공 시 새 전술 추가. (엔진 검증이 잘못 전이를 잡으므로 거짓 양성 0, 비용은 낭비 롤아웃뿐.)
- **스킬-사용 프로파일**: 스킬별 "정답이었던 맥락" 누적 = 도구의 올바른 사용(D9 생성 어휘).
### Acceptance
- S11에서 학습한 전술이 S12/S13에 전이돼 **동일 난이도 해를 더 적은 롤아웃**으로 발견(시행착오 감소 실측). 라이브러리 영속·성장.

## Phase 5 — 난이도·설계 감사 오라클 · **[로드맵 · 미확정, Phase 3~4 증거 후 재계획]**
### 목표
Phase 2~4를 **레벨 품질 오라클**로 패키징(생성의 적합도 함수).
### 산출
- `tools/solver/audit_level.py`: 입력 레벨 → `{풀림, 트리비얼?(스킬0 빈 플랜 클리어), 최소스킬 수·종류, 난이도(절대·등급별), 해 다양성, 정합성 오류, 스킬 오용/잉여 인벤토리}`.
### Acceptance
- 기존 스테이지에 리포트가 직관과 일치(트리비얼 검출·필수 스킬 식별·정합성 경고). 캘리브레이션 루프.

## Phase 6 — 생성 (북극성) · **[로드맵 · 미확정, 6a가 6b/6c 게이트]**
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
> execute.py가 실행하는 게이트는 `verify` 하나뿐(L809). 그래서 **각 단계 완료 = `verify`를 그 단계 게이트로 갱신하고 그린**(R2-HIGH). inert 키 금지. 현재 `verify` = Phase 0+1(아래 1+2). **Phase 2는 `--selftest`가 `data/solutions/*.solve.json`(자동발견 해)까지 검증하도록 확장돼 verify 문자열 무변경으로 게이트 편입** — 중복 키 없이 selftest 내용 확장이 곧 강제 계약(엔진/스킬 변경이 확보된 해를 깨면 selftest FAIL).
1. **결정론(✅, 현재 `verify`)**: `DeterminismReplayTest`(per-frame) + `DeterminismSpawnScheduleTest`(스폰 드리프트 0).
2. **하니스/자동동기화(Phase 1 완료 시 `verify`에 편입)**: `PlanReplayHarnessTest`(+배치 누수 0) + `run_plan.py --selftest` + `SkillMetadataDriftTest`(스킬 메타 완전성·솔버 열거==레지스트리, D7 강제).
3. **기존 회귀 무파손**: `CampaignS11~S14`·`GameFlow`·`StageRunnerBeginGate` 등(SkillApplier 리팩터·시계 프레임화에도 플레이 불변).
4. **솔버/난이도**: 각 스테이지 max-margin 해 + 반응-윈도우 난이도·정합성 리포트가 직관 일치.
5. **학습**: 전이로 롤아웃 감소 실측. **생성**: 6a 오라클 선별력 → 6b 비자명 레벨 산출.

## 회귀 주의 (사전 식별)
- **시계 의미 불변(✅ Phase 0)**: 프레임화가 플레이 불변임을 회귀로 입증 완료.
- **속도 가정**: 생성 처리량이 여기 의존 → 라이브러리 가속·병렬 필수(D9).
- **스킬 적용 인벤토리-충실(CRITICAL-1)**: `Skill.new().apply()` 직접 호출 금지, `SkillApplier` 경유. 드라이버·주석은 ground truth 아님(D4).
- **자동 동기화(D7)**: 솔버에 게임 지식 하드코딩 금지(spike의 blocker 하드코딩 = 제거 대상). 스킬 self-describing + `SkillAffordance` 종속화 + `SkillMetadataDriftTest`로 엔진/UI/솔버 desync 차단. 전역기능은 명세 config.
- **셀렉터 결정성**: 활성 스테이지 루트 스코프 + `(x, spawn_index, instance_id)` tie-break. 전역 `ants` 그룹 직접 순회 금지.
- **드라이버 병행**: 기존 GDScript 드라이버 삭제 안 함(회귀 안전망), 솔버 정답 기준으로는 비참조.

## 산출물 위치
- GDScript: `scripts/core/{SimConfig(✅),SkillApplier,PlanRunner}.gd`. 능력 config `data/solver/capabilities.tres`.
- Python 오케스트레이터: `tools/solver/{solve,audit_level}.py` (+ spike `solve_spike.py`).
- 하니스/회귀 씬: `tests/{SolverHarness(spike),PlanReplayHarness,SkillMetadataDriftTest}.{gd,tscn}`. 골든·해 플랜: `data/solutions/`.
- 전술 라이브러리: `data/solver/tactics.*`(영속 산출물). 트랙 트레일: `codex-worklog/solver/STATUS.md`.
