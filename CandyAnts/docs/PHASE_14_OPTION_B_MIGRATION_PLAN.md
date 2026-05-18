# Phase 14~20 옵션 B v0.2 마이그레이션 계획서

**작성 일자**: 2026-05-18
**상태**: Round 6 반영본 (Python launcher preflight + 모든 python 호출을 `& $Python` 변수 호출로 전환 + PROPOSAL §4 cross-ref 정정) — Round 7 진입 직전
**근거 문서**: `docs/PHASE_14_OPTION_B_PROPOSAL.md` (옵션 B 제안서. 버전 0.2는 frontmatter로 관리)
**관련 문서**:
- `phases/mvp/README.md` — 표준 7단계 절차
- `phases/mvp/status.json` — 현 진행 ledger
- `CLAUDE.md` — Notion 동기화·리뷰 정책

> 본 문서는 `docs/PHASE_14_OPTION_B_PROPOSAL.md`에 정리된 옵션 B 개정안을 `phases/mvp/` 폴더와 `status.json`에 실제로 반영하는 마이그레이션 작업 계획서다. 미래의 본인이 본 작업을 재개하거나 검수할 때 1차 참조한다. 본 문서 자체는 계획서이며, 본 문서 작성 시점에는 status.json·phase 명세 파일에 변경이 없다.
>
> **선행 조건**: `docs/PHASE_14_OPTION_B_PROPOSAL.md`가 현재 worktree에 실제 파일로 존재해야 한다. 해당 파일이 없으면 phase 명세 파일 작성·status 재구성·review 진행을 시작하지 않는다.

---

## 0. 작업 컨텍스트

- **개발 모델**: 1인 + AI 페어 협업(Claude Code + Codex). 본인은 결정·검수·통합, AI는 명세·코드·리뷰 분담. 여가 시간 개발이라 wall-clock 추정은 무의미(`PROPOSAL.md` §0.7.0).
- **대상 플레이어**: 어린 플레이어. 사망 연출·폭력 묘사 전면 배제. 페일은 "사탕 손실"로 통일(§0).
- **본 작업 위치**: 옵션 B 확정 절차(`PROPOSAL.md` §8) 중 1번 잔여 결정 확정 직후, 2번 PROPOSAL.md 1차 persist + 3번 codex review + 5번 phase 파일 재구성을 commit 시퀀스로 묶는 단계.
- **본 plan에서 손대지 않는 것**: 실제 코드, `notion-phase-ids.json`, phase 1~13 산출물. (PROPOSAL.md는 Commit 1에서 새로 작성, Commit 2에서 review 반영 시 v0.3 frontmatter 갱신 가능.)
- **선행 환경 요구사항** — Python launcher가 PowerShell PATH에 있어야 한다. 본 plan의 모든 검증·마이그레이션 명령(`scripts/execute.py`, `scripts/check_tone_policy.py`)은 Python 호출에 의존. PowerShell 세션 시작 시 다음 preflight를 1회 실행해 `$Python` 변수를 설정한다 — 모든 후속 명령은 `& $Python scripts/...` 형태로 이 변수를 통해 호출한다.

  ```powershell
  $Python = (Get-Command python -ErrorAction SilentlyContinue).Source
  if (-not $Python) {
      $Python = (Get-Command py -ErrorAction SilentlyContinue).Source
  }
  if (-not $Python) {
      throw "Python launcher not found on PATH. Install Python or activate venv before migration."
  }
  & $Python --version  # sanity check
  ```

  preflight 실패 시 Commit 1 self-review·Commit 3 phase 재구성·§6.x 검증 어떤 단계도 진입 금지.

---

## 1. 사용자 확정 사항

`PROPOSAL.md` §5의 잔여 결정 5건 처리 상태.

| 항목 | 결정 | 근거 |
|---|---|---|
| **§5.1** Phase 14 분할 14a/14b | **분할 채택** | `PROPOSAL.md` §7.1 정수 id 정책 + 정착에 능력 전이 시스템 포함으로 단일 phase는 무겁다 |
| **§5.2** Phase 17 (파괴) 분할 | **17a/17b 분할 채택** | 식물 지형 신설 부담 분리 + codex HIGH 위험 회피. 결과: 7 phase 구성 |
| **§5.3** 분배자 사탕 UX | **A안** (경고 없이 정착 허용) | `PROPOSAL.md` §3.1.3. 100% 도달 = 회수 동선 설계(§0.7.5) |
| **§5.4** 상대 무게 재산정 | **잠정치 유지** | §0.7.0 정책. 각 phase plan 단계에서 재조정. wall-clock 환산 금지 |
| **§5.5** Phase 1~13 콘텐츠 재설계 | **별도 트랙 분리 (a)** | 본 옵션 B 작업 범위 외. `codex-worklog/` 트랙 또는 v1.1 phase로 후속 처리 |

phase 작업과 직접 충돌하는 잔여 결정은 §5.1·§5.2 두 건이었고, 위 결정으로 모두 해소.

---

## 2. 새 phase 매핑 (7 phase)

