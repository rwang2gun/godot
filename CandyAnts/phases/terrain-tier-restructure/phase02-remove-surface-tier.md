---
name: remove-surface-tier
duration_estimate: 7200
verify: python scripts/run_test.py tests/test_StageLayoutBuilder.tscn && python scripts/run_test.py tests/StageLayoutBuilderEarthBackwardCompatTest.tscn && python scripts/run_test.py tests/Stage02HeadlessTest.tscn && python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/StageLayoutBuilder.gd, data/stage_layouts/stage01_layout.tres, data/stage_layouts/stage02_layout.tres, data/stage_layouts/stage03_layout.tres, tests/test_StageLayoutBuilder.gd, phases/terrain-tier-restructure/REVISION_2026-06-01-terrain-tier-restructure.md]
---

# Phase 2: remove-surface-tier

## 목표
ground terrain에서 **surface tier를 제거**해 **under-surface가 최상단 룩**이 되게 한다.
builder 렌더링 + 3개 레이아웃 + SoT 문서 + builder 테스트를 한 phase에서 일관되게 전환한다
(문서-코드 drift 방지).

## 배경 (REVISION §2~§3)
- 현재 레벨 데이터 tile type 3종(`surface` / `solid` / `background`). under-surface는 별도 타입이 아니라
  `solid` 위가 `surface`일 때 자동 선택되는 텍스처(`_solid_texture_for_cell`).
- surface 셀은 충돌 없는 시각 전용 → 제거해도 좌표/충돌/Home/Candy/Spawner 정렬 불변.
- 노출천장 자동 오버레이(`_add_solid_visual` 2번)도 surface 시각이므로 제거.

## 변경 대상
- `scripts/world/StageLayoutBuilder.gd`
  - `_add_cell` / `_add_visual_only_cell`: `TILE_SURFACE` 분기 제거(`background`만 visual-only로 남김).
    (`TILE_SURFACE` 상수는 잔존 참조가 없어지면 함께 정리.)
  - `_add_solid_visual`: 노출천장 surface 오버레이(약 line 163~178, `SurfaceSprite`) **블록 제거**.
  - `_solid_texture_for_cell` **규칙 반전**: **exposure 술어를 `not map.has(above_key)`로 못박는다**
    (= `_add_solid_visual`이 이미 쓰는 `is_surface` 정의와 동일 SoT). 위 칸이 **레이아웃에 존재하지 않을 때만**
    (= 진짜 빈 칸/공기) 노출 최상단 → `cookie_tile_under_surface.png`; 위 칸이 레이아웃에 존재하면
    (tile type 불문 — `solid`/`slope_*`/`plant`/`background` 무엇이든) → `cookie_tile_background.png`(interior).
    - **codex plan R1-M1 반영**: 좁은 `== TILE_SOLID` 해석 금지. `map.has` 기반이라 `solid`-under-`slope`/
      `plant`/`background` 케이스가 자동으로 interior(=가려진 셀)로 처리되어 오탐 방지. `background`가 위에 있으면
      그 solid는 시각적으로 묻힌 것이므로 interior가 맞다(빈 칸일 때만 노출 top).
    - 현재 `_solid_texture_for_cell`(line 289~295)의 `str(map.get(above_key,"")) == TILE_SURFACE` 분기를
      `not map.has(above_key)`로 교체. (현재 model "위가 surface면 under" → 새 model "위가 비면 under".)
  - `_get_tile_texture_for_cell`(현재 호출처 없음) 정리/제거 여부 확인.
  - `_surface_texture()`: 슬로프(`_add_slope_visual`)가 `cookie_tile_surface.png`를 직접 `load`하므로
    슬로프 경로는 유지. `_surface_texture()`가 surface 제거 후 미사용이면 제거(슬로프는 자체 `load` 유지).
    **`cookie_tile_surface.png` 파일은 삭제 금지**(슬로프용 보존).
- `data/stage_layouts/stage01_layout.tres` (surface 32) / `stage02_layout.tres` (40) / `stage03_layout.tres` (27)
  - `tile_map`에서 모든 `"surface"` 셀 엔트리 제거. solid/background 행 불변.
  - 마이그레이션 후 각 surface 셀이 있던 자리 바로 아래 solid가 "노출 최상단"이 되어 under-surface 텍스처를
    받는지(걷는 면 룩 유지) 확인.
- `docs/TERRAIN_TILE_RULES.md`
  - 3-tier → **2-tier(under-surface top / interior)**로 재작성. surface tier/타일 타입/오버레이 서술 제거,
    `_solid_texture_for_cell` 반전 규칙 박제, §7 확장 절차/§8 회귀 테스트/§10 안티 규칙 갱신.
  - §11 sand-mound는 별도 동적 시스템이라 **유지**(본문 범위 밖임을 §0에 명시). 슬로프 surface PNG 보존 명시.
- `tests/test_StageLayoutBuilder.gd`
  - invariant 갱신: `surface` tile type 부재 / 노출 최상단 solid가 under-surface 텍스처 / surface 오버레이
    부재 / solid만 충돌·점유. 기존 `_test_stage01_*`가 surface 가정에 의존하면 새 모델로 수정.
  - **codex plan R1-M1 반영 — 합성 레이아웃 edge case 4종 추가**: (a) `solid` 아래 또 `solid`(stacked) →
    아래 solid는 interior, (b) `solid` 위가 `slope_left`/`slope_right` → 그 solid는 interior(노출 아님),
    (c) `solid` 위가 `background` → interior(가려짐), (d) 위가 빈 칸인 isolated/노출 `solid` → under-surface.
    각 케이스의 BaseSprite 텍스처(`cookie_tile_under_surface.png` vs `cookie_tile_background.png`) assert.
  - **codex plan R1-M2 반영 — 3-stage 마이그레이션 불변 테스트**: stage01/02/03 실제 `.tres`를 빌드한 뒤
    각 stage에서 `_static_occupancy` 점유 셀 집합 == collision tile(`solid`/`slope_*`/`plant`) 셀 집합과 정확히 일치
    (surface/background 시각 전용은 점유 0). surface 제거가 충돌/점유를 바꾸지 않음을 stage01 포함 전 stage에서 박제.

## 비목표 (이 phase에서 하지 않음)
- `background` 채움 폐기 / solid 깊이 전환 / 굴착 동적 re-tiering / 세로 단면 tier (다음 트랙).
- sand-mound surface tier 변경. 슬로프 시각 규칙 변경.

## 검증 방법
- `verify`(test_StageLayoutBuilder + EarthBackwardCompat + Stage02/03 headless) 전부 PASS.
- **Stage01 런타임 헤드리스 씬은 없다**(Stage02/03만 존재). M2 대응으로 stage01 마이그레이션 커버리지는
  위 `test_StageLayoutBuilder`의 **3-stage 점유 불변 테스트**가 담당한다(stage01 실제 `.tres` 빌드 후
  `_static_occupancy`==collision-tile 집합 일치). surface 셀이 시각 전용이라 충돌/점유/스코어가 구조적으로
  불변임을 stage01 포함 전 stage에서 박제.
- 시각 실측(스크린샷): Stage 1/3에서 걷는 면이 under-surface로 보이고, 위 surface 데코 밴드가 사라졌는지.
- grep으로 `"surface"`(레이아웃) / `TILE_SURFACE` / `SurfaceSprite` 잔존 0건(슬로프 `cookie_tile_surface` load는 예외).
