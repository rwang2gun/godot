# 지형 타일 규칙

CandyAnts ground terrain의 **painterly cookie 3-tier 시각 시스템** SoT(Source of Truth)다.
Stage 1에서 도입된 surface / under-surface / interior 시스템을 박제하고, 다른 stage·theme로 확장할 때 따라야 할 규약을 정의한다.
신규 타일 자산 발주, `StageLayoutBuilder` 수정, 새 stage 레이아웃 작성은 반드시 이 문서를 우선한다.

## 0. 스코프

**대상**: ground terrain의 surface / under-surface / interior 3-tier 타일링과 그 painterly cookie 아트 디렉션 (현재 `cookie_crust` theme 1종).

**대상에 포함** (별도 구조라 별도 섹션):
- **모래 쌓기(Sand-Mound) 동적 스킬 타일** — §11. ground terrain과 정반대(세로 스택·1칸 폭·정사각형 3장)라 본문 §1~§10의 가로 아틀라스 규약을 적용하지 않는다.

**범위 밖** (본 문서가 다루지 않음):
- `slope_left` / `slope_right` 경사 타일 — 별도 시각 규칙.
- `plant` 타일 (Phase 19 Cutter 대상) — 독립 sprite 파이프라인.
- Hazard / Candy / Home 등 entity 시각.
- `cookie_segment`, `thin_floor`, `cookie_bridge_tile`, `thin_bridge` 등 비-`cookie_crust` theme variants — 본 문서의 painterly 디렉션은 따르되, 각자의 시각 규칙은 별도 박제 필요.

위 항목들의 시각 규약이 박제되어 있지 않다는 사실 자체가 향후 system 작업 후보다 (§9 참조).

## 1. 시각적 목표

기준 이미지: `assets/illustrations/stage_bg_painted.png` (타이틀 화면 바닥).

지형은 다음을 모두 만족해야 한다.

- 회화적이고 부드러운 캔디-쿠키 톤.
- 걷는 면은 따뜻한 톱다운 쿠키 바닥으로 읽힌다.
- 표면이 본체와 만나는 경계에만 쿠키 측면 크러스트가 보인다.
- 깊은 내부는 부드러운 초콜릿 단면, 파스텔 배경과 어울리는 저대비 톤.

실패 신호:

- 분리된 정사각 블록처럼 보임.
- 픽셀아트 벽돌 느낌.
- 딱딱한 검은 초콜릿.
- 절차적 플레이스홀더 같은 인상.

## 2. 시각 모델 — 3-tier + 레벨 데이터 3종

**시각 tier 3개** (셀이 어떻게 그려지는지)

| Tier | 텍스처 | 역할 |
| --- | --- | --- |
| surface | `cookie_tile_surface.png` | 톱다운 쿠키 바닥. 측면 벽 디테일을 포함하지 않는다. |
| under-surface | `cookie_tile_under_surface.png` | surface와 interior의 전환 띠. 상단은 surface 측면 가장자리, 하단은 초콜릿 내부로 자연스럽게 이어진다. |
| interior | `cookie_tile_background.png` | 깊은 초콜릿 본체. 쿠키 상단 가장자리를 포함하지 않으며 수직 반복 시 가로 단턱이 보이지 않는다. |

**레벨 데이터에 직접 쓰는 tile type은 3종**:

| `tile_map` 값 | 충돌 | 시각 동작 |
| --- | --- | --- |
| `surface` | 없음 | surface 텍스처. `_add_visual_only_cell()`로 그려짐. |
| `solid` | 있음 | `_add_solid_visual()`로 그려짐. 베이스 텍스처는 §3 자동 추론 1로 결정. |
| `background` | 없음 | interior 텍스처를 시각 전용으로 채움. 빈 공간이 검게 비치는 걸 막는다. |

**under-surface는 별도 tile type이 아니다** — `solid` 셀이 위치에 따라 builder가 자동으로 선택한다. 레벨 작성자는 surface / solid / background 세 가지만 칠한다.

## 3. Builder 자동 동작

`StageLayoutBuilder`가 다음 두 가지를 자동 수행한다. 이 추론이 깨지면 §2 모델 전체가 무너지므로 invariant로 취급한다.

**자동 추론 1 — `_solid_texture_for_cell()`** (line 282)
- `solid` 셀 바로 위가 `surface`이면 베이스 텍스처는 `cookie_tile_under_surface.png`.
- 그 외에는 `cookie_tile_background.png`.

