# Stage 2/3 3-tier 지형 구조 확장 — 2026-05-29

> Stage 1에서 락다운한 3-tier 지형 시각 시스템(surface / under-surface / interior)을
> 나머지 전 스테이지(Stage 2·3)로 확장.
> 위치: `worklog/2026-05/2026-05-29-stage-3tier-layout-migration.md`
> 트랙 관계: `docs/TERRAIN_TILE_RULES.md` §7 "확장 절차"를 따른 일회성 layout 데이터 마이그레이션.
> Claude 직접 수행(코덱스 핸드오프 아님). 산출물은 map-editor 트랙의 artifact(`data/stage_layouts/`)이므로 STATUS "다음 작업" 항목도 갱신.

---

## 1. 배경

- Stage 1만 3-tier 구조(`stage01_layout.tres`, commit `a4cc9d7`). Stage 2·3은 구버전 `solid` 한 줄짜리 → 렌더 시 공중에 뜬 얇은 wafer 막대처럼 보임(크러스트·초콜릿 깊이 없음).
- 사용자 요청: "Stage 1 구조를 전체 스테이지로 확장." 결정 — Stage 1과 **동일 풀 적용**(background 내부 채움까지), 레벨은 새로 작성 가능하되 **새 타일 구조가 동일 규칙으로 게임 내 동작**할 것.

## 2. 핵심 설계 — 가산 시각 레이어 (충돌 불변)

`TERRAIN_TILE_RULES.md` §3: `surface`/`background`는 StaticBody2D·occupancy 미생성. → 3-tier는 **순수 가산 시각 레이어**.

따라서 **기존 `solid` 충돌 cell·엔티티 좌표·spawn 파라미터를 한 칸도 변경하지 않고** surface 캡 + background 깊이만 추가.
- 충돌 geometry/퍼즐/스킬 상호작용 불변 → 헤드리스 회귀 테스트가 메커니즘적으로 깨질 수 없음.
- 엔티티(home/candy/spawn)는 이미 `solid` 한 칸 위(= surface row)에 정렬돼 있어(Stage 1 컨벤션과 동일) **좌표 변경 불필요**.
- 깊이 bottom row 30 (Stage 1과 동일, 뷰포트 1080 하단 일치).

스테이지별 처리:
- **Stage 2 (모래 다리)**: 바닥 solid(22) + surface(21) + background(23~30). 떠 있는 캔디 발판 solid(17) + surface(16) + 얇은 밑면 background(18). 발판은 **공중 유지**(ants가 밑을 지나 x≈870에서 builder 다리 — `Stage02HeadlessTest` TRIGGER_X 보존). 갭을 메우면 퍼즐이 깨지므로 deep-fill 대신 1줄 밑면만.
- **Stage 3 (흙을 깎다)**: 바닥 solid(22) + surface(21, 흙벽 col 12~16 제외) + background(23~30). 흙벽 기둥 solid(12~16 × rows 17~21) 유지 + surface(16) → 깊은 solid는 빌더가 자동 초콜릿 텍스처 렌더(별도 background 불필요). 좌측 step(2,21) 유지 + 시각 보강.

## 3. 산출물

- `scripts/tools/build_stage_3tier_layout.py` — **신규**. §7 확장 절차를 코드로 박제한 재현 가능 생성기. 각 stage의 3-tier 구조를 명시적으로 기술 → `.tres` 재작성. `--print`로 미리보기.
- `data/stage_layouts/stage02_layout.tres` — 재작성 (40 solid + surface/background, 302 tiles). uid/엔티티 필드 보존.
- `data/stage_layouts/stage03_layout.tres` — 재작성 (52 solid + surface/background, 296 tiles). uid/엔티티 필드 보존.
- `tests/StageLayoutBuilderEarthBackwardCompatTest.gd` — **선재 버그 수정**. criterion (4) `occ == tile_map.size()`가 3-tier(surface/background 비충돌)와 모순 → 충돌 타일(solid/slope/plant) 수로 카운트하도록 정정. `a4cc9d7`가 stage01을 3-tier로 바꾸면서 남긴 red(`occ=40 expected=388`)를 해소.

## 4. 검증 (evidence)

충돌 cell 보존 교차검증: Stage 2 solid 40→40 / Stage 3 52→52 (added 0, **lost 0**). 엔티티·카메라·spawn·cell_size 전 필드 불변.

| 테스트 | 베이스라인 | 변경 후 | 판정 |
| --- | --- | --- | --- |
| `Stage03HeadlessTest` (clear) | PASS | PASS | 보존 |
| `Stage02HeadlessTest` | FAIL(time_out) | FAIL(time_out) | 불변 (선재) |
| `test_StageLayoutBuilder` | — | PASS | ok |
| `StageLayoutBuilderEarthBackwardCompatTest` (23 layout) | FAIL(stage01) | PASS | 선재 red 해소 |
| `GameFlowTest` A/B/C (통합) | — | PASS | ok |

시각 검증: `verify_stage0{1,2,3}.png` 재생성 — Stage 2·3가 Stage 1과 동일한 크러스트+초콜릿 입체 쿠키 지형으로 렌더 확인.

## 5. 남은 과제 / deferred

- **(선재) `Stage02HeadlessTest` time_out**: 변경 전부터 실패. 빌더 다리 하나로 5칸 발판 등반 클리어가 안 되는 **밸런스/테스트 타이밍 문제**이며 지형 시각과 무관. 별도 과제(테스트 driver 보강 또는 stage 2 퍼즐 밸런싱).
- **맵 에디터 surface/background 브러시 미지원**: 이번엔 생성기로 hand-author. 에디터 기반 저작을 하려면 `addons/candyants_level_tool`에 surface/background 브러시 + 자동 깊이 채움 추가 필요 (map-editor STATUS 참조).
- **퍼즐 재설계**: 사용자가 "레벨 새로 만들어도 OK"라 했으나, 회귀·스코프 보존을 위해 이번엔 지형 시각만 3-tier화하고 퍼즐 정체성(흙벽/갭/발판 위치)은 유지. 퍼즐 자체 재설계는 별도 후속.
- §5 세로 연속성은 여전히 도구 미enforce (TERRAIN_TILE_RULES §9-1). 시각 검사로만 확인.
