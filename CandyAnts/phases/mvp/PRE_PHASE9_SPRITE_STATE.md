# Pre-Phase 9 — Sprite Integration & Asset State Snapshot

> 작성일: 2026-05-16
> 작성 시점: Phase 8(input-pause-step) 완료 후, Phase 9(ui-theme-assets) 진입 전
> 위치: phases/mvp/PRE_PHASE9_SPRITE_STATE.md
> 목적: chibi PNG 스프라이트가 게임에 들어가는 hot-fix가 phase 9 정식 진입 전에 처리됐고, 핸드오프 SVG와의 충돌 정리가 필요해 현재 상태를 동결 기록.

---

## 1. 발생 경위

- Phase 8 완료(commit `13123a2`) 후 사용자가 "Phase 9 진입 전에 캐릭터/캔디가 실제 스프라이트로 보이는 화면을 만들고 넘어가고 싶다"고 요청.
- 당시 Ant.tscn 시각은 갈색 `Polygon2D` 12×10 placeholder, Candy.tscn은 노란 `Polygon2D` 24×16 placeholder.
- 한편 `assets/sprites/characters/ant_pajama_girl/`에 chibi 잠옷 캐릭터 PNG 시트 9 애니메이션(idle/walk/carry/fall/blocker/climb/dig/build/victory)이 이미 임포트만 된 채 unused 상태였고, `assets/sprites/candy/`에도 6프레임 PNG가 임포트만 된 상태.
- 결정: **Phase 카운트를 늘리지 않고** hot-fix 형태로 시각 swap만 처리. 게임 로직(state/collision/direction)은 무변경, 시각 노드만 교체.

## 2. 적용된 변경 (이미 워킹 트리에 있음, 미커밋)

### 신규 파일
- `assets/sprites/characters/ant_pajama_girl/AntFrames.tres` — 9 애니메이션 SpriteFrames 리소스 (idle 6fps, walk 10, carry 10, fall 12, blocker 4, climb 8, dig 8, build 8, victory 8). victory만 loop=false, 나머지 loop=true.
- `assets/sprites/candy/CandyFrames.tres` — 6프레임 단일 `default` 애니, 4fps loop.

### 수정 파일
- `scenes/entities/Ant.tscn`:
  - `Polygon2D` "Sprite" 노드 제거.
  - `AnimatedSprite2D` "Sprite" 노드 추가. `position=(0,-14)`, `scale=(0.08,0.08)`, autoplay=`idle`.
  - 원본 PNG 329×473 → 렌더 ~26w × 38h px. collision 12×10은 그대로 유지(시뮬레이션 무회귀).
  - 발 baseline이 collision 바닥(y=+5)에 맞도록 sprite y offset = -14.
- `scenes/entities/Candy.tscn`:
  - `Polygon2D` 제거, `AnimatedSprite2D` 추가. `scale=(0.09,0.09)`. 원본 250×302 → 렌더 ~22×27.
- `scripts/ant/Ant.gd`:
  - `_sprite: AnimatedSprite2D` 필드 + `_last_anim` 캐시 추가.
  - `_ready()`에서 `$Sprite` 바인딩.
  - `_physics_process()` 끝에 `_update_sprite()` 호출 — state 분기 보고 anim 매핑 + `direction<0` 시 `flip_h`.
  - 매핑: Walker→walk, Carrying→carry, Faller→fall, Worker[blocker]→blocker, Worker[builder]→build, Worker[기타]→dig, 그 외→idle.
- `scripts/world/Candy.gd:5`:
  - `_sprite` 타입을 `Polygon2D` → `AnimatedSprite2D`로 변경.
  - depleted 시 회색조 처리: `_sprite.color` → `_sprite.modulate`로 전환 (AnimatedSprite2D엔 color 속성 없음).

### 미적용 — 미사용 자산 (정리 대상)
- `assets/sprites/chibi_ant_pajama_girl_sprite.png` + `.import` — `generate_chibi_ant_pajama_sprite.py` 산출물, 더 이상 참조하지 않는 단일 시트.
- `scripts/tools/generate_chibi_ant_pajama_sprite.py`, `scripts/tools/prepare_ant_pajama_idle_sheet.py` — 시트 제작 보조 스크립트. 재현성 보존 vs 제거 결정 보류 중.

## 3. 검증 결과

- `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` → **PASS** (`[Phase4Test] PASS`).
- `python scripts/run_test.py tests/BlockerOverlapTest.tscn` → **PASS** (B-1 ~ B-8 전수).
- 에디터 실행에서 발생한 lint 경고들(`signal X declared but never explicitly used`, `GameAction has the same name as a global class`, `local variable "name" is shadowing...`)은 본 변경 이전부터 존재. 빌드/실행 영향 없음.
- 초기 에디터 실행 시 `Candy.@implicit_ready: Trying to assign value of type 'AnimatedSprite2D' to a variable of type 'Polygon2D'` 에러는 `Candy.gd:5` 타입 변경으로 해소.

