> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness 구조 개편 계획 (v4)

작성일: 2026-05-10
대상: `.claude/commands/harness.md`, `scripts/execute.py`, `phases/mvp/phase*.md`, `phases/mvp/status.json`, 신규 `phases/mvp/metadata.json`
상태: v3 + 실제 하네스 구조 분석 반영본

> v4는 v3의 핵심인 "자동 로드 축소 + phase-local SoT"를 유지하되, 실제 운영 리스크까지 닫는다.
> - 구조 메타데이터(`active_revision`)를 런타임 상태(`status.json`)에서 분리한다.
> - `execute.py`에 validate/preflight를 추가해 phase 계약을 기계적으로 검사한다.
> - `git add -A` 자동 커밋이 unrelated 파일을 끌고 들어가는 위험을 제거한다.

---

## 1. 현재 하네스 구조

| 파일 | 현재 역할 | 문제 |
|---|---|---|
| `.claude/commands/harness.md` | 세션 시작 문서 로드, phase 생성/진행 절차 지시 | `UI_GUIDE.md` 자동 로드, phase 템플릿에 `sot` 없음 |
| `scripts/execute.py` | `status.json` 생성/갱신, `next`, `complete`, 자동 커밋 | phase 메타 검증 없음, `git add -A`가 unrelated 파일까지 staging |
| `phases/mvp/status.json` | phase 진행 상태 | 런타임 상태와 구조 메타데이터를 섞으면 reset 때 유실 위험 |
| `phases/mvp/README.md` | 7단계 절차 SoT | 하네스가 절차 준수 여부를 검증하지 않음 |
| `CLAUDE.md` | 프로젝트 CRITICAL 규칙 + 리뷰/Notion 정책 | `harness.md`와 정책 일부 중복 |
| `phases/mvp/phaseNN-*.md` | phase 정의 | 1차 SoT가 frontmatter에 없음 |
| `phases/mvp/notion-phase-ids.json` | Notion page_id 매핑 | phase 6 page_id null, 하네스 검증 대상 아님 |
| `docs/HARNESS_REVIEW_V3.md` | v3 계획 | metadata 분리와 commit preflight 미포함 |

---

## 2. 목표

1. 세션 시작 자동 컨텍스트를 200줄 안팎으로 줄인다.
2. 각 phase 진입 시 필요한 1차 SoT를 `sot` frontmatter로 결정한다.
3. 런타임 상태와 구조 메타데이터를 분리한다.
4. phase 완료 커밋이 unrelated 파일을 포함하지 않게 한다.
5. 하네스 계약을 `execute.py validate`로 확인 가능하게 만든다.

---

## 3. 핵심 결정

### D1. 자동 로드 축소

