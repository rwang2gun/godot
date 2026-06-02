# CandyAnts — 필요 리소스 / 에셋 제작 목록

작성: 2026-06-02 · 분류 기준: **파일 존재 여부가 아니라 실제 픽셀을 직접 열어 본 품질**.

## 0. 검증 방법 & 주의

- 각 항목은 실제 이미지를 렌더해 **손그림 완성품 vs 절차생성/스텁 placeholder**로 분류했다 (파일명 추정 아님).
- **생성기 출처**: `scripts/tools/`의 Python 스크립트가 만드는 에셋은 placeholder 강력 후보다
  (`generate_skill_png_icons.py`, `generate_hazard_plant_sprites.py`, `generate_polished_terrain.py` 등).
- ⚠️ **움직이는 타깃**: 병렬 아트/레벨 파이프라인이 세션 중에도 에셋을 생성한다(예: stun 스프라이트가
  2026-06-02 15:35 PNG → 15:41 import로 대화 도중 완성됨). 이 문서는 **그 시점 스냅샷**이며, 재확인 시
  실제 디스크 상태(`*.png` 존재 + `.godot/imported/*.ctex`)를 우선한다 — `LEVEL_REDESIGN_STATUS.md`의
  `[ ]/[x]` 체크박스보다 디스크가 SoT.

---

## A. Placeholder로 때워진 것 — 존재하지만 조잡 (교체 대상)

실제 이미지를 열어 확인한 결과:

> **정정 (2026-06-02)**: `home.svg`는 **게임 미사용**(orphan)으로 확인됐다 — 실사용 집(Home) 스프라이트는
> `ant_hole.png`다(`scenes/entities/Home.tscn`이 직접 참조). `home.svg`는 §A 하단 orphan 표로 이동. `DOMAIN_MAP.md:19`가
> Home에 home.svg를 잘못 적은 stale 상태(별도 정정 필요).

| 에셋 | 현재 상태 | 출처 | 가시성 | 증거 |
|---|---|---|---|---|
| **`assets/sprites/spawners/ant_hole.png`** (= **집/Home 목적지** 스프라이트) | 단순 주황 타원 구멍, 무질감 | 절차생성 | ⭐ 매우 높음(전 스테이지 배달 목표) | `Home.tscn`이 유일 참조·이걸 Sprite로 사용. 경로는 `spawners/`지만 **실제 용도는 집**. 별도 Spawner 씬 없음 |
| **`assets/sprites/terrain/soda_water.png`** (물 즉사 해저드) | 밋밋한 하늘색 + 거품 점 | `generate_hazard_plant_sprites.py` | 높음 | 평면 그라데이션, 무질감 |
| **`assets/sprites/terrain/peppermint_plant.png`** (cutter 대상) | 거친 빨강/초록 바람개비 | 절차생성 | 중간 | "자를 덩굴"로 안 읽힘 |
| **`assets/sprites/terrain/cookie_stair_tile.png`** (builder 대각 계단) | 계단식 박스, **대각으로 안 읽힘** | 절차/러프 | 중간 | A4 우려 확정 — builder 대각 상승화와 시각 불일치 |

> **디자인 미결**: 집(Home 목표)을 **구멍(ant_hole)으로 둘지, 캔디 집으로 만들지** 결정 필요. `home.svg`(미사용)는
> 과거 "집(언덕+문)" 시안이었고 stage_bg엔 painterly 초콜릿 버섯집이 있다 → 집을 별도 비주얼로 갈 여지. 현재는 스폰 구멍과
> 동일 비주얼이라 "출발지 vs 도착지" 구분이 약하다.

### 절차생성 — 기능은 하나 손그림 아님 (⏸ 보류, 2026-06-02 결정)

| 에셋 | 비고 |
|---|---|
| **스킬 아이콘 10종** `assets/icons/skills/*.png` + **커서 10종** `assets/icons/skills/cursors/*.png` | `generate_skill_png_icons.py` — 캔디 뱃지(원형 그라데이션) + 캐릭터 스프라이트 크롭 + 도형 소품 합성. 일부(climber 등)는 꽤 읽힘. **⏸ 보류** — 절차생성이지만 기능·가독 충분으로 판단, 이번 라운드 교체 대상에서 제외 |

### Orphan 의심 — 미사용 placeholder (정리 후보, 교체 아님)

