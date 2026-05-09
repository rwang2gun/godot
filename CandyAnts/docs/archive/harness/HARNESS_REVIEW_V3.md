> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness 명령 컨텍스트 효율 개편 계획 (v3)

작성일: 2026-05-10
대상: `.claude/commands/harness.md`, `phases/mvp/phase*.md`, `phases/mvp/status.json`, `scripts/execute.py`
상태: v2 리뷰 발견 사항 반영본

> v3는 v2의 핵심 방향(자동 로드 축소 + phase-local SoT)을 유지하되, 리뷰에서 발견된 실행 리스크 3건을 보정한다.
> - H1: `harness.md`의 phase 생성 템플릿에 `sot`/`sot_aux`가 없으면 새 phase가 다시 비결정적으로 생성됨.
> - H2: "22 phase 일괄 갱신" 표현이 실제 로컬 phase 파일 20개와 불일치함.
> - H3: `status.json.active_revision`은 `execute.py reset`/재초기화 시 사라질 수 있음.

---

## 1. 목표

세션 시작 시 자동으로 읽는 컨텍스트를 줄이되, 각 phase 진입 시 필요한 1차 SoT는 frontmatter에서 결정적으로 찾게 만든다.

핵심 원칙:
- 공통 자동 로드는 `PRD / ARCHITECTURE / ADR / CLAUDE.md`까지만 유지한다.
- UI 문서, revision 문서, README, status는 필요할 때 명시 read한다.
- phase별 1차 SoT는 해당 phase 파일 frontmatter의 `sot` 필드에 둔다.
- 새 phase 생성 템플릿도 같은 스키마를 강제해 미래 drift를 막는다.

---

## 2. 진단

### F1. UI_GUIDE 자동 로드 dead context - HIGH
- 다음 진입 phase 6/7/8은 모두 UI 무관이다.
- 전체 MVP 20개 로컬 phase 중 UI track은 phase 9~13, 5개뿐이다.
- 비-UI 세션에서 `docs/UI_GUIDE.md` 약 450줄이 dead context가 된다.

### F2. 1차 SoT 자동 로드 누락 - HIGH
- 현 harness는 공통 문서만 자동 로드한다.
- phase 6의 `docs/GAME_FLOW_PROPOSAL_V5.md` 같은 phase별 1차 SoT는 모델이 본문에서 찾아야 한다.
- 이 방식은 누락과 cross-reference 오류 가능성이 있다.

### F3. 생성 템플릿이 새 스키마를 보장하지 않음 - HIGH
- v2는 기존 phase 파일에 `sot`를 추가하지만, `.claude/commands/harness.md`의 phase 생성 템플릿 갱신을 명시하지 않았다.
- 템플릿이 그대로면 다음 task/phase 생성 시 `sot` 없는 파일이 재생산된다.

### F4. status 재초기화가 active_revision을 보존하지 않음 - MEDIUM
- `scripts/execute.py reset`은 `status.json`을 삭제한다.
- `init_status()`는 현재 `active_revision`을 생성하지 않는다.
- `status.json.active_revision`을 장기 포인터로 쓰려면 초기화 경로까지 같이 고쳐야 한다.

---

## 3. 측정값

자동 로드 = 세션 시작 시 harness가 강제 read하는 파일. 모델이 phase 진입 후 frontmatter를 보고 명시 read하는 SoT는 자동 로드에 포함하지 않는다.

| 항목 | 현재 | v2/v3 적용 후 |
|---|---:|---:|
| 자동 로드 줄 수 | 약 643 | 약 195 |
| 변화 | - | 약 -448줄, -70% |
| 비-UI phase dead context | `UI_GUIDE.md` 약 450줄 | 없음 |
| phase별 SoT 결정성 | 본문 검색/모델 판단 | frontmatter `sot` |
| 새 phase 생성 안정성 | 템플릿에 `sot` 없음 | 템플릿에 `sot` 필수 |

내역:
- 현재 643 = PRD(22) + ARCHITECTURE(70) + ADR(46) + UI_GUIDE(450) + CLAUDE.md(55)
- 적용 후 195 = PRD(22) + ARCHITECTURE(70) + ADR(46) + CLAUDE.md(55) + phase frontmatter 노출분

---

## 4. 변경 명세

### 4.1 `.claude/commands/harness.md` - 자동 로드

§1을 다음 방향으로 수정한다.

