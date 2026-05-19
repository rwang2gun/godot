# Phase Plan Revision — 2026-05-18 (옵션 B v0.2)

> **목적**: phase 14~20을 stage 기반에서 **메카닉 기반** 7-phase 구성으로 재구성하는 v4 개정의 결정·매핑·산출물 SoT.
>
> **현재 유효 결정**: **v4 (본 문서)**. v1(`REVISION_2026-05-09.md` §1~7), v2(§8~14), v3(§15)는 **historical** — phase 14~20 구조는 본 v4가 덮어쓴다.
>
> **1차 SoT**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../docs/PHASE_14_OPTION_B_PROPOSAL.md) (옵션 B 제안서 v0.2)
> **마이그레이션 절차**: [docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md](../../docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md)

---

## 1. v4 개정 동기

phase 13(ui-title-menu) 완료 후 stage4~10(phase 14~20) 진입 직전, 사용자가 v0.1 비공식 원안에 누적된 디자인 변경을 정식 SoT로 박길 요청.

핵심 동기 3건:

1. **톤 폴리시 통일** — 대상 플레이어가 어린 플레이어. 사망 연출·폭력 묘사 전면 배제. 페일 어휘를 "사탕 손실"로 일괄 통일. 기존 phase14 본문(`phase14-stage4-hazard-water.md:19-21`)에 남아 있던 금지 어휘(`die()`/`DeadState`/사망/죽) 정책 위반 해소.
2. **메카닉 기반 재구성** — stage 단위 phase는 stage scene 단일 산출물에 메카닉이 묶여 phase 무게가 들쭉날쭉. 옵션 B v0.2는 phase를 **메카닉 시스템 단위**로 묶고 stage scene은 각 phase의 검증 산출물로 따로 본다.
3. **Bomber 삭제 + Cutter 신설** — Bomber(원형 파괴 + 사망 연출 강함)는 톤 폴리시 위배. 식물 지형 + Cutter(절단) 신설로 대체. Miner(대각선 굴착)도 흙 파괴는 Basher+Digger로 충분해 삭제.

---

## 2. v4 결정 사항 (잔여 5건 모두 확정)

PROPOSAL.md §5의 잔여 결정 5건 처리 상태 (PROPOSAL.md §5.1~§5.5와 동일 내용. 본 표는 phase 매핑과 직접 연결되는 결정만 요약).

| 항목 | 결정 | 근거 |
|---|---|---|
| §5.1 Phase 14 분할 14a/14b | **분할 채택** | 14b(정착 + 능력 전이) 시스템 부담 분리. 정수 id 정책(§7.1) 유지하며 라벨로만 a/b 표기 |
| §5.2 Phase 17 (파괴) 분할 17a/17b | **17a/17b 분할 채택** | 식물 지형 신설 + 흙 파괴 동시 진행 시 phase 무게 과적. 결과: 7-phase 구성 |
| §5.3 분배자 사탕 UX | **A안** (경고 없이 정착 허용) | 100% 정착 → 회수 동선 끊김 = puzzle 본질 신호 (PROPOSAL §0.7.5) |
| §5.4 상대 무게 재산정 | **잠정치 유지** | PROPOSAL §0.7.0 wall-clock 환산 금지. phase plan 단계에서 재조정 |
| §5.5 Phase 1~13 콘텐츠 재설계 | **별도 트랙 분리** | 본 옵션 B 범위 외. `codex-worklog/` 트랙 또는 v1.1 phase로 후속 처리 |

---

## 3. v4 phase 매핑 (7 phase)

### 3.1 매핑 표 — 기존 stage 기반 → 옵션 B 메카닉 기반