### 2.1 id 정책
- `execute.py:462,654`는 정수 id만 허용. 14a/14b/17a/17b는 README 라벨로만 표기.
- `execute.py:111`이 `sorted(glob("phase*.md"))`로 파일명 알파벳 순 정렬하여 id 자동 부여 → 파일명 prefix가 `phase14-`, `phase15-`, … 형식이면 id 14, 15, … 자동 매핑.
- `name`(슬러그)은 frontmatter에서 결정.

### 2.2 매핑 표

| id | 라벨 | 파일명 | 슬러그 | 묶음 | 무게 잠정 |
|---|---|---|---|---|---|
| 14 | 14a | `phase14-mechanic-adaptation-traits.md` | `mechanic-adaptation-traits` | Climber + Floater(민들레씨 보유 트레잇) | 5400 |
| 15 | 14b | `phase15-mechanic-adaptation-settlement.md` | `mechanic-adaptation-settlement` | Blocker + 민들레씨 분배자 + 정착 시스템 + 능력 전이 | 7200 |
| 16 | 15  | `phase16-mechanic-creation.md` | `mechanic-creation` | Sand-mound(수직) + Bridge(수평) | 7200 |
| 17 | 16  | `phase17-mechanic-hazard.md` | `mechanic-hazard` | Water + 끈끈이 + 사탕 손실 페일 룰 | 7200 |
| 18 | 17a | `phase18-mechanic-destruction-earth.md` | `mechanic-destruction-earth` | Basher + Digger (흙 지형 동적 파괴) | 5400 |
| 19 | 17b | `phase19-mechanic-destruction-plant.md` | `mechanic-destruction-plant` | Cutter + 식물 지형 신규 클래스 | 5400 |
| 20 | 18  | `phase20-polish.md` | `polish` | Release Rate + 별 시스템 + 정산 UI + 사운드 hook + 피날레 | 9000 |

**합계(잠정)**: 46800. `PROPOSAL.md` §2.4 합계 그대로(17 분할로 분배만 재구성).

> **무게 수치 해석 주의**: 본 표의 무게는 phase 간 상대 비교용 잠정치다. 시간 단위로 환산하지 않는다(§0.7.0). 각 phase 진입 시 plan 단계에서 재조정 가능.

### 2.3 기존 status.json (stage 기반) → 옵션 B 매핑 (메카닉 기반)

| 기존 status.json (stage 기반) | 옵션 B + 17 분할 (메카닉 기반) | 변경 종류 |
|---|---|---|
| phase14 stage4-hazard-water | phase17 mechanic-hazard | 통합 + 내용 교체 (Water + 끈끈이, 톤 폴리시 반영) |
| phase15 stage5-basher | phase18 mechanic-destruction-earth | 통합 (Basher + Digger) |
| phase16 stage6-digger | (phase18에 통합됨) | 통합 흡수 |
| phase17 stage7-miner | — | **삭제** (Cutter로 대체. PROPOSAL `§1` 핵심 변경 표 / `§3.4.2` Cutter + 식물 지형 / `§5.2` 17 분할) |
| phase18 stage8-climber | phase14 mechanic-adaptation-traits | 통합 (Climber + Floater) |
| phase19 stage9-floater | (phase14에 통합됨) | 통합 흡수 |
| phase20 stage10-bomber-polish | phase20 polish | 내용 교체 (Bomber 삭제, 별 시스템·정산 UI·끈끈이 후처리 추가) |
| — | phase15 mechanic-adaptation-settlement | **신규** (Blocker + 민들레씨 분배자) |
| — | phase16 mechanic-creation | **신규** (Sand-mound + Bridge) |
| — | phase19 mechanic-destruction-plant | **신규** (Cutter + 식물 지형) |

요약: 기존 7개 → 새 7개. 1:1 rename 없음. **신규 작성 3 + 통합·내용 교체 rename 4**.

### 2.4 git mv 정책 — 사용하지 않는다

- `PROPOSAL.md` §7.2 결론: `git mv` 사용 안 함. 사유:
  - 새 파일과 기존 파일의 본문 유사도가 매우 낮음(톤 폴리시·신규 시스템·통합으로 거의 처음부터 작성).
  - git이 자동으로 rename 인식하지 않을 가능성 높음.
  - `execute.py:743-748`이 git rename 감지 시 complete를 hard reject. 본 작업은 `execute.py complete` 흐름이 아닌 일반 commit이지만 혼선 방지.
- **결론**: `git rm` + 새 파일 `git add` 패턴. history는 본 migration plan 문서와 README v4 개정 노트로 보존.

### 2.5 phase 명세 파일 frontmatter 표준

기존 phase14 frontmatter(`phase14-stage4-hazard-water.md:1-8`)와 동일 구조:

```yaml
---
name: <슬러그>
duration_estimate: <잠정 무게>
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---
```

`name`/`duration_estimate`는 §2.2 표대로. `docs/PRD.md`는 기존 프로젝트 최상위 SoT로 유지하되, 옵션 B 신규 메카닉·톤 폴리시는 `sot_aux`의 `docs/PHASE_14_OPTION_B_PROPOSAL.md`와 `phases/mvp/REVISION_2026-05-18-option-b.md`를 보조 SoT로 명시한다.

