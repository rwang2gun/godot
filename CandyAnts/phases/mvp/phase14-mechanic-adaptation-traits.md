---
name: mechanic-adaptation-traits
duration_estimate: 5400
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---

# Phase 14 (14a): mechanic-adaptation-traits

## 목표
Climber + Floater 트레잇 도입 — 수직 적응 능력과 민들레씨 보유 트레잇을 개미에 부여하는 메카닉 1차 구현.

## 변경 대상 (가이드 수준)
- `scripts/ant/` — Climber/Floater 트레잇 데이터 모델 (보유 여부 플래그 또는 컴포넌트), 벽 감지 + 낙하 변형 로직.
- `scripts/skills/` — Climber/Floater를 부여하는 스킬 등록 (`SkillRegistry.SKILL_SCRIPTS`에 preload 1줄 추가).
- `scenes/entities/Ant.tscn` — 트레잇 시각 표식(아이콘·색상) hook.
- `data/skills/` — 신규 스킬 리소스.
- `scenes/stages/` — 트레잇 검증용 stage scene (수직 절벽 + 낙하 갭).

상세 노드 트리 · 시그널 contract · 트레잇 보유 표현 방식은 phase 진입 시 `plans/phase14-plan.md`에서 결정.

## 검증 방법
1. Stage 1~13 회귀 무영향 (기존 6상태 머신 + 스킬 등록 + 회귀 씬 모두 PASS).
2. Climber 부여 개미가 수직 벽을 올라가는 동작 확인 (기본 개미는 벽 앞에서 방향 전환).
3. Floater 부여 개미가 낙하 시 자유낙하 → 느린 낙하로 거동 변경 확인 (Hazard 진입 전까지 사탕 손실 없음).
4. 두 트레잇이 동시에 부여된 경우 양쪽 모두 작동.
5. 헤드리스 회귀 씬 (`tests/Stage03HeadlessTest.tscn` 등) PASS.

## 엣지 케이스 (요지)
- 트레잇 보유 개미가 정착(phase 15)에서 후속 개미에 능력을 전이할 수 있어야 한다 — 본 phase는 **보유 트레잇** 도입까지만 다루고, 전이 트리거는 phase 15 범위 (PROPOSAL §3.1.2).
- Climber + Floater 동시 보유 시 우선순위(벽 등반 중 낙하 변형이 끼어드는지) — PROPOSAL §3.1.4 엣지 케이스 영역. 본 phase plan에서 결정.

## 참조
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.1.2 능력 전이](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#312-능력-전이) — 트레잇이 전이 대상이라는 전제.
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §2.1 묶음 한 줄 요약](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#21-묶음-한-줄-요약) — 14a 묶음 정의.

## 톤 폴리시 (§0.2 어휘 정책 준수)
본 phase 명세 · 코드 · UI는 PROPOSAL.md §0.2의 어휘 정책을 따른다. 페일 어휘는 "사탕 손실", 상태 어휘는 "정착" · "임무 완수" · "탈락"만 사용. 본 phase는 hazard·페일 처리를 직접 도입하지 않지만, 트레잇 시각 표식 · 메시지 작성 시 동일 정책을 준수.

## Open decisions before implementation
phase 진입 시 `plans/phase14-plan.md`의 결정 항목으로 승격해 채운다. 본 phase 명세에는 한 줄 요약만 둔다 (PROPOSAL TBD 본문 직접 복사 금지).

- 트레잇 보유는 컴포넌트(별도 노드)인가, Ant 노드 상의 플래그인가? (확장성 vs 단순성)
- Climber 벽 감지 기준은 RayCast2D인가, TileMap cell 조회인가?
- Floater 낙하 변형은 중력 계수 조정인가, 별도 fall 상태 분기인가?
- 트레잇 시각 표식은 아이콘 overlay인가, sprite 색조 보정인가, 둘 다인가?
- 본 phase 검증용 stage scene을 별도 폴더(`scenes/stages/dev/`)로 분리할 것인가?

## 표준 절차
plan/review/deferred는 [phases/mvp/README.md](README.md) 참조.
