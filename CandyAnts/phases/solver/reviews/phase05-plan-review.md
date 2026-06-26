# Phase 5 (솔버 고도화·재설계 — 가능성-공간 다양-해) — Plan-stage 적대적 리뷰

> 정책: plan stage = 최대 2회 수정+재리뷰 (3-round cap). Round 3 HIGH 시 STOP·사용자 보고.
> 대상: `phases/solver/auto-solver-plan.md` Phase 5 절(특히 §"5b 계약") + 워킹트리 diff(아카이브 격리·5c 영속).
> 실행: 사용자 "bash로 실행" 지시 → `codex-companion.mjs adversarial-review`([[codex-adversarial-review-invocation]] 예외).

## Round 1

Target: working tree diff (focus가 "--help"로 전달돼 CLI 표면에 치우침 — 유효한 리뷰)
Verdict: **needs-attention**

No-ship: the CLI advertises an archived, falsified transfer mechanism as a normal supported command.

Findings:
- **[medium] `--help` exposes archived transfer-bench as an active command** (try_solve.py:367-372)
  `transfer-bench`/`seed_fn`/`vault_fn`/`tactics.py`를 archived로 표기했으나 parser는 여전히 정상 서브커맨드로
  등록(활성처럼 보이는 help + `--mode vault` 기본). `--help`로 발견한 사용자가 죽은(완전성 희생) 메커니즘을
  지원 Phase 4 벤치처럼 실행 → 오해 소지 PASS/FAIL 또는 archive가 금지한 경로 재유입.
  Recommendation: 정상 help에서 제거하거나 `help=SUPPRESS`로 숨김(명시적 archival/debug 진입), 또는 가시면
  help/출력이 `ARCHIVED / do not use for live gates`를 명시하고 vault/seed 실행 전 명시적 opt-in 요구.

### 대응 (R1 → 수정)
- `transfer-bench` 서브커맨드 help 텍스트를 `⛔ARCHIVED (Phase 4 종료) — 라이브 게이트 아님, 역사 재현 전용`으로
  변경 + **`--archived-ok` 명시적 opt-in 요구**(없으면 거부·exit 2) + 실행 시 `transfer_bench()`가 ⛔ARCHIVED 경고
  print. (argparse 서브파서 `help=SUPPRESS`는 `==SUPPRESS==`로 흉하게 노출돼 라벨+opt-in 방식 채택.)
- 검증: `--help`에 ⛔ARCHIVED 라벨 노출, `transfer-bench --test 12`(opt-in 없음) → 거부 메시지·exit 2. 회귀 0.
- 주: R1은 focus="--help"로 CLI 표면에 치우쳐 plan §5b 계약 본체는 미검토 → R2를 plan 계약에 포커스해 재실행.

## Round 2

Target: working tree diff (focus = Phase 5 §5b 계약 falsifiability)
Verdict: **needs-attention**

No-ship: Phase 5b still over-claims the merge/split contract. (archived transfer-bench help surface = R1 수정으로 해소 확인.)

Findings:
- **[high] Sampled ranges can be merged into a solution-class without proving interior continuity** (auto-solver-plan.md:494-515)
  계약이 range를 연속 클리어 구간으로 정의·병합하면서 range는 sampled/gap-추론이고 5c 게이트는 min/max 경계 +
  바깥 1칸만 리플레이 → **내부 hidden fail-island를 falsify 못 함**. 미샘플 gap을 가로질러 병합해도 경계 게이트는
  통과 → "비연속 배치는 별개 solution-class" 규칙을 정면 위반.
  Recommendation: 연속성을 sampled 추론이 아니라 **검증된 artifact**로 — `{sampled_points, gap_check_stride,
  intervals, gaps, gap_verified}` 저장; 게이트가 `analyze.py --verify`처럼 내부/gap 점도 리플레이; 선언 해상도로
  verified일 때만 병합, 아니면 provisional 표기·확정 병합 금지.
