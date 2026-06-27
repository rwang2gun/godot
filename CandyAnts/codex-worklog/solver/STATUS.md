# solver STATUS

## 목적
스테이지 자동 솔버 트랙(툴링, gameplay phase와 직교). 실제 Godot 게임을 헤드리스로 돌려(인-더-루프)
스테이지 클리어 가능 여부를 기계 검증하고, 이후 자동 레벨 디자인(풀이가능성·최소스킬·난이도)에 재사용.

- **Plan SoT**: [phases/solver/auto-solver-plan.md](../../phases/solver/auto-solver-plan.md) (4-phase: 0 결정론·속도 게이트 →
  1 플랜-리플레이 하니스 → 2 탐색 솔버 → 3 레벨 디자인 활용).
- **정답 기준(D4)**: "솔버가 실제 인벤토리로 달성한 클리어"를 무수정 게임 코드(`StageRunner._conclude_stage`)가
  판정한 결과만 정답. 기존 드라이버·주석은 ground truth 아님.

---

## 현재 상태 (2026-06-18) — **Phase 0 구현 완료, 게이트 통과** (적대적 리뷰 진행 중)

> 적대적 리뷰 트레일: [phases/solver/reviews/phase0-impl-review.md](../../phases/solver/reviews/phase0-impl-review.md).
> R1(codex) HIGH(스폰 프레임 환산 drift/early-fire) + MEDIUM(replay deadline=pass) → 수정(분수-초 데드라인 ceil
> 누적 + deadline hard-fail + `DeterminismSpawnScheduleTest`) → 자체리뷰 clean → **R2(codex) approve = 종결**.
> 커밋: Phase 0 본체 `97ea271`, R1 수정 `985c7ae`.

### 결정론 모드 (opt-in)
- **`scripts/core/SimConfig.gd`** 신규 autoload(`project.godot` 등록, GameManager 직후). `deterministic` 플래그
  기본 `false` → 게임·기존 테스트 동작 불변. `CANDYANTS_DETERMINISTIC=1`(env) 또는 `set_deterministic(true)`로 켬.
  `seconds_to_frames(s)` = `round(s × physics_ticks_per_second)`.
- **게임플레이 시계 프레임화(결정론 모드 한정)** — 기본 경로는 종전 그대로:
  - 스폰 grace: `Ant.arm_spawn_grace()`/`in_spawn_grace()`로 캡슐화. det 모드 = `Engine.get_physics_frames()` 컷오프,
    기본 = 벽시계(`Time.get_ticks_msec`). Home이 위임(직접 `_grace_until` 비교 제거).
  - 스폰 타이밍: `AntSpawner` det 모드 = `_physics_process` 프레임 게이팅(`_interval_frames`), 기본 = Timer.
  - 리스폰: `Home` det 모드 = `_pending_respawns` 프레임 데드라인 펌프, 기본 = per-ant Timer.
  - 스테이지 타임아웃: `StageRunner` det 모드 = `begin()` 시점 물리프레임 경과로 `time_left` 산출, 기본 = `_process` delta 누적.
- **`Ant.spawn_index`** 노출 (AntSpawner가 `_spawn_one`에서 세팅). 결정론 셀렉터/리플레이 안정 tie-break 키
  (instance_id는 실행 간 달라져 부적합).

### 검증 (`tests/DeterminismReplayTest.{gd,tscn}`)
- Stage11을 det 모드 + 동일 빈 플랜으로 **2회 in-process** 실행, 매 프레임 개미 스냅샷
  (spawn_index·pos·vel·state·dir·has_candy) + 종단 결과 **byte-identical 단언**.
- **결과: PASS — 960 프레임 per-frame 완전 일치.** (빈 플랜이라 `no_more_ants` 실패가 정상; 핵심은 run1==run2.)

### 속도 게이트 (실측, RogallyX, Godot 4.6.2 headless console)
| 구성 | wall | frames | sim 속도 |
|---|---|---|---|
| S11 default, `--fixed-fps` 없음 | 26.77s | 1561 | **58 f/s ≈ 실시간** |
| S11 결정론 + `--fixed-fps 60` | 1.10s | 1560 | **1416 f/s (~24x 실시간)** |
| startup baseline (`--quit-after 1`) | 0.82s | — | — |
- **게이트 통과**: 한 롤아웃(≈26s 게임플레이) wall ≈ 1.1s(startup 포함), startup 상각 시 **롤아웃당 ~0.3s**.
  목표 "≤ 수 초/롤아웃" 충분히 충족. 인-더-루프 아키텍처 진행 OK(Phase 2 차단 사유 없음).
- **가속 메커니즘 = `--fixed-fps`**: 없으면 헤드리스가 실시간(58 f/s)으로 페이싱됨(plan CRITICAL-2 확인). 솔버 하니스는 `--fixed-fps` 필수.
- **부수 확증**: S11이 결정론+fixed-fps에서 **올바르게 클리어**(saved=4/4, 1560f) → 프레임화가 클리어 판정 불변.

### 회귀 (기본 모드, `--fixed-fps` 없음)
- **신규 회귀 0건.** Phase 0 변경 전/후 비교(git stash 베이스라인 대조):
  - PASS(불변): `CampaignS11ClearTest`(saved=4/4), `CampaignS13ClearTest`, `StageRunnerBeginGateTest`(time_scale), `HomeNoRespawnAfterDepletedTest`(grace 직접 세팅).
  - FAIL(**선존 결함, 변경 무관**): `CampaignS12ClearTest`·`CampaignS14ClearTest`(time_out saved=0 frame=6000), `GameFlowTest`(await_signal timeout) —
    셋 다 **베이스라인에서도 동일하게 실패**(WIP 커밋 f918346 "ch1 클리어 드라이버 수정 진행 중"의 미완 드라이버). Phase 0와 무관, 별도 트랙에서 처리.
- 기본 모드는 `--fixed-fps`에서 비결정적(벽시계 grace) → 기존 테스트는 `--fixed-fps` 없이(run_test.py 기본) 돌아 무영향.

---

## Spike (2026-06-18) — 재접근 검증: 솔버가 손코딩 드라이버를 대체

> 동기 재정의: 솔버의 진짜 목적 = **손코딩 CampaignSxx 클리어 드라이버가 brittle**(레벨 재설계 시 하드코딩
> 해법이 깨짐 — S12/S14 등)이라 **레벨을 스스로 풀어 클리어 가능성을 검증**하는 것. 워크플로우 결정(사용자):
> **search-once → 플랜 고정 → CI는 빠른 리플레이**. 솔버 산출 플랜이 드라이버를 대체.

수직 슬라이스(blocker 전용) 실증:
- **`tests/SolverHarness.{gd,tscn}`** — 플랜 JSON(env `CANDYANTS_PLAN_PATH`) 읽어 blocker 액션(트리거: y-band+select(min_x/max_x)+x cmp)을
  결정론 헤드리스로 재생, 무수정 게임 verdict + 진척(best_min_y·picked·best_carry_home_dist)을 `SOLVER_RESULT` JSON으로 보고. Phase 1 PlanRunner 전구체.
  스킬 적용은 `BlockerSkill.new()`+can_apply, 총량 = stage 인벤토리(budget) cap = blocker 한정 D4-충실(SkillApplier 하드닝은 Phase 1).
- **`tools/solver/solve_spike.py`** — layout .tres 파싱(표면/물가/사다리 랜드마크) → blocker 후보 → **병렬 beam search**(진척 휴리스틱)
  + **국소 정밀탐색**(최선 플랜 주변 ±1셀 스윕). 후보별 SolverHarness 헤드리스 실행. 클리어 시 `data/solutions/stageNN.spike.json` 저장.
- **결과**:
  - **S11(양성 대조, 이미 풀리는 레벨)**: 12 롤아웃에 클리어 플랜 자동 재발견(`r12:max_xge21`, saved 4/4) → **탐색 기계 검증**.
  - **S12(깨진 타깃, 손드라이버 time_out 실패)**: **자동 클리어 플랜 발견** `[r13:min_xle1, r10:max_xge5, r7:max_xge6]`, **saved 5/5**, 228+92 롤아웃.
    → 레벨은 blocker×3로 **풀린다**(손드라이버가 틀렸던 것). 저장 플랜 **결정론 재현**(×2 identical, frame=2385, 각 ~1.4s) = CI 리플레이 테스트로 즉시 사용 가능.
  - **휴리스틱 교훈(→ Phase 2 설계 반영)**: height-only 단조 휴리스틱은 왕복(픽업→복귀)을 가지치기함. **candy 픽업 + home 근접** 신호 추가가
    S12 왕복 플랜을 드러냄. 거친 랜드마크 격자의 마지막 한 칸은 **국소 정밀탐색**이 닫음.

## 계획 개정 (2026-06-18) — 북극성 = 레벨 생성, 솔버 = 적합도 오라클
plan SoT를 생성 중심으로 개정([auto-solver-plan.md](../../phases/solver/auto-solver-plan.md)). 추가 결정 D5~D9:
- D5 타이밍 = 행동공간·난이도 1급 차원. D6 반응-윈도우 인간타당성 = 정합성+난이도 척추(난이도 = 가장 쉬운 해의 가장 빡빡한 윈도우, 절대·등급별).
- D7 자동 동기화(솔버 게임지식 하드코딩 0 — 엔진 인-더-루프 + self-describing 스킬 메타 + 전역 능력 config). D8 누적 학습(전술 라이브러리 CBR/EBL). D9 북극성=생성(생성-후-검증 + 구성적, 처리량 1급).
- 개정 phase: 0(✅) → 1 하니스+능력명세 → 2 탐색 → 3 반응윈도우/난이도 → 4 전술라이브러리 → 5 감사 오라클 → 6 생성(6a 실증→6b PCG→6c 구성적).

## Phase 1 완료 (2026-06-18) — 리플레이 하니스 + 능력 명세 (게이트 그린 + 적대적 리뷰 R9 approve)
> **적대적 리뷰 종결**: codex impl-stage R1 HIGH(stale stage)→R2 HIGH(동기 분리)→R3 HIGH(인스턴스-스코프 verdict)→R4 HIGH(단일활성런 가드)→R5 HIGH(재진입+after-index)→R6 MED(repeat 앵커)→R7 MED(deterministic 복원)→R8 MED(취소 _exit_tree)→**R9 approve**. 매 라운드 사이 자체 적대적 리뷰 clean. 트레일: [phase01-impl-review.md](../../phases/solver/reviews/phase01-impl-review.md). 커밋: 본체 `3004ce5` + sweep `2a50c14`/`6463cf2`/`b8405d0`/`79ef494`/`cd11aed`/`5b10166`/`757435d`/`d032cb5`.
> PlanRunner 강건성(리뷰 산출): 인스턴스-스코프 `StageRunner.concluded` verdict(글로벌 버스 cross-talk 0) + `static _active_run` 단일-활성-런 가드(동시 in-process 금지; 병렬화는 subprocess) + 동기 스테이지 분리(late verdict 0) + after 앵커 첫-발화 고정 + deterministic 복원(_finish/_teardown/_exit_tree).
손코딩 드라이버를 **데이터(플랜)** 로 대체 + 솔버가 능력을 **읽어** 행동공간 구성(D7). spike(blocker 전용)를 일반화·다중스킬화.

### 산출물
- **`scripts/core/SkillApplier.gd`** (D7·CRITICAL-1): 스킬 적용 **순수 규칙 단일 출처**. `apply_to_ant(id,ant,inventory)`(개미②③) + `place_on_cell(id,terrain,where,parent,inventory)`(셀①SIGN/④DEVICE, 카테고리 라우팅). 인벤토리(참조형) 성공 시에만 in-place 차감. `SkillToolbar._apply_skill/_place_sign/_place_leaf_jump_pad`를 SkillApplier 위임으로 리팩터(툴바는 슬롯 UI·SFX·terrain 탐색만). 미사용 `SignPlacementScript`/`LeafJumpPadScript` const 제거.
- **스킬 self-describing 메타**: 10 스킬에 `const SOLVER_META {target:"ant"|"cell", category, hints}`. `SkillRegistry`: `_metas` 수집(`get_script_constant_map`) + `skill_ids()`(결정론 정렬 generic 열거) + `solver_meta(id)`/`all_solver_metas()`. (메서드명 `get_meta`는 `Object.get_meta`와 충돌 → `solver_meta`.)
- **전역 능력 명세**: `scripts/core/SolverCapabilities.gd`(Resource) + `data/solver/capabilities.tres`(pause/slow 무, input_methods, T_human 3티어 기본값).
- **`scripts/core/PlanRunner.gd`**: 플랜(JSON)→`_physics_process`마다 트리거 평가(스코프=스테이지 루트 하위, tie-break spawn_index)→SkillApplier 적용→EventBus verdict 캐치→결과 dict emit. **D4 budget = 실행 중 StageData.skill_inventory**(스테이지 루트가 곧 StageRunner라 루트 우선 확인). 타이밍 트리거(D5): `at_frame`/`ant_reaches_x`/`ant_at_cliff`/`ant_on_wall`/`active_ants_le`/`picked_ge`/`after`. select: max_x/min_x/spawn_index. finished 후 스테이지 free + 시그널 해제(배치 누수 0).
- **`tests/PlanReplayHarness.{gd,tscn}`**: env `CANDYANTS_PLAN_PATH`→PlanRunner→`SOLVER_RESULT {json}` 1줄(SolverHarness 일반화 후속).
- **`scripts/run_plan.py`**: 단일 플랜 실행 + `--selftest`(골든 검증). `data/solutions/golden/*.plan.json`의 `expect`와 무수정 게임 verdict 대조.
- **`tests/PlanReplayHarnessTest`**: in-process. S11 클리어(saved 4/4) + **×2 byte-identical(배치 누수 0)** + 빈 플랜 음성.
- **`tests/SkillMetadataDriftTest`** (D7 가드): ① 솔버 열거==레지스트리 ② 등록·스테이지 인벤토리 스킬의 메타 완전성 ③ `SOLVER_META.category`==`SkillAffordance.category_of`(단일 권위 종속) + target↔category 정합 ④ capabilities.tres 로드·필드.
- **골든 5종** `data/solutions/golden/`: s11_blocker_clear(ANT, saved4)·s12_blocker3_clear(ANT 다중, **spike 바이트동일 frame=2385 saved5**)·s05_sand_mound_sign(CELL SIGN, incomplete 충실성)·s08_leaf_jump_device(CELL DEVICE, time_out 충실성)·s11_empty_negative(빈 플랜 음성).