| id | 라벨 | 새 파일명 | 새 슬러그 | 묶음 | 무게 잠정 | 변경 종류 |
|---|---|---|---|---|---|---|
| 14 | 14a | `phase14-mechanic-adaptation-traits.md` | `mechanic-adaptation-traits` | Climber + Floater(민들레씨 보유 트레잇) | 5400 | 통합 (구 18 + 19 흡수) |
| 15 | 14b | `phase15-mechanic-adaptation-settlement.md` | `mechanic-adaptation-settlement` | Blocker + 민들레씨 분배자 + 정착 시스템 + 능력 전이 | 7200 | **신규** |
| 16 | 15  | `phase16-mechanic-creation.md` | `mechanic-creation` | Sand-mound(수직) + Bridge(수평) | 7200 | **신규** |
| 17 | 16  | `phase17-mechanic-hazard.md` | `mechanic-hazard` | Water + 끈끈이 + 사탕 손실 페일 룰 | 7200 | 통합 + 내용 교체 (구 14 hazard-water, 톤 폴리시 반영) |
| 18 | 17a | `phase18-mechanic-destruction-earth.md` | `mechanic-destruction-earth` | Basher + Digger (흙 지형 동적 파괴) | 5400 | 통합 (구 15 + 16 흡수) |
| 19 | 17b | `phase19-mechanic-destruction-plant.md` | `mechanic-destruction-plant` | Cutter + 식물 지형 신규 클래스 | 5400 | **신규** (구 17 Miner 자리, Cutter로 대체) |
| 20 | 18  | `phase20-polish.md` | `polish` | Release Rate + 별 시스템 + 정산 UI + 사운드 hook + 피날레 | 9000 | 내용 교체 (Bomber 삭제, 별/정산 UI/끈끈이 후처리 추가) |

**합계(잠정)**: 46800. PROPOSAL §2.4와 동일. v0.1 합계 유지하며 17 분할로 분배만 재구성.

### 3.2 기존 → 새 매핑 (요약)

| 기존 (stage 기반) | 새 (메카닉 기반) | 변경 종류 |
|---|---|---|
| phase14 stage4-hazard-water | phase17 mechanic-hazard | 통합 + 내용 교체 (톤 폴리시 어휘 일괄 치환) |
| phase15 stage5-basher | phase18 mechanic-destruction-earth | 통합 (Basher + Digger 묶음) |
| phase16 stage6-digger | (phase18에 흡수) | 통합 흡수 |
| phase17 stage7-miner | — | **삭제** (Cutter로 대체. PROPOSAL §1 / §3.4.2 / §5.2) |
| phase18 stage8-climber | phase14 mechanic-adaptation-traits | 통합 (Climber + Floater 묶음) |
| phase19 stage9-floater | (phase14에 흡수) | 통합 흡수 |
| phase20 stage10-bomber-polish | phase20 polish | 내용 교체 (Bomber 삭제, 별/정산 UI/끈끈이 후처리 추가) |
| — | phase15 mechanic-adaptation-settlement | **신규** (Blocker + 민들레씨 분배자) |
| — | phase16 mechanic-creation | **신규** (Sand-mound + Bridge) |
| — | phase19 mechanic-destruction-plant | **신규** (Cutter + 식물 지형) |

요약: 기존 7개 → 새 7개. 1:1 rename 없음. **신규 작성 3 + 통합·내용 교체 4**.

### 3.3 git mv 미사용 — 사유

PROPOSAL §7.2와 동일:
- 본문 유사도 매우 낮음 (톤 폴리시·신규 시스템·통합으로 거의 처음부터 작성).
- git이 자동으로 rename 인식하지 않을 가능성 높음.
- `execute.py:743-748`이 git rename 감지 시 complete를 hard reject (혼선 방지).

**결론**: `git rm` + 새 파일 `git add` 패턴. history는 본 REVISION + migration plan으로 보존.

---

## 4. v4 산출물 (working tree 변경)

```
신규 (Commit 1, 이미 main에 반영됨):
  docs/PHASE_14_OPTION_B_PROPOSAL.md         ← 1차 SoT
  docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md   ← 마이그레이션 절차
  phases/mvp/reviews/option-b-v0.2-plan-review.md   ← codex plan-stage review Round 1~7
  scripts/check_tone_policy.py               ← 톤 폴리시 어휘 검증 스크립트

신규 (Commit 3, 본 REVISION 포함):
  phases/mvp/REVISION_2026-05-18-option-b.md         ← 본 문서
  phases/mvp/phase14-mechanic-adaptation-traits.md
  phases/mvp/phase15-mechanic-adaptation-settlement.md
  phases/mvp/phase16-mechanic-creation.md
  phases/mvp/phase17-mechanic-hazard.md
  phases/mvp/phase18-mechanic-destruction-earth.md
  phases/mvp/phase19-mechanic-destruction-plant.md
  phases/mvp/phase20-polish.md

삭제 (Commit 3):
  phases/mvp/phase14-stage4-hazard-water.md
  phases/mvp/phase15-stage5-basher.md
  phases/mvp/phase16-stage6-digger.md
  phases/mvp/phase17-stage7-miner.md
  phases/mvp/phase18-stage8-climber.md
  phases/mvp/phase19-stage9-floater.md
  phases/mvp/phase20-stage10-bomber-polish.md

수정 (Commit 3):
  phases/mvp/metadata.json   ← active_revision → REVISION_2026-05-18-option-b.md
  phases/mvp/README.md       ← v4 개정 노트 + phase 14~20 표 갱신
  phases/mvp/status.json     ← sync-status --prune-missing 자동 갱신 (phase 1~13 보존)
```