- **[medium] Distinctness rule ignores timing and target-role differences** (auto-solver-plan.md:496-500)
  분리 규칙이 비연속 배치·스킬횟수 변화만 새 해로 봄 → 너무 강함. 액션은 target role·trigger/timing을 포함하고
  D5가 타이밍을 1급 차원으로 둠. 같은 스킬·같은 배치 구역이라도 `select`/carrying/`picked_ge` 서수/`ant_reaches_x`
  방향이 다르면 **다른 전략**인데 병합돼 디자이너 보고에서 은폐.
  Recommendation: solution-class 동치를 skill multiset + 배치 구간 + target role/state + trigger/timing 앵커/subgoal로
  정의. 그 비-placement 의미가 같을 때만 same-region same-count 병합, 아니면 timing/role 변형을 별개 축으로 표기.

### 대응 (R2 → 수정)
1. (HIGH) §5b 계약·게이트·Acceptance를 **검증된 연속**으로 전환: range 발견이 `{sampled_points, gap_check_stride,
   intervals, gaps, gap_verified}` 산출(analyze.py `_reconstruct_runs`+R12 gap_verified 재사용). **병합은 stride
   해상도 gap_verified일 때만**, 미검증=`provisional`(확정 병합 금지). 5c 게이트가 **경계 + 내부/gap 샘플 점**을
   리플레이(analyze.py --verify 동형)해 hidden fail-island 병합 차단.
2. (MEDIUM) distinctness를 **4요소 동치**로: skill multiset + 검증된 연속 구역 + target role/state(`select`/`state`)
   + trigger/timing(`trigger` type·cmp·`picked_ge` 서수·subgoal). 넷 다 같을 때만 병합, 하나라도 다르면 분리.
- 다음: Round 3(최종, 3-round cap) 재리뷰.

## Round 3 (최종 — 3-round cap)

Target: working tree diff (focus = R2 수정 검증 + 잔여 over-claim)
Verdict: **needs-attention (HIGH 0, MEDIUM 1)**

R2의 연속성(HIGH)·4요소 동치(MEDIUM)는 "mostly closed" 확인. 잔여 = 내부 일관성 MEDIUM:

Findings:
- **[medium] Region-only forbid can hide valid role/timing-distinct solution classes** (auto-solver-plan.md:510-511)
  4요소 distinctness는 "같은 배치라도 role/state·trigger/timing이 다르면 분리"라 했으나, 분리-해 탐색이 **발견 placement
  구역 전체를 forbid한 뒤** 재탐색 → 같은 검증 구역·다른 `state`/`select`/`picked_ge` 서수/trigger 방향/subgoal 대안이
  **분류 전에 필터**됨. 보고가 후보 없음으로 멈춰 distinct 전략을 과소보고하면서 4요소 distinctness를 주장.
  Recommendation: forbid 키를 placement 구역이 아니라 **4요소 solution-class 시그니처**로; 또는 구역 forbid 전에
  구역-내 role/timing/subgoal 스윕을 명시.

### 대응 (R3 → plan 내 처리·종결)
- **MEDIUM (HIGH 0)** → plan-stage 정책 "MEDIUM만 남으면 plan 내 처리로 종결"에 따라 **STOP 불필요·plan 수정으로 종결**.
- §5b "분리-해 탐색"을 **4요소 시그니처 forbid + 2단계**로 수정: (a) 구역-내 role/timing/subgoal 변형 스윕을 **먼저**
  (same-placement 다른 전략 포착) → (b) 구역 밖 배치 탐색. forbid가 시그니처 단위라 placement 동일·role/timing 상이
  class가 구역 forbid에 묻히지 않음.

## 종결 (Phase 5 §5b 계약 plan-stage)
- **R1**(needs-attention: MEDIUM×1, archived CLI 표면 — 수정) → **R2**(needs-attention: HIGH×1 연속성 + MEDIUM×1
  4요소 — 수정) → **R3**(needs-attention: HIGH **0**, MEDIUM×1 forbid 일관성 — plan 내 처리). 3-round cap 내, **Round 3
  HIGH 0 → STOP 미발동**. 잔여 HIGH 없음, MEDIUM 전부 plan에 반영 → **plan-stage 종결**.
