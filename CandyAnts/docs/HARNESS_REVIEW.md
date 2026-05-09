# Harness 명령 컨텍스트 효율 점검 및 개선안

작성일: 2026-05-09
대상: `.claude/commands/harness.md` (`/harness {task}` 명령)
범위: 세션 시작 시 `/harness mvp` 호출 시 자동 로드되는 컨텍스트의 효율과 누락

---

## 1. 현재 자동 로드 명세

`.claude/commands/harness.md` §1에서 정의된 자동 읽기 대상:

| 파일 | 줄 수 | 가치 |
|---|---|---|
| `docs/PRD.md` | 22 | 작음·범용 |
| `docs/ARCHITECTURE.md` | 70 | 작음·범용 |
| `docs/ADR.md` | 46 | 작음·범용 |
| `docs/UI_GUIDE.md` | **450** | UI phase에서만 가치 |
| **합계** | **588** | |

추가 시스템 자동 로드 (harness와 별도):
- `CLAUDE.md` (55줄) — project instructions
- `MEMORY.md` 인덱스 + linked memory 파일들 (auto memory)

---

## 2. 발견된 비효율

### F1. UI_GUIDE 자동 로드의 dead context — **HIGH**

**증상**: `docs/UI_GUIDE.md` (450줄)가 세션 시작 시 항상 로드됨.

**문제**:
- 다음 진입 phase = phase 6 (game-flow), phase 7 (input-pad), phase 8 (input-pause). **모두 UI 무관**
- UI_GUIDE는 phase 9~13 (UI track) 5개에서만 가치
- 전체 20 phase 중 25%에서만 필요, **75% 세션에서 dead context 약 ~3-5K tokens 낭비**

### F2. 1차 SoT 자동 로드 누락 — **HIGH**

**증상**: harness가 *공통 기반* 4개만 읽고, *현재 작업의 1차 SoT*는 자동 로드 안 함.

| 파일 | 줄 수 | 어느 phase의 SoT |
|---|---|---|
| `phases/mvp/REVISION_2026-05-09.md` | **524** | **현재 유효 phase 구조의 1차 SoT** (v3 game-flow 결정 포함) |
| `phases/mvp/README.md` | 186 | 7단계 표준 절차 |
| `docs/INPUT_PLAN.md` | 721 | phase 5/7/8 SoT |
| `docs/INPUT_MAPPING.md` | 370 | phase 5/7/8 보조 |
| `docs/GAME_FLOW_PROPOSAL_V5.md` | 732 | phase 6 SoT |
| `phases/mvp/status.json` | 227 | 현재 진행 상태 |

**문제**:
- harness 시작 후 모델이 *알아서* 추가 read 해야 하는데, harness 명세에 명시 없음
- 결과: 매 세션마다 *비결정적* 동작 (모델이 status.json 안 보면 옛 phase 가정 + cross-reference 오류)
- 특히 REVISION_2026-05-09.md는 현재 유효 결정의 1차 SoT인데 자동 로드 안 됨 → phase 번호 매핑 오해 위험

### F3. phase 파일에 SoT 포인터 부재 — **MEDIUM**

**증상**: 각 phase 파일이 본문 텍스트로 1차 SoT를 가리키지만 frontmatter에 기계 판독 가능한 필드 없음.

예: `phase06-game-flow-foundation.md`가 본문에 "GAME_FLOW_PROPOSAL_V5.md가 1차 SoT"라고 명시했지만 frontmatter는 `name` / `duration_estimate`만 있음.

**문제**:
- 모델이 phase 본문을 다 읽고 추출해야 하므로 토큰·시간 비효율
- 자동화(execute.py + harness)가 SoT를 추출해서 추가 로드하기 어려움

---

## 3. 측정값

| 항목 | 현재 | 권고안 적용 후 |
|---|---|---|
| harness 자동 로드 | 588줄 | 760줄 (UI_GUIDE 제외 + REVISION + README 추가) |
| 시스템 자동 로드 | CLAUDE.md (55줄) + memory | 동일 |
| phase 진입 시 동적 추가 (현재) | 비결정적 | 결정적 (phase frontmatter `sot:` 또는 CLAUDE.md 매핑 표 기반) |
| UI phase 진입 시 | 이미 로드됨 | + UI_GUIDE (450) |
| Input phase 진입 시 | 미로드 (모델이 알아서) | + INPUT_PLAN (721) |
| Phase 6 진입 시 | 미로드 (모델이 알아서) | + GAME_FLOW_V5 (732) |

**핵심 개선**: 총 줄 수보다 *결정성·SoT 보장*. 1차 SoT를 매번 명시 read 안 해도 되므로 후속 토큰 절감.

---

## 4. 개선 옵션

| # | 변경 | 효과 | 변경 위치 |
|---|---|---|---|
| **A** | UI_GUIDE를 자동 로드에서 제외, "UI phase 진입 시에만 읽기"로 표기 | -450줄 (75% 세션) | `.claude/commands/harness.md` |
| **B** | harness §1에 `phases/{task}/REVISION_*.md`와 `phases/{task}/README.md` 추가 자동 로드 | 1차 SoT + 표준 절차 자동 확보 | `.claude/commands/harness.md` |
| **C** | harness §5(execute.py)에 "next phase 진입 시 phase 파일 frontmatter `sot:` 필드를 자동 read" 명시 | phase별 SoT 자동 로드 | `.claude/commands/harness.md` + 모든 phase 파일 frontmatter |
| **D** | CLAUDE.md에 "phase별 1차 SoT 매핑" 표 추가 | 모델이 결정적으로 1차 SoT 식별 | `CLAUDE.md` |

