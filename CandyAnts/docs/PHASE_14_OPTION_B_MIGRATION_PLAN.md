# Phase 14~20 옵션 B v0.2 마이그레이션 계획서

**작성 일자**: 2026-05-18
**상태**: codex adversarial-review 진입 직전 정리물
**근거 문서**: `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md` (옵션 B 개정안 v0.2)
**관련 문서**:
- `docs/PHASE_14_OPTION_B_PROPOSAL.md` — 옵션 B v0.1 원본 (보존)
- `phases/mvp/README.md` — 표준 7단계 절차
- `phases/mvp/status.json` — 현 진행 ledger
- `CLAUDE.md` — Notion 동기화·리뷰 정책

> 본 문서는 `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md`에 정리된 옵션 B 개정안을 `phases/mvp/` 폴더와 `status.json`에 실제로 반영하는 마이그레이션 작업 계획서다. 미래의 본인이 본 작업을 재개하거나 검수할 때 1차 참조한다. 본 문서 자체는 계획서이며, 본 문서 작성 시점에는 status.json·phase 명세 파일에 변경이 없다.

---

## 0. 작업 컨텍스트

- **개발 모델**: 1인 + AI 페어 협업(Claude Code + Codex). 본인은 결정·검수·통합, AI는 명세·코드·리뷰 분담. 여가 시간 개발이라 wall-clock 추정은 무의미(`PROPOSAL_v0.2.md` §0.7.0).
- **대상 플레이어**: 어린 플레이어. 사망 연출·폭력 묘사 전면 배제. 페일은 "사탕 손실"로 통일(§0).
- **본 작업 위치**: 옵션 B 확정 절차(`PROPOSAL_v0.2.md` §8) 중 1번 잔여 결정 확정 직후, 2번 v0.3 갱신 + 5번 phase 파일 재구성을 한 commit 시퀀스로 묶는 단계.
- **본 plan에서 손대지 않는 것**: 실제 코드, `notion-phase-ids.json`, `PROPOSAL_v0.2.md` 본문(v0.3 갱신은 codex review 후).

---

## 1. 사용자 확정 사항

`PROPOSAL_v0.2.md` §5의 잔여 결정 5건 처리 상태.

| 항목 | 결정 | 근거 |
|---|---|---|
| **§5.1** Phase 14 분할 14a/14b | **분할 채택** | `PROPOSAL_v0.2.md` §7.1 정수 id 정책 + 정착에 능력 전이 시스템 포함으로 단일 phase는 무겁다 |
| **§5.2** Phase 17 (파괴) 분할 | **17a/17b 분할 채택** | 식물 지형 신설 부담 분리 + codex HIGH 위험 회피. 결과: 7 phase 구성 |
| **§5.3** 분배자 사탕 UX | **A안** (경고 없이 정착 허용) | `PROPOSAL_v0.2.md` §3.1.3. 100% 도달 = 회수 동선 설계(§0.7.5) |
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

**합계(잠정)**: 46800. `PROPOSAL_v0.2.md` §2.4 합계 그대로(17 분할로 분배만 재구성).

> **무게 수치 해석 주의**: 본 표의 무게는 phase 간 상대 비교용 잠정치다. 시간 단위로 환산하지 않는다(§0.7.0). 각 phase 진입 시 plan 단계에서 재조정 가능.

### 2.3 v0.1 원안 → v0.2 옵션 B 매핑

| v0.1 (현재 status.json) | v0.2 + 17 분할 (새) | 변경 종류 |
|---|---|---|
| phase14 stage4-hazard-water | phase17 mechanic-hazard | 통합 + 내용 교체 (Water + 끈끈이, 톤 폴리시 반영) |
| phase15 stage5-basher | phase18 mechanic-destruction-earth | 통합 (Basher + Digger) |
| phase16 stage6-digger | (phase18에 통합됨) | 통합 흡수 |
| phase17 stage7-miner | — | **삭제** (Cutter로 대체, §0/§4) |
| phase18 stage8-climber | phase14 mechanic-adaptation-traits | 통합 (Climber + Floater) |
| phase19 stage9-floater | (phase14에 통합됨) | 통합 흡수 |
| phase20 stage10-bomber-polish | phase20 polish | 내용 교체 (Bomber 삭제, 별 시스템·정산 UI·끈끈이 후처리 추가) |
| — | phase15 mechanic-adaptation-settlement | **신규** (Blocker + 민들레씨 분배자) |
| — | phase16 mechanic-creation | **신규** (Sand-mound + Bridge) |
| — | phase19 mechanic-destruction-plant | **신규** (Cutter + 식물 지형) |

