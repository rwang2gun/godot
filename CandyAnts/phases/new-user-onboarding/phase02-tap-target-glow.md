---
name: tap-target-glow
duration_estimate: 9000
verify: python scripts/run_test.py tests/TapTargetGlowAntTest.tscn && python scripts/run_test.py tests/TapTargetGlowSurfaceTest.tscn && python scripts/run_test.py tests/TapTargetGlowEligibilityTest.tscn && python scripts/run_test.py tests/SignPlacementParityTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [docs/DOMAIN_MAP.md, scripts/ui/SkillToolbar.gd, scripts/world/SkillSign.gd, scripts/skills/Skill.gd, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 2: tap-target-glow

## 목표
스킬 선택 시 **"어디를 탭하나"를 글로우로 표시**한다 — 카테고리 SoT 기준으로 ANT_* = 적격 개미 글로우, SIGN/DEVICE = surface 타일 글로우. (STAGE_GUIDE_PLAN §0.8.1~§0.8.3)

## 배경
- "반짝이는 걸 탭한다" 규칙의 핵심 구현. 4입력모델 혼란을 "개미 반짝 vs 타일 반짝" 2지선다로 축소.
- 글로우 대상·적격은 **Phase 1 카테고리 SoT + `Skill.can_apply`**에서 파생(하드코딩 금지).

## 변경 대상
- `scripts/ui/SkillToolbar.gd`: `_pending_skill_id` 변경 시 글로우 컨트롤러에 카테고리 통지(선택/해제 토글). 라우팅 분기는 Phase 3에서 SoT화 — 본 phase는 글로우 트리거만.
- `scripts/world/SignPlacement.gd` (신규, **공유 배치 검증 API** — codex R1 MEDIUM 대응): `resolve_surface_install_cell(terrain, skill_id, world_or_cell) -> {cell, valid, reason}`. 기존 `SkillToolbar._ground_cell_for_sign`(점유 거부 + 아래 64칸 스냅) + `_leaf_jump_pad_exists`(DEVICE 중복 거부) 로직을 **추출**해 단일 출처화. `SkillToolbar` 배치 경로를 이 API 호출로 교체(동작 동일).
- `scripts/world/AffordanceGlowController.gd` (신규, `scripts/world/`): 매 frame(또는 선택 시) 카테고리에 따라 — ANT_* → `get_nodes_in_group("ants")` 중 `is_alive() && skill.can_apply()` 개미에 `Glow` 적용 / SIGN·DEVICE → **`SignPlacement.resolve_surface_install_cell`이 `valid` 반환하는 셀**(스냅 타깃 = 지면 위 빈 셀, leaf_jump 중복 셀 제외) 글로우. 트리거 규칙(`SkillSign._ant_at_cell`)이 아니라 **실제 배치 규칙**과 동일 SoT. 부적격 무표시.
- `tests/TapTargetGlowAntTest.{gd,tscn}` (신규): ③/② 스킬 선택 시 적격 개미만 글로우, 타일 무글로우.
- `tests/TapTargetGlowSurfaceTest.{gd,tscn}` (신규): ①/④ 스킬 선택 시 `SignPlacement`가 valid한 surface 셀만 글로우(점유/허공 열 제외·스냅 타깃 표시), 개미 무글로우. leaf_jump 중복 pad 셀 제외.
- `tests/TapTargetGlowEligibilityTest.{gd,tscn}` (신규): `can_apply=false` 개미는 글로우 제외(예: 이미 무장/부적격 상태).
- `tests/SignPlacementParityTest.{gd,tscn}` (신규): `SignPlacement` API 결과 = 기존 `_ground_cell_for_sign`/`_leaf_jump_pad_exists` 동작(점유 거부·아래 스냅·중복 거부 케이스) — 추출이 회귀 없음 단언.

## 검증 방법
- 4 신규 테스트 PASS — 카테고리별 올바른 대상만 글로우 + 적격 게이팅 + 배치 API parity.
- 기존 스킬 부여/배치 동작(탭→적용, 푯말/점프대 스냅) 회귀 0 — 글로우는 시각 레이어, 배치는 동일 API로 이전.

## 수용 기준
- 글로우 대상 결정이 100% 카테고리 SoT + can_apply(개미) / `SignPlacement`(타일) 파생(스킬 id·배치 규칙 하드코딩 없음).
- **surface 글로우 셀 = 실제 클릭 성공 셀**(점유 거부·아래 스냅·leaf_jump 중복 거부 반영). 트리거 규칙(`_ant_at_cell`)과 혼동 금지.
