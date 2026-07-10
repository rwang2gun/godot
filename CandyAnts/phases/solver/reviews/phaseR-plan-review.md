# Phase R (정식 RL 솔버) — plan-stage 적대적 리뷰 트레일

> 대상: `phases/solver/auto-solver-plan.md` §"Phase R — 정식 RL 솔버". codex `task --effort high`(read-only,
> 미커밋 plan은 adversarial-review가 못 보므로 task 모드 — phase03 선례). 정책 = plan stage 3-round cap.

## Round 1 (2026-07-03) — needs-attention (HIGH 3 · MEDIUM 3 · LOW 1)

**Verdict: Needs Attention**

No CRITICAL finding, but several HIGH issues should be fixed before R0 implementation.

- **HIGH-1:** R0 reward is unsafe on deadline terminals. The plan divides by `hp` in `saved/hp`, `picked_total/hp`, `lost/hp`, but `PlanRunner` reports deadline as `saved=0, lost=0, hp=-1` (PlanRunner.gd:224). With bad plans mostly timing out, the shaping reward becomes nonsensical and can penalize pickup progress via a negative denominator. R0 needs an explicit terminal-result normalizer for timeout/error cases.

- **HIGH-2:** The R0 action space does not cover the known S12 solution, so the S12 stretch is currently a dead branch. R0 only states `ant_reaches_x(ge, x=col*48)` and no y-band, while S12 requires `cmp: le` twice and three distinct `y_min/y_max` bands (stage12.solve.json:30,35,58). `PlanRunner` defaults omitted y-band to ±∞ and default state to `walker` (PlanRunner.gd:391,395), but R0's state head is `{any, carrying}`, not `walker`. Add `cmp`, y-band, and `walker`, or explicitly mark S12 impossible under R0 grammar.

- **HIGH-3:** R0 acceptance is not yet reproducible enough to be falsifiable. "≤20k episodes or wall ≤2h" depends on hardware, `N` envs, batch size, seed, and hyperparameters, while reward scale is "튜닝 자유". Make this a fixed command/config: seed, env count, max episodes, max wall, and exact pass predicate.

- **MEDIUM-1:** The "solve.score signal reuse" claim is overstated. The plan uses `lost` and no trace, but `solve.score()` uses trace-derived `retired` and `goal_dist` (solve.py:148,156). `lost` exists in `SOLVER_RESULT` (PlanRunner.gd:489), but it is not equivalent to retired/trapped ants.

- **MEDIUM-2:** Gate non-coupling is mostly true, but R0 acceptance lacks fail-closed automation. `.rl.json` is intentionally outside selftest; existing selftest/analyze glob only `*.solve.json` / `*.analysis.json`. `try_solve replay` can replay arbitrary files, but its exit code only requires `saved >= 1` (try_solve.py:258). R0 should define its own acceptance command that checks saved=hp and replay x2 byte identity.

- **MEDIUM-3:** Parallel env readiness is over-claimed. The spike proves repeated single persistent env runs, but the plan claims N-parallel readiness. `_free_port()` explicitly closes the socket before Godot binds and says the race is ignored (env.py:46). Add a small parallel determinism/port-collision preflight before relying on `N병렬 ×N`.

- **LOW-1:** PyTorch/Python 3.14 is a hard precondition but not captured in a manifest. The plan asserts PyTorch 2.12.1 on Python 3.14; sandbox rejected interpreter probes. Add a solver-RL requirements file or a documented setup check.

**Confirmed Non-Issue**: `lost` is actually present in `SOLVER_RESULT` (PlanRunner.gd:478,489).

### 처리 (전부 plan 반영)
- H1 → 보상 정규화 계약: `hp_stage`(StageData 상수, env 셋업 시 1회 확정)로만 나눔, result `hp` 미사용.
  timeout/error verdict = cleared 보너스 0 + timeout 페널티, picked shaping은 유지.
- H2 → 액션 어휘 확장: `cmp ∈ {ge,le}` head + `y_row ∈ {any, 0..H-1}`(row→y-band 변환) head + state에 `walker`
  추가. **문법 커버리지 단위 검사**(known S11/S12 해를 문법으로 인코딩 가능, 롤아웃 불요) acceptance 편입.
- H3 → 고정 커맨드/설정 acceptance: pinned seed·envs·예산 + 정확한 pass predicate(saved==hp_stage) 명시.
- M1 → 문구 정정("신호 계열 차용" → "유사하나 등가 아님 — lost≠retired").
- M2 → `rl/` 자체 검증 커맨드(`--verify-r0`): rl.json replay ×2 byte-identical + saved==hp_stage fail-closed.
  (메인 게이트 비편입 유지 = 커플링 0 원칙.)
- M3 → R0 작업에 병렬 preflight 추가(N=4 동시, 각 2회 byte-identical + bind-실패 재시도 계약).
- L1 → `tools/solver/rl/requirements.txt` + 셋업 체크 1줄.

## Round 2 (2026-07-03) — needs-attention (HIGH 1 · MEDIUM 3; R1 핵심 해소 확인)

Verdict: **needs-attention**. No CRITICAL findings, but Round 1 is not fully closed.

- **HIGH:** The "fixed command" is still not a real reproducible command — `--seed {0,1,2}` is placeholder/brace-expansion notation, not portable; argparse would receive one literal seed. Need `--seeds 0,1,2` or three explicit commands plus an aggregate checker.
- **MEDIUM:** `train.py defaults are SoT` weakens falsifiability — acceptable only if `--verify-r0` also validates an emitted effective-config manifest; as written, changing defaults changes the acceptance target without changing the plan.
- **MEDIUM:** The N=1 fallback conflicts with the fixed `--envs 4` acceptance story. Define whether R0 can pass under N=1, and pin the command/budget semantics.
- **MEDIUM:** `--verify-r0` is fail-closed for replay only, not for the full R0 acceptance (3-seed predicate, no-hint condition, envs mode, effective config remain manual).

