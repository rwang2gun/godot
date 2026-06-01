---
name: square-tile-art-swap
duration_estimate: 5400
verify: python scripts/run_test.py --import && python scripts/run_test.py tests/test_StageLayoutBuilder.tscn && python scripts/run_test.py tests/StageLayoutBuilderEarthBackwardCompatTest.tscn && python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/StageLayoutBuilder.gd, tests/test_StageLayoutBuilder.gd, phases/terrain-tier-restructure/REVISION_2026-06-01-terrain-tier-restructure.md]
---

# Phase 3: square-tile-art-swap

## 목표
ground terrain 타일 텍스처를, 사용자가 추가한 새 **48×48 단일 정사각 4-variant 타일**로 교체한다.
- **최상단(노출) tier** ← `cookie_surface_square_01~04.png` (윗 쿠키 크러스트 가장자리 = 걷는 면)
- **본체(interior) tier + `background` 시각 채움** ← `cookie_solid_rotatable_square_01~04.png` (초콜릿 칩 본체)
기존 `cookie_tile_under_surface.png` / `cookie_tile_background.png` (336×48 가로 아틀라스)는 ground에서 미사용.

## 배경
- Phase 2에서 2-tier(under-surface top / interior)로 정착. 텍스처 선택은 `_solid_texture_for_cell`(exposure 술어
  `not map.has(above_key)`)이 담당하고, 렌더는 `_configure_repeating_region`(336×48 아틀라스를 cell.x로 슬라이스).
- 새 에셋은 **48×48 단일 타일 4장씩**(가로 아틀라스 아님). 세 stage 모두 cell_size=48 → 스케일 1:1.
- 따라서 렌더를 **아틀라스 슬라이스 → whole-tile + position 기반 variant 순환**으로 바꾼다 (sand-mound §11.3 whole-tile
  스케일과 동형). cookie/sand가 모두 discrete 정사각 타일로 수렴.

## 변경 대상
- `scripts/world/StageLayoutBuilder.gd`
  - variant 경로 상수 추가: `SURFACE_TILES`(cookie_surface_square_01~04), `SOLID_TILES`(cookie_solid_rotatable_square_01~04).
  - **variant 선택 = 비선형 정수 해시** `_variant_index(cell, n)` (codex plan R1-M1 반영). `posmod(a*x+b*y, 4)` 류
    선형식은 대각/줄 밴딩을 만들고 4-bucket이라 주기성이 눈에 띈다 → bit-mixing 해시로 분산:
    `var h := cell.x * 374761393 + cell.y * 668265263; h = (h ^ (h >> 13)) * 1274126177; h = h ^ (h >> 16); return posmod(h, n)`.
    (결정적이라 같은 cell은 항상 같은 variant — 리빌드 안정.)
  - `_solid_texture_for_cell(cell)`: 노출 최상단(`not map.has(above)`) → `SURFACE_TILES[_variant_index(cell,4)]`,
    그 외 → `SOLID_TILES[_variant_index(cell,4)]`.
  - `_add_solid_visual`: `_configure_repeating_region` 대신 신규 `_apply_square_tile(sprite, tex, cell_size)`
    (region_enabled=false, whole-tile, scale=`cell_size/tex_size`, 중앙) 사용. **cell_size 비-48에서도 scale로 처리**(크롭 없음).
  - `_add_visual_only_cell`(background): 텍스처를 `SOLID_TILES[_variant_index(cell,4)]`로, 동일 whole-tile 렌더.
  - `_configure_repeating_region`가 ground에서 미사용이 되면 정리(슬로프는 자체 경로라 무관). 슬로프 `_add_slope_visual`은
    `cookie_tile_surface.png`를 계속 사용 → **무변경**.