요약: 기존 7개 → 새 7개. 1:1 rename 없음. **신규 작성 3 + 통합·내용 교체 rename 4**.

### 2.4 git mv 정책 — 사용하지 않는다

- `PROPOSAL_v0.2.md` §7.2는 "git mv로 history 보존"을 제안.
- 그러나 새 파일과 기존 파일의 본문 유사도가 매우 낮다(톤 폴리시·신규 시스템·통합으로 거의 처음부터 작성).
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
sot_aux: [docs/ARCHITECTURE.md]
---
```

`name`/`duration_estimate`는 §2.2 표대로. 본문에서 `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md` 해당 절을 SoT로 참조.

### 2.6 phase 명세 본문 표준

각 phase 본문은 다음 섹션을 포함(기존 phase14~20 패턴 + 옵션 B 반영):

1. **목표 1줄** — `PROPOSAL_v0.2.md` §2.1 묶음 한 줄 요약.
2. **변경 대상** — 씬·스크립트·데이터 파일 목록 (가이드 수준). 상세는 각 phase 진입 시 `plans/phaseNN-plan.md`에서 채운다.
3. **검증 방법** — Stage 1~13 회귀 무영향 확인 + 신규 메카닉 동작 확인.
4. **엣지 케이스** — `PROPOSAL_v0.2.md` §3 신규 시스템 예외 처리(§3.1.4, §3.2.3, §3.3.3) 참조.
5. **참조** — `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md` 해당 절 링크.
6. **톤 폴리시 주석** — `die()`·DeadState·사망·죽 어휘 금지를 명시. "정착" / "임무 완수" / "사탕 손실" 어휘 사용(§0.2).

> **주의**: 기존 `phase14-stage4-hazard-water.md:20-21`에는 `ant.die()` / `DeadState.gd` 코드 명세가 들어있다. 새 phase17(hazard) 본문에서는 이 어휘를 모두 §0 톤 폴리시 어휘로 바꿔야 한다. 단순 rename·복붙이 아니라 본문 재작성.

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
| `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md` | UNCHANGED | v0.3 갱신은 codex review 후 |
| `docs/PHASE_14_OPTION_B_PROPOSAL.md` (v0.1) | UNCHANGED | 보존 |

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
  > 상세 근거: docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md +
  >           docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md.
  ```

### 3.5 작업 그룹 E: Notion 동기화 — 보류

- **본 plan commit에서 손대지 않음** (사용자 결정).
- `phases/mvp/notion-phase-ids.json` 갱신 + Notion DB 페이지 정리는 **phase 14a 진입 직전** 처리.
- 처리 방식은 그 시점에 별도 결정(기존 page_id 재활용 + slug 갱신 vs 신규 페이지 6개 생성 + 기존 7개 아카이브).
- phase 14a `plans/phase14-plan.md` 작성 시 Notion 처리를 **0번 작업**으로 명시(CLAUDE.md "Phase 진입 시" 동기화 시점 정책 준수).

### 3.6 영향 외 (변경 없음)

- `docs/PRD.md` / `docs/ARCHITECTURE.md` / `docs/ADR.md` — `PROPOSAL_v0.2.md` §7.5에 따라 큰 틀 그대로. PRD에 "사망 페일 → 사탕 손실" 톤 폴리시 명시 여부는 별도 작업.
- `docs/ADR.md` ADR-002 4-카운터 — v0.2도 그대로 사용(`PROPOSAL_v0.2.md` §3.5). 변경 없음.
- post-MVP phase 21~23 정의.
- `phases/mvp/plans/phase01-plan.md ~ phase13-plan.md` 등 phase 1~13 산출물 전체.
- `CLAUDE.md` — 규약 변경 없음.

---

## 4. 작업 순서 — commit 단위

### Commit 1: migration plan 산출물 작성

- NEW `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` (**본 문서**).
- 메인 worktree에만 untracked로 있는 `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md`도 본 작업 브랜치에 함께 들어가도록 처리 — 본 worktree로 복사하거나, 메인에서 먼저 commit 후 본 worktree로 merge.
- 커밋 메시지: `docs(plan): Phase 14~20 옵션 B v0.2 마이그레이션 계획서 + 제안서 v0.2 동봉`.
- 본인 검수 1회 후 commit. codex review 전 — 본인 검수만.

### Commit 2: phase 파일 재구성

