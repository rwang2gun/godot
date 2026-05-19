---
name: mechanic-adaptation-settlement
duration_estimate: 7200
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---

# Phase 15 (14b): mechanic-adaptation-settlement

## 목표
Blocker + 민들레씨 분배자 + 정착 시스템 + 능력 전이 1차 구현 — 분배자가 정착하면 보유 트레잇(Floater 등)을 후속 개미에 자동 부여.

## 변경 대상 (가이드 수준)
- `scripts/skills/` — Blocker 스킬 + 분배자 스킬 등록 (`SkillRegistry.SKILL_SCRIPTS` 등록 1줄씩).
- `scripts/ant/` — 정착 상태 머신 또는 settlement controller, 능력 전이 로직.
- `scripts/world/` — 정착 좌표 마커 또는 settlement marker 노드 (분배자가 점유한 위치).
- `scenes/entities/` — 분배자 시각화 + 정착 시각 표식.
- `scenes/stages/` — 정착 + 능력 전이 검증 stage scene.
- `data/skills/` — 신규 스킬 리소스 2종.

상세 명세는 phase 진입 시 `plans/phase15-plan.md`에서 결정.

## 검증 방법
1. Stage 1~14 회귀 무영향.
2. Blocker 스킬을 받은 개미가 정착해 후속 개미를 막아 방향 전환 시키는 기존 동작 확인.
3. 분배자 스킬을 받은 개미가 트레잇 보유 상태로 정착 → 정착 좌표 진입 후속 개미에 트레잇 자동 부여 확인.
4. 능력 전이 받은 개미가 트레잇 동작(예: Floater 낙하 변형)을 정상 수행.
5. 100% 정착 도달 시 회수 동선 끊김 → puzzle 본질 신호 (PROPOSAL §0.7.5)로 처리되고 별도 페일 fire 없음 확인.
6. 헤드리스 회귀 씬 PASS.

## 엣지 케이스 (요지)
- 분배자가 운반 중 정착 진입 시 사탕 운반/정착/회수 판정 우선순위 (PROPOSAL §3.1.4).
- 능력 전이 받는 개미가 이미 다른 트레잇 보유 시 중복 부여 정책 (PROPOSAL §3.1.2 중복 처리).
- 분배자 사탕 UX는 A안 — 경고 없이 정착 허용 (PROPOSAL §3.1.3 / §5.3 결정 사항).

## 참조
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.1 정착 + 능력 전이 시스템](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#31-정착--능력-전이-시스템-phase-15--14b)
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.5 ADR-002 4-카운터](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#35-adr-002-4-카운터--변경-없음) — 정착은 별도 카운터 도입 여부 phase plan 단계에서 재검토.
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §0.7.5 100% 정착 → 회수 동선 설계](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#075-100-정착--회수-동선-설계-53-a안-부속-정책)

## 톤 폴리시 (§0.2 어휘 정책 준수)
PROPOSAL.md §0.2 어휘 정책 준수. "정착" · "임무 완수" · "사탕 손실" · "탈락"만 사용. 정착이 페일 처리가 아님을 명세 · UI · 로그 메시지 전반에서 일관되게 유지 (정착은 메카닉의 일부, 페일은 phase 17 hazard 도입 후 사탕 손실로 표기).

## Open decisions before implementation
phase 진입 시 `plans/phase15-plan.md`의 결정 항목으로 승격. 본 phase 명세에는 한 줄 요약만 둔다.

- 정착 트리거 조건: 타이머 / 위치 / 플레이어 입력 중 무엇?
- 정착 후 상태 머신: 기존 StateMachine 확장 vs 별도 settlement controller?
- 정착 해제 허용 여부?
- 능력 전이 범위: 반경 / 시간 / 직접 접촉 중 무엇?
- 전이 시각화: 파티클 / 아이콘 / 둘 다 / 없음?
- 이미 트레잇 보유 개미 중복 부여: 무시 / 갱신 / 스택?
- 전이 가능 트레잇: Floater만 vs 전체 vs 화이트리스트?
- 분배자 정착 중 사탕 충돌 시 운반/정착/회수 우선순위?
- 능력 전이 받은 개미가 이미 다른 트레잇 보유 시 처리 (위 중복 정책과 같은 규칙인가 다른가)?
- 정착 직후 hazard 진입으로 사탕 손실 처리 시 전이 완료/취소/지연?
- 정착 개미를 별도 카운터(`settled`)로 추적할 필요?

## 표준 절차
plan/review/deferred는 [phases/mvp/README.md](README.md) 참조.