### 2.6 phase 명세 본문 표준

각 phase 본문은 다음 섹션을 포함(기존 phase14~20 패턴 + 옵션 B 반영):

1. **목표 1줄** — `PROPOSAL.md` §2.1 묶음 한 줄 요약.
2. **변경 대상** — 씬·스크립트·데이터 파일 목록 (가이드 수준). 상세는 각 phase 진입 시 `plans/phaseNN-plan.md`에서 채운다.
3. **검증 방법** — Stage 1~13 회귀 무영향 확인 + 신규 메카닉 동작 확인.
4. **엣지 케이스** — `PROPOSAL.md` §3 신규 시스템 예외 처리(§3.1.4, §3.2.3, §3.3.3) **요지만 1~2줄 인용**. TBD 본문을 그대로 복사하지 않는다.
5. **참조** — `docs/PHASE_14_OPTION_B_PROPOSAL.md` 해당 절 링크.
6. **톤 폴리시 주석** — §0.2 어휘 정책 준수 명시. 페일 어휘는 "사탕 손실", 상태는 "정착"·"임무 완수" 사용. 금지된 직접 API 호출·상태 정의는 사용하지 않는다.
7. **Open decisions before implementation** — 본 phase에 해당하는 PROPOSAL.md §3 TBD 절을 짧은 결정 항목 목록으로 나열. 본문 상세는 phase 진입 시 `plans/phaseNN-plan.md`의 결정 항목으로 승격되어 채워진다. phase 명세 파일에 TBD 본문을 직접 복사 금지(권한 모호 회피).

> **주의**: 기존 `phase14-stage4-hazard-water.md:20-21`에는 §0.2 금지 어휘가 사용된 코드 명세가 들어있다. 새 phase17(hazard) 본문에서는 이 어휘를 모두 §0.2 정책 어휘로 바꿔야 한다. 단순 rename·복붙이 아니라 본문 재작성.

### 2.7 active_revision 처리

- `metadata.json:5`의 `active_revision`은 `phases/mvp/REVISION_2026-05-09.md`(v3 game-flow 개정).
- 본 옵션 B v0.2 적용은 v4 개정. 새 revision 문서를 작성하고 `active_revision`을 갱신한다.
  - **NEW**: `phases/mvp/REVISION_2026-05-18-option-b.md`.
  - 본문: 옵션 B v0.2 + §5.2 17 분할의 결정 사항·매핑 표 + 본 migration plan 링크.
- v2/v3 패턴 유지. REVISION 문서가 "phase 재구성 어떤 phase가 어떻게 바뀌었는지"의 핵심 SoT 역할.

---

## 3. 수정 범위 — 파일 단위

### 3.1 작업 그룹 A: 명세 산출물 (docs/)

| 파일 | 종류 | 비고 |
|---|---|---|
| `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` | NEW | **본 문서 자체**. Commit 1에서 추가 |
| `docs/PHASE_14_OPTION_B_PROPOSAL.md` | NEW | 옵션 B 제안서 1차 persist 본(version 0.2). Commit 1에서 추가. v0.3 갱신(codex review 반영)은 Commit 2에서 |

### 3.2 작업 그룹 B: status + 메타 (phases/mvp/)

| 파일 | 종류 | 비고 |
|---|---|---|
| `phases/mvp/status.json` | EDIT (auto) | `sync-status`로 자동 갱신. 직접 수정 X(`execute.py`가 SoT). phase 1~13 completed 데이터 보존됨(`execute.py:652-657` `by_file` 매칭) |
| `phases/mvp/REVISION_2026-05-18-option-b.md` | NEW | v4 개정 노트 |
| `phases/mvp/metadata.json` | EDIT | `active_revision` 갱신 |

### 3.3 작업 그룹 C: phase 명세 파일 (phases/mvp/)

**DELETE** 7개:
- `phase14-stage4-hazard-water.md`
- `phase15-stage5-basher.md`
- `phase16-stage6-digger.md`
- `phase17-stage7-miner.md`
- `phase18-stage8-climber.md`
- `phase19-stage9-floater.md`
- `phase20-stage10-bomber-polish.md`

**NEW** 7개 (§2.2 표 그대로):
- `phase14-mechanic-adaptation-traits.md`
- `phase15-mechanic-adaptation-settlement.md`
- `phase16-mechanic-creation.md`
- `phase17-mechanic-hazard.md`
- `phase18-mechanic-destruction-earth.md`
- `phase19-mechanic-destruction-plant.md`
- `phase20-polish.md`

### 3.4 작업 그룹 D: README (phases/mvp/)

`phases/mvp/README.md` EDIT:
- 페이지 하단 phase 목록 표 갱신(7개 phase 14~20을 §2.2 표 내용으로).
- 개정 노트 줄 추가:

  ```
  > 2026-05-18 개정 v4 (option-B v0.2 + §5.2 17 분할): phase 14~20 재구성.
  > 상세 근거: docs/PHASE_14_OPTION_B_PROPOSAL.md +
  >           docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md.
  ```

### 3.5 작업 그룹 E: Notion 동기화 — 보류

