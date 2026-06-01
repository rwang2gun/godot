# 지형 타일 규칙

CandyAnts ground terrain의 **painterly cookie 2-tier 시각 시스템** SoT(Source of Truth)다.
지형은 **노출 최상단(전환 띠, surface family) / interior(깊은 내부, solid family)** 두 tier로 구성된다. 다른 stage·theme로 확장할 때
따라야 할 규약을 정의한다. 신규 타일 자산 발주, `StageLayoutBuilder` 수정, 새 stage 레이아웃 작성은 반드시 이 문서를 우선한다.

> **개정 이력 — surface tier 제거 (terrain-tier-restructure Phase 2, 2026-06-01)**
> 이전에는 surface / under-surface / interior **3-tier**였고, 걷는 면 위에 톱다운 쿠키 `surface` 데코 레이어가
> 따로 얹혔다. 그 `surface` tier(타일 타입 + 노출천장 자동 오버레이 + 톱다운 텍스처)를 **제거**하여
> **under-surface가 최상단 룩**이 되도록 단순화했다. 굴착 surface 캡 인프라(직전 skill-tile-surface 트랙)도 함께
> revert됐다. 자세한 결정·범위는 `phases/terrain-tier-restructure/REVISION_2026-06-01-terrain-tier-restructure.md`.
>
> **개정 이력 — 아틀라스 → discrete 48×48 4-variant 타일 (terrain-tier-restructure Phase 3, 2026-06-01)**
> ground 2-tier 텍스처를 (구) `336×48` 가로 아틀라스(`cookie_tile_under_surface` / `cookie_tile_background`)에서
> **48×48 단일 정사각 4-variant 타일**로 교체했다. 노출 최상단 = `cookie_surface_square_01~04`,
> 가려진 본체 + background = `cookie_solid_rotatable_square_01~04` (`assets/sprites/terrain/usable_square/`).
> 렌더는 아틀라스 가로 슬라이스(`region_enabled=true`, cell.x 오프셋)에서 **whole-tile**(`region_enabled=false`,
> `scale=cell_size/tex`, 중앙)로, variant 선택은 `posmod(cell.x, columns)` 선형식에서 **비선형 bit-mixing
> 해시 `_variant_index(cell, n)`**로 바뀌었다(대각/줄 밴딩 방지·결정적). exposure 2-tier 술어(§3)는 불변.
> 구 아틀라스 PNG는 ground에서 미사용이나 `cookie_tile_background`는 `CookiePlatformVisual`이, `cookie_tile_surface`는
> 슬로프가 계속 사용하므로 **삭제하지 않는다**.

## 0. 스코프

**대상**: ground terrain의 노출 최상단 / interior 2-tier 타일링(48×48 discrete 4-variant)과 그 painterly cookie 아트 디렉션 (현재 `cookie_crust` theme 1종).

**대상에 포함** (별도 구조라 별도 섹션):
- **모래 쌓기(Sand-Mound) 동적 스킬 타일** — §11. ground terrain과 구조가 다르다(세로 스택·1칸 폭). Phase 3 이후 ground도 discrete 정사각 whole-tile로 수렴했으나, sand-mound는 **자체 surface/under/background 3-tier를 세로로 유지**한다(ground의 노출 2-tier 자동 추론과 독립 — §9 참조).

**범위 밖** (본 문서가 다루지 않음):
- `slope_left` / `slope_right` 경사 타일 — 별도 시각 규칙. 대각 윗면은 여전히 `cookie_tile_surface.png`를
  사용한다 → **`cookie_tile_surface.png` 파일은 슬로프용으로 보존**(ground 2-tier가 안 써도 삭제 금지).
- `plant` 타일 (Phase 19 Cutter 대상) — 독립 sprite 파이프라인.
- Hazard / Candy / Home 등 entity 시각.
- `cookie_segment`, `thin_floor`, `cookie_bridge_tile`, `thin_bridge` 등 비-`cookie_crust` theme variants — 본 문서의 painterly 디렉션은 따르되, 각자의 시각 규칙은 별도 박제 필요.
- **굴착(digger/basher) 단면의 동적 re-tiering** — 현재 미구현(skill-tile-surface 트랙에서 보류·revert). 향후 트랙 후보.
- **세로 단면(측벽) tier** — 미박제. 굴착으로 드러난 세로 면은 현재 tier 연속성을 강제하지 않는다.

위 항목들의 시각 규약이 박제되어 있지 않다는 사실 자체가 향후 system 작업 후보다 (§9 참조).