**Resolved / Sufficient**: R1-H1(hp_stage 분모 — PlanRunner deadline hp=-1 대비 정확한 수정), R1-H2(cmp/y-band/walker — PlanRunner 스키마·S12 해와 대조 확인, 밴드 변환식 명시 요청), R1-M1(문구 정정), R1-L1(requirements 명시).

### 처리
- H → 단일 pinned 커맨드 `--seeds 0,1,2`(seed당 예산 + train.py 집계 exit code)로 확정.
- M1 → effective-config manifest를 stage11.rl.json에 동봉 + verify-r0 검증 대상화.
- M2 → `--envs 4`=상한 + preflight 실패 시 자동 N=1 강등 + `envs_effective` manifest 기록, pass는 N 무관.
- M3 → verify-r0 확장: manifest 완전성 + 3-seed predicate 재판정 + replay ×2 + saved==hp_stage 전부 fail-closed.
- (부수) 커버리지 검사를 "byte 인코딩"에서 "격자 인코딩 + 엔진 리플레이 클리어(스테이지당 1롤)"로 재정의.

## Round 3 (2026-07-03) — **approve** (CRITICAL/HIGH 0 · MEDIUM 1 · LOW 2)

Verdict: **approve**. No CRITICAL/HIGH findings.

- **MEDIUM:** "가장 가까운 격자 인코딩" under-specified — row band formula defined but arbitrary y_min/y_max → row conversion needs a deterministic metric/tie-breaker (suggested: maximize overlap, deterministic tie, record selected row). Not HIGH because engine replay fail-closes.
- **LOW:** `verify-r0` partially trusts the manifest train.py wrote — acceptable for a local non-main-gate check since verify-r0 independently replays best plan ×2 with saved==hp_stage.
- **LOW:** `--max-wall 7200` is per-seed (documented); flag name could be misread as global but text resolves it.

The four R2 fixes are sufficient. Sanity: hp_stage aligns with StageData.candy_hp/original_hp; PlanRunner reports hp=-1 only on deadline path; RL stays outside frontmatter verify (gate coupling zero).

### 처리 (plan-stage 종결)
- MEDIUM → plan 내 처리: 변환 규칙 명문화(겹침 최대 row, 동률 시 낮은 row, 선택 row 기록).
- LOW×2 → 수용(트레일 박제): verify-r0의 manifest 신뢰는 로컬 비게이트 검사 + 독립 replay가 보완. per-seed wall은 문서로 해소.
- **plan stage 종결 = R1 fix → R2 fix → R3 approve (3-round cap 내).** 구현(R0) 진입.

---

# §R1 (trace-shaped 보상) plan-stage 리뷰 (2026-07-03)

> 대상: plan §"R1 — trace-피드백 보상 shaping". codex `task --effort high`(read-only, 미커밋 plan — task 모드).
> 정책 = plan stage 3-round cap.

## R1 Round 1 — needs-attention (HIGH 1 · MEDIUM 4 · LOW 1)

**Verdict: needs-attention.** No CRITICAL findings.

- **HIGH:** `--verify-r1`/`R1_PIN` under-pinned vs R0 gate — stage_id=12, envs_requested=4, budgets,
  replay_deadline=7000, shaping coefficients가 fail-closed 상수로 명시 안 됨 (R0_PIN 교훈).
- **MEDIUM-1:** goal_dist "단조" 과대 서술 — probe 자체가 #2에서 goal plateau·retired가 구별함을 보임.
  올바른 주장 = 합성(goal+retired) 단조.
- **MEDIUM-2:** trace 처리량 주장만 있고 게이트 없음 — trace-on preflight/manifest 기록 필요.
- **MEDIUM-3:** 엔트로피(0.03→0.005)와 shaped 보상 스케일 상호작용 미언급 — 스케줄 pin 또는 진단 로깅.
- **MEDIUM-4:** cross-doc drift — STATUS는 R1을 "후보 집합"으로 서술, plan은 확정. 순환 SoT 리스크.
- **LOW:** 로드맵 아래 리스크 절 stale — "shaping(picked/lost)로 완화"는 S12가 반증한 문구.
- Non-issue 확인: PlanServerHarness trace passthrough 건전(env.py:91, PlanServerHarness.gd:74,89).

### 처리 (전부 반영)
- H1 → Acceptance 2항에 R1_PIN 상수 전량 명시(stage_id·seeds·envs·예산·replay_deadline·shaping·**계수
  {goal:0.5, retired:0.1}**) + "계수 튜닝은 fallback 1에서만, R1_PIN 동일 커밋 갱신" 계약. pinned 검증
  커맨드 명시(`--verify-r1 --stage 12`).
- M1 → "합성 신호(goal_dist+retired) 단조"로 본문·정직 경계 재서술(known-prefix 한정 명시).
- M2 → trace-on preflight(digest+trace 전부 identical) + `preflight_trace_wall_s` manifest 기록 설계 추가.
- M3 → 엔트로피 스케줄 R0 유지 사전 결정 박제 + 배치 로그에 meanShape 분리 출력(진단 가시성).
- M4 → STATUS S12 stretch 항목에 "후속 세션 R1 스코프 확정(plan §R1 SoT)" 추기.
- L1 → 리스크 절 "R0가 반증 → R1 trace-파생 shaping 대체"로 갱신.
- (자기-발견, Round 1 전 반영) 학습 deadline 함정: 격자-인코딩 S12 클리어 frame=2981 vs 학습 cap 3000f
  → `--train-deadline` 신설, pinned 커맨드 4500. / S12 prefix 단조성 probe 실측을 §R1 grounding에 박제.

## R1 Round 2 — needs-attention (HIGH 1 · MEDIUM 1; Round 1 전 항목 closed 확인)

- **HIGH:** `--train-deadline 4500`이 pinned 커맨드에 있는데 R1_PIN 강제 목록에 없음 — plan 스스로
  "3000f cap이 최적점 근방을 굶긴다"고 명시했으므로 material 파라미터. stale 3000f 산출물이 통과 가능.
- **MEDIUM:** trace-on preflight를 게이트로 서술하고 `preflight_trace_wall_s`를 기록한다면서 verify-r1
  manifest 완전성 검사에 그 증거(패스 마커/wall)가 없음 — fail-closed 밖에 남음.
