---
name: guide-data-copy
duration_estimate: 10800
verify: python scripts/run_test.py tests/StageGuideDataRenderTest.tscn && python scripts/run_test.py tests/GuideSkillSubsetDriftGuardTest.tscn && python scripts/run_test.py tests/StringsTableTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [scripts/core/Strings.gd, scripts/core/StageData.gd, docs/DOMAIN_MAP.md, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 5: guide-data-copy

## 목표
인트로 카드에 **실제 가이드 내용**을 바인딩한다 — 가이드 데이터 리소스 + 카피 + S1~S8 작성 + 드리프트 가드. (STAGE_GUIDE_PLAN §2.4·§3·§4·§5)

## 배경
- 카드 내용 = 신규 스킬(카테고리 배지 포함) + 목표/스킬/해저드 카피. 카피는 `Strings.gd` 중앙화(프로젝트 규칙).
- "카드가 광고하는 스킬 ⊆ stage.available_skills" 가드로 레벨 개정 시 카드 자동 검증(§1 드리프트 재발 방지).

## 변경 대상
- `scripts/core/StageGuideData.gd` (신규): 스테이지별 가이드 메타 — 신규 스킬 id 배열 + 카피 key 배열 + 해저드 플래그(§2.4 B안).
- `data/guides/stageNN_guide.tres` ×8 (신규, S1~S8): §4 스테이지별 계획 반영. 신규 스킬은 그 스테이지 첫 등장 스킬만. 스킬 칩은 `SkillAffordance.category_of` 배지 + `SkillToolbar.ICONS` + `Strings.skill_label` 재사용.
- `scripts/core/Strings.gd`: `guide.sN.*`(목표/스킬설명/해저드) + `guide.badge.*`(입력모델 배지 라벨) 추가.
- `scripts/ui/StageIntroCard.gd`: placeholder → `StageGuideData` 바인딩(타이틀=display_name, 목표/스킬칩/해저드 렌더).
- `tests/StageGuideDataRenderTest.{gd,tscn}` (신규): 카드가 S1·S5·S8 가이드 데이터로 올바른 칩/카피/배지 렌더.
- `tests/GuideSkillSubsetDriftGuardTest.{gd,tscn}` (신규, **CRITICAL 가드**): 각 stageNN_guide의 신규 스킬 ⊆ `stageNN.tres.available_skills`. 어긋나면 fail.

## 검증 방법
- 3 신규/갱신 테스트 PASS(StringsTableTest 포함 — 새 key 정합).
- 드리프트 가드가 §1의 서술↔라이브 불일치류를 카드 레벨에서 차단.

## 수용 기준
- 카드 카피 100% `Strings.gd`(씬 하드코딩 0).
- S1~S8 가이드 데이터의 신규 스킬이 라이브 `available_skills` 부분집합.
- 입력모델 배지가 카테고리 SoT 파생(어포던스와 동일 어휘).
