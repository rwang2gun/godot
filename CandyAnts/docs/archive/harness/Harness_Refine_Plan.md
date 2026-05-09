> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness Refine Plan

작성일: 2026-05-10
입력 문서:
- `docs/HARNESS_REVIEW_V4.md`
- `docs/Harness_Feedback_v4.md`

상태: v4 plan-stage feedback 반영 결정안

> 결론: v4의 방향은 유지하되 그대로 적용하지 않는다. feedback의 HIGH 4건을 모두 해소한 v5 계획으로 재작성한 뒤 적용한다.

---

## 1. 채택 결정

`Harness_Feedback_v4.md`의 추천 조합을 채택한다.

| 항목 | 결정 |
|---|---|
| `.uid` 자동 생성 메타 파일 정책 | `execute.py complete`에서 안전 화이트리스트 자동 stage |
| staging 흐름 | 별도 수동 staging 단계 없이 `complete` 내부에서 자동 처리 |
| `sot: self` | 폐지 |
| `local_phase_count` | metadata hard-code 폐지, validate가 동적 glob으로 계산 |
| v2/v3/v4 누적 정리 | v5 통합 후 구버전 계획 문서는 archive 또는 superseded 처리 |

---

## 2. v4에서 보존할 것

다음 설계는 유지한다.

- 자동 로드 축소: `docs/UI_GUIDE.md`, `REVISION_*.md`, `README.md`, `status.json`, `docs/design_handoff/`는 자동 로드하지 않는다.
- phase-local SoT: 각 phase frontmatter의 `sot`가 해당 phase의 1차 SoT를 결정한다.
- 구조 메타데이터 분리: `active_revision`은 `status.json`이 아니라 `metadata.json`에 둔다.
- `execute.py validate`: phase 계약을 기계적으로 검증한다.
- 롤백 가능성: frontmatter/metadata 추가는 비파괴 변경으로 둔다.

---

## 3. v4에서 바꿀 것

### R1. staged-only complete 폐기

v4의 staged-only complete는 적용하지 않는다.

이유:
- Godot `.uid` 파일은 phase 산출물의 일부다.
- untracked `.uid`가 생길 때마다 complete가 중단되면 하네스가 매 phase마다 마찰을 만든다.
- 수동 staging은 누락 위험이 높고, 누락 시 다른 머신/CI에서 import 문제가 생길 수 있다.

대신 `complete`는 안전 화이트리스트 기반 자동 stage를 수행한다.

### R2. 자동 stage 화이트리스트 도입

`execute.py complete`는 `git add -A` 대신 허용된 경로/확장자만 stage한다.

화이트리스트는 "stage 가능 후보"일 뿐, 무조건 커밋해도 되는 전체 목록이 아니다. `complete`는 whitelist 밖 변경이 있으면 중단하고, whitelist 안 변경도 현재 phase 산출물인지 판단할 수 있도록 목록을 출력한다.

1차 허용 범위:
- `scripts/**/*.gd`
- `scripts/**/*.gd.uid`
- `tests/**/*.gd`
- `tests/**/*.gd.uid`
- `tests/**/*.tscn`
- `scenes/**/*.tscn`
- `data/**/*.tres`
- `project.godot`
- `phases/{task}/phase*.md`
- `phases/{task}/plans/*.md`
- `phases/{task}/reviews/*.md`
- `phases/{task}/status.json`
- `phases/{task}/metadata.json`
- `.claude/commands/*.md`
- `CLAUDE.md`
- `docs/*.md`

명시 제외:
- repo 외부 파일
- 임시 파일
- 대용량 design handoff 원본
- whitelist 밖 untracked 파일

정책:
- whitelist 안 변경은 자동 stage한다.
- whitelist 밖 변경이 있으면 complete를 중단하고 목록을 출력한다.
- whitelist 밖 파일이 phase 산출물이라면 whitelist를 먼저 갱신한다.
- whitelist 안 변경이라도 phase와 무관한 파일이 섞일 수 있으므로 `complete` 출력에는 staged file 목록을 반드시 포함한다.
- 장기적으로 phase manifest(`commit_paths`)가 도입되면 whitelist는 fallback으로만 사용한다.

### R2-1. complete 순서 보정

현재 `execute.py complete`는 status를 completed로 저장한 뒤 `git add -A`와 commit을 수행한다. 이 순서를 그대로 두면 preflight나 commit 실패 시 `status.json`만 완료 상태가 되는 부분 완료가 생긴다.