- Verified closed: R1 Round 1의 HIGH·M1(합성 단조)·M2(대부분)·M3(엔트로피)·M4(STATUS)·LOW 전부.

### 처리 (전부 반영)
- H → R1_PIN에 `train_deadline=4500` 편입(verify-r1 fail-closed 강제). "학습-전용 knob 비대상"의 R0
  원칙에 대한 명시 예외 — plan이 material하다고 스스로 입증한 knob은 pin.
- M → manifest에 `preflight_trace {ok, wall_s, runs}` 필드 필수 + `envs_effective>1 → ok=true` 강제
  (N=1 강등 시 ok=false 허용 = R0 N-폴백 계약 동형)를 verify-r1 검사에 편입.

## R1 Round 3 — **approve** (no remaining findings)

- Verified: R1_PIN에 `train_deadline=4500` fail-closed 편입(+R0 "학습-전용 knob 비대상" 원칙의 명시 예외
  근거) / verify-r1이 `preflight_trace {ok,wall_s,runs}` 요구 + `envs_effective>1 → ok=true` 강제 +
  ok=false는 N=1 강등 계약 하에서만 허용.
- **Final verdict: approve.** plan-stage 종결(R1→fix→R2→fix→R3 approve, 3-round cap 내).

### Post-approve 사용자 수정 (2026-07-04 — 리뷰 대상 아님, 사용자 결정 기록)
- **wall 예산 하향**: pinned 커맨드·R1_PIN `max_wall 7200→1800`(사용자 "최대 30분 기준"). 설계 불변 —
  예산 상수만 교체. 음성 대조(dc68a47, wall 7200에서 20k eps 완주)와의 비교 눈금은 에피소드 수로(plan 정직 표기).
- **§R1-스윕 신설**: S13~S25 순차 탐사(단일 seed·30분 cap·비게이트·세션 로그 박제). acceptance 무관.

---

# §R2 (영속 학습: 체크포인트+스테이지-불변 정책+curriculum+cell-target) plan-review

## Round 1 (2026-07-04) — Request Changes (CRITICAL 2 · HIGH 4 · MEDIUM 4 · LOW 1)

- **[critical] 재개 등가성이 서술대로는 불성립** — 병렬 수집·포트 재시도·SIL 순서·비-torch RNG·wall 회계
  하에서 "정확 일치"는 torch RNG만 저장해선 불가. → **배치-수 기준 판정**(wall 제외) + 사용 RNG 전수·SIL
  내용/순서 직렬화 + 인덱스-순서 수집 계약 명시로 재정의.
- **[critical] P2 문법 승격이 기존 verify-r0/r1 산출물을 검증 불능화** → **선결 계약 신설**: verify-r0/r1
  grammar pin을 리터럴 "r1.1"로 동결 + StageMDP 버전 인자 구성(레거시 경로 보존). 가중치는 애초에 게이트
  비대상(산출물=plan JSON) 명문화.
- **[high] curriculum acceptance 비falsifiable("유의 상회")** → 고정 커맨드+predicate(≥2/3 seed 클리어,
  R1 형식)로 교체, 통계 술어 금지. from-scratch 대조 3-seed 완성 옵션 명시.
- **[high] cell-target이 sum-type 계약 없이 모호** → `target_kind` 1급 판별자 head + kind별 유효 head
  마스킹 + JSON lowering 규칙 + **at_frame 트리거 추가**(S19 known 해 실측이 요구 — 리뷰 중 확인).
- **[high] S19 클리어가 어휘 증명과 학습 성공을 혼동** → ⓐ 결정론 커버리지(known 해 r2 라운드트립 replay)
  / ⓑ 학습 발견 분리 — 실패 원인 구별 가능화.
- **[high] campaign_manifest SoT 미정의** → `data/campaign_manifest.tres` 명시(read-only 파싱, 하드코딩 0)
  + verify-r2 manifest 정합 검사.
- **[medium] 체크포인트 직렬화 목록 불충분** → 전수 목록(RNG 전수·SIL·digest들·모델 config·dtype) +
  verify-r2 비호환 재개 거부.
- **[medium] param/y_row "정규화"가 r1.1 시맨틱 파괴 위험** → 정규화 기각, **이산 전역 어휘+마스킹** 확정
  + r2 커버리지 게이트(S11/S12/S19).
- **[medium] entropy 스케줄 영속 vs curriculum 탐험 충돌** → 스테이지 경계 리셋 + 전역 카운터 별도 보존
  결정.
- **[medium] verify-r2 무계약** → 커맨드+검사 항목 계약 신설(pin 상수는 impl 커밋 동봉 — R0/R1 선례).
- **[low] S14/S15 동기가 acceptance에 없음** → 비게이트 R2-스윕(curriculum 체크포인트 기반, 대비표 박제)
  항목 추가.

전 항목 §R2 v2에 반영 완료 → Round 2 재리뷰.

## Round 2 (2026-07-04) — HIGH 2 · MEDIUM 4 · LOW 2 (R1 전 항목 해소 인정)

- **[high] S12-커리큘럼-ckpt 출처 미정의(cherry-pick 가능)** → **per-seed pinned 사슬**(S11 from-scratch
  → S12 transfer → S13 acceptance, 각 seed는 자기 사슬 ckpt만; 재개 사슬 manifest+verify-r2가 무결 증명;
  사슬 앞단 미클리어 seed = FAIL 집계).
- **[high] 레이아웃 digest fail-closed가 curriculum 전이와 모순** → **로드 2모드 분리**: `--resume-ckpt`
  (동일-스테이지 exact, digest 일치 요구) / `--transfer-ckpt`(타 스테이지, 가중치+optimizer만 이월·
  스테이지-파생 상태 재구성·문법/shape 호환만 요구). manifest에 mode 기록.