- **본 plan commit에서 손대지 않음** (사용자 결정).
- `phases/mvp/notion-phase-ids.json` 갱신 + Notion DB 페이지 정리는 **phase 14a 진입 직전** 처리.
- 처리 방식은 그 시점에 별도 결정(기존 page_id 재활용 + slug 갱신 vs 신규 페이지 6개 생성 + 기존 7개 아카이브).
- phase 14a `plans/phase14-plan.md` 작성 시 Notion 처리를 **0번 작업**으로 명시(CLAUDE.md "Phase 진입 시" 동기화 시점 정책 준수).

### 3.6 영향 외 (변경 없음)

- `docs/PRD.md` / `docs/ARCHITECTURE.md` / `docs/ADR.md` — `PROPOSAL.md` §7.5에 따라 큰 틀 그대로. PRD에 §0.2 페일 어휘 정책(기존 페일 어휘 → "사탕 손실" 통일) 명시 여부는 별도 작업.
- `docs/ADR.md` ADR-002 4-카운터 — v0.2도 그대로 사용(`PROPOSAL.md` §3.5). 변경 없음.
- post-MVP phase 21~23 정의.
- `phases/mvp/plans/phase01-plan.md ~ phase13-plan.md` 등 phase 1~13 산출물 전체.
- `CLAUDE.md` — 규약 변경 없음.

---

## 4. 작업 순서 — commit 단위

### Commit 1: 제안서 + migration plan 1차 persist

- NEW `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` (**본 문서**).
- NEW `docs/PHASE_14_OPTION_B_PROPOSAL.md` (옵션 B 제안서 v0.2 1차 persist 본). 본 commit에서 직접 작성.
- Commit 전 확인:
  - `docs/PHASE_14_OPTION_B_PROPOSAL.md`이 실제로 작성되어 있고 §0(컨텍스트+톤 폴리시)·§1(핵심 변경 요약)·§2(phase 매핑)·§3(신규 시스템 명세)·§5(결정 사항)·§7(정책)·§8(확정 절차) 구조를 갖춤.
  - 본 migration plan이 PROPOSAL.md의 §0.2 / §0.7.0 / §0.7.5 / §2.1 / §2.4 / §3 / §3.1.3 / §3.1.4 / §3.5 / §5.1~§5.5 / §7.1 / §7.2 / §7.5 / §8을 인용하므로, 해당 § 헤더가 PROPOSAL.md에 실제로 존재함을 grep으로 확인.
- 커밋 메시지: `docs(plan): Phase 14~20 옵션 B 제안서 + 마이그레이션 계획서 1차 persist`.
- 본인 검수 1회 후 commit.

### Commit 2: codex adversarial-review (plan stage)

- Commit 1 직후, phase 파일 삭제·재작성 전에 실행한다. plan-stage review가 destructive migration 뒤에 오면 HIGH/CRITICAL 발견 시 되돌릴 범위가 커지므로 금지.
- 데스크톱 슬래시 커맨드(반드시 데스크톱 Claude Code에서 사용자가 트리거 — `phases/mvp/README.md` §2의 Bash subprocess 우회 정책):

  ```
  /codex:adversarial-review --background "phase 14~20 옵션 B v0.2 재구성: 톤 폴리시·7 phase 분할·신규 시스템 명세·status.json 정합성"
  ```

- 결과 → `phases/mvp/reviews/option-b-v0.2-plan-review.md`로 보존.
  - 본 작업은 단일 phase가 아닌 task-wide 재구성이므로 `phaseNN-review.md` 패턴 대신 별도 슬러그.
- **Plan stage 정책 적용** (CLAUDE.md):
  - CRITICAL/HIGH 0건 → phase 파일 재구성 진행.
  - CRITICAL/HIGH 1건 이상 → 즉시 중단 + 사용자 결정. 자동 재리뷰 사이클 X.
- 통과 시 또는 사용자 결정 반영 후 migration plan/proposal을 v0.3로 갱신 commit: `docs(plan): Phase 14~20 옵션 B v0.3 (codex review 반영)`.

### Commit 3: phase 파일 재구성

