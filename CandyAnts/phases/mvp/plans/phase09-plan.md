# Phase 9 Plan v8: Theme + 폰트 + SVG 정규화 (13 SVG)

> **v7 → v8 차이 (impl round 2 doc sync)**: codex impl review round 2가 HIGH 2건 모두 doc-sync 잔재로 판정. v7에서 헤더 표는 갱신했으나 본문 의사코드/검증 섹션이 v6 잔재. v8에서 5종→4종 + 2 alpha_variants → 1로 본문도 동기화.
> - R2-H1 alpha resolve order doc drift: 본 plan 본문 §"resolve_order" + smoke test pseudocode 갱신.
> - R2-H2 phase 문서 + plan 본문 잔재: 본 plan smoke test pseudocode가 5종 import key + 2 alpha_variants 리스트하던 것을 4종 + 1로 동기화. `params/flags/filter` / `params/flags/mipmaps` 제거.
> - R2-M1 CLASS_RE scan over-match: `--scan` / `--scan-handoff-all`이 XML 파싱으로 class 속성 enumerate (raw regex는 parse fail 시 폴백).
> - R2-M2 style block strip risk: phase 9는 class-only style 정책 명시, 향후 element/id selector 도입 시 strict-fail로 전환 (deferred).
> - R2-M3 dead-entry policy 확장성: --audit-dead-map 도구는 post-MVP sweep로 deferred. 본 phase는 alpha_variants invariant[4]만 자동, 다른 섹션은 수동 리뷰.
> - R2-L1 SpinBox composition note: UI_GUIDE §2.4 한 줄 추가 완료.
>
> **v6 → v7 차이 (impl 단계 디스커버리)**: codex impl review round 1에서 plan-impl drift 4건 발견. 본 v7은 impl 단계 정정 사항을 plan에도 반영해 cross-doc 일관성 복구.
> - SR1-H1 / impl-H1: `normalize_svg.py` resolve_oklch가 alpha-bearing oklch에 대해 alpha_variants 미스 시 token hex로 폴백 → 투명도 손실. 수정: 토큰 oklch + alpha + alpha_variants 미매핑 시 exit 1.
> - impl-H2: UI_GUIDE §2.5 `flags/filter=true`는 Godot 4 .import 키가 아님. §2.5를 Godot 4.6 실제 키 4종(`svg/scale`, `compress/mode`, `process/fix_alpha_border`, `mipmaps/generate`)으로 갱신. filter는 ProjectSettings default Linear 의존 명시.
> - impl-H3: Theme `SpinBox/styles/normal`은 Godot 4 무효 아이템 (SpinBox는 LineEdit를 internal field로 composition). Theme에서 제거, LineEdit Theme이 자동 적용됨을 코멘트로 명시.
> - impl-H4: svg_color_map.json `alpha_variants.ink_700/0.35` 제거는 plan v6 "mapping values 무변경" 약속과 충돌. v7에서 본 변경을 **명시적 impl-stage 정정**으로 인정: Phase 9 v4 sprite drop 후 본 매핑이 production에서 미사용(dead) → sanity_invariants[4] 강제. plan v7부터 "mapping values는 dead entry 제거 외 무변경"로 명확화.
>
> **v5 → v6 차이**: codex plan review round 5 (HIGH 2 + MEDIUM 2 + LOW 1) 반영.
> - R5-H1: 수동 검증 6번에서 `SKY_300/GRASS_300 ↔ stage_bg.svg 색 사용` 불가능 요건 제거. illustration 전용 토큰은 3-way 검증 비대상 명시. stage_bg 색 정합은 smoke test가 이미 자동 검증.
> - R5-H2: `docs/UI_GUIDE.md` phase 번호 일괄 갱신 — Phase 8(theme-assets) → Phase 9, Phase 9(atoms) → Phase 10. `### 1.3`, `### 2`, `### 2.6`, `### 3`, `### 4` 헤더 등 8군데.
> - R5-M1: UI_GUIDE 본문의 "phase 8" 잔재(§2.6 본문 안) 함께 갱신.
> - R5-L1: 본 plan에서 "svg_color_map.json 무변경" → "mapping values 무변경, `_about` 메타만 갱신"으로 명확화.
>
> **v4 → v5 차이**: codex plan review round 4 (HIGH 2 + MEDIUM 5 + LOW 1) 반영.
> - R4-H1: illust-token 자동 강제 게이트 제거 (handoff stage_bg.svg는 token 자체가 아닌 oklch_extras 변종 사용 — 게이트가 항상 fail하는 dead test였음). SKY_300/GRASS_300은 documented constants로 유지(codex R3 LOW 인정 dead constants).
> - R4-H2: `docs/UI_GUIDE.md` §2.6 디자이너 갱신 절차를 Option A scope(`--scan-handoff-all` + 5장 normalize)로 동기화.
> - R4-L1: `scripts/tools/svg_color_map.json` `_about.owner` "phase 8" → "phase 9 (normalizer + smoke gate owner)" 갱신.
> - R4-M4/M5는 명시된 trade-off로 유지, R4-M3은 impl 단계 처리.
>
> **v3 → v4 차이**: codex plan review round 3 (HIGH 4 + MEDIUM 3) 반영.
> - HIGH#1: SVG import setting 검증을 실제 `.import` 키 확인 기반으로 닫음 (※ 검증 시점에 5종으로 표기됐으나 v8에서 4종으로 정정 — 본 행은 historical record).
> - HIGH#2: `phase09-ui-theme-assets.md`도 Option A(5장 정규화 + skill icons 8장 검증)로 동기화.
> - HIGH#3: `normalize_svg.py --scan-handoff-all` 게이트 추가로 invariant[3] handoff class mapping 누락 검출.
> - HIGH#4: `SKY_300`/`GRASS_300`은 illustration 전용으로 Theme inspector 3-way 검증에서 제외.
> - MED#1~3: float 표기 drift 문구 정정, skill icon freshness trade-off 명시, alpha resolve-path는 normalize 단위 검증으로 이동.
>
> **v2 → v3 차이**: codex plan review round 2 (HIGH 5) 반영.
> - HIGH#1: oklch 매칭 `round()` 제거, exact float tuple 비교 (또는 unrounded 문자열 정규화).
> - HIGH#2: normalize_svg.py 스코프 단일 정의 (5장 명시, **Option A** — 기존 skill icons 8장은 비대상).
> - HIGH#3: SvgImportSmokeTest 게이트 문구 정정 ("4 invariant 검증 + 1 normalize_svg.py 책임").
> - HIGH#4: `Tokens.gd`에 `SKY_300`, `GRASS_300` 추가.
> - HIGH#5: `phase09-ui-theme-assets.md`에서 atom override 정책 구절 제거 (phase 10으로 위임).

