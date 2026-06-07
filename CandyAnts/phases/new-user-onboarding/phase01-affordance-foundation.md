---
name: affordance-foundation
duration_estimate: 9000
verify: python scripts/run_test.py tests/SkillAffordanceCategoryTest.tscn && python scripts/run_test.py tests/OutlineGlowSmokeTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [docs/DOMAIN_MAP.md, scripts/core/SkillRegistry.gd, scripts/ui/Motion.gd, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 1: affordance-foundation

## 목표
어포던스의 두 기반 primitive를 게임 배선 없이 신설한다 — ① **카테고리 단일 SoT**(스킬→입력모델), ② **외곽선 셰이더 글로우** 헬퍼. (STAGE_GUIDE_PLAN §0.8.5 + §0.8.3-2)

## 배경
- 현재 입력모델 분류가 `SkillSign.SIGN_SKILLS` 등에 분산. 신규 스킬 확장성을 위해 카테고리를 단일 SoT로 모은다(CRITICAL, §0.8.5).
- 개미/타일 하이라이트 인프라가 전무(`Motion`은 fade/pop tween만). 외곽선 셰이더를 재사용 가능하게 신설.

## 변경 대상 (신규 — sot_aux에는 미기재, 실존 후 후속 phase가 참조)
- `scripts/core/SkillAffordance.gd` (신규): `enum Category { ANT_ARMED, ANT_SETTLE, SIGN, DEVICE }` + `SKILL_CATEGORY: {skill_id→Category}`(10종) + `CATEGORY_AFFORDANCE: {Category→{glow_target: ANT|SURFACE, cursor_kind: ICON|SETTLE_FORM|SIGN|DEVICE}}` + 조회 헬퍼(`category_of(id)`, `glow_target_of(id)`, `cursor_kind_of(id)`).
- `assets/shaders/outline.gdshader` (신규): 외곽선 폭·색·펄스 알파 uniform. Sprite2D/타일 rect에 적용.
- `scripts/ui/Glow.gd` (신규, `scripts/ui/`): 노드/셀에 outline 머티리얼을 붙였다 떼는 헬퍼(펄스 tween 포함). `Tokens` 팔레트 사용.
- `tests/SkillAffordanceCategoryTest.{gd,tscn}` (신규): **확장 가드** — `SkillRegistry.SKILL_SCRIPTS` 모든 스킬이 `SKILL_CATEGORY`에 존재(누락 시 fail) + 각 카테고리의 glow_target/cursor_kind 매핑 단언.
- `tests/OutlineGlowSmokeTest.{gd,tscn}` (신규): Sprite + 타일 rect에 Glow 적용/해제 헤드리스 스모크(머티리얼 부착·uniform 세팅 확인).

## 검증 방법
- `SkillAffordanceCategoryTest` PASS — 10 스킬 카테고리 커버리지 + 매핑 정합. (신규 스킬이 카테고리 빠뜨리면 여기서 깨짐)
- `OutlineGlowSmokeTest` PASS — 셰이더 컴파일·부착·해제 무오류.
- 게임플레이 배선 없음 → 기존 회귀 0(코어 미변경).

## 수용 기준
- 카테고리 SoT가 DOMAIN_MAP §2.1 4분류와 일치.
- Glow 헬퍼가 modulate-only가 아닌 외곽선 셰이더 기반(§0.8 결정).
- 기존 분산 SoT(`SkillSign.SIGN_SKILLS` 등)는 **이 phase에선 변경 안 함**(Phase 3에서 흡수) — 단 카테고리 SoT가 동일 분류를 표현하는지 테스트로 교차 확인.
