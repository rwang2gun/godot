# Phase 4 (전술 라이브러리 CBR/EBL) — Plan-stage 적대적 리뷰

> 정책: plan stage = 최대 2회 수정+재리뷰 (3-round cap). Round 3 HIGH 시 STOP·사용자 보고.
> 대상: `CandyAnts/phases/solver/auto-solver-plan.md` Phase 4 절 (working-tree diff).

## Round 1

Target: working tree diff
Verdict: **needs-attention**

No-ship: the Phase 4 plan promotes a falsifiability claim that its own proposed integration can invalidate, and it leaves the core lifting/measurement contracts undefined enough that transfer results could look green without proving reusable tactics.

Findings:
- **[high] Seed bonus injection can contaminate the rollout baseline the phase is supposed to measure** (auto-solver-plan.md:356-375)
  The plan says CBR will be integrated by adding seed bonuses into `model.propose()`'s existing `_w` weighting, while the gate measures ON/OFF rollout counts. That makes the metric fragile: unless the plan requires an isolated baseline path with identical candidate generation except for tactics, a lower rollout count can come from distorted ranking or changed heuristic interaction rather than transferable tactics. The same integration also risks hiding false-green behavior because seeded candidates are mixed into normal ranking instead of being tracked as a separate source with separate success/failure accounting.
  Recommendation: define an A/B harness that runs the exact same solver/model path with tactics fully disabled for OFF, tactics isolated and attributed for ON, and reports seeded-candidate attempts, seeded successes, fallback successes, and rollout counts separately.
- **[high] False-green is asserted but not operationally defined for transfer-bench** (auto-solver-plan.md:367-379)
  Engine validation only proves a final solve is valid; it does not prove the solve came from the transferred tactic, nor that the benchmark did not fall back to ordinary search after failed seeds. A benchmark can pass by finding a valid S12/S13 solution with fewer rollouts due to ordinary heuristic variance, cache/library ordering, or partial fallback, without validating the CBR transfer hypothesis.
  Recommendation: block on explicit attribution criteria: transfer-bench should fail unless the accepted solution contains the seeded tactic/subgoal binding, records no un-attributed fallback success as transfer success, and compares repeated deterministic OFF/ON runs under identical seeds and budgets.
- **[medium] The tactic lifting model is underspecified against the existing action schema** (auto-solver-plan.md:361-372)
  From `{skill, target, trigger}` alone, the plan does not define which frame of reference owns the local features, how multi-step timing anchors survive layout changes, how a specific ant identity is removed, or what makes a relative placement binding valid on S12/S13. Two implementations could both satisfy the plan while producing incompatible libraries or silently overfitting S11 coords.
  Recommendation: define the lifting contract in the plan: enumerate allowed local feature anchors, coordinate transforms, ant/slot binding rules, timing-anchor semantics, and rejection conditions when an action cannot be lifted unambiguously.

Next steps:
- Resolve the measurement and attribution contract before treating 4a as a real de-risk.
- Define the tactic lifting schema tightly enough that transfer-bench can validate what was transferred, not just that a solve exists.

### 대응 (R1 → 수정) [원래 plan에 반영, 아래 R2에서 HIGH-1만 provenance로 추가 강화]
세 finding 모두 plan에 반영(MEDIUM 포함 — 핵심 산출물 모호성이라 cheap-to-specify):
1. (HIGH) A/B 하니스 명세: OFF=tactics 완전 비활성·동일 경로, ON=tactics 격리·귀속. seeded 시도/성공·fallback 성공·롤아웃 수 **별도 계측**. 동일 seed·budget 결정론 반복.
2. (HIGH) transfer-bench 귀속 기준: 채택 해가 **seeded 전술/서브골 바인딩을 포함**해야만 전이 성공으로 카운트. un-attributed fallback 성공은 전이 성공 불가. 미충족 시 fail.
3. (MEDIUM) 리프팅 계약 명세: 허용 국소 앵커·좌표 변환·개미/슬롯 바인딩 규칙·타이밍앵커 의미·리프팅 불가 시 거부 조건.

## Round 2

Target: working tree diff
Verdict: **needs-attention**

No-ship: the revised plan closes the Round 1 baseline/false-green/lifting gaps in wording, but the attribution gate still cannot prove the accepted solve was caused by the seeded tactic rather than merely containing the same binding after ON-path ranking perturbation or fallback search.

