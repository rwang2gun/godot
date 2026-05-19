---
name: mechanic-destruction-plant
duration_estimate: 5400
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---

# Phase 19 (17b): mechanic-destruction-plant

## 목표
Cutter 스킬 + 식물 지형 신규 클래스 1차 구현 — 식물 지형은 TileMap 신규 cell type. Bomber 자리 대체.

## 변경 대상 (가이드 수준)
- `scripts/skills/` — Cutter 스킬 등록 (`SkillRegistry.SKILL_SCRIPTS` 등록 1줄 추가).
- `scripts/world/` — 식물 지형 셀 처리 헬퍼 (식물 / 흙 구분, 절단 처리).
- `tilesets/` 또는 데이터 — 식물 지형 신규 TileMap cell type (terrain set 또는 custom data).
- `scenes/entities/` — Cutter 동작 시각화 + 식물 지형 placeholder.
- `scenes/stages/` — Cutter + 식물 지형 검증 stage scene.
- `data/skills/` — Cutter 스킬 리소스.

상세 명세는 phase 진입 시 `plans/phase19-plan.md`에서 결정.

## 검증 방법
1. Stage 1~18 회귀 무영향 (특히 phase 18 Basher / Digger 흙 파괴와 행위 분리 확인).
2. Cutter: 개미가 식물 지형 셀을 절단해 통로 생성. 절단 후 셀이 정상 제거되고 다른 개미 통행 가능.
3. 흙 지형은 Cutter로 파괴 불가, 식물 지형은 Basher / Digger로 파괴 불가 — 메카닉 분리 검증.
4. 식물 지형이 hazard / 생성 메카닉과 같은 좌표일 때의 우선순위 확인 (phase plan 결정 사항).
5. 헤드리스 회귀 씬 PASS.

## 엣지 케이스 (요지)
- 식물 지형 위 생성 메카닉(Sand-mound · Bridge) 허용 여부 (PROPOSAL §3.2.3 / §3.4.2).
- 절단 후 잔여물(파편 · 아이템) 처리 방식 (PROPOSAL §3.4.2 TBD).
- 식물 지형이 hazard 영역과 겹칠 때 우선순위 (PROPOSAL §3.4.2 TBD).

## 참조
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.4.2 Cutter + 식물 지형 (17b)](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#342-cutter--식물-지형-17b)
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §1 핵심 변경 요약](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#1-핵심-변경-요약-v01--v02) — Bomber 삭제 + Cutter 신설.

## 톤 폴리시 (§0.2 어휘 정책 준수)
PROPOSAL.md §0.2 어휘 정책 준수. Cutter 작동은 "절단" · "제거"로 표기. 식물 지형 신규 클래스 명명 시에도 §0.2 금지 어휘 사용 금지.

## Open decisions before implementation
phase 진입 시 `plans/phase19-plan.md`의 결정 항목으로 승격.

- Cutter 작동 범위: 인접 셀 1칸 / 라인?
- 식물 지형 vs 흙 지형 구분 기준: TileMap layer / terrain set / custom data?
- 절단 후 잔여물: 파편 / 아이템 / 즉시 제거?
- 식물 지형이 hazard와 겹칠 때 어느 판정 우선?
- 식물 지형 위 생성 메카닉(Sand-mound · Bridge) 허용?
- Cutter가 끈끈이 해방 메커니즘으로 작동하는가 (phase 17 §3.3.2 TBD와 연결)?

## 표준 절차
plan/review/deferred는 [phases/mvp/README.md](README.md) 참조.