- DELETE 7개 + NEW 7개 (§3.3).
- NEW `phases/mvp/REVISION_2026-05-18-option-b.md` (§3.2).
- EDIT `phases/mvp/metadata.json` `active_revision` 갱신.
- EDIT `phases/mvp/README.md` v4 개정 노트 + phase 표 갱신.
- 실행 순서:
  1. 새 phase 파일 7개 작성 + 기존 7개 삭제 + REVISION + metadata + README 편집.
  2. `python scripts/execute.py mvp sync-status` → `status.json` 자동 갱신. 자동 `.bak` 생성됨(`execute.py:681`).
  3. `python scripts/execute.py mvp validate` → frontmatter·status 무결성 확인.
  4. `python scripts/execute.py mvp` → phase 1~13 completed 데이터 보존 + 14~20 새 슬러그·pending 확인.
- 커밋 메시지: `feat(plan): Phase 14~20 옵션 B v0.2 재구성 (v4 개정)`.

### Commit 3: codex adversarial-review (plan stage)

- 데스크톱 슬래시 커맨드(반드시 데스크톱 Claude Code에서 사용자가 트리거 — `phases/mvp/README.md` §2의 Bash subprocess 우회 정책):

  ```
  /codex:adversarial-review --background "phase 14~20 옵션 B v0.2 재구성: 톤 폴리시·6/7 phase 분할·신규 시스템 명세·status.json 정합성"
  ```

- 결과 → `phases/mvp/reviews/option-b-v0.2-plan-review.md`로 보존.
  - 본 작업은 단일 phase가 아닌 task-wide 재구성이므로 `phaseNN-review.md` 패턴 대신 별도 슬러그.
- **Plan stage 정책 적용** (CLAUDE.md):
  - CRITICAL/HIGH 0건 → 다음 단계 진행.
  - CRITICAL/HIGH 1건 이상 → 즉시 중단 + 사용자 결정. 자동 재리뷰 사이클 X.
- 통과 시 (혹은 사용자 결정 반영 후) v0.3로 갱신 commit: `docs(plan): Phase 14~20 옵션 B v0.3 (codex review 반영)`.

### Commit 4 (조건부): Notion 동기화 — phase 14a 진입 시

- 본 plan에서는 손대지 않음.
- Phase 14a 진입 직전(첫 `python scripts/execute.py mvp next` 호출 전):
  1. `notion-phase-ids.json` 갱신 (기존 page_id 재활용 vs 신규 생성 결정).
  2. Notion DB 페이지 정리 (Notion MCP `notion-update-page` 또는 수동).
  3. CLAUDE.md "Phase 진입 시" 동기화 정책대로 새 phase 14 page 상태 → "진행 중".
- 본 작업은 phase 14a plan(`plans/phase14-plan.md`)의 0번 작업.

> Phase 14~20 각각의 표준 7단계 절차는 `phases/mvp/README.md` 참조. 본 migration plan은 phase 진입 전 1회 마이그레이션 작업에 한정.

---

## 5. 리스크 + 완화

| # | 리스크 | 영향 | 완화 |
|---|---|---|---|
| R1 | `sync-status`가 phase 1~13 completed 데이터를 덮어쓸 가능성 | 진행 ledger 손실 | `execute.py:652-657`이 `by_file` 매칭으로 기존 entry 보존. sync-status는 자동 `.bak` 생성(line 681). Commit 2 후 git diff로 phase 1~13 entry 보존 재확인 |
| R2 | git rename 감지로 인한 자동 stage 거부 | execute.py complete 차단 | 본 plan commit은 `execute.py complete` 흐름이 아닌 일반 commit. 새 phase 진입 시점에는 phase 파일이 이미 새 슬러그라 rename 미발생 |
| R3 | Notion 동기화 누락으로 페이지 ID-슬러그 불일치 | Phase DB 추적 끊김. CLAUDE.md "Notion Phase DB 동기화" 위반 | 본 plan에서 명시적으로 보류. 본 문서 §3.5 + §4 Commit 4에 "phase 14a 진입 시 처리"를 강조. phase 14 plan의 0번 작업으로 명시. Notion은 보조 트래커(CLAUDE.md "Notion MCP 호출 실패해도 작업은 계속") |
| R4 | Commit 2 직후 status.json은 새 슬러그(`mechanic-adaptation-traits`)지만 notion-phase-ids.json은 옛 슬러그(`stage4-hazard-water`)로 불일치 | 사용자 혼란, 추적 끊김 | 이 상태가 **의도적** 임을 본 문서 §3.5 + §4 Commit 4에 명시. phase 14a 시작 시 일괄 동기화로 해소 |
| R5 | 기존 phase14 본문의 `ant.die()`·DeadState·사망 어휘가 새 phase17 본문에 그대로 복붙됨 | §0 톤 폴리시 위반 | Commit 2의 phase17 본문 작성 시 §0 어휘 변환 체크리스트 적용. 본 문서 §2.6 명시. self-review에서 `git diff` + grep으로 `die\|Dead\|사망\|죽` 0건 확인 |
| R6 | 본 작업 자체에 대한 codex review가 라운드 폭증 | usage limit | CLAUDE.md plan stage 정책 — codex 1회만 실행, HIGH 1건이라도 발견 시 즉시 중단 + 사용자 결정. 자동 재리뷰 사이클 X |
| R7 | 상대 무게 잠정치를 wall-clock으로 오해하고 페이스 가이드 삼음 | 페이스 어긋남·번아웃 | §0.7.0 정책 본 문서 §2.2 표 주석에 명시. `duration_estimate` 필드 자체에는 절대 시간 의미 부여하지 않음 |
| R8 | Phase 17 분할이 무게 면에서 과분할로 판명 → phase 19 비어 보임 | 작업 흐름 어색 | §2.2 무게 잠정치 5400 + 5400. 식물 지형 신설은 TileMap 신규 cell type 추가 등 단순 스킬 추가 이상의 작업으로 5400 적정. phase 19 진입 시 plan 단계에서 재조정 가능 |

