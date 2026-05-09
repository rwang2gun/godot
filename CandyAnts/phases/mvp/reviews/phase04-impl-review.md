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

---

## Round 4 (post-commit confirm)

- **실행 시각**: 2026-05-09 (sweep commit 348a4ea post-commit 재확인)
- **명령**: `/codex:adversarial-review --base 4478fb0 --scope branch --background "phase 4 sweep post-commit 재확인: 348a4ea의 blocker bounce per-frame guard + BlockerOverlapTest 회귀 추가가 4478fb0 대비 결정성/idempotency를 깼는지 검증"`
- **scope**: branch (4478fb0 → HEAD = 348a4ea)
- **verdict**: needs-attention

# Codex Adversarial Review

Target: branch diff against 4478fb0
Verdict: needs-attention

No-ship: the new guard only makes duplicate blocker callbacks idempotent inside one physics frame; compared with 4478fb0 it reintroduces non-idempotent behavior as soon as the same overlap is observed again on a later frame.

Findings:
- [high] Blocker bounce is only frame-idempotent and can reverse back on retried overlap callbacks (CandyAnts/scripts/ant/Ant.gd:83-90)
  4478fb0 assigned direction from relative position, so replaying the same blocker overlap callback produced the same result. This change stores only Engine.get_physics_frames() and then flips other.direction. If the same physical overlap is reported again after the frame advances, for example after monitoring/shape re-enable, callback retry, or an overlap that is still present across frame boundaries, the second callback passes the guard and flips the ant back toward its original direction. That can let an ant pass through a blocker or oscillate, which is exactly the determinism/idempotency surface this change claims to protect. The added regression only calls two blockers synchronously in one frame, so it does not cover this failure mode.
  Recommendation: Make duplicate suppression overlap-scoped rather than frame-scoped, e.g. track blocker/body pairs until body_exited or otherwise mark an active bounce interaction as consumed. Add a regression that replays the same overlap after at least one physics frame or toggles blocker monitoring while the walker remains overlapping.

Next steps:
- Block shipping until cross-frame duplicate overlap behavior is made idempotent and covered by a regression test.

---

## Round 5 (sweep fix v3 — overlap-scoped guard)

- **실행 시각**: 2026-05-09 (round 4 HIGH 후속 fix v3)
- **명령**: `/codex:adversarial-review --scope working-tree --background "phase 4 sweep round5: round4 HIGH(blocker bounce frame-scoped guard 취약) 후속. _last_blocker_bounce_frame(int) → _active_blocker_overlaps(Dictionary, blocker InstanceID set) 교체, _on_blocker_body_exited 핸들러 + set_blocker_active(false)/_exit_tree cleanup 추가. tests/BlockerOverlapTest.gd §B-6 추가."`
- **scope**: working-tree (uncommitted v3: overlap-scoped guard만 사용)
- **verdict**: needs-attention

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the overlap guard fixes same-pair replay but can suppress a real bounce from a second blocker for the entire duration of any prior overlap.

Findings:
- [high] Distinct blocker contacts can be consumed without bouncing (CandyAnts/scripts/ant/Ant.gd:99-104)
  The new guard treats any non-empty `_active_blocker_overlaps` as a reason to suppress bounce from a newly entered blocker. Because the code still inserts the new `blocker_id` before returning, a walker that is still overlapping blocker A when it enters blocker B will record B as active but will not flip. In Godot, `body_entered` is edge-triggered until an exit, so B's real contact has been consumed; after A exits, the walker can remain inside B with no second chance to bounce. This is an inference from the changed control flow and signal semantics, and it is not covered by §B-5 because that test only checks same-frame direct calls, not cross-frame distinct blocker entry while a previous overlap is still active.
  Recommendation: Separate same-frame multi-blocker idempotency from overlap membership. For example, keep the per-blocker overlap set for same-pair replay, but suppress additional blocker bounces only within the same physics frame as the last accepted bounce; add a regression where blocker B enters on a later physics frame while blocker A is still overlapped and verify B still bounces or is explicitly handled on A exit.

Next steps:
- Add a cross-frame distinct-blocker regression beyond §B-5/§B-6.
- Revise the guard so non-empty overlap state does not permanently consume later real blocker contacts.

---

## Round 6 (sweep fix v4 — dual-guard)

- **실행 시각**: 2026-05-09 (round 5 HIGH 후속 fix v4)
- **명령**: `/codex:adversarial-review --scope working-tree --background "phase 4 sweep round6: round 5 HIGH 후속. dual-guard로 변경 — _active_blocker_overlaps(per-pair, cross-frame replay) + _last_blocker_bounce_frame(per-frame, same-frame 다중 blocker double-flip) 둘 다 적용. §B-7 추가."`
- **scope**: working-tree (uncommitted v4: dual-guard)
- **verdict**: needs-attention

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the dual guard still has a same-frame consumption path that can make a valid blocker contact inert until exit/re-entry.

