# Phase 04 Implementation Adversarial Review

- **실행 시각**: 2026-05-08 (post-commit 사후 리뷰)
- **명령**: `/codex:adversarial-review --base HEAD~1 --scope branch --background "phase 4 stage3-blocker: Blocker 스킬의 충돌·방향전환 결정성, AntSpawner 양방향 라운드로빈 타이밍, WorkerState/Faller 전이 일관성, 스킬 등록 계약(SkillRegistry.SKILL_SCRIPTS)"`
- **scope**: branch (HEAD~1 → HEAD)
- **base ref**: ec9d43c (phase 3: stage2-builder)
- **head ref**: 4478fb0 (phase 4: stage3-blocker)
- **verdict**: needs-attention

---

# Codex Adversarial Review

Target: branch diff against HEAD~1
Verdict: needs-attention

No-ship: blocker redirection can become nondeterministic under real frame timing, making the Stage 3 blocker fail exactly when the simulation is stressed.

Findings:
- [high] Blocker bounce uses post-overlap position instead of incoming direction (CandyAnts/scripts/ant/Ant.gd:66-67)
  `_on_blocker_body_entered` decides the ant's new direction from `other.global_position.x - global_position.x`. That is only deterministic if the ant is still on the entry side when the Area2D signal is handled. Under a large physics delta, speed change, or deep initial overlap after enabling the blocker, the ant can already be past the blocker center when this runs; the code then sets the direction away from the post-penetration side, which can preserve the ant's original travel direction and let it pass through the blocker. This directly weakens the stage3 blocker guarantee and is hard to catch because the current headless test only covers the normal timing path.
  Recommendation: Derive the bounce from the incoming movement direction, e.g. `other.direction = -signi(other.direction)` or `-sign(other.velocity.x)`, and optionally snap/separate the ant just outside the hitbox so remaining overlap cannot re-enter or tunnel through on the next frame. Add a regression test that applies a blocker while another ant is already overlapping or crosses the hitbox center in one physics tick.

Next steps:
- Fix blocker redirection to use incoming direction/velocity rather than current relative position.
- Add a stressed collision test for overlap-on-activation and large-delta crossing.

---

## Round 2

- **실행 시각**: 2026-05-08 (sweep fix v1)
- **명령**: `/codex:adversarial-review --scope working-tree --background "phase 4 sweep round2: blocker bounce 결정성 수정 + BlockerOverlapTest 회귀 추가, 가이드라인 보강"`
- **scope**: working-tree (uncommitted fix v1: `-other.direction` 단순 반전)
- **verdict**: needs-attention

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the blocker fix trades the old deep-overlap bug for a non-idempotent bounce path that can fail when more than one blocker signal is delivered for the same ant.

Findings:
- [high] Blocker bounce is no longer idempotent under duplicate blocker contacts (CandyAnts/scripts/ant/Ant.gd:69)
  The handler now blindly flips `other.direction`. That fixes a single deep-overlap event, but it reintroduces the exact double-bump hazard the previous absolute assignment avoided. Because `BlockerSkill.can_apply()` does not enforce spacing or a single active blocker, a walker can overlap two blocker hitboxes, or receive repeated blocker contact delivery in one physics frame; two calls to this handler flip twice and leave the ant moving in its original direction, so it can pass through the blocker setup. The new regression only calls the handler once per case, so this failure mode is not covered.
  Recommendation: Make blocker redirection idempotent per contact frame, e.g. store the last blocker-bounce physics frame/body on the ant and ignore additional blocker bounces in that frame, or derive and persist an incoming direction before any blocker handler mutates it. Add a regression with two active blockers or two same-frame handler deliveries proving the ant is not flipped back to its original direction.

Next steps:
- Add a duplicate-contact regression to BlockerOverlapTest before shipping.
- Rework `_on_blocker_body_entered` so repeated blocker delivery cannot cancel the bounce.

---

## Round 3 (retry — round 3 첫 시도는 codex sandbox가 read-only 명령을 거부해 ungrounded 무효 결과)

- **실행 시각**: 2026-05-08 (sweep fix v2)
- **명령**: `/codex:adversarial-review --scope working-tree --background "phase 4 sweep round3 retry: per-physics-frame guard로 dual-blocker 동시 발화 idempotent 보장. §B-5 회귀 추가"`
- **scope**: working-tree (uncommitted fix v2: per-frame guard + direction reversal)
- **verdict**: approve ✅

# Codex Adversarial Review

Target: working tree diff
Verdict: approve

No defensible blocker found in the inspected working-tree diff. The new guard is stored on the moving ant, keyed to `Engine.get_physics_frames()`, and prevents same-frame duplicate blocker contacts from undoing the incoming-direction reversal. I did not find a grounded concurrency, timing, or determinism defect strong enough to block shipping.

No material findings.
