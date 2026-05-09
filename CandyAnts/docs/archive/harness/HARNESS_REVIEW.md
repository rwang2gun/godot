> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness 명령 컨텍스트 효율 개편 계획 (v2)

작성일: 2026-05-10
대상: `.claude/commands/harness.md`, `phases/mvp/phase*.md`, `phases/mvp/status.json`, `scripts/execute.py`
상태: 사용자 컨펌 대기 → 컨펌 후 §5 순서로 적용

> v1(2026-05-09)의 권고안(A+B+D 동시 적용)은 plan-stage 적대적 리뷰에서 HIGH 3건이 발견되어 폐기됨.
> - H1: KPI 계산 오류(588 → 760이라 적었으나 실제 643 → 1130, 즉 *증가*)
> - H2: `REVISION_*.md` glob 자동 로드가 향후 revision 누적 시 dead context 회귀
> - H3: CLAUDE.md 매핑 표 vs `REVISION_2026-05-09.md` §15 = circular SoT
> v2는 v1이 보류했던 옵션 C(phase 파일 frontmatter `sot:`)를 핵심 수단으로 채택해 자동 로드 절감과 결정성을 동시에 달성한다.

---

## 1. 진단 (v1에서 사실관계만 유지)

### F1. UI_GUIDE 자동 로드 dead context — HIGH
- 다음 진입 phase 6/7/8은 모두 UI 무관. 전체 20 phase 중 UI track은 phase 9~13 (5개, 25%)
- 75% 세션에서 `docs/UI_GUIDE.md` 450줄이 dead context

### F2. 1차 SoT 자동 로드 누락 — HIGH
- 현 harness는 `docs/{PRD,ARCHITECTURE,ADR,UI_GUIDE}.md` 4개(공통 기반)만 자동 로드
- phase별 1차 SoT(예: phase 6의 `GAME_FLOW_PROPOSAL_V5.md`)는 모델이 *알아서* 추가 read해야 함 → 비결정적, cross-reference 오류 위험

### F3. phase 파일에 SoT 포인터 부재 — MEDIUM (v2 핵심 해결 수단)
- phase 파일 frontmatter에 기계 판독 가능한 SoT 필드 없음 → 모델이 본문 paragraph 검색
- v1에서는 22 phase 갱신 비용 때문에 보류했으나, v1의 D 안이 폐기되면서 본 옵션이 가장 깔끔한 해법으로 부상

---

## 2. 측정값 (v1 수치 정정)

자동 로드 = 시스템이 세션 시작 시 강제 read하는 파일 (CLAUDE.md 포함, JSON 포함).

| 항목 | 현재 | v1(폐기) 적용 시 | **v2 적용 시** |
|---|---|---|---|
| 자동 로드 줄 수 | 643 | 1,130 (REVISION 524 + README 186 + status 227 추가) | **195** |
| 자동 로드 변화 | — | **+487 (악화)** | **-448 (-70%)** |
| 비-UI phase 진입 비용 | UI_GUIDE 450줄 dead | 위 dead + 1,130 dead | 0 dead + 해당 phase 1차 SoT 1개만 명시 read |
| UI phase 진입 비용 | 이미 자동 로드됨 | UI_GUIDE 중복 회피 | + UI_GUIDE 450줄 명시 read (1회) |
| phase 진입 결정성 | 비결정 | (a)③ 채택 시 비결정 잔존 | **frontmatter `sot:`로 100% 결정적** |
| drift 시 갱신 지점 | — | 3곳 (CLAUDE.md / REVISION / status.json) | **1곳 (해당 phase 파일)** |

내역:
- 현재 643 = PRD(22) + ARCH(70) + ADR(46) + UI_GUIDE(450) + CLAUDE.md(55)
- v2 적용 후 195 = PRD(22) + ARCH(70) + ADR(46) + CLAUDE.md(55) + frontmatter 22 phase × ~1줄 ≈ +2줄 노출

---

## 3. 개편 결정 사항

사용자 컨펌(2026-05-10):

| ID | 결정 | 해결 대상 |
|---|---|---|
| **(a)④** | phase 파일 frontmatter에 `sot:` 필드 추가 (v1의 C 부활) | F2 + F3 |
| **(b)②** | `phases/{task}/status.json`에 `active_revision` 필드 추가 | v1 H2 (REVISION 누적) |
| **(c)A** | KPI 숫자 정직 정정 → 본 문서 §2에 반영 완료 | v1 H1 |
| **(d)①** | `harness.md` §5에 codex 리뷰 흐름 1줄 추가 | harness.md ↔ CLAUDE.md 정합성 |

폐기: v1의 A(UI_GUIDE 제외 단일 변경) → v2 (a)④에 흡수, B(REVISION/README/status 자동 로드) → 폐기, D(CLAUDE.md 매핑 표) → 폐기.

---

## 4. 변경 명세

### 4.1 `.claude/commands/harness.md`

#### §1 자동 로드 — UI_GUIDE 제외 + lazy load 명시

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

#### §5 execute.py 실행 — frontmatter `sot` lookup + codex 흐름 명시

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

### 4.2 Phase 파일 frontmatter 표준 (22 phase 일괄 갱신)

#### 신규 frontmatter 스키마

```yaml
---
name: {phase 이름}
duration_estimate: {예상 초}
verify: {선택 — 검증 명령}
sot: {필수 — 1차 SoT 파일 경로 (자기 자신이면 self)}
sot_aux: {선택 — 보조 SoT 파일 경로 배열}
---
```

#### Phase별 `sot` 매핑