- plan-review 통과 → revised 5b **구현 진입 가능**(range-sweep + gap_verified + 4요소 solution-class + 2단계 forbid +
  5c 경계/내부/gap 게이트). 구현은 impl-stage 적대 리뷰 정책(별도) 적용.

---

# 5d② sand_mound (cell-up) routing — Plan-stage 리뷰 (2026-06-26)

> 정책: plan stage = 최대 2회 수정+재리뷰 (3-round cap). Round 3 HIGH 시 STOP·사용자 보고.
> 대상: 워킹트리 doc diff = `phases/solver/auto-solver-plan.md` §"5d② 계약" (+ STATUS.md 동명 절).
> 실행: 사용자 "bash로 실행" → `codex-companion.mjs adversarial-review --wait --scope working-tree`
> ([[codex-adversarial-review-invocation]] 예외). codex session 019f017b-b186.

## 5d② Round 1 — needs-attention (HIGH×2 + MEDIUM×1)

No-ship(codex): "wall-detection 계약이 의도 벽을 놓칠 만큼 모호 + acceptance가 정준 스테이지를 안 풀고도 통과 가능."

- **[HIGH] wall_targets 방향 소스 부재** (auto-solver-plan.md D1): 트레이스는 셀 변화+carry/state만 기록하고
  `ant.direction`/wall-hit 이벤트가 없다. d를 *반전 후* 이동으로 추론하면 S19 우측벽(15,14)이 bounce 후 좌향으로
  잡혀 전방-solid 테스트가 빗나가고, 넓게 추론하면 계곡서 좌·우 벽을 어느 게 route를 진척시키는지 증명 없이 둘 다
  emit → 정확히 타깃 지오메트리(valley)에서 후보 0개 또는 예산낭비 false-positive. 권고: d를 명시·테스트가능하게
  (incoming 세그먼트로) 정의 + S19 right/left/two-wall 케이스 테스트를 구현 전에.
- **[HIGH] acceptance가 S19 미클리어로도 ship 허용** (D 스코프): S19를 정준 100%라 부르면서 falsifiable
  acceptance는 "유효 후보+best_goal_dist 개선"만 먼저 수용하고 S19 100% 실패를 후속 트랙으로 명시 defer = escape
  hatch. 구현이 plan 게이트를 통과하면서 sand_mound×2 닫힌-루프 stacking의 유일 정준 증명에 실패할 수 있음(STATUS도
  동일 경계 반복). 권고: S19 100%(×2)를 하드 게이트로, 아니면 primitive-only spike로 정직하게 개명하고 S19를
  정준 주장에서 제거.
- **[MEDIUM] D4 crisis 노트 = dead text 또는 아카이브 pruning 재오픈**: `knowledge.detect_crises`는 하드코딩
  토큰(reverse_target.to_water 등)만 발화 → `detect: wall_targets` 노트는 코드 없이 미발화(dead). 발화시키면
  `vault_prune`가 crisis factor를 소비해 "서술용" 노트가 vault 모드 후보 필터링에 영향. plan이 둘 중 어느 경계도
  선택·테스트 안 함. 권고: D4 제거, 또는 no-code doc-only로 명시 + `knowledge.resolve`/`vault_prune` 출력 불변
  regression. live 검출은 별도 리뷰 변경.

### Round 1 수정 (3건 전부 반영, → Round 2 재리뷰 대기)
- **R1-H1**: D1 재작성 — **d = 진입(incoming) 세그먼트 방향**으로 명시 정의(반전 전 마지막 수평 이동 부호) +
  **soundness 게이트 = 전방 `(cx+d_in,cy)` occupied**(허공 반전·절벽 배제) + two-wall valley 둘 다 emit·목표거리
  감소 desc 정렬 + **`model._selfcheck_wall_targets()`**(right/left/two-wall/허공반전/목표-아래 5케이스 prove-it,
  rediscover-verify 편입)로 방향 규약 박제.