**자동 추론 2 — `_add_solid_visual()` surface overlay** (line 156–172)
- `solid` 셀 바로 위가 `_layout_tile_map()`에 **존재하지 않으면**(= 노출된 천장), surface decoration sprite 한 장을 베이스 위에 추가로 얹는다.
- 즉 레벨에 `surface`를 명시하지 않아도 노출된 솔리드 상단은 시각적으로 surface처럼 보인다. 이중 안전망.

**충돌/시각 분리 invariant**
- `surface` / `background`는 절대로 `StaticBody2D`를 만들지 않고 `Terrain` 점유(occupancy)에 등록되지 않는다.
- `solid`만 충돌 셀이며 `Terrain._static_occupancy`에 `kind="earth"`로 등록된다.

## 4. Atlas 규격 + 생성 도구

**셀 크기**: `48 × 48` 정사각. 모든 tier 텍스처는 이 비율을 따른다.

**Atlas 가로 규격**: `336 × 48` (= 48² 정사각 셀 7개 가로 variant). `_configure_repeating_region()`(line 290)이 `posmod(cell.x, columns)`로 cell.x에 따라 variant를 선택한다 — 같은 row를 따라가도 가로 반복이 단조롭게 보이지 않게 한다.

**SoT 도구**: `scripts/tools/process_new_tiles.py`.
- 원본 painting(에이전트가 별도로 생성)을 `make_seamless()`로 가로 이음새를 자동 블렌딩한 뒤 `336 × 48` atlas로 출력.
- 3개 tier 텍스처를 한 번에 생성한다.
- 같은 출력을 `cookie_tile_<tier>.png` (live)와 `cookie_tile_<tier>_painted.png` (백업) 양쪽에 저장. flip 변종도 동시 생성.

**`_painted` 백업 컨벤션**: live 파일은 추후 다른 후처리(픽셀화 등)가 들어갈 수 있다. `_painted` 변종은 painterly 원본을 항상 보존해두는 컨벤션이다. 도구가 자동으로 동기화하므로 수작업으로 한쪽만 갱신하지 않는다.

**도구 한계** (§5와 직결): `make_seamless()`는 **가로 이음새만** 처리한다. 세로 연결은 도구가 보장하지 않는다.

## 5. 연속성 규칙

**가로 연속성**
- 한 row를 같은 tier로 가로 반복 시 단조로움이나 끊김 없이 하나의 연속된 면으로 읽혀야 한다.
- variant 간 자연스러운 변주(미세 균열, 부스러기, 톤 변화)는 허용, 명백한 반복 패턴은 금지.
- 도구가 `make_seamless()` + 7-variant cycling으로 자동 enforce.

**세로 연속성 — S → U → I → I 4-스텝 체인**

세 tier를 세로로 쌓았을 때 각 전환이 보이지 않게 이어져야 한다. 다음 세 transition이 모두 매끄러워야 한다:

1. **Surface 하단 ↔ Under-Surface 상단** — surface의 바닥 픽셀 톤·디테일이 under-surface의 윗단으로 자연스럽게 흐른다.
2. **Under-Surface 하단 ↔ Interior 상단** — under-surface의 초콜릿 전환부가 interior 상단으로 끊김 없이 연결된다.
3. **Interior 하단 ↔ Interior 상단** — interior가 자기 자신과 세로로 반복될 때 셀 경계마다 가로 능선이 보이지 않는다.

**현재 system은 세로 연속성을 enforce하지 않는다.**
- `process_new_tiles.py`는 가로 블렌딩만 수행한다.
- 3개 tier 텍스처가 서로 **다른 원본 painting 3장**에서 독립 crop된다. 세로 정합은 원본 painting들의 톤 일관성에 의존한다.
- 따라서 **새 자산을 발주할 때 §5의 4-스텝 체인을 요구사항으로 명시**해야 한다. 도구가 통과시킨다고 시각 정합이 보장되는 게 아니다.

향후 system 개선 후보는 §9 참조.

## 6. 레퍼런스 사용 방침

기준 이미지: `assets/illustrations/stage_bg_painted.png`.

- 톤·팔레트·질감의 기준으로만 사용한다.
- **원근감·배경·소품·보석·덤불 같은 비-타일 요소가 포함된 영역은 절대로 직접 크롭해 타일로 쓰지 않는다.**
- 직접 크롭이 이음새를 망치면, 타이틀 이미지는 팔레트·텍스처 레퍼런스로만 두고 필요한 tier 타일은 회화적 스타일을 유지한 채 새로 painting을 의뢰하거나 절차적으로 합성한다.