v5 구현에서는 순서를 바꾼다.

1. phase 존재/상태 확인
2. verify 실행
3. impl review 파일 존재 확인
4. whitelist preflight 실행
5. whitelist 자동 stage
6. staged file 목록 출력
7. staged diff가 없으면 중단
8. status를 completed로 갱신하고 `status.json` stage
9. commit 실행
10. commit 실패 시 status 변경을 원복하거나, 최소한 실패를 크게 출력하고 다음 phase 진행 금지

핵심 원칙:
- commit 가능성이 확인되기 전에는 `status.json`을 completed로 저장하지 않는다.
- `status.json` 완료 표시와 phase 산출물 commit은 같은 commit에 들어간다.

### R2-2. review artifact preflight

`complete`는 구현 리뷰 산출물 없이 통과하면 안 된다.

필수 파일:
- `phases/{task}/reviews/phaseNN-impl-review.md`

권장 확인:
- 파일 존재
- 비어 있지 않음
- `Self-Review` 또는 `adversarial-review` 관련 헤더/본문이 포함됨

주의:
- plan-stage review 파일(`phaseNN-review.md`)은 phase에 따라 이미 과거에 존재할 수 있으므로 validate 대상은 아니지만, 신규 phase에서는 harness 절차가 생성해야 한다.
- impl review 파일이 없으면 `complete`는 중단한다.

### R3. `sot: self` 폐지

모든 phase는 실제 파일 경로를 `sot`에 적는다.

권장 매핑:

| Phase | sot | sot_aux |
|---|---|---|
| 1 | `docs/PRD.md` | `[docs/ARCHITECTURE.md, docs/ADR.md]` |
| 2~4 | `docs/PRD.md` | `[docs/ARCHITECTURE.md, docs/ADR.md]` |
| 5 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 6 | `docs/GAME_FLOW_PROPOSAL_V5.md` | `[phases/mvp/REVISION_2026-05-09.md]` |
| 7 | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 8 | `docs/INPUT_PLAN.md` | `[]` |
| 9~13 | `docs/UI_GUIDE.md` | `[docs/INPUT_PLAN.md]` |
| 14~20 | `docs/PRD.md` | `[docs/ARCHITECTURE.md]` |

validate 규칙:
- `sot: self`는 실패 처리한다.
- `sot` 경로는 반드시 존재해야 한다.
- `sot_aux` 경로도 모두 존재해야 한다.

### R4. `local_phase_count` hard-code 제거

`metadata.json`에서 `local_phase_count`를 제거한다.

권장 `metadata.json`:

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

validate는 `phase*.md` glob 결과를 기준으로 동적 계산한다.

### R5. status sync 명령 추가

validate가 `status.json`과 실제 phase 파일 목록 불일치를 발견했을 때 reset만 권하면 진행 데이터가 유실된다.

신규 명령:

```bash
python scripts/execute.py mvp sync-status
```

정책:
- 기존 phase 항목은 `file` 기준으로 보존한다.
- 새 phase 파일은 pending으로 추가한다.
- 삭제된 phase 파일은 기본적으로 status에서 제거하지 않고 경고한다.
- 의도적 삭제를 반영할 때만 명시 옵션을 쓴다.
- 완료된 phase의 `started_at`, `completed_at`, `duration_seconds`는 보존한다.

명시 옵션:

```bash
python scripts/execute.py mvp sync-status --prune-missing
```

`--prune-missing` 정책:
- missing phase가 completed면 중단하고 사용자 확인을 요구한다.
- missing phase가 pending이면 status에서 제거 가능하다.
- renumbering이 의심되면 prune하지 말고 phase 파일명/status 매핑을 먼저 수정한다.

### R6. validate 호출 시점 명시

validate는 매 phase마다 필수로 돌리지 않는다.

호출 시점:
- 새 세션에서 `/harness {task}` 시작 직후 1회
- phase 파일 추가/삭제/이름 변경 후 1회
- metadata 또는 harness/execute.py 수정 후 1회
- complete 실패 원인이 phase 계약 불일치일 때 1회

---

## 4. v5 문서 작성 지침

v5는 v4를 patch하지 않고 단일 적용 계획으로 다시 쓴다.

반드시 포함할 내용:
- v4 feedback의 HIGH 4건 해결 방식
- `complete` 자동 stage whitelist
- `complete` 상태 갱신/commit 순서 보정
- impl review artifact preflight
- `sot: self` 금지
- metadata에서 `local_phase_count` 제거
- `validate`와 `sync-status` 명령 정의
- `sync-status --prune-missing` 정책
- `sot_aux` 파싱 방식
- 구버전 계획 문서 정리 정책

