# Phase 2 — tap-target-glow · impl review

## 변경 요약
- **신규** `scripts/world/SignPlacement.gd` — 설치형(①)·장치(④) 공유 배치 검증 API. `resolve_surface_install_cell(terrain, skill_id, world_or_cell, sign_parent) -> {cell, valid, reason}`. 기존 `SkillToolbar._ground_cell_for_sign`+`_leaf_jump_pad_exists` 로직 추출(단일 출처).
- **신규** `scripts/world/AffordanceGlowController.gd` — 카테고리 SoT 파생 글로우. ANT_*→적격 개미(is_alive&&can_apply) Sprite 글로우 / SIGN·DEVICE→커서 아래 valid surface 셀(SignPlacement) 글로우. PlacementPreview 폴링 패턴 답습. `refresh(cursor)` 공개(테스트/런타임 공통).
- **수정** `scripts/ui/SkillToolbar.gd` — `_place_sign`/`_place_leaf_jump_pad`를 SignPlacement 호출로 교체, 중복 로직(`_ground_cell_for_sign`/`_leaf_jump_pad_exists`/`_SIGN_SNAP_MAX_CELLS`) 제거. 동작 동일.
- **신규 테스트 4종** — TapTargetGlowAnt(②③ 개미 글로우·타일 무) / TapTargetGlowSurface(①④ valid 셀 글로우·개미 무·스냅·중복 제외) / TapTargetGlowEligibility(can_apply 무장·사망 제외+동적 복귀) / SignPlacementParity(추출 회귀: 점유거부·스냅·중복·world↔cell 동치·null).

## 검증
- 신규 4 테스트 PASS.
- 툴바 배치 경로 회귀 세트 PASS (SignGroundSnap·BasherSign·CutterSign·SandMoundSign·LeafJumpSign·SkillToolbarCutterIntegration·PositionGuard·Reentry·DropAssign·PausedAssign 등 12종) — 0 회귀.

## 수용 기준 점검
- 글로우 대상 100% 카테고리 SoT(`SkillAffordance`) + `can_apply`(개미) / `SignPlacement`(타일) 파생 — 스킬 id·배치 규칙 하드코딩 없음. ✓
- surface 글로우 셀 = 실제 클릭 성공 셀(점유 거부·아래 스냅·leaf_jump 중복 거부) = `SignPlacement` 단일 출처. 트리거 규칙(`_ant_at_cell`)과 분리. ✓

## Self-Review Round 1

발견:
- **개미 글로우 생명주기**: queue_free된 개미는 다음 refresh에서 eligible 집합 제외 → `_remove_ant_glow`가 `is_instance_valid` 가드로 안전 erase. 누수/크래시 없음. (확인 OK)
- **idempotent**: 개미 글로우는 신규 적격에만 apply(`_glowing_ants` 추적), surface는 `Glow.apply` 멱등. per-frame 재apply 폭주 없음. (OK)
- **테스트 결정성 함정**: 지면 없는 개미는 물리 프레임에서 즉시 Faller로 떨어져 `is_on_floor()`=false(blocker/floater/bridge can_apply 요건 불충족) → 실제 바닥 fixture(layer 1, ant mask 3) 착지 후 `set_physics_process(false)`로 상태 고정. (수정 완료)

자체 판정: 구현 코드 자체 HIGH/CRITICAL 0.

## Round 1 (codex adversarial-review)

Verdict: **needs-attention**

- **[high] 글로우가 런타임 씬에서 인스턴스화되지 않음** (`AffordanceGlowController.gd`): Phase 3 배선 연기는 dead code를 ship — 실 스테이지에서 스킬 선택해도 글로우 미발생. 테스트가 통합 지점을 우회.
  - 권고: PlacementPreview 노드 옆에 valid toolbar/terrain path로 배선 + 수동 필드 주입 없는 stage-level 통합 테스트 추가.

(impl-stage 정책: HIGH는 defer 금지 → 즉시 수정.)

## Self-Review Round 2 (Round 1 HIGH 수정)

수정:
- **9개 stage 씬 배선**: `scripts/tools/wire_affordance_glow.py`(멱등 one-shot)로 9개 Stage0N.tscn의 `World/PlacementPreview` 옆에 `AffordanceGlowController` 노드 주입(동일 `toolbar_path=../../SkillToolbar`, `terrain_path=../Terrain`). PlacementPreview가 같은 경로로 검증된 배선이라 안전.
- **통합 테스트 신규** `tests/TapTargetGlowIntegrationTest`: 실 Stage01 로드 → 컨트롤러가 씬에 존재 + NodePath로 toolbar/terrain 해소(수동 주입 X) + 실 toolbar 선택 시 `_process` 폴링이 적격 개미 글로우. PASS(1 ant glowing).
- 회귀: CampaignS1/S3/S7/S8/S9 Clear·SceneFlowStageScan·SignPlacementParity·TapTargetGlow×3·Integration **전부 PASS**.
- **GameFlowTest Scenario B(Stage09)**: timeout 실패 — **`git stash`로 확인 결과 pristine HEAD에서도 동일 실패 = 선재 실패(내 변경 무관)**. CampaignS9ClearTest는 PASS라 Stage09 자체는 클리어됨. Phase 2 verify 대상 아님. 별도 추적(스코프 밖).

자체 판정: 구현 코드 HIGH/CRITICAL 0. dead-code 지적 해소(실 씬 배선 + 통합 테스트).

## Round 2 (codex adversarial-review)

Verdict: **needs-attention**

- **[high] `_place_leaf_jump_pad`가 미정의 `id` 참조 (line 295)** — **FALSE POSITIVE.** codex가 diff hunk만 읽고 메서드 상단 `var id := "leaf_jump"`(line 283) 선언을 못 봄. `id`는 정의돼 있고, `LeafJumpSignTest`(이 메서드를 직접 통과)가 PASS = 파싱/실행 정상 입증. SignGroundSnap·SignPlacementParity·Integration도 PASS.
  - 조치: 버그 아님이나, diff 자체-문서화 + 가독성 위해 `id` → `skill_id` 리네임(SignPlacement 파라미터명과 일치). 동작 무변경, LeafJumpSignTest 재PASS.

## Self-Review Round 3 (Round 2 대응)

- `_place_leaf_jump_pad` 로컬 `id`→`skill_id` 리네임(전부 일관). 동작 동일.
- codex-지목 4 테스트(LeafJumpSign·SignGroundSnap·SignPlacementParity·Integration) 전부 PASS 재확인.
- 자체 판정: 실제 결함 0(R2는 false positive). HIGH/CRITICAL 0.

## 남은 스코프 경계 (deferred, plan 정합)
- **입력 모드 분기**(touch hover 없음 등)는 Phase 6 소관. 현재 surface 글로우는 `get_global_mouse_position()` 기반(mouse).
- **PlacementPreview ③(bridge/builder) 제거**는 Phase 3(cursor-result + preview 리팩터) 소관 — 현재 preview와 glow가 공존(역할 상이: preview=ghost 결과, glow=탭 대상). 충돌 없음.