## 목표

UI 시각 1차 적용. Godot Theme 리소스에 `docs/UI_GUIDE.md` §1·§2 토큰을 인코딩하고, Korean 폰트(Jua/Gaegu) 임포트, handoff SVG 5장(logo 3 + home 1 + stage_bg 1)을 정규화해 `assets/`에 배치. 기존 정규화 완료 skill icons 8장은 SvgImportSmokeTest 검증 범위에만 포함(재정규화 없음).

UI 씬 교체는 안 함 — phase 10/11 범위. **본 phase는 Theme + 에셋 임포트 + Motion 헬퍼 + 테스트만**. 회귀 0건이 목표.

## 운영 모델 전제 (UI_GUIDE §0.5 인용)

- **1인 개발** + **AI 생성·외부 수급 자산** 운영 모델.
- `docs/design_handoff/` 패키지의 SVG·preview HTML은 placeholder, 시각 비교 강제력 X.
- 색 매칭: 현재 phase 9가 정규화할 handoff SVG 5장은 토큰 oklch는 §1.1·§1.2 토큰 표로, 토큰 외 oklch는 `svg_color_map.json` 명시적 매핑(`oklch_extras`/`alpha_variants`/`literal_color_map`/`allowed_literals`)으로 resolve — 모두 **strict 1:1 lookup** (tolerance 도입 X). AI 생성·외부 수급 자산이 새 토큰 외 색을 도입하는 시점에 별도 phase에서 `svg_color_map.json` + UI_GUIDE §1을 함께 revision.
- 시각 회귀: UI_GUIDE §8 v2 (1인 개발 기준). Stage01 default 해상도 1회 캡처 + Theme inspector hex 토큰 일치 확인이 강제, handoff preview 비교는 보조.

## 리뷰 반영 요약 (codex round 1·2)

| Finding | 처리 |
|---|---|
| R1#1 oklch tolerance | tolerance 폐기 → R2#1에서 round() 잔재 발견 → v3에서 round() 완전 제거 |
| R1#2 alpha_variants invariant | smoke test에 alpha_variants 사용 검증 추가 |
| R1#3 atom override freeze | plan에서 제거 → R2#5에서 phase 문서 잔재 발견 → v3에서 phase09-ui-theme-assets.md 동기화 완료 |
| R1#4 시각 회귀 scope | UI_GUIDE §8 v2 1인 개발 기준 인용 |
| R1 MED#1 import settings | 5종 전수 검증 (※ v8에서 Godot 4.6 실제 4종으로 정정, `flags/filter`는 .import key 부재) |
| R1 MED#2 _README 문구 | "phase 9 normalize 책임 X, 재현 가능" 명확화 |
| R1 LOW typo | "toekn" → "token" |
| R2#1 round() 잔재 | exact float tuple 비교로 교체 (본 v3) |
| R2#2 정규화 스코프 충돌 | **Option A** 채택, 5장 명시 단일 정의 |
| R2#3 sanity gate 과장 | "4 invariant 검증 + 1 normalize_svg.py 책임" 정정 |
| R2#4 Tokens.gd 토큰 누락 | SKY_300, GRASS_300 추가 |
| R2#5 atom 정책 잔재 | phase09-ui-theme-assets.md 갱신 완료 |
| R2 MED#1 alpha resolve-path | output presence만으로는 부족 → v4에서 normalize_svg.py `--self-test` 단위 검증으로 분리 |
| R2 MED#2 단일 리뷰어 갭 | 운영 모델 §0.5에 명시된 의도적 trade-off — handoff preview shape/layout drift는 본 phase 비검출 허용 (acknowledged risk) |
| R3#1 import settings 5종 | Godot 4.6 `.import` 실제 키 확인 결과: 4종(`svg/scale`, `compress/mode`, `process/fix_alpha_border`, `mipmaps/generate`). v8에서 4종 자동 검증으로 정정 — 5종 주장은 obsolete (`flags/filter`는 Godot 4 `.import` key 부재). |
| R3#2 phase 문서 스코프 충돌 | `phase09-ui-theme-assets.md`를 Option A로 동기화 |
| R3#3 invariant[3] ungated | `--scan-handoff-all` 추가, handoff 전체 미매핑 class/literal/oklch/rgba 발견 시 fail |
| R3#4 illustration token 3-way 불가 | Theme inspector 3-way는 Theme/atom 토큰만, `SKY_300`/`GRASS_300`은 Tokens/UI_GUIDE/SVG 산출물 기준 |
| R3 MED#1 float 표기 drift | `0.78`과 `0.780`은 같은 Python float임을 명시, drift 위험은 문자열 감사가 아니라 미매핑/매핑 보강으로 처리 |
| R3 MED#2 skill icons freshness | Option A 의도적 trade-off로 명시, 본 phase는 기존 8장 sanity만 보장 |
| R3 MED#3 alpha resolve-path | `--self-test`에서 alpha_variants input→rgba output 경로를 직접 검증 |

