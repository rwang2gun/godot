# Phase 19 Impl Adversarial Review

본 파일은 phase 19 (mechanic-destruction-plant) impl-stage codex adversarial-review의 라운드별 stdout 누적. plan v3.1.1 SoT. CLAUDE.md impl-stage 정책: CRITICAL/HIGH 1건이라도 발견 시 반드시 fix → 자체 적대적 리뷰 cycle → codex 재리뷰까지 clean 반복. MEDIUM/LOW는 강제 fix 대상 아님(deferred 박제 또는 별도 sweep 허용).

---

## Round 1 (2026-05-25, plan v3.1.1 SoT)

**Verdict**: needs-attention — **HIGH 0건**, MEDIUM 2건(F1, F2) + LOW 1건(F3).

### Summary
Phase 19 implementation matches the main Cutter/plant separation design and the essential tests cover the primary happy path, cross-kind rejection, registry wiring, and backward compatibility. No CRITICAL data-loss/crash issue, but a few gaps where tests or validation do not fully cover the adversarial risks named in the prompt.

### Findings

**[MEDIUM] F1: Cutter can process multiple destruction ticks in one state update**
- Location: `scripts/ant/states/WorkerState.gd:454-460`, `scripts/ant/states/WorkerState.gd:479`
- Impact: If `delta` is large enough to satisfy `while _tick_accum >= CUTTER_TICK` more than once, Cutter can destroy and teleport across multiple cells in one update without an intervening physics/Area2D step. That can skip intermediate overlap behavior, especially plant+hazard cells beyond the first.
- Recommendation: Cap Cutter to one destruction per physics update, or add an explicit test with accumulated delta / multi-plant hazard overlap to prove the current loop cannot skip required hazard contact.

**[MEDIUM] F2: Unknown layout tile types silently become earth**
- Location: `scripts/world/StageLayoutBuilder.gd:43-45`, `scripts/world/StageLayoutBuilder.gd:92-97`
- Impact: A typo such as `"plnat"` is built and registered as `"earth"` instead of failing or remaining unregistered. That creates an invalid kind enum path where intended plant terrain becomes Basher-targetable earth.
- Recommendation: Validate `tile_type` against `solid`, `slope_right`, `slope_left`, and `plant`; fail loudly with `push_error`/assert or skip registration for unknown values.

**[LOW] F3: PRD skill roster is now stale relative to implementation**
- Location: `docs/PRD.md:10`; `scripts/core/SkillRegistry.gd:3-13`; `scripts/ui/SkillToolbar.gd:14-24`
- Impact: PRD says "8 skills" and does not name Cutter, while the implementation registers Cutter and toolbar support. Cross-doc consistency, not a runtime bug.
- Recommendation: Update PRD skill wording or add a note that phase plans supersede the original MVP skill roster.

### Test Gate Analysis
- **E1 — PARTIAL**: Gates end-to-end vine cut, save, cleared plant kind, and floor preservation, but does not verify static body free despite plan §2.5 claiming that check.
- **E2 — PARTIAL**: Gates edge stop, two-cell removal, and adjacent kind stability; does not assert exact final ant cell/position.
- **E3 — GATES**: Deterministically gates Cutter→earth rejection via earth kind preservation, static occupancy count, and Walker return.
- **E4 — GATES**: Deterministically gates Basher→plant rejection via plant kind preservation, static occupancy count, and Walker return.
- **E5 — GATES**: Gates plant registration, cross-kind atomic rejection, add_tile rejection on plant, and plant destroy cleanup.
- **E6 — PARTIAL**: Gates single same-cell plant+hazard independence and Sticky activation; does not gate multi-cell same-frame destroy/overlap skipping.
- **E7 — GATES**: Gates SkillRegistry preload, ID lookup, validate_stage success, and unknown-id rejection.
- **E8 — GATES**: Gates current `data/stage_layouts/*.tres` backward compatibility by scanning all non-phase-19 layouts and asserting all registered cells are earth.
- **E9 — GATES**: Gates toolbar cutter slot creation, icon, KO label, skill id, and hotkey.

### §9 Regression Coverage
The §9 command list is broader than the prompt's "14 real filenames": plan lines `429-453` list 19 commands total, including 3 phase 2-4 stage/base tests and 16 phase 14-18 mechanic tests. Coverage is adequate for the named phase 1-18 mechanics in this repo, with one caveat: the list guards existing essential behavior but does not add a dedicated carry-rejection regression for Cutter, relying instead on `CutterSkill.can_apply()` mirroring Basher/Digger at `scripts/skills/CutterSkill.gd:15-16`.

### 정책 적용

- **HIGH 0건** → CLAUDE.md impl-stage 정책상 "CRITICAL/HIGH 1건이라도 나오면 반드시 수정" 조건 미충족. 강제 fix loop 진입 안 함.
- F1/F2/F3 (MEDIUM 2건 + LOW 1건)은 `phases/mvp/plans/phase19-deferred.md`에 박제 — 각 finding의 phase 19 본질 분석:
  - F1: Basher/Digger phase 18에서도 동일 while loop 패턴(`_update_basher` `_update_digger`), 동일 hypothetical risk 보유. phase 18 ship 시점에도 명시 가드 없이 통과. **phase 19 신규 위험 아님** → deferred.
  - F2: plan v3 §11 risk에 이미 박제 (`tile_map` value vocabulary silent fallback). 추가 push_warning은 phase 19 scope 확장이라 v1.1 또는 polish phase로 deferred.
  - F3: plan §2.7 ban list가 `docs/PRD.md` 무변경 명시. phase 19에서 PRD wording 갱신은 정책 위반. polish phase (phase 20) 또는 별도 doc track에서 처리 → deferred.
- 자체 적대적 리뷰 cycle 진입 X (HIGH 0건). codex 재리뷰 cycle도 진입 X.
- phase 19 complete 진입 가능.

### Next steps

- F1/F2/F3 deferred 박제 → `phases/mvp/plans/phase19-deferred.md` 작성.
- `execute.py complete 19` + Notion 동기화 + git commit.