Findings:
- **[high] Attribution criterion can still false-green on coincidental seeded-binding overlap** (auto-solver-plan.md:359-382)
  Transfer success defined as "accepted solution contains the seeded binding" (content-based) is weaker than provenance: an ON run can try a seed, fail or only perturb ranking, then ordinary fallback search finds a valid solution that happens to include the same tactic-shaped binding — satisfying "rollout reduction AND seeded binding included" without a transferred tactic. transfer-bench can still certify CBR transfer without proving it.
  Recommendation: make attribution **provenance-based**: the accepted solve must be generated from a seeded candidate/source tag for the decisive steps; fallback-origin candidates fail transfer attribution even if they contain the same binding; markers must distinguish seeded-origin accepted solves from fallback-origin accepted solves.

Next steps:
- Revise the Measurement/Attribution Contract before implementation; the Round 1 lifting concern appears materially closed by the new lifting contract.

### 대응 (R2 → 수정)
- (HIGH-1) 귀속을 **content-based → provenance-based**로 전환: 채택 해의 *결정적 액션*이 **seeded source-tag에서 생성**돼야만 전이 성공. 같은 모양 바인딩이라도 fallback-origin이면 전이 실패로 회계. 마커가 seeded-origin 채택 vs fallback-origin 채택을 구별. (리프팅 MEDIUM은 R2에서 "materially closed" 확인 — 추가 수정 없음.)

## Round 3 (최종)

Target: working tree diff
Verdict: **approve**

No-ship issue from Round 2 appears closed: the plan now requires generation-time source tags, seeded-origin provenance on the accepted decisive tactic action, fallback-origin failures even on identical bindings, distinct markers, and a gate requiring both rollout reduction and seeded-origin attribution. No remaining defensible HIGH.

No material findings.

---

### 종결 (boost 설계)
- **R1**(needs-attention: HIGH×2 + MEDIUM×1) → R2(needs-attention: HIGH×1, 리프팅 closed) → **R3 approve (HIGH 0)**. 3-round cap 내 종결.
- plan-stage 리뷰 통과 → Phase 4 구현(Step 4a de-risk부터) 진입.

---

# 재설계 re-review (boost falsified → 볼트-pruning)

> 4a de-risk 실측이 boost를 falsify(S12 OFF=ON=8롤, NO-TRANSFER). 사용자 결정으로 Obsidian 지식 볼트 +
> 위기-인덱스 pruning으로 재설계. 메커니즘·귀속이 바뀌어 plan-stage 적대적 리뷰 재실행(새 3-round cap).

## 재설계 Round 1

Target: working tree diff
Verdict: **needs-attention**

No-ship: pruning 규칙의 안전성·귀속이 미확립이고, plan에 구식 seed-provenance 게이트가 잔존.

Findings:
- **[high] Vault pruning이 미지 스테이지에서 유일 viable 후보 삭제 가능** (knowledge.py:vault_prune)
  off>=1 물-가장자리 reverse 후보를 전역 hard-drop — off=0 근거는 stage11/12뿐, lead time/천장/기하가 off>=1을
  요구하는 스테이지를 ON에서 풀지 못하게 할 수 있음. "OFF는 안전"은 메커니즘이 *비활성일 때만* 안전하다는 뜻.
  → fail-open(ON 정체 시 prune 형제 복원) 또는 학습된 local predicate 전까지 hard-prune 금지. held-out 검증.
- **[high] Same-solution 귀속이 overfit pruning을 false-green** (try_solve.py transfer-bench)
  "ON 클리어+롤아웃<OFF+동일 final_plan+pruned>0"은 *건너뛰고 같은 답 도달*만 증명, *건너뛴 형제가 비-유효*임은
  증명 안 함. → prune된 각 후보를 반사실 분류(미클리어/strictly worse)로 검증 + held-out. same_solution+pruned는
  '전이'가 아니라 '최적화' 증거로 취급.
- **[medium] plan에 구식 seed-provenance 게이트 잔존** (auto-solver-plan.md measurement/4a/gate/acceptance)
  재설계 subsection은 vault 귀속인데 measurement/4a/gate/acceptance는 여전히 seeded-origin 요구 — 호환 불가 완료기준
  2개 공존. → 해당 절을 vault 메커니즘으로 재작성, 구 seed 계약은 historical로 격리.
- **[medium] crisis 검출이 solver 훅에서 retired/trapped 누락** (solve.py vault_fn 호출)
  detect_crises는 count_retired.fall/water·count_trapped.carry에도 발화하나, 훅은 `vault_fn(d, cands)`만 전달 →
  reverse_target.to_water 외 위기 미발화. → retired/trapped를 vault_fn에 전달 + 실-훅 검출 selftest.