## SoT 참조

- `docs/UI_GUIDE.md` §0.5(운영 모델), §1.1·§1.2(토큰), §1.3(카운터 색), §1.4(폰트), §1.5·§1.6·§1.7, §2(Theme), §2.4(SpinBox composition), §2.5 v2(임포트 4종), §2.6(resolve_order conditional), §4(Motion), §8 v2(시각 회귀) — **1차 SoT**.
- `phases/mvp/PRE_PHASE9_SPRITE_STATE.md` §6 — mixed-canon 정책.
- `phases/mvp/phase09-ui-theme-assets.md` v4 (atom override 구절 제거 동기화 완료).
- `scripts/tools/svg_color_map.json` — 매핑 SoT. v7부터 정책: dead entry 제거(예: v4 sprite drop 후 production 미사용 alpha_variants 키)는 sanity_invariants[4] 강제 차원에서 정공법 처리, 그 외 mapping values는 무변경. `_about.owner`/`_about` 메타도 phase 9 ownership으로 갱신.
- `docs/PRD.md` / `docs/ARCHITECTURE.md` / `docs/ADR.md` — 시뮬레이션 무관.

## 비-범위

1. HUD/Toolbar/StageDialog 씬 교체 — phase 10/11.
2. Atom 신설 (CButton·Chip·Counter·SkillSlot 등) — phase 10. Motion.gd만 본 phase 신설.
3. **Atom override 정책 결정** — phase 10 plan 범위. 본 plan은 phase 10에 정책 freeze를 부과하지 않음.
4. Ant/Candy sprite swap — commit `6d3edc0` 완료.
5. handoff sprite SVG 정규화 — v4 drop.
6. 별점/SaveData/카피 가이드 — phase 11~12.
7. 시각 회귀 다중 해상도 — polishing phase로 deferral.
8. AI 생성·외부 자산 도입 시 매핑 갱신 — 본 plan 외, 도입 시점 별도 revision.
9. 기존 skill icons 8장 재정규화 — 본 phase 비대상 (Option A). 향후 디자이너 갱신 시 별도 처리.

## 변경 파일

### 신규 `scripts/tools/normalize_svg.py` (의사코드, Option A 스코프)