## 4. 자산 인벤토리 — 현재 섞임 상태

| 분류 | 위치 | 스타일 | 카운트 | 상태 |
|---|---|---|---|---|
| A. 캐릭터 PNG 시트 | `assets/sprites/characters/ant_pajama_girl/` | chibi 잠옷 일러스트 | 9 anim, 36 frame | **production 사용 중** |
| B. 캔디 PNG 시트 | `assets/sprites/candy/` | chibi 일러스트 | 6 frame | **production 사용 중** |
| C. 스킬 SVG 아이콘 | `assets/icons/skills/` | 벡터 토큰화 (pure hex, 정규화 완료) | 8 | **production SoT** (phase 10 toolbar 예정) |
| D. 핸드오프 SVG 스프라이트 | `docs/design_handoff/assets/sprites/` | 벡터 모노그램 (oklch + class) | 15 (ant×13 + candy + home) | **designer-source, 미정규화** — A/B와 의도 중복 |
| E. 핸드오프 로고/일러스트 SVG | `docs/design_handoff/assets/{logo,illustrations}/` | 벡터 (oklch + class) | 4 (wordmark, icon, mascot, stage_bg) | **designer-source, 미정규화** — phase 9 정규화 대상 |
| F. Phase 9 plan output | `scripts/tools/svg_color_map.json` | 매핑 SoT | 1 | 작성 완료 (2026-05-09 enumerate 기반) |
| G. 잡 파일 | `assets/sprites/chibi_ant_pajama_girl_sprite.png`, `scripts/tools/generate_*.py` | 생성 흔적 | 1 png + 2 py | 정리 대상 |
| H. 디자이너 노트 | `assets/sprites/characters/ant_pajama_girl/SPRITE_PLAN.md` | 문서 | 1 | 보존 (production 가이드) |

## 5. 핵심 충돌

**D vs A/B** — Phase 9 plan(`phase09-ui-theme-assets.md`)은 D(핸드오프 ant*.svg 15개)를 정규화해 `assets/sprites/ant*.svg`로 production output을 만드는 게 목표.
- 그러나 A/B(chibi PNG)가 이미 더 풍부(9 애니 × 다중 프레임 vs 정적 1프레임)하게 들어가 있고 본 hot-fix로 게임 시각의 SoT가 됨.
- D를 그대로 정규화하면 **사용처가 없는 산출물**이 됨. SvgImportSmokeTest는 27장을 강제하지만 그 중 15장은 dead asset이 됨.
- 동시에 svg_color_map.json의 `class_map` 27 엔트리 중 sprite 전용 클래스가 다수 — D 폐기 시 매핑도 축소 가능.

## 6. 권장 정리 방향 — Mixed canon

엔티티(살아 움직이는 것: Ant·Candy)는 **chibi PNG가 canon**, UI/로고/배경(정적: Skill icon, Logo, Home, Stage BG)은 **SVG가 canon**.

근거:
- 두 스타일이 시각적으로 직접 경쟁하지 않음 (entity ≠ UI chrome).
- A/B는 41 프레임 일러스트, D는 1프레임 모노그램 — A/B 폐기 비용이 훨씬 큼.
- Phase 9 scope만 줄이면 정합성 회복 (전체 plan 재작성 불요).

## 7. Phase 9 plan revision (v4) 예정 사항

본 문서가 결정의 1차 근거. 사용자 승인 후 `phase09-ui-theme-assets.md` 갱신:

1. **D 폐기** — `### 산출 SVG` 섹션의 `assets/sprites/ant*.svg (15)` 항목 삭제. handoff sprites는 디자이너 reference로 남겨두되 정규화 대상에서 제외.
2. **SVG 카운트** 27 → **12** (logo 3 + skill icons 8 + illustration 1).
3. **SvgImportSmokeTest** 카운트·잔여 검사 범위 12장으로 축소.
4. **svg_color_map.json** — sprite 전용 `class_map` 엔트리 pruning (e.g. `.ant-belly`, `.ant-hood` 등). `oklch_extras` 중 stage_bg 전용은 유지, sprite 전용은 제거.
5. **신규 항목** — UI_GUIDE 또는 본 plan에 "Ant·Candy 시각은 chibi PNG SpriteFrames(`AntFrames.tres`, `CandyFrames.tres`), pre-phase 9 hot-fix로 적용 완료. phase 10/11에서 sprite swap 없음" 명시.
6. **Home 처리** — handoff `home.svg`는 정규화 대상으로 남길지 결정. Home은 entity지만 정적이라 SVG 적합. → 권장: **유지** (SVG 카운트 12 → 13).
7. **본 hot-fix 변경분 커밋 시점** — phase 9 plan revision과 같은 커밋으로 묶을지, 먼저 `feat(sprite): wire chibi pajama girl + candy animated sprites` 단독 커밋으로 분리할지 사용자 결정.

