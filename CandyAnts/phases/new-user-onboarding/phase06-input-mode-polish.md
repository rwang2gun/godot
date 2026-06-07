---
name: input-mode-polish
duration_estimate: 7200
verify: python scripts/run_test.py tests/GuideInputModeCopyTest.tscn && python scripts/run_test.py tests/OnboardingIntegrationTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [scripts/ui/InputHintLabel.gd, scripts/core/Strings.gd, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 6: input-mode-polish

## 목표
입력 모드(mouse/touch/pad)별 조작 카피 분기 + 카드↔어포던스 공통 시각 어휘 마감 + 통합 회귀. (STAGE_GUIDE_PLAN §2.6·§0.8.4)

## 배경
- 조작 안내("탭"/"클릭"/"A 버튼")는 `InputModeTracker` 현재 모드에 맞춰 분기(기존 `InputHintLabel` 패턴 재사용).
- 카드에서 배운 입력모델 배지 ↔ 인게임 글로우/커서가 같은 색·아이콘 어휘를 공유해야 학습이 이어짐.

## 변경 대상
- `scripts/ui/StageIntroCard.gd`: 조작 카피를 `InputModeTracker` 모드별 분기(`EventBus.input_mode_changed` 구독, `InputHintLabel` 패턴). 터치=hover 없음 안내.
- `scripts/core/Strings.gd`: `guide.op.mouse/touch/pad` 등 모드별 조작 문구.
- `scripts/world/AffordanceGlowController.gd` / `scripts/ui/SkillToolbar.gd`(커서): 카드 입력모델 배지와 글로우/커서 색·모티프 토큰 정합(공통 `Tokens` 사용 확인).
- 터치/패드 어포던스 보정: 터치=글로우가 주 신호(hover 커서 없음), 패드=`VirtualCursor`가 커서 대행(§0.8.3-4).
- `tests/GuideInputModeCopyTest.{gd,tscn}` (신규): mouse/touch/pad 모드별 카드 조작 카피 분기.
- `tests/OnboardingIntegrationTest.{gd,tscn}` (신규): 진입→카드(내용)→시작→어포던스(글로우/커서)→스킬 적용→클리어 1스테이지 E2E.

## 검증 방법
- 2 신규 테스트 PASS.
- **최종 통합 회귀**: S1~S9 clear/neg, GameFlow, SceneFlow, 전 스킬 스위트 — 온보딩 레이어가 코어 게임플레이에 회귀 0.

## 수용 기준
- 3 입력 모드 모두 조작 카피·어포던스 동작.
- 카드 배지 ↔ 인게임 글로우/커서가 동일 시각 어휘(색/아이콘).
- 전 캠페인 회귀 green.