```python
"""
normalize_svg.py — handoff SVG 5장 정규화 → assets/

스코프 (Option A, 단일 정의):
  입력 = 다음 5개 파일만 (하드코딩 list, glob X):
    docs/design_handoff/assets/logo/wordmark.svg
    docs/design_handoff/assets/logo/icon.svg
    docs/design_handoff/assets/logo/mascot.svg
    docs/design_handoff/assets/sprites/home.svg
    docs/design_handoff/assets/illustrations/stage_bg.svg
  출력 = assets/<상대경로>.svg (5장)
  기존 assets/icons/skills/*.svg 8장은 본 스크립트 비대상 — phase 8 시점 manual 산출물 그대로 유지.

resolve_order (svg_color_map.json _about.resolve_order, strict 1:1, alpha 유무 조건 분기 — v8 정정):
  (0) white-alpha shortcut: oklch(1 0 0 / a) → rgba(255,255,255,a)
  (1) alpha 있음 + (L,C,H) ∈ TOKENS → alpha_variants 엔트리 필수 (미스 → exit 1, token-hex 폴백 금지 — 투명도 손실 방지)
  (1') alpha 있음 + (L,C,H) ∉ TOKENS → alpha_variants 우선, 미스 시 CSS Color 4 변환 (rgba 출력)
  (2) alpha 없음 + (L,C,H) ∈ TOKENS → token hex
  (3) alpha 없음 + (L,C,H) ∉ TOKENS + oklch_extras 매칭 → 매핑 hex
  (4) 셋 다 미스 → CSS Color 4 spec 변환, gamut fail 시 exit 1

oklch 매칭 = exact float tuple 비교 (round() 도입 X):
  - 파서가 oklch(L C H) 또는 oklch(L C H / a) 추출
  - L/C/H는 raw float으로 보존 (Python float, double precision)
  - TOKENS dict의 key도 동일 raw float
  - 비교 = `(parsed_L, parsed_C, parsed_H) in TOKENS` (Python dict exact lookup)
  - handoff SVG의 oklch 수치가 Python float tuple로 토큰 표와 동일해야 매칭 성공 (예: "0.78 0.155 28"과 "0.780 0.1550 28.0"은 같은 tuple)
  - 수치가 토큰 tuple과 다르면 → svg_color_map.json.oklch_extras 또는 alpha_variants에 디자이너가 보낸 값을 매핑 추가 (drift 처리는 매핑으로, 코드 tolerance로 X)

색 위치 (전 위치 일괄 처리):
  속성: fill, stroke, stop-color, flood-color, lighting-color, color
  인라인 style="...": fill / stroke / *-color 선언
  <defs><style> 블록 안 CSS 선언 (인라인 후 블록 제거)

처리 순서 (한 파일에 대해):
  1. xml.etree.ElementTree로 파싱. register_namespace('', 'http://www.w3.org/2000/svg').
  2. <defs><style> 블록 CSS 파싱 → class별 fill/stroke/* 추출 (svg_color_map.json.class_map의 fallback).
  3. 트리 순회:
     a. class="X" → class_map[X] 매칭 시 fill/stroke/stroke-* 속성 인라인 + class 속성 제거.
        'stop' 클래스는 _skip_inline=true (gradient marker).
        미매칭 class 발견 시 exit 1 (svg_color_map.json 보강 강제).
     b. fill/stroke/stop-color/flood-color/lighting-color/color 속성 → resolve_order 적용.
     c. style="..." 속성 → CSS 선언 파싱 → 각 *-color 선언 resolve_order 적용 → 재구성.
  4. <defs><style> 블록 제거.
  5. literal hex 처리: literal_color_map[원본] → 매핑 hex. allowed_literals.values 통과. 둘 다 미매칭 → exit 1.
  6. rgba() 처리: rgba_handling.passthrough=true 통과.
  7. 출력: assets/<상대경로>.svg (디렉토리 자동 생성, formatting은 ET.tostring default).

TOKENS = {
    # (L, C, H) raw float → hex (sRGB). UI_GUIDE §1.1·§1.2와 동기.
    (0.985, 0.012,  75): "#FBF8F1",  # cream_50
    (0.965, 0.020,  70): "#F5EFE3",  # cream_100
    (0.93,  0.030,  70): "#E9DFCB",  # cream_200
    (0.88,  0.040,  65): "#D9C9AC",  # cream_300
    (0.26,  0.045,  50): "#3A2A1C",  # ink_900
    (0.40,  0.060,  50): "#5C4530",  # ink_700
    (0.58,  0.045,  55): "#8C7660",  # ink_500
    (0.90,  0.08,   35): "#FAD9C4",  # peach_300
    (0.78,  0.155,  28): "#F2A48F",  # peach_500
    (0.62,  0.165,  30): "#D17A60",  # peach_700
    (0.92,  0.07,  175): "#D4F0E5",  # mint_300
    (0.82,  0.13,  175): "#9ED9C2",  # mint_500
    (0.60,  0.13,  175): "#5EA88A",  # mint_700
    (0.86,  0.10,   10): "#F7C9C4",  # berry_300
    (0.70,  0.20,   15): "#E48579",  # berry_500
    (0.55,  0.20,   15): "#B85546",  # berry_700
    (0.95,  0.10,   95): "#FCEFC2",  # lemon_300
    (0.88,  0.16,   95): "#F0D77B",  # lemon_500
    (0.72,  0.16,   90): "#C9A93C",  # lemon_700
    (0.88,  0.07,  300): "#DCCEE2",  # grape_300
    (0.72,  0.14,  300): "#B49AC5",  # grape_500
    (0.55,  0.14,  300): "#7E5A9A",  # grape_700
    (0.92,  0.05,  235): "#CCDFEA",  # sky_300
    (0.88,  0.07,  140): "#B0DCB4",  # grass_300
}

# oklch 추출 정규식: r'oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)(?:\s*/\s*([\d.]+))?\s*\)'
# 매칭 시 (float(L), float(C), float(H))를 TOKENS dict에 lookup → hex.
# alpha 분리: "/ a" 부분 있으면 alpha_variants key "<L> <C> <H> / <a>" 형태로 svg_color_map에 lookup.

CLI:
  python scripts/tools/normalize_svg.py                    # 5장 정규화 실행
  python scripts/tools/normalize_svg.py --scan             # 5장 enumerate (no write, 새 unmapped 발견 시 stdout)
  python scripts/tools/normalize_svg.py --scan-handoff-all # docs/design_handoff/assets/**/*.svg 전체 enumerate + mapping coverage gate
  python scripts/tools/normalize_svg.py --check            # 5장 멱등 검증 (output == 기존 assets/<해당경로>)
  python scripts/tools/normalize_svg.py --self-test        # resolve_order 단위 검증(alpha_variants 포함)
  python scripts/tools/normalize_svg.py --strict           # default true

--scan-handoff-all gate:
  - 변환/출력은 하지 않고 handoff 전체 SVG에서 class/literal/oklch/rgba를 enumerate.
  - class_map/literal_color_map/allowed_literals/alpha_variants/oklch_extras/UI_GUIDE token table/white-alpha shortcut 중 어디에도 매칭되지 않는 값이 있으면 exit 1.
  - Option A에서도 production 출력은 5장만 만들지만, handoff 전체 mapping coverage를 확인해 sanity_invariants[3] 공백을 닫는다.

--self-test:
  - svg_color_map.json.alpha_variants의 각 key를 resolve_order alpha-present branch (alpha_variants 매칭)에 직접 통과시켜 expected rgba와 일치하는지 검증.
  - token oklch와 oklch_extras 중복 금지, white-alpha shortcut, allowed literal passthrough를 단위 입력으로 검증.

Exit codes: 0 success / 1 unmapped/gamut fail / 2 malformed input
```

