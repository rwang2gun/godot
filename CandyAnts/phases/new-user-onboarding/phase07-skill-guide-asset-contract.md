---
name: skill-guide-asset-contract
duration_estimate: 7200
verify: python scripts/run_test.py tests/SkillGuideAssetContractTest.tscn && python scripts/run_test.py tests/SkillGuideAssetReportTest.tscn && python scripts/tools/report_skill_guide_assets.py --report-check
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [docs/ASSET_PRODUCTION_NEEDS.md, scripts/ui/SkillToolbar.gd, scripts/world/SkillSign.gd, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 7: skill-guide-asset-contract

## 목표
**신규 스킬 추가 시, 카테고리에 따른 가이드 에셋 제작 요청을 자동화**한다 — 카테고리별 필요 에셋을 계약화 + 누락 가드 테스트 + `ASSET_PRODUCTION_NEEDS.md` 자동 요청. (STAGE_GUIDE_PLAN §0.8.6)

## 배경
- §0.8.5 카테고리 SoT가 "신규 스킬 = 카테고리 1줄"을 보장하나, 그 스킬이 필요로 하는 **가이드 에셋(②정착폼·④장치 스프라이트, 공통 아이콘/커서, 카드 카피)**이 빠진 채 머지될 수 있음.
- 1인 개발 + AI 자산 모델이라(`ASSET_PRODUCTION_NEEDS.md`), 누락을 **시끄럽게 fail + 제작 요청으로 기록**해야 채워진다.
- 현재 10 스킬의 ②정착폼·④장치 스프라이트는 Phase 3에서 신설됨(placeholder 허용) → 본 phase는 그것을 **계약으로 못박고 미래 스킬에 강제**.

## 변경 대상
- `scripts/core/SkillAffordance.gd`: `CATEGORY_GUIDE_ASSETS: { Category → [required asset/copy keys] }` 추가(카테고리 SoT 옆 단일 출처). 공통(아이콘/커서/skill_label/guide.skill.{id}) + ②정착폼 스프라이트 경로 + ④장치 스프라이트 경로.
- `scripts/tools/report_skill_guide_assets.py` (신규): 등록 스킬 전체를 순회해 카테고리 요구 에셋/카피 존재 검사. **모드(codex R1 MEDIUM 대응 — 실패와 요청 생성을 한 워크플로에)**:
  - `--report-check` (verify·CI 기본): 누락분을 `docs/ASSET_PRODUCTION_NEEDS.md`의 "신규 스킬 가이드 에셋 요청" 섹션에 **먼저 멱등 기록(중복 없이 갱신)** → 그 다음 누락 있으면 비정상 종료. **요청 생성과 실패가 같은 필수 경로**에서 일어남.
  - `--check` (선택, 읽기전용 CI): 기록 없이 누락 시 비정상 종료.
  - 누락 0이면 두 모드 다 exit 0 + 요청 섹션을 "없음"으로 정리.
- `tests/SkillGuideAssetContractTest.{gd,tscn}` (신규): 등록 스킬 전체가 카테고리 요구 에셋/카피를 만족(누락 시 fail + 목록 출력). 가짜 미등록-에셋 스킬로 fail 경로도 단언.
- `tests/SkillGuideAssetReportTest.{gd,tscn}` (신규, **R1 MEDIUM**): `--report-check`가 누락 주입 시 ① `ASSET_PRODUCTION_NEEDS.md` 요청 섹션을 갱신하고 ② 비정상 종료함을 **동시에** 단언 + 재실행 시 **중복 없이 멱등**. 누락 0이면 섹션 정리 + exit 0.
- `docs/ASSET_PRODUCTION_NEEDS.md`: "F. 신규 스킬 가이드 에셋 계약(카테고리 파생)" 섹션 신설 — 계약 표 + 자동 요청 출력 위치 명시.
- `CLAUDE.md`(프로젝트): "새 스킬 추가 시 SkillRegistry preload 1줄" CRITICAL 항목에 **"+ SkillAffordance 카테고리 1줄 + 가이드 에셋 계약 충족(또는 report 도구로 요청 기록)"** 추가. (프로젝트 헌법 변경 — 본 phase 산출물에 포함)

## 검증 방법
- `SkillGuideAssetContractTest` PASS — 현 10 스킬이 계약 충족(Phase 3 정착폼/장치 스프라이트 전제).
- `report_skill_guide_assets.py --check` exit 0 — 누락 없음. (누락 주입 시 비정상 종료 + 요청 기록 동작은 테스트가 단언)
- 회귀 0 — 계약/리포트는 빌드타임 가드, 런타임 게임플레이 무변경.

## 수용 기준
- 신규 스킬을 카테고리만 선언하고 에셋을 빠뜨리면 `SkillGuideAssetContractTest`가 **fail**하고 무엇이 없는지 출력.
- `report` 도구가 누락 에셋을 `ASSET_PRODUCTION_NEEDS.md` 제작 요청으로 기록.
- CLAUDE.md 스킬 추가 규칙이 카테고리+에셋 계약을 포함.