### 대응 (R1 → 수정)
4건 모두 반영:
1. (HIGH) **fail-open pruning**: solve 정체 시 vault OFF로 재propose해 prune 형제 복원 → ON 완전성 ≥ OFF(해 손실 0).
2. (HIGH) **반사실 귀속**: OFF tried_log·ON pruned_log 기록 → prune된 각 후보가 OFF에서 미클리어였음 확인(pruning_justified). 게이트에 편입.
3. (MEDIUM) plan measurement/4a/gate/acceptance를 vault 기준 재작성, 구 seed는 historical 격리.
4. (MEDIUM) retired/trapped를 vault_fn에 전달 + knowledge selftest에 실-훅 검출 케이스.

## 재설계 Round 2

Target: working tree diff
Verdict: **needs-attention**

No-ship: vault 경로가 완전성·crisis-hook 보장을 아직 미구현.

Findings:
- **[high] fail-open이 pruning이 후보를 0개로 만든 라운드에서 우회됨** (solve.py)
  `_propose(use_vault=True)`가 빈 cands를 내거나 eval이 비면 즉시 break — fail-open(use_vault=False 복원)은 *평가
  후 미개선*일 때만 발동. off=0이 이미 tried/채택돼 capped pool이 prune되는 off>=1뿐인 라운드에서 ON은 멈추는데
  OFF는 그 형제를 평가 → 완전성 주장 위배.
  → cands/eval이 비어도 fail-open 발동(break 전에 복원).
- **[medium] LA2에서 vault crisis 검출이 stale trace(best) 사용** (solve.py _propose)
  diag1은 res1 trace에서 나오는데 retired/trapped는 best.trace에서 계산 → retired/trapped-only 위기가 잘못된
  맥락으로 발화. carry-timing 등 향후 factor에서 문제.
  → 진단을 만든 결과(src_res)를 _propose에 넘겨 retired/trapped를 같은 trace에서 계산.

### 대응 (R2 → 수정)
1. (HIGH) **fail-open #1 추가**: `evaluated`가 비면(빈 cands 포함) break 전에 vault OFF 재propose·평가. 기존 미개선
   분기는 fail-open #2로 유지 → 빈-라운드·정체 둘 다 형제 복원 = ON 완전성 >= OFF.
2. (MEDIUM) `_propose(d, cap, base, src_res, use_vault)` — src_res(진단 출처 결과)의 trace로 retired/trapped 계산.
   main=best, LA2=res1. (실-훅 retired/trapped 발화는 knowledge selftest로 단위 보장 + 벤치로 통합 행사.)

재측정: S12 8→4·S13 26→22, same해·justified·TRANSFER-OK 유지. selftest 16/16 PASS.

## 재설계 Round 3 (최종 — 3-round cap)

Target: working tree diff
Verdict: **needs-attention** (HIGH 1)

빈-라운드 fail-open·src_res trace 스레딩은 닫혔으나, **완전성 보장이 모든 pruning 경로에서 성립 안 함**.

Findings:
- **[high] 개선하는 후보를 채택하기 전에 prune된 형제를 여전히 건너뜀** (solve.py)
  복원 경로는 pruned 집합이 비거나 미개선일 때만 발동. **surviving off=0이 best를 개선하면 즉시 commit·continue**
  → OFF가 같은 base에서 평가했을 off>=1 형제(클리어/더 나은 분기일 수 있음)를 ON은 안 봄. "ON ⊇ OFF" 불변식 위배.
  LA2 second-step pool에도 빈/정체 fail-open 없음.
  → commit 전 unpruned pool을 같은 base로 평가하거나, prune 형제가 surviving 개선 후보를 못 이김을 증명·강제. LA2도 동일.

### 정책 발동 — STOP·사용자 결정
CLAUDE.md plan-stage: **Round 3 HIGH 1건이라도 → 즉시 중단, 사용자에게 보고. 사용자가 수정 방향·범위·취소 결정.**
모델 임의 4차 수정 금지. (R1 HIGH×2+MED×2 → R2 HIGH×1+MED×1 → R3 HIGH×1.)

**작성자 평가(보고용)**: HIGH는 *production 완전성 주장*의 과대표현을 지적 — 정확. 단 **측정된 de-risk 결과(S12/S13)는 건전**:
벤치 게이트가 `same_solution`(pruning이 해를 바꾸면 NO-TRANSFER) + `pruning_justified`(prune 형제가 OFF서 미클리어)
를 요구하므로, "off>=1이 더 나았다면 same_solution=False로 걸러짐". 즉 결함은 **plan prose의 'ON 완전성 >= OFF'**가
코드가 보장 못 하는 강한 주장이라는 점. vault-pruning은 *완전성 보존 변환*이 아니라 **per-stage 벤치로 검증되는
휴리스틱 최적화**로 재기술해야 정확. 해결 방향은 사용자 결정 대기(아래 옵션).