### 검증 (게이트 = plan frontmatter `verify`, 그린)
`DeterminismReplayTest && DeterminismSpawnScheduleTest && PlanReplayHarnessTest && SkillMetadataDriftTest && run_plan.py --selftest` — **전부 PASS**.
- 회귀 0(SkillApplier 리팩터): `CampaignS11/S13ClearTest`, `Skill{RoutingByCategory,Affordance Category}Test`, `{SandMound,Basher,Cutter,LeafJump}SignTest`, `SignGroundSnapTest`, `SkillToolbar{CutterIntegration,Reentry}Test`, `StageRunnerToolbarDisableTest` PASS.
- `SkillDropAssignTest`는 **선존 플래키**(개미 WalkerState 진입 타이밍; git stash 베이스라인에서도 동일 산발 FAIL, 내 버전 4/4 PASS) — 변경 무관.

## Phase 2 WIP (2026-06-19) — 예측 기반 솔버 (커밋 묶음, 미완)

> 설계 SoT: 세션 플랜 `~/.claude/plans/glittery-weaving-stardust.md`(승인). blind generate-and-test를
> **예측 닫힌-루프**로 재설계: 베이스라인 관측(엔진 트레이스) → 진단 → 개입 1개 → 재관측. **엔진=진실(D4)**,
> 모델은 계획 가속 휴리스틱(D10). 성공=saved 100%(정합성). 롤아웃 상한 10/스테이지(미달 시 사용자 승인).

**산출물(이 커밋):**
- `tools/solver/model.py`(순수 예측: 레이아웃 파싱 + 트레이스 진단 + 개입 제안) + `tools/solver/solve.py`(닫힌-루프 오케스트레이터).
- `tests/SolverMetaDump.{gd,tscn}`(D7 능력/메타 덤프 브리지) — Python 솔버가 SkillRegistry 메타를 읽음.
- **스킬 메타 확장(D11)**: 10 스킬 `SOLVER_META`에 `routing`(reverse/up/down/cross/break/jump/safe_fall) + `purpose`. `SkillMetadataDriftTest`가 완전성 강제. `StageData.skill_notes`(optional 도구별 용도 비고, 비구속).
- **PlanRunner 가산 확장**: 궤적 트레이스(plan `trace:true`, 게이트) + `picked_total`/`remaining_hp` 결과 필드. 게임 동작·verdict 불변.
- 해 플랜: `data/solutions/stage11.solve.json`(saved 4/4)·`stage12.solve.json`(saved 5/5) — predictive 100%.

**진단·점수 규칙(사용자 통찰 누적):**
- 낙하 가장자리 반전(blocker) + **x 변형 off=0,1,2(대응 지점 -2타일까지, 현실 타이밍)**. 상승 라우팅(반대편 사다리 유도). safe_fall(floater) 방어 대응.
- early/late climber 둘 다 후보(S13=early, S14=late; 엔진이 고름). 무장 up은 귀로 단계 최우선.
- **루프(블로커 충돌) 감지 = saved==0일 때만** 보정(집 도달 개미 있으면 무시). **점수 최우선순위 = saved → 리타이어 최소 → picked**(전원 생존을 candy 도달보다 우선).
- 리포트: **리타이어 낙하/물 구별** + 사용 도구 수(`search_meta.retired_ants{water,fall,total}`/`tools_used`).

**현재 성적:** S11 100%(2롤)·S12 100%(11롤). S13 부분(climber 조합 thrashing). S14 **리타이어 8→0**(survival-first 발판) 그러나 candy 미도달.

**verify 게이트:** 결정론×2 + PlanReplayHarnessTest + SkillMetadataDriftTest + run_plan --selftest = **5/5 PASS**.

## Phase 2 WIP 속행 (2026-06-19 세션2) — S14 물리 규명 + 모델 4-fix + lookahead 인프라

> 이 세션 동기: S14 계단 하강. **상태 트레이스로 S14 실패 물리를 규명**하고, 사용자 통찰을 모델에 정밀
> 반영. S14는 **검증된 해 존재**(수동 구성, 엔진 verdict로 100% 확인)이나 닫힌루프 자동발견은 미완.

### S14 물리 규명 (상태 트레이스 도입으로 확정)
- **낙하 드리프트가 사인**: `FallerState`가 낙하 중 수평속도(`velocity.x = direction × speed × 0.5`)를 줌.
  P_r4 우측끝(x23)에서 10칸 낙하 시 x23→x24로 밀려 **바닥(x23 solid)을 놓치고 물(x24)에 빠짐** —
  `is_on_floor()`가 한 번도 참이 안 돼 stun 미발생, `AdriftState`(=익사, is_alive=false)로 종착.
- **낮은 낙하점 생존**(사용자 통찰 확증): P_r10(row9→바닥 4칸)은 드리프트 적어 **x23 바닥 착지·생존** 후
  보행. 즉 "낮은 낙하지점에서 생존해서 물로 걸어감"이 정확. candy(22,13)는 우측 가장자리 낙하가 전부
  물행인 "주머니" — **좌측에서 바닥을 걸어 접근**해야 도달.
- 레이아웃(48px셀): P_r4(x12-22,row3)→P_r7(x8-18,row6)→P_r10(x12-22,row9)→바닥(x0-23,row13). 좌측 매시프
  (x0-4) + 사다리(x3,row2-5). 귀환 = 바닥→x4 벽 **climber** 등반→상단→home.

### 모델 4-fix (사용자 통찰 정밀 반영)
1. **물 우선 + 동선 backpath** (`model.diagnose`/`propose`): 반전 타깃을 **물 익사 가장자리 우선** 정렬.
   off=0,1,2 변형을 **좌표(x-off)가 아닌 개미 동선의 grounded 타일을 거슬러** 잡음(공중 낙하 타일 건너뜀)
   — 계단처럼 접근이 비수평이어도 실제 보행 타일에 정착, 거슬러 갈수록 발화 여유↑.
2. **상태 트레이스** (`PlanRunner._record_trace`/`_state_code`): 샘플에 walk/fall/climb/carry/dead/lost 동봉
   (가산적·결정론, **트레이스 byte-identical·verdict 불변**). 모델이 낙하생존 vs 낙하사 vs 익사를 추측 없이 구분.
3. **`count_retired` 수정**: 옛 `_max_fall_run>=5` 휴리스틱이 **낙하 생존자를 거짓 낙하사 카운트** →
   score 오염(하강 기피)시키던 버그 제거. 실제 종단 상태(dead) + below-hazard(익사) 사용. (`_max_fall_run`/
   `FALL_STUN_CELLS` 제거.)
4. **`best_goal_dist` score**: `best_min_y`(항상 '위로' 보상)를 candy/home 셀 맨해튼 접근으로 교체 →
   candy가 아래(S14)면 하강을, 위(S11/S12)면 상승을 보상(방향 무관 진척).
- 추가: **carry-climber 제안**(`select=min_x, state=carrying`, picked_ge n) — 운반 개미 귀환 무장(S14 핵심).
- 추가: **2-스텝 lookahead**(`solve.py`) — 1-스텝 정체 시 **goal_dist 최근접 first-step**에서 재진단→second
  평가(retired-우선 score 아님 — candy 근처서 익사한 디딤돌이 핵심). S13 문서화 과제(2-액션 lookahead) 겸용.

### S14 검증된 해 (수동 구성, 엔진 D4 verdict = 100%)
- 플랜: **blocker×3 계단**(P_r4 reverse-left @x22,row3 · P_r7 reverse-right @x8,row6 · P_r10 reverse-left
  @x21,row9) + **climber×5**(운반 개미, `min_x/carrying`, picked_ge 1..5). → **saved=5/5, frame=4560**
  (시간제한 6000 이내). 5마리 전원 candy 픽업(reached=5 @frame 4694) 후 x4 벽 등반 귀가.
- **시간 타당성 확인**: 계단 하강 자체는 충분히 빠름(reached 4694). 1-블로커 단독 지그재그가 느렸던 것.

### 자동발견 → 2026-06-19 세션3에서 해결 (아래 "S14 자동발견 성공" 참조)
- (당시 추정) lookahead 깊이/frontier 문제로 봤으나 **실제 원인은 score 기각**: 솔버는 LA2로 blocker×3 →
  reached=5(전원픽업) 디딤돌을 이미 발견(롤16~21)했으나, climber 없이 귀환 불가→사망→retired 정당→
  score(retired>picked)가 "0픽업0사망"(blocker1)을 우대해 디딤돌을 기각, climber 얹을 trace에 미도달.
- 정책: 사용자 = "**해를 찾아내는 것만으로 phase 성공**, 솔버는 계속 고도화". 검증된 해 존재 = 성공 신호.

### 검증/회귀 (이 세션)
- **verify 게이트 5/5 PASS**: DeterminismReplay/SpawnSchedule + **PlanReplayHarnessTest(byte-identical 포함)**
  + SkillMetadataDrift + run_plan --selftest(골든 5/5, s12 frame=2385 동일). 트레이스 state 추가가 무영향.
- **회귀 0**: S11 100%(2롤)·S12 100%(11롤) 유지. `stage12.solve.json`은 search_meta 필드만 추가(해 동일).
- (게이트 주: `PlanReplayHarnessTest`는 13런이라 run_test 기본 `--quit-after 3600`에 걸려 EXIT 0[timeout-마스킹].
  `--fixed-fps 60 --quit-after 60000`로 완주시 **PASS 명시 확인**. 선존 게이트 약점 — 차후 게이트에 fixed-fps 추가 검토.)

## S14 자동발견 성공 (2026-06-19 세션3) — score 전원픽업 디딤돌 + carry 연쇄

> 동기화(b49d0d6=다른 PC Phase2 WIP) 직후 S14 자동발견 완료. LA2 로그로 정체 근본원인 규명 후 2-fix.
> 사용자 2통찰이 핵심. (반증 기록: 첫 가설 "count_retired water 오판"은 수정해도 결과 0변경 → 갇힌
> 개미는 실제 사망, retired 정당 → 되돌림. 진짜 원인은 score 디딤돌 기각.)

**2-fix (tools/solver/ 18줄, 엔진/PlanRunner/테스트 무변경):**
1. **전원픽업 디딤돌 우대** (`solve.score`): `remaining_hp==0`이면 picked를 retired보다 우선
   (retired>picked는 전원픽업 전까지만 적용). 디딤돌(blocker3=전원픽업) 기각 해소 → climber 얹을 trace 도달.
   사용자 통찰: 사탕과 충돌(픽업)=방향전환 → 그 다음 집으로 가는 장애물을 climber로 대응.
2. **carry 연쇄** (`model.propose` carry exclude 면제 + `solve.eval_cands` action-dup 가드): carry가 tried로
   막히면 early/afterpick으로 흩어져 **비운반 개미 무장→candy 미도달·등반 무한루프**(사용자 통찰). carry를
   plan 누적 시 재평가 가능케 → carry1→2→…→5 연쇄 채택. 중복 롤아웃은 action-dup 가드가 차단.

**결과:** S14 **SOLVED 100%** — blocker×3 + climber×5(8액션), saved=5/5, frame=4624, rollouts=40.
검증 수동해와 일치. `data/solutions/stage14.solve.json`(결정론 재현: run_plan 리플레이 cleared/saved=5/frame=4624).
**회귀 0**: S11 2롤·S12 11롤 100% 불변, run_plan --selftest 골든5 PASS.
**cap 메모**: S14=40롤·S12=11롤로 기본 cap10 초과(사용자 "해 찾으면 성공" 정책 하 허용 — 미달 시 사용자 승인).

## S13 자동발견 성공 (2026-06-20) — Phase 2 완료 (S11~S14 전부 무힌트 자동 해결)

> S14 인프라(carry 연쇄 + 전원픽업 디딤돌 score)로 **코드 변경 0**(tools/solver 무수정). cap만 올려(40)
> 기존 예측 솔버가 그대로 풀었다. "솔버 진단은 LA 롤아웃 로그로 좁히고 가설은 재실행으로 검증" 교훈 재확인.

**진단(롤아웃 로그)**: 베이스라인 saved=0(no_more_ants — 무개입은 candy 미도달). 솔버가 blocker@(17,6)을
**전원픽업 디딤돌**로 채택(reached=5, 단 5마리 carrying 갇힘). 이어 climber **carry1~5 연쇄**가 saved를
1→2→3→4→5로 **단조 증가**(S14와 동일 메커니즘) → carry5 롤아웃에서 saved=5 `_Clear`. 정체 근본원인은
**cap 10 부족 하나**뿐이었음(blocker 탐색 6롤 + carry 연쇄 5라운드 > 10). S12(11롤)·S14(40롤) 선례대로
cap 상향(사용자 "해 찾으면 성공" 정책). carry가 saved를 못 늘리는 로직 문제는 **없었음**(cap 25 재실행으로
carry1→saved1, carry2→saved2, carry3→saved3 단조 증가를 직접 관측해 반증).

**해**: blocker×1 @ (17,6) max_x(x=840 ge) + climber×5 (carry1~5, picked_ge n / min_x·carrying).
saved=5/5, frame=2719, rollouts=26. `data/solutions/stage13.solve.json` (결정론 재현 확인).

**CI 회귀 게이트 편입**: `scripts/run_plan.py --selftest`를 확장 — 기존 golden(5) + **`data/solutions/*.solve.json`(4)**
까지 결정론 리플레이해 무수정 game verdict와 대조. S11~S14 자동발견 해(saved 100%)가 엔진/스킬 변경에 조용히
깨지면 selftest가 잡는다(D4). **verify 프론트매터 문자열은 무변경**(이미 `--selftest` 포함) — selftest 내용
확장이 곧 Phase 2 게이트 편입(중복 없는 강제 계약).

**검증**: ① S13 해 리플레이 saved=5/5 frame=2719(solve.py와 byte-identical) ② verify 게이트 5/5 PASS
(회귀 0: DeterminismReplay/SpawnSchedule/PlanReplayHarness S11 4/4/SkillMetadataDrift 11/selftest)
③ selftest **9/9**(golden 5 + solve 4: stage11 saved4 · stage12·13·14 saved5).

**Phase 2 Acceptance(plan §Phase 2) 충족**: S11(2롤)·S12(11)·S13(26)·S14(40) 전부 실제 인벤토리로
무힌트 자동 해결 + 게임 verdict 100%(D4). **탐색 솔버 단계 완료.**

**적대적 리뷰 종결**: codex R1(needs-attention, HIGH = selftest fail-open "golden 존재 시 solve 누락/빈
expect가 verdict-only 통과") → fail-closed 수정(EXPECTED_SOLVE_STAGES 누락 즉시 FAIL + solve glob 멤버십에
`cleared:true`+`saved≥1` 강제 + `_selfcheck_schema` 음성 자가검증) → self-review R1(self-HIGH 정규식→멤버십)
→ **R2 approve**. 커밋 `bdb23c1`(S13+게이트) + sweep `94078f0`(fail-closed). 트레일 `phases/solver/reviews/phase02-impl-review.md`.

## Phase 3 진행 중 (2026-06-20) — plan stage approve + PlanRunner 가산①② (회귀 0, 미커밋·미완)

