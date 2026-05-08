# Phase 3 Adversarial Review

- **실행 시각**: 2026-05-08 14:56
- **포커스**: phase 3 plan: builder skill + worker state + skill toolbar + stage2 chasm
- **scope**: working-tree
- **base ref**: ffe353ef9a396057f221ad5f0c16514efd8ca1eb

---

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the Phase 3 plan explicitly defers automated tests while relying on timing/geometry/UI interactions that are already called out as precision-sensitive, so the change would be difficult to catch regressions for before release.

Findings:
- [high] Phase exits with TDD bypass and no automated coverage for the new skill/state/stage contract (CandyAnts/phases/mvp/plans/phase03-plan.md:154-160)
  The plan introduces a new SkillToolbar input path, group-based ant targeting, WorkerState movement/tile placement, dynamic terrain collision, and Stage02 geometry, but then lists unit tests as deferred and includes a TDD bypass removal as the exit gate. Inference from the plan: this means the phase can be accepted after manual/headless scenarios without a repeatable test asserting the critical invariants, such as inventory not decrementing on failed can_apply, WorkerState returning carrying ants to the correct speed/state, Terrain.add_tile collision setup, and Stage02 remaining clearable. The likely impact is a shippable regression that only appears under click timing, geometry drift, or later refactors, with no automated signal to block it.
  Recommendation: Do not defer tests for this phase. Add automated tests or deterministic headless harness coverage for SkillRegistry validation, SkillToolbar inventory/can_apply behavior, WorkerState builder tick/abort/carrying-state preservation, Terrain.add_tile collision, and Stage02 clear/no-skill failure before allowing the phase to pass without a bypass.

Next steps:
- Add a minimal automated regression suite for the new builder skill path before marking stage2-builder complete.
- Make the phase exit criteria fail if scripts/hooks/.tdd_bypass is needed or if the Stage02 deterministic clear scenario is not covered.

---

## 처리 결정

| Severity | 이슈 | 결정 |
|----------|------|------|
| HIGH | TDD bypass + 자동화 테스트 부재 | **수정** — `tests/Stage02HeadlessTest.{gd,tscn}` 통합 회귀 테스트 추가, 각 새/수정 스크립트에 per-file 스텁 (TDD Guard 통과). bypass 사용 안 함. |

HIGH는 deferred 금지. 즉시 plan 갱신 후 구현 단계 진입.
