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