## 1. 시각적 목표

기준 이미지: `assets/illustrations/stage_bg_painted.png` (타이틀 화면 바닥).

지형은 다음을 모두 만족해야 한다.

- 회화적이고 부드러운 캔디-쿠키 톤.
- 걷는 면(지형 최상단)은 노출 전환 띠(surface family) — 쿠키 측면 크러스트가 상단 가장자리에 보이고 아래로 초콜릿 내부로 흐른다.
- 깊은 내부는 부드러운 초콜릿 단면, 파스텔 배경과 어울리는 저대비 톤.

실패 신호:

- 분리된 정사각 블록처럼 보임.
- 픽셀아트 벽돌 느낌.
- 딱딱한 검은 초콜릿.
- 절차적 플레이스홀더 같은 인상.

## 2. 시각 모델 — 2-tier + 레벨 데이터 2종

**시각 tier 2개** (셀이 어떻게 그려지는지). 각 tier는 `48×48` 단일 정사각 타일 **4-variant**로, 셀마다 `_variant_index(cell, 4)`(비선형 해시)가 하나를 결정한다.

| Tier | 텍스처 family (4-variant) | 역할 |
| --- | --- | --- |
| 노출 최상단 (surface family) | `usable_square/cookie_surface_square_01~04.png` | **지형 최상단**(공기와 맞닿는 노출 면 = 걷는 면). 쿠키 크러스트 가장자리 룩. |
| interior (solid family) | `usable_square/cookie_solid_rotatable_square_01~04.png` | 깊은 초콜릿 본체. `background` 시각 전용 채움도 이 family를 쓴다. |

> 톱다운 `surface` tier는 (Phase 2에서) 제거됐다 — 별도의 톱다운 쿠키 바닥 텍스처/타일/오버레이가 없다.
> (구) `336×48` 가로 아틀라스(`cookie_tile_under_surface` / `cookie_tile_background`)는 Phase 3에서 ground 미사용으로 대체됐다.

**레벨 데이터에 직접 쓰는 tile type은 2종**:

| `tile_map` 값 | 충돌 | 시각 동작 |
| --- | --- | --- |
| `solid` | 있음 | `_add_solid_visual()`로 그려짐. 베이스 텍스처는 §3 자동 추론으로 surface family(노출) 또는 solid family(interior) 결정. |
| `background` | 없음 | interior 텍스처를 시각 전용으로 채움. 빈 공간이 검게 비치는 걸 막는다. |

**노출 / interior tier는 별도 tile type이 아니다** — `solid` 셀이 위치(노출 여부)에 따라 builder가 자동으로 family를 선택한다.
레벨 작성자는 solid / background 두 가지만 칠한다. (`surface` 타일 타입은 폐기 — 레이아웃에 `"surface"` 값이 있으면 안 된다.)

## 3. Builder 자동 동작

`StageLayoutBuilder`가 다음을 자동 수행한다. 이 추론이 깨지면 §2 모델 전체가 무너지므로 invariant로 취급한다.

**자동 추론 — `_solid_texture_for_cell()` (exposure 술어)**
- `solid` 셀 바로 위 칸이 **레이아웃에 존재하지 않으면**(`not tile_map.has(above_key)` = 진짜 빈 칸/공기) → 노출 최상단 → **surface family** `cookie_surface_square_NN.png`.
- 위 칸이 레이아웃에 **존재하면**(solid / slope_* / plant / background 무엇이든 = 가려진 셀) → **solid family** `cookie_solid_rotatable_square_NN.png` (interior).
- `not tile_map.has(above_key)` 술어는 단일 SoT다 — 좁은 `== TILE_SOLID` 해석 금지(slope/plant/background-above가 잘못 노출 처리되는 것을 방지).

**variant 선택 — `_variant_index(cell, n)` (비선형 해시)**
- family 안에서 4 variant 중 하나를 고르는 함수. `posmod(a*x+b*y, n)` 류 선형식은 대각/줄 밴딩 + 4-bucket 주기성이 눈에 띄므로 **bit-mixing 정수 해시**로 분산한다.
- **결정적**: 같은 cell → 항상 같은 variant (리빌드/리프리뷰 안정). 따라서 회귀 테스트는 이 공식을 **복제하지 않고** family 집합 membership + 결정성 + 넓은 필드 분포(≥2 variant)만 검증한다(§8).

