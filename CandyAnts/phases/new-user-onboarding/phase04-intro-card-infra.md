---
name: intro-card-infra
duration_estimate: 9000
verify: python scripts/run_test.py tests/StageIntroCardShowTest.tscn && python scripts/run_test.py tests/StageRunnerBeginGateTest.tscn && python scripts/run_test.py tests/StageIntroCardHeadlessSkipTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [scripts/ui/StageDialog.gd, scripts/core/StageRunner.gd, scripts/core/SceneFlow.gd, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 4: intro-card-infra

## 목표
스테이지 진입 인트로 카드의 **인프라**를 신설한다(내용은 Phase 5) — `StageIntroCard` + 스폰/타이머 게이트 + 헤드리스 스킵. (STAGE_GUIDE_PLAN §2.1~§2.3·§2.5·§2.7)

## 배경
- `StageRunner._ready()`가 `_spawner.start()`를 즉시 호출(`StageRunner.gd:80`) → 카드가 닫힐 때까지 스폰/타이머를 게이트해야 함.
- 헤드리스 테스트(`run_test.py`)·플레이테스트 진입은 카드 없이 즉시 시작해야 회귀가 안 깨짐.

## 변경 대상
- `scenes/ui/StageIntroCard.tscn` + `scripts/ui/StageIntroCard.gd` (신규): `StageDialog` 패턴 복제(`PROCESS_MODE_ALWAYS`, Motion.fade_in/caPop, CButton 시작/건너뛰기, Esc dismiss via `_unhandled_input`). `show_intro(stage_data)`/`intro_dismissed` 시그널/`is_showing()` inspector. 내용은 placeholder(Phase 5에서 데이터 바인딩).
- `scripts/core/StageRunner.gd`: `_ready`의 즉시 start를 `begin()`으로 분리. 카드 있으면 `intro_dismissed` 후 `begin()`, 카드 없음/헤드리스 스킵이면 즉시 `begin()`. `AntSpawner.start` degraded 동기 emit ordering 가드 유지.
- `scripts/core/SceneFlow.gd`: 스테이지 로드 시 카드 노출 배선 + 헤드리스/플레이테스트 스킵 플래그.
- `tests/StageIntroCardShowTest.{gd,tscn}` (신규): 진입 시 카드 표시 → "시작" → `intro_dismissed` → `begin()` 1회. Esc dismiss.
- `tests/StageRunnerBeginGateTest.{gd,tscn}` (신규): 카드 미닫힘 동안 스폰/타이머 미시작, 닫으면 정확히 1회 begin.
- `tests/StageIntroCardHeadlessSkipTest.{gd,tscn}` (신규): 헤드리스/스킵 플래그 시 카드 없이 즉시 begin(스폰 시작).

## 검증 방법
- 3 신규 테스트 PASS.
- **회귀(중요)**: 기존 헤드리스 스테이지 테스트(S1~S9 clear/neg, GameFlow, SceneFlow)가 begin 게이트 분리 후에도 동일 — 카드 스킵으로 즉시 begin.

## 수용 기준
- `StageRunner.begin()`가 테스트에서 직접 호출 가능(카드 의존 없음).
- 카드 표시 중 게임 정지(스폰·타이머 미진행), 닫으면 정확히 1회 시작.
