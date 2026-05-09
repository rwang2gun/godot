> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness Refine Plan v2

작성일: 2026-05-10
입력 문서:
- `docs/Harness_Refine_Plan.md`
- `docs/Harness_Refine_Plan_Feedback.md`

상태: refine plan feedback 반영본 + 자체 적대적 리뷰 보완 완료

> 결론: `Harness_Refine_Plan.md`의 큰 방향은 유지하되, v5 작성 전 결정 사항을 더 구체화한다. 특히 `complete`의 자동 stage 정책은 단순 whitelist가 아니라 **deny-list 우선 + whitelist fallback** 하이브리드로 설계한다.

---

## 1. 채택 결정 요약

`Harness_Refine_Plan_Feedback.md`의 추천 조합을 기본 채택한다.

| ID | 결정 |
|---|---|
| DR-H1 | `scripts/**` 허용. `scripts/execute.py`뿐 아니라 test runner/helper 전체를 phase 산출물로 인정 |
| DR-H2 | `**/*.uid` 허용. Godot resource type별 `.uid` 변종을 일괄 처리 |
| DR-H3 | `assets/**`, `art/**`, `audio/**`, `themes/**`, `fonts/**` 등 런타임 자산 디렉토리 허용 |
| DR-H4 | `phases/{task}/notion-phase-ids.json` 허용 |
| DR-H5 | `phases/{task}/REVISION_*.md` 허용 |
| DR-H6 | `sync-status --force-prune-completed` 도입. 비인터랙티브 CLI에서 사용자 확인을 옵션으로 표현 |
| DR-H7 | `{task}` placeholder는 `execute.py`가 런타임에 치환 |
| DR-H8 | `docs/**/*.md` 허용하되 `docs/design_handoff/**`는 기본 deny |
| DR-H9 | 삭제(D)는 allow 패턴 안이면 자동 stage, rename(R)은 중단 후 명시 확인 |
| DR-H10 | stage 정책은 deny-list 우선 + whitelist fallback 하이브리드 |
| DR-M1 | complete atomicity는 strict 원복 |
| DR-M2 | impl review artifact는 파일 존재 + non-empty까지 강제 |
| DR-M4 | `sot_aux: []`, `[a]`, `[a, b]` 인라인 배열 지원. 외부 YAML 의존성 없음 |
| DR-M7 | 구버전 계획 문서는 `docs/archive/harness/`로 이동 |
| DR-M8 | `.claude/{commands,agents,hooks}/**`와 `.claude/settings.json` 계열만 명시 허용 |
| DR-M9 | `**/*.import`는 commit 대상, `.godot/**` 캐시는 deny |
| DR-M10 | frontmatter parser가 필수 키 누락을 빈 문자열로 채우고 validate에서 실패 처리 |

---

## 2. v5에 반영할 핵심 설계

### 2.1 자동 로드 축소