자동 로드 유지:
- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/ADR.md`
- `CLAUDE.md`는 상위 지침으로 이미 로드되는 전제

자동 로드 제외:
- `docs/UI_GUIDE.md`
- `phases/{task}/REVISION_*.md`
- `phases/{task}/README.md`
- `phases/{task}/status.json`
- `docs/design_handoff/`

명시 read 조건:
- `sot`가 가리키는 파일은 phase 진입 직후 read
- `sot_aux`는 보조 결정이 필요할 때 read하되, harness 지침은 "있으면 read"로 둔다

### D2. phase frontmatter SoT

모든 로컬 phase 파일은 다음 필드를 가진다.

```yaml
---
name: {phase 이름}
duration_estimate: {예상 초}
verify: {선택 — 검증 명령}
sot: {필수 — 1차 SoT 파일 경로, 자기 자신이면 self}
sot_aux: []
---
```

이번 일괄 갱신 대상은 로컬 파일이 존재하는 phase 1~20뿐이다.

post-MVP 21~23은 현재 README/Notion 매핑에만 존재하므로 이번에 파일을 만들지 않는다. 실제 로컬 phase 파일을 만들 때 `sot`를 동시에 결정한다.

### D3. 구조 메타데이터 분리

`active_revision`은 `status.json`이 아니라 신규 `phases/mvp/metadata.json`에 둔다.

```json
{
  "schema_version": 1,
  "task": "mvp",
  "active_revision": "phases/mvp/REVISION_2026-05-09.md",
  "local_phase_count": 20,
  "post_mvp_phase_range": [21, 23],
  "notes": [
    "status.json is runtime state only.",
    "post-MVP phase files are created only when their sot is decided."
  ]
}
```

이유:
- `status.json reset`으로 구조 포인터가 사라지지 않는다.
- 런타임 진행 상태와 구조 결정의 수명이 다르다.
- 미래 task가 늘어날 때 task별 metadata로 확장하기 쉽다.

### D4. `execute.py validate`

신규 명령:

```bash
python scripts/execute.py mvp validate
```

검사 항목:
- `metadata.json` 존재 여부
- `metadata.task == task`
- `active_revision` 경로 존재 여부
- 로컬 phase 파일 수가 `metadata.local_phase_count`와 일치
- 모든 `phase*.md`에 frontmatter 존재
- 모든 phase frontmatter에 `name`, `duration_estimate`, `sot` 존재
- `sot != self`인 경우 경로 존재
- `sot_aux`가 있으면 배열 또는 빈 배열로 해석 가능
- `status.json`의 phase file 목록과 실제 phase 파일 목록 일치

검사 제외:
- Notion page_id null 여부. Notion은 보조 트래커이고 phase 6 신규 page 생성은 별도 운영 이슈다.
- `docs/design_handoff/`의 대용량 레퍼런스 존재 여부.

### D5. `execute.py complete` preflight

현재 `complete`는 `git add -A`로 전체 변경을 커밋한다. 지금 repo처럼 `.uid` 미추적 파일이 많은 상태에서는 unrelated 파일이 phase 커밋에 섞일 수 있다.

v4에서는 다음 중 하나를 선택한다.

권장안 A: complete 전 dirty preflight
- `git status --porcelain` 출력
- 변경 파일을 보여주고, phase 관련 파일인지 확인 불가하면 complete 중단
- 자동 staging은 하지 않거나, 최소한 사용자 확인 후 진행

권장안 B: phase manifest 기반 staging
- phase plan 또는 phase 파일에 `changed_files`/`commit_paths`를 명시
- `execute.py complete`는 그 경로만 `git add`
- 초기 구현 부담이 커서 v4에서는 보류

v4 채택: **권장안 A**

정책:
- `complete`는 verify 통과 후 `git status --porcelain`을 출력한다.
- untracked 파일이 있으면 자동 커밋을 중단한다.
- 사용자가 직접 정리/stage하거나, 별도 allow 옵션이 도입되기 전까지 `git add -A`를 실행하지 않는다.

추가 명령은 추후 고려:

```bash
python scripts/execute.py mvp complete 6 --stage-all
```

단, v4 첫 적용에서는 안전을 위해 옵션 미도입.

---

## 4. 변경 명세

### 4.1 `.claude/commands/harness.md`

수정 범위:
- §1 자동 로드에서 `UI_GUIDE.md` 제거
- lazy-load 파일 목록 추가
- §4 phase 생성 템플릿에 `sot`, `sot_aux` 추가
- §5 `next` 이후 `sot`/`sot_aux` read 명시
- §5 `complete` 전 validate/preflight 흐름 명시

권장 흐름:

```text
python scripts/execute.py {task} validate
python scripts/execute.py {task}
python scripts/execute.py {task} next
frontmatter sot/sot_aux read
phase 작업
manual/automated verify
/codex:adversarial-review
python scripts/execute.py {task} complete {N}
```

### 4.2 `phases/mvp/metadata.json` 신규 생성

파일: `phases/mvp/metadata.json`

```json
{
  "schema_version": 1,
  "task": "mvp",
  "active_revision": "phases/mvp/REVISION_2026-05-09.md",
  "local_phase_count": 20,
  "post_mvp_phase_range": [21, 23],
  "notes": [
    "status.json is runtime state only.",
    "post-MVP phase files are created only when their sot is decided."
  ]
}
```

### 4.3 phase frontmatter 갱신

로컬 phase 20개를 갱신한다.

| Phase | sot | sot_aux |
|---|---|---|
| 1~4 | `self` | `[]` |
| 5 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 6 | `docs/GAME_FLOW_PROPOSAL_V5.md` | `[phases/mvp/REVISION_2026-05-09.md]` |
| 7 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 8 | `docs/INPUT_PLAN.md` | `[]` |
| 9~13 | `docs/UI_GUIDE.md` | `[docs/INPUT_PLAN.md]` |
| 14~20 | `docs/PRD.md` | `[docs/ARCHITECTURE.md]` |

### 4.4 `scripts/execute.py`

추가/변경:
- `metadata_file(task)` helper
- `load_metadata(task)` helper
- `cmd_validate(task)` 추가
- `main()`에 `validate` command 추가
- `cmd_complete()`에서 `git add -A` 제거
- `cmd_complete()`에 dirty/untracked preflight 추가

preflight 정책:
- verify 실패: 기존처럼 중단
- untracked 파일 존재: complete 중단
- tracked modified 파일 존재: 목록 출력 후 자동 staging 없이 중단하거나, 이미 staged된 파일만 커밋

v4 권장 구현:
- `git diff --cached --quiet`로 staged 변경이 있는지 확인
- staged 변경이 없으면 "stage files intentionally before complete" 메시지로 중단
- 즉, phase 완료자는 먼저 의도한 파일만 직접 stage한다.
- 이후 `execute.py complete`는 staged 변경만 커밋한다.

장점:
- unrelated `.uid` 파일 자동 포함 방지
- 커밋 범위가 명시적
- 기존 "Phase 완료 후 자동 커밋"은 유지하되, staging 책임만 사람/에이전트가 의도적으로 수행

### 4.5 `phases/mvp/status.json`

변경 없음.

정책:
- runtime state만 둔다.
- `active_revision`은 넣지 않는다.
- reset으로 삭제/재생성되어도 구조 메타데이터에는 영향이 없어야 한다.

### 4.6 문서 정합성 보정

`CLAUDE.md`의 다음 문구는 현재 실제 매핑과 다르다.

```text
page_id 매핑은 phase가 추가/이름 변경될 때만 `notion-phase-ids.json` 갱신 (현재 22 phase 고정, 변경 빈도 낮음)
```

실제 `notion-phase-ids.json`은 1~23을 가진다. v4 적용 시 다음처럼 바꾼다.

```text
page_id 매핑은 phase가 추가/이름 변경될 때만 `notion-phase-ids.json` 갱신 (현재 23 phase 매핑, 로컬 MVP phase 파일은 20개)
```

---

## 5. 적용 순서

1. `docs/HARNESS_REVIEW_V4.md` 사용자 컨펌
2. `phases/mvp/metadata.json` 생성
3. `.claude/commands/harness.md` 수정
4. `CLAUDE.md` phase 수 문구 정정
5. 로컬 phase 20개 frontmatter에 `sot`/`sot_aux` 추가
6. `scripts/execute.py validate` 추가
7. `scripts/execute.py complete`에서 `git add -A` 제거 + staged-only commit preflight 추가
8. `python scripts/execute.py mvp validate` 실행
9. 의도한 파일만 stage
10. 커밋

권장 커밋 메시지:

```text
chore: make harness phase context explicit and safer
```

---

## 6. 검증 기준

| 항목 | 기준 | 명령/방법 |
|---|---|---|
| 자동 로드 축소 | `UI_GUIDE.md` 자동 read 제거 | `.claude/commands/harness.md` 확인 |
| phase SoT | 20개 phase 모두 `sot` 보유 | `rg -L "^sot:" phases/mvp/phase*.md` 결과 없음 |
| metadata 분리 | `metadata.json` 존재, `status.json`에는 구조 메타 없음 | 파일 확인 |
| validate 통과 | phase/schema/path/status 일치 | `python scripts/execute.py mvp validate` |
| complete 안전성 | untracked 파일 자동 staging 없음 | untracked 파일 있는 상태에서 complete 중단 확인 |
| staged-only commit | 의도적으로 stage한 파일만 커밋 | `git diff --cached --name-only` 후 complete |
| next 결정성 | `next` 출력에 `sot`/`sot_aux` 노출 | `python scripts/execute.py mvp next` |

---

## 7. 롤백

단일 커밋 revert로 복구 가능하다.

잔존 영향:
- phase frontmatter의 `sot`/`sot_aux`는 코드 실행에 영향 없음
- `metadata.json`은 참조하지 않으면 무해
- `complete` staged-only 정책을 되돌리면 기존 `git add -A` 동작으로 회귀

---

## 8. v3 대비 차이

| 측면 | v3 | v4 |
|---|---|---|
| `active_revision` 위치 | `status.json` + `init_status()` | 신규 `metadata.json` |
| status 역할 | 진행 상태 + 구조 포인터 가능 | 진행 상태만 |
| execute 검증 | frontmatter 노출 확인 위주 | `validate` 명령 추가 |
| complete 커밋 | 기존 자동 staging 전제 | staged-only commit, untracked 자동 포함 방지 |
| phase 수 정합성 | 로컬 20개 명시 | 로컬 20개 + Notion 23개 문구까지 보정 |
| 운영 안전성 | context 결정성 중심 | context 결정성 + 커밋 범위 안전성 |