**Python 외부 의존성 0건** — `xml.etree.ElementTree` + `re` + `json` + `math`.

### 신규 `theme/candyants.tres`

UI_GUIDE §2 인스펙터 값. (v2와 동일)

- default: font Jua-Regular 20, color `#3A2A1C`
- Button 4 state StyleBoxFlat (normal `#F2A48F` / pressed `#D17A60` / disabled `#C8B5A6` / hover = normal). border 3 `#3A2A1C`, radius 16, content_margin (h=22, v=10).
- Panel: bg `#F5EFE3`, border 3, radius 24.
- LineEdit/SpinBox/CheckButton: border 3, radius 8~12, bg `#F5EFE3`.
- Label: color `#3A2A1C`.
- shadow_* 미사용.

### 신규 `scripts/ui/Tokens.gd` (HIGH#4 반영 — SKY_300, GRASS_300 포함)

```gdscript
class_name Tokens
extends RefCounted

# Cream / Ink (UI_GUIDE §1.1)
const CREAM_50  := Color("#FBF8F1")
const CREAM_100 := Color("#F5EFE3")
const CREAM_200 := Color("#E9DFCB")
const CREAM_300 := Color("#D9C9AC")
const INK_900   := Color("#3A2A1C")
const INK_700   := Color("#5C4530")
const INK_500   := Color("#8C7660")

# Brand / Semantic (UI_GUIDE §1.2)
const PEACH_300 := Color("#FAD9C4")
const PEACH_500 := Color("#F2A48F")
const PEACH_700 := Color("#D17A60")
const MINT_300  := Color("#D4F0E5")
const MINT_500  := Color("#9ED9C2")
const MINT_700  := Color("#5EA88A")
const BERRY_300 := Color("#F7C9C4")
const BERRY_500 := Color("#E48579")
const BERRY_700 := Color("#B85546")
const LEMON_300 := Color("#FCEFC2")
const LEMON_500 := Color("#F0D77B")
const LEMON_700 := Color("#C9A93C")
const GRAPE_300 := Color("#DCCEE2")
const GRAPE_500 := Color("#B49AC5")
const GRAPE_700 := Color("#7E5A9A")

# Illustration 전용 documented constants (UI_GUIDE §1.2).
# Theme/atom 코드 분기 비사용. Theme inspector 3-way 검증 대상 아님.
# 현 handoff stage_bg.svg는 본 토큰이 아닌 oklch_extras 변종(#A9CFA5/#D6E5F0 등)을 사용 —
# 본 상수들은 SoT 완전성(UI_GUIDE §1.2 mirror)을 위해 유지하는 documented constants이며,
# 현 phase에서 코드 사용처 없음. 향후 일러스트가 토큰 자체를 직접 쓰면 stage_bg.svg 정규화
# 출력에 자연스럽게 등장 (별도 게이트 불필요).
const SKY_300   := Color("#CCDFEA")
const GRASS_300 := Color("#B0DCB4")

# Counter kind (UI_GUIDE §1.3) — phase 10 atom용
enum CounterKind { CANDY_HP, IN_TRANSIT, SAVED, LOST, TIME }

const COUNTER_COLOR := {
    CounterKind.CANDY_HP   : PEACH_500,
    CounterKind.IN_TRANSIT : GRAPE_500,
    CounterKind.SAVED      : MINT_500,
    CounterKind.LOST       : BERRY_500,
    CounterKind.TIME       : LEMON_700,
}
```

**Freeze**: 상수 이름·값은 phase 9 완료 시 freeze. 추가 = sweep commit.

### 신규 `scripts/ui/Motion.gd`

UI_GUIDE §4 본문 5개 시그니처. (v2와 동일)

```gdscript
class_name Motion
extends RefCounted

static func caPop(node: CanvasItem) -> Tween
static func boop(node: Control) -> Tween
static func idle_bob(node: CanvasItem, amplitude: float = 1.03, period: float = 1.6) -> Tween
static func fade_in(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween
static func fade_out(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween
```

**Freeze**.

### 신규 `assets/fonts/` (3 파일)

- `Jua-Regular.ttf` — Google Fonts, OFL 1.1
- `Gaegu-Bold.ttf` — Google Fonts, OFL 1.1
- `LICENSE.txt` — OFL 원문 × 2 + 출처 URL + 다운로드 일자

`scripts/tools/check_font_license.py`로 CI 게이트.

### 신규 `assets/{logo,sprites/home,illustrations/stage_bg}.svg` (정규화 산출 5장)

normalize_svg.py 산출.

### 신규 `assets/icons/skills/_README.md` (MEDIUM#2)

```
# Skill Icons

Source: docs/design_handoff/assets/icons/skills/ (designer-authored placeholders).
Origin: 2026-05-09 phase 8 plan revision 시 manual normalize 산출 (디자이너/사용자 처리).
본 phase(9)는 본 디렉토리 normalize 책임 없음 — normalize_svg.py가 동일 매핑
(svg_color_map.json)으로 재현 가능하지만, byte-identical 보장 없으므로 phase 8 산출물 그대로 유지.
SvgImportSmokeTest 검사 범위에는 포함 (8장 sanity 검증).

향후 갱신 시 (디자이너 후속):
1. docs/design_handoff/assets/icons/skills/<name>.svg 갱신
2. (옵션) python scripts/tools/normalize_svg.py로 재현 가능하게 만들고 싶다면 normalize_svg.py
   입력 file list에 추가 — 현재 본 스크립트는 5장(logo×3 + home + stage_bg)만 처리 (Option A).
3. tests/SvgImportSmokeTest.gd PASS 확인.

License: 프로젝트 내부 placeholder. 디자이너 최종 픽 후 동일 파일명으로 교체.

8 files: basher, blocker, bomber, builder, climber, digger, floater, miner (각 .svg).
```