**렌더 — `_apply_square_tile()` (whole-tile)**
- 텍스처를 **통째로** cell_size에 맞춰 균일 scale(`scale = cell_size / tex_size`)하고 중앙 정렬한다. `region_enabled = false` — 가로 슬라이스/오프셋을 쓰지 않으므로 cell_size가 48이 아니어도(32 등) 정사각 그림이 잘리지 않는다 (sand-mound §11.3과 동형).

**(폐기) 노출천장 surface 오버레이** — 이전 모델의 `_add_solid_visual` 2번(노출 천장 → `SurfaceSprite` 오버레이)은 **제거**됐다.
노출 최상단의 룩은 베이스 텍스처(surface family) 자체가 담당한다. **`SurfaceSprite` 노드는 더 이상 생성되지 않는다.**

**충돌/시각 분리 invariant**
- `background`는 절대로 `StaticBody2D`를 만들지 않고 `Terrain` 점유(occupancy)에 등록되지 않는다.
- `solid`(및 slope_*/plant)만 충돌 셀이며 `Terrain._static_occupancy`에 등록된다. ground cookie solid는 `kind="earth"`.

## 4. 타일 규격 (Phase 3 — discrete 4-variant)

**셀 크기**: `48 × 48` 정사각. 모든 tier 텍스처는 이 규격(단일 정사각 1칸)을 따른다. `_apply_square_tile()`이 `scale = cell_size / tex_size`로 처리하므로 cell_size가 48이 아니어도 비례 스케일된다.

**variant 수**: tier당 **4종** (`_01~_04`). 가로 아틀라스가 아니라 **독립된 48×48 PNG 4장**이다.
- 노출 최상단: `usable_square/cookie_surface_square_01~04.png`
- interior + background: `usable_square/cookie_solid_rotatable_square_01~04.png`

**variant 선택**: `_variant_index(cell, 4)` 비선형 해시(§3). cell.x 슬라이스가 아니라 (cell.x, cell.y) 양쪽을 섞으므로 가로·세로·대각 어느 방향으로도 단조 패턴이 생기지 않는다.

**부트스트랩**: 새 PNG 추가/교체 후 `godot --headless --path . --import` 1회 필수 (안 하면 런타임 `load()`가 null). `*.png.import` 사이드카 + `.godot/imported/*.ctex` 캐시는 gitignore 대상이라 머신마다 재생성한다 — 커밋은 PNG만.

> **(폐기) 336×48 가로 아틀라스 파이프라인** — (구) `scripts/tools/process_new_tiles.py`(make_seamless 가로 블렌딩 → `336×48` atlas, `_painted` 백업 동기화)는 ground 2-tier가 더 이상 쓰지 않는다. 슬로프 대각면이 쓰는 `cookie_tile_surface.png`, `CookiePlatformVisual`이 쓰는 `cookie_tile_background.png`는 보존(§9-5, §10). 새 theme를 다시 가로 아틀라스로 갈 일이 있으면 그때 이 도구를 부활시킨다.

## 5. 연속성 규칙

**가로 연속성** (Phase 3 — discrete 타일)
- 한 row를 같은 tier로 가로 반복 시 단조로움이나 끊김 없이 하나의 연속된 면으로 읽혀야 한다.
- 더 이상 가로 seamless 스트립이 아니다 — 각 48×48 타일은 자기완결적이고, 인접 타일과 **가장자리가 호환되도록** 그려져야 한다(좌우 경계에 튀는 디테일 금지). 4 variant + `_variant_index` 비선형 해시가 반복 패턴을 깬다.
- variant 간 자연스러운 변주(미세 균열, 부스러기, 톤 변화)는 허용, 명백한 반복 패턴·정사각 스티커 룩은 금지(§10).

**세로 연속성 — S → I → I 체인** (S=노출 surface family, I=interior solid family)

두 tier를 세로로 쌓았을 때 각 전환이 보이지 않게 이어져야 한다. 다음 두 transition이 모두 매끄러워야 한다:

1. **노출 타일 하단 ↔ interior 상단** — 노출 면의 초콜릿 전환부가 interior 상단으로 끊김 없이 연결된다.
2. **Interior 하단 ↔ Interior 상단** — interior가 자기 자신과 세로로 반복될 때 셀 경계마다 가로 능선이 보이지 않는다.

