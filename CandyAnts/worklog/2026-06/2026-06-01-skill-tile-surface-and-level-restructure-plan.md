# 굴착 타일 surface 일관화 시도 + 레벨 구조 개편 결정 — 2026-06-01

> 굴착 스킬(digger/basher)이 파괴·생성한 타일을 cookie 3-tier(surface/under-surface/interior) 구조로
> 보이게 하려는 시도(`skill-tile-surface` task, Phase 1~4)와 그 결과, 그리고 **현 레벨 구조로는 한계가 있어
> 레벨 구조 개편으로 방향을 전환**하기로 한 결정을 기록.
> 위치: `worklog/2026-06/2026-06-01-skill-tile-surface-and-level-restructure-plan.md`
> 트랙: gameplay/terrain 시각. Claude 직접 수행. SoT: `docs/TERRAIN_TILE_RULES.md`, `phases/skill-tile-surface/`.

---

## 1. 배경 — 원 요청

사용자: "3스테이지에서 개미가 굴착했을 때 파인 타일이 3층 구조를 안 따라서 어색하다. surface 구조를 갖게 할 수 있나?"

- 초기엔 "땅파기(digger)"로 보고됐으나, **Stage 3의 실제 굴착 스킬은 basher(가로 터널)**임이 확인됨
  (`stage03.tres`: `available_skills = ["basher"]`, digger 없음). 사용자도 digger/basher 혼동을 인정.
- 핵심 니즈: 굴착으로 드러난 **걸을 수 있는 면(walkable surface)**이 주변 지형처럼 cookie로 보일 것.

## 2. 진행한 작업 — `skill-tile-surface` task (Phase 1~4, 전부 main 커밋)

정식 phase 프로세스(plan → plan-stage adversarial-review → impl → self/codex adversarial-review 루프 → complete).

| Phase | 내용 | commit |
| --- | --- | --- |
| 1. surface-skin-infra | `Terrain`에 cookie 3-tier 텍스처 등록(`register_cookie_tier_textures`) + 동적 surface 오버레이 헬퍼(`apply_cookie_surface_overlay`, 멱등·null-safe·geometry 일반화). `StageLayoutBuilder.build()`이 빌드 타임 등록. | `6c0aa7f` |
| 2. digger-exposed-surface | `destroy_tile_at(..., apply_below_surface_cap)` opt-in 추가. digger가 파낸 칸 아래(새 바닥)에 surface 캡. 정적 사각 cookie만 대상(slope/plant/동적 제외, 빌드타임 SurfaceSprite 중복 가드). | `340e893` |
| 3. basher-exposed-surface | basher도 동일 opt-in으로 터널 바닥에 surface 캡. 테스트 계약 정리(opt-in=false=cutter 무캡 / basher positive 분리). | `39fc514` |
| 4. basher-headroom-tier | basher가 몸통+위 행 2칸 제거(머리공간, **정적 쿠키 벽만**) + 바닥 아래 칸 under-surface 재스킨(`apply_under_surface_at`). | `71c4b03` |

부수 커밋: `.gitignore` worktrees 규칙(`33883b0`, pull 머지 해결).

신규 테스트(전부 PASS): `CookieSurfaceOverlayTest`, `DiggerExposedSurfaceTest`, `BasherExposedSurfaceTest`,
`BasherHeadroomTierTest`(+ dev 레이아웃/씬 `dev_basher_headroom_layout.tres`/`BasherHeadroomTest.tscn`).
기존 basher/digger/Stage03 회귀 0.

## 3. 결과 — 실제로 동작하는 것 (헤드리스 실측 + 스크린샷 검증)

실제 Stage 3에 진짜 ant를 굴려 basher로 둔덕(cols 12-16, rows 17-21)을 뚫고 측정:
- `(12,20)`·`(12,21)` 둘 다 제거 → **2칸 높이 터널(머리공간) 작동 ✓**
- `(12,22)` 바닥에 surface 캡 1장 → **바닥 surface 작동 ✓** (base는 background + 캡 오버레이)

스크린샷: `worklog/2026-06/assets/2026-06-01-stage3-basher-tunnel.png` — 2칸 터널 + 쿠키 바닥 확인됨.