- DELETE 7개 + NEW 7개 (§3.3).
- NEW `phases/mvp/REVISION_2026-05-18-option-b.md` (§3.2).
- EDIT `phases/mvp/metadata.json` `active_revision` 갱신.
- EDIT `phases/mvp/README.md` v4 개정 노트 + phase 표 갱신.
- 실행 순서 (sot_aux 참조 무결성 보장 — 각 단계 후 다음 단계 진입):
  1. **REVISION 작성** — `phases/mvp/REVISION_2026-05-18-option-b.md` 생성. 본문: 옵션 B v0.2 + §5.2 17 분할 결정·매핑 표 + 본 migration plan 링크.
  2. **metadata.json 갱신** — `active_revision` 필드를 `phases/mvp/REVISION_2026-05-18-option-b.md`로 변경.
  3. **README.md 편집** — v4 개정 노트 + phase 표 갱신 (§3.4).
  4. **새 phase 파일 7개 작성** (§3.3 NEW 목록 + §2.5 frontmatter + §2.6 본문 표준). 작성 직전에 `Test-Path phases/mvp/REVISION_2026-05-18-option-b.md`로 REVISION 존재 확인 — frontmatter `sot_aux`가 참조하는 모든 파일(`docs/PRD.md` / `docs/ARCHITECTURE.md` / `docs/PHASE_14_OPTION_B_PROPOSAL.md` / REVISION)이 작성 시점에 모두 실재해야 함.
  5. **기존 phase 파일 7개 삭제** — `git rm phases/mvp/phase14-stage4-hazard-water.md` 외 6개 (§3.3 DELETE 목록).
  6. **pre-validate 체크** (PowerShell):
     - `Test-Path docs/PHASE_14_OPTION_B_PROPOSAL.md`
     - `Test-Path phases/mvp/REVISION_2026-05-18-option-b.md`
     - 새 phase 파일 7개 모두 `Test-Path` 통과
     - 각 새 phase 파일 frontmatter의 `sot` / `sot_aux` 모든 경로 `Test-Path` 통과
     - `& $Python scripts/check_tone_policy.py --commit3` 실행, exit 0 확인 (톤 폴리시 어휘 hits 0건).
     - 위 중 하나라도 실패 시 `sync-status` 호출 전이므로 step 11 §"sync-status 전 실패" 분기로 복구 진행.
  6b. **수동 backup 생성** (sync-status가 fixed-name `.bak`을 덮어쓰는 위험 회피):
     - 같은 PowerShell 세션에서 변수에 backup path를 한 번 만들고, step 11 rollback에서도 동일 변수를 재사용한다 (생성·복구가 한 SoT를 공유).

       ```powershell
       $statusBackup = "phases/mvp/status.json.manual-bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
       Copy-Item -LiteralPath phases/mvp/status.json -Destination $statusBackup
       ```

     - sync-status 호출 직전 1회 실행. 이후 자동 `.bak`이 mutate된 값으로 덮어써도 `$statusBackup`이 가리키는 파일로 rollback 가능.
     - 세션이 끊겨 `$statusBackup` 변수를 잃은 경우, `phases/mvp/status.json.manual-bak-*` glob에서 가장 최신 timestamp 파일을 1차 SoT로 사용.
  7. **sync-status** — `& $Python scripts/execute.py mvp sync-status --prune-missing` → `status.json` 자동 갱신. 삭제된 pending phase entry를 prune하고 자동 `.bak` 생성됨(`execute.py:678-681`).
  8. **validate** — `& $Python scripts/execute.py mvp validate` → frontmatter·status 무결성 확인.
  9. **read-only status** — `& $Python scripts/execute.py mvp` → phase 1~13 completed 데이터 보존 + 14~20 새 슬러그·pending 확인.
  10. **post-sync assertion** (status.json + 새 phase 파일 frontmatter 양쪽):
      - **status.json**:
        - 전체 entry 정확히 20개.
        - id 1~20 연속.
        - 삭제 대상 7개 파일명이 entry에 남아 있지 않음.
        - phase 14 `name == "mechanic-adaptation-traits"` 및 `state == "pending"`.
        - phase 14~20 모두 새 파일명·새 슬러그·pending 상태.
      - **각 새 phase 파일 frontmatter** (14~20):
        - `name`이 §2.2 표 슬러그와 일치.
        - `duration_estimate`가 §2.2 표 잠정치와 일치 (14=5400 / 15=7200 / 16=7200 / 17=7200 / 18=5400 / 19=5400 / 20=9000).
        - `sot == docs/PRD.md`.
        - `sot_aux`가 `[docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]` 3개 모두 포함.
  11. **실패 시 복구 절차** (실패 지점에 따라 분기):
      - **step 1~6 중 `sync-status` 전 실패** (step 1 REVISION 작성·step 2 metadata 갱신·step 3 README 편집·step 4 phase 파일 작성·step 5 `git rm`·step 6 pre-validate 어느 시점에서든):
        - 새로 생성한 파일 제거: `REVISION_2026-05-18-option-b.md` + 작성된 새 phase 파일 일부/전체.
        - `git rm`으로 삭제된 기존 phase 파일 복구 (`git restore --staged phases/mvp/phase14-stage4-hazard-water.md` 등 + 작업 트리 복원).
        - `metadata.json` `active_revision`을 이전 값(`phases/mvp/REVISION_2026-05-09.md`)으로 원복.
        - `README.md` v4 개정 노트 + phase 표 갱신 원복.
        - `status.json`은 이 분기에서 mutate된 적 없으므로 손대지 않는다.
        - 복구 후 `& $Python scripts/execute.py mvp validate`로 원상 검증.
      - **step 7 이후 실패** (`sync-status --prune-missing` 호출 후 step 8 validate / step 9 read-only / step 10 assertion 중 실패):
        - **`status.json`을 step 6b의 수동 backup으로 복원**:

          ```powershell
          Copy-Item -LiteralPath $statusBackup -Destination phases/mvp/status.json -Force
          ```

          (`$statusBackup`은 step 6b에서 동일 PowerShell 세션에 정의된 변수. 세션이 끊겼다면 `phases/mvp/status.json.manual-bak-*` glob에서 가장 최신 timestamp 파일을 골라 동일 명령으로 복원.)
        - `status.json.bak` (자동 생성)은 신뢰하지 않는다 — 두 번째 실수 `sync-status` 호출이 이미 한 번 덮어썼을 가능성. 수동 backup이 1차 SoT.
        - 그 다음 위 "step 1~6 실패" 분기와 동일하게 새 phase 파일 제거 + 삭제 phase 파일 복구 + metadata · README 원복.
      - **복구 후 필수 확인**: `& $Python scripts/execute.py mvp validate` 통과 + `& $Python scripts/execute.py mvp`로 phase 14가 기존 `stage4-hazard-water` pending으로 돌아왔는지 확인.