- **[medium] 전역 격자 상한·양축·at_frame head 미정의** → 전역 W/H = campaign_manifest 등재 레이아웃
  전수 스캔 파생(초과 = 명시 에러+어휘 버전 승격, silent 확장 금지) / 행 head 이원 마스크(ant=surface,
  cell=전 행) / at_frame = 양자화 격자 head+train_deadline 마스크.
- **[medium] cell 트리거 어휘 미정** → **트리거 직교 계약**: cell도 전 트리거 유효(트리거="언제"·
  target="무엇에"), kind 마스크는 target 계열 head만.
- **[medium] 병렬 수집 하 배치 순서 미계약** → 결정론 배치 계약 ⓐ~ⓓ(메인 스레드 순차 샘플링·인덱스-순서
  수집·부팅 재시도 RNG 비소비·등가성 시험 중 wall 중단 비활성).
- **[medium] 재개 사슬 예산 회계 미정** → **구간별 회계**(acceptance 예산은 해당 스테이지 구간에만,
  verify-r2가 구간 카운터 검증).
- **[low] §R1 "pin 비대상" 문구와 충돌** → §R2 선결 계약에 개정 우선순위 명시(§R2 > §R1 해당 문구).
- **[low] S19 학습 acceptance 미pin** → from-scratch 단독 pinned 커맨드+≥2/3 predicate 고정.

전 항목 §R2 v3에 반영 → Round 3 (최종) 재리뷰.

## Round 3 (2026-07-04) — HIGH 2 · MEDIUM 1 → **정책상 STOP·사용자 보고** (3-round cap)

- **[high] transfer 호환성이 과소 축소** — `--transfer-ckpt` 요구를 "문법 버전+모델 shape"로 좁힌 게
  과교정: shape가 같아도 **전역 어휘 digest**(스킬 id 순서·트리거 id·격자 어휘·at_frame bin)가 다르면
  가중치가 다른 시맨틱에 silent 매핑. → digest 계약 분리 필요(transfer는 레이아웃/per-stage 마스크
  digest 무시 OK, **전역 어휘/head-시맨틱 digest는 fail-closed**).
- **[high] acceptance 2 커맨드가 실행 불능 pin** — `--seeds 0,1,2`(복수)에 단수 `--transfer-ckpt <ckpt>`
  하나: seed별 ckpt 해석이 암묵적 → 한 seed의 ckpt를 전 seed에 쓰는 오구현 여지. → seed→ckpt 매핑
  (사슬 manifest 인자) 또는 per-seed 단일 커맨드 ×3으로 pin 필요.
- **[medium] 사슬 앞단(S11/S12) 예산 미pin** — "R1 계열 예산" 문구뿐, S12 구간 커맨드/예산 미고정 →
  S13 구간 회계만으로는 curriculum 증명이 비재현(운영자 재량 S12 구간 허용).

R2 fix들은 실질 해소로 인정("boundary gaps introduced by fixes, not repeats"). 위 3건 처리 방향은
사용자 결정 대기(계속 수정+R4 / 반영 후 종결 / 취소).

## Round 4 (2026-07-04, user-extended cap — 사용자 승인 "3건 반영 + R4 재리뷰")

R3 3건 반영:
- HIGH-1 → transfer digest 계약 분리: 레이아웃/per-stage 마스크 digest 면제, **전역 어휘/head-시맨틱
  digest fail-closed**(스킬 사전 순서·트리거 어휘·격자 크기·at_frame bin).
- HIGH-2 → acceptance 2를 **seed별 독립 커맨드 ×3**으로 재작성(①S11 from-scratch → ②S12 transfer →
  ③S13 acceptance, seed→ckpt 명시).
- MED → 사슬 전 구간 공통 예산 pin(--envs 4 --max-episodes 20000 --max-wall 1800 --shaping trace
  --train-deadline 4500 --sil).

**Round 4 결과 — HIGH 0 · MEDIUM 1 → plan 내 처리 종결**
- R3 3건 전부 실질 해소 판정(H1 fixed with MED wording cleanup / H2 fixed / M fixed).
- [medium] acceptance 4의 verify-r2 문구("문법/레이아웃 digest 일치")가 P1 mode별 계약과 모순 →
  **mode별 digest 계약 명문**(exact=전부 일치 / transfer=레이아웃·마스크 면제+전역 어휘 digest
  fail-closed)으로 재작성, P1과 동일 문구 강제. **§R2 plan-stage 종결** (R1 11건 → R2 8건 → R3 3건 →
  R4 MED 1건 in-plan — 사용자 승인 user-extended cap 경로).

# §R3 (trace-refinement MDP: closed-loop 학습판) plan-review (2026-07-04)

> 대상 = auto-solver-plan.md `### R3 — trace-refinement MDP` 섹션. codex task-모드 적대 리뷰,
> 3-round cap(플랜 정책). 스코프 = 사용자 결정 "trace-refinement 우선, dense per-prefix는 내부 fallback".

## Round 1 (2026-07-04) — CRITICAL 0 · HIGH 5 · MEDIUM 4 · LOW 2

- **[high-1] 처리량 acceptance under-pin·wall-bound**: R3=L+1 롤아웃/에피소드인데 R2와 동일 20k/1800s
  pin. S13은 1롤에서도 ~3.5k eps/1800s(R1 로그) → R3는 wall 전 수백 에피소드만 돌 위험. plan이
  인지는 하나 acceptance predicate가 아님. → **처리량 floor 게이트**(최소 완료 에피소드/distinct-prefix
  롤아웃 도달 요구; 미달=“infra/throughput-pin invalid”≠model FAIL) + max-rollouts/distinct-prefix pin.
- **[high-2] memo 캐시 키 계약이 주장 대비 약함**: `rollout(P)`는 plan JSON뿐 아니라 stage/layout digest·
  grammar lowering·deadline·trace flag/schema·engine build에 의존 → “같은 prefix=같은 결과”는 전체 exec
  config 하에서만 참. on/off byte-identical 테스트는 좋으나 키 스키마 pin 없이는 불충분. → **memo_key =
  hash(stage_id, layout_digest, grammar/vocab_digest, train/replay deadline, trace 요청/schema digest,
  정규화 lowered plan, engine/protocol version)** 명문화 + resume 등가성은 --max-batches·wall-disabled로
  판정 명시(비직렬화 warm 캐시가 wall-limited 정지 행동 바꿈 차단).
