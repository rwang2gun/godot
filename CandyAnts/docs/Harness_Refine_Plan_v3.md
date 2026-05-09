# Harness Refine Plan v3

작성일: 2026-05-10
입력 문서:
- `docs/Harness_Refine_Plan_v2.md`
- `docs/Harness_Refine_Plan_v2_Feedback.md`

상태: Plan v2 feedback 반영본. 차기 정식 적용 계획 SoT.

> 명명 규칙: 이 문서 시리즈는 `Harness_Refine_Plan_vN.md`로 유지한다. `HARNESS_REVIEW_V5.md`는 만들지 않는다.
>
> 결론: Plan v2의 방향은 유지하되, large-change override, read/stage policy 분리, metadata bootstrap, parser 허용 범위, rollback atomicity, plan-stage 리뷰 정책을 명시적으로 닫는다.

---

## 1. 채택 결정

`Harness_Refine_Plan_v2_Feedback.md`의 추천 조합을 채택한다.

| ID | 결정 |
|---|---|
| DR2-H1 | `large_change_ok: true` phase frontmatter flag 도입. 단, count guard만 우회하고 size guard는 항상 유지 |
| DR2-H2 | read policy와 stage policy를 별도 섹션으로 분리 |
| DR2-H3 | `validate` 첫 호출 시 `metadata.json`이 없으면 기본값 자동 생성 |
| DR2-H4 | 구버전 계획 archive는 Plan v3 적용 commit과 분리 |
| DR2-H5 | frontmatter parser는 단순 inline array만 지원. 따옴표/공백 경로/콤마 포함 경로는 거부 |
| DR2-H6 | Plan-stage HIGH 발견 시 자동 재리뷰 금지. 즉시 중단하고 사용자 결정 대기 |
| DR2-M1 | complete 시작 시 사전 staged 항목이 있으면 중단한다. 실패 cleanup은 하네스가 추가 stage한 항목만 unstage |
| DR2-M2 | rename/copy 감지는 `git status --porcelain=v2 -z` 기반 |
| DR2-M3 | `sync-status --force-prune-completed` 전 `status.json.bak` 자동 생성 |
| DR2-M4 | UI asset workflow 명시: `docs/design_handoff/**`는 read-only reference, runtime 자산은 `assets/` 등으로 복사 |
| DR2-M5 | `addons/**`는 whitelist 유지하되, addon 추가는 별도 commit 권고 + large change guard 적용 |

---

## 2. 목표

1. 세션 시작 자동 컨텍스트를 200줄 안팎으로 줄인다.
2. phase마다 `sot`/`sot_aux`로 read 컨텍스트를 결정한다.
3. runtime state(`status.json`)와 structure metadata(`metadata.json`)를 분리한다.
4. `execute.py validate`로 phase 계약을 기계 검증한다.
5. `execute.py complete`가 Godot metadata를 누락하지 않으면서 unrelated 파일은 막는다.
6. complete 실패 시 `status.json`만 completed로 남는 부분 완료를 방지한다.
7. plan-stage 리뷰는 HIGH 발견 시 자동 재리뷰하지 않는다.

---

## 3. Read Policy

### 3.1 자동 로드