- `& $Python scripts/execute.py mvp next`는 이 단계에서 **호출 금지**. `next`는 read-only가 아니라 첫 pending phase를 `in_progress`로 바꾸고 `started_at`을 기록한다(`execute.py:557-560`).
- 커밋 메시지: `feat(plan): Phase 14~20 옵션 B v0.3 재구성 (v4 개정)`.

### Commit 4 (조건부): Notion 동기화 — phase 14a 진입 시

- 본 plan에서는 손대지 않음 (mapping + 상태 변경 모두 phase 14a 진입 시점).
- Phase 14a 진입 시점 절차 (local status.json ↔ Notion 윈도우 최소화):
  1. **(`next` 전) Mapping 정리** — `notion-phase-ids.json` slug/page mapping 갱신. 기존 page_id 재활용 vs 신규 생성 결정. Notion DB 페이지 메타데이터·archiving도 이 시점에 처리.
  2. **`next` 호출** — `& $Python scripts/execute.py mvp next` 실행. local `status.json`의 첫 pending phase가 `in_progress`로 전환되고 `started_at`이 기록됨.
  3. **(`next` 직후, 즉시) Notion 상태 변경** — CLAUDE.md "Phase 진입 시" 동기화 정책대로 새 phase 14 page 상태 → "진행 중". local in_progress 시각과 Notion in_progress 시각 차이를 분 단위 이하로 유지.
- 본 작업은 phase 14a plan(`plans/phase14-plan.md`)의 0번 작업.
- **Mapping 정리(1번)가 끝나기 전 `next` 호출 금지** — slug 불일치 상태로 `in_progress` 진입을 막기 위함.
- **Notion 상태 변경(3번)이 빠지면 phase tracking 끊김** — Notion DB에서 phase 14가 "시작 전" 상태로 보이므로 즉시 처리 필수.

> Phase 14~20 각각의 표준 7단계 절차는 `phases/mvp/README.md` 참조. 본 migration plan은 phase 진입 전 1회 마이그레이션 작업에 한정.

---

## 5. 리스크 + 완화

| # | 리스크 | 영향 | 완화 |
|---|---|---|---|
| R1 | `sync-status`가 phase 1~13 completed 데이터를 덮어쓸 가능성 | 진행 ledger 손실 | `execute.py:652-657`이 `by_file` 매칭으로 기존 entry 보존. 삭제된 pending entry 제거를 위해 `sync-status --prune-missing`를 사용하며 이때 자동 `.bak` 생성(`execute.py:678-681`). Commit 3 후 git diff로 phase 1~13 entry 보존 재확인 |
| R2 | git rename 감지로 인한 자동 stage 거부 | execute.py complete 차단 | 본 plan commit은 `execute.py complete` 흐름이 아닌 일반 commit. 새 phase 진입 시점에는 phase 파일이 이미 새 슬러그라 rename 미발생 |
| R3 | Notion 동기화 누락으로 페이지 ID-슬러그 불일치 | Phase DB 추적 끊김. CLAUDE.md "Notion Phase DB 동기화" 위반 | 본 plan에서 명시적으로 보류. 본 문서 §3.5 + §4 Commit 4에 "phase 14a 진입 시 처리"를 강조. phase 14 plan의 0번 작업으로 명시. Notion은 보조 트래커(CLAUDE.md "Notion MCP 호출 실패해도 작업은 계속") |
| R4 | Commit 3 직후 status.json은 새 슬러그(`mechanic-adaptation-traits`)지만 notion-phase-ids.json은 옛 슬러그(`stage4-hazard-water`)로 불일치 | 사용자 혼란, 추적 끊김 | 이 상태가 **의도적** 임을 본 문서 §3.5 + §4 Commit 4에 명시. phase 14a 시작 시 일괄 동기화로 해소. Notion 동기화 전 `next` 호출 금지 |
| R5 | 기존 phase14 본문의 §0.2 금지 어휘가 새 phase17 본문에 그대로 복붙됨 | §0.2 톤 폴리시 위반 | Commit 3의 phase17 본문 작성 시 §0.2 어휘 변환 체크리스트 적용. 본 문서 §2.6 명시. self-review에서 §6.1 grep scope(새 phase 파일 7개 + PROPOSAL.md, 정의부·정책 인용 exemption)로 0건 확인 |
| R6 | 본 작업 자체에 대한 codex review가 라운드 폭증 | usage limit | CLAUDE.md plan stage 정책 — codex 1회만 실행, HIGH 1건이라도 발견 시 즉시 중단 + 사용자 결정. 자동 재리뷰 사이클 X |
| R7 | 상대 무게 잠정치를 wall-clock으로 오해하고 페이스 가이드 삼음 | 페이스 어긋남·번아웃 | §0.7.0 정책 본 문서 §2.2 표 주석에 명시. `duration_estimate` 필드 자체에는 절대 시간 의미 부여하지 않음 |
| R8 | Phase 17 분할이 무게 면에서 과분할로 판명 → phase 19 비어 보임 | 작업 흐름 어색 | §2.2 무게 잠정치 5400 + 5400. 식물 지형 신설은 TileMap 신규 cell type 추가 등 단순 스킬 추가 이상의 작업으로 5400 적정. phase 19 진입 시 plan 단계에서 재조정 가능 |
| R9 | `docs/PHASE_14_OPTION_B_PROPOSAL.md` 또는 그 안의 인용 § 헤더가 누락된 상태에서 phase 명세·migration plan이 해당 파일을 참조 | SoT 링크 깨짐, review 불완전 | Commit 1에서 PROPOSAL.md를 직접 작성하여 파일 존재를 보장. Commit 1 self-review에서 migration plan이 인용하는 모든 § 헤더(§0.2 / §0.7.0 / §0.7.5 / §2.1 / §2.4 / §3 / §3.1.3 / §3.1.4 / §3.5 / §5.1~§5.5 / §7.1 / §7.2 / §7.5 / §8)가 PROPOSAL.md에 실제 존재함을 grep으로 확인 |