> 트레일: plan-review [phase03-plan-review.md](../../phases/solver/reviews/phase03-plan-review.md) R1~R4.
> plan SoT Phase 3 v3 확정([auto-solver-plan.md](../../phases/solver/auto-solver-plan.md)).

### plan stage 종결 (codex 적대 4R → approve)
- R1(C1C2H1H2H3H4M1M2L1) → R2(H1H2H3M1M2M3) → R3(H1M1M2M3L1) → **R4 approve**. R4는 사용자 cap 연장 승인.
- **핵심 진화**: "엔진 무변경"→**"엔진 가산 opt-in 확장"**(trace 패턴). 윈도우 측정 = spawn_index 고정 +
  at_frame_exact 스윕(시간 1급) + ant_reaches_x x스윕(위치 보조). 최소화 = deletion-minimal(고정순서 순차
  제거), cardinality는 `--prove-cardinality` opt-in. 측정 대상 = "발견된 해(현 solve.json)"(max-margin은 3b).
  T_human = provisional(tier_source=default_uncalibrated). 게이트 = analyze.py --verify(interval/gap +
  coverage 선검증, incomplete=FAIL).

### impl: PlanRunner 가산①② 완료 (회귀 0)
- **가산①** `report_fired:true` → SOLVER_RESULT에 `fired_actions:[{index,label,skill,frame,target_kind,
  spawn_index?/target_pos?/target_cell?}]`. analyze.py가 baseline에서 f*·대상 ID 획득(stdout regex 불요).
- **가산②** `at_frame_exact{frame}`: `_frame==frame` 단발 평가(no-retry, 정확 프레임 발화). 기존 at_frame(>=) 불변.
- `_fire_cell` bool→Dictionary(placed,cell)(cell-target fired 기록), `_mark_fired(act, fired_info)`.
- **회귀 0(byte-identical)**: verify 게이트 5종 PASS — DeterminismReplay(962f)/SpawnSchedule/PlanReplayHarness
  (S11 4/4)/SkillMetadataDrift(11)/run_plan --selftest(골든5+solve4, s12=2385·s13=2719·s14=4624 동일).
- **작동 실증**: stage11 report_fired → blocker fired f*=581 si*=0. at_frame_exact 스윕(spawn_index 고정):
  frame 550·581 clear / 300·450·620+ 실패 = 시간 윈도우 [~550,~600] 드러남. no-retry 확인(450·620 fired=0).

### impl: analyze.py 완료 (2026-06-20, 회귀 0 · verify 게이트 그린)
- **`tools/solver/analyze.py`**(순수 오케스트레이터, 엔진 무변경): (A) 최소화 deletion-minimal(identity
  기반 제거 가드) + opt-in `--prove-cardinality`(부분집합 브루트포스, 기본 off·verify 미포함) / (B) 윈도우
  측정 = baseline(1-minimal) report_fired+trace 1회 → 각 필수 액션의 `(spawn_index*, f*)` 획득 → spawn_index
  고정 + at_frame_exact 스윕(기하 도메인 bracket → 경계 binary 정밀 → `_reconstruct_runs` gap 검출). 위치
  윈도우는 ant_reaches_x 한정·보조(원본 x 스윕, **도메인=trace 도달 x로 제한**해 ge/le 단방향 포화를
  `saturated_lo/hi`로 정직 표기; verify 게이트 비포함) / (C) T_human 분류 provisional(tier_source=
  default_uncalibrated) / (D) `stageNN.analysis.json` + 콘솔 / (E) `--verify`: gate self-check(검출기 음성
  6 거부) + 빈 대상 FAIL + coverage 선검증(index/label 1:1·incomplete 필수 액션 0) + interval 내부=clear/양
  끝 밖=fail/gap 내부=fail 리플레이 + 1-minimal 자체 클리어.
- **sweep_target 핵심**: spawn_index 고정 시 `y_min/y_max/dir` **드롭**(원본은 공간 *선택* 수단인데 핀하면
  스윕 프레임에 개미가 밴드 밖이라 잘못 배제 — `_select_ant`가 y-band를 spawn_index 매칭 전에 거름),
  `state`만 보존(없으면 "any"; 기본 walker면 carrying 미선택·S13 깨짐, R2-H2).
