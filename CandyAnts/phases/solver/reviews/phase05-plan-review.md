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