- **R1-H2**: 스코프 재작성 — **S19 100%(saved=5/5, sand_mound×2) = 하드 acceptance 게이트**. escape hatch 제거.
  불가 판명 시 silent defer 금지·S18식 실측 입증 후 사용자 STOP·에스컬레이트. S21~25/S5는 명시적으로 게이트 밖 stretch.
- **R1-M**: **D4(볼트 crisis 노트) 본 plan에서 제거** — knowledge.py/볼트 무변경. 신규 위기 볼트 편입이 필요하면
  별도 doc-only 변경(resolve/vault_prune 출력 불변 regression)으로 분리.

## 5d② Round 2 — needs-attention (HIGH×1 + MEDIUM×1)

No-ship(codex): "수정된 plan도 S19 stacking 경로가 기존 cell-placement 의미와 내부 불일치."

- **[HIGH] stacked sand_mound 사인이 의존 지형이 생기기 전 emit됨** (D2/D3): 모든 cell-up 타깃이 at_frame=0인데
  D3은 1번째 사다리가 지어진 *후* 2번째 타깃이 나타나는 닫힌-루프에 의존. SignPlacement는 요청 빈 셀을 **현재
  점유 ground로 아래 snap** → frame0엔 1번째 사다리 rung이 없어 2번째 타깃(예 col15,row9)이 valley 바닥으로
  snap, 2-사다리 S19 acceptance가 하드 게이트에도 불구 불가능할 수 있음. 권고: stacked cell-up을 선행 사다리
  건설 *후* 스케줄, 또는 no-snap exact 배치 모드 + S19 2번째 사인이 post-ladder top에 lands하는 prove-it.
- **[MEDIUM] S19 하드 게이트가 정준 verify 계약에 미배선**: 회귀 게이트가 selftest byte-identical + 현 verify
  green + `_selfcheck_wall_targets`만 — 현 verify 체인에 stage19 없고 rediscover-verify 대상도 4/13/20뿐. 새
  분기가 단일 정준 게이트 밖 → 산문 1회 충족 후 회귀해도 verify가 못 잡음. 권고: stage19를 실행 가능 게이트
  (rediscover-verify 또는 동등 search-19 재발견)에 편입 + sand_mound×2 시그니처 검증 명시.

### Round 2 — 경험적 조사 + 수정 (사용자 질문이 교정 유발)
**조사(엔진 replay + 코드 실독, R2 HIGH "likely impossible" 검증):**
- 손배치 `[(15,14),(15,10)]` replay → **saved=1/5**: ant0(건설자)만 cap·픽업·귀환, ant1~4는 (15,12)↔(15,11) 진동.
  → 처음엔 "추종자 cap=건설자 전용"으로 오판.
- **사용자 질문 "지금 천장 못 넘는다고 판단하나?"** → `LadderClimbState` 실독: cap = 위=레지 AND 위-위=빔이면
  추종자도 레지 넘음. **오판 교정** — 천장은 넘을 수 있음.
- **6×4 col 스윕**: 대각(L1col==L2col) 전부 1/5, L2col>L1col 상삼각 전부 **5/5**. 손배치 `(10,14)+(12,10)` →
  **saved=5/5 frame1586, 5마리 전원 픽업·귀환**. 1/5의 진짜 원인 = **같은-col 재스택**(ladder2 바닥 rung이
  ladder1 cap "위-위=빔" 채워 깨뜨림) + **벽-붙은 ladder1**(off=0, ladder2 공간 無).
- ∴ R2 HIGH의 *snap* 주장은 **경험 반증**(S19 두 타깃 모두 기존 플랫폼 위라 frame-0 유효), 그러나 조사가 더 깊은
  **배치 위상 제약**(T1 다른-col / T2 우향 / T3 off≥1)을 드러냄.

