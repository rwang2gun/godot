# Game Flow Proposal Cycle — Archive

이 폴더는 2026-05-09 game-flow 결정에 이르기까지의 자체 적대적 리뷰 사이클(v1~v5) 산출물 9개를 백업한다. **현재 유효한 결정안은 `docs/GAME_FLOW_PROPOSAL_V5.md`** (1차 SoT).

## 사이클 회고

| 라운드 | finding (H/M/L) | 핵심 변화 |
|---|---|---|
| v1 → v1 review | 0 / 1 / 1 | 진단 채택, slot swap 옵션 (오류) |
| v2 → v2 review | 0 / 4 / 4 | swap 오류 교정, mass-rename 안전성 보강 |
| v3 → v3 review | **1** / 4 / 3 | EventBus signature 충돌 발견 (HIGH) |
| v4 → v4 review | 0 / 3 / 6 | lifecycle 모호성 발견 |
| v5 → v5 review | **0 / 1 / 4** | 사이클 수렴, 결정안 확정 |

## 보존된 파일

| 파일 | 의미 |
|---|---|
| `GAME_FLOW_PROPOSAL.md` | v1 — 최초 제안 |
| `GAME_FLOW_PROPOSAL_REVIEW.md` | v1 리뷰 (slot swap 오류 포함) |
| `GAME_FLOW_PROPOSAL_V2.md` | v2 — slot swap 오류 교정 |
| `GAME_FLOW_PROPOSAL_V2_REVIEW.md` | v2 리뷰 |
| `GAME_FLOW_PROPOSAL_V3.md` | v3 — 의사코드 도입 |
| `GAME_FLOW_PROPOSAL_V3_REVIEW.md` | v3 리뷰 (EventBus signature HIGH) |
| `GAME_FLOW_PROPOSAL_V4.md` | v4 — signature 결정, lifecycle 명시 |
| `GAME_FLOW_PROPOSAL_V4_REVIEW.md` | v4 리뷰 |
| `GAME_FLOW_PROPOSAL_V5_REVIEW.md` | v5 리뷰 (사이클 종료 회고) |

## 결정 결과의 흡수 위치

v5의 결정 사항은 다음 파일들에 1차 반영됨:

- `docs/GAME_FLOW_PROPOSAL_V5.md` — 1차 SoT (그대로 보존)
- `phases/mvp/REVISION_2026-05-09.md` §15 — phase plan revision 기록
- `phases/mvp/phase06-game-flow-foundation.md` — phase 6 skeleton
- `phases/mvp/status.json` — 20개 phase 재정렬
- `phases/mvp/notion-phase-ids.json` — 23개 매핑 (post-MVP shift 포함)
- `phases/mvp/README.md` — phase 표 갱신
- `CLAUDE.md` — review cycle 정책 (plan stage HIGH 시 즉시 중단, 2026-05-09 갱신)

## 정책 변경 (2026-05-09 사용자 결정)

이 사이클이 v1~v5로 5라운드 소요된 결과, 사용자가 **plan stage 자동 재리뷰 사이클을 폐기**하기로 결정:

- **Plan stage**: codex HIGH 1건 이상 → 즉시 중단 + 사용자 결정. 자동 재리뷰 X
- **Impl stage (Step 7)**: 기존 사이클 유지 (자체 리뷰 → codex 재리뷰 → clean)

상세: `CLAUDE.md`, `phases/mvp/README.md` Step 4 / Step 7, memory `feedback_review_cycle_policy.md`.