---

## 5. 권고

**A + B + D 동시 적용** (`.claude/commands/harness.md` + `CLAUDE.md` 2곳 변경, 효과 즉시).

**C 보류**: 모든 phase 파일 frontmatter를 변경해야 하므로 비용 큼. D만으로도 동등 효과 확보 가능.

### 5.1 A 적용 — harness.md UI_GUIDE 제외

`.claude/commands/harness.md` §1을 다음과 같이 변경:

```markdown
### 1. docs/ 문서를 전부 읽는다 (자동)
순서대로 반드시 읽기:
- `docs/PRD.md` — 뭘 만드는지
- `docs/ARCHITECTURE.md` — 어떻게 만드는지
- `docs/ADR.md` — 왜 이렇게 만드는지

`docs/UI_GUIDE.md`는 UI track phase 진입 시 명시 read (자동 로드 X).
`docs/references/`는 추가 컨텍스트로만 참조, 강제 아님.
```

### 5.2 B 적용 — harness.md 1차 SoT 추가

§1 아래에 다음 항목 추가:

```markdown
### 1.1 task-level 1차 SoT 자동 로드 (자동)
`phases/{task}/REVISION_*.md` (있으면 모두) — task 내 phase 구조의 1차 SoT
`phases/{task}/README.md` — 표준 절차 (7단계)
`phases/{task}/status.json` — 현재 진행 상태

이 파일들이 phase 번호·이름·매핑·진입 절차의 결정적 기준.
```

### 5.3 D 적용 — CLAUDE.md phase ↔ SoT 매핑 표

`CLAUDE.md`에 다음 섹션 추가:

```markdown
## Phase별 1차 SoT 매핑 (현재 유효 — v3 game-flow 개정 후)

phase 진입 시 다음 1차 SoT를 추가 read한다. phase 파일 본문이 동일 SoT를 가리키지만, 결정성 위해 표로 명시.

| Phase 범위 | 1차 SoT | 보조 |
|---|---|---|
| Phase 1~4 (core) | `phases/mvp/phaseNN-*.md` 본문만 | — |
| Phase 5 / 7 / 8 (input) | `docs/INPUT_PLAN.md` | `docs/INPUT_MAPPING.md` |
| Phase 6 (game-flow) | `docs/GAME_FLOW_PROPOSAL_V5.md` | `phases/mvp/REVISION_2026-05-09.md` §15 |
| Phase 9~13 (UI) | `docs/UI_GUIDE.md` + `docs/design_handoff/` | `docs/INPUT_PLAN.md` (input 연계) |
| Phase 14~20 (stage) | 기존 `docs/PRD.md` / `docs/ARCHITECTURE.md` | — |
| post-MVP 21~23 | (확정 시점에 갱신) | — |

phase 추가/삭제 시 본 표를 동시 갱신.
```

---

## 6. 적용 시 추가 효과

1. **세션 시작 결정성 ↑**: 모델이 status.json만 보면 어떤 SoT를 추가 로드할지 결정적으로 판단
2. **dead context 제거**: UI_GUIDE 450줄을 75% 세션에서 미로드
3. **cross-reference 오류 방지**: REVISION 자동 로드로 옛 phase 번호 가정 위험 제거
4. **다음 세션 자동 안내**: 다음 세션에서 `/harness mvp` 시 phase 6이 1차 진입 → harness가 GAME_FLOW_PROPOSAL_V5.md를 결정적으로 추가 read

---

## 7. 측정 가능한 KPI (개선 후)

- harness 자동 로드 줄 수: 588 → 760 (UI_GUIDE 제외, REVISION/README 포함)
- UI phase 진입 시: + 450 (UI_GUIDE) — 동일
- 비-UI phase 진입 시: -450 (dead UI_GUIDE 제거) + 524 (REVISION 추가) = 순증 74줄
- phase별 SoT 동적 로드: 비결정적 → 결정적
- 모델이 phase 진입 시 추가 read 인스트럭션 횟수: 평균 2-3회 → 0~1회 (CLAUDE.md 표가 흡수)

---

## 8. 비범위

- post-MVP 21~23 SoT 매핑 — phase 진입 시점 결정
- design_handoff 폴더 자동 로드 — 1.4MB로 너무 크므로 명시 read만
- 외부 references 자동 로드 — 76KB이지만 강제 아님 유지

---

## 9. 적용 권고 순서

1. `.claude/commands/harness.md` §1 수정 (A 적용) + §1.1 신설 (B 적용)
2. `CLAUDE.md` 끝에 §"Phase별 1차 SoT 매핑" 추가 (D 적용)
3. 다음 세션에서 `/harness mvp` 호출 시 효과 확인 (REVISION 자동 로드 + UI_GUIDE 미로드)
4. C(phase 파일 frontmatter `sot:`)는 D만으로 충분하지 않을 때 도입

---

## 10. 미해결 결정 사항

- **C 도입 시점**: 지금 / phase 14 (stage track 진입) / 도입 안 함
- **post-MVP 21~23 SoT**: phase 진입 시 결정 vs 지금 미리 추정해서 표에 추가
- **harness §5 (execute.py 실행) 정확성**: 현재 명세는 `next` / `complete` 명령만 사용. plan-stage 자체 적대적 리뷰 사이클 부재 → CLAUDE.md 정책과의 정합성은 별도 점검 필요 (이번 세션 범위 외)