- 에셋(커밋 대상): **정확히 8개 PNG만** — `usable_square/cookie_surface_square_01~04.png` +
  `usable_square/cookie_solid_rotatable_square_01~04.png`. `python scripts/run_test.py --import`(verify에 포함)로 부트스트랩.
  - **`.import` 사이드카는 커밋하지 않는다** (codex impl R1 정정): `*.import`는 repo 전역 `.gitignore:10` 대상이라
    git이 무시하며, 기존 terrain PNG도 `.import` 없이 트래킹된다. 머신마다 `--import`로 재생성. plan R1-L1의
    "미사용 PNG의 `.import` 혼입" 리스크는 gitignore가 원천 차단 → 자동 해소.
  - **완료(complete) 커밋 정확화 — `execute.py complete`의 auto-stage는 whitelisted untracked `assets/**`(+ `phases/{task}/`
    의 `phase*.md`/`reviews/*.md`/`status.json`)를 전부 staging**한다(M1). 무관 art가 Phase 3 커밋에 섞이지 않게 **반드시 un-bundle**한다.
    `*.import`는 gitignore라 git이 untracked로 보고하지 않으므로 staging 후보에 없다(혼입 불가).
    0. **전제**: whitelist 밖 untracked phase 문서가 있으면 complete가 step 10에서 abort한다. 본 세션의 핸드오프 문서
       `RESUME-phase3-2026-06-01.md`는 목적 달성(Phase 3 재개) 후 obsolete → **complete 전 삭제 완료**. 직전 `git status
       --short --untracked-files=all`로 잔여 whitelist-밖 파일이 없음을 확인한다.
    1. `python scripts/execute.py terrain-tier-restructure complete 3` (verify+리뷰게이트 통과 후 커밋 생성).
    2. `git reset --soft HEAD~1` (커밋 해제, staged 유지).
    3. 무관 art unstage: `git reset HEAD -- assets/sprites/terrain/concepts assets/sprites/terrain/cookie_stair_tile_flip.png assets/sprites/terrain/usable_square/_preview_square_tiles.png assets/sprites/terrain/usable_square/biscuit_ladder_root_square.png assets/sprites/terrain/usable_square/biscuit_ladder_middle_square.png assets/sprites/terrain/usable_square/biscuit_ladder_top_square.png`
    4. `git diff --cached --name-only`로 **정확히 다음 16개만** 남았는지 확인:
       8 PNG(`usable_square/cookie_surface_square_01~04.png` + `cookie_solid_rotatable_square_01~04.png`) +
       `scripts/world/StageLayoutBuilder.gd` + `tests/test_StageLayoutBuilder.gd` + `scripts/run_test.py` +
       `docs/TERRAIN_TILE_RULES.md` + `phases/terrain-tier-restructure/`의 `phase03-square-tile-art-swap.md` ·
       `status.json` · `reviews/phase03-impl-review.md` · `reviews/phase03-plan-review.md`.
    5. `git commit -m "phase 3: square-tile-art-swap"`. 무관 art는 untracked로 복귀(사용자 정책 = art untracked 유지).
  - **(완료) 병렬 stair/entity 작업**(stair 기능 `Terrain.gd`/`WorkerState.gd`/`cookie_stair_tile.png`,
    엔티티 씬 `Candy.tscn`/`Home.tscn`)은 본 phase 재개 전 별도 커밋됨(`d71e2d2` feat(builder), `6331c63` fix(entities)) →
    더 이상 tree에 없음. 사용자 결정(2026-06-01) 이행 완료.
- `docs/TERRAIN_TILE_RULES.md`: §2 텍스처 family/§3 builder 동작(`_variant_index`·`_apply_square_tile`)/§4 규격/§5 연속성을
  **discrete 48×48 4-variant** 모델로 갱신(336×48 아틀라스 → 단일 정사각 + 비선형 해시 variant). 교차참조 정합을 위해
  §0 스코프·§7 발주 체크리스트·§8 회귀 테스트 표·§9 한계·§10 안티규칙·§11 sand-mound 대비 문구도 동반 갱신(ground 맥락
  "under-surface" 용어 → "노출/surface family" 통일, sand-mound 자체 under-surface tier는 유지). 슬로프 surface PNG 보존 문구 유지.
- `tests/test_StageLayoutBuilder.gd`: tier 텍스처 assert를 새 family로 갱신 (codex plan R1-M1·M2 반영):
  - 노출 solid = `cookie_surface_square` family **중 하나**(4개 중 valid), 가려진 solid + background =
    `cookie_solid_rotatable_square` family 중 하나, `region_enabled == false`.
  - **공식 복제 금지** — variant index를 테스트가 다시 계산해 assert하지 않는다. 대신 (i) 텍스처가 해당 tier의
    4 variant 집합에 속함, (ii) **결정성**(같은 layout 두 번 build → 같은 cell 같은 텍스처), (iii) 넓은 solid 필드에서
    **2개 이상 variant 등장**(분포 sanity, 밴딩 회귀 감지) 정도만 검증.
  - **32px 케이스 추가**: cell_size=32 합성 layout으로 solid + background cell build → `region_enabled == false`,
    중앙 정렬, `scale == Vector2(32.0/tex_w, 32.0/tex_h)` assert (shared builder의 비-48 cell_size 회귀 가드).

## 비목표
- 슬로프/plant/hazard/CookiePlatformVisual 시각. sand-mound. 맵 에디터(별도 트랙, Phase 2 D-1).
- 새 stage 추가나 레이아웃 geometry 변경.
- biscuit_ladder_* 타일 사용(이번 요청 범위 밖).

## 검증 방법
- `godot --headless --import` 후 `verify`(test_StageLayoutBuilder + EarthBackwardCompat + Stage03 headless) 전부 PASS.
- **cell_size=32 회귀**는 `test_StageLayoutBuilder`의 합성 32px 케이스(위 test 항목 (iii)+32px)가 커버 — 별도 32px
  헤드리스 씬 불요(dev_*_layout는 본 phase verify 범위 밖, 시각 회귀는 합성 케이스로 충분).
- 충돌/점유/스코어 불변(텍스처 교체만 — geometry·collision 무변경). Stage03 풀 게임플레이 clear 유지.
- 시각 실측(스크린샷): 걷는 면이 cookie_surface 4-variant, 본체가 cookie_solid 4-variant로 보이고 줄무늬 없는지.
- grep: ground 경로가 새 타일 참조, 미사용 `_configure_repeating_region` 잔존 점검.