| Phase | sot | sot_aux |
|---|---|---|
| 1~4 (core, 완료) | `self` (phase 파일 본문) | — |
| 5 (input-action-foundation, 완료) | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| **6 (game-flow-foundation)** | `docs/GAME_FLOW_PROPOSAL_V5.md` | `[phases/mvp/REVISION_2026-05-09.md]` |
| 7 (input-pad) | `docs/INPUT_PLAN.md` | `[docs/INPUT_MAPPING.md]` |
| 8 (input-pause) | `docs/INPUT_PLAN.md` | — |
| 9~13 (UI track) | `docs/UI_GUIDE.md` | `[docs/INPUT_PLAN.md]` (필요 시 design_handoff 명시 read) |
| 14~20 (stage track) | `docs/PRD.md` | `[docs/ARCHITECTURE.md]` |
| post-MVP 21~23 | phase 진입 시 결정 — `sot:` 필드 비워두기 금지, 진입 시 즉시 채움 | — |

#### 갱신 정책
- phase 추가/이름 변경 시: **그 phase 파일 1곳만** 갱신
- post-MVP 21~23은 진입 시점에 `sot:` 결정해서 즉시 채움 (placeholder 금지 — 결정성 위해)

### 4.3 `phases/mvp/status.json`

신규 필드 추가:

```json
{
  "active_revision": "phases/mvp/REVISION_2026-05-09.md",
  "...(기존 필드)"
}
```

- 용도: 미래 v4/v5 revision 추가 시 "현재 유효" 1개를 결정적으로 식별
- 자동 로드 X — 모델이 phase 구조 결정 맥락 필요할 때 status.json read 후 그 경로로 명시 read
- 갱신 시점: 새 REVISION 작성 후 (현재는 v3 = `REVISION_2026-05-09.md` 고정)

### 4.4 `scripts/execute.py`

점검 항목:
- `python scripts/execute.py {task} next` 출력이 phase 파일의 frontmatter를 **포함**해서 stdout에 노출하는지 확인
- 본문만 출력하면 모델이 frontmatter `sot` 필드를 못 봄 → 결정성 깨짐
- 미포함이면 frontmatter도 출력하도록 수정 (변경 분량 작음, 1~5줄 예상)

---

## 5. 적용 순서

1. **본 문서 사용자 컨펌** (지금 단계)
2. `.claude/commands/harness.md` §1 + §5 수정 (위 §4.1 diff)
3. 22개 phase 파일 frontmatter에 `sot` / `sot_aux` 추가 (위 §4.2 표 기준)
4. `phases/mvp/status.json`에 `active_revision` 필드 추가 (위 §4.3)
5. `scripts/execute.py next` 출력 점검 → 필요 시 frontmatter 포함 수정 (위 §4.4)
6. 별도 커밋 1개로 묶음 (메시지: `chore: harness 자동 로드 슬림화 + phase frontmatter sot 도입`)
7. 다음 새 세션에서 `/harness mvp` 호출 → §6 검증 기준으로 효과 확인

---

## 6. 검증 기준

| 항목 | 기준 | 측정 방법 |
|---|---|---|
| 자동 로드 줄 수 | ≤ 200 | 새 세션 시작 직후 시스템 자동 read 파일 합산 |
| phase 진입 결정성 | turn 1에 frontmatter `sot` lookup → 1차 SoT read | 새 세션에서 `/harness mvp` → 첫 turn 관찰 |
| 비-UI phase의 dead context | UI_GUIDE 부재 | 모델 컨텍스트 확인 |
| drift 갱신 지점 | 1곳 (phase 파일) | 시뮬레이션: 가상 phase 추가 시 영향 파일 수 카운트 |
| harness ↔ CLAUDE.md 정합성 | harness.md §5에 codex 흐름 명시 | grep |

---

## 7. 비범위 / 미결정

- `docs/design_handoff/` 자동 로드 — 1.4MB로 명시 read만 유지 (변경 없음)
- post-MVP 21~23 phase의 `sot:` 값 — phase 진입 시 결정 (지금 미리 채우지 않음 — 결정 시점이 너무 빠르면 잘못 매핑 위험)
- phase 파일의 OpenAPI-style 더 풍부한 메타데이터 표준화 — 현재 미고려, `sot` 도입 효과 측정 후 추후 결정
- `notion-phase-ids.json`은 본 개편과 무관 (phase 추가 시 별도 갱신 정책 유지)

---

## 8. 롤백 절차

문제 발견 시 비용 낮게 되돌릴 수 있도록 모든 변경을 비파괴로 설계:

1. `.claude/commands/harness.md` git revert (1 commit)
2. phase 파일 frontmatter `sot` 필드는 잔존해도 무해 — 어떤 코드도 강제 read 안 함
3. `status.json`의 `active_revision` 잔존 무해 — 자동 로드 안 됨
4. `scripts/execute.py` 변경 revert

전부 1 commit revert로 복구 가능. phase 파일 frontmatter는 잔존하더라도 동작에 영향 없음.

---

## 9. v1 대비 차이 요약

| 측면 | v1 (폐기) | v2 |
|---|---|---|
| 자동 로드 변화 | +487줄 (악화) | -448줄 (개선) |
| SoT 매핑 위치 | CLAUDE.md 표 (REVISION과 중복) | phase 파일 frontmatter (자기 phase에 동봉) |
| 갱신 지점 | 3곳 | 1곳 |
| 결정성 메커니즘 | CLAUDE.md 표 lookup (모델이 원본 vs 표 충돌 시 판단) | execute.py가 frontmatter 강제 노출 |
| 미래 revision 누적 대응 | glob 무방어 | `status.json.active_revision` 단일 포인터 |
| 비파괴성 | CLAUDE.md 변경 누적 | phase 파일 frontmatter 추가만 (revert 1commit) |