### 수정 `project.godot`

```ini
[gui]
theme/custom = "res://theme/candyants.tres"

[internationalization]
locale/preferred=PackedStringArray("ko")
locale/test=""
```

기존 섹션 충돌 검사, 신규 키만 추가.

### 신규 `tests/SvgImportSmokeTest.gd` (HIGH#3 반영 — 게이트 문구 정정)

13 SVG 전수 + svg_color_map.json `sanity_invariants` 중 본 테스트가 검증하는 4개:

- invariant[0] — `oklch_extras` 키 ↔ token oklch 중복 X (token oklch가 extras에 등장하면 fail)
- invariant[1] — 모든 색 hex가 allowed_hex 합집합 부분집합
- invariant[2] — production SVG에 `oklch(`/`class="`/`<style` 0건
- invariant[4] — `alpha_variants` 각 키가 정규화 산출 SVG 텍스트에서 `rgba(...)` 형태로 1회 이상 등장

invariant[3] (handoff class에 매핑 entry 존재)은 **normalize_svg.py --scan-handoff-all 책임** — 본 테스트 비검증. 자동 검증 목록에서 별도 gate로 실행한다.

```gdscript
extends Node

const PRODUCTION_SVGS := [
    "res://assets/logo/wordmark.svg", "res://assets/logo/icon.svg", "res://assets/logo/mascot.svg",
    "res://assets/icons/skills/basher.svg", "res://assets/icons/skills/blocker.svg",
    "res://assets/icons/skills/bomber.svg", "res://assets/icons/skills/builder.svg",
    "res://assets/icons/skills/climber.svg", "res://assets/icons/skills/digger.svg",
    "res://assets/icons/skills/floater.svg", "res://assets/icons/skills/miner.svg",
    "res://assets/sprites/home.svg", "res://assets/illustrations/stage_bg.svg",
]

# 임포트 설정 Godot 4.6 실제 4종 (UI_GUIDE §2.5 v2 — v8 정정):
# `flags/filter`는 Godot 4 .import key 부재. ProjectSettings/canvas_textures/default_texture_filter
# (기본 Linear) 또는 CanvasItem.texture_filter override로 제어. 본 phase는 default Linear 의존.
const REQUIRED_IMPORT_KEYS := {
    "params/svg/scale": 1.0,
    "params/compress/mode": 0,
    "params/process/fix_alpha_border": true,
    "params/mipmaps/generate": true,  # Godot 3 `flags/mipmaps` 후신
}

func _ready() -> void:
    var failures: Array[String] = []
    var color_map: Dictionary = _load_color_map()
    var allowed_hex: Dictionary = _build_allowed_hex_set(color_map)
    var alpha_variants_rgba: Array = _alpha_variants_target_rgba(color_map)
    var alpha_hit: Dictionary = {}
    for r in alpha_variants_rgba: alpha_hit[r] = false

    for path in PRODUCTION_SVGS:
        # (1) load + size
        var tex: Texture2D = load(path)
        if tex == null or tex.get_size().x == 0:
            failures.append("[load] " + path); continue

        # (2) 비-blank ≥ 5%
        var img: Image = tex.get_image()
        var non_blank := 0; var total := img.get_width() * img.get_height()
        for y in img.get_height():
            for x in img.get_width():
                if img.get_pixel(x, y).a > 0.01: non_blank += 1
        if float(non_blank) / float(total) < 0.05:
            failures.append("[blank] " + path); continue

        var text: String = FileAccess.get_file_as_string(path)

        # (3) invariant[2] — 잔여
        if text.contains("oklch("): failures.append("[oklch] " + path)
        if text.contains("class=\""): failures.append("[class] " + path)
        if text.contains("<style"): failures.append("[style] " + path)

        # (4) invariant[1] — hex 부분집합
        for hex in _extract_hex_from_color_attrs(text):
            if not allowed_hex.has(hex.to_lower()):
                failures.append("[hex] " + path + " hex=" + hex)

        # (5) invariant[4] — alpha_variants 사용 누적
        for r in alpha_variants_rgba:
            if text.contains(r): alpha_hit[r] = true

        # (6) 임포트 설정 (MEDIUM#1)
        _check_import_settings(path, failures)

    # (7) invariant[0] — oklch_extras 토큰 중복
    for key in color_map.get("oklch_extras", {}).keys():
        if key.begins_with("_"): continue
        if key in _ui_guide_token_oklch_strings():
            failures.append("[sanity-0] oklch_extras has token oklch: " + key)

    # (8) invariant[4] — 미사용 alpha_variants 키
    for r in alpha_hit.keys():
        if not alpha_hit[r]:
            failures.append("[sanity-4] alpha_variants unused: " + r)
    # 주: SKY_300/GRASS_300 사용 강제 게이트는 의도적으로 두지 않음.
    # 현 handoff stage_bg.svg는 token sky_300/grass_300이 아닌 oklch_extras 변종
    # (#A9CFA5, #D6E5F0 등)을 사용. 게이트를 추가하면 dead test가 됨. SKY_300/GRASS_300은
    # documented constants (UI_GUIDE §1.2 illustration tier) — codex R3 LOW 인정한 dead constant.

    if failures.size() > 0:
        push_error("SvgImportSmokeTest FAIL — " + str(failures.size()) + ":\n" + "\n".join(failures))
        get_tree().quit(1)
    else:
        print("[SvgImportSmokeTest] PASS — 13 SVG verified, 4 sanity invariants checked")
        print("  (invariant[3] handoff class mapping — normalize_svg.py --scan-handoff-all gate)")
        get_tree().quit(0)

func _check_import_settings(path: String, failures: Array) -> void:
    # UI_GUIDE §2.5 v2 — Godot 4.6 실제 4종: svg/scale=1.0, compress/mode=0, process/fix_alpha_border=true, mipmaps/generate=true
    var import_path: String = path + ".import"
    var cfg := ConfigFile.new()
    if cfg.load(import_path) != OK:
        failures.append("[import-missing] " + import_path); return
    for key in REQUIRED_IMPORT_KEYS.keys():
        var parts := key.split("/", true, 1)
        var section := parts[0]
        var entry := parts[1]
        var actual = cfg.get_value(section, entry, null)
        if actual != REQUIRED_IMPORT_KEYS[key]:
            failures.append("[import] " + path + " " + key + " expected=" + str(REQUIRED_IMPORT_KEYS[key]) + " got=" + str(actual))
```

