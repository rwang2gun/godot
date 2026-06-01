# Phase 2 Impl Review — remove-surface-tier

## Verify (Claude, 2026-06-01)
수정 verify 체인 전부 PASS (CHAIN_EXIT=0):
- `test_StageLayoutBuilder` PASS — 2-tier 모델 + exposure edge case(stacked / under-slope / under-background /
  isolated-exposed) + stage01/02/03 점유 불변(surface 부재, 점유==collision tile)
- `StageLayoutBuilderEarthBackwardCompatTest` PASS — 23 layouts all-earth
- `Stage03HeadlessTest` PASS (clear score=1.0) — surface 제거 후에도 Stage 3 풀 게임플레이 정상

레이아웃 마이그레이션: surface 32/40/27 → 0 (solid/background 불변). grep: `TILE_SURFACE` / `_surface_texture` /
`_get_tile_texture_for_cell` 코드 잔존 0건, 레이아웃 `"surface"` 0건. `cookie_tile_surface.png`는 슬로프/
CookiePlatformVisual/생성도구가 계속 사용(파일 보존).

`Stage02HeadlessTest`는 verify에서 제외 — pre-existing 실패(stash 비교로 surface 제거 전 baseline에도 동일
FAIL 확인 → 본 변경과 무관). 상세 `phase02-deferred.md` 참조.

## Round 1 (codex adversarial-review, 2026-06-01)
Target: working tree diff · Verdict: **needs-attention** (CRITICAL/HIGH 0 · MEDIUM 1)
- **[medium]** `status.json` phase-2 verify가 제외된 Stage02HeadlessTest를 여전히 포함 (`status.json:22`).
  markdown(phase02)과 불일치 — status.json을 읽는 도구/리뷰어가 known-failing 테스트를 실행하게 됨.

### Fix (Round 1 MEDIUM)
`python scripts/execute.py terrain-tier-restructure sync-status` 실행 → status.json phase-2 verify가
frontmatter(Stage02 제외)와 일치하도록 동기화. (.bak 미생성, phase1=completed/phase2=in_progress 상태 보존.)

## Self-Review Round 1 (Claude, 2026-06-01)
자체 적대적 스캔 결과 **clean** (CRITICAL/HIGH 0):
- status.json ↔ markdown verify 일치 확인. phase1 state=completed 보존.
- exposure 술어 `not map.has(above_key)`: solid-under-background/slope/plant=interior, isolated-exposed/stacked-top=
  under-surface, stacked-lower=interior — 전부 테스트로 검증.
- 레이아웃 surface 0건, dead code(TILE_SURFACE/_surface_texture/_get_tile_texture_for_cell) 잔존 0건.
- 문서 "surface/3-tier" 잔존 참조는 전부 의도된 개정이력/deferred 설명(모순 없음).
- `_solid_texture_for_cell`는 항상 load() 반환(null 위험 없음), `_add_solid_visual`/test가 null-safe.

## Round 2 (codex adversarial-review, 2026-06-01)
Target: working tree diff · Verdict: **needs-attention** (CRITICAL/HIGH 0 · MEDIUM 1, status.json 해소 확인)
- **[medium]** 웹 맵 에디터가 옛 surface-tier 모델 사용 (`tools/map_editor/public/editor.js:180-200`).
  런타임은 `not map.has(above)`로 under-surface/interior를 고르는데, 에디터는 `tileMap[aboveKey] !== 'solid'` +
  폐기된 `IMAGES.tileSurface`를 그림 → 에디터 프리뷰 ↔ 런타임 렌더 발산.

### 처리 (Round 2 MEDIUM)
**Defer** (정책: impl-stage clean-loop은 CRITICAL/HIGH 한정, MEDIUM은 `phaseNN-deferred.md` 허용).
사유: (1) 본 task 스코프 밖(맵 에디터 = 별도 codex map-editor 트랙), (2) `tools/**`는 harness staging whitelist
밖이라 Phase 2 커밋에 포함 불가(complete 거부), (3) MEDIUM·셰이딩된 stage엔 무영향. `phase02-deferred.md` D-1에
박제 + 사용자에게 spawn-task로 map-editor 트랙 후속 플래그.

## Verdict
CRITICAL/HIGH 0건. status.json MEDIUM 수정 완료. 남은 MEDIUM 1건(맵 에디터)은 스코프·whitelist 밖이라 정식
defer. impl-stage 정책 충족 → Phase 2 complete 진행.