## 7. 확장 절차

**새 stage에 같은 시스템 적용**
1. `data/stage_layouts/stageNN_layout.tres`에 ground row를 `surface`로, 그 아래 row를 `solid`로 칠한다.
2. 시각적으로 비어 보이면 안 되는 빈 공간(컬럼 절벽 안쪽 등)은 `background`로 채운다.
3. Home / Candy / Spawner 좌표는 시각 `surface` row가 아니라 실제 `solid` 충돌 row에 정렬한다. Stage 1에서 `home_cell` y=16 → y=17로 옮긴 게 그 예시.
4. 시각 추론은 builder가 자동 — 추가 작업 없음.

**새 theme 추가**
1. 같은 3-tier 모델(surface / under-surface / interior)을 유지한 painting을 의뢰한다. §1 painterly 디렉션과 §5 세로 체인 조건을 발주서에 박제한다.
2. `process_new_tiles.py`에 새 theme 분기를 추가하거나, 그에 상응하는 atlas 3장을 같은 규격(`336 × 48`)으로 직접 생성한다.
3. `StageLayoutBuilder._surface_texture()` / `_solid_texture_for_cell()`에 새 theme 분기를 추가한다 — 현재는 `if/elif` chain이라 수정이 필요하다. 이 점이 §9 system 후보의 동기.
4. `layout.theme` 필드를 새 theme 이름으로 설정한 stage layout으로 검증한다.

**새 자산 발주 체크리스트**
- §1 painterly 톤·실패 신호 명시.
- §4 `336 × 48`, 48² × 7 variant 규격 명시.
- §5 세로 체인 4-스텝(S→U→I→I) 정합 요구.
- 가능하면 3개 tier 원본을 **단일 painting의 surface/under/interior 3개 band**로 통합 요청 — 세로 정합이 원본 시점에서 보장된다.

## 8. 회귀 테스트

`tests/test_StageLayoutBuilder.gd`가 본 문서 §2~§3의 invariant를 검증한다.

| 테스트 | 검증 항목 |
| --- | --- |
| `_test_visual_only_tile_types()` | `solid`만 충돌 등록 / `surface` / `background`는 visual-only / under-surface 자동 추론 / interior 자동 추론 / atlas region 크롭 |
| `_test_stage01_background_fill_is_visual_only()` | stage01 실제 layout으로 surface row visual-only + 그 아래 solid 충돌 + 깊은 solid가 interior 텍스처 사용 |

세로 연속성(§5)은 현재 자동 테스트 대상이 아니다 — 시각 검사로만 검증된다.

## 9. 현재 system 한계 + 개선 후보

본 문서가 enforce하려는 규칙 중 system이 받쳐주지 못하는 영역:

1. **세로 연속성 (§5)** — `process_new_tiles.py`에 vertical blend 단계가 없다. 개선안: 단일 source painting의 3-band 통합 또는 도구에 `make_seamless_vertical` 추가.
2. **Theme 확장이 builder 코드 수정을 요구** — 현재 `_surface_texture()` / `_solid_texture_for_cell()`이 string `if/elif` chain. 개선안: `TerrainTheme.tres` 리소스화 — 각 theme가 surface/under/interior 텍스처 3장 + tone 메타데이터를 declared field로 보유.
3. **slope / plant / hazard 시각 규약 미박제** — 각자 별도 경로(`_add_slope_visual` / `_add_plant_visual`)로 그려지며 본 문서의 디렉션을 따른다는 보장이 없다. 개선안: 시각 카테고리별 별도 박제 문서 + builder 시각 경로 통합.

위 셋이 해소되기 전까지 본 문서는 "ground terrain 3-tier 시스템에 한해서만" 가드레일로 작동한다.

## 10. 안티 규칙

다음 중 어느 하나라도 발견되면 즉시 수정한다.