---

## 6. 검증 계획

### 6.1 본 migration plan 자체 검증

- 본인 self-review:
  - `docs/PHASE_14_OPTION_B_PROPOSAL.md`이 §0·§1·§2·§3·§5·§7·§8 구조로 작성되었고, 본 plan이 인용하는 모든 § 헤더(R9 참조)가 실제 존재.
  - **톤 폴리시 어휘 grep**: `scripts/check_tone_policy.py`로 검증한다.
    - 정책 본문은 PROPOSAL.md §0.2. 스크립트는 동일 패턴(`die\(\)|Dead|사망|죽`)과 동일 exemption(PROPOSAL.md §0.2 정의부, `### 0.2`부터 다음 `### ` heading 직전까지 섹션 경계 기준)을 구현한다.
    - 사용:
      - Commit 1 self-review: `& $Python scripts/check_tone_policy.py --commit1` (PROPOSAL.md만 검사. 새 phase 파일이 아직 없는 시점).
      - Commit 3 phase 파일 작성 직후: `& $Python scripts/check_tone_policy.py --commit3` (PROPOSAL.md + 새 phase 파일 7개 검사).
    - exit code: 0 PASS / 1 forbidden token hit / 2 missing target file.
    - migration plan 자체는 정책 인용 문구(§0 작업 컨텍스트 / §2.6 phase 본문 표준 주의문 / §5 R5 / §6.1 본 self-review 정책)에 금지 어휘가 등장하므로 자동 scope에서 제외 — 스크립트는 PROPOSAL.md + 새 phase 파일만 본다.
    - 스크립트 자체의 신뢰성(인코딩·missing 파일·exemption 경계)은 별도 코드 검증 책임이며, plan-stage 리뷰의 범위 밖이다.
  - 본 plan §2.2 매핑 표가 PROPOSAL.md §2.1 묶음 한 줄 요약과 정합.
  - 본 plan §2.3 기존 → 옵션 B 매핑이 PROPOSAL.md §1 핵심 변경 요약과 정합.
  - 잔여 결정 5건이 모두 §1 표에서 해소.
- 사용자 검수 1회.

### 6.2 Commit 2 (codex review) 후

- `phases/mvp/reviews/option-b-v0.2-plan-review.md` 생성 확인.
- HIGH/CRITICAL 0건 또는 사용자 승인된 처리 방침 확인 후 Commit 3 진행.

### 6.3 Commit 3 후 status.json·메타·frontmatter 검증

**Step 1 — pre-validate 존재 체크** (§4 Commit 3 step 6 참조). PowerShell:

```powershell
Test-Path docs/PHASE_14_OPTION_B_PROPOSAL.md
Test-Path phases/mvp/REVISION_2026-05-18-option-b.md
Test-Path phases/mvp/phase14-mechanic-adaptation-traits.md
# … 나머지 새 phase 파일 6개도 동일하게 Test-Path 통과
```

하나라도 `False`면 작업 중단 + sot_aux 깨짐 원인 진단. 추가로 `& $Python scripts/check_tone_policy.py --commit3`도 통과해야 함.

**Step 1b — 수동 backup** (sync-status 호출 직전):

```powershell
$statusBackup = "phases/mvp/status.json.manual-bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath phases/mvp/status.json -Destination $statusBackup
```