자동 로드 유지:
- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/ADR.md`

자동 로드 제외:
- `docs/UI_GUIDE.md`
- `phases/{task}/REVISION_*.md`
- `phases/{task}/README.md`
- `docs/design_handoff/**`

주의:
- `status.json`은 애초에 자동 로드 KPI가 아니다. v5에서는 자동 로드 제외 KPI에 `status.json`을 넣지 않는다.
- phase 진입 후 `sot`/`sot_aux`가 가리키는 파일만 명시 read한다.

### 2.2 phase frontmatter SoT

`sot: self`는 금지한다.

모든 로컬 phase 파일은 실제 파일 경로를 가진다.

```yaml
---
name: game-flow-foundation
duration_estimate: 7200
verify:
sot: docs/GAME_FLOW_PROPOSAL_V5.md
sot_aux: [phases/mvp/REVISION_2026-05-09.md]
---
```

권장 매핑:

| Phase | sot | sot_aux |
|---|---|---|
| 1~4 | `docs/PRD.md` | `[docs/ARCHITECTURE.md, docs/ADR.md]` |
| 5 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 6 | `docs/GAME_FLOW_PROPOSAL_V5.md` | `[phases/mvp/REVISION_2026-05-09.md]` |
| 7 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 8 | `docs/INPUT_PLAN.md` | `[]` |
| 9~13 | `docs/UI_GUIDE.md` | `[docs/INPUT_PLAN.md, docs/design_handoff/README.md]` |
| 14~20 | `docs/PRD.md` | `[docs/ARCHITECTURE.md]` |

UI track 주의:
- `docs/design_handoff/**`는 자동 로드/자동 stage 기본 대상이 아니다.
- 단, UI phase에서 특정 design handoff 파일을 실제로 읽어야 하면 phase plan에 명시하고 필요한 파일만 read한다.
- `sot_aux`에는 대표 진입점인 `docs/design_handoff/README.md`만 둔다. 대용량 하위 파일 전체를 강제 read하지 않는다.

### 2.3 metadata 분리

`phases/mvp/metadata.json`을 생성한다.

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

금지:
- `local_phase_count` hard-code 금지
- `status.json`에 `active_revision` 중복 금지
- `CLAUDE.md`에 phase count 숫자 중복 금지

---

## 3. `execute.py` 변경 계획

### 3.1 신규 명령

```bash
python scripts/execute.py mvp validate
python scripts/execute.py mvp sync-status
python scripts/execute.py mvp sync-status --prune-missing
python scripts/execute.py mvp sync-status --force-prune-completed
```

`validate` 검사:
- `metadata.json` 존재
- `metadata.task == task`
- `active_revision` 경로 존재
- 모든 `phase*.md` frontmatter 존재
- `name`, `duration_estimate`, `sot` 필수
- `sot` 빈 값 또는 `self`면 실패
- `sot` 경로 존재
- `sot_aux` 누락/빈 값은 `[]`로 해석
- `sot_aux` 경로 모두 존재
- `status.json`의 phase file 목록과 실제 phase file 목록 일치

`sync-status` 정책:
- 기존 status 항목은 `file` 기준으로 보존
- 새 phase 파일은 pending으로 추가
- missing phase는 기본적으로 제거하지 않고 경고
- `--prune-missing`: pending missing만 제거
- `--force-prune-completed`: completed missing도 제거하되, 명시 옵션이므로 비인터랙티브 확인으로 간주

### 3.2 frontmatter parser

외부 YAML 의존성은 도입하지 않는다.

지원 범위:
- `key: value`
- `sot_aux: []`
- `sot_aux: [docs/A.md]`
- `sot_aux: [docs/A.md, docs/B.md]`
- `sot_aux:` 또는 누락은 빈 배열

validate에서 실패 처리:
- frontmatter 없음
- `sot` 키 누락
- `sot` 빈 값
- `sot: self`
- `sot_aux` inline array가 닫히지 않음
- `sot_aux` 항목 경로가 존재하지 않음

### 3.3 complete 순서

현재 `complete`는 status를 먼저 completed로 저장한 뒤 commit한다. v5에서는 strict atomicity를 적용한다.

순서:
1. phase 존재 확인
2. phase가 already completed면 no-op
3. verify 실행
4. `phaseNN-impl-review.md` 존재 + non-empty 확인
5. git status 수집
6. deny-list 위반 확인
7. whitelist stage 후보 계산
8. rename(R) 감지 시 중단
9. whitelist 밖 변경 감지 시 중단
10. 삭제(D)는 whitelist 안이면 stage
11. allow 후보 자동 stage
12. staged file 목록 출력
13. staged diff 없으면 중단
14. status를 completed로 갱신
15. `status.json` stage
16. commit 실행
17. commit 실패 시 `status.json` 원복 + 재stage 정리 + 실패 출력

원칙:
- commit 전에는 `status.json`을 completed로 저장하지 않는다.
- commit 실패 후 status만 completed로 남기지 않는다.
- impl review artifact 없이는 complete 불가.

---

## 4. 자동 stage 정책

### 4.1 deny-list 우선

아래 패턴은 어떤 경우에도 자동 stage하지 않는다.

| 패턴 | 이유 |
|---|---|
| `.git/**` | git 내부 |
| `.godot/**` | Godot local/import cache |
| `.import/**` | legacy/local import cache directory 가능성 |
| `node_modules/**` | dependency cache |
| `.venv/**`, `venv/**` | local Python env |
| `__pycache__/**`, `*.pyc` | Python cache |
| `.DS_Store`, `Thumbs.db` | OS metadata |
| `*.tmp`, `*.temp`, `*.log`, `*.bak` | temp/log/backup |
| `export/**`, `build/**`, `dist/**` | build artifacts |
| `docs/design_handoff/**` | 대용량/외부 handoff 원본. 필요한 경우 별도 명시 commit |

### 4.2 whitelist fallback

deny-list에 걸리지 않은 변경 중 아래 패턴만 자동 stage 후보가 된다.

도구/스크립트:
- `scripts/**`

Godot runtime:
- `project.godot`
- `scenes/**`
- `scripts/**`
- `data/**`
- `addons/**`
- `assets/**`
- `art/**`
- `audio/**`
- `themes/**`
- `fonts/**`

테스트:
- `tests/**`

Godot metadata:
- `**/*.uid`
- `**/*.import`

하네스/문서:
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

`{task}` placeholder:
- whitelist 정의에는 `{task}`를 쓸 수 있다.
- `execute.py`는 런타임 task 인자로 `phases/{task}/...`를 실제 경로로 치환한다.
- 내부 비교는 repo root 기준 POSIX-style 경로(`/`)로 정규화한다.

### 4.3 git status 처리

| 상태 | 정책 |
|---|---|
| `??` untracked | deny-list 아니고 whitelist면 자동 stage |
| `M` modified | deny-list 아니고 whitelist면 자동 stage |
| `A` added | deny-list 아니고 whitelist면 유지/stage |
| `D` deleted | deny-list 아니고 whitelist면 자동 stage |
| `R` renamed | 중단. rename은 의도 확인 후 별도 stage |
| `C` copied | 중단. copied는 의도 확인 후 별도 stage |

중단 메시지에는 반드시 다음을 포함한다.
- deny-list 위반 파일 목록
- whitelist 밖 파일 목록
- rename/copy 파일 목록
- stage 후보 목록

---

## 5. 문서 정리 정책

v5 작성 후 구버전 계획 문서는 archive로 이동한다.

대상:
- `docs/HARNESS_REVIEW.md`
- `docs/HARNESS_REVIEW_V3.md`
- `docs/HARNESS_REVIEW_V4.md`
- `docs/Harness_Refine_Plan.md`
- `docs/Harness_Refine_Plan_Feedback.md`
- `docs/Harness_Refine_Plan_v2.md`는 v5 승인 전까지 현재 위치 유지. v5 승인 후 archive 이동 여부 결정.

archive 위치:
- `docs/archive/harness/`

archive 정책:
- 파일명은 원래 이름을 유지한다.
- 각 archive 파일 맨 위에 다음 헤더를 추가한다.

```markdown
> SUPERSEDED: See `docs/HARNESS_REVIEW_V5.md`.
```

삭제하지 않는 이유:
- 리뷰 히스토리 보존
- plan-stage 결정 근거 추적

---

## 6. v5 작성 순서

1. `docs/HARNESS_REVIEW_V5.md` 생성
2. v5에 이 문서의 결정 사항을 단일 적용 계획으로 통합
3. v5 자체 적대적 리뷰 1회 수행
4. HIGH 발견 시 v5 문서 보완 후 재리뷰
5. clean 또는 사용자 명시 승인 후 실제 적용

v5 필수 포함:
- 자동 로드 축소
- `sot: self` 금지
- metadata 분리
- `validate`
- `sync-status`
- complete strict atomicity
- impl review non-empty gate
- deny-list 우선 + whitelist fallback stage 정책
- `{task}` placeholder 치환
- git status 상태별 처리
- 구버전 archive 정책

---

## 7. 수용 기준

| 항목 | 기준 |
|---|---|
| 자동 로드 | `UI_GUIDE.md`는 비-UI phase 시작 시 자동 read되지 않음 |
| phase SoT | 모든 로컬 phase가 실제 경로 `sot` 보유 |
| self 금지 | `rg 'sot:\s*self' phases/mvp -g 'phase*.md'` 결과 없음 |
| metadata | `active_revision`은 metadata에만 존재, status에는 없음 |
| validate | `python scripts/execute.py mvp validate` 통과 |
| sync-status | reset 없이 phase/status 불일치 복구 가능 |
| complete atomicity | commit 실패/중단 시 status만 completed로 남지 않음 |
| review gate | `phaseNN-impl-review.md` 없거나 비어 있으면 complete 불가 |
| Godot metadata | `**/*.uid`, `**/*.import` 자동 stage 가능 |
| Python helper | `scripts/**` 변경이 v5 적용 commit을 막지 않음 |
| UI assets | runtime asset 디렉토리 변경이 UI phase를 막지 않음 |
| design handoff | `docs/design_handoff/**`는 기본 자동 stage 제외 |
| rename/copy | R/C 상태는 자동 stage하지 않고 중단 |
| 문서 drift | CLAUDE.md에 phase count 숫자 중복 없음 |

---

## 8. 자체 적대적 리뷰

### Round 1 Findings

#### HIGH 1. `docs/design_handoff/**` deny와 `docs/**/*.md` whitelist의 충돌

문제:
- deny-list가 우선이라는 원칙이 있으므로 최종 정책은 안전하다.
- 하지만 v5 구현자가 whitelist만 보고 `docs/design_handoff/README.md`까지 stage할 수 있다.

보완:
- v5에는 "deny-list가 whitelist보다 항상 우선"을 구현 규칙으로 명시한다.
- stage 후보 계산 순서는 `changed -> deny 제거/차단 -> whitelist 필터`로 고정한다.

#### HIGH 2. `sot_aux`에 `docs/design_handoff/README.md`를 넣으면 read 계약과 stage 계약이 혼동될 수 있음

문제:
- `sot_aux`는 read 계약이고 whitelist/deny는 stage 계약이다.
- 같은 파일이 read 대상이면서 stage deny 대상일 수 있어 혼란 가능.

보완:
- v5에서 read policy와 stage policy를 별도 섹션으로 분리한다.
- `docs/design_handoff/README.md`는 read 가능하지만 자동 stage는 deny된다고 명시한다.

#### MEDIUM 1. `.claude/settings.local.json` 자동 stage 위험

문제:
- local 설정 파일은 보통 개인 환경 파일일 수 있다.

보완:
- `.claude/settings.local.json`은 whitelist에서 제거한다.
- 필요한 경우 별도 수동 stage로만 허용한다.

#### MEDIUM 2. `addons/**`는 외부/서드파티 코드가 섞일 수 있음

문제:
- project plugin을 phase 산출물로 추가할 수 있지만, 외부 addon 전체 자동 stage는 위험할 수 있다.

보완:
- `addons/**`는 whitelist에 유지하되, 100개 이상 파일 변경 또는 총 staged 크기 임계값 초과 시 중단한다.
- v5에 "large change guard"를 추가한다.

#### LOW 1. `docs/archive/harness/` 이동 자체가 docs whitelist에 걸림

문제 없음:
- archive 이동은 v5 적용 phase 산출물이므로 허용된다.
- 다만 R/C rename 상태는 중단 정책이라 archive 이동은 delete+add로 처리하거나 명시 stage가 필요하다.

보완:
- archive 이동은 v5 적용 중 수동 stage 또는 `sync/archive` 별도 commit으로 분리할 수 있다고 명시한다.

### Round 1 반영

위 findings를 반영해 본 문서의 최종 정책을 다음처럼 보완한다.

추가 결정:
- deny-list는 whitelist보다 항상 우선한다.
- read policy와 stage policy는 별개다.
- `.claude/settings.local.json`은 자동 stage whitelist에서 제외한다.
- `addons/**` 등 대량 변경 가능 디렉토리는 large change guard 적용 대상이다.
- archive 이동은 rename 자동 stage 금지 정책 때문에 별도 commit 또는 수동 stage가 가능하다.

---

## 9. 최종 보정 정책

v5에 반드시 추가한다.

### 9.1 stage 후보 계산 순서

```text
changed files
→ normalize path
→ deny-list match이면 block
→ R/C status이면 block
→ whitelist match이면 stage candidate
→ 나머지는 block
```

### 9.2 local settings 제외

자동 stage whitelist에서 제외:
- `.claude/settings.local.json`

허용:
- `.claude/settings.json`
- `.claude/commands/**`
- `.claude/agents/**`
- `.claude/hooks/**`

### 9.3 large change guard

다음 조건 중 하나면 complete 중단:
- stage 후보가 100개 초과
- stage 후보 중 단일 파일이 5MB 초과
- stage 후보 총 크기가 25MB 초과

예외:
- 사용자가 명시 승인한 asset import phase에서는 한시적으로 완화 가능
- 완화 옵션은 v5에서는 구현하지 않고 수동 stage/commit으로 처리한다.

### 9.4 archive 이동

구버전 계획 문서 archive 이동은 다음 중 하나로 처리한다.
- v5 적용 commit에 delete+add로 포함
- 별도 `docs: archive superseded harness plans` commit으로 분리

rename 상태(`R`) 자동 stage는 여전히 금지한다.