### 신규 `tests/MotionPauseSafeTest.gd`

UI_GUIDE §4 pause_safe 검증 (v2와 동일).

### 신규 `tests/{SvgImportSmokeTest,MotionPauseSafeTest}.tscn`

Scene wrapper.

### 신규 `scripts/tools/check_font_license.py` (~20줄)

(v2와 동일)

## 변경하지 않는 파일

- `scenes/ui/HUD.tscn`, `SkillToolbar.tscn` — phase 10.
- `scripts/ui/*.gd` (기존) — phase 10.
- `scenes/entities/Ant.tscn`, `Candy.tscn` — commit `6d3edc0`.
- `scripts/ant/*.gd`, `scripts/world/*.gd` — 시뮬레이션 무변경.
- `scripts/tools/svg_color_map.json` — 매핑 SoT. v7부터 정책: dead entry 제거(예: v4 sprite drop 후 production 미사용 alpha_variants 키)는 sanity_invariants[4] 강제 차원에서 정공법 처리, 그 외 mapping values는 무변경. `_about.owner`/`_about` 메타도 phase 9 ownership으로 갱신.
- `docs/design_handoff/assets/*.svg` — designer-source, 무변경.
- `assets/icons/skills/*.svg` (8장) — phase 8 manual 산출, 무변경 (Option A).

## 검증

### 자동 (헤드리스)

**모든 자동 검증 PASS는 phase 9 complete의 전제 조건** — 한 건이라도 fail 시 `python scripts/execute.py mvp complete 9` 차단.

1. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` — Theme 적용 후 0 회귀 PASS.
2. `python scripts/run_test.py tests/BlockerOverlapTest.tscn` — PASS.
3. `python scripts/run_test.py tests/SvgImportSmokeTest.tscn` — 13 SVG + 4 sanity invariants + 임포트 4종 키 검증 PASS.
4. `python scripts/run_test.py tests/MotionPauseSafeTest.tscn` — pause_safe PASS.
5. `python scripts/tools/normalize_svg.py --check` — 5장 멱등 PASS.
6. `python scripts/tools/normalize_svg.py --scan-handoff-all` — handoff 전체 mapping coverage PASS (invariant[3] gate, exit 1 시 차단).
7. `python scripts/tools/normalize_svg.py --self-test` — resolve_order + alpha_variants 직접 검증 PASS.
8. `python scripts/tools/check_font_license.py` — LICENSE.txt PASS.
9. phase 5~8 기존 테스트 전수 PASS — 회귀 0.

### 임포트 설정 검증 (MEDIUM#1, UI_GUIDE §2.5)

자동 — SvgImportSmokeTest의 `_check_import_settings()` 헬퍼가 Godot 4.6 `.import` 실제 4종 키 (svg/scale, compress/mode, process/fix_alpha_border, mipmaps/generate)를 모두 검증. `flags/filter`는 .import key 부재 — ProjectSettings default Linear 의존 (v8 명시).

### 수동 (UI_GUIDE §8 v2 1인 개발 강제 항목)

1. Theme 인스펙터 — Button×4 state, Panel, Label, LineEdit, SpinBox 등록.
2. 빈 씬에 Button + Label + Panel — Theme 자동 적용.
3. SVG 인스펙터 미리보기 + `.import` 파일 생성.
4. 폰트 Korean glyph 렌더 ("사탕/잠시/등반/낙하산").
5. Stage01 default 해상도 실행 — placeholder UI 가독성/layout OK.
6. **Theme/atom 토큰 3-way SoT 일치** — Theme inspector hex ↔ `scripts/ui/Tokens.gd` 상수 ↔ UI_GUIDE §1.1·§1.2 표. **단 illustration 전용 `SKY_300`/`GRASS_300`은 본 3-way 검증 비대상** (Theme 비노출, 현재 stage_bg.svg 미사용). stage_bg.svg 색 정합성은 SvgImportSmokeTest의 (4) color hex 합집합 + (3) `oklch(` 잔여 0건이 이미 자동 검증.

### 시각 회귀 보조 (UI_GUIDE §8 v2 보조, 강제 X)

- handoff preview HTML vs Godot Theme inspector preview — 자산 출처가 handoff인 경우만 의미.
- 다중 해상도 — polishing phase로 deferral.

## 엣지 케이스

- **그림자 hard-edge**: shadow_* 절대 사용 안 함.
- **oklch → sRGB 재계산 금지**: UI_GUIDE §1.1·§1.2 hex 그대로.
- **폰트 LICENSE 누락**: check_font_license.py exit 1 → complete 차단.
- **Atom override 정책**: 본 plan 비-범위 (phase 10 결정).
- **SVG 잔여 (oklch / class / style)**: SvgImportSmokeTest 0건 강제.
- **alpha_variants 미사용**: smoke test sanity-4 강제.
- **alpha_variants resolve-path**: `normalize_svg.py --self-test`가 alpha_variants input oklch+alpha → expected rgba 변환 경로를 직접 검증.
- **oklch 표기 drift**: normalize_svg.py가 exact tuple lookup, 미매칭 시 exit 1 (tolerance X). drift 발견 시 svg_color_map.json 보강.
- **Korean glyph 누락**: `[?]` 허용 (post-MVP 보강).
- **stage_bg 비-token oklch**: oklch_extras 6개 step 3에서 매핑.
- **Theme 적용 시각 회귀**: 자동(시뮬레이션) + 수동(시각) 분리 검증.
- **project.godot 충돌**: 기존 키 보존, 신규만 추가.
- **normalize_svg.py 멱등 깨짐**: `--check` fail → complete 차단. xml 출력 비결정성 방지 위해 sorted attribute order + 일관된 indentation.
- **xml.etree namespace 손실**: `ET.register_namespace('', 'http://www.w3.org/2000/svg')` 명시.
- **skill icons handoff freshness / preview shape drift**: Option A와 운영 모델 §0.5의 의도된 trade-off. 본 phase는 기존 skill icons 8장의 load/color/import sanity와 handoff 전체 mapping coverage만 보장하고, 디자이너 원본과의 freshness/shape 동일성은 보장하지 않음.
- **AI 생성·외부 자산 도입**: 본 plan 외, 도입 시 별도 revision phase.

## 산출물 요약

```
theme/candyants.tres                  ← 신규
scripts/ui/Tokens.gd                  ← 신규 (SKY_300/GRASS_300 포함, freeze)
scripts/ui/Motion.gd                  ← 신규 (5 함수, freeze)
scripts/tools/normalize_svg.py        ← 신규 (5장 정규화, strict 1:1, exact float tuple)
scripts/tools/check_font_license.py   ← 신규 (CI 게이트)
assets/fonts/Jua-Regular.ttf          ← 신규
assets/fonts/Gaegu-Bold.ttf           ← 신규
assets/fonts/LICENSE.txt              ← 신규 (OFL × 2)
assets/logo/wordmark.svg              ← 신규 (정규화)
assets/logo/icon.svg                  ← 신규
assets/logo/mascot.svg                ← 신규
assets/sprites/home.svg               ← 신규
assets/illustrations/stage_bg.svg     ← 신규
assets/icons/skills/_README.md        ← 신규 (출처 + Option A 명시)
project.godot                         ← 수정
tests/SvgImportSmokeTest.gd + .tscn   ← 신규 (13 SVG + 4 invariants + 임포트 4종)
tests/MotionPauseSafeTest.gd + .tscn  ← 신규
```

총 신규 ~19, 수정 1.

## Phase 9 → Phase 10/11 호환성

- **Motion.gd 시그니처 freeze** — phase 10/11 호출.
- **Tokens.gd 상수 freeze** — phase 10/11/12 참조 SoT.
- **Theme 인스펙터 값 freeze** — phase 10/11/12 노드가 변경하지 않음.
- **Atom override 정책** — phase 10 plan이 결정 (본 phase 미관여).
- **SVG 13장 freeze** — phase 10 skill icons + phase 11 logo/home/stage_bg 사용.

## Phase 9 plan stage 정책 (CLAUDE.md 준수)

- 본 plan v6은 codex round 6에서 **clean verdict** 획득 (HIGH 0건).
- 잔존 MEDIUM 2건 + LOW 1건은 phase 9 blocker 아님. R6-M1(svg_color_map invariant comment)은 v6에서 정정 완료. R6-M2(UI_GUIDE phase 10/12 사용 표기 vs §0.5 범위 — atoms 외 stage-dialog/title 등 +1 shift 잔재)는 phase 10 진입 전 sweep 처리. R6-L1(plan footer "v4/round 4" 표기)은 v6에서 정정 완료.

## 표준 절차

phase 시작 → plan v1 (round 1 HIGH 4) → plan v2 (round 2 HIGH 5) → plan v3 (round 3 HIGH 4) → plan v4 (round 4 HIGH 2, illust-token dead test 발견) → plan v5 (round 5 HIGH 2, UI_GUIDE phase 번호 drift 발견) → plan v6 (round 6 **clean**) → 구현 → 헤드리스 + 수동 검증 → self-review → codex impl review → clean까지 반복 → complete.