`$statusBackup`은 같은 PowerShell 세션에서 step 11 rollback 시 `Copy-Item -LiteralPath $statusBackup -Destination phases/mvp/status.json -Force`로 재사용. 자동 `.bak`은 `sync-status --prune-missing` 호출마다 덮어쓰이므로, 실패 후 두 번째 실행이 정상 backup을 손상시킬 위험이 있다. 수동 backup이 rollback 1차 SoT (§4 Commit 3 step 6b/step 11).

**Step 2 — sync-status**:

```powershell
& $Python scripts/execute.py mvp sync-status --prune-missing
```

기대 결과:
- 삭제된 pending phase entry prune 로그 출력.
- `phases/mvp/status.json.bak` 생성 (참고용 — rollback SoT 아님. rollback은 step 1b에서 만든 `$statusBackup` 사용).

**Step 3 — validate**:

```powershell
& $Python scripts/execute.py mvp validate
```

기대 결과:
- `✓ validate ok — 20 phase files; metadata + frontmatter clean` (phase 1~13 + 새 14~20 = 20개).
- phase 1~13의 completed 데이터 보존 확인 (`started_at` / `completed_at` / `duration_seconds` 그대로).
- phase 14~20의 새 슬러그 + `state="pending"` 확인.

**Step 4 — read-only status**:

```powershell
& $Python scripts/execute.py mvp
```

기대 결과: 다음 phase가 `Phase 14 — mechanic-adaptation-traits`로 표시.

**Step 5 — post-sync assertion** (수동 또는 스크립트):

status.json:
- 전체 entry 정확히 20개, id 1~20 연속.
- 삭제 대상 7개 파일명이 status entry에 없음.
- phase 14~20 모두 새 파일명·새 슬러그·pending 상태.

각 새 phase 파일(14~20) frontmatter:
- `name`이 §2.2 슬러그와 일치.
- `duration_estimate`가 §2.2 잠정치와 일치 (14=5400, 15=7200, 16=7200, 17=7200, 18=5400, 19=5400, 20=9000).
- `sot == docs/PRD.md`.
- `sot_aux`가 `[docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]` 3개 모두 포함.

> `& $Python scripts/execute.py mvp next`는 본 §6.3 검증 단계에서 **호출 금지**. 해당 명령은 status를 mutate한다(`execute.py:557-560`).

**실패 시 복구**: §4 Commit 3 step 11과 동일한 분기·절차를 따른다 — rollback의 1차 SoT는 step 1b/§4 step 6b에서 생성한 `$statusBackup` (수동 timestamped backup)이며, 자동 `phases/mvp/status.json.bak`은 참고용에 그친다.

### 6.4 헤드리스 회귀 — 불필요

- 본 작업은 코드 변경 없음. 헤드리스 회귀 불필요.
- migration 리스크는 phase metadata/status reconciliation/README consistency/SoT 링크 존재 여부에 집중한다.
- 필요 시 Godot 에디터 Stage 1~3 실행은 추가 smoke check로만 수행하고, 필수 검증은 CLI validation과 status diff 검토로 판단한다.

---

## 7. 산출물 요약

본 migration plan 승인 후 생성·수정되는 파일:

| 종류 | 경로 | Commit |
|---|---|---|
| NEW | `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` | 1 (본 문서) |
| NEW | `docs/PHASE_14_OPTION_B_PROPOSAL.md` (신규 작성, version 0.2) | 1 |
| NEW | `phases/mvp/reviews/option-b-v0.2-plan-review.md` (Round 3 누적) | 2 |
| EDIT | `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` (v0.3 review 반영, 선택) | 2 |
| EDIT | `docs/PHASE_14_OPTION_B_PROPOSAL.md` (version 0.3 frontmatter bump + review 반영, 선택) | 2 |
| NEW | `phases/mvp/REVISION_2026-05-18-option-b.md` | 3 |
| EDIT | `phases/mvp/metadata.json` (active_revision) | 3 |
| EDIT | `phases/mvp/README.md` (v4 개정 노트 + 표) | 3 |
| EDIT (auto) | `phases/mvp/status.json` (`sync-status --prune-missing`) | 3 |
| DELETE | `phases/mvp/phase14-stage4-hazard-water.md` 외 6개 | 3 |
| NEW | `phases/mvp/phase14-mechanic-adaptation-traits.md` 외 6개 | 3 |

**손대지 않는 파일** (의도적):
- `phases/mvp/notion-phase-ids.json` — phase 14a 진입 시 일괄 처리.
- `phases/mvp/plans/phase01-plan.md ~ phase13-plan.md` 등 phase 1~13 모든 산출물.

---

## 8. 다음 단계

1. **사용자 검수** — 본 migration plan 통독 + §1 잔여 결정 확정 재확인.
2. **Commit 1** — PROPOSAL.md 신규 작성 + 본 migration plan commit (1차 persist).
3. **Commit 2** — codex adversarial-review (plan stage). HIGH 1건 발견 시 즉시 사용자 보고. review 반영 후 v0.3 갱신.
4. **Commit 3** — phase 파일 재구성 + `sync-status --prune-missing` + validate + read-only status 확인 + commit.
5. **Phase 14a 진입** — Notion 동기화 + `plans/phase14-plan.md` 작성 + 표준 7단계 절차 시작.