> 참고: 사용자가 중간에 본 "1칸 터널"은 Phase 4 이전(Phase 3) 빌드 화면으로 추정(해당 창에 basher 적용 로그 없음).

## 4. 한계 — 현 구조로는 "어색함"의 본질을 못 잡음

사용자 최종 피드백: **"터널과 좌우 타일 구조가 다르다. surface/under-surface 타일을 써서 터널이 아닌 곳과 연결되는 구조여야 한다."**

즉 진짜 니즈는 floor 캡이 아니라 **굴착으로 드러난 모든 면(특히 세로 단면·가장자리)이 주변 지형의 3단 구조와 연속**되는 것. 현 구조의 장벽:

1. **`background` 채움**: Stage 3는 걷는 바닥(row 22) 아래가 전부 `background`(시각 전용, StaticBody2D·occupancy 없음). under-surface 재스킨/세로 단면 tier는 `solid` 셀에만 적용 가능 → background 영역엔 못 입힘.
2. **가로 터널의 가림**: under-surface는 floor(row 22) 아래(row 23)에 들어가는데, 가로 터널에선 그 윗면이 floor에 덮여 **보이지 않음**. "바닥 2-tier"가 시각적으로 드러나지 않는 근본 이유.
3. **세로 단면 미처리(의도적 제외)**: 지금까지 "측벽(세로 단면) surface"는 스코프에서 제외. 그런데 터널이 안 뚫린 지형과 "이어져 보이려면" 바로 그 세로 단면의 tier 연속성이 필요.
4. **동적 re-tiering 부재**: 굴착 후 드러난 셀들의 tier(surface/under/interior)를 빌드타임 규칙(`_solid_texture_for_cell`)대로 **런타임에 재계산**하는 메커니즘이 없음. 현재는 floor에 캡 1장 얹는 수준.

→ **결론: 현 레벨/타일 구조(얇은 solid + background 채움, 빌드타임 고정 tier) 위에서 "굴착 단면의 3단 연속성"을 만드는 건 비효율적이고 복잡하다.** 사용자 판단: "지금 구조로는 너무 어려울 것 같다. 레벨 구조에 대한 새 방향성이 필요하다."

## 5. 결정 — 레벨 구조 개편으로 전환

- `skill-tile-surface` task의 Phase 1~4 산출물(인프라 + 굴착 캡)은 **유지**(유용한 토대). Phase 5(bridge-builder-surface)는 **보류**.
- 다음 단계는 **레벨/지형 구조 개편**: 굴착이 일어나도 드러난 모든 면이 3단(surface/under/interior)으로 주변과 연속되게 하는 **새 지형 모델**을 설계한다.

### 개편 시 검토할 방향 (다음 세션 입력용, 미확정)
- **지형 본체를 `solid` 깊이로**(background 채움 폐기 또는 축소) → 굴착 단면이 실제 solid 셀이라 tier 부여 가능.
- **굴착 후 동적 re-tiering**: 파괴/노출 시 인접 셀의 tier를 빌드타임 규칙으로 재계산(노출 윗면=surface, 그 아래=under, 깊은 곳=interior). `Terrain`에 "void 인접 셀 re-tier" 연산 신설.
- **세로 단면 tile 규칙 박제**: `TERRAIN_TILE_RULES`에 측벽/단면 tier 규칙 추가(현재 §0에서 측벽은 범위 밖).
- 성능(굴착 매 틱 re-tiering 범위), 회귀(기존 stage 레이아웃 마이그레이션), `background` 폐기 시 빈 공간 검정 비침 방지 등 트레이드오프 정리 필요.

## 6. 미해결/후속
- [ ] 레벨 구조 개편 방향 확정 (위 검토안 중 택1 또는 신안) → 새 task/phase 설계.
- [ ] 확정 후 `docs/TERRAIN_TILE_RULES.md` 세로 단면/동적 re-tiering 규칙 박제.
- [ ] `skill-tile-surface` Phase 5(bridge-builder) 재개 여부 결정 (개편 결과에 종속될 수 있음).
- [ ] 임시 아티팩트 정리: 본 worklog의 스크린샷은 근거용 보존.