제외할 내용:
- v3를 운영 구조의 일부처럼 취급하는 표
- `status.json`을 자동 로드 KPI에 포함하는 표현
- "현재 23 phase / 로컬 20개" 같은 숫자를 CLAUDE.md에 직접 반복하는 문구

---

## 5. 구현 계획

### Step 1. 문서 정리

- `docs/HARNESS_REVIEW_V5.md` 생성
- v2/v3/v4 문서는 archive 또는 superseded 처리
- `CLAUDE.md`의 phase 수 문구는 숫자 대신 metadata 참조로 변경

권장 문구:

```text
phase/page_id 매핑은 `phases/mvp/notion-phase-ids.json`과 `phases/mvp/metadata.json`을 참조한다. 숫자를 CLAUDE.md에 중복 기록하지 않는다.
```

### Step 2. harness.md 수정

- 자동 로드에서 `UI_GUIDE.md` 제거
- phase 생성 템플릿에 `sot`, `sot_aux` 추가
- `/harness` 시작 시 `execute.py validate` 1회 실행 지시
- `next` 후 `sot`/`sot_aux` read 지시
- `complete`는 whitelist 자동 stage 후 커밋한다고 명시

### Step 3. metadata 생성

- `phases/mvp/metadata.json` 생성
- `local_phase_count`는 넣지 않음
- `active_revision`만 구조 포인터로 유지

### Step 4. phase frontmatter 갱신

- 로컬 phase 20개에 `sot`/`sot_aux` 추가
- `self` 사용 금지
- `sot_aux: []` 형식을 기본으로 사용

### Step 5. execute.py 개선

추가 명령:
- `validate`
- `sync-status`

complete 변경:
- `git add -A` 제거
- whitelist 자동 stage 추가
- whitelist 밖 변경이 있으면 중단
- impl review 파일이 없으면 중단
- commit 가능성 확인 전에는 status를 completed로 저장하지 않음
- stage 후 staged diff가 없으면 중단
- commit은 staged 변경만 대상으로 실행

frontmatter 파싱:
- 외부 의존성 없이 간단 parser 유지
- `sot_aux: []`
- `sot_aux: [docs/A.md, docs/B.md]`
- 빈 값 또는 누락은 빈 배열로 처리

### Step 6. 검증

```bash
python scripts/execute.py mvp validate
rg -L "^sot:" phases/mvp -g 'phase*.md'
python scripts/execute.py mvp next
```

complete 안전성 검증:
- whitelist 안 `.uid` 파일은 자동 stage되는지 확인
- whitelist 밖 임시 파일이 있으면 complete가 중단되는지 확인
- impl review 파일이 없으면 complete가 중단되는지 확인
- commit 실패 시 `status.json`만 completed로 남지 않는지 확인

---

## 6. 수용 기준

| 항목 | 기준 |
|---|---|
| 자동 로드 | `UI_GUIDE.md`는 비-UI phase 시작 시 자동 read되지 않음 |
| phase SoT | 20개 로컬 phase 모두 실제 경로 `sot` 보유 |
| self 금지 | `rg "sot:\\s*self" phases/mvp -g 'phase*.md'` 결과 없음 |
| metadata | `active_revision`은 metadata에만 존재, status에는 없음 |
| validate | `python scripts/execute.py mvp validate` 통과 |
| sync-status | reset 없이 phase/status 불일치 복구 경로 존재 |
| complete | `.uid`는 자동 stage, whitelist 밖 파일은 중단 |
| complete atomicity | commit 실패/중단 시 status만 completed로 남지 않음 |
| review gate | impl review 파일 없이는 complete 불가 |
| 문서 drift | CLAUDE.md에 phase count 숫자 중복 없음 |

---

## 7. 보류 항목

- phase manifest 기반 `commit_paths`: whitelist 방식이 부족해질 때 재검토한다.
- Notion page_id null 검증: phase 6 page 생성 운영 이슈로 별도 처리한다.
- `pyyaml` 의존성 도입: 현재는 단순 frontmatter 스키마만 필요하므로 보류한다.

---

## 8. 다음 산출물

이 문서를 기준으로 다음 파일을 만든다.

- `docs/HARNESS_REVIEW_V5.md`

v5가 승인되면 실제 코드/문서 변경을 진행한다.