Findings:
- [high] Same-frame skipped blocker is still marked as consumed (CandyAnts/scripts/ant/Ant.gd:103-109)
  _on_blocker_body_entered writes blocker_id into other._active_blocker_overlaps before checking _last_blocker_bounce_frame. When a second distinct blocker fires in the same physics frame, line 108 returns without bouncing, but the pair remains recorded as an active overlap. Any later body_entered replay for that same still-overlapping blocker is suppressed by lines 101-102, so the contact is consumed until body_exited happens. This is especially risky because Area2D signal ordering is not guaranteed: if the first processed blocker is on one side and the skipped blocker is the one the ant is now moving toward after the first flip, the walker can ignore that blocker for the rest of the overlap. The new §B-5 test only asserts the immediate direction and does not assert the skipped blocker can still bounce on a later frame while overlap persists.
  Recommendation: Do not add the blocker_id to _active_blocker_overlaps until the contact is actually accepted, or store same-frame skipped contacts as pending and replay/resolve them on the next physics frame if the pair is still overlapping. Add a regression that calls the two blockers in both orders, advances a physics frame without body_exited, and verifies the skipped blocker is not permanently suppressed when it should still block.

Next steps:
- Fix guard ordering or add an explicit pending-contact path for same-frame skipped blockers.
- Extend §B-5 to cover reverse signal order and next-frame replay while still overlapping.

---

## Round 7 (sweep fix v5 — skip-no-record)

- **실행 시각**: 2026-05-09 (round 6 HIGH 후속 fix v5)
- **명령**: `/codex:adversarial-review --scope working-tree --background "phase 4 sweep round7: round 6 HIGH 후속. _on_blocker_body_entered에서 frame 검사를 set 기록 *전*으로 이동 — bounce가 실제로 accept될 때만 set에 기록. tests §B-8 추가 (reverse signal order + next-frame replay)."`
- **scope**: working-tree (uncommitted v5: skipped not recorded in set)
- **verdict**: needs-attention

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the fix prevents permanent suppression by allowing skipped contacts to replay next frame, but that also turns the original same-frame double-flip blocker into a delayed double-flip.

Findings:
- [high] Skipped same-frame blocker can undo the accepted bounce one frame later (CandyAnts/scripts/ant/Ant.gd:108-114)
  `_last_blocker_bounce_frame` only suppresses duplicate blocker hits within the current physics frame, and the new skip-no-record ordering means a same-frame skipped blocker is eligible as soon as `Engine.get_physics_frames()` advances. In the B-then-A case, B flips the walker from `+1` to `-1`, A is skipped, then A's next-frame replay flips the walker back to `+1` without an exit/re-entry or any check that the walker is moving into A. That is the same double-flip failure round 2 was blocking, just delayed by one frame; `BlockerOverlapTest.gd` lines 187-188 currently encode this direction reset as PASS, so the regression would be hidden rather than caught.
  Recommendation: Keep skipped blocker IDs out of `_active_blocker_overlaps`, but do not accept a skipped contact merely because the frame advanced. Require a real `body_exited`/new `body_entered` before it can bounce, or store skipped contacts separately with enough entry-side/inbound-direction state to prove the replay represents a valid new blocker collision. Update §B-8 so a no-exit next-frame replay cannot restore the original direction unless that is explicitly documented as intended gameplay.

Next steps:
- Clarify the intended behavior for a walker simultaneously overlapping two blockers across consecutive frames.
- Adjust §B-8 to distinguish real re-entry after exit from synthetic no-exit replay.
- Add a production-style overlap test if Godot can emit the replay through monitoring/shape changes rather than direct method calls.

---

## Round 8 (sweep fix v6 — overlap-lifetime idempotency, FINAL approve)

- **실행 시각**: 2026-05-09 (round 7 HIGH 후속 fix v6)
- **명령**: `/codex:adversarial-review --scope working-tree --background "phase 4 sweep round8: round 7 HIGH(skip-no-record가 next-frame synthetic replay에서 지연된 double-flip) 후속 fix. set 기록을 frame 검사 *앞*으로 되돌림 — overlap이 지속되는 동안 bounce/skip 무관 추가 발화 무효, body_exited 후 재진입은 fresh bounce. §B-8 (a)reverse-order 1회 flip + (b)synthetic next-frame replay suppress + (c)재진입은 fresh bounce."`
- **scope**: working-tree (uncommitted v6: overlap-lifetime guard + dual-guard 조합)
- **verdict**: **approve** ✅

# Codex Adversarial Review

Target: working tree diff
Verdict: approve

Ship: I could not support a material blocker in the round8 diff. The set-before-frame-check ordering closes the delayed replay double-flip, body_exited clears overlap-scoped suppression, and the added B-6/B-7/B-8 coverage directly exercises the prior high-risk paths.

No material findings.

---

## 최종 정리

Phase 4 sweep은 **8 라운드**의 challenge review를 거쳐 다음 invariant에 수렴:

- **Overlap-lifetime idempotency**: 같은 (blocker, walker) 쌍은 walker가 hitbox에 머무는 동안(body_exited 전까지) 추가 bounce 없음 — bounce/skip 상태 무관하게 set 멤버십으로 가드.
- **Same-frame multi-blocker**: 다중 blocker가 동시에 발화해도 단 1회 flip — `_last_blocker_bounce_frame` per-frame guard.
- **Cross-frame distinct blocker**: walker가 A에 overlap 중인 상태로 다른 frame에 B에 진입하면 정상 bounce — set엔 없고 frame guard도 풀려있음.
- **Body_exited cleanup**: monitoring=false 시 직접 정리 + `_exit_tree`로 free 시 cleanup — stale set entry 방지.

테스트 회귀: `BlockerOverlapTest.gd` §B-1 ~ §B-8 (8 케이스).
구현: `scripts/ant/Ant.gd` `_on_blocker_body_entered/exited`, `set_blocker_active`, `_exit_tree`.