| 에셋 | 비고 |
|---|---|
| **`assets/sprites/home.svg`** | ❗ **게임 미사용 확인** — 유일 참조는 `tests/SvgImportSmokeTest.gd`(import 검증용). `Home.tscn`은 `ant_hole.png` 사용. 도형 스텁이라, 집 신규 아트로 가면 삭제 후보 |
| `assets/illustrations/stage_bg.svg` | 실사용은 `stage_bg_painted.png`(TitleScene/MainMenu/StageSelect). svg 미참조 의심 |
| `assets/logo/mascot.svg`, `assets/logo/wordmark.svg` | 실사용은 `mascot_premium.png`/`logo_wordmark_premium.png`(LogoPanel). svg 구버전 의심 |
| `assets/icons/ui/*.svg` (arrow/close/lock/pause/play/settings/unlock), `sticky_timer_bar.svg` | 벡터 UI 크롬은 보통 이대로 OK → 교체 불필요, 폴리시만 선택 |

> orphan 여부는 커밋 전 `grep -r <파일명> scenes/ data/ project.godot`로 참조 0 확인 후 정리.

---

## B. 아예 없어서 신규 생성 필요

| 에셋 | 사유 / 근거 |
|---|---|
| **earth(파괴 가능) vs 쿠키(불괴) 구분 타일** | 현재 단일 cookie_crust 룩 → digger/basher 대상을 플레이어가 시각 구분 못함. 재설계 B3 |
| **digger 수직 단면 / 측벽 타일** | basher는 root/top reskin 있으나 digger는 단면 텍스처 없음. `TERRAIN_TILE_RULES.md §9-3·§12.3` |
| (선택) `saved` 행복 점프 애니 (2~4프레임) | `SPRITE_PLAN.md` 계획, 미제작 — `victory` 애니로 대체 가능 |
| (선택) per-world 테마 타일세트 / 배경 | 9스테이지 비주얼 다양성 원할 때. 테마당 surface×4 + solid×4. 절차는 `TERRAIN_TILE_RULES.md §7` |

---

## C. 완성품 — 건드리지 말 것 ✅

- **캐릭터 전 애니** `assets/sprites/characters/ant_pajama_girl/` — idle/walk/carry/fall/blocker/climb/dig/build/victory/**stun**
  (stun은 아트+import 완료. 남은 건 코드: `StunnedState` 신설 + `stun` 애니 재생 연결, 아트 아님)
- **candy** `candy_00~05.png` — 손그림 보석 캔디
- **2-tier 지형 타일** `usable_square/cookie_surface_square_01~04.png` · `cookie_solid_rotatable_square_01~04.png` — painterly
- **배경** `stage_bg_painted.png` · `stage_bg_far.png`
- **로고** `mascot_premium.png` · `logo_wordmark_premium.png`
- (양호) `sticky_caramel.png`, `biscuit_ladder_*_square.png`, `basher_*_square.png` — 기능·가독 OK, 폴리시는 선택

---

## D. 우선순위

| 순위 | 항목 | 종류 | 근거 |
|---|---|---|---|
| **1** | `ant_hole.png`(= **집/Home 목표**) 손그림 교체 | placeholder 교체 | 전 스테이지 배달 목표 + 도형 수준이라 가장 튐. (집을 구멍/캔디집 중 무엇으로 갈지 디자인 결정 선행) |
| **2** | `soda_water` / `peppermint_plant` | placeholder 교체 | 핵심 해저드·cutter 대상이 밋밋 |
| **3** | `cookie_stair_tile` 재제작 | placeholder 교체 | builder 대각화 시각 정합 (A4) |
| **4** | earth vs 쿠키 구분 타일 | 신규 | 파괴 스킬 가독성 (B3) |
| 5 | digger 단면 / `saved` 애니 / 테마 확장 / orphan svg(`home.svg`·`stage_bg.svg`·로고 svg) 정리 | 선택 | 폴리시·미래 |
| ⏸ | 스킬 아이콘/커서 손그림화 | **보류** | 절차생성도 기능 충분 — 2026-06-02 보류 결정 |

---

## E. 결정 / 미결 질문

- ✅ **스킬 아이콘 10종(절차생성)** — **보류 결정** (2026-06-02). 기능·가독 충분으로 판단, 이번 라운드 교체 대상 제외. 향후 폴리시 패스 때 재검토.
- ❓ 우선순위 1~3 항목의 **발주 사양서**(스타일·크기·`TERRAIN_TILE_RULES.md §7` 정합 조건) 작성 여부.

## 참고 문서
- `docs/TERRAIN_TILE_RULES.md` — 타일 발주 규약(§7 체크리스트)
- `docs/LEVEL_REDESIGN_STATUS.md` — A/B/C/D 작업 트랙(체크박스는 디스크보다 후행할 수 있음)
- `assets/sprites/characters/ant_pajama_girl/SPRITE_PLAN.md` — 캐릭터 애니 계획
- `scripts/tools/` — 절차생성 스크립트(placeholder 출처 식별용)