- **[high-3] R3_PIN이 material obs 상수를 impl에 남김**: trace_channels가 “impl 확정”인데 verify-r3는
  material 계약으로 요구 → 모순. 누락 상수 = 채널 이름/순서·스칼라 순서·정규화/클리핑·밀도 분모·
  rasterize 좌표·dtype·absent-value 인코딩·obs-schema digest. → **R3_OBS_SCHEMA를 구현 전 pin**,
  verify-r3는 obs schema digest 불일치 fail-closed.
- **[high-4] dense potential이 정책-불변을 과대주장**: PBRS 불변은 base reward·γ·terminal potential
  관례·Markov state가 정의돼야 성립. plan이 γ·base clear 유지 여부·R1 terminal shaping 제거 여부·
  terminal φ zeroing 미pin. “가산 아님”도 부정확(PBRS는 base에 *더함* — 피해야 할 건 terminal φ와
  dense Δφ *둘 다* 더하기). → base=D4 terminal verdict 보상, dense=base+PBRS, dense 모드에선 R1
  terminal trace bonus 제거, γ pin, terminal φ=0 강제(또는 telescoping 상수 증명) + 결정론 telescoping
  단위테스트.
- **[high-5] fallback이 R3 결과를 silent 재스코프 가능**: acceptance 6이 primary FAIL 후 `--dense-shaping`
  켜고 R3_PIN을 같은 커밋에 갱신 → 후일 verify-r3가 dense를 통과시키는데 보고는 “trace-refinement
  primary 성공”으로 읽힐 위험. → **R3_PRIMARY_PIN / R3_DENSE_PIN 분리(불변)** + primary 실패 산출물
  검증 보존 + 결과 라벨 `primary`/`dense_fallback`/`ppo_fallback`(R1 impl R5 mode-필드 선례).
- **[medium-1] A/B 격리 과장**: “유일 차이=--refine”이나 --refine은 obs+상호작용+롤아웃수+memo+wall
  동역학을 바꿈. 성공은 closed-loop 가설을 지지하나 주장만큼 깔끔친 않음. → **blind-refinement 대조군**
  (동일 prefix 롤아웃·비용, trace 채널 zeroed/dummy)로 trace-정보 vs loop/cost 격리.
- **[medium-2] R2 산출물 서술 모호**: R3 선결이 “인증=stage11/12/19 rl/rl2.json”이라 했으나 R2 실측은
  stage12/13.rl2.json=실패 기록·인증은 stage11/19 rl2만. stage12는 R1 rl.json으로만 인증. → 정정:
  “인증 = R1 stage12.rl.json + R2 stage11/19.rl2.json; stage12/13.rl2.json=실패 기록”.
- **[medium-3] --memo CLI 미pin**: acceptance 3이 “--memo on/off 또는 --no-memo”라 모호, 스모크 커맨드에
  플래그 없음, train.py에 옵션 부재. → default-on + `--no-memo` 확정, 두 커맨드 명시.
- **[medium-4] S11/S12 refine 비회귀 약속했으나 acceptance 아님**: 리스크에만 있고 acceptance 5는
  기존 게이트/verify-r0/r1/r2만(=--refine 미실행). → 저비용 `--refine --stage 11/12` 스모크 acceptance
  편입 or 주장 삭제.
- **[low-1] “엔진/PlanRunner/env.py 무변경” 과절대**: closed-loop prefix 롤아웃·memo 토글·rasterize는
  최소한 RL env 오케스트레이션을 바꿈. → 불변식 축소: Godot gameplay/PlanRunner 시맨틱 무변경, Python
  RL env는 opt-in refine 오케스트레이션 가산 허용.
- **[low-2] “무비용에 가까움” 낙관적**: prefix 롤아웃은 이미 있으나 φ 계산·rasterize·캐시압·저장 비용
  존재. → “추가 Godot 롤아웃 없음”으로 표현.

→ 전 항목(HIGH 5 + MEDIUM 4 + LOW 2) §R3 v2 반영 → Round 2 재리뷰.

## Round 2 (2026-07-04) — CRITICAL 0 · HIGH 4 · MEDIUM 4 · LOW 1 (R1: M2/M3/L1/L2 해소·H2/H3/H4 부분·H1/H5/M1/M4 미해소)

- **[high-1] trace-blind 대조가 여전히 비게이트 → trace-정보 주장 false-green**: --refine 성공이 trace
  내용 아닌 loop/최적화 동역학/prefix-cost 때문일 수 있음. → **trace-blind를 pinned 대조 런**(동일 seed·
  예산·memo·floor)으로 승격 + 인과 가드: trace-blind도 ≥2/3 클리어하면 "trace 정보가 고원을 뚫었다" 주장
  금지·"refinement loop가 도움, trace-특정 인과 미증명"으로 relabel.
- **[high-2] 보상 정의 충돌 = R1 terminal shaping 이중계상**: primary `R_base + R1_terminal_shaping`인데
  `R_base`를 "D4 + R1 terminal trace-shaping"으로 정의(이중) + dense는 R_base를 D4-only로 씀 = live SoT
  충돌. → 명명 분리 `R_d4`; primary=`R_d4 + R1_terminal_shaping`; dense=`R_d4 + ΣF_t`; verify-r3가 primary
  shaping 1회·dense `R1_terminal_shaping=off` 강제.
- **[high-3] THROUGHPUT_FLOOR escape hatch + MIN_DISTINCT 미pin**: 반복 floor miss가 언제 설계 실패인지
  cap/retry 규칙 없음, MIN_DISTINCT="impl 확정". → MIN_DISTINCT 설계 내 pin + preflight 처리량 calibration +
  invalid 런 산출물 전량 보존 + **예산/pin 개정 최대 1회(명시 리뷰)** 후 미달이면 throughput-infeasible 분류.
