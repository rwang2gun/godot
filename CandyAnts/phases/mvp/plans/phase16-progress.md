# Phase 16 Progress — 세션 재진입용 (2026-05-23 작성 · 2026-05-24 v7 갱신)

> **목적**: phase 16 plan v7(codex Round 3 R3-H1 fix + grace 재충전 정책 명시) 후 codex Round 4 진행 직전 시점 박제. 다음 세션이 즉시 이어갈 수 있도록 현재 상태·결정·미해결 갈래를 한 페이지에 박아 둔다.

---

## 0. 첫 액션 (다음 세션 시작 시 그대로 실행)

```bash
python scripts/execute.py mvp validate       # 1회
python scripts/execute.py mvp                # 상태 확인 — Next: Phase 16
```

`docs/PRD.md` + `docs/ARCHITECTURE.md` + `docs/ADR.md` 자동 로드 후, 아래 §3 결정 후보 중 하나 선택해 진행.

---

## 1. 진행 위치

- **phase**: 16 mechanic-creation (Sand-mound + Bridge)
- **plan**: v7 — codex Round 3 R3-H1(bridge 첫 update off-floor hole) 사용자 직접 inline fix 완료 + N1+N3 cleanup(progress 갱신 + grace 재충전 정책 명시). codex Round 4 실행 직전
- **Notion DB**: 진행 중 (page_id `35bb23cf-3720-816b-9afe-ff7373c0430e`)
- **status.json**: phase 16 pending (변경 없음, validate만 실행)
- **커밋 0건. 구현 0건.**
- **Deferred nits** (N2/N4/N5): [phase16-deferred.md](phase16-deferred.md) — cross-doc wording tighten + fixture 옵션 정확도. impl 이후 sweep 가능.

### v5 변경 요약 (v4 self-review pass)

| # | 항목 | fix |
|---|---|---|
| H1 | §2.4 dev_sand_mound_layout / §2.5 SandMoundClimbTest "4-cell" | "5 cells" + PASS에 `tile_count == 5` 추가 |
| M1 | §7.3 Bridge 1-cell 갭 분석 | ray 도달 거리 풀어 tile_count=1로 정정. §5.2 3-cell 갭 case도 동일 논리로 재서술 |
| M2 | §11 Builder backward-compat risk row | Stage 01/02/03 각각 verbose 분석 + Stage03HeadlessTest 회귀 가드 추가 |
| M3 | §2.2 Terrain.gd 변경 (sprite scale) | `rect.size` cell_size 비례 + `scale_factor = cell_size/16.0`로 sprite.position·scale 비례 적용. cell_size=16 시 scale_factor=1.0 회귀 0건. §4.4 snippet도 일관 갱신 |

### v6 변경 요약 (codex Round 2 fix)

| # | 항목 | fix |
|---|---|---|
| R2-H1 | §4.2 `_update_bridge` fall guard 모순 | `_update_bridge` snippet에 `if _remaining < BRIDGE_MAX_LENGTH and not a.is_on_floor(): _aborted = true` 가드 도입. §7.5/§11 일관 정리. 신규 헤드리스 `tests/BridgeFallAbortTest` 추가 |
| R2-M1 | §11 risk row sand_mound "4-cell 갭" 잔존 | "5-cell 갭"으로 통일 |

> **주의**: v6의 `_remaining < BRIDGE_MAX_LENGTH` 단독 guard는 Round 3에서 폐기됨. v7 정책이 현재 기준.

### v7 변경 요약 (codex Round 3 fix + N1/N3 cleanup, 사용자 직접 수정)

| # | 항목 | fix |
|---|---|---|
| R3-H1 | §4.2 bridge 첫 update off-floor hole | `_remaining < BRIDGE_MAX_LENGTH` 면제 제거. 신규 필드 `_bridge_floor_grace_used` 도입. 첫 tile 전 off-floor는 1-frame grace로 return(`_tick_accum`/placement loop 모두 skip), 다음에도 off-floor이면 abort. tile 1개 이상 배치 후 off-floor도 즉시 abort. 신규 헤드리스 `tests/BridgeFirstTickOffFloorAbortTest` 추가. 기존 `BridgeFallAbortTest`는 mid-work fall만 검증으로 범위 축소. §0.2 strict acceptance 5조 신설 |
| N1 (Claude) | progress.md v6 stale | 본 문서 v7 갱신 (Round 3 결과 + v7 fix 요약 + Round 4 직전 상태 박제) |
| N3 (Claude) | §4.2 snippet의 grace 재충전 정책 미명시 | §4.2 snippet 주석 + §7.5 "Grace 재충전 정책" 단락 + §0.2 strict acceptance에 "Grace recharge after re-landing" 항목 추가. 1-frame 물리 진동 false abort 보호 의도 명시 |

## 2. working tree (커밋되지 않음)

```
?? phases/mvp/plans/phase16-plan.md            # v7 plan 본문
?? phases/mvp/plans/phase16-progress.md        # 본 문서 (v7)
?? phases/mvp/plans/phase16-deferred.md        # N2/N4/N5 cosmetic nit 박제
?? phases/mvp/reviews/phase16-plan-review.md   # Round 1+2+3 stdout 누적
 M phases/mvp/status.json                       # validate 자동 갱신 (실질 변경 없음)
```