## 8. State → Animation 매핑 표 (구현 SoT)

| State | work_type | Animation | Loop | FPS | 비고 |
|---|---|---|---|---|---|
| WalkerState | — | walk | true | 10 | direction에 따라 flip_h |
| CarryingState | — | carry | true | 10 | 사탕 보유 중 |
| FallerState | — | fall | true | 12 | 낙하 중 |
| WorkerState | blocker | blocker | true | 4 | 정지 자세 |
| WorkerState | builder | build | true | 8 | 다리 건설 모션 |
| WorkerState | basher/digger/기타 | dig | true | 8 | 현재 basher/digger는 plan 단계, dig 애니로 통일 대응 |
| SavedState | — | (없음, 즉시 queue_free) | — | — | 향후 retain 시간 줄 경우 victory 재생 가능 |
| DeadState | — | (없음, 즉시 queue_free) | — | — | dead 시트 미제작 (SPRITE_PLAN §7) |
| (외) | — | idle | true | 6 | fallback |

## 9. 사이즈 결정 근거

- Ant 원본 PNG: 329 × 473 (잠옷 캐릭터 일러스트).
- 게임 CELL_SIZE = 16px, collision 12 × 10.
- scale = 0.08 → 렌더 ~26w × 38h ≈ 1.6 × 2.4 셀. "현재 도형보다 조금 더 큼" 요구 만족.
- sprite offset y = -14 — 발 baseline을 collision 하단(y=+5)에 맞춤. 계산: 렌더높이/2 ≈ 19, 중앙→발끝 9.5px 보정 + collision 하단 정렬.
- Candy 원본 250 × 302, scale 0.09 → ~22 × 27. 24×16 collision과 비슷한 가로폭, 위로 약간 돌출 (사탕 머리 표현).

## 10. 결정 보류 항목 (사용자 입력 필요)

1. **Mixed canon 확정** — 본 문서 §6 권장안을 phase 9 revision v4로 반영해도 OK?
2. **G 정리** — generate 스크립트(`scripts/tools/generate_*.py`)와 단일 시트(`chibi_ant_pajama_girl_sprite.png`) 제거 vs 보존?
3. **Home SVG 처리** — Phase 9 정규화 대상에 포함(권장) vs 제외?
4. **커밋 시점** — sprite swap 단독 커밋 먼저 vs phase 9 revision과 합쳐서?

## 11. 회귀 안전망

- 본 hot-fix는 시각 노드만 교체, 게임 로직(state/collision/direction/EventBus signal/score) 무변경.
- 헤드리스 테스트 Stage03 + BlockerOverlap 둘 다 PASS 확인.
- Phase 1~8 시뮬레이션 회귀는 다음 phase 진입 전 한 번 더 sweep 권장 (수동: Stage01/02/03 플레이).

---

## 부록 A — 산출 파일 트리

```
assets/sprites/characters/ant_pajama_girl/
├── AntFrames.tres                ← 신규 (SpriteFrames, 9 anim)
├── SPRITE_PLAN.md                ← 디자이너 가이드 (보존)
├── idle/idle_00..03.png          ← 4 frame
├── walk/walk_00..05.png          ← 6 frame
├── carry/carry_00..05.png        ← 6 frame
├── fall/fall_00..03.png          ← 4 frame
├── blocker/blocker_00..01.png    ← 2 frame
├── climb/climb_00..01.png        ← 2 frame
├── dig/dig_00..04.png            ← 5 frame
├── build/build_00..03.png        ← 4 frame
└── victory/victory_00..05.png    ← 6 frame

assets/sprites/candy/
├── CandyFrames.tres              ← 신규 (SpriteFrames, 1 anim 6 frame)
└── candy_00..05.png              ← 6 frame

scenes/entities/
├── Ant.tscn                      ← 수정 (Polygon2D → AnimatedSprite2D)
└── Candy.tscn                    ← 수정 (Polygon2D → AnimatedSprite2D)

scripts/ant/Ant.gd                ← 수정 (_update_sprite 추가)
scripts/world/Candy.gd            ← 수정 (_sprite 타입 + modulate)
```

## 부록 B — Phase 9 plan revision 영향 추정

| 항목 | 현재 (v3) | 예상 (v4) | 차이 |
|---|---|---|---|
| 산출 SVG | 27 | 12~13 | -14/-15 |
| SvgImportSmokeTest 검사 대상 | 27 | 12~13 | 동일 |
| svg_color_map.json class_map | 27 | ~10 추정 | sprite 전용 class 제거 |
| svg_color_map.json oklch_extras | 6 | 6 (stage_bg 전용) | 변동 없음 예상 |
| Phase 9 duration_estimate | 7200s | 5400s? (scope 축소) | -1800s |

duration_estimate는 plan 작성 시 실측치로 결정.