- **[high-4] memo key가 cross-config stale 안전엔 여전히 부족**: inventory/hp·skill 메타·fixed-fps/SimConfig·
  capabilities·Godot script/project rev를 (layout_digest/engine_version에 숨지 않는 한) 명시 안 함. →
  **`exec_config_digest` 정의 + 멤버 전량 열거**(stage resource digest[inventory/hp]·skill ids/meta digest·
  fixed-fps·SimConfig·script/version digest·deadlines·trace request/schema·정규화 plan).
- **[medium-1] R3_OBS_SCHEMA 잔여 material 갭**: "max_len_frames 등"(등 금지)·verdict_code 숫자 enum 미pin.
  → "등" 삭제·분모 전량 열거·verdict_code enum 매핑 pin·obs_schema_digest 포함.
- **[medium-2] 재개 등가성 memo 직렬화가 impl 결정으로 남음**: "캐시 재구성 또는 ckpt 동봉 — impl 확정".
  치명 아님(acceptance 3이 memo-on/off byte 동일 요구)이나 resume 행동 미명세. → **택1: memo 미직렬화+결정론
  재구성**(채택) → resume를 warm·cold memo 양쪽서 검증.
- **[medium-3] S11/S12 비회귀 절반만**: S11 스모크만·S12 optional. S12는 R1 성공 사례라 silent 퇴행 위험.
  → **bounded S12 refine 스모크 추가**(작아도).
- **[medium-4] PPO fallback = dead/리뷰불가 브랜치**: R3_PPO_PIN "승격 시" 확정 = 리뷰 가능 pin 아님. →
  **PPO를 별도 plan-review 라운드 전까지 out-of-scope 선언**(dead 브랜치 제거 — dense도 FAIL이면 사용자
  escalate로 새 plan).
- **[low-1] dense PBRS terminal 처리가 SUBMIT만 언급**: 인벤토리 소진·max_len·timeout/실패·clear 조기
  terminal도 φ(terminal)=0 강제해야. → terminal 잠재 0을 모든 terminal 원인으로 정의.

→ 전 항목(HIGH 4 + MEDIUM 4 + LOW 1) §R3 v3 반영 → Round 3(최종·3-round cap) 재리뷰.

## Round 3 (2026-07-04) — CRITICAL 0 · HIGH 2 · MEDIUM 3 · LOW 2 → **정책상 STOP·사용자 보고** (3-round cap)

R2 fix 검증: H2/M1/M2/M3/L1 resolved · H1 mostly(MED outcome-label 잔여) · M4 mostly(stale PPO 텍스트) ·
**H3/H4 미완**(아래 2 HIGH). "fixes가 만든 경계 갭, 반복 아님" 판정.

- **[high-1] `exec_config_digest`가 rollout-영향 입력을 여전히 과소명세**: `stage_resource_digest(레이아웃+
  인벤토리+hp)`가 subset — spawn schedule/count·spawn points·stage timeout/objectives·per-entity config·
  resource deps·Godot 바이너리/헤드리스 호출이 밖. 이 키가 memoized `rollout(P)`를 게이트하므로 stale
  hit이 trace·보상·D4 replay를 오염. → `stage_resource_digest`를 **canonical full runtime stage snapshot
  (스테이지 리소스+deps 전체 content hash)**로 정의(subset 금지) + verify-r3 음성(각 runtime 필드 변경이
  memo key 무효화).
- **[high-2] `MIN_DISTINCT` pin 불일치**: acceptance는 `1500`인데 R3_PRIMARY_PIN은 `impl-pin` — R2-H3가
  닫으려던 arbitrary-floor escape 재개방. → 전 R3 pin 정의(dense 포함)에서 `impl-pin`→`1500` + verify-r3가
  다른 값이면(리뷰된 plan 개정 없이) FAIL.
- **[medium-1] trace-blind 인과 가드가 top-level PASS 오독 여지**: trace-blind도 클리어 시 `trace_causal=
  unproven` relabel은 되나 R3 "PASS"가 trace 증거로 오독될 수 있음. → outcome 라벨 분리: `r3_mechanical_pass`
  (trace-full 성공) vs `trace_causal_pass`(trace-full 성공 ∧ 양 대조 실패).
- **[medium-2] `throughput-infeasible`가 1급 terminal 산출물로 미pin**: 분류로만 서술. → manifest outcome
  enum `throughput-infeasible`·`budget_revisions=1`·preflight/런 산출물 보존·verify-r3가 infra terminal로만
  수용(model FAIL/success 아님) 강제.
- **[medium-3] dense pin이 `R3_PRIMARY_PIN ∪ dense_shaping=true`라 shaping 상속 모호**(primary는
  `shaping="trace"` 포함). → `R3_DENSE_PIN` 독립 정의(`shaping="none"`+`dense_shaping=true` 또는 dense가
  terminal trace shaping을 override·reject 명시).
- **[low-1] 개요(STATUS 앞) R2를 현 설계 타깃으로 서술** — R3 확정과 불일치(경미, 문서 상단).
- **[low-2] 레거시 리스크 텍스트 "PPO 승격 경로 사전 명시"가 R3 out-of-scope와 충돌**.

**정책 판정**: 3-round cap Round 3에서 HIGH 2 → **즉시 STOP·사용자 보고**(CLAUDE.md plan-stage 정책).
두 HIGH 모두 수렴적·기계적(H2=consistency 슬립, H1=digest scope 강화, fix 방향 자명). 사용자 결정 대기
(수정 방향·범위·취소). §R2 선례 = "3건 반영 + R4 user-extended cap".

## Round 4 (2026-07-04, user-extended cap — 사용자 승인 "7건 반영 + R4 재리뷰")

Round 3 7건(HIGH 2 + MEDIUM 3 + LOW 2) v4 반영:
- HIGH-1 → `stage_resource_digest` = canonical full runtime stage snapshot content hash(subset 금지;
  spawn schedule/count/points·timeout/objectives·per-entity·deps 전체) + verify-r3 runtime-필드 음성.
