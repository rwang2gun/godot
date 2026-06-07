# Phase 3 — cursor-result-preview-refactor · impl review

## 변경 요약
- **`scripts/ui/SkillToolbar.gd`**:
  - 커서 = `SkillAffordance.cursor_kind_of(id)` 파생(`_cursor_source`): ICON(③)=per-skill 커서 아이콘 / DEVICE(④)=`leaf_jump_pad.png` / SIGN(①)=푯말 보드+아이콘 합성(`_sign_cursor_texture`, 캐시) / SETTLE_FORM(②)=아이콘 fallback(아트 Phase 7).
  - 라우팅 = `SkillAffordance.category_of(id)` match: DEVICE→`_place_leaf_jump_pad` / SIGN→`_place_sign` / ANT_*→개미탭. `_try_assign`·`try_assign_dragged` 둘 다. (기존 `SIGN_SKILLS.has` + `=="leaf_jump"` 분기 대체.)
- **`scripts/world/SkillSign.gd`**: `SIGN_SKILLS` 하드코딩 const **제거**(카테고리 SoT로 단일화). `SIGN_BOARD_TEXTURE` 유지.
- **`scripts/world/PlacementPreview.gd`**: `PLACEMENT_SKILLS` 제거, 전면 재작성. ③(bridge/builder/climber) 탭-타임 ghost 폐지. ①④는 `SignPlacement.resolve_surface_install_cell`이 반환한 **커서 설치 셀** 기준(글로우와 동일 SoT): sand_mound=위로 rung 스택 / leaf_jump=pad 1칸 / basher·cutter·digger=결과 ghost 없음. ②=현재 없음(Phase 7 아트).
- **`scripts/ant/states/WorkerState.gd`**: BUILDER/BRIDGE 캡 주석의 stale `PlacementPreview.BUILDER_MAX/BRIDGE_MAX` 이중 SoT 참조 정정(③ ghost 폐지로 해소).
- **신규 테스트 3종**: CursorKindByCategory(kind별 소스 선택) / PlacementPreviewRefactor(③·② ghost 없음 + sand_mound 스택 + leaf_jump pad + 파괴형 없음) / SkillRoutingByCategory(실 toolbar `_try_assign`→SkillSign/LeafJumpPad/trait 산출 단언).

## 검증
- 신규 3 테스트 PASS.
- **광범위 회귀 25/25 PASS, 0 회귀**: BasherSign·CutterSign·SandMoundSign·LeafJumpSign·SignGroundSnap·SkillToolbar{CutterIntegration,PositionGuard,Reentry}·SkillDropAssign·PausedAssign·SignPlacementParity·TapTargetGlow×4·Cursor/Preview/Routing×3·CampaignS1/3/4/5/7/8/9 Clear.

## 수용 기준 점검
- `SkillSign.SIGN_SKILLS`·`PlacementPreview.PLACEMENT_SKILLS` 분산 리스트 제거 → 카테고리 SoT 위임. ✓
- 무장 스킬(③)에 탭-타임 빌드 고스트 없음(테스트 단언). ✓

## Self-Review Round 1
- 커서 합성 `get_image`/`blend_rect`(RGBA8 변환 후): 헤드리스 OK, 1회 캐시. (테스트 통과)
- 라우팅 match `_:` default = ANT_ARMED+ANT_SETTLE → 개미탭(정확).
- sand_mound 프리뷰 anchor를 nearest-ant→커서 설치셀로 변경: 실제 설치(SIGN=_place_sign이 커서 셀에 sign 생성)와 **정합되는 수정**(과거 nearest-ant는 설치와 불일치였음). 시각 전용, 게임로직 무영향(캠페인 회귀 통과).
- PlacementPreview dead code(_compute_targets/_find_closest_ant/CLICK_RADIUS/BUILDER_MAX/BRIDGE_MAX) 제거 — 외부 참조 0 확인.
- 자체 판정: HIGH/CRITICAL 0.

## Round 1 (codex adversarial-review)

Verdict: **needs-attention**

- **[medium] sand_mound 프리뷰가 설치 셀에 고정 — 실제 빌드 셀과 다를 수 있음** (`PlacementPreview.gd`): 푯말은 열(x)에 설치되고 실제 작업은 그 열에 도착한 개미의 body_cell에서 일어남(SkillSign._ant_at_cell + WorkerState). 다중 표면 컬럼에서 설치 셀 ≠ 빌드 셀 → 프리뷰가 잘못된 위치 안내.
  - 권고: deferred sign의 결과 ghost 제거(safer) 또는 트리거 규칙과 동일 계산.

## Self-Review Round 2 (Round 1 MEDIUM 수정)

- **sand_mound(및 모든 ①SIGN) 결과 ghost 제거**: SIGN은 deferred(설치≠빌드 셀 가능)이므로 결과 ghost 폐지. 설치 위치는 surface 글로우(Phase 2), 종류는 SIGN 커서가 표시 → 오도 위험 제거. plan §0.8.2가 sand_mound 결과 ghost를 "옵션"으로 명시 → 폐지 plan-compliant.
- **PlacementPreview는 이제 DEVICE(④ leaf_jump)만 프리뷰**: 장치는 SignPlacement 셀에 결정적 설치(설치=빌드 셀 항상 일치)라 발산 불가.
- 테스트 갱신: sand_mound 포함 ①SIGN 전부 ghost 없음 단언 + leaf_jump만 ghost. 3 테스트 재PASS.
- 자체 판정: HIGH/CRITICAL 0, R1 MEDIUM 해소(발산 가능성 자체 제거).

## 스코프 경계 (deferred)
- ② 정착폼 커서/프리뷰 아트 → Phase 7(asset contract). 현재 아이콘 fallback.