**현재 system은 가로·세로 연속성을 코드/도구로 enforce하지 않는다.**
- variant 선택(`_variant_index`)은 분포만 분산할 뿐 인접 타일 간 가장자리 정합을 보장하지 않는다.
- 8개 타일은 외부에서 그려진 독립 PNG다 — 가로/세로 정합은 **타일 아트 자체의 가장자리 호환성**에 의존한다.
- 따라서 **새 자산을 발주할 때 §5의 가장자리 호환 + S→I→I 체인을 요구사항으로 명시**해야 한다. import가 통과한다고 시각 정합이 보장되는 게 아니다.

향후 system 개선 후보는 §9 참조.

## 6. 레퍼런스 사용 방침

기준 이미지: `assets/illustrations/stage_bg_painted.png`.

- 톤·팔레트·질감의 기준으로만 사용한다.
- **원근감·배경·소품·보석·덤불 같은 비-타일 요소가 포함된 영역은 절대로 직접 크롭해 타일로 쓰지 않는다.**
- 직접 크롭이 이음새를 망치면, 타이틀 이미지는 팔레트·텍스처 레퍼런스로만 두고 필요한 tier 타일은 회화적 스타일을 유지한 채 새로 painting을 의뢰하거나 절차적으로 합성한다.

## 7. 확장 절차

**새 stage에 같은 시스템 적용**
1. `data/stage_layouts/stageNN_layout.tres`에 지형을 `solid`로 칠한다 (`surface` 타일 타입은 폐기 — 쓰지 않는다).
2. 시각적으로 비어 보이면 안 되는 빈 공간(컬럼 절벽 안쪽 등)은 `background`로 채운다.
3. Home / Candy / Spawner 좌표는 ant 본체 행(걷는 solid의 한 칸 위) 또는 실제 `solid` 충돌 행 컨벤션을 따른다.
   surface 제거는 충돌 행을 바꾸지 않으므로 기존 정렬은 그대로 유효하다.
4. 시각 추론(노출 최상단=surface family, 그 외=interior=solid family)은 builder가 자동 — 추가 작업 없음.

**새 theme 추가**
1. 같은 2-tier 모델(노출 surface / interior)을 유지한 painting을 의뢰한다. §1 painterly 디렉션과 §5 세로 체인 조건을 발주서에 박제한다.
2. 각 tier의 48×48 단일 타일 4-variant를 생성한다 (가로 아틀라스가 아니라 독립 PNG 8장). 새 theme를 굳이 가로 아틀라스로 가야 한다면 (구) `process_new_tiles.py` 파이프라인을 부활시키되, 렌더 경로(`_apply_square_tile` whole-tile)도 함께 분기해야 한다.
3. `StageLayoutBuilder._solid_texture_for_cell()`에 새 theme 분기를 추가한다 — 현재는 `cookie_crust` 텍스처를 직접 `load`한다. theme 다변화 시 이 점이 §9 system 후보의 동기.
4. `layout.theme` 필드를 새 theme 이름으로 설정한 stage layout으로 검증한다.

**새 자산 발주 체크리스트**
- §1 painterly 톤·실패 신호 명시.
- §4 `48 × 48` 단일 정사각, tier당 4-variant 규격 명시.
- §5 가로 가장자리 호환 + 세로 S→I→I 체인 정합 요구.
- 가능하면 노출(surface) / interior 원본을 **단일 painting에서 잘라낸 정합 세트**로 통합 요청 — 세로·가장자리 정합이 원본 시점에서 보장된다.

## 8. 회귀 테스트

`tests/test_StageLayoutBuilder.gd`가 본 문서 §2~§3의 invariant를 검증한다.

| 테스트 | 검증 항목 |
| --- | --- |
| `_test_texture_tiers_and_visual_only()` | `solid`만 충돌 등록 / `background`는 visual-only(solid family) / **노출 최상단 solid = surface family** / **가려진 solid = solid family** / whole-tile(`region_enabled==false`) / **`SurfaceSprite` 오버레이 부재** / exposure edge case(stacked / under-slope / under-background / isolated-exposed) |
| `_test_variant_distribution_and_determinism()` | 같은 layout 두 번 build → 같은 cell 같은 텍스처(**결정성**) / 넓은 노출·interior 필드에 각각 **≥2 variant 등장**(밴딩 회귀). variant index 공식은 복제하지 않는다. |
| `_test_non_48_cell_size()` | cell_size=32 합성 layout → `region_enabled==false` / 중앙 정렬(`position==0`, `centered`) / `scale == Vector2(32/tex_w, 32/tex_h)` (비-48 회귀 가드). |
| `_check_stage()` × stage01/02/03 | 실제 레이아웃 마이그레이션 불변 — **`surface` 타일 타입 부재** / 점유 셀 == collision tile 셀 / surface·solid family tier 정합 / `SurfaceSprite` 부재 |