- HIGH-2 → `MIN_DISTINCT=1500`을 전 R3 pin(primary/dense)에 일관 pin, verify-r3가 타 값 거부.
- MED-1 → outcome 라벨 2분(`r3_mechanical_pass` = trace-full 클리어 / `trace_causal_pass` = ∧ 양 대조 실패).
- MED-2 → `throughput-infeasible` 1급 manifest outcome enum(+budget_revisions≤1) + verify-r3 infra-terminal 수용.
- MED-3 → `R3_DENSE_PIN` 독립 정의(`shaping="none"`+`dense_shaping=true`, verify-r3가 dense shaping="trace" 거부).
- LOW-1 → 개요 R2 완료·R3 설계 대상으로 갱신 / LOW-2 → 레거시 리스크 PPO 문구 R3 out-of-scope 정합.

→ Round 4 codex 재리뷰 대기.

**Round 4 결과 — CRITICAL/HIGH 0 · LOW 2 → plan 내 처리 종결**
- Round 3 7건 전부 실질 해소 확인(H1 full-snapshot digest — over-broad invalidation은 per-run distinct-prefix
  memo 비용 논증 무해로 수용 / H2 MIN_DISTINCT=1500 floor·primary·dense 일관 / M1 라벨 분리로 overclaim 차단 /
  M2 throughput-infeasible 1급 terminal / M3 R3_DENSE_PIN 독립·shaping="none" / L1·L2 정합).
- [low-1] verify-r3 outcome 분기(pass=predicate/replay · model_fail=floor∧미달 · throughput-* = pass replay
  스킵+산출물 요구) 명시 → 반영. [low-2] `trace_causal_pass=false`+`trace_causal_reason` 스키마 명명 일관 → 반영.
- **§R3 plan-stage 종결** (R1 11건 → R2 9건 → R3 7건[STOP·사용자 승인] → R4 CRITICAL/HIGH 0·LOW 2 in-plan —
  사용자 승인 user-extended cap 경로, §R2 선례 동일). 다음 = **R3 구현**(사용자 go 대기).

# §R4 (타일-의미 계층 + 좌표-불변 랜드마크 표현) plan-review (2026-07-10)

> 대상: plan SoT §R4(R4a 타일-의미 계층 / R4b 랜드마크 문법 r4.0) + 로드맵 R4 확정 항목.
> 리뷰어: codex task-모드(read-only). 정책: plan-stage 3-round cap.

## Round 1 — needs-attention (C1 + H4 + M3 + L1)

**CRITICAL**
- **C1 — acceptance 2 fail-open**: "median ≥50% 감소 **또는** 클리어율 증가"는 n=2에서 너무 약함
  (r4 scratch 0/2 + xfer 1/2 = scratch 퇴행+우연 1회가 PASS로 위장; §13.5 자신이 n=2 혼합을 무전이로
  해석한 기준보다 느슨). DNF median 산식(cap 대입 여부)도 미pin.

**HIGH**
- **H1 — impl-pin loophole 재도입**: "세부 상수 pin은 impl 커밋 동봉"이 material constant escape
  hatch(§R1~R3 리뷰의 핵심 severity bar 위반). envs/max-wall/cap/at_frame quant/candidate cap/
  pointer dtype/DNF 산식/소스 ckpt 예산 등이 미pin.
- **H2 — 커버리지 FAIL 처리 ↔ hybrid rung 내부 모순**: coverage FAIL(=r4.0이 known 해 표현 불가) 직후
  절대좌표 r4.1로 진행 가능하면 "landmark 표현 검증" 목적 자체가 무효화. S12 해는 at_frame·절대
  y-band 기반이라 갭 리스크 실재.
- **H3 — "하드코딩 0" ↔ kind 어휘 3계 충돌**: layout kind(solid/plant/…) ↔ 엔진 _cell_kind(earth/
  plant) ↔ 스킬 판정(basher=earth, cutter=plant)이 서로 다른 어휘 — canonical alias table 미정의면
  메타가 서로 다른 언어를 말함.
- **H4 — candidate cap이 리스크에만 존재**: 후보 상한은 pointer 분포·파밍·커버리지·재개 등가성을
  전부 바꾸는 material constant인데 숫자·절단 키·검증 없음.

**MEDIUM**
- **M1 — "좌표 불변" 과장**: dist/drop_height 피처는 레이아웃별 절대 기하 파생 — 정확한 주장은
  "절대 head 제거 + geometry-정규화 pointer"이고 전이 개선은 실측(ⓑ vs ⓓ)으로만 성립.
- **M2 — KnowledgeLedger overclaim**: transfer 시 ledger 리셋 유지인데 "스테이지-불문 의미 토큰"
  서술은 cross-stage 이득처럼 읽힘 — 실체는 per-stage 토큰의 형식 개선.
- **M3 — C_layout=8 ↔ "전수 스캔 파생" 계약 모호**: 동적 파생이면 새 kind에 ckpt shape가 흔들리고,
  8 고정이면 스캔 결과의 하드 pin — 어느 쪽인지 명시 필요.

**LOW**
- **L1 — background 처리 "구현 시 검증" 유예**: parse_layout이 tile_map 전 항목 occupied 처리는
  현행 사실이고 background가 tile_map에 실존(전수 스캔 실측) — 지금 pin 가능한 것을 유예.

**조치(전건 plan 반영, v2)**:
- C1 → predicate AND 결합(클리어 seed 수 ≥ ∧ paired median ≤0.5 ∧ ⓑ 무전이 재확인) + DNF=cap 대입
  pin + 클리어율만 증가는 `r4_transfer_reachability_pass` 별도 라벨(PASS 집계 금지).
- H1/H4 → `R4_PIN` 블록 신설(grammar 리터럴·landmark_schema_digest·C_layout=8·dtype float32·
  `LANDMARK_CANDIDATE_CAP=64`(+절단 회계·known-해 후보 소실 FAIL)·at_frame 300f·deadline 4500/7000·
  레시피(trace{0.5,0.1}·sil(8,0.1)·blocker/knowledge-coef 1.0·envs 4·max_len 8)·예산(cap 120 batch·
  wall 3600/arm·소스 ckpt 20000eps/1800s)·DNF 산식) — "impl 확정" 문구 제거, R4_PIN이 유일 상수 출처.