---

## 6. 검증 계획

### 6.1 본 migration plan 자체 검증

- 본인 self-review:
  - 톤 폴리시(§0) 어휘 사용 여부 (`die`·`Dead`·사망·죽 grep 0건).
  - §2.3 매핑 표가 `PROPOSAL_v0.2.md` §4 변경표와 정합.
  - 잔여 결정 5건이 모두 §1 표에서 해소.
- 사용자 검수 1회.

### 6.2 Commit 2 후 status.json·메타 검증

```powershell
python scripts/execute.py mvp validate
```

기대 결과:
- `✓ validate ok — 20 phase files; metadata + frontmatter clean` (phase 1~13 + 새 14~20 = 20개).
- phase 1~13의 completed 데이터 보존 확인 (`started_at` / `completed_at` / `duration_seconds` 그대로).
- phase 14~20의 새 슬러그 + `state="pending"` 확인.

```powershell
python scripts/execute.py mvp next
```

기대 결과: `Phase 14: mechanic-adaptation-traits` 출력. 그 후 next는 호출만 하고 실제 실행은 안 함 (codex review 통과 전).

### 6.3 Commit 3 (codex review) 후

- `phases/mvp/reviews/option-b-v0.2-plan-review.md` 생성 확인.
- HIGH/CRITICAL 0건 + verdict clean → Phase 14a 진입 가능.

### 6.4 헤드리스 회귀 — 불필요

- 본 작업은 코드 변경 없음. 헤드리스 회귀 불필요.
- 단 Commit 2 후 1회 Godot 에디터로 Stage 1~3 실행해 파일 시스템 변동에 회귀 없는지 확인(안전 차원).

---

## 7. 산출물 요약

본 migration plan 승인 후 생성·수정되는 파일:

| 종류 | 경로 | Commit |
|---|---|---|
| NEW | `docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md` | 1 (본 문서) |
| NEW | `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md` (worktree로 이관) | 1 |
| NEW | `phases/mvp/REVISION_2026-05-18-option-b.md` | 2 |
| EDIT | `phases/mvp/metadata.json` (active_revision) | 2 |
| EDIT | `phases/mvp/README.md` (v4 개정 노트 + 표) | 2 |
| EDIT (auto) | `phases/mvp/status.json` (sync-status) | 2 |
| DELETE | `phases/mvp/phase14-stage4-hazard-water.md` 외 6개 | 2 |
| NEW | `phases/mvp/phase14-mechanic-adaptation-traits.md` 외 6개 | 2 |
| NEW | `phases/mvp/reviews/option-b-v0.2-plan-review.md` | 3 |

**손대지 않는 파일** (의도적):
- `phases/mvp/notion-phase-ids.json` — phase 14a 진입 시 일괄 처리.
- `docs/PHASE_14_OPTION_B_PROPOSAL_v0.2.md` 본문 — v0.3 갱신은 codex review 후.
- `docs/PHASE_14_OPTION_B_PROPOSAL.md` (v0.1) — 보존.
- `phases/mvp/plans/phase01-plan.md ~ phase13-plan.md` 등 phase 1~13 모든 산출물.

---

## 8. 다음 단계

1. **사용자 검수** — 본 migration plan 통독 + §1 잔여 결정 확정 재확인.
2. **Commit 1** — `PROPOSAL_v0.2.md` worktree 이관 + 본 migration plan commit.
3. **Commit 2** — phase 파일 재구성 + sync-status + validate + commit.
4. **Commit 3** — codex adversarial-review (plan stage). HIGH 1건 발견 시 즉시 사용자 보고.
5. **Phase 14a 진입** — Notion 동기화 + `plans/phase14-plan.md` 작성 + 표준 7단계 절차 시작.