- 지형이 분리된 정사각 스티커처럼 보임.
- `surface` 안에 측면 벽 디테일이 들어감.
- 깊은 interior 타일에 쿠키 상단 단턱이 들어감.
- Interior를 세로 반복했을 때 셀 경계마다 가로 능선이 보임.
- Surface → Under-Surface, Under-Surface → Interior 전환에 띠 단절이 보임.
- 파스텔 배경과 충돌하는 고대비 검정 또는 네온 톤이 사용됨.
- 새 theme / 새 stage 자산을 §1·§5 명시 없이 발주함.
- `cookie_tile_*.png` live 파일만 수정하고 `_painted` 백업을 동기화하지 않음 (또는 그 반대).
- 본 문서의 가드레일을 코드/도구가 enforce한다고 단정함 — 실제 enforce 범위는 §3과 §4 가로 seamless에 한정된다.
- **모래 쌓기 타일을 가로 아틀라스(N-variant)나 seamless 스트립으로 발주함** — 세로 1칸 스택이라 가로 연결이 무의미하고, cell.x variant는 "쌓을 때마다 다르게" 보이는 부작용만 남긴다 (§11).

## 11. 동적 스킬 타일 — 모래 쌓기 (Sand-Mound)

§1~§10은 **가로로 넓게 깔리는 정적 ground terrain**(336×48 가로 아틀라스 + 가로 seamless 반복)을 전제한다.
**모래 쌓기 스킬 타일은 정반대 구조**다 — cookie 지형 규약을 그대로 적용하면 안 된다.

### 11.1 구조 — 세로로 쌓는 1칸 폭 동적 타일

- 개미가 `SandMoundSkill`로 자기 발밑에 타일을 한 칸씩 **위로** 쌓아 만드는 1칸 폭 수직 더미 (최대 `SAND_MOUND_MAX_HEIGHT`=5칸).
- 가로 인접/연결이 없다 → **가로 seamless·N-variant 아틀라스가 불필요**. cookie의 `process_new_tiles.py` / `make_seamless()` / `StageLayoutBuilder._configure_repeating_region` 파이프라인을 쓰지 않는다.
- 정적 ground terrain과 달리 `Terrain.add_tile()`로 런타임 생성되는 동적 `StaticBody2D`다.

### 11.2 자산 — 독립된 정사각형 타일 3장

| Tier | 파일 | 더미 내 위치 |
| --- | --- | --- |
| surface | `sand_tile_surface.png` | 맨 위 칸 |
| under-surface | `sand_tile_under_surface.png` | 위에서 2번째 칸 |
| background | `sand_tile_background.png` | 3번째 이하 (세로 반복) |

- 각 파일은 **단일 정사각형 1칸**(아틀라스 아님). 권장 규격 **48 × 48** (= cell_size).
- **가로 variant 금지** (cookie의 7개 가로 배열과 다름). 한 tier당 그림 1장 → 모든 더미가 **어디에 쌓아도 동일하게** 보인다.
- 위치: `assets/sprites/terrain/`. 파일명은 위 표 그대로 (코드가 이 경로를 `load`).

### 11.3 렌더 동작 (코드 자동)

- **그리기**: `Terrain._apply_sand_tier()`가 텍스처 **전체**를 cell_size에 맞춰 균일 scale한다 (`region_enabled = false`). 가로 슬라이스/오프셋을 쓰지 않으므로 cell_size가 달라도(32/48) 정사각형 그림이 잘리지 않고 통째로 보존된다.
- **tier 배정**: 더미가 위로 자라 맨 위 칸이 계속 바뀌므로, 타일을 쌓을 때마다 `Terrain._reskin_sand_column()`이 column을 위→아래 surface → under_surface → background로 재배정한다 (3번째 이하는 한 번 background가 되면 불변 → 상위 3칸만 갱신해도 invariant 유지).
- 아트 담당은 **그림 3장만** 만들면 된다. tier 배정·재스킨은 코드가 한다.

### 11.4 연속성 — 세로만 중요

- 가로 연속성은 무의미하다 (1칸 폭).
- 대신 **세로로 쌓았을 때** surface 하단 → under_surface → background → background가 매끄럽게 이어져야 한다 (§5의 S→U→I→I 체인을 **세로로만** 적용).
- background는 세로 self-repeat 시 셀 경계에 가로 능선이 보이지 않아야 한다.

### 11.5 부트스트랩 + 회귀 테스트

- 새 PNG 교체 후 `godot --headless --path . --import` 1회 필수 (안 하면 런타임 `load()`가 null → 타일 안 보임).
- `tests/SandMoundMaxHeightTest.gd`가 검증: (1) tier 순서 surface→under→background (2) `region_enabled = false` (3) cell_size에 맞춘 whole-texture scale (4) 중앙 정렬.
- `tests/SandMoundClimbOverLedgeTest.gd`는 더미가 기존 솔리드 레지를 타고 넘는 게임플레이를 검증 (시각과 별개).
