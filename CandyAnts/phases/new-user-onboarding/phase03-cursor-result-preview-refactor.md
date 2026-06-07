---
name: cursor-result-preview-refactor
duration_estimate: 10800
verify: python scripts/run_test.py tests/CursorKindByCategoryTest.tscn && python scripts/run_test.py tests/PlacementPreviewRefactorTest.tscn && python scripts/run_test.py tests/SkillRoutingByCategoryTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [docs/DOMAIN_MAP.md, scripts/world/PlacementPreview.gd, scripts/world/SkillSign.gd, scripts/ui/SkillToolbar.gd, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 3: cursor-result-preview-refactor

## 목표
**커서 = 결과물 모양**으로 만들고, 분산된 라우팅/미리보기 SoT를 **카테고리 SoT로 통합**한다. (STAGE_GUIDE_PLAN §0.8.2 + §0.8.3-3·§0.8.5)

## 배경
- 현재 커서는 전 스킬 동일(스킬 아이콘)이고, `PlacementPreview.PLACEMENT_SKILLS=[sand_mound,builder,bridge]`는 입력모델 혼재 + 무장 스킬(bridge/builder)을 탭-타임 고스트로 잘못 표시.
- 라우팅이 `SkillSign.SIGN_SKILLS`·`REUSABLE_SIGNS`·toolbar 분기로 3중 분산 → 카테고리 SoT 단일화(§0.8.5 이중 SoT 제거).

## 변경 대상
- `scripts/ui/SkillToolbar.gd`: 커서 = `SkillAffordance.cursor_kind_of(id)` — ICON(③)/SETTLE_FORM(②, 반투명 정착폼)/SIGN(①, 푯말)/DEVICE(④, 점프대). `_try_assign`/`try_assign_dragged`의 푯말 vs 개미탭 분기를 `SkillAffordance.glow_target_of`(SURFACE→설치, ANT→탭)로 대체.
- `scripts/world/SkillSign.gd`: `SIGN_SKILLS` 하드코딩 리스트를 카테고리 SoT 조회(`category == SIGN`)로 대체(동작 동일, SoT 단일화).
- `scripts/world/PlacementPreview.gd`: `PLACEMENT_SKILLS` 제거. **bridge/builder(③) 탭-타임 고스트 제거**(무장이라 위치가 나중 결정). 미리보기를 — ①/④ surface 고스트(푯말/장치, **Phase 2 `SignPlacement.resolve_surface_install_cell`이 반환한 셀에 렌더** — 글로우와 동일 SoT) + ②(반투명 정착폼, 타깃 최근접 적격 개미에 스냅)로 카테고리 파생 재배치. sand_mound(①)는 surface 글로우 + 결과 ghost(옵션).
- `tests/CursorKindByCategoryTest.{gd,tscn}` (신규): 카테고리별 cursor_kind 매핑·교체 단언.
- `tests/PlacementPreviewRefactorTest.{gd,tscn}` (신규): ③(bridge/builder) 탭-타임 고스트 **없음** + ①④ 고스트/② 반투명폼 렌더.
- `tests/SkillRoutingByCategoryTest.{gd,tscn}` (신규): SURFACE 카테고리는 설치 경로, ANT 카테고리는 개미탭 경로 — 기존 라우팅과 동치.

## 검증 방법
- 3 신규 테스트 PASS.
- **회귀(중요)**: 전 스킬 부여가 리팩터 후에도 동일 동작 — `tests/*Basher*`·`*Digger*`·`*Cutter*`·`*Bridge*`·`*Builder*`·`*SandMound*`·`*Floater*`·`*Blocker*`·`*LeafJump*` + S1~S9 clear 큐레이트. 라우팅 SoT 통합이 동작을 바꾸지 않음.

## 수용 기준
- `SkillSign.SIGN_SKILLS`·`PlacementPreview.PLACEMENT_SKILLS` 같은 분산 스킬 리스트 제거(또는 카테고리 SoT 위임).
- 무장 스킬(③)에 탭-타임 빌드 고스트 없음.