**수정(plan 반영):**
- **R2-H(위상)**: 메커니즘 절에 추종자-cap 교정 + (T1~T3) 위상 제약 명문화. **D2를 후보 column-sweep(A안)**으로 —
  반전-셀 단일 대신 backpath off=0..5 펼침 + 같은-col exclude(T1) + 엔진 verdict 선별(T2/T3는 verdict가 거름).
  acceptance에 **5/5 witness**(존재 확인된 해) 박제 + naive greedy 실패·검색 breadth 필수 명시.
- **R2-M(verify)**: rediscover-verify에 **stage19 케이스 편입**(solve.solve(19,save=False) → cleared saved=5/5 +
  sand_mound×2 시그니처 단언) + solve.json/selftest EXPECTED. 실행 가능 정준 게이트로 배선.

## 5d② Round 3 (최종, 3-round cap) — needs-attention (HIGH×1 + MEDIUM×1) → STOP·사용자 결정

No-ship(codex): "수정 plan도 S19 수렴 계약이 plan이 실제로 바인딩하지 않는 솔버 plumbing에 의존."

- **[HIGH] 같은-col exclude를 `base plan` 기준으로 명세했으나 LA2 제안은 오늘 `base2`를 못 봄** (D2): T1을
  "base plan에 이미 있는 col 후보 exclude"로 안전화했는데, 이건 랭킹이 아니라 1/5 실패모드. 기존 `_propose`는
  LA2용 `base` 인자를 받지만 `model.propose(..., plan=plan)`로 **closed-over 확정 plan**을 넘김(solve.py:223-228,
  LA2가 base2 전달 solve.py:326). ∴ 필터를 `model.propose` 안에 넣으면 **LA2 2nd-step 제안(speculative 첫
  sand_mound 후)엔 미적용** → 유일한 조합-검색 경로가 plan이 "불가능"이라던 같은-col 재스택을 제안 가능, 좁은
  LA2 cap 낭비 또는 poisoned pair 선택. 권고: cell-up exclude에 speculative `base`를 넘기도록 solve.py plumbing
  명시(early-chain closure 의미 보존하며 cell-up 전용 `accepted_actions`/`base_plan` 파라미터) + LA2가 speculative
  첫 후 2번째 sand_mound 제안 시 같은-col 후보 부재 regression.
- **[MEDIUM] off=5 witness가 후보-emit 증명으로 보호 안 됨** (D1/D2): 유일 알려진 S19 해는 ladder1=col10
  =우측벽서 off=5. D2는 off=0..5 펼침이라지만 D1 selfcheck는 방향/soundness/정렬만 증명, **backpath가 그만큼
  깊은지·propose가 off=5를 실제 emit하는지 미단언**. 현 reverse는 backpath 4 hard-cap(model.py:129)·제안
  min(3,len(bp))(model.py:304) → 미러 구현이 D1 selfcheck 통과하며 witness col을 영영 안 낼 수 있음 → S19 실패가
  비싼 rediscover서 'cap/heuristic' 모호 진단으로만 표면화. 권고: S19형 wall_targets fail-closed
  selfcheck/fixture — 우측벽 타깃이 backpath ≥6 보유 + propose가 롤아웃 전에 off=5 후보 (10,14) emit 단언.
  새 backpath collector는 기존 reverse depth cap 재사용 금지 명시.

→ **plan-stage 3-round cap 도달, Round 3 HIGH 1건 → 정책상 STOP. 사용자가 수정 방향·범위·취소 결정.**

### Round 3 후속 — 사용자 결정 (2026-06-26, AskUserQuestion) = "반영 후 구현 진입"
3-round cap·R3 HIGH 정책상 STOP → 사용자가 방향 결정. 두 finding(R3-H1 LA2 base plumbing / R3-M1 off=5 emit
증명)은 **접근 무효가 아닌 테스트가능성 요구**로 판단 → **plan에 구현 바인딩 요구로 명문화**(§"구현 바인딩
요구") 후 **구현 진입**. 4th plan-review 라운드 없이, 두 요구의 충족은 **impl-stage 적대 리뷰 + fail-closed
fixture/regression**으로 검증한다. (정책 예외=사용자 오케스트레이터 override, S18/S20 선례 동류.) → **plan-stage 종결.**
