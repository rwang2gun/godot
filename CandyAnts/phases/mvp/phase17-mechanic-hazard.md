---
name: mechanic-hazard
duration_estimate: 7200
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---

# Phase 17 (16): mechanic-hazard

## 목표
Hazard 추상 + Water + 끈끈이 1차 구현. 사탕 손실 페일 룰을 4-카운터(ADR-002)에 연결.

## 변경 대상 (가이드 수준)
- `scripts/world/hazards/` — Hazard 베이스(Area2D, body_entered → 페일 처리), WaterHazard, StickyHazard 신규.
- `scenes/entities/hazards/` — Water · 끈끈이 시각화 + Area2D 설정 (collision_mask는 Ant Layer 3을 포함 — CLAUDE.md 규칙).
- `scripts/ant/` — hazard 진입 시 사탕 손실 처리 hook (트레잇 정의 · 페일 어휘는 §0.2 정책 준수, 금지 어휘 사용 X).
- `scripts/core/ScoreSystem.gd` — `candy_piece_lost` 시그널 구독 → 4-카운터(`original_hp / saved / in_transit / lost`) 갱신, 불변식 assert.
- `scripts/ui/HUD.gd` — Lost 카운터 표시 활성화.
- `scenes/stages/` — Water + 끈끈이 검증 stage scene.
- `data/stages/` — 신규 stage 데이터.

상세 명세는 phase 진입 시 `plans/phase17-plan.md`에서 결정.

## 검증 방법
1. Stage 1~16 회귀 무영향.
2. Water hazard 진입 시: 빈손 개미는 사탕 손실 카운터 변화 없이 탈락, 운반 중 개미는 사탕 손실 + 4-카운터 `lost++` / `in_transit--`.
3. 끈끈이 hazard 진입 시: 개미 이동 속도 감소 또는 일시 정지 (해방 메커니즘은 phase plan 결정).
4. ScoreSystem 불변식 (`saved + in_transit + lost ≤ original_hp`) 위반 시 assert 발화.
5. 클리어 술어: `candy.hp == 0 && in_transit == 0 → score = saved / original_hp` (사탕 손실 있어도 클리어 가능, 점수만 낮음).
6. 헤드리스 회귀 씬 PASS — Water · 끈끈이 hazard 동작 검증 씬 신규 추가.

## 엣지 케이스 (요지)
- 여러 Hazard 동시 진입 시 사탕 손실 1회만 처리 (이미 탈락 처리된 개미는 무시) — PROPOSAL §0.2 어휘 정책 준수.
- Builder의 Bridge / Sand-mound가 Water 위에 놓일 때 hazard와 발판이 같은 셀 점유 시 처리 (Hazard `set_disabled()` 또는 monitoring 토글). PROPOSAL §3.2.3 / §3.3.3.
- Floater 트레잇 보유 개미가 Water 진입 시 사탕 손실 처리 여부 (느린 낙하 + 수면 진입 시 정상 사탕 손실로 일관). phase plan 결정.

## 참조
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.3 Hazard](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#33-hazard-phase-17--16)
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §0.2 톤 폴리시 어휘 통일](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#02-톤-폴리시--어휘-통일) — 페일 어휘 · 금지 API 정의부.
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §3.5 ADR-002 4-카운터](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#35-adr-002-4-카운터--변경-없음)

## 톤 폴리시 (§0.2 어휘 정책 준수)
**본 phase는 페일 시스템 1차 도입으로 §0.2 어휘 정책 적용이 가장 까다롭다.** 페일 어휘는 "사탕 손실"로 통일. PROPOSAL.md §0.2가 명시한 금지 어휘 및 그와 동등한 직접 API 호출 · 상태 정의는 사용하지 않는다 (구체 어휘는 PROPOSAL.md §0.2 정의부 참조). 시그널 · 함수 · 상태 · UI 메시지 모두 동일 정책 적용.

기존 `phase14-stage4-hazard-water.md` 본문은 §0.2 금지 어휘 기반으로 작성되어 있어 그대로 복붙 금지 — 본 phase 명세 · 구현 · 코드 작성 시 정책 어휘로 재작성.

## Open decisions before implementation
phase 진입 시 `plans/phase17-plan.md`의 결정 항목으로 승격.

- Water 깊이: 단일 레벨 / 여러 단계?
- Water 전파 속도: 고정값 / stage 데이터 override?
- Water + 끈끈이 겹침: 어느 hazard 판정 우선?
- 끈끈이 해방 메커니즘: 시간 경과 자동 / Cutter 등 외부 개입 / 둘 다?
- 끈끈이 위 정착 허용 여부?
- 끈끈이 상태에서 능력 전이 허용 여부?
- 끈끈이 시각 · 사운드 후처리: 본 phase 최소 구현에 포함 / phase 20 polish로 넘김?
- Water 위 Bridge 생성: 허용 / 차단 / 조건부?
- Hazard 위 능력 전이 발생: 전이 완료 / 차단 / 지연?

## 표준 절차
plan/review/deferred는 [phases/mvp/README.md](README.md) 참조.
