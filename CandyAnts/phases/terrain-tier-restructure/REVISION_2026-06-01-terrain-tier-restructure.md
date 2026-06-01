# REVISION — terrain-tier-restructure (2026-06-01)

> 지형 ground terrain의 **3-tier(surface / under-surface / interior)** 시각 구조에서
> **surface tier를 제거**해 **under-surface가 최상단**이 되게 한다.
> 동시에 직전 트랙 `skill-tile-surface`(Phase 1~4)가 추가한 **굴착 surface 캡 인프라를 통째 revert**한다.
> 1차 SoT는 본 문서 + `docs/TERRAIN_TILE_RULES.md`(Phase 2에서 2-tier로 재작성). 트랙: gameplay/terrain 시각, Claude 직접 수행.

---

## 1. 배경

`skill-tile-surface` 트랙(2026-06-01)은 굴착(digger/basher)으로 드러난 면을 cookie 3-tier로
보이게 하려 했으나, 현 레벨/타일 구조(얇은 solid + background 채움 + 빌드타임 고정 tier) 위에서
"굴착 단면의 3단 연속성"을 만드는 게 비효율적이라는 결론에 도달했다
(`worklog/2026-06/2026-06-01-skill-tile-surface-and-level-restructure-plan.md` §4~§5).
그 후속으로 **레벨/지형 구조 개편**을 진행하며, 그 첫 스텝이 **surface tier 제거**다.

## 2. 사용자 확정 결정 (2026-06-01)

| # | 질문 | 결정 |
| --- | --- | --- |
| 1 | surface 제거 후 최상단 룩 | **under-surface가 최상단** — 톱다운 surface 텍스처/타일/오버레이 전부 제거. 걷는 행 = `solid`(under-surface 텍스처), 그 아래 = `solid`(interior). 2-tier(under→interior). |
| 2 | 걷는 바닥 아래 `background` 채움 | **이번엔 안 건드림** — background 폐기/solid 깊이 전환은 다음 단계로 분리. |
| 3 | skill-tile-surface 굴착 캡 인프라 | **제거/되돌림** — surface 개념을 없애므로 굴착 surface 캡 로직과 모순. Phase 1~4 인프라 통째 revert. |
| 4 | basher 2칸 머리공간(Phase 4) | **되돌림(1칸 터널)** — skill-tile-surface 통째 revert. basher는 body row 1칸만 제거 = Phase 18 원래 동작. `destroy_static_cookie_cell`(머리공간)도 제거. |
| 5 | 작업 구성 | **새 harness task** — 정식 phase 프로세스(plan → adversarial-review → impl → review). |

## 3. 확정 스코프

**포함**
1. `StageLayoutBuilder`: `surface` 타일 타입 + 노출천장 자동 오버레이(자동 추론 2) 제거. `_solid_texture_for_cell` 규칙 반전 — **노출된 최상단 solid → under-surface 텍스처**, 그 아래(위에 solid가 있는 셀) → interior(background) 텍스처.
2. `data/stage_layouts/stage01/02/03_layout.tres`: `surface` 셀 제거 (Stage1: 32, Stage2: 40, Stage3: 27개). surface 셀은 충돌 없는 시각 전용이라 좌표/충돌/Home/Candy/Spawner 정렬 **불변**.
3. `skill-tile-surface`(Phase 1~4) 굴착 surface 캡 인프라 통째 revert:
   - `Terrain.gd`: `register_cookie_tier_textures` / `get_cookie_*_texture` / `apply_cookie_surface_overlay` / `_configure_cookie_region` / `_cap_exposed_below` / `_is_solid_cookie_body` / `apply_under_surface_at` / `destroy_static_cookie_cell` / `_cookie_*_tex` 필드 / `COOKIE_SURFACE_CAP_NAME` 제거 + `destroy_tile_at`의 `apply_below_surface_cap` 파라미터 제거(Phase 18 시그니처 `destroy_tile_at(cell, allowed_kinds)` 복귀).
   - `WorkerState.gd`: `_destroy_digger_cell`/`_destroy_basher_cell`의 cap opt-in(`true`) 제거, basher 머리공간(`destroy_static_cookie_cell`) + 바닥 재스킨(`apply_under_surface_at`) 호출 제거 → basher 1칸 터널.
   - `StageLayoutBuilder.build()`: `register_cookie_tier_textures(...)` 호출 제거.
   - 테스트 제거: `CookieSurfaceOverlayTest` / `DiggerExposedSurfaceTest` / `BasherExposedSurfaceTest` / `BasherHeadroomTierTest`(+ dev `dev_basher_headroom_layout.tres` / `BasherHeadroomTest.tscn`).
4. `docs/TERRAIN_TILE_RULES.md`: 2-tier(under-surface top / interior)로 재작성.
5. `tests/test_StageLayoutBuilder.gd`: invariant 갱신(surface 소멸 / 노출 solid = under-surface / overlay 없음).

**범위 밖 (다음 트랙)**
- `background` 채움 폐기 또는 solid 깊이 전환.
- 굴착 후 동적 re-tiering (노출 셀 tier 재계산).
- 세로 단면(측벽) tier 규칙.
- **sand-mound(§11) surface tier** — 별도 동적 스킬 타일 시스템. 본 트랙에서 미변경(향후 일관화 후보).
- **슬로프** — `_add_slope_visual`은 `cookie_tile_surface.png`를 대각 윗면 텍스처로 계속 사용. surface PNG **파일은 슬로프용으로 보존**(삭제 금지). 슬로프는 별도 시각 규칙(`TERRAIN_TILE_RULES` 범위 밖).

## 4. Phase 분해

| Phase | slug | 내용 |
| --- | --- | --- |
| 1 | revert-excavation-surface-caps | skill-tile-surface Phase 1~4 캡 인프라 통째 제거. 정적 지형 렌더 무변경(surface 타일 아직 유지). basher/digger → Phase 18 동작. |
| 2 | remove-surface-tier | builder surface 타일 타입+오버레이 제거 + `_solid_texture_for_cell` 반전 + 3개 레이아웃 마이그레이션 + `TERRAIN_TILE_RULES` 2-tier 재작성 + `test_StageLayoutBuilder` 갱신. |

선형 의존: Phase 2는 Phase 1의 클린 baseline(캡 제거 완료) 위에서 진행.

## 5. 회귀 가드

- Phase 1: `BasherTunnelThroughWallTest` / `BasherEdgeStopTest` / `DiggerVerticalTunnelTest` / `TerrainDestroyTileApiTest`(2-arg, 캡 미참조) / `Stage03HeadlessTest` 회귀 0건.
- Phase 2: `test_StageLayoutBuilder` / `StageLayoutBuilderEarthBackwardCompatTest` / `Stage02HeadlessTest` / `Stage03HeadlessTest` + surface 셀 제거 후 충돌/점유/스코어 불변 + 시각 스크린샷 검사.