```diff
 ### 1. docs/ 문서를 전부 읽는다 (자동)
 순서대로 반드시 읽기:
 - `docs/PRD.md` — 뭘 만드는지
 - `docs/ARCHITECTURE.md` — 어떻게 만드는지
 - `docs/ADR.md` — 왜 이렇게 만드는지
-- `docs/UI_GUIDE.md` (있으면)
+
+다음 파일은 자동 로드하지 않는다 (필요 시 명시 read):
+- `docs/UI_GUIDE.md` — UI track phase(9~13) 진입 시
+- `phases/{task}/REVISION_*.md` — phase 구조 결정 맥락이 필요할 때만
+- `phases/{task}/README.md` — 7단계 표준 절차 확인 시
+- `phases/{task}/status.json` — execute.py가 출력하므로 직접 read 보통 불요
 
 `docs/references/`는 추가 컨텍스트로만 참조, 강제 아님.
```

### 4.2 `.claude/commands/harness.md` - phase 생성 템플릿

v3 필수 보정 사항. §4의 phase 파일 구조 템플릿에 `sot`와 `sot_aux`를 추가한다.

```diff
 각 phase 파일 구조:
 ```markdown
 ---
 name: {phase 이름}
 duration_estimate: {예상 초}
 verify: {선택 — 검증 명령}
+sot: {필수 — 1차 SoT 파일 경로, 자기 자신이면 self}
+sot_aux: {선택 — 보조 SoT 파일 경로 배열}
 ---
```

추가 규칙:
- `sot`는 새 phase 생성 시 비워두지 않는다.
- 아직 결정 전인 post-MVP phase는 로컬 phase 파일을 만들지 않는다.
- post-MVP phase 파일을 생성하는 순간 `sot`도 같이 결정한다.

### 4.3 `.claude/commands/harness.md` - execute.py 흐름

§5에 frontmatter lookup과 codex 리뷰 흐름을 명시한다.

```diff
 ### 5. execute.py 실행 (자동)
 `python scripts/execute.py {task-name}`로 상태 확인 후 Phase 진행:
-- `python scripts/execute.py {task-name} next` — 다음 pending Phase의 내용 출력
-- 해당 Phase 작업 수행
-- `python scripts/execute.py {task-name} complete {N}` — 완료 표시 + 자동 커밋
+- `python scripts/execute.py {task-name} next` — 다음 pending Phase 파일을 frontmatter 포함 출력
+  - frontmatter `sot:` 필드의 경로를 즉시 명시 read (해당 phase 1차 SoT)
+  - frontmatter `sot_aux:` 필드(있으면) 보조 SoT도 read
+- 해당 Phase 작업 수행. CLAUDE.md §개발 프로세스의 plan/impl stage 정책 준수.
+  특히 `complete` 직전 `/codex:adversarial-review` 의무 + impl stage 자체 적대적 리뷰 사이클.
+- `python scripts/execute.py {task-name} complete {N}` — 완료 표시 + 자동 커밋
 - 모든 Phase 완료까지 반복
```

### 4.4 로컬 phase 파일 frontmatter

현재 로컬 MVP phase 파일은 20개다.

갱신 대상:
- `phases/mvp/phase01-bootstrap.md` ~ `phase20-stage10-bomber-polish.md`

갱신하지 않는 대상:
- post-MVP 21~23은 현재 README/Notion 매핑에만 있고 로컬 phase 파일이 없다.
- 따라서 이번 일괄 갱신 대상이 아니다.
- 향후 post-MVP phase 파일을 실제 생성할 때 `sot`를 즉시 채운다.

신규 frontmatter 표준:

```yaml
---
name: {phase 이름}
duration_estimate: {예상 초}
verify: {선택 — 검증 명령}
sot: {필수 — 1차 SoT 파일 경로, 자기 자신이면 self}
sot_aux: {선택 — 보조 SoT 파일 경로 배열}
---
```

Phase별 매핑:

| Phase | sot | sot_aux |
|---|---|---|
| 1~4 (core, 완료) | `self` | - |
| 5 (input-action-foundation, 완료) | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 6 (game-flow-foundation) | `docs/GAME_FLOW_PROPOSAL_V5.md` | `[phases/mvp/REVISION_2026-05-09.md]` |
| 7 (input-pad-cursor) | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 8 (input-pause-step) | `docs/INPUT_PLAN.md` | - |
| 9~13 (UI track) | `docs/UI_GUIDE.md` | `[docs/INPUT_PLAN.md]` |
| 14~20 (stage track) | `docs/PRD.md` | `[docs/ARCHITECTURE.md]` |

YAML 표기 규칙:
- 단일 경로는 문자열로 쓴다. 예: `sot: docs/INPUT_PLAN.md`
- 보조 경로는 YAML inline array로 쓴다. 예: `sot_aux: [docs/INPUT_MAPPING.md]`
- 보조 SoT가 없으면 `sot_aux: []` 또는 필드 생략 중 하나로 통일한다. 권장: `sot_aux: []`

### 4.5 `phases/mvp/status.json`와 `scripts/execute.py`

`active_revision`을 status에 둘 경우 초기화 경로까지 같이 보정한다.

`phases/mvp/status.json` 현재 파일에 추가:

```json
{
  "task": "mvp",
  "active_revision": "phases/mvp/REVISION_2026-05-09.md",
  "...": "..."
}
```

`scripts/execute.py`의 `init_status()`에도 기본값을 추가한다.

```diff
     status = {
         "task": task,
+        "active_revision": "phases/mvp/REVISION_2026-05-09.md" if task == "mvp" else None,
         "started_at": datetime.now().isoformat(timespec="seconds"),
         "completed_at": None,
         "phases": phases,
     }