세로 연속성(§5)은 현재 자동 테스트 대상이 아니다 — 시각 검사로만 검증된다.

> 참고: `tests/Stage02HeadlessTest.tscn`은 본 트랙과 무관한 pre-existing 실패(`reason=time_out`, `96a5c2a` 3-tier
> 확장 시 테스트 하드코딩 좌표 어긋남 추정)가 있어 별도 후속 이슈로 분리됐다. Stage 2 레이아웃 마이그레이션 자체는
> 위 `_check_stage("…stage02…")` 점유 불변이 커버한다.

## 9. 현재 system 한계 + 개선 후보

본 문서가 enforce하려는 규칙 중 system이 받쳐주지 못하는 영역:

1. **가로·세로 연속성 (§5)** — discrete 4-variant 타일은 인접 가장자리 정합을 코드가 검사하지 않는다(variant 분포만 분산). 개선안: 단일 source painting에서 정합 세트로 잘라 발주하거나, 향후 edge-aware variant 선택(wang tile류) 도입.
2. **Theme 확장이 builder 코드 수정을 요구** — 현재 `_solid_texture_for_cell()`이 `cookie_crust` 텍스처를 직접 `load`. 개선안: `TerrainTheme.tres` 리소스화 — 각 theme가 under/interior 텍스처 2장 + tone 메타데이터를 declared field로 보유.
3. **굴착 단면 동적 re-tiering / 세로 단면 tier 미구현** — 굴착으로 드러난 면(특히 세로 단면)이 주변 지형과 tier 연속되지 않는다(skill-tile-surface 트랙에서 비효율로 판단·보류). 개선안: `background` 채움을 solid 깊이로 전환 + 노출 셀 tier 런타임 재계산.
4. **sand-mound(§11)는 여전히 3-tier(surface 포함)** — ground terrain은 surface를 버렸지만 sand-mound는 자체 surface tier를 유지한다. 두 시스템의 tier 모델이 분기한 상태. 개선안: 일관화 필요 시 sand-mound도 2-tier로 전환 검토.
5. **slope / plant / hazard 시각 규약 미박제** — 각자 별도 경로로 그려지며 본 문서의 디렉션을 따른다는 보장이 없다. 슬로프 대각면은 `cookie_tile_surface.png`(폐기된 ground surface 텍스처)를 계속 쓴다.

위가 해소되기 전까지 본 문서는 "ground terrain 2-tier 시스템에 한해서만" 가드레일로 작동한다.

## 10. 안티 규칙

다음 중 어느 하나라도 발견되면 즉시 수정한다.

- 지형이 분리된 정사각 스티커처럼 보임.
- 깊은 interior 타일에 쿠키 상단 단턱이 들어감.
- Interior를 세로 반복했을 때 셀 경계마다 가로 능선이 보임.
- 노출 최상단(surface family) → Interior 전환에 띠 단절이 보임.
- 파스텔 배경과 충돌하는 고대비 검정 또는 네온 톤이 사용됨.
- **레이아웃 `.tres`에 `"surface"` 타일 값이 존재함** (폐기된 타입 — solid/background만 허용).
- **`solid` 셀 위에 `SurfaceSprite` 오버레이가 생성됨** (제거된 레거시 — 노출 최상단은 surface family 베이스 텍스처로 표현).
- **노출 최상단 solid가 solid family로 그려짐**(또는 가려진 solid가 surface family로 그려짐) — exposure 술어(`not map.has(above_key)`) 위반.
- 새 theme / 새 stage 자산을 §1·§5 명시 없이 발주함.
- `cookie_tile_*.png` live 파일만 수정하고 `_painted` 백업을 동기화하지 않음 (또는 그 반대).
- **`cookie_tile_surface.png`를 삭제함** — ground 2-tier가 안 써도 슬로프가 사용하므로 보존해야 한다.
- 본 문서의 가드레일을 코드/도구가 enforce한다고 단정함 — 실제 enforce 범위는 §3 exposure 술어 + variant 결정성/분포(§8)에 한정된다. 가로·세로 가장자리 정합은 타일 아트가 책임진다.
- **모래 쌓기 타일을 가로 아틀라스(N-variant)나 seamless 스트립으로 발주함** — 세로 1칸 스택이라 가로 연결이 무의미하고, cell.x variant는 "쌓을 때마다 다르게" 보이는 부작용만 남긴다 (§11).

