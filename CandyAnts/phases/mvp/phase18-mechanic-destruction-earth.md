---
name: mechanic-destruction-earth
duration_estimate: 5400
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---

# Phase 18 (17a): mechanic-destruction-earth

## 목표
흙 지형 동적 파괴 메카닉 1차 구현 — Basher(수평 굴착) + Digger(수직 굴착). Terrain cell 단위 실시간 제거 (impl 시점 StaticBody2D registry 방식 채택 — plan v10 §3 + ADR-010).

## 변경 대상 (가이드 수준)
- `scripts/skills/` — Basher 스킬 + Digger 스킬 등록 (`SkillRegistry.SKILL_SCRIPTS` 등록 1줄씩).
- `scripts/world/` — Terrain cell 단위 동적 제거 헬퍼 (cell-keyed StaticBody2D registry + kind 분류 + atomic destroy API; plan §3).
- `scenes/entities/` — Basher · Digger 동작 시각화 (파편 · 진행 indicator는 phase 20 polish 영역).
- `scenes/stages/` — 흙 파괴 검증 stage scene (수평 흙벽 + 수직 흙기둥).
- `data/skills/` — 신규 스킬 리소스 2종.

상세 명세는 phase 진입 시 `plans/phase18-plan.md`에서 결정.

## 검증 방법
1. Stage 1~17 회귀 무영향.
2. Basher: 개미가 진행 방향의 흙벽을 수평으로 굴착해 통로 생성. 흙 셀이 정상 제거되고 다른 개미 통행 가능.
3. Digger: 개미가 수직 아래로 굴착해 통로 생성. 굴착 후 위쪽 개미의 fall-through가 정상 처리.
4. 흙 파괴와 hazard(Water · 끈끈이) · 생성물(Bridge · Sand-mound) 좌표 동시 점유 시 우선순위 확인 (phase plan 결정 사항 검증).
5. 헤드리스 회귀 씬 PASS.

## 엣지 케이스 (요지)
- 흙 동적 파괴 후 위쪽 개미의 fall-through 판정 타이밍 (즉시 재계산 vs 다음 physics tick) — PROPOSAL §3.4.1.
- Basher / Digger 파괴가 chain reaction을 만들 수 있는가 (인접 셀이 무너지는지) — PROPOSAL §3.4.1 TBD.
- 파괴 시도 셀이 hazard(Water · 끈끈이) 영역과 겹칠 때 — 발판 위 hazard 제거가 의도치 않은 동선을 만들지 않게 명세 필요.

## 참조
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.4.1 Basher + Digger (흙 지형, 17a)](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#341-basher--digger-흙-지형-17a)

## 톤 폴리시 (§0.2 어휘 정책 준수)
PROPOSAL.md §0.2 어휘 정책 준수. 흙 셀 제거는 "파괴" · "굴착" · "제거"로 표기. 개미 사탕 손실 처리는 phase 17 hazard에서 도입된 정책 어휘 그대로 사용.

## Open decisions before implementation
phase 진입 시 `plans/phase18-plan.md`의 결정 항목으로 승격.

- 흙 동적 파괴 후 위쪽 개미 fall-through: 즉시 재계산 / 다음 physics tick?
- Basher / Digger 파괴가 chain reaction 허용?
- 파괴 가능 영역 시각화: preview overlay / cursor hint / 없음?
- 흙 셀 제거 시 충돌 갱신 비용 — 한 번에 여러 셀 제거 시 batch 처리?
- 식물 지형(phase 19)과의 구분: TileMap layer / terrain set / custom data?

## 표준 절차
plan/review/deferred는 [phases/mvp/README.md](README.md) 참조.