```

주의:
- 이 값은 자동 로드 대상이 아니다.
- 모델이 phase 구조 결정 맥락이 필요할 때만 status를 read하고, `active_revision`이 가리키는 파일을 명시 read한다.
- 향후 task가 늘어날 경우 task별 revision 포인터가 필요할 수 있다. 그때는 `phases/{task}/metadata.json` 분리를 검토한다.

### 4.6 `scripts/execute.py next`

현재 구현은 `fp.read_text(encoding="utf-8")`로 phase 파일 전체를 출력하므로 frontmatter가 이미 노출된다.

따라서 v3 적용 시 필수 수정은 아니다.

검증만 수행:
- `python scripts/execute.py mvp next` 출력에 `---`, `sot:`, `sot_aux:`가 보이는지 확인한다.
- 만약 향후 본문만 출력하도록 바뀐다면 이 검증이 실패해야 한다.

---

## 5. 적용 순서

1. `docs/HARNESS_REVIEW_V3.md` 사용자 컨펌
2. `.claude/commands/harness.md` §1 자동 로드 수정
3. `.claude/commands/harness.md` §4 phase 생성 템플릿에 `sot`/`sot_aux` 추가
4. `.claude/commands/harness.md` §5 execute 흐름에 frontmatter lookup + codex 리뷰 흐름 추가
5. 로컬 phase 파일 20개에 `sot`/`sot_aux` 추가
6. `phases/mvp/status.json`에 `active_revision` 추가
7. `scripts/execute.py init_status()`에 `active_revision` 기본값 추가
8. `python scripts/execute.py mvp next` 출력에서 frontmatter 노출 확인
9. 별도 커밋 1개로 묶음

권장 커밋 메시지:

```text
chore: slim harness autoload and add phase sot metadata
```

---

## 6. 검증 기준

| 항목 | 기준 | 측정 방법 |
|---|---|---|
| 자동 로드 줄 수 | 200줄 이하 | 새 세션 시작 직후 강제 read 파일 합산 |
| UI dead context | 비-UI phase에서 `UI_GUIDE.md` 자동 read 없음 | `/harness mvp` 첫 turn 관찰 |
| phase SoT 결정성 | `next` 출력에서 `sot` 확인 후 해당 SoT 명시 read | `python scripts/execute.py mvp next` |
| 새 phase 생성 안정성 | harness 템플릿이 `sot` 필수 포함 | `.claude/commands/harness.md` grep |
| active_revision 보존 | reset 후 재초기화해도 필드 존재 | 임시 브랜치 또는 백업 후 `reset` 시뮬레이션 |
| 로컬 phase 갱신 범위 | 20개 phase 파일 모두 `sot` 존재 | `rg -L "^sot:" phases/mvp/phase*.md` |

---

## 7. 롤백 절차

모든 변경은 비파괴다.

1. 단일 커밋 revert로 `.claude/commands/harness.md`, phase frontmatter, `status.json`, `execute.py` 변경을 되돌린다.
2. phase 파일에 남은 `sot`/`sot_aux`는 코드 동작에 직접 영향이 없다.
3. `active_revision`도 자동 로드 대상이 아니므로 잔존해도 실행에는 영향이 없다.

---

## 8. v2 대비 차이

| 측면 | v2 | v3 |
|---|---|---|
| phase 생성 템플릿 | 갱신 누락 | `sot`/`sot_aux` 필수 반영 |
| phase 파일 수 표현 | 22 phase 일괄 갱신 | 로컬 20개 갱신, post-MVP 21~23은 파일 생성 시 결정 |
| `active_revision` | status 수동 추가 | status + `init_status()` 기본값 동시 보정 |
| `execute.py next` | 수정 가능성 점검 | 현재 전체 출력 확인, 검증 항목으로 유지 |
| 자동 로드 절감 | 유지 | 유지 |
