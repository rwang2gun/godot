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

## 다음 작업 (Phase 3 또는 솔버 고도화)
- **Phase 3 진입**(반응-윈도우·인간타당성·난이도, plan §Phase 3): max-margin 해의 각 필수 명령에 대해
  (프레임·위치) 윈도우를 스윕 측정 → `T_human` 필터(정합성) + 난이도 점수. 최소화/크레딧 할당(잉여 액션 제거).
- (선택) 솔버 효율 고도화: S13 26롤은 매 carry 라운드 early 후보가 cap을 1개씩 낭비(S13선 무용). carry
  연쇄 우선·early 후순위로 cap 내 해결 가능 — 사용자 정책상 해 확보가 우선이라 defer 가능(회귀 위험 ↔ 효율).
- 게이트 약점(잔존): `PlanReplayHarnessTest`가 run_test 기본 `--quit-after`에 timeout-마스킹(EXIT 0).
  verify에 `--fixed-fps`/큰 `--quit-after` 부여 검토(이번 검증은 명시 옵션으로 PASS 확인).

## 블로커
- 없음.
