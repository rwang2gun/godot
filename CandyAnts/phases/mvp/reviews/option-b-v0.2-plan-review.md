# Phase 14~ 옵션 B v0.2 Migration Plan — Plan-stage Adversarial Review

- **실행 시각**: 2026-05-18
- **포커스**: docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md plan-stage 리뷰 (옵션 B v0.2 + §5.2 17 분할)
- **scope**: working-tree
- **base ref**: 87c7ee5174529ecccd9349b063ccf945211a4489
- **대상 문서**: docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md
- **컨텍스트 문서**: docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md (메인 worktree only), docs/PHASE_14_OPTION_B_PROPOSAL.md (v0.1)
- **리뷰어**: codex (codex-companion task forwarder via `/codex:rescue` 흐름)
- **정책**: CLAUDE.md plan stage — CRITICAL/HIGH 1건이라도 발견 시 즉시 중단 + 사용자 결정. 자동 재리뷰 사이클 X.

---

## Round 1

**BLOCKER**

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:213-215`, `271-280`
  **Problem:** `sync-status` is invoked without `--prune-missing` after deleting seven pending phase files. Repository `execute.py` preserves missing pending entries unless pruned, so `status.json` will still reference deleted files and `validate` will fail.
  **Mitigation:** Change step 2 to `python scripts/execute.py mvp sync-status --prune-missing`, then validate the expected phase count and deleted-file absence.

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:282-286`, `233-240`
  **Problem:** The validation step calls `python scripts/execute.py mvp next` before codex review and before the planned Notion sync. In this repo, `next` mutates `status.json` by marking the first pending phase `in_progress` and setting `started_at`, so this is not a harmless read-only check. It also conflicts with Commit 4's "first `next` call" gate.
  **Mitigation:** Use `python scripts/execute.py mvp` for read-only inspection, or add an explicit rollback/reset step if `next` is intentionally called. Do Notion sync before the first real `next`.

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:218-231`, after Commit 2 at `205-216`
  **Problem:** The "plan stage" adversarial review is sequenced after the destructive migration commit that deletes and recreates phase files. If the review finds HIGH/CRITICAL issues, the plan says to stop, but the migration has already been applied.
  **Mitigation:** Move codex adversarial review immediately after Commit 1 and before Commit 2. Commit 2 should only happen after plan-stage findings are resolved or explicitly accepted.

**HIGH**

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:5`, `104`, `136`, `201`
  **Problem:** The plan depends on `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md`, but that file is absent from the current worktree. The plan says to copy or merge it later, but all mappings and phase bodies already cite it as source of truth.
  **Mitigation:** Make proposal v0.2 a hard prerequisite before reviewing or executing Commit 2. Add a concrete source path, checksum/commit, and validation that the file exists before phase files reference it.

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:250`, `213`
  **Problem:** The risk table claims `sync-status` creates an automatic `.bak`, but the planned command does not pass prune flags. In repo code, backup creation only happens when pruning is enabled. Without `--prune-missing`, there is no backup and the deleted pending entries are retained.
  **Mitigation:** Correct the risk entry and execution step: either explicitly run `sync-status --prune-missing` or manually copy `status.json` before sync.

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:263-267`
  **Problem:** The migration-plan self-review says `die` / `Dead` / `사망` / `죽` grep should return 0, but the plan itself contains those terms in lines 115, 117, 254, and 266. The stated validation cannot pass as written.
  **Mitigation:** Scope the grep to newly generated phase files only, or allow quoted legacy terms inside this migration plan and update the validation wording.

**MEDIUM**

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:93-104`, `186-189`
  **Problem:** New phase files keep `docs/PRD.md` and `docs/ARCHITECTURE.md` as formal frontmatter SoT while the actual option-B mechanics and tone policy live in proposal v0.2, and PRD updates are explicitly deferred. This creates a split authority: tooling validates PRD/ARCHITECTURE existence, but the new behavior is elsewhere.
  **Mitigation:** Add proposal v0.2 or the new revision document to `sot_aux`, or update PRD/ARCHITECTURE before making the new phase files authoritative.

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:179-184`, `252-253`, `233-240`
  **Problem:** Notion slug mismatch is intentionally deferred, but the plan also schedules review, status validation, and a possible `next` check before synchronization. This creates a window where local status and external tracker disagree during the exact period when the next phase may be started.
  **Mitigation:** Either synchronize `notion-phase-ids.json` in Commit 2 with the local ledger or explicitly prohibit any `next`/phase-start command until Notion mapping is updated.

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:211-215`, `271-280`
  **Problem:** The expected validation result says "20 phase files" and phase 14-20 pending, but the plan does not include a check that `status.json` has exactly 20 entries after pruning. With the current command sequence, the file count and status-entry count can diverge.
  **Mitigation:** Add an explicit post-sync assertion: no `status.json` entries for deleted files, exactly 20 phases, ids 1-20 contiguous, and phase 14 name equals `mechanic-adaptation-traits`.

**LOW**

- **Location:** `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md:293-297`
  **Problem:** The "Godot editor Stage 1~3" check does not validate the actual migration risk, which is phase metadata, status reconciliation, README consistency, and source-document availability.
  **Mitigation:** Replace or supplement it with CLI checks: `validate`, read-only phase listing, status diff review, deleted-file absence, and proposal/revision link existence checks.

---

## Codex 메타

```
agentId: abc8f4e7cef46b02e (use SendMessage with to: 'abc8f4e7cef46b02e' to continue this agent)
total_tokens: 13791
tool_uses: 1
duration_ms: 199989
```