본 v4 범위 **밖** (의도적 미수정):
- `phases/mvp/notion-phase-ids.json` — phase 14a 진입 시 일괄 처리 (migration plan §3.5 + §4 Commit 4).
- `docs/PRD.md` / `docs/ARCHITECTURE.md` / `docs/ADR.md` — 큰 틀 유지. PRD에 §0.2 페일 어휘 정책 명시는 별도 작업 (PROPOSAL §7.5).
- `phases/mvp/plans/phase01~13-plan.md` 등 phase 1~13 모든 산출물.

---

## 5. 검토 체크리스트 (다음 세션)

```bash
# 구조 확인
ls phases/mvp/phase*.md                            # 20개 (phase01~20, 단 14~20은 새 슬러그)
& $Python scripts/execute.py mvp validate          # 20 phase files; metadata + frontmatter clean

# active_revision 확인
grep active_revision phases/mvp/metadata.json      # REVISION_2026-05-18-option-b.md

# phase 14~20 새 슬러그 확인
& $Python scripts/execute.py mvp                   # Next: Phase 14 — mechanic-adaptation-traits

# 톤 폴리시 어휘 검증
& $Python scripts/check_tone_policy.py --commit3   # PASS: 0 forbidden token hits

# Notion 동기화 (phase 14a 진입 시점에 별도 처리, 본 시점에는 mapping 미갱신)
grep -E '"14":|"15":|"16":|"17":|"18":|"19":|"20":' phases/mvp/notion-phase-ids.json  # 옛 슬러그 유지
```

---

## 6. 리스크 / 결정 보류

| 리스크 | 영향 | 처리 |
|---|---|---|
| Commit 3 직후 status.json은 새 슬러그지만 notion-phase-ids.json은 옛 슬러그 | Notion DB 추적 일시 끊김 | 의도적 — phase 14a 진입 시 일괄 동기화 (migration plan §3.5). Notion 동기화 전 `next` 호출 금지 |
| 기존 phase14 본문의 §0.2 금지 어휘가 새 phase17에 복붙될 위험 | 톤 폴리시 위반 | `scripts/check_tone_policy.py --commit3`로 자동 검증 (PROPOSAL.md §0.2 정의부 exemption 포함) |
| 무게 잠정치를 wall-clock으로 오해 | 페이스 어긋남 | PROPOSAL §0.7.0 정책. `duration_estimate` 필드는 phase 간 상대 비교용 잠정치 |
| Phase 17 분할이 과분할로 판명 (phase 19 비어 보임) | 작업 흐름 어색 | 식물 지형 신설은 TileMap 신규 cell type 추가로 5400 적정. phase 19 진입 시 plan 단계에서 재조정 |

---

## 7. v4 codex review 회고

- **Plan stage**: codex adversarial-review 7 라운드 누적 (BLOCKER 3 + HIGH 3 + MEDIUM 3 + LOW 1 → HIGH 0 + LOW 1 PASS).
- 보존: [reviews/option-b-v0.2-plan-review.md](reviews/option-b-v0.2-plan-review.md).
- CLAUDE.md plan stage 정책상 자동 재리뷰 사이클은 라운드 폭증 + usage limit 우려로 금지지만, 본 작업은 task-wide 재구성이라 매 라운드 finding을 사용자가 검토한 후 다음 라운드를 명시적으로 트리거하는 방식으로 진행 (CLAUDE.md "사용자가 수정 방향·범위·취소 여부를 결정" 정책 준수).
- impl-stage 자체 적대적 리뷰 사이클은 phase 14a부터 phase 본체 구현 시 적용 (본 plan revision은 코드 변경 없음).

---

**작성**: 2026-05-19 / v4 plan revision (옵션 B v0.2 + §5.2 17 분할)
**참조**: [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../docs/PHASE_14_OPTION_B_PROPOSAL.md), [docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md](../../docs/PHASE_14_OPTION_B_MIGRATION_PLAN.md), [phases/mvp/README.md](README.md)