## 11. 동적 스킬 타일 — 모래 쌓기 (Sand-Mound)

§1~§10은 **가로로 넓게 깔리는 정적 ground terrain**(Phase 3 이후 48×48 discrete 4-variant whole-tile + 노출 2-tier 자동 추론)을 전제한다.
**모래 쌓기 스킬 타일은 세로 1칸 스택 구조**다 — ground의 노출 2-tier 자동 추론을 적용하지 않는다.
또한 모래 쌓기는 **자체 surface/under/background 3-tier를 유지**한다 (ground terrain의 surface 제거와 독립 — §9-4).

### 11.1 구조 — 세로로 쌓는 1칸 폭 동적 타일

- 개미가 `SandMoundSkill`로 자기 발밑에 타일을 한 칸씩 **위로** 쌓아 만드는 1칸 폭 수직 더미 (최대 `SAND_MOUND_MAX_HEIGHT`=5칸).
- 가로 인접/연결이 없다 → **가로 variant·아틀라스가 불필요**. Phase 3 이후 ground도 whole-tile(`_apply_square_tile`)로 수렴해 렌더 방식은 같지만, sand-mound는 tier당 **1장**(가로 variant 0)이고 ground는 tier당 **4-variant**(`_variant_index`)라는 점이 다르다. (구) cookie 가로 아틀라스 파이프라인(`process_new_tiles.py` / `make_seamless`)은 양쪽 다 쓰지 않는다.
- 정적 ground terrain과 달리 `Terrain.add_tile()`로 런타임 생성되는 동적 `StaticBody2D`다.

### 11.2 자산 — 독립된 정사각형 타일 3장

| Tier | 파일 | 더미 내 위치 |
| --- | --- | --- |
| surface | `sand_tile_surface.png` | 맨 위 칸 |
| under-surface | `sand_tile_under_surface.png` | 위에서 2번째 칸 |
| background | `sand_tile_background.png` | 3번째 이하 (세로 반복) |

- 각 파일은 **단일 정사각형 1칸**(아틀라스 아님). 권장 규격 **48 × 48** (= cell_size).
- **가로 variant 금지** (cookie ground의 tier당 4-variant와 다름). 한 tier당 그림 1장 → 모든 더미가 **어디에 쌓아도 동일하게** 보인다.
- 위치: `assets/sprites/terrain/`. 파일명은 위 표 그대로 (코드가 이 경로를 `load`).

### 11.3 렌더 동작 (코드 자동)

- **그리기**: `Terrain._apply_sand_tier()`가 텍스처 **전체**를 cell_size에 맞춰 균일 scale한다 (`region_enabled = false`). 가로 슬라이스/오프셋을 쓰지 않으므로 cell_size가 달라도(32/48) 정사각형 그림이 잘리지 않고 통째로 보존된다.
- **tier 배정**: 더미가 위로 자라 맨 위 칸이 계속 바뀌므로, 타일을 쌓을 때마다 `Terrain._reskin_sand_column()`이 column을 위→아래 surface → under_surface → background로 재배정한다 (3번째 이하는 한 번 background가 되면 불변 → 상위 3칸만 갱신해도 invariant 유지).
- 아트 담당은 **그림 3장만** 만들면 된다. tier 배정·재스킨은 코드가 한다.

### 11.4 연속성 — 세로만 중요

- 가로 연속성은 무의미하다 (1칸 폭).
- 대신 **세로로 쌓았을 때** surface 하단 → under_surface → background → background가 매끄럽게 이어져야 한다 (S→U→I→I 체인을 **세로로만** 적용).
- background는 세로 self-repeat 시 셀 경계에 가로 능선이 보이지 않아야 한다.

### 11.5 부트스트랩 + 회귀 테스트

- 새 PNG 교체 후 `godot --headless --path . --import` 1회 필수 (안 하면 런타임 `load()`가 null → 타일 안 보임).
- `tests/SandMoundMaxHeightTest.gd`가 검증: (1) tier 순서 surface→under→background (2) `region_enabled = false` (3) cell_size에 맞춘 whole-texture scale (4) 중앙 정렬.
- `tests/SandMoundClimbOverLedgeTest.gd`는 더미가 기존 솔리드 레지를 타고 넘는 게임플레이를 검증 (시각과 별개).
