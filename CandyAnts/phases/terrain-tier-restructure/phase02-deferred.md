# Phase 2 Deferred (MEDIUM/LOW)

## D-1 [MEDIUM] 웹 맵 에디터가 옛 surface-tier 모델 사용 — 런타임과 프리뷰 발산
- 출처: codex impl-review Round 2 (2026-06-01).
- 위치: `tools/map_editor/public/editor.js:180-200`.
- 내용: Phase 2에서 런타임 exposure 술어를 `not map.has(above_key)`(위 빈 칸 → under-surface)로 바꿨으나,
  맵 에디터는 여전히 `tileMap[aboveKey] !== 'solid'`로 노출을 판정하고(`editor.js:185/189/193`) 노출 solid에
  **폐기된 `IMAGES.tileSurface`(cookie_tile_surface) 텍스처**를 그린다. 결과: `background`/slope 위의 solid나
  비-cookie theme에서 에디터 프리뷰가 Godot 런타임과 다르게 보일 수 있다(신규/편집 레이아웃의 version skew).
- **defer 사유**:
  1. **스코프 밖** — 본 task(terrain-tier-restructure)의 확정 스코프는 builder/레이아웃/문서/테스트. 맵 에디터는
     별도 **codex map-editor 트랙**(CLAUDE.md, `codex-worklog/map-editor/STATUS.md`) 소관.
  2. **harness whitelist 밖** — `tools/**`는 `scripts/execute.py`의 staging whitelist에 없어 Phase 2 커밋에
     포함될 수 없다(complete가 "outside whitelist"로 거부). 맵 에디터 변경은 해당 트랙에서 별도 커밋해야 한다.
  3. **MEDIUM** — CRITICAL/HIGH 아님. 셰이딩된 stage 레이아웃(이미 마이그레이션·검증)에는 영향 없고,
     에디터로 신규 작성하는 경우의 프리뷰 정합 문제.
- **후속 액션(map-editor 트랙)**: `editor.js`의 cookie_crust/cookie_segment/thin_floor 분기에서
  exposure를 `!(aboveKey in tileMap)` 류로 바꾸고, 노출 solid는 under-surface 텍스처, 가려진 solid는 background를
  그리도록 수정. 폐기된 surface 프리뷰 제거. (사용자에게 spawn-task로 플래그함.)

## (참고) Stage02HeadlessTest pre-existing 실패 — defer 아님, 별도 이슈
- 본 트랙과 무관(stash 비교로 surface 제거 전·후 동일 FAIL). `96a5c2a`(Stage 2/3 3-tier 확장) 이후 테스트
  하드코딩 좌표(`TRIGGER_X=870`) 어긋남으로 추정. Phase 2 verify에서 제외(이유는 `phase02-remove-surface-tier.md`
  검증 방법 + `docs/TERRAIN_TILE_RULES.md §8` 참조). 별도 후속 이슈로 사용자에게 플래그함.