자동 로드 유지:
- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/ADR.md`

자동 로드 제외:
- `docs/UI_GUIDE.md`
- `phases/{task}/REVISION_*.md`
- `phases/{task}/README.md`
- `docs/design_handoff/**`

KPI:
- 자동 로드 목표: 200줄 이하
- 기존 추정: 약 643줄
- 적용 후 추정: 약 195줄

주의:
- `status.json`은 자동 로드 KPI 대상이 아니다. `execute.py` 출력으로 필요한 상태만 노출한다.
- phase 진입 후 `sot`와 `sot_aux`가 가리키는 파일만 명시 read한다.

### 3.2 phase frontmatter SoT

`sot: self`는 금지한다.

기본 스키마:

```yaml
---
name: game-flow-foundation
duration_estimate: 7200
verify:
large_change_ok: false
sot: docs/GAME_FLOW_PROPOSAL_V5.md
sot_aux: [phases/mvp/REVISION_2026-05-09.md]
---
```

필드:
- `name`: 필수
- `duration_estimate`: 필수, 정수로 해석 가능해야 함
- `verify`: 선택, 빈 값 허용
- `large_change_ok`: 선택, 기본 `false`. `true`는 stage 후보 개수 제한만 우회하며 size guard는 우회하지 않음
- `sot`: 필수, 실제 경로만 허용
- `sot_aux`: 선택, 누락/빈 값은 `[]`

권장 매핑:

| Phase | sot | sot_aux | large_change_ok |
|---|---|---|---|
| 1~4 | `docs/PRD.md` | `[docs/ARCHITECTURE.md, docs/ADR.md]` | `false` |
| 5 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` | `false` |
| 6 | `docs/GAME_FLOW_PROPOSAL_V5.md` | `[phases/mvp/REVISION_2026-05-09.md]` | `false` |
| 7 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` | `false` |
| 8 | `docs/INPUT_PLAN.md` | `[]` | `false` |
| 9 | `docs/UI_GUIDE.md` | `[docs/INPUT_PLAN.md, docs/design_handoff/README.md]` | `true` |
| 10~13 | `docs/UI_GUIDE.md` | `[docs/INPUT_PLAN.md, docs/design_handoff/README.md]` | `false` |
| 14~20 | `docs/PRD.md` | `[docs/ARCHITECTURE.md]` | `false` |

### 3.3 UI asset workflow

`docs/design_handoff/**` is a read-only reference area.

Policy:
- Agents may read specific design handoff files when a phase plan names them.
- Agents should not modify or auto-stage files under `docs/design_handoff/**`.
- Runtime assets derived from design handoff must be copied or generated into project runtime folders such as `assets/`, `art/`, `themes/`, `fonts/`, or `audio/`.
- The runtime copies are normal phase outputs and may be auto-staged if they pass stage policy.

This separates read policy from stage policy:
- `docs/design_handoff/README.md` can appear in `sot_aux`.
- `docs/design_handoff/**` is still deny-listed for automatic staging.

---

## 4. Metadata Policy

`phases/{task}/metadata.json` stores structure metadata.

For `mvp`, default file:

```json
{
  "schema_version": 1,
  "task": "mvp",
  "active_revision": "phases/mvp/REVISION_2026-05-09.md",
  "post_mvp_phase_range": [21, 23],
  "notes": [
    "status.json is runtime state only.",
    "local phase files are discovered dynamically from phases/<task>/phase*.md."
  ]
}
```

Rules:
- Do not store `active_revision` in `status.json`.
- Do not hard-code `local_phase_count`.
- Do not duplicate phase count numbers in `CLAUDE.md`.
- Initial implementation keeps known task defaults in `scripts/execute.py`.
- Known defaults are limited to `mvp` until another task is explicitly added.
- If `metadata.json` is missing, `python scripts/execute.py {task} validate` creates it with task-specific defaults when known.
- If task defaults are unknown, validate fails with a message telling the user to create `phases/{task}/metadata.json`.

---

## 5. Frontmatter Parser Policy

No external YAML dependency.

Supported:
- `key: value`
- `verify:` as an empty value
- `large_change_ok: true`
- `large_change_ok: false`
- `sot_aux:`
- `sot_aux: []`
- `sot_aux: [docs/A.md]`
- `sot_aux: [docs/A.md, docs/B.md]`
- UTF-8 path characters without commas or surrounding quotes

Rejected:
- quoted array items, e.g. `['docs/A.md']`
- paths with leading/trailing spaces inside array items
- paths containing spaces anywhere in the path
- paths containing commas
- paths containing unmatched `[` or `]`
- multi-line YAML lists
- `sot: self`
- missing `sot`
- empty `sot`

Path guidance:
- Use paths without spaces in `sot`/`sot_aux`.
- If a human-readable source file has spaces in its name, create a stable no-space wrapper/summary file and point `sot_aux` at that wrapper.

---

## 6. execute.py Commands

### 6.1 validate

```bash
python scripts/execute.py mvp validate
```

Responsibilities:
- Create `metadata.json` on first run if task defaults are known in `scripts/execute.py`.
- Treat `mvp` as the only known default task in the first implementation.
- Validate `metadata.task == task`.
- Validate `active_revision` exists.
- Discover local phase files dynamically from `phase*.md`.
- Validate frontmatter schema.
- Reject `sot: self`.
- Validate all `sot` and `sot_aux` paths exist.
- Validate `large_change_ok` is `true`, `false`, or empty.
- Validate `status.json` phase files match discovered phase files.

When to run:
- At `/harness {task}` start, once per session.
- After phase files are added/deleted/renamed.
- After metadata, harness command, or `execute.py` changes.
- After a complete failure caused by phase contract mismatch.

### 6.2 sync-status

```bash
python scripts/execute.py mvp sync-status
python scripts/execute.py mvp sync-status --prune-missing
python scripts/execute.py mvp sync-status --force-prune-completed
```

Rules:
- Existing status entries are preserved by `file`.
- New phase files are added as pending.
- Missing phase files are reported and kept by default.
- `--prune-missing` removes pending missing entries only.
- `--force-prune-completed` removes completed missing entries too.
- Before any prune operation, write `status.json.bak` next to `status.json`.
- If renumbering is suspected, do not prune. Fix file/status mapping first.

### 6.3 complete

```bash
python scripts/execute.py mvp complete 6
```

Strict order:
1. Load status and target phase.
2. If already completed, no-op.
3. Run `verify` command if present.
4. Require `phases/{task}/reviews/phaseNN-impl-review.md` to exist and be non-empty.
5. Snapshot pre-existing staged files.
6. If pre-existing staged files are non-empty, abort and print the staged list.
7. Read git status using `git status --porcelain=v2 -z`.
8. Reject deny-listed changes.
9. Reject rename/copy states.
10. Reject whitelist-outside changes.
11. Compute auto-stage candidates.
12. Apply large-change guard. If phase has `large_change_ok: true`, bypass only the candidate count guard.
13. Auto-stage candidates, batching paths to avoid command length limits.
14. Print staged file list.
15. Abort if staged diff is empty.
16. Update status entry to completed.
17. Stage `status.json`.
18. Commit staged changes.
19. If commit fails, restore previous `status.json` content and unstage only paths added by the harness after the pre-stage snapshot.

Rollback rule:
- `complete` expects a clean index at start. If the user has pre-staged files, stop before changing anything.
- Never unstage user pre-staged files if they appear due to a race or manual intervention after the initial check.
- Harness tracks which files it staged and only cleans those up on failure.
- If cleanup fails, print a blocking error and tell the user not to proceed to the next phase.

Rationale:
- `complete` owns staging for the phase.
- Allowing pre-staged files would let unrelated changes ride along in the phase commit.
- A clean-index requirement is stricter but keeps the commit contract deterministic.

---

## 7. Stage Policy

### 7.1 Candidate Calculation

Order:

```text
changed files
→ normalize to repo-root POSIX-style path
→ deny-list match => block
→ git status R/C => block
→ whitelist match => stage candidate
→ otherwise block
```

`{task}` placeholders:
- Stage policy may use `phases/{task}/...`.
- `execute.py` expands `{task}` using the task CLI argument.

### 7.2 Deny-list

Never auto-stage:

| Pattern | Reason |
|---|---|
| `.git/**` | Git internals |
| `.godot/**` | Godot local/import cache |
| `.import/**` | Legacy/local import cache directory |
| `node_modules/**` | dependency cache |
| `.venv/**`, `venv/**` | local Python env |
| `__pycache__/**`, `*.pyc` | Python cache |
| `.DS_Store`, `Thumbs.db` | OS metadata |
| `*.tmp`, `*.temp`, `*.log`, `*.bak` | temp/log/backup |
| `export/**`, `build/**`, `dist/**` | build artifacts |
| `docs/design_handoff/**` | read-only external handoff/reference |
| `.claude/settings.local.json` | local/private settings |

### 7.3 Whitelist

Auto-stage candidates when not deny-listed:

Godot runtime:
- `project.godot`
- `scenes/**`
- `scripts/**`
- `data/**`
- `assets/**`
- `art/**`
- `audio/**`
- `themes/**`
- `fonts/**`
- `addons/**`

Tests:
- `tests/**`

Godot metadata:
- `**/*.uid`
- `**/*.import`

Harness/docs:
- `.claude/commands/**`
- `.claude/agents/**`
- `.claude/hooks/**`
- `.claude/settings.json`
- `CLAUDE.md`
- `docs/**/*.md`
- `phases/{task}/phase*.md`
- `phases/{task}/plans/*.md`
- `phases/{task}/reviews/*.md`
- `phases/{task}/status.json`
- `phases/{task}/metadata.json`
- `phases/{task}/notion-phase-ids.json`
- `phases/{task}/REVISION_*.md`

### 7.4 Git Status Handling

| Status | Policy |
|---|---|
| `??` untracked | auto-stage if allowed |
| `M` modified | auto-stage if allowed |
| `A` added | auto-stage/keep if allowed |
| `D` deleted | auto-stage if allowed |
| `R` renamed | block, require explicit user handling |
| `C` copied | block, require explicit user handling |

Detection:
- Use `git status --porcelain=v2 -z`.
- If rename/copy detection is ambiguous, block and print the affected paths.

### 7.5 Large Change Guard

Default guard:
- More than 100 stage candidates => block
- Any single candidate larger than 5 MB => block
- Total candidate size larger than 25 MB => block

Override:
- If target phase frontmatter has `large_change_ok: true`, bypass only the candidate count guard.
- The single-file size guard and total-size guard always apply.
- Even with override, deny-list and rename/copy block still apply.
- `large_change_ok` must be rare and phase-specific.

Addon note:
- `addons/**` remains whitelist candidate because local plugins may be phase outputs.
- Adding or updating large third-party addons should usually be a separate commit.
- Count and size guards apply to `addons/**`.
- `large_change_ok: true` can bypass the count guard for addon-heavy phases, but never bypasses addon size guards.

Phase 9 size audit:
- Phase 9 may use `large_change_ok: true` because theme/font/SVG import can create many legitimate files.
- Before `complete 9`, the implementation review must include a size audit table for all newly added or modified runtime assets under `assets/`, `art/`, `audio/`, `themes/`, and `fonts/`.
- The audit must list path, size, source, and reason for inclusion.
- Any single runtime asset larger than 5 MB or total staged runtime asset size larger than 25 MB blocks `complete`, even in phase 9.
- Oversized source/design files must stay in `docs/design_handoff/**` or an external design source, not be copied into runtime asset folders.
- If an oversized runtime asset is truly required, handle it outside the normal phase 9 commit with an explicit user decision and a separate asset policy update.

---

## 8. Archive Policy

Archive is separate from Plan v3 implementation.

Rules:
- Do not mix harness implementation changes with mass archive moves.
- After Plan v3 is accepted or applied, archive old plan documents in a separate commit:
  - `docs: archive superseded harness plans`
- Archive path: `docs/archive/harness/`
- Add this header to archived files:

```markdown
> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.
```

Archive targets:
- `docs/HARNESS_REVIEW.md`
- `docs/HARNESS_REVIEW_V3.md`
- `docs/HARNESS_REVIEW_V4.md`
- `docs/Harness_Refine_Plan.md`
- `docs/Harness_Refine_Plan_Feedback.md`
- `docs/Harness_Refine_Plan_v2.md`
- `docs/Harness_Refine_Plan_v2_Feedback.md`

Rename policy:
- Since automatic rename staging is blocked, archive moves should be staged manually or represented as delete+add in the separate archive commit.

---

## 9. Harness Command Updates

`.claude/commands/harness.md` must change to:
- Remove `docs/UI_GUIDE.md` from automatic read.
- Add the phase frontmatter template fields `large_change_ok: false`, `sot: <required path>`, `sot_aux: []`.
- Run `python scripts/execute.py {task} validate` once at session start.
- After `next`, read `sot` and `sot_aux` paths.
- Explain read policy and stage policy separately.
- State that `complete` performs safe auto-stage using deny-list + whitelist.
- State that plan-stage HIGH review findings stop the flow and require user decision.

`CLAUDE.md` must change to:
- Remove hard-coded phase count text.
- Refer to `phases/mvp/metadata.json` and `phases/mvp/notion-phase-ids.json` for phase/page metadata.

---

## 10. Plan-Stage Review Policy

Plan v3 inherits `CLAUDE.md` policy:
- Run plan-stage review once when needed.
- If CRITICAL/HIGH appears, stop immediately.
- Do not auto-fix and auto-rerun review.
- Report findings to the user and wait for direction.
- MEDIUM/LOW may be handled in the plan or deferred with explanation.

This document itself should not prescribe an automatic review loop.

---

## 11. Acceptance Criteria

| Item | Criterion |
|---|---|
| Auto-load | non-UI phase does not auto-read `UI_GUIDE.md`; target auto-load stays <= 200 lines |
| Read policy | `sot`/`sot_aux` determines phase-specific reads |
| Stage policy | read policy and stage policy are documented separately |
| No self SoT | `rg 'sot:\s*self' phases/mvp -g 'phase*.md'` returns no matches |
| Metadata | `active_revision` exists only in `metadata.json`, not `status.json` |
| Bootstrap | first `validate` can create missing `metadata.json` for `mvp`; unknown tasks fail with manual metadata instructions |
| Validate | `python scripts/execute.py mvp validate` passes after migration |
| Sync | `sync-status` can repair status without reset |
| Backup | prune operations create `status.json.bak` |
| Complete atomicity | commit failure does not leave only `status.json` completed |
| Clean index | `complete` aborts before mutation when pre-existing staged files are present |
| User staged preservation | if pre-staged files appear after startup, cleanup never unstages them |
| Review gate | missing or empty `phaseNN-impl-review.md` blocks complete |
| Godot metadata | `**/*.uid` and `**/*.import` can auto-stage |
| Python helpers | `scripts/**` changes do not block harness implementation |
| UI assets | `large_change_ok: true` can unblock many intentional asset files, but file-size and total-size guards still block oversized assets |
| Phase 9 audit | phase 9 implementation review includes a runtime asset size audit before `complete 9` |
| Addons | `addons/**` changes obey deny-list, rename/copy block, and size guards even when `large_change_ok: true` |
| Design handoff | `docs/design_handoff/**` is read-only reference and not auto-staged |
| Rename/copy | R/C status blocks auto-stage |
| Archive | old plan archive is separate from implementation commit |

---

## 12. Next Step

If this Plan v3 is accepted, apply it in implementation phases:

1. Update docs and phase frontmatter.
2. Add `metadata.json`.
3. Update `execute.py`.
4. Update `.claude/commands/harness.md`.
5. Update `CLAUDE.md` metadata wording.
6. Run validate and targeted safety checks.

Plan-stage HIGH findings during implementation planning stop the flow and return to the user.
