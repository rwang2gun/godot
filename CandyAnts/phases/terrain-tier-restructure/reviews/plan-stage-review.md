# Plan-stage Adversarial Review — terrain-tier-restructure

## Round 1 (codex, 2026-06-01)

Target: working tree diff (untracked plan markdown: REVISION + phase01 + phase02)
Verdict: **needs-attention** (CRITICAL/HIGH 0건 · MEDIUM 2건)

No-ship (codex): the plan leaves the riskiest visual predicate under-specified and does not actually
verify one of the migrated production layouts at runtime.

Findings:
- **[medium]** Exposed-top predicate is underspecified for non-`solid` blockers (`phase02-remove-surface-tier.md:28-30`)
  Phase 2 says `_solid_texture_for_cell` should use under-surface when the cell above is not a "collision
  solid", then paraphrases that as "above is solid". In the current builder, collision bodies are not only
  `solid`: `_add_cell` also creates/registers bodies for slopes and `plant`. If implementation follows the
  narrower `TILE_SOLID` interpretation, a solid directly under a slope or plant will be treated as exposed
  and rendered with `cookie_tile_under_surface.png` even though it is occluded by a collision tile.
  Conversely, the plan does not pin down how visual-only `background` above a solid should behave.
  Recommendation: Define an explicit predicate for "above blocks exposure" and add builder tests for
  solid-under-slope, solid-under-background, isolated solid, and stacked solid cases.
- **[medium]** Stage01 layout migration lacks runtime regression coverage (`phase02-remove-surface-tier.md:35-53`)
  The plan removes surface cells from stage01/02/03 and claims collision/occupancy/score invariants, but the
  Phase 2 verify chain only runs Stage02 and Stage03 headless tests. `test_StageLayoutBuilder` samples a few
  Stage01 builder nodes but is not a runtime test. A stage01 regression can pass the declared gate despite
  modifying 32 stage01 cells.
  Recommendation: Add a Stage01 runtime/headless regression, or an explicit all-stage migration invariant
  test (collision count, `_static_occupancy`, alignment, score-relevant state) after surface removal.

Next steps (codex):
- Tighten Phase 2 before implementation: specify the exposure predicate and expand the verification gate for Stage01.

### 처리
Plan-stage 정책(CLAUDE.md 2026-05-25): CRITICAL/HIGH 0건 → STOP 불필요. MEDIUM/LOW만 남으면 plan 내 처리 또는
명시 defer로 종결. 두 MEDIUM 모두 plan을 더 정확하게 만들므로 **반영**(defer 없음). 추가 codex 라운드 불필요.

- **[MEDIUM M1] 반영**: `phase02` `_solid_texture_for_cell` exposure 술어를 모호한 "collision solid"가 아니라
  **`not map.has(above_key)`**(= `_add_solid_visual`의 기존 `is_surface` 정의와 동일 SoT)로 못박음. 위 칸이
  레이아웃에 **존재하지 않을 때만** under-surface, 존재하면(tile type 불문 solid/slope/plant/background) interior.
  → solid-under-slope/plant/background 자동 정합. 합성 레이아웃 edge case 4종(stacked / under-slope /
  under-background / isolated-exposed) BaseSprite 텍스처 assert 추가.
- **[MEDIUM M2] 반영**: Stage01 런타임 헤드리스 씬 부재 확인(Stage02/03만 존재). `test_StageLayoutBuilder`에
  **3-stage 점유 불변 테스트** 추가 — stage01/02/03 실제 `.tres` 빌드 후 `_static_occupancy` 점유 집합 ==
  collision-tile(`solid`/`slope_*`/`plant`) 집합 일치를 stage01 포함 전 stage에서 박제. surface 시각 전용 제거가
  충돌/점유/스코어를 구조적으로 바꾸지 않음을 증명.

verdict: MEDIUM 2건 plan 반영 완료 → plan-stage 종결. impl(Phase 1)로 진행.
