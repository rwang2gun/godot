---
name: mechanic-creation
duration_estimate: 7200
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---

# Phase 16 (15): mechanic-creation

## 목표
생성 메카닉 1차 구현 — Sand-mound(수직 발판) + Bridge(수평 발판). 기존 Builder의 발판 생성 모델을 확장한다.

## 변경 대상 (가이드 수준)
- `scripts/skills/` — Sand-mound 스킬 + Bridge 스킬 등록 (`SkillRegistry.SKILL_SCRIPTS` 등록 1줄씩).
- `scripts/world/` — 생성물 노드 / 동적 TileMap 셀 작성 헬퍼, 충돌 등록.
- `scenes/entities/` — Sand-mound, Bridge 시각화 + 진행 단계 표시.
- `scenes/stages/` — Sand-mound · Bridge 검증 stage scene (수직 갭 + 수평 갭).
- `data/skills/` — 신규 스킬 리소스 2종.

상세 명세는 phase 진입 시 `plans/phase16-plan.md`에서 결정.

## 검증 방법
1. Stage 1~15 회귀 무영향.
2. Sand-mound: 개미가 모래를 쌓아 위로 올라가는 발판 생성. 최대 높이 도달 시 멈춤.
3. Bridge: 개미가 갭을 가로지르는 수평 발판 생성. 수평 한계 거리 도달 시 멈춤.
4. 두 생성물이 다른 개미의 통행 발판으로 정상 작동.
5. 헤드리스 회귀 씬 PASS.

## 엣지 케이스 (요지)
- Sand-mound와 Bridge가 같은 좌표에 겹치면 어느 생성물이 우선하는가 (PROPOSAL §3.2.3).
- Hazard(Water · 끈끈이) 위 생성 시도 — 허용/차단/조건부 (phase 17과 상호작용. PROPOSAL §3.2.3).
- 미완성 Bridge 상태에서 개미가 사탕 손실 처리되면 잔재 처리 (PROPOSAL §3.2.2 TBD).

## 참조
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.2 생성 메카닉](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#32-생성-메카닉-phase-16--15)

## 톤 폴리시 (§0.2 어휘 정책 준수)
PROPOSAL.md §0.2 어휘 정책 준수. "사탕 손실" · "임무 완수" 사용. 미완성 생성물 처리 시 §0.2 금지 어휘는 사용하지 않는다 — 잔재는 "남김" · "제거" 같은 중립 어휘로 명세.

## Open decisions before implementation
phase 진입 시 `plans/phase16-plan.md`의 결정 항목으로 승격.

- Sand-mound 쌓기 속도: tick 기반 / 거리 기반?
- Sand-mound 최대 높이: 고정값 / stage 데이터 override?
- Sand-mound 생성 중 다른 개미 충돌: 통과 / 밀림 / 중단?
- Sand-mound 자연 무너짐 여부?
- Bridge 수평 거리 한계: 고정값 / stage 데이터 override?
- Bridge 시작/끝: 갭 자동 감지 / 플레이어 수동 지정?
- 미완성 Bridge에서 개미가 사탕 손실 처리 시: 잔재 유지 / 제거 / 즉시 완성?
- Sand-mound + Bridge 좌표 겹침: 어느 생성물 우선?
- Hazard 위 생성: 허용 / 차단 / 조건부?
- 식물 지형(phase 19) 위 생성 가능 여부와 우선순위?

## 표준 절차
plan/review/deferred는 [phases/mvp/README.md](README.md) 참조.
