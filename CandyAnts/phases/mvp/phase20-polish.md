---
name: polish
duration_estimate: 9000
verify:
large_change_ok: false
sot: docs/PRD.md
sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]
---

# Phase 20 (18): polish (MVP 종료)

## 목표
Release Rate + 별 시스템 + 정산 UI + 사운드 hook + 끈끈이 후처리 + 피날레 — MVP 종료. Bomber는 본 phase에서 도입하지 않는다 (PROPOSAL §1 / §3.4.2 Cutter로 대체).

## 변경 대상 (가이드 수준)
- `scripts/core/` — Release Rate 조정 시스템, 별 시스템 계산 헬퍼.
- `scripts/ui/` — 정산 UI(StageDialog 별 표시 강화 + 클리어 후 진행 표시), 사운드 hook 통합점.
- `data/stages/` — 모든 stage 별 산정 기준 데이터 (saved / original_hp 비율 → 별 1~3).
- `assets/audio/` 또는 placeholder — 사운드 hook용 placeholder만 (실제 BGM/SFX는 post-MVP phase 21).
- `scenes/ui/` — 정산 UI · 별 시각화 컴포넌트.
- `scripts/skills/` — Release Rate UI · 컨트롤 (input · UI는 phase 5~13에서 도입 완료, 본 phase는 stage 단위 적용).

상세 명세는 phase 진입 시 `plans/phase20-plan.md`에서 결정.

## 검증 방법
1. Stage 1~19 회귀 무영향.
2. Release Rate: 플레이어가 stage 진행 중 개미 출현 빈도를 조정 가능. 조정값이 다음 spawn에 반영.
3. 별 시스템: stage 클리어 시 saved / original_hp 비율로 별 1~3 산정. 정산 UI에 표시.
4. 정산 UI: clear / fail 모두 별 표시 + Next / Replay / Menu 액션 정상 (phase 6 game-flow 호환).
5. 사운드 hook: 모달 · 카운터 · 스킬 등 핵심 이벤트 hook 지점 명확화. 실제 사운드 재생은 post-MVP에서 연결.
6. 끈끈이 후처리: phase 17에서 미완료된 시각 · 사운드 polish (phase 17 명세에서 phase 20으로 넘긴 항목 처리).
7. 모든 헤드리스 회귀 씬 PASS — MVP 종료 검증.

## 엣지 케이스 (요지)
- Release Rate가 0이면 새 개미 spawn 중단 — fail 판정(no_more_ants)과의 상호작용 (phase 6 game-flow).
- 별 산정 시 사탕 손실이 있어도 saved 비율로 산정 — 클리어 가능하되 별 수만 감소 (PROPOSAL §3.5 4-카운터 정책 유지).
- 정산 UI · 사운드 hook이 phase 12 ui-stage-dialog 구조와 호환되는지 검증 (재작성 X, 확장 only).

## 참조
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §2.1 묶음 한 줄 요약](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#21-묶음-한-줄-요약) — phase 20 polish 묶음 정의.
- [docs/PHASE_14_OPTION_B_PROPOSAL.md §1 핵심 변경 요약](../../docs/PHASE_14_OPTION_B_PROPOSAL.md#1-핵심-변경-요약-v01--v02) — Bomber 삭제 + 별 시스템 / 정산 UI 신설.

## 톤 폴리시 (§0.2 어휘 정책 준수)
PROPOSAL.md §0.2 어휘 정책 준수. 정산 UI · 별 표시 · 클리어/페일 메시지 모두 "사탕 손실" · "임무 완수" · "탈락" 어휘로 통일. phase 12 ui-stage-dialog의 페일 어휘가 잔존하면 본 phase에서 일괄 치환.

## Open decisions before implementation
phase 진입 시 `plans/phase20-plan.md`의 결정 항목으로 승격.

- Release Rate 단위: 초당 / 프레임당 / stage 데이터 override?
- Release Rate UI 위치: HUD 내 / StageDialog 옆 / 별도 toolbar?
- 별 산정 기준: saved/original_hp 단순 비율 / 시간 보너스 포함 / stage별 override?
- 사운드 hook 인터페이스: signal / 전용 SoundController autoload / 직접 함수 호출?
- 피날레 시퀀스: 별도 cinematic 씬 / StageDialog 강화 / 타이틀 복귀만?
- post-MVP 사운드 phase 21에서 hook을 어떻게 받을지의 contract 명세 위치 (본 phase or phase 21)?

## 표준 절차
plan/review/deferred는 [phases/mvp/README.md](README.md) 참조.