- H2 → coverage FAIL = 즉시 STOP·사용자 보고(우회 금지). hybrid r4.1은 acceptance 경로에서 제거 —
  "R4 FAIL 후 별도 plan-review 대상"으로만 존치, 결과는 `hybrid_absolute_escape_pass` 별도 라벨.
- H3 → canonical kind alias table(엔진 덤프 생성·타일 메타 digest 결속: solid→earth·cookie→
  non-breakable·sand_mound→climbable) + TileMetadataDriftTest가 alias 왕복(layout kind ⊆ alias ⊆
  엔진 어휘·스킬 판정 상수 대조) 검증.
- M1 → 주장 격하("절대 좌표 head 제거 + geometry-정규화 피처 pointer") + 산출물 라벨
  `landmark-relative`(coordinate-invariant 금지) + 전이 주장은 acceptance 2 실측으로만.
- M2 → "스테이지-불문 *형식*의 per-stage 토큰"으로 정정, cross-stage 이월 = 별도 plan-review.
- M3 → C_layout=8 하드 pin 명시(전수 스캔 = 어휘 도출 절차, 런타임 동적 아님) + 미지 kind
  fail-closed + 새 kind는 r4.x schema 승격(ckpt 버전 상승)으로만.
- L1 → background=tile_map 실존(실측) + parse_layout occupied 오분류 = 선존 결함 확정 명시. 정정은
  r4 경로 한정(opt-in 파서 파라미터), 레거시 경로 byte-identical 유지(y_rows vocab·pinned 산출물
  보호).

→ Round 2 codex 재리뷰.

## Round 2 — needs-attention (신규 H2 + M2 + L1; R1 재검증 C1/H3/H4/M2/M3/L1 RESOLVED, H1/H2/M1 PARTIAL)

**R1 재검증**: C1(AND predicate)·H3(alias table)·H4(candidate cap)·M2(ledger 격하)·M3(8ch 하드 pin)·
L1(background 확정) RESOLVED / H1·H2·M1 PARTIAL(아래 신규로 승계).

**신규 HIGH**
- **H5 — S13 r4 소스 ckpt under-pin(H1 승계)**: 소스 학습 커맨드에 grammar/envs/shaping/sil/coef/
  deadline/max_len/--save-ckpt 누락 + seed→ckpt 매핑·소스 실패 분류 부재 = 실행 불가능 수준.
- **H6 — knowledge-coef 내부 상수 미결속(H1 승계)**: KNOWLEDGE={0.05,0.02,cap50}·토큰화(필드 단위)·
  시행착오 정의(프런티어)·SIL 재평가·ledger resume/transfer 규칙이 material인데 R4_PIN 밖.

**신규 MEDIUM**
- **M4 — 리스크 절에 "hybrid r4.1 rung" 잔존(H2 승계)**: 본문은 제거했는데 리스크 완화책 목록에
  rung으로 재등장 — 용어 불일치.
- **M5 — "known 해 전수" 과장**: repo에 stage23/24.witness.json이 실존하는데 커버리지 대상(S11~S17+
  S19)은 subset — "전수" 명명이 corpus와 충돌.

**신규 LOW**
- **L2 — STATUS tail 미동기화**: R4 plan-stage 진입이 STATUS에 없음.

**+ M1 잔존**: 제목·로드맵의 "좌표-불변" 표현.

**조치(전건 반영, v3)**:
- H5 → R4_PIN에 소스 커맨드 전량 pin(`--grammar r4.0 --stage 13 --seeds 0,2 --envs 4
  --max-episodes 20000 --max-wall 1800 --shaping trace --train-deadline 4500 --sil --blocker-coef 1.0
  --knowledge-coef 1.0 --max-len 8 --save-ckpt --no-save`) + 산출 경로 `stage13_seed{s}.r4.pt` +
  seed 매핑 고정(cross-seed 금지, verify-r4 ckpt seed 메타 대조) + `source-unavailable`(infra) 분류
  (양 seed 실패 = infra FAIL·escalate, model FAIL 아님).
- H6 → `knowledge_contract_digest`(KNOWLEDGE 상수+토큰화+시행착오 정의+SIL 재평가+ledger 규칙) +
  `blocker_contract_digest`(redirect_value 귀속+정규화) 신설, 산출물·ckpt 동승 + verify-r4
  fail-closed.
- M4 → 리스크 절에서 rung 삭제("완화책 아님 — R4 FAIL 후 별도 plan-review 후보" 통일 서술).
- M5 → "R4 커버리지 subset"으로 명명 격하 + witness 2종 명시 제외·사유(Phase 5 stretch 수기 needle)
  + 비게이트 인코딩-가능성 탐사로 박제.
- L2 → STATUS.md tail에 §R4 plan-stage 항목 추가(동기화).
- M1 잔존 → 제목 "타일-의미 계층 + 랜드마크-상대 표현(절대-좌표 head 제거·추상 전이 실험)"으로
  개명 + 로드맵 동일 + 명명 정정 배너.

→ Round 3 codex 재리뷰(최종 — 3-round cap: HIGH 잔존 시 STOP·사용자 보고).

## Round 3 — **approve** (§R4 plan-stage 종결)

- Round 2 전건 RESOLVED 확인(H5 소스 커맨드·seed 매핑·source-unavailable / H6 knowledge·blocker
  contract digest — brain 로그 §14.4 상수와 일치 확인 / M4 rung 문구 통일 / M5 커버리지 subset 명명
  +witness 제외 사유 / L2 STATUS 동기화 / M1 잔존 제목 개명).
- 신규 CRITICAL/HIGH/MEDIUM/LOW: 0.
- **§R4 plan-stage 종결**(R1 needs-attention C1+H4+M3+L1 → R2 needs-attention H2+M2+L1 →
  R3 approve — 3-round cap 내 종결, §R1 선례 동일 경로). 다음 = **R4 구현**(사용자 go 대기).