- **측정 결과(S11~S14, `data/solutions/stageNN.analysis.json`)**: 전부 1-minimal=원해(잉여 0). 시간 윈도우
  binding(스테이지 최소): S11=2.28s(blocker)·S12=1.35s(blocker#2)·S13=1.98s(blocker#0)·S14=1.43s(climber#3).
  **전부 comfortable(>0.3s)·provisional_machine_only 0**(튜토리얼 난이도와 정합). 통찰: blocker 반전이
  타이밍 binding, **carry climber는 5~72s로 매우 관대**(운반 개미는 무장 시점 여유). gap 0(전 액션 단일 연속
  구간). cell-target 필수 액션 없음(스키마만 준비).
- **게이트 = `analyze.py --verify` 그린**: S11(4체크)·S12(10)·S13(19)·S14(25) = 58 경계 재검증 롤아웃 전부
  정확. plan frontmatter `verify`에 `&& python tools/solver/analyze.py --verify` 편입(3a 완료 정의).
- **회귀 0**: 기존 verify 5종 그린 — DeterminismReplay(962f)·SpawnSchedule·PlanReplayHarness(S11 4/4)·
  SkillMetadataDrift(11)·run_plan --selftest(골든5+solve4, frame byte-identical s12=2385·s13=2719·s14=4624).
  analyze.py는 신규 툴이라 엔진/PlanRunner 무변경(가산①②는 선커밋 `02c2d43`).
- **단위 검증**: prove_cardinality 양/음 분기 + classify_tier 경계 + _reconstruct_runs(연속·gap 분리) +
  gate self-check 모킹 통과.

### 적대 리뷰 (impl stage) — **종결: codex 14R → R14 approve** (트레일 `reviews/phase03-impl-review.md`)
- **14 codex 라운드 + 15 자체 라운드**. 모두 "verify가 analysis.json 필드를 무검증 신뢰"하는 fail-closed
  누수였고, 권위 출처(solve.json·capabilities.tres·엔진 리플레이)에서 재검증하도록 전부 닫음:
  - R1~R6 HIGH: pos incomplete 게이트 / gap stride 명시·dense 재스캔 / solution sha256·파일명 바인딩 /
    파생 재계산 / 1-minimality deletion 트라이얼 / tri-state verdict(infra 실패 fail-closed).
  - R7~R10 HIGH: pos 차원(스키마·경계·gap·셀렉터 핀) → 결국 **bouncing 개미에 x-임계 스윕이 근본 모호**라
    informational `pos_hint`(시간윈도우+trace 파생, authoritative:false, verify 비대상)로 격하해 종결.
  - R11 HIGH: `analysis_schema_version` 가드(의미 변경 stale 차단) + 레거시 pos_window 거부.
  - R12 HIGH: gap sampled 정직표기(gap_verified/gap_coverage, 과대주장 제거 — 사용자 결정 "sampled 표기" 채택).
  - R13 MEDIUM: sampled disclosure note 강제. **R14 approve(no material findings)**.
- **디버그(R10)**: cp949 UnicodeEncodeError가 `--all` 중간 크래시 → stale(여러 재측정 미반영 원인) → UTF-8
  stdout 강제. 커밋: `78736e6`/`9c93785`/`4fdd8e1`/`f63211f`/`1513be3`/`7b21cb5`/`fdd1ae8`/`a422459`/`254a811`/
  `5dc8c3c`/`3b2fed8`/`436205e`/`aa573d7`/`cb954f5`.

### 최종 게이트 (frontmatter `verify`, 그린)
결정론×2 + PlanReplayHarness(S11 4/4) + SkillMetadataDrift(11) + run_plan --selftest(9/9) + **analyze.py --verify
(4스테이지 272체크)**. 회귀 0(엔진 무변경, 가산①②는 선커밋 `02c2d43`).

### 측정 결과
S11~S14 전부 1-minimal=원해(잉여 0). stage_min(binding): S11 2.28s / S12 1.35s / S13 1.98s / S14 1.43s(전부
comfortable·sampled@stride 추정). pos는 informational pos_hint. **Phase 3a 완료.**

### 남은 작업 (선택)
- T_human 라벨 pre-register 대조(`--labels` Spearman) — 게이트 아님, 사용자 난이도 순위 입력 시.
- 3b(스케치): T_human 티어 보정 + 대안 해 탐색(max-margin) + 권위 난이도(binding 윈도우 full-scan).

> **상태**: analyze.py + 4 analysis.json + plan.md(verify 편입) + STATUS **워킹트리 미커밋**(codex 리뷰 후
> 커밋 예정). PlanRunner 가산①②는 선커밋 `02c2d43`. 워킹트리에 사용자 챕터2 WIP 동시 존재 — analyze.py 무관.

## 트랙 범위·게이트 신뢰도 갱신 (2026-06-20) — 미커밋(적대 리뷰 R1→R3 approve, 커밋 대기)

> 사용자 정렬 2건. 상세는 plan SoT §"트랙 범위·게이트 갱신".

**① 트랙 범위 축소**: 생성은 솔버 역할 아님 → 솔버 학습 결과를 *참조하는 별개 소비자*. **Phase 5(감사
오라클)·6(생성)은 auto-solver에서 분리해 별도 브랜치**로. 본 트랙 = **Phase 0~4(학습 결과 생산)** 까지.
고도화 방침 = 실제 미검증 스테이지를 솔버가 풀어보며 함께 개선(현 검증 = S11~S14).

**② 게이트 false-green 제거 (신뢰도)**: 옛 약점 — `PlanReplayHarnessTest`(멀티런, >18000f 필요)를 bare
`run_test.py`로 돌리면 `--quit-after` 안전망이 **exit 0(=PASS와 동일)** 으로 끝나 타임아웃이 통과로 위장.
실측 확정: 게이트-기본 호출이 ⑤에서 잘려도 EXIT 0·PASS 마커 없음(126s) / `--fixed-fps`+18000도 잘림
(예산 부족) / `--fixed-fps`+120000만 완주·PASS. → **순수 프레임 예산 부족 + exit-code 충돌**.
- 수정 = **`tools/solver/try_solve.py` front-door 분리**(사용자 원칙 "run_test 기능중심, 스테이지 풀이는
  try_solve"). replay/selftest/search는 `run_plan.py`·`solve.py` import-위임(동작 불변), 신규 `harness-test`는
  **PASS = 마커 AND exit 0 둘 다 요구**로 판정 + `--fixed-fps 60`·budget 120000. 두 fail-open 모두 차단:
  타임아웃("exit 0 + 마커 없음", 가드 실증 budget=2000→FAIL) + 마커 후 비정상 종료("마커 + nonzero"→FAIL, codex R2).
- 게이트 재구성: Determinism×2·SkillMetadataDrift는 run_test 유지 / PlanReplayHarnessTest→`try_solve harness-test`
  / `run_plan --selftest`→`try_solve selftest`. run_test.py docstring drift(3600→18000) 정정 + exit-0 caveat 명시.
- **전체 게이트 그린(최종 코드)**: 6/6 PASS·EXIT 0·269s (harness-test PASS·selftest 9/9·analyze --verify 4스테이지).
  회귀 0(replay/selftest frame byte-identical s12=2385·s13=2719·s14=4624). `run_plan.py`는 back-compat 유지.
- **적대 리뷰(impl, codex working-tree)**: R1 MEDIUM(§검증 방법 옛 게이트 레시피 drift)→수정 / R2 MEDIUM×2
  (harness_test가 마커 후 nonzero 삼킴=fail-open + §검증 item4 max-margin 과대주장)→수정 / **R3 approve(no material
  findings)**. 매 라운드 사이 자체 적대 리뷰. cross-doc 정정: §검증 방법·Phase1 Acceptance·Phase2 CI게이트·Phase5/6
  헤더·item4. (STATUS 과거 세션 로그·`reviews/*.md`는 immutable 히스토리라 의도적 미수정.)

## Phase 3b plan-stage → ⛔ DEFERRED (2026-06-20, 실측 증거 + 사용자 Option C)

> 트레일: [phase03b-plan-review.md](../../phases/solver/reviews/phase03b-plan-review.md). plan §3b = DEFERRED 배너.

- **범위 정렬(Option A)**: 3a 증거(S11~S14 전부 comfortable 동일 티어, spread 0)로 T_human 보정 시기상조 →
  3b를 **max-margin 대안 해 탐색**만으로 좁힘(R1-H4 해소). placement coordinate-ascent 설계(knob=position-
  triggered blocker 변형 → 전 필수 액션 min-window 최대화; binding non-knob이면 간접 완화 기대).
- **codex plan-review R1**: needs-attention(4H+2M+1L). HIGH-1 격자 도메인 미정의 / HIGH-2 verify fail-open /
  HIGH-3 candidate-local 재발화 누락 / HIGH-4 빈 탐색 통과 / MEDIUM-1 sampled 과대주장 / MEDIUM-2 cross-doc /
  LOW S14 간접완화 추측. HIGH-1/2/3·MEDIUM-2는 plan 수정 반영.
- **실측 probe(엔진 D4)가 핵심 전제 반증**: placement 변형이 binding 윈도우를 **전혀 못 움직임**.
  - S12(binding blocker#2 81f): 18변형 9클리어 **0 widened** (다른 knob·자기 knob 전부 81f 불변).
  - S14(binding climber#3 86f): 18변형 9클리어 **0 widened** (blocker 간접완화 가설 거짓).
  - 근본: 난이도=구조/메커닉 결정(placement 아님). 3a binding이 이미 placement-local max-margin →
    placement-only coordinate-ascent vacuous(codex R1-H4가 가설 아닌 현실). T_human 축도 spread 0으로 막힘.
- **결정 = Option C(사용자)**: 3b 보류. **미검증 실제 레벨을 풀어 difficulty spread + 새 구조 코퍼스 먼저 생성.**
  3b 재진입 시 우선 = **cross-structure 대안**(placement 아닌 다른 스킬 multiset; placement는 실측 무효).
- **코드 무변경**(maxmargin.py 미구현, verify 프론트매터 그대로). 회귀 0.

## Option C 킥오프 (2026-06-20) — 챕터-그라운드 landscape + bridge routing 추가 (S3 solved)

> 사용자 정정: 솔버 타깃은 **파일 넘버링이 아니라 `data/campaign_manifest.tres` 챕터 배치** 기준.
> Ch1 기초=[1,11,12,13,14,2,15,16,17,18] / Ch2 건설=[3,4,5,19,20,21,22,23,24,25] / Ch3 파괴=[6,7] /
> Ch4 장치=[8] / Ch5 종합=[9,10].

**솔버 커버리지 landscape (try_solve search, cap 8~10):**
- **즉시 SOLVED**: S2(floater 2롤)·S4(slideR 2롤) — 기존 routing으로 풀림. solve.json 신규 생성.
- **NO-PROPOSE(routing 부재)**: S3·S9(bridge=cross) / S5·S19(sand_mound=cell-up SIGN) / S7(basher=break) /
  S8(cutter/leaf_jump) — `model.propose`가 해당 routing 미처리. (basher/cutter/digger/leaf_jump=Ch3/4, 후순위.)
- **CHECKPOINT(제안하나 cap 내 미해결)**: S1(climber 부분 saved1/3) / S15~18(Ch1, blocker/climber/floater만 쓰나
  cap10 미달 — S13 26롤·S14 40롤처럼 **cap 부족 의심**) / S20~25(Ch2, 일부 스킬만 제안·bridge/sand_mound 부재).
- **결론**: Ch1은 routing 다 있음(cap·휴리스틱 튜닝 과제). **Ch2 핵심 = bridge(cross)+sand_mound(cell-up) 두 routing.**

**bridge(cross) routing 추가 — S3 SOLVED (커밋 대기):**
- **변경 = `model.propose` 1줄**: `("reverse","safe_fall")` → `(...,"cross")`. BridgeSkill이 ANT_ARMED·
  `arms_until:cliff`(무장 개미가 낙하 가장자리서 자동 건설)라 **기존 ① 낙하-가장자리 기계에 그대로 편입**
  (diagnose가 이미 물/허공 가장자리 검출). cell-target 신규 분기 불요.
- **결과**: S3 "웅덩이 넘기" SOLVED 5/5(bridge×2, 5롤, `stage03.solve.json`). selftest **12 플랜 PASS**(golden5 +
  solve7: 02·03·04·11·12·13·14) 회귀 0. 격리 확인: model.py diff=내 1줄만.
- **자체 검토(clean)**: bridge 미보유 스테이지(S11~14 등)는 `by_r["cross"]` 빈 리스트 → 후보 0 → 검색 불변
  (selftest 기존 해 frame byte-identical). 결정론(고정 순서·가중 정렬) 유지.
- **게이트 커플링 수정(analyze.py verify decouple)**: 새 solve.json(02/03/04) 추가가 `analyze.py --verify`를
  FAIL시킴 — `_verify_target_ids`가 `analysis ∪ solve` 합집합이라 "solve 있는데 analysis 없으면 FAIL"(R3-H1
  1:1 시절 설계). **Option C는 측정(3a) 없이 해만 먼저 쌓으므로** verify 타깃을 **측정된 `analysis.json`만**으로
  decouple(`return _analysis_stage_ids()`). solve-without-analysis = "풀렸으나 미측정" 유효 상태(replay 정합은
  selftest가 모든 solve에 fail-closed 강제). **orphan analysis 가드(analysis→solve 바인딩, R3-H1 핵심)는 보존.**
  ⚠ fail-closed 가드 의미 변경이라 codex 리뷰 후속 권장(이번은 사용자 "지금 커밋" 정책으로 선커밋).
- **전체 게이트 green**: Determinism×2 + SkillMetadataDrift(11) + harness-test + selftest(12플랜 EXPECTED[2,3,4,
  11~14]) + analyze --verify(decoupled, 4 analysis). 회귀 0(엔진 무변경; model.py/analyze.py는 솔버·게이트 툴).

**⚠ 병행 사용자 WIP (워킹트리, 세션 시작 후 등장):** `SandMoundSkill.gd`(can_apply 운반자 통일 2026-06-20)·
stage17/21/22/23/25(tres/tscn/layout)·project.godot·SandMoundCarryBuildTest = **사용자 ch2/sand_mound 능동 작업**.
→ **내 커밋은 내 파일만 선택 staging**(model.py + stage02/03/04.solve.json + 3 docs), 사용자 WIP 미포함.
→ **sand_mound 솔버 작업은 보류·코디**(사용자가 SandMound 능동 수정 중 — racing 방지). 내 sand_mound 스캔(S5/S19/
S21~25)·S17/21/22/25 스캔은 in-flux 레벨 대상이라 잠정치.

**Ch1 cap 튜닝 결과(cap40, 커밋 대기):** routing 있는 Ch1은 cap 상향으로 풀림(S13/14 선례 확인).
- **S1 climber3 SOLVED 3/3(13롤)** / **S15 climber5+floater2 SOLVED 5/5(32롤)** / **S16 blocker3+floater1
  SOLVED 5/5(32롤, floater 2액션 중 1 inventory no-op)** / **S18 부분 saved4/5(37/40롤 — cap 더 필요)**.
- 신규 solve.json 3개(01/15/16). selftest **15플랜 PASS**(golden5+solve10). EXPECTED에 1·15·16 추가.
- S17 제외(사용자 WIP). S18은 cap50+ 재시도 or 휴리스틱 개선 과제.

## stage17 "돌고 도는 길" SOLVED — 천장-인지 reverse 배치 (2026-06-22, 커밋 대기)

> 사용자가 단계적 통찰을 주고 솔버가 **스스로 로직으로** 풀게 한 세션(사용자 요구: "의도된 위치를 받는 건
> 의미 없다, 솔버가 개미 경로를 시뮬레이션해 논리로 찾아야 한다"). model.py만 변경, 엔진/PlanRunner 무변경.

**레벨 구조(파일 17 = Ch1 9번째, blocker×4 / hp5 / 9마리)**: 피라미드 4단(바닥 row13 / L1 row10 / L2 row7 /
맨위 row4) + 중앙 sand_mound 사다리(정적, 상승 전용 — 꼭대기 위가 solid라 위에서 진입 불가) + 양옆 물. home은
사다리 **왼쪽**(col5), candy는 맨위(14,3). spawn dir=-1(왼쪽). 4난관: ①왼쪽 물 방지 ②사다리로 상승 ③candy
픽업 후 **낙하**로 층층이 하강(사다리 하강 불가) ④사다리 **왼쪽**에 착지시켜 home 직행(오른쪽 착지 시 사다리가
위로 빨아들여 무한 순환).

**진단(방법론)**: `report_fired`+`trace`로 운반 개미 동선 vs 설치 blocker 위치를 셀 단위 대조 → 픽업 후 운반
개미 5마리가 `(8,3)`↔`(17,6)` blocker 사이를 365프레임 주기로 시간 끝까지 **무한 왕복**(carry 방문 60회)임을
규명. blocker 단계별 방문-타일 HTML 시각화로 사용자와 공유(파랑=빈손/상승, 빨강=운반/왕복).

**근본 원인**: blocker는 영구·양방향 벽 → candy로 올려보내는 상승 유도 blocker `(17,6)`가 맨위 낙하 경로
(col17, 상공이 뻥 뚫림) 위에 있어 착지 개미가 재충돌. climber 부재라 carry 연쇄 탈출구도 없음.

**사용자 통찰 → 솔버 로직 2건 (model.py):**
1. **천장 선호** (`_has_ceiling` + `ceil_w=4` 가중): reverse blocker는 **상공에 solid 천장이 있는 셀**을
   선호한다. 천장이 있으면 위층 개미가 그 열로 못 떨어져 착지 재충돌이 없다. 실측 확증: L2 3번째 blocker가
   col17(천장無)→saved 0 무한왕복, **col9~16(맨위 플랫폼이 천장)→전부 saved 5/5 CLEAR**.
2. **천장 reverse 후보 exclude 면제**: 한 단계에서 단독 기각된 천장 blocker가 다른 blocker와 **함께라야**
   진척하는 상호의존(`16,6`은 `8,3`과 함께라야 맨위 도달+귀환)을 greedy/LA2가 놓치지 않게, 천장 후보는
   `exclude(tried)` 면제해 plan 맥락 변화 시 재평가(carry 연쇄와 동일 패턴, 중복은 action-dup 가드 차단).
   *함정 규명*: 천장 보너스로 `16,6`이 1단계에 일찍 평가→tried 소진→2단계에서 exclude로 제외→LA2가
   `16,6+8,3` 조합 못 만듦. 면제로 해소.

**해**: `[@1,12, @24,12, @16,6, @8,3]`(전부 천장 있는 위치) → saved 5/5 frame 3367 rollouts 19.
`data/solutions/stage17.solve.json`. selftest EXPECTED에 17 추가.

**회귀 0**: selftest 16 plans PASS(golden5+solve11, stage17 포함 무결) + **S11~14 재탐색 전부 SOLVED**
(S11 2롤·S12 8롤[11→8 개선]·S13 26롤·S14 40롤 — 천장 휴리스틱이 기존 자동발견 불변/개선). 임시 진단·시각화
스크립트(`_probe17.py`/`_viz17.py`/`_viz17.json`)는 정리(삭제).

**⚠ stage17 레벨 = 사용자 WIP였음**: `stage17_layout.tres`(sand_mound 위치 재배치)·`Stage17.tscn`은
워킹트리 수정본이며 solve.json이 그 기준 → 해-레벨 일관성 위해 layout+tscn을 solve.json과 **함께 커밋**.
(stage17.tres는 line-ending만, 21~25·project.godot 등 별개 사용자 WIP는 격리 제외.)

## 다음 작업 (Option C)
- **Ch1 잔여**: S18(부분 4/5 — cap50+ or 휴리스틱). Ch1 = 11~14·1·2·15·16·**17** solved + 18(부분).
- **sand_mound(cell-up) routing**: 사용자 SandMound WIP 정착 후(Ch2 S5/19/21~25 핵심). cell-target propose
  신규 분기(수직 벽 검출 → place_on_cell) — bridge보다 큰 작업.
- **Ch2 잔여**: S20(bridge+climber — bridge 추가됐으니 cap 재시도)·S21~25(bridge+sand_mound 복합).
- (미래) 천장-인지를 일반 낙하 시뮬레이션으로 확장 — 다층 낙하 레벨 일반성↑.
- (미래 3b) cross-structure max-margin + dense 권위 binding — 코퍼스 확보 후.

## Phase 4 (CBR/EBL) 4a de-risk — 전이 실증 (2026-06-24)

> plan-stage 적대적 리뷰 R1→R3 approve(`phases/solver/reviews/phase04-plan-review.md`) 후 4a 구현·측정.
> 신규: `tools/solver/tactics.py`(전술 라이브러리, 순수) + `solve.py` seed_fn/provenance 훅(seed_fn=None=기존
> byte-identical) + `try_solve.py transfer-bench`(OFF/ON A/B + provenance 귀속, save=False=게이트 산출물 불변).

### 결과: **NO-TRANSFER (가설 미지지) — de-risk가 음성 신호로 작동**
S11 전술(blocker-반전@물-가장자리)을 S12에 시드한 A/B:
- OFF=8롤아웃, **ON=8롤아웃(감소 0)**. 두 경로가 **byte-identical 후보 순서**(rollout 2~8 동일 label·순서),
  차이는 ON의 rollout 2~7에 `[seeded:...]` 태그뿐.
- **결정적(클리어) 액션 = blocker@6,6(min_x le) = fallback-origin** — 물-가장자리 아님 → 전술 미커버.
- 판정: `rollout_reduced=false` AND `decisive_seeded=false` → 전이 실패로 정직 회계(content가 아니라 provenance).

### 왜 (mechanistic)
1. **propose() 휴리스틱이 이미 물-가장자리를 동일 우선순위로 front-load**(water_w) → 학습 전술이 같은 순서를
   재유도할 뿐, 보너스가 순서를 바꾸지 못함(감소 0).
2. **롤아웃 낭비의 실제 원인 = backpath 형제 후보 탐색**: 솔버가 @0,12/@1,12/@2,12(off=0,1,2)를 차례로
   롤а웃한 뒤 @0,12 채택(=3롤). 시드는 형제를 **prune하지 않고** 똑같이 boost → 낭비 그대로.
3. 결정적 step(@6,6)은 propose()도 fallback으로 찾는, 전술이 모르는 패턴.
→ **"일치 후보 boost/reorder" 메커니즘은 휴리스틱이 이미 잘 정렬한 경우 롤아웃을 못 줄인다.** 전이 가치는
  (a) 휴리스틱이 낭비하는 형제 후보 **pruning**, 또는 (b) 휴리스틱이 모르는 지식 인코딩에서만 나온다 — 현 4a 인코딩은 둘 다 안 함.

### 결정 필요 (plan 4a STOP 규칙 발동)
plan의 4a 게이트: "롤아웃 안 줄거나 seeded-origin 귀속 안 되면 STOP·사용자 보고·재설계". → 사용자 결정 대기.
선택지: (A) Phase 4 중단(CBR가 현 휴리스틱 대비 가치 적음) / (B) 메커니즘을 **형제-pruning**으로 재설계 후
plan-review 재실행 / (C) S13(climber 전술)로 추가 측정 후 결정. 코드는 보존(transfer-bench는 음성 입증 인프라).

### 재설계 (2026-06-24, 사용자 결정) — 지식 볼트 + 위기-인덱스 pruning → **TRANSFER-OK**
사용자: "스스로 답을 찾아야 해. 레벨마다 재검증 무의미. 각 액션 사용 시 고려 요소를 Obsidian 볼트로,
발생한 위기에 링크된 도구를 조회해 해결." → boost(falsified)를 버리고 **볼트-pruning**으로 재설계.

- **볼트** `tools/solver/knowledge/`(17 노트): `crises/`(위기, frontmatter `detect:`로 diagnose 신호 연결) +
  `skills/` + `factors/` + `subgoals/` + `stages/`, [[위키링크]] 그래프. README에 규약·검색 흐름.
- **파서** `knowledge.py`(순수): load_vault / detect_crises / **resolve**(위기→링크 도구·요소) / **vault_prune**.
- **메커니즘**: `diagnose → 위기 식별 → 링크 요소([[backpath-offset]]) → 물-가장자리 reverse 후보의 형제(off>=1)
  prune` → 휴리스틱이 형제마다 낭비하던 롤아웃 제거. solve.py `vault_fn` 훅(기본 None=기존 byte-identical).
- **귀속**(boost의 seed-provenance와 다름): ON 클리어 AND 롤아웃<OFF AND **OFF와 동일 해(final_plan)** AND
  vault_pruned>0 — "같은 답을 더 적은 롤아웃으로, 감소는 볼트가 prune한 형제로 설명."

**측정(transfer-bench --mode vault)**:
| stage | OFF | ON | pruned | same해 | 판정 |
|---|---|---|---|---|---|
| S12 | 8롤 | 4롤 | 4 | ✓ | TRANSFER-OK |
| S13 | 26롤 | 22롤 | 4 | ✓ | TRANSFER-OK |

같은 볼트 지식으로 두 스테이지 개선(레벨별 손 시드 0). 게이트 selftest 16/16 PASS(vault_fn=None inert).
S13 감소폭 작음 = 26롤 대부분이 climber carry 탐색(물-가장자리 pruning 무관) → 향후 [[carry-timing]] pruning factor로 확장(4d).

### plan-review 재실행 (볼트-pruning) — R1→R3, 그리고 완전성 결론
- **R1**(HIGH×2+MED×2: pruning 안전성·overfit 귀속·구 seed 잔존·retired/trapped 누락) → 수정(fail-open·반사실
  귀속·plan 재작성·trace 전달) → **R2**(HIGH×1: fail-open이 빈-라운드 우회 + MED LA2 stale trace) → 수정 →
  **R3**(HIGH×1: 개선 후보 commit 전 prune 형제 미평가 → "ON ⊇ OFF" 불성립). 3-round cap → 사용자 결정.
- 사용자 결정 = **B(솔버 완전성 강화)**. 구현: commit/정체 판단 전 prune 형제까지 항상 평가(ON ⊇ OFF), LA2도 동일.
  pruning은 더 이상 후보 영구 삭제 아님(평가 순서 우선만), 절약은 클리어 라운드 early-exit에서만.

### ⚠ 완전성 버전 실측 — **pruning 이득은 incompleteness 산물이었음 (sound 이득 0/음수)**
| stage | OFF | ON(완전성) | |
|---|---|---|---|
| S12 | 8롤 | **9롤** | NO-TRANSFER (형제 평가 복원 → 절약 소멸 + 순서 오버헤드) |
| S13 | 26롤 | **38롤·미클리어** | NO-TRANSFER (예산 소진·greedy 경로 divergence) |

**결론**: boost(순서)=무효(휴리스틱이 이미 정렬), prune(불완전)=겉보기 이득이나 **완전성 희생**, prune+완전성=**OFF보다 나쁨**.
→ 현 propose() 휴리스틱이 S12/S13 후보를 이미 올바르게 랭킹하므로, "어느 후보를 선호/prune"하는 볼트 지식은
**sound한 속도 이득이 없다**. sound transfer는 휴리스틱이 *모르는* 지식(탐색이 못 푸는 서브문제의 구성적 전술)을
인코딩해야 가능 — 재랭킹/prune로는 불가. **de-risk가 pruning-for-speed 가설을 kill**(rigor가 환상을 제거).

### 방향 재정의 (2026-06-24, 사용자) — 솔버 = **다양-해 발견 + 풀이법 보고서** (designer-in-the-loop)
속도 아님. 솔버는 한 스테이지를 **스스로 다양한 방법으로** 클리어하는 경로(플레이어가 찾을 법한 의도-외 해 포함)를
찾아 **풀이법 보고서**로 제시. 사용자가 보고 **인정 / 레벨·도구 조절**을 스스로 결정. 솔버는 **의도 판단·조절 의견
제시 안 함**(중립 발견·보고만). = D9 생성 오라클·Phase 5 감사의 핵심(속도는 잘못 잡은 하위목표였음).

**구현(de-risk, 2026-06-24)**: `try_solve.py diverse <stage>` —
- 다양성 축 = **인벤토리 변형**(수량/종류 감소): `solve(inv_override=...)`로 더 적은/다른 도구로 클리어되나 탐색.
  각 해 엔진 검증(D4), 시그니처로 dedup.
- **추가 탐색 캡(사용자)**: 첫 해 발견 후 추가 시도는 `--extra-cap` 롤아웃 예산 내에서만(무한 다양성 탐색 방지).
  초과 시 남은 변형 중단·`search_capped:true` 정직 보고.
- 보고서 = 해별 {도구·수량·액션 요약} + 스테이지 위기 맥락(볼트 `knowledge.resolve`). 의도 diff·조절 제안 없음.
- 실측: S12·S13 각 **구별되는 해 1개**(인벤토리 줄이면 미클리어 = 타이트 제약, 정직 보고). 캡 트리거 확인(S13 extra-cap=1 → search_capped:true).
- 기존 자산 재사용: 엔진-인-더-루프 솔버(sound), 볼트(해 설명 어휘), 결정론. `analyze.py`(1-minimal·cardinality)는 "더 적은 도구" 축의 보완.

**✅ item 1 완료 (2026-06-24) — 배치/전략 변형 축 (diverse 다양-해)**: 같은 인벤토리로 *다른* 배치/전략 해를
forbid-재탐색으로 발견.
- **`solve.solve(..., forbid=None)`**: forbid(액션 dict/시그니처 문자열 iterable)된 액션을 `_propose`에서
  **hard-filter 절대 배제** — `exclude`(tried)와 달리 ceiling/carry **면제도 무시**해 모든 경로(main/sibling/LA2)에
  일관 적용. 후보 0이면 솔버는 정직하게 정지(= 더 이상 구별되는 해 없음, 완전성 주장 아님). `forbid=None`이면
  **무영향**(게이트 byte-identical). 시그니처 = `_action_sig` = `json.dumps(action, sort_keys=True)`.
- **`diverse_report` 2-축 재구성**: ① **전략 축**(신규) — 전체 인벤토리로 발견 해의 액션을 forbid에 누적하고
  재탐색(첫 해 이후 롤아웃만 `--extra-cap` 예산). ② **인벤토리 축**(기존) — 변형(수량/종류 감소), 전체는 ①에서
  다루므로 skip. 해는 `_plan_sig`(순서무관)로 dedup, 각 해에 `axis` 라벨.
- **baseline-clear 정직성 보강**: 무개입으로 클리어되는 스테이지는 `final_plan`이 `None`이라 diverse가 해 0개로
  보고하던 잠재 갭 → 빈 플랜 `[]`(무도구 해)을 기록하도록 수정(stats 한정, 게이트/solve.json 무영향).
- **검증**: selftest 16/16 PASS(forbid=None inert, frame byte-identical s12=2385·s13=2719·s14=4624 불변). diverse 12
  → **구별되는 2해**(blocker×3 동일 인벤토리, `@24/888/312` vs `@72/840/360`, search_capped=false=자연 종료) =
  전략 축 + 모듈간 시그니처 일치 동시 입증.

## Phase 4 강제 종료 + Phase 5 진입 (2026-06-24, 사용자 결정)

> 사용자: "phase4는 강제 종료, 지금은 phase5. 솔버 고도화 및 재설계로 잡고 진행." 기존 페이즈 산출물(Phase 0~2
> 토대) 위에 쌓는 구조 확인 후 결정.

**Phase 4 ⛔ TERMINATED**: 속도 위한 전술 전이 가설 기각(boost falsified + pruning-for-speed=incompleteness 산물).
- plan §Phase 4 = TERMINATED 배너(음성-입증 이력 보존). 살아남은 자산: 볼트(`knowledge/`)=해 설명 어휘로 Phase 5 이관.
- **아카이브 보존(사용자 결정 2026-06-24, 삭제 안 함)**: `tactics.py`·`solve.py vault_fn/seed_fn`·`try_solve
  transfer-bench`에 ⛔ARCHIVED 배너 + 매니페스트 `tools/solver/ARCHIVE.md`. in-place(라이브 코드와 얽힘, None-safe inert).

**Phase 5 — 솔버 고도화 및 재설계 (다양-해 발견 + 풀이법 보고서, designer-in-the-loop)**: in-track 현재 페이즈.
plan §Phase 5 신설(구 Phase 5 감사·6 생성은 번호 없는 트랙-밖 다운스트림으로 격리). 하위:
- **5a 재설계 정립** (✅ 이 갱신): Phase 4 종료 + 방향 재정의 명문화. dead 메커니즘 historical 격리.
- **5b 다양성 축** (메커니즘 토대 ✅ Item 1 / 계약 **재설계 — plan 초안 완료, plan-review 대기**): 사용자 정정
  (2026-06-24) — 솔버 단위 질문 = "해 개수"가 아닌 **"클리어 가능 범위(가능성 공간)"**. ±1타일 시프트(S12 실측:
  3 blocker 일제히 1셀 이동 = 같은 전략)를 별개 해로 오보하던 naive distinctness 결함 발견 → **가능성-공간 계약**:
  스킬별 **연속 클리어 구역=range로 묶어 표현**, **비연속 배치 또는 스킬 횟수 변화만** 별개 solution-class. 범위 발견=
  독립 축 스윕(`analyze.py _reconstruct_runs` 재사용), sampled/axis_independent/informational 정직 표기, 경계만
  authoritative(엔진 재검증). plan §"5b 계약"에 정식 작성. **plan-stage 적대적 리뷰 종결**(codex, bash 실행):
  R1(MEDIUM archived CLI 표면→수정) → R2(HIGH 연속성 미검증 병합 + MEDIUM 4요소 동치→수정) → **R3(HIGH 0,
  MEDIUM forbid 일관성→plan 내 처리)**. 3-round cap 내, Round 3 HIGH 0 → STOP 미발동·종결. 트레일
  [phase05-plan-review.md](../../phases/solver/reviews/phase05-plan-review.md). **다음=revised 5b 구현**(range-sweep +
  gap_verified + 4요소 solution-class + 2단계 forbid + 5c 경계/내부/gap 게이트; impl-stage 리뷰 정책 적용).
- **5c 보고서 영속** (✅ 영속 구현 / ⏳ 게이트 편입 보류): `try_solve.py diverse --save` → `data/solutions/stageNN.diverse.json`
  (리플레이-ready: top `stage_scene`/`deadline_frames` + 해별 풀 `plan`+`expect`). **검증**: stage12.diverse.json 2해
  추출·리플레이 → 둘 다 `cleared=true saved=5`(D4). selftest 16/16 유지(`*.solve.json` 글롭이라 diverse.json 미간섭, verify 불변).
  ⏳ **게이트 편입(range 경계 셀 fail-closed 리플레이 → selftest)은 plan-review 후** — 현재 snapshot(회귀 미강제).
  ⚠ 현 `stage12.diverse.json`은 **naive 스키마**(해별 풀 플랜)이고 그 "2해"는 5b 계약상 1 solution-class로 병합될
  대상 — 5b 재설계 구현 시 range 스키마로 교체된다(잠정 산출물).
- **5d 고도화**: 미검증 스테이지(S18·Ch2 sand_mound 계열) 풀이 + 다양-해 코퍼스. sand_mound(cell-up) routing 추가. **← 다음 작업.**

**게이트**: 현 `verify`(Determinism×2+SkillMetadataDrift+harness-test+selftest+analyze) 그린 유지(다양성 opt-in=기본 불변,
selftest 16/16 확인). 5c 전까지 inert 키 금지로 `verify` 무변경. **plan-review**: Phase 5의 확정 구현(5c 게이트) 진입
전 plan-stage 적대적 리뷰 권장(사용자 트리거 — codex는 model-invocation 불가).

**세션 경계 상태 (2026-06-24, 세션 종료)**: solver-track 전체 작업 **커밋·푸시 완료** — 커밋 `39938af`
(Phase 4 강제 종료·아카이브 + Phase 5 5a/5b Item1/5c + plan-review R1~R3 종결), `origin/auto-solver`로 푸시.
게이트 그린(selftest 16/16). **사용자 병행 WIP 미포함**: `tests/{Basher,Cutter,Digger,SandMound}CarryBuildTest.gd.uid`
4개는 작업 트리에 unstaged로 남김(carry-build 게임플레이 작업, 사용자 소관).
GODOT_BIN = Downloads 중첩 폴더(메모리 [[godot-binary-location]]).

## revised 5b 구현 완료 (2026-06-24, 세션) — range-sweep + 4요소 class + 5c 게이트 (자체 리뷰 clean, ⏳codex 대기)

> plan §"5b 계약" 구현. 신규 `tools/solver/diverse.py`(순수 시그니처 + range-sweep + 4요소 class + forbid 술어
> + 게이트). 트레일 [phase05-impl-review.md](../../phases/solver/reviews/phase05-impl-review.md).

**산출물:**
- **`tools/solver/diverse.py`**(신규): ① 4요소 시그니처(`_placement_cell`=ant_reaches_x→셀, `_role_sig`=select/
  state/mode, `_timing_sig`=trigger type/cmp/picked_ge n/subgoal[**x 제외**=placement], `_skill_multiset`).
  ② **placement range-sweep**(`_sweep_placement`): cell_x 슬롯을 *나머지 고정* 독립 축 스윕(엔진 D4), 도메인
  ≤cap이면 전 셀(stride1=gap_verified), 넘으면 stride 샘플(provisional). `_runs`로 intervals/gaps 복원.
  ③ **solution-class**(`_build_class` 슬롯 좌→우 정렬, `_class_sig` dedup) + **4요소 forbid 술어**(`_make_forbid`
  — placement∈gap_verified 구역 AND skill/role/timing 일치 시 배제, same-region·다른 role/timing은 발견됨=R3 2단계
  (a) 자동). ④ **게이트**(`verify_diverse`/`verify_one_diverse`/`_coverage_check_diverse`/`_selfcheck_diverse`):
  reference clear + 각 cell_x 슬롯 interval 전 셀 clear + **도메인-내부** 경계 밖 fail + gap fail(analyze --verify 동형).
- **`solve.solve(forbid=)`**: **callable 술어** 허용(4요소 class forbid). 기존 sig iterable·None 불변(byte-identical).
- **`try_solve.py`**: 옛 naive `diverse_report`/helpers 제거 → diverse.py 위임. `diverse`(+`--workers`) + 신규
  **`diverse-verify`**(no-arg=모든 diverse.json, fail-closed) 서브커맨드.
- **frontmatter `verify`** 확장: `&& python tools/solver/try_solve.py diverse-verify` 편입(5c 게이트 활성).
- **`data/solutions/stage12.diverse.json`**: naive 2해 스키마 → **range 스키마 재생성**(1 solution-class).

**merge acceptance 충족(falsifiable)**: S12 naive 2해(`@24/888/312`·`@72/840/360`=3 blocker 일제 1셀 시프트)가
**1 solution-class**로 병합 — 슬롯 검증 구역 col[0–3]·[6–18]·[0–18](각 gap_verified=stride1 full sweep)에 sol2 포함.
naive distinctness 결함 해소 실증.

**게이트(verify) 전체 그린·회귀 0**: Determinism×2(962f) + SkillMetadataDrift(11) + harness-test(PASS+exit0) +
selftest **16/16**(frame byte-identical s12=2385·s13=2719·s14=4624) + analyze --verify(4스테이지 272체크) +
**diverse-verify stage12(1 class, 40체크)**. forbid=None inert로 기존 경로 불변.

**자체 적대 리뷰 clean(HIGH 0)**: 구현 중 [HIGH] 게이트 도메인-끝 경계 false-fail 1건 발견·수정(도메인-내부 경계만
단언). fail-open(selfcheck 17케이스·빈대상 FAIL·coverage 파생/변조 거부)·종료성·byte-identical 검토 통과. 정직
경계(axis_independent joint 미주장 / forbid 보수 under-report / grid 도메인 한정) 문서화.
**⏳ 다음 = codex impl 재리뷰**(사용자 트리거 — model-invocation 불가). clean 후 커밋 + 5d.

## revised 5b — codex impl-review 종결 (2026-06-25) — ✅ R10 approve

> 사용자 "bash로 실행해줘" → companion 직접 호출(정식 경로, [[codex-adversarial-review-invocation]]).
> 트레일 [phase05-impl-review.md](../../phases/solver/reviews/phase05-impl-review.md). base=`6bef989`(revised 5b 부모).

**codex 10라운드 + 자체리뷰 10라운드 → R10 approve(no material findings).** 매 codex 라운드 사이 자체 적대
리뷰 clean(HIGH 0). 발견·수정 누적(전부 `tools/solver/diverse.py`±`solve.py`, 엔진/PlanRunner/게임 무변경):
- R1: provisional 비병합 / y-band 정체성 / stage 바인딩.  R2: plan-level completion forbid / minimize 정규화.
- R3: canonical class-sig(순서무관) / 인벤토리축 forbid 루프.  R4: continue-past-dup / 예산(minimize+sweep) 계상.
- R5: 단일연속 region(비연속=별개 class) / dry-limit 제거.  R6: subset-forbid 통합 / fixed_cell 불변식 coverage / capped 거부.
- R7: Kuhn 이분매칭 / sampled_points 강제.  R8: **plus-형 forbid**(검증 단일슬롯 변형만, 미검증 joint 발견 허용).
- R9: dead_exact(검증 joint duplicate 정확 차단, false-capped 제거).  **R10 approve.**

**핵심 산물 = forbid 메커니즘**: plus-형(reference + 한 cell_x 슬롯만 interval + superset, soundness 증명으로
distinct class 미차단) + dead_exact(발견된 검증 joint duplicate 정확+superset 차단) + Kuhn 매칭. 결과: 좌표
±시프트·inert-padding superset·검증 joint duplicate는 모두 1 class로 수렴, **미검증 Cartesian joint는 발견 허용**
(완전성), uncapped 자연소진(stage12 1 class·48롤·search_capped=false). 게이트: `diverse-verify`가 fixed_cell
불변식·단일 interval·sampled_points·capped 거부·중복 class를 fail-closed 검증 + 3 selfcheck(class-sig/forbid/coverage).
커밋 cf1fd38·9f31ab2·770f558·4d02d10·2209c26·6100a75·cd98e7d·48e3109·c0f5ccd → **`4d5bef9`까지 origin/auto-solver 푸시 완료**.

## 5d 착수 계획 (다음 세션 진입점, 2026-06-25 핸드오프)

> 사용자 결정: **가벼운 것(코퍼스 확장) 먼저**, sand_mound routing은 후순위. revised 5b forbid 메커니즘
> (plus-형+dead_exact+Kuhn)은 R10 approve 종결 — **검증된 도구**이므로 아래 ①은 *데이터 생성*(코드 무변경)이라
> codex 리뷰 불요. 환경: `GODOT_BIN=` Downloads 중첩 console.exe([[godot-binary-location]]), `--fixed-fps` 하니스 필수.

### ① 다양-해 코퍼스 확장 — **먼저, 코드 변경 없음** (← 다음 세션 시작점)
기존 routing(blocker/climber/floater/bridge)으로 풀리는 스테이지에 `diverse.json` 생성. 절차(스테이지별):
1. `python tools/solver/try_solve.py diverse <id> --save --extra-cap <N>` (예 500). **uncapped 목표**:
   `search_capped=false` 여야 게이트(diverse-verify의 capped 거부, R6) 통과·커밋 가능. capped면 `--extra-cap` 상향.
   - **stage12 선례**: plus-형 forbid로 1 class·48롤·uncapped 자연소진 → S13/S14도 같은 패턴 기대(churn 없음).
2. `python tools/solver/try_solve.py diverse-verify <id>` 그린 확인 → 전체 게이트(verify 프론트매터) 그린 확인.
3. 대상: **S13**(blocker×1+climber×5 carry 연쇄 = 다중 cell_x 슬롯 → plus-형/dead_exact 실전 검증) · **S14**
   (blocker×3+climber×5) · (선택) S11.  각 `stageNN.diverse.json` 커밋.
   - ⚠ S13/S14는 carry climber(picked_ge n = none-slot, 비공간) 다수 → forbid의 none-slot 매칭·dead_exact 실전
     첫 검증. stage12(blocker만)와 달리 **새 슬롯 조합**이라 결과 면밀 확인(특히 search_capped·n_solution_classes).
4. **S18**: 현재 부분(saved 4/5, 40롤 미달) — diverse 전에 **solve부터** 필요. `try_solve.py search 18 --max-rollouts 50+`
   로 완주 해 먼저 확보(`stage18.solve.json`) → selftest 편입 → 그 후 diverse. (cap 튜닝만으로 풀릴 가능성, S13/14 선례.)
   - solve가 cap만으로 안 되면 model.py 휴리스틱 손질 = **코드 변경 → impl-review 대상**(가벼운 트랙에서 분리).

### ② sand_mound (cell-up) routing — **후순위, 선결 확인 필요**
- `model.propose`에 **cell-target 신규 분기**(수직 벽 검출 → `place_on_cell`) 추가 = bridge보다 큰 작업, **코드 변경
  → plan-review + impl-review 대상**. Ch2 핵심(S5/S19/S21~25).
- ⚠ **선결**: 이전 세션에 사용자가 `SandMoundSkill.gd`·stage17/21~25 능동 수정 중이었음(racing 방지로 보류). 착수
  전 **그 WIP가 커밋·정착됐는지 확인**(현재 워킹트리=`*CarryBuildTest.gd.uid` 4개뿐이라 정착됐을 가능성). 정착 후 routing 설계.
- Ch2 잔여: S20(bridge+climber, bridge 있으니 cap 재시도) · S21~25(bridge+sand_mound 복합).

## 5d① 다양-해 코퍼스 확장 완료 (2026-06-25) — S11/S13/S14 diverse.json (코드 무변경, 데이터 생성)

> 5d 착수 계획 ① 수행. revised 5b R10-approve forbid 메커니즘(plus-형+dead_exact+Kuhn)을 검증된 도구로
> 그대로 사용 — `tools/solver/` 무변경, 신규 산출물은 `data/solutions/stageNN.diverse.json` 3개뿐이라 codex 리뷰 불요.
> 하니스 `--fixed-fps`(GODOT_BIN=Downloads console.exe, [[godot-binary-location]]).

- **S13** (blocker×1+climber×5, carry 연쇄): **n_classes=2, search_capped=false**(extra 197롤 자연소진). class1=
  마지막 슬롯 climber carry(picked_ge5) / class2=마지막 슬롯 climber **spawn_index/immediate** — carry climber
  슬롯에서 plus-형/dead_exact가 실전 동작해 *구별되는 전략 변형*을 발견(none-slot 매칭 첫 실증). blocker 슬롯
  col[5–17] full sweep(gap_verified). diverse-verify **32체크 PASS**.
- **S14** (blocker×3+climber×5 계단): **n_classes=1, search_capped=false**(extra 323롤). 3 blocker 슬롯 각
  col 구역 full sweep(8–23 / 0–22 / 0–22, gap_verified) — 좌표 시프트 변형이 plus-형 forbid로 1 class 수렴
  (stage12 선례 재현). diverse-verify **66체크 PASS**.
- **S11** (blocker×1, 양성 대조): **n_classes=1, search_capped=false**(extra 4롤). col[18–21] full sweep.
  diverse-verify **7체크 PASS**.
- **S18 = DEFER(별도 코드-변경 트랙)**: `search 18 --max-rollouts 80` → **40롤에서 saturate**(1·2-스텝
  lookahead 둘 다 진척 0). cap 문제 아님 — best plan=floater+blocker×2+climber×4, saved=4/5 고정(5번째 개미
  물 익사, carry5 추가해도 불변). 100% 미달 = `model.py` 휴리스틱 손질 필요 = **코드 변경 → plan/impl-review
  대상**이라 가벼운 데이터 트랙에서 분리. solve.json/selftest 미편입(부분 해는 게이트 비대상).
- **게이트 전체 그린(코드 무변경 회귀 0)**: Determinism×2(962f) + SkillMetadataDrift(11) + harness-test(PASS+exit0)
  + selftest **16/16**(frame byte-identical s12=2385·s13=2719·s14=4624·s17=3367) + analyze --verify(4스테이지
  11/12/13/14) + **diverse-verify 4개(11/12/13/14, 7+40+32+66=145체크) PASS**. diverse.json은 `*.solve.json`
  글롭 비대상이라 selftest 불간섭. `verify` 프론트매터 무변경(diverse-verify가 no-arg로 신규 3개 자동 발견).
- 커밋: `data/solutions/stage{11,13,14}.diverse.json` + STATUS(이 절). 사용자 WIP `*CarryBuildTest.gd.uid` 4개 미포함.

## S20 "이상한 계단" SOLVED — early-climber 체이닝 (2026-06-25, 커밋 대기, ⏳codex 대기)

> 5d 잔여 Ch2 타깃. S20(bridge×2+climber×5)을 cap 재시도로 시도했으나 **saved=1/5 포화**(S18과 동일한
> 휴리스틱 한계, cap 부족 아님 — rollout 29/50서 "진척 못 냄" 조기 정지). 사용자 결정="S20 early-climber
> 체이닝"으로 model.py 휴리스틱 손질. 엔진/PlanRunner/게임 무변경, `tools/solver/` + selftest EXPECTED만.

**레벨 구조(파일 20 = Ch2 5번째)**: 3단 상승 계단 — 1단 home(cols0–4,표면row12) → 갭1 물(cols5–7) → 2단
(cols8–12,row10) → 갭2 물(cols13–15) → 3단 candy(cols16–19,row7, candy(18,6)). 의도 해 = 갭마다 bridge
1개(영구) + **5마리 전원 climber**(각자 픽업 *전*[상행]에 2개 단 벽을 타고 올라감 → candy → 하강 귀환).
bridge×2 + climber×5가 정확히 맞음.

**진단(왜 saved=1 포화)**: bridge 2개는 깔리나 climber가 **1마리(si3)에만** 적용 — 나머지 4마리는 단 벽에서
못 올라가 flip→되돌아감(리타이어 0=사망 아님, candy 미도달). 솔버 `propose`가 `climber@early:si0..si4`를
생성하지만 **carry 체인처럼 spawn_index 전반으로 체이닝하지 않음**(early는 exclude(tried) 면제 없음). S14
carry 체인(픽업 *후* 운반 무장)의 **상행판**이 부재.

**fix(`model.py` + `solve.py` 게이트 1줄 + `run_plan.py` EXPECTED 1줄, 엔진 무변경):**
- **`model._has_early_arm(plan, sid)`** 신규: plan에 이 스킬의 early 무장(select=spawn_index + trigger
  immediate)이 채택돼 있는가. **early 체인 게이트.**
- **`propose(..., plan=None)`**: `early_armed=_has_early_arm(plan, sid)`이면 나머지 spawn_index 무장을 ⓐ
  exclude **면제** + ⓑ 가중 부스트(210+, carry처럼 연쇄가 먼저 평가돼 cap 내 완결)로 si0→…→si(n-1) 연쇄 채택.
  중복 롤아웃은 `eval_cands` action-dup 가드가 차단(carry와 동일 패턴). early_armed=False면 종전 byte-identical.
- **게이트 = 확정 plan(closure)으로 판정**(speculative base 아님): ⚠ **핵심 함정** — `base2=plan+[c1]`(LA2)로
  판정하면 LA2가 climber@early를 c1로 깔 때 early_armed 조기 발화 → boost가 2nd-step의 **bridge(gap2)를 max_n
  밖으로 밀어내 다중스킬 조합 발견을 깨뜨림**(실측: saved 1→0). 확정 plan에 early 무장 든 뒤(=조합 발견 후)에만
  체인 boost ON. `solve._propose`가 `model.propose(..., plan=plan)`로 closure 확정 plan 전달(forbid_pred의 base는 종전대로).

**해**: `[bridge@4,11, climber@early:si3, bridge@12,9, climber@early:si0, si1, si2, si4]` (bridge×2+climber×5,
7액션) → **saved=5/5, frame=1869, rollouts=30**. 발견(LA2 rollout14: climber si3+bridge gap2, saved=1) →
체인(rollout18→30: si0→saved2…si4→saved5). `data/solutions/stage20.solve.json`. **결정론 재현 확인**(재탐색 byte-identical).

**회귀 0(byte-identical, 증명):**
- **기존 스테이지 재탐색 전부 byte-identical**: S4=2(slideR early, 첫 후보 즉시 클리어라 2라운드 無)·S11=2·
  S1=13·S15=32·S13=26·S14=40 롤 — solve.json git 무변경. (S12 solve.json은 `rollouts:11→8` 1줄 diff가
  보이나 **선재 드리프트**[stage17 천장 휴리스틱, 이미 HEAD]임을 **내 코드 stash 격리 테스트로 입증**[stash시도 8롤] —
  내 변경 무관, plan/actions byte-identical. HEAD로 복원, 본 커밋 미포함.)
- blocker-only(S16/S17/S2/S3 등)는 `up` 루프 미진입 → 구조상 무관.
- **verify 게이트 전체 그린·EXIT 0**: Determinism×2(962f) + SkillMetadataDrift(11) + harness-test(PASS+exit0) +
  selftest **17 plans**(golden5+solve12, stage20→cleared saved5 frame1869, EXPECTED에 20 등재, 기존 해 frame
  byte-identical s13=2719·s14=4624) + analyze --verify(4스테이지) + diverse-verify(4스테이지).

**자체 적대 리뷰 clean(HIGH 0)**: 구현 중 [HIGH] LA2 speculative-base 조기발화로 조합 발견 깨짐 1건 발견·수정
(확정 plan 게이팅). closure plan 참조 정합·early action 유일식별(immediate+spawn_index)·결정론·boost 한정성 검토 통과.

**codex impl-review R1(needs-attention, base=a560995, 커밋 `50e8ccb` diff) → 2-fix:** 트레일
[phase05-impl-review.md](../../phases/solver/reviews/phase05-impl-review.md) `## S20 …`.
- **[HIGH] early-armed boost가 구조 후보를 굶김**: 부스트(210+)가 `cands[:max_n]` 절단에서 reverse/cross(다리·
  블로커) 후보를 밀어내 structure→early→structure 다단 레벨이 막힐 수 있음(S20는 동작하나 전역 적용 잠재위험).
  → **수정**: `early_active`면 **최상위 구조 후보 1개를 절단에서 항상 보존**(`trigger=ant_reaches_x` 식별, 매
  라운드 구조 평가 보장; early_active=False면 미적용=byte-identical). S20 30→31롤(보존 1칸), plan 불변.
- **[MEDIUM] selftest는 plan replay만 — 탐색 휴리스틱 미검증**: EXPECTED에 20 넣어도 저장 plan replay라 게이트/
  boost/결정론 회귀를 못 잡음. → **수정**: `try_solve.py rediscover-verify` 신규(up-루프 대표 S4 early-single/
  S13 carry-chain/S20 early-chain을 `solve.solve(save=False)` 재발견 → cleared+액션 시그니처 일치 단언, fail-closed).
  frontmatter `verify`에 편입.
- **자체 적대 리뷰(2-fix) clean(HIGH 0)**: 보존-게이트 `is not` 식별자 제외 정확·max_n=1 경계(budget 끝)·결정론·
  rediscover save=False 무부작용·stats 갱신 경로 검토 통과. 정직 한계: 보존은 *최상위* 구조만 보장(임의 필요 구조는
  반복 라운드+LA2로 수렴, 완전성 아님), rediscover cap은 롤아웃 증가 시 갱신 필요.
- **전체 게이트 그린·EXIT 0**(rediscover-verify 포함: S4 1/1·S13 6/6·S20 7/7 시그니처 일치). 회귀 0(early_active=False
  byte-identical).

**codex R2(needs-attention, base=a560995, 커밋 `8aab1f1`까지) → 2-fix:** R1 fix가 미흡.
- **[HIGH] 보존 슬롯 독점**: R1 보존이 *최상위* struct만 되돌리는데, ceiling-exempt struct는 exclude 면제라
  **이미 시도돼 실패한 천장 후보가 매 라운드 재보존돼 슬롯 독점** → 차하위 필요 구조 여전히 굶음. → **수정**:
  보존 대상을 **untried(label∉exclude) 최상위 구조**로 한정 → 시도·실패한 구조는 tried라 보존서 빠지고 fresh
  구조가 슬롯 획득(독점 차단). S20 거동 불변(31롤, solve.json byte-identical — S20 구조는 이미 라운드마다 fresh).
- **[MEDIUM] rediscover가 잔여 실패모드 미커버**: 후보 *랭킹* 회귀(early-active+다중 구조 경쟁)는 엔진 재발견이
  못 거름. → **수정**: `model._selfcheck_preserve()` 단위 검증(엔진 불요) — 구조 A(천장·고가중)/B(저가중) + early
  활성에서 A untried→보존 A / A tried→보존 B(독점 차단) 단언. rediscover-verify ① 선두에 편입. **prove-it 확정**:
  R1 동작으로 되돌리면 selfcheck FAIL(A 독점 반환), R2 fix면 PASS = vacuous 아님.
- **자체 적대 리뷰(R2 2-fix) clean(HIGH 0)**: untried 필터 결정론·`is not` 식별자·selfcheck 합성입력 정합 검토 통과.
- 전체 게이트 그린·EXIT 0(preserve-selfcheck PASS + rediscover S4/S13/S20 + selftest 17 + analyze 4 + diverse 4).

**codex R3(needs-attention, base=a560995, 커밋 `6ac97c1`까지) → 라운드-로빈 fix:** R2가 R1 모순을 노출.
- **[HIGH] R2 untried 필터가 ceiling-exemption과 모순**: 천장 후보는 "단독 실패하나 다른 액션이 plan 맥락을
  바꾸면 유용"해 의도적 재제안되는데, R2의 `label∉exclude`가 이들을 보존서 영구 배제 → 맥락 변화 후 필요해진
  천장 구조가 여전히 굶음(R1 독점 ↔ R2 retry-eligible 배제 순환). → **수정**: 보존 대상을 **least-attempted
  라운드-로빈**으로 — live 구조(재제안 천장 포함) 중 **롤아웃 시도 횟수 최소**(동률=가중 desc)를 보존. 보존·실패
  하면 attempts↑ → 다음 라운드 다른 구조 보존 → **모든 live 구조가 유한 라운드 내 보존(영구 starvation 불가능,
  천장 retry-eligible rotating past)**. `solve.attempts`(label→횟수) eval_cands서 누적·propose 전달. attempts=None
  기본=R1(다른 호출자). S20 거동 불변(31롤 byte-identical). early_active=False면 미적용=byte-identical.
- selfcheck 갱신(라운드-로빈): 동률→A(최대가중) / A 1회→B(독점차단) / B 2회→A(rotation, retry-eligible). **prove-it**:
  R1(top-1) 동작이면 (2)에서 A 반환 FAIL, R3면 PASS = 박제. 자체 리뷰 clean(HIGH 0): min 결정론·attempts 누적·
  early_active=False 불변 검토 통과.
- 전체 게이트 그린·EXIT 0(preserve round-robin + rediscover S4/S13/S20 + selftest 17 + analyze 4 + diverse 4).

**codex R4(needs-attention) → 사용자 결정 = carry-mirror 단순화(보존 폐기):** R1→R4가 **단순 카운터로 못
닫는 휴리스틱 근본 한계**를 좁혀옴 — R4 HIGH는 "global attempts가 base 맥락 무시 → cross-base 재시도 지연".
분석 결과 **global↔base-scoped 직접 충돌**(global=라운드-로빈 OK·cross-base 페널티 / base-scoped=cross-base
fresh·메인루프 매 라운드 base 변경이라 독점 재발). "맥락이 *의미있게* 바뀌었나"의 semantic 판단 필요 = 카운터
범위 밖. **이 starvation은 latent**(현 캠페인에 structure→early→structure 없음; S20는 discovery서 구조 완료
후 early-chain. **선재 carry-chain도 동일 속성**[carry 40 > 구조 12]이나 미flag).
- **사용자 결정(2026-06-25, AskUserQuestion) = "단순화: carry-mirror"**: 보존 메커니즘(R1 reserve + R2 untried +
  R3 라운드-로빈 + attempts + `_selfcheck_preserve`) **전부 폐기**. early-armed 가중을 **carry 프로파일 바로 위**
  (`early_w_base = max(carry_base,40) + cnt`)로 두어 carry no-op 위에서 평가되되 **carry-chain과 동형 가중 프로파일**.
  → 구조 후보와의 관계가 **검증된 carry-chain과 동일**(새 starvation 클래스 없음, 공유 선재 속성). `early_active`
  플래그·구조 보존 절단 분기·`attempts` 스레딩·preserve selfcheck 제거. rediscover-verify의 **엔진 재발견(S4/S13/
  S20)은 유지**(원래 R1 MEDIUM 해소 — 탐색 휴리스틱 회귀 가드).
- **결과**: S20 SOLVED 30롤(보존 reserve 제거로 31→30 복귀), plan 불변(bridge×2+climber×5). 회귀 0(S4/S13
  byte-identical, early_armed=False면 byte-identical). 전체 게이트 그린·EXIT 0(selftest 17·analyze 4·diverse 4·
  rediscover S4 1/1·S13 6/6·S20 7/7). 자체 적대 리뷰 clean(carry-mirror 가중 결정론·early_armed gate 정합·
  carry_base floor 검토).

**codex R5(carry-mirror 최종) = needs-attention(예상) → 사용자 사전수용 latent로 종결:** codex는 diff만 보므로
carry-mirror가 early-above-structural을 유지하는 한 구조 starvation을 계속 flag(R5 HIGH = R1~R4와 동일 클래스).
이 HIGH는 **사용자가 carry-mirror 선택 시 AskUserQuestion에서 명시 사전수용**한 속성(선택지 설명에 "carry와
공유하는 선재 속성·codex 여전히 flag 가능·근거 carry 동형" 명기). **수용 근거**: ① 검증된 carry-chain이 이미 동일
(carry _w 40 > 구조 _w 12 → structure-after-carry 동일 starvation, codex는 carry가 diff 밖이라 미flag) — 새 회귀
아님. ② **latent**(structure→early→structure 다단 레벨 현 캠페인 부재; S20는 discovery 후 early-chain이라 무경쟁).
③ 완전 해소는 카운터 범위 밖(global↔base 충돌). MEDIUM(rediscover 미커버)은 preservation 폐기로 무의미. **재진입
조건**: 실제 그런 레벨 등장 시 semantic 맥락-인지 preservation 재설계. 트레일 `phase05-impl-review.md` `## S20…`
R1~R5 전체. **정책 예외(impl HIGH accept)는 사용자 결정 override**(사용자=오케스트레이터). **S20 종결.**

## 5d② sand_mound (cell-up) routing — 설계 완료, ⏳plan-review 대기 (2026-06-26)

> 사용자 결정(AskUserQuestion) = "5d② sand_mound routing"으로 5d 잔여 진입. SandMound WIP 정착 선결조건은
> pull한 `b88533b`(챕터2 stage21~25 밸런싱)로 충족. 코드-변경 트랙이라 plan-review → impl-review 절차.
> 설계 SoT = [auto-solver-plan.md](../../phases/solver/auto-solver-plan.md) §"5d② 계약". 하니스 `--fixed-fps`
> (GODOT_BIN=Downloads 중첩 console.exe, [[godot-binary-location]]).

- **결함 재현**(`search 19` baseline): cell-target SIGN(sand_mound)은 `model.propose`에 분기 부재 → **후보 0개**.
  S19 trace = 5마리 home(1,10)→추락(col5,row10→14)→계곡 row14에서 좌우 벽(col4/col16) **반전 무한왕복**,
  **retired=0(낙하·물 0)·time_out**. 낙하/물 신호 없어 기존 reverse_targets blind. candy(16,6)=계곡서 +7~8 상승.
- **검증 메커니즘**(엔진 실독): 개미 스킬 없이 단차 0(벽=반전·절벽=추락) / sand_mound=수직 사다리 **최대 5칸**·
  ceiling cap·영구 지형(이후 개미 climb) / 사인 **one-shot**(1개=모두 위한 사다리 1개) / cell=[col,row]=표면 위
  **빈 보행 셀**(점유면 무효).
- **설계 3축**: D1 diagnose 신규 `wall_targets`(벽-반전 검출, **d=진입 세그먼트 방향**+전방-solid soundness 게이트+
  목표-위 게이트 → 벽-기저 셀, two-wall valley 둘 다 emit·목표근접 정렬, `_selfcheck_wall_targets` 박제) / D2 propose
  신규 ③ SIGN cell-up 분기(meta.target==cell && routing==up, at_frame 0 emit, ①②와 격리) / D3 닫힌-루프 자연
  stacking(매 라운드 최상단 벽 검출, S19=2·S25=4). **inert 불변식**: up-cell 스킬 없으면 byte-identical.
- **스코프(R1 후)**: **S19 100%(sand_mound×2 saved=5/5) = 하드 acceptance 게이트**(escape hatch 제거). 불가 판명 시
  silent defer 금지·S18식 실측 입증 후 사용자 STOP·에스컬레이트. S21~25/S5=stretch(게이트 아님). 볼트 crisis 노트는
  본 plan 제외(knowledge.py 무변경, R1-MEDIUM). break/down/jump cell 디바이스=미커버 유지.
- **codex plan-review R1 = needs-attention**(HIGH×2+MED×1) → 3개 수정: d 방향 규약+soundness+selfcheck / S19 하드
  게이트화 / D4 볼트 노트 제거.
- **codex plan-review R2 = needs-attention**(HIGH×1 stacking-placement + MED×1 verify-wiring) → **경험적 조사로 설계
  심화**(사용자 질문 "추종자 천장 못 넘나?"가 내 오판 교정):
  - **추종 개미도 천장 cap 넘음**(`LadderClimbState` 실독) — "cap=건설자 전용"은 **오판**. R2 HIGH의 snap 주장도
    경험 반증(기존 플랫폼 cap은 frame-0 유효).
  - **S19 ×2 = 5/5 입증**(손배치 witness `(10,14)+(12,10)` saved=5/5 frame1586) — 하드 게이트는 *존재 확인된 해*.
  - **진짜 제약 = 배치 위상**(6×4 스윕): (T1) 두 사다리 **다른 col**(같은 col은 cap "위-위=빔" 깨짐, 대각 전부 1/5)
    (T2) ladder2는 ladder1보다 **진행방향 쪽** (T3) ladder1은 벽에서 **off≥1** 떨어뜨려 ladder2 공간 확보.
  - **해소 = D2 후보 column-sweep(A안)**: 반전-셀 단일이 아니라 backpath off=0..5 펼침 + 같은-col exclude(T1) +
    엔진 verdict 선별. verify 실편입 = rediscover-verify에 stage19 추가(R2-MED).
- **codex plan-review R3(최종) = needs-attention**(HIGH×1 + MED×1) → **3-round cap 도달·정책상 STOP·사용자 결정 대기**:
  - **[HIGH]** 같은-col exclude(T1)를 `base plan` 기준 명세했으나, 기존 `model.propose(plan=plan)`는 closed-over
    확정 plan만 봐서 **LA2 2nd-step(speculative 첫 사다리 후)엔 필터 미적용** → 유일 조합검색 경로가 같은-col
    재스택 제안 가능. 권고=solve.py plumbing(cell-up exclude에 speculative base 전달) + LA2 regression.
  - **[MED]** off=5 witness((10,14)) emit이 미증명 — 현 reverse backpath 4 cap·min(3,len(bp))을 미러하면 D1
    selfcheck 통과해도 witness col 영영 미emit. 권고=우측벽 backpath≥6 + propose off=5 emit fail-closed fixture.
  - 트레일 [phase05-plan-review.md](../../phases/solver/reviews/phase05-plan-review.md) `## 5d② Round 1·2·3`.
- **사용자 결정(2026-06-26) = "반영 후 구현 진입"**: 두 R3 finding을 plan §"구현 바인딩 요구"로 명문화(R3-H1 LA2
  cell-up base plumbing / R3-M1 off=5 emit 증명·reverse depth cap 비재사용) → **4th plan-review 없이 구현 진입**,
  충족은 impl-stage 적대 리뷰 + fail-closed fixture/regression으로 검증. **plan-stage 종결.**
## 5d② 구현 완료 (2026-06-26) — S19 SOLVED·게이트 그린·자체리뷰 clean, ⏳codex impl-review 대기

> 트레일 [phase05-impl-review.md](../../phases/solver/reviews/phase05-impl-review.md) `## 5d② …`. 엔진/게임 무변경.

- **산물**: model.diagnose `wall_targets`(d=진입방향+soundness 전방-solid+목표-위, backpath≥6) / model.propose ③
  SIGN cell-up(column-sweep off=0..5, **off 큰 쪽 선호**=벽서 멀리 둬 ladder2 공간, T1 같은-col exclude, dedup) /
  solve._propose `cellup_base=base` plumbing(LA2 base2, R3-H1) / `_selfcheck_wall_targets`(ⓐ-ⓔ+R3-M1 off=5 emit+
  R3-H1 same-col) / stage19.solve.json + EXPECTED + rediscover[19].
- **S19 하드 게이트 통과**: `solve.solve(19)` saved=5/5 rollouts=8 자동발견(`[(10,14),(11,10)]`, off=5 greedy→
  다음 라운드 다른-col 우향). **핵심 수정**: off-preference 뒤집기(`+off`) — greedy가 벽-붙은 off=0 dead-end 대신
  벽서 먼 ladder1 채택해야 닫힌-루프가 수렴(off=0만이면 1/5 trap).
- **게이트 그린·EXIT 0**: Determinism×2+Drift+harness+selftest **18**(stage19, 기존 byte-identical)+analyze4+
  diverse4+`_selfcheck_wall_targets`+rediscover(4/13/19/20). **inert 확인**: 기존 solve.json git 무변경.
- **자체 적대 리뷰 clean(HIGH 0)** + **codex impl-review 3R → R3 approve**(bash 경로): R1 per-sample 목표
  (any()-picked → 반전 샘플별 home/candy, ⓕ) / R2 phase-키 aggregation(픽업 전·후 stale 병합 차단, ⓖ)+연속
  backpath(루프/계단 stale 셀 배제, ⓗ) / **R3 approve(no material findings)**. selfcheck ⓐ-ⓗ. impl-stage 종결.
- **커밋·푸시 완료**: `6196a4d`(feat: 5d② sand_mound cell-up routing — S19 SOLVED) + `9f32372`(chore: carry-build
  .uid 고아 메타 정착) → `origin/auto-solver` 푸시. 5d② 종결.

## 다음 세션 진입점 (2026-06-26 핸드오프) — S21~25 = **리스크-구동 다중-도구 분기** 설계 (⏳plan 미작성)

> 사용자 결정(AskUserQuestion) = 5d② 후 "S21~25 sand_mound 조합". 트리아지·S22 심층 조사로 **방향이 큰 검색
> 재설계로 수렴**. 다음 세션 = **plan 작성 → plan-review**. 하니스 `--fixed-fps`(GODOT_BIN=Downloads 중첩
> console.exe, [[godot-binary-location]]). 인벤토리는 전부 커버된 routing(blocker/bridge/sand_mound/slide/floater),
> basher/cutter/digger/leafjump 없음.

### 트리아지 결과 (search 80롤, 전부 미해결 = 휴리스틱 갭, cap 아님 — 다 조기 "정지")
- **S22**: best `bridge+slideR` → **reached=7(전원 픽업)·saved=0·lost=7** = 귀환 routing 갭(가장 근접).
- **S21**(sand_mound 채택)·**S23**(blocker+bridge)·**S24**(floater+blocker)·**S25**(후보 0): reached=0, time_out.

### S22 심층 (정준 타깃) — 핵심 발견
- **귀환 실패 메커니즘**(trace): 운반 개미가 중앙 플랫폼(row6)서 좌측 col7 **절벽 낙하**→물 분실. home(0,2) 좌상단,
  bridge는 이미 row2에 깔림. 솔버가 slideR(우측, 무효)에 락온해 sand_mound로 위로 올릴 생각을 못 함.
- **✅ 단순해 witness 입증**: `bridge + sand_mound@(10,6)` → **saved=7/7 lost=0**. (col8/9는 0/7 — 사다리 꼭대기가
  bridge 복귀선과 맞는 **배치 위상**이라야. col10만 7/7.)
- **사용자 의도-해**(designer intent): **floater(낙하산)→slideR(우측 경사)→bridge(다리)→sand_mound(사다리)→사탕→
  slideL(좌측 경사)** = 5종 풍부 해. 단순해(2종)와 **둘 다 유효** = 다양-해의 산 증거(의도≠유일).

### 근본 진단 = greedy-commit dead-end (S19/S20/S22 재발 패턴)
솔버가 중간 목표("reached")에 greedy-commit → 귀환 불가 배치 위에 동계열 도구만 쌓음, dead-end서 백트랙 못 함.
다양성은 현재 `diverse.py`가 **첫 해 후 forbid**해서 사후적으로만 작동.

### 합의된 방향 (사용자) = 리스크마다 적용-도구 집합 탐색
"리스크 발견 시 다양한 도구를 넣고 해를 찾기" = **dead-end 탈출 + 다양-해 발견을 하나로 묶는 메커니즘**. 레벨 =
리스크 시퀀스(낙하·경사·갭·벽·물), 각 리스크 = 적용-도구 집합(절벽 → floater/bridge/blocker/sand_mound…), 해 =
선택 경로(여러 경로 = 다양-해). **북극성(Phase 5 다양-해)과 일치.**

### 다음 작업 (plan 작성 골자 — plan-review 대상)
1. **선결: sand_mound를 절벽 도구 집합에 편입** — 현재 cell-up은 *벽-반전*(wall_targets)만. **목표-위 절벽**
   (운반 개미 home 위)에도 sand_mound 후보를 내야(reverse_targets→cell-up 연결). S22 witness(10,6) 입증됨.
   ⚠ 현 propose ① 루프는 절벽마다 이미 blocker/floater/bridge 후보를 냄 — sand_mound만 빠짐.
2. **검색 재설계: per-risk 도구-분기** — greedy 1경로 대신 리스크별 적용-도구를 별도 해-분기로 탐색,
   성공 해들을 다양-해로 수집(`diverse.py` forbid 재사용), **cap/forbid로 탐색 폭증 제어**가 설계 핵심.
3. **리스크 분류·적용-도구 매핑은 메타 routing 기반**(하드코딩 0, 기존 `_skills_by_routing` 확장).
4. **acceptance(S22 정준)**: 솔버가 **의도-해(5종)와 단순해(2종)를 둘 다 다양-해로 발견**. (혹은 최소 1해 + 진척.)
- 미결: 의도-해(floater→slideR→bridge→sand_mound→slideL)가 현 routing으로 *표현 가능*한지 손배치 미검증
  (slideL/slideR routing=up·ANT_ARMED). plan 전 또는 plan 중 입증 권장.

## 5e 계약 작성 완료 (2026-06-26) — 선결 de-risk 실측 → plan 영속, ⏳codex plan-review 대기

> 사용자 결정(AskUserQuestion) = "선결 먼저 실측". S22로 선결 프로토타입 검증 후 plan §"5e 계약" 작성.

- **de-risk 실측(S22 정준, 프로토타입은 revert)**:
  - 리스크 시퀀스 = ① 접근 절벽 (4,2)→우(추락) → bridge로 전원 픽업(reached=7) → ② **귀환 절벽 (8,6)→좌**
    (운반 7마리 row7 플랫폼 좌단 추락, lost=7). candy=(20,6) home=(0,2).
  - **선결(reverse_targets→cell-up 목표-위) = witness 후보 emit 확인**: bridge 후 진단이 (8,6) backpath
    `[(8,6),(9,6),(10,6),(11,6)]` + home 위 → cell-up sand_mound@(10,6) emit. **손배치 `bridge+sand_mound@(10,6)`
    = saved 7/7 lost 0**(유일, off=2; (8/9/11,6)=0/7). 후보 풀에 정답 존재.
  - **선결 단독 불충분 = _w burial이 진짜 병목**: carry-arm(slideL/R, up·ANT_ARMED) _w≈220 vs cell-up _w≈10 →
    propose top-6를 carry-arm이 독점, sand_mound **롤아웃조차 안 됨**(cap 30·LA2로도 22롤 STOP). _w 1위
    carry-arm은 클리어 못 함(7 reached/0 saved), 꼴찌 cell-up이 클리어 = cross-routing 랭킹 burial("slideR 락온"의 정체).
- **plan §"5e 계약" 골자**: D1 선결(목표-위 fall-edge→cell-up, selfcheck 확장) + **D2 리스크별 intervention-class
  *evaluated-prefix*** (plan-review R1-HIGH 반영 — "class top 1롤"은 intra-class burial 미해소라 기각): 각
  class의 *구별 차원* 프리픽스를 commit/stall 전 결정론 소진 — **up-cell = backpath `off ∈ range(min(N,len(bp)))`
  오름차순 전부**(N=수집 개수 상한 reverse=4·wall=6), ant-routing = 기존 off0..2. _w는 프리픽스 내부·잔여 순서만.
  + D3 다양-해(기존 forbid 재사용, 신규 0). 하드 게이트 = `solve.solve(22)` 7/7(witness 입증) + **witness-rolled
  fixture**(stop/commit 전 sand_mound@(10,6)=off2 실제 롤 단언, 단순 풀-존재 아님). rediscover[22] 편입.
  stretch = S21/23/24/25 + 다양-해(의도-해 5종). inert = 단일-class·단일-offset 리스크 byte-identical.

- **5e plan-review 완료 = R3 approve**(R1 HIGH intra-class burial → D2 evaluated-prefix 강화 / R2 HIGH STATUS
  stale + MED off-by-one → 동기화·`range(min(N,len(bp)))` 명시 / **R3 approve, no material findings**). 3-round cap
  내 approve(STOP 불요). 트레일 [phase05-plan-review.md](../../phases/solver/reviews/phase05-plan-review.md)
  `## 5e Round 1·2·3`. **plan-stage 종결 → 구현 진입 가능.**

## 5e 구현 완료 (2026-06-27) — S22 SOLVED·게이트 그린·자체리뷰 clean, ⏳codex impl-review

> 트레일 [phase05-impl-review.md](../../phases/solver/reviews/phase05-impl-review.md) `## 5e 구현`. plan §"5e 계약"
> (R3 approve) 구현. 엔진/PlanRunner/게임 무변경 — `tools/solver/model.py` + `scripts/run_plan.py` + `try_solve.py`.

- **D1**(`model.py`): diagnose가 fall_edges에 **per-sample `goal_above`**(`edge_goal_above` OR 집계: cur[3]==1=
  운반→home / 아니면 candy가 셀보다 위) 추가 → reverse_targets에 `goal_above` 필드. propose ③ cell-up이
  `wall_targets` + **목표-위 fall-edge**(reverse_targets 중 goal_above) 함께 순회(wall=전방 solid·fall=비-solid
  배타, seen_cells 중복 차단; N: wall=6/fall=4). ①(reverse/safe_fall/cross)는 goal_above 무시=byte-identical.
- **D2**(`model._class_prefix_protect`, propose 말미): `up_cell`이 *다른 class*(carry-arm `up_armed`·bridge
  `cross`)와 경쟁 시 _w(≈10)가 carry-arm(_w≈220)에 눌려 top-max_n 절단에 밀려 **롤아웃조차 안 되던** cross-routing
  burial 해소 — up_cell 프리픽스(off 전부)를 절단 밖이면 추가 보호. **3중 inert 가드**: up_cell∉classes OR
  len(classes)≤1(S19 단일) OR len(cands)≤max_n(절단 없음)이면 무발동=byte-identical. ①②③에 `_class` 부여
  (action/label/_w 불변, solve 미사용 → 누출 0). 추가 순서 (_risk, off↑) 사전식 결정론.
- **selfcheck 확장**(`_selfcheck_wall_targets` ⓘ-ⓙ + D2 prove-it): ⓘ 목표-위 fall-edge→emit + wall 누출 0 /
  ⓙ 목표-아래→미emit / D2 witness-rolled(carry-arm _w220 독점 합성서 보호가 witness off2 포함 + naive 절단엔
  up_cell 0개=burial 재현[vacuous 아님] + 단일 up_cell 보호 항등[inert]).
- **하드 게이트 = S22 100%**: `solve.solve(22)` **saved 7/7**, plan=`[bridge, sand_mound@(10,6)]`, 16롤. 롤8~13
  carry-arm(slideR/L) 미클리어 → D2 보호로 cell-up off0(8,6)→off1(9,6)→**off2(10,6) 클리어**(de-risk witness 일치).
- **회귀 0(byte-identical 실측)**: S19(8롤)·S13(26)·S14(40)·S20(31) solve.json git diff **0**. D1 fall-edge가 S19에
  누출 0(단일 up_cell→D2 무발동), D2가 up_cell 없는 multi-class(S13/14/20)에 무영향.
- **게이트 8/8 그린·EXIT 0**: Determinism×2(962f)+SkillMetadataDrift(11)+harness-test+selftest **19**(golden5+solve14,
  stage22 saved=7, frame byte-identical s12=2385·s13=2719·s14=4624)+analyze4(272체크)+diverse4(145체크)+rediscover
  **5**(4/13/19/20/**22** cleared actions 2/2). EXPECTED·REDISCOVER에 22 편입, stage22.solve.json 신규.
- **자체 적대 리뷰 clean(HIGH 0)**: byte-identical 경로(①goal_above 무시·_class solve 미사용)·D2 3중 가드·soundness
  (fall/wall 배타)·정직 경계 검토.
- **codex impl-review 9R(R1~R8 finding → R9 approve) + 자체 리뷰 9R clean → 종결.** 누적 해소(트레일 phase05-impl-review
  `## codex impl-review R1~R9`): R1 stale phase backpath→`edge_back_above` / R2 cap 무제한→bounded ≤2·max_n / R3 좌표순
  →`_src_rank` source priority / R4 wall이 fall starve→risk 라운드-로빈 인터리브 / R5 main이 LA2 잠식→`LA2_RESERVE`(사용자
  옵션 A) / R6 vault complete cap(dead) / R7 reserve가 작은 cap starve→`_main_cap` per-round 보존 / R8 default cap
  protected 미평가(삼각 모순)→명시 [cap 경고]+CHECKPOINT(사용자 옵션 A enforce). **정직 박제**: 정상 per-round+D2
  protected+LA2 reserve는 작은 cap에 수학적 동시 불가 → D2는 충분 cap 필요, default 10은 명시 경고. 커밋 `be78bb5`(feat)
  +`2234381`/`1d73328`/`d2f1bd2`/`5fc58fd`/`3308540`/`7fdfd41`/`d8443d6`/`fc44c38`(R1~R8 fix). **미push(로컬).**

## 블로커
- **다음 작업 = 5e push + stretch**: S21/23/24/25 + S22 다양-해(D3). 하드 게이트(S22 cap40 7/7)·게이트·codex approve 완료.
  엔진/게임 무변경. (S20 carry-mirror·S18 휴리스틱·break/down/jump cell 디바이스는 기존 미커버 유지.)
- **5d② sand_mound cell-up routing = 종결**(커밋·푸시 `6196a4d`). S19 자동 5/5.
- **S18 100% 자동발견 = model.py 휴리스틱 트랙(코드 변경)** — 5d①에서 cap-saturate 확인, 분리(별 트랙).
- **S20 구조-starvation = 수용된 latent 한계**(carry-mirror, 사용자 결정). 실제 structure→early→structure 레벨
  등장 시에만 semantic preservation 재설계로 재진입.
- **break/down/jump cell 디바이스(Basher/Cutter/Digger/LeafJump) = 미커버 routing**(스코프 밖, 후속).