## 3. 다음 단계 (2026-05-24 — codex Round 4 HIGH 0건 통과, R4-M1 명세 강화 완료, 구현 진입 가능)

**codex Round 4 결과** (plan v7 working-tree scope):
- Verdict: needs-attention (HIGH 0건, MED ×1)
- R4-M1: BridgeFirstTickOffFloorAbortTest fixture가 can_apply gate에 막혀 hollow test 가능 (= 사전 박제한 N5와 동일, codex가 권고 강화 추가)
- 권고: option (b) 제거 + can_apply 통과 + WorkerState 진입 명시 검증 + grace+abort 시퀀스로 8-step 재서술

**plan-stage policy 판정**: HIGH 0건 → 정책 통과. **구현 진입 가능.**

**R4-M1 처리** (사용자 결정 (A)):
- §2.5 BridgeFirstTickOffFloorAbortTest 명세를 8-step 시퀀스로 재서술 완료 (can_apply assert → apply → WorkerState 진입 assert → lift → grace frame 검증 → abort 검증). hollow test 방지.
- [phase16-deferred.md](phase16-deferred.md) N5 RESOLVED 마킹.

**Round 흐름 요약**:
| Round | HIGH | MED | 비고 |
|---|---|---|---|
| 1 | 2 | 0 | D8 stage cell + cell_size mismatch → v2~v4 |
| 2 | 1 | 1 | bridge fall guard 모순 + §11 4-cell → v5/v6 |
| 3 | 1 | 0 | bridge 첫 update off-floor hole → v7 (사용자 직접) |
| **4** | **0** | **1** | **R4-M1 = N5 흡수 → §2.5 명세 강화** |

**구현 진입 다음 액션**:
1. `python scripts/execute.py mvp` — Phase 16 진입 확인
2. plan §0.2 strict acceptance 5조를 self-check guide로 사용
3. impl 진행 → 자체 적대적 리뷰 → codex impl-stage 리뷰 → clean → `complete 16`

**Notion**: phase 16 진행 중 상태 유지 (id `35bb23cf-3720-816b-9afe-ff7373c0430e`). 완료 시 → 완료 변경.

## 4. 핵심 SoT 인용

- `phases/mvp/plans/phase16-plan.md` v7 — phase 16 1차 작업 SoT (frontmatter Status / §0.2 v7 row / §4.2 snippet / §7.5 Grace 재충전 정책)
- `phases/mvp/reviews/phase16-plan-review.md` — codex Round 1+2+3 finding 누적
- `phases/mvp/plans/phase16-deferred.md` — N2/N4/N5 cosmetic nit 박제
- `docs/PHASE_14_OPTION_B_PROPOSAL.md` §3.2 — 생성 메카닉 1차 SoT
- `phases/mvp/REVISION_2026-05-18-option-b.md` — v4 phase 매핑 SoT

## 5. 사용자 결정 기록 (AskUserQuestion 답변 누적)

| 질문 | 결정 | 시점 |
|---|---|---|
| Cell-size unification | **Unify to layout cell_size (Recommended)** — Terrain/WorkerState가 active StageLayoutData.cell_size 동기화 | 2026-05-23 (v2) |
| Stage-occupancy fix | **StageLayoutBuilder registers cells in Terrain (Recommended)** — 단일 SoT | 2026-05-23 (v2) |
| Round 2 needs-attention 대응 | **(A) HIGH+MED fix → v6 → Round 3** | 2026-05-24 |
| Round 3 needs-attention 대응 | "**따로 수정할게**" — 사용자 직접 v7 작성 | 2026-05-24 |
| v7 nit 대응 | **(A) N1+N3 fix → deferred N2/N4/N5 → Round 4** | 2026-05-24 |

## 6. 환경 / 제약

- Plan stage 정책 (CLAUDE.md): codex HIGH 발견 시 즉시 중단 + 사용자 결정, 자동 재리뷰 사이클 금지 → 본 세션이 그대로 이 흐름 따랐음 (Round 1 → 2 → 3 → 4 모두 사용자 명시 결정)
- Notion 동기화: 진입 시 진행 중 ✅, 완료 시 → 완료 (impl 단계에서 처리)
- `phase16-plan.md` + `phase16-progress.md` + `phase16-deferred.md` + `phase16-plan-review.md`는 phase 16 complete 시 execute.py가 자동 staging

## 8. 미해결 의문 (구현 진입 시 풀어야 함)

- §5.1 dev_sand_mound_layout의 정확한 cell 좌표 (ant 발 y vs MAX_HEIGHT=5 vs 상부 platform y 정합) — dev 수동 검증으로 미세 조정
- §5.4 SandBridgeOverlapTest의 same-frame multi-spawn — release_rate 조절 또는 spawn parent 코드 강제 placement
- §5.2 dev_bridge_layout의 갭 폭 정확도 (3 vs 4 cells에 따라 tile_count PASS 명제 가변) — 구현 시 fine-tune
- Builder backward-compat — Stage02HeadlessTest 회귀 검증 결과에 따라 §11 리스크 표 재검토
