---
name: ui-theme-assets
duration_estimate: 7200
verify: ""
---

# Phase 8: Theme + 폰트 + SVG 에셋 임포트

## 목표
디자인 토큰을 Godot Theme 리소스로 인코딩 + 폰트/SVG 에셋 임포트. **UI 씬 교체는 안 함** — 기존 placeholder UI에 Theme만 적용해 시각이 1차 적용되도록.

## 전제
- `docs/UI_GUIDE.md` (1차 SoT, §1·§2 토큰/Theme 매핑) + `docs/design_handoff/` (시각 레퍼런스)
- Phase 5~7(input layer) 완료 — 본 phase는 input과 무관해서 no-op 호환
- Stage01~03 placeholder UI는 노드 그대로, 시각만 바뀜

## 변경 대상

### 신규 파일
**Theme**:
- `theme/candyants.tres` — UI_GUIDE §2 인스펙터 값 그대로 박음

**폰트** (Google Fonts OFL 1.1):
- `assets/fonts/Jua-Regular.ttf`
- `assets/fonts/Gaegu-Bold.ttf`
- `assets/fonts/LICENSE.txt` — 두 폰트 OFL 원문 + 출처 URL

**SVG 에셋** — `docs/design_handoff/assets/`의 SVG들은 **두 가지 Godot 임포터 호환성 문제**를 가짐:
1. **`oklch(L C H)` 색 함수** — Godot 4 SVG 임포터 미지원. 토큰 외 값(예: `stage_bg.svg`의 `oklch(0.94 0.04 235)`, `oklch(0.78 0.10 80)` 등)도 등장.
2. **외부 정의 없는 `class="..."` 속성** — handoff `<defs><style>`가 비어있고 어디에도 `.k`/`.hood`/`.skin`/`.hair`/`.ribbon`/`.ink-fill`/`.frame`/`.canopy`/`.ground`/`.confetti` 등 클래스 CSS 정의 없음. 즉 핸드오프 SVG는 **디자이너 후속 작업 placeholder** 상태.

본 phase는 **정규화(normalize) 후 복사** 정책. 정규화 산출물이 production SoT, handoff 원본은 designer-source.

### 산출 도구

**`scripts/tools/svg_color_map.json`** — **plan revision 시 작성됨** (2026-05-09 enumerate 결과). phase 8은 본 파일을 normalize_svg.py 입력으로 사용. 디자이너 갱신 시 `--scan` 재실행 후 패치.

본 파일이 직접 매핑 SoT. phase 파일에는 **스키마 키만** 표기 (정확한 값 중복 박지 않음, drift 방지):

```jsonc
// scripts/tools/svg_color_map.json 의 최상위 섹션
{
  "_about":              { "purpose, scope, owner, tokens_ref, last_scan, resolve_order[] " },
  "oklch_extras":        { "<L C H>": "#hex", "...": "..." },     // 토큰 외 oklch만
  "alpha_variants":      { "<L C H> / <a>": "rgba(...)", "..." }, // 토큰 + alpha
  "class_map":           { "<className>": { "fill", "stroke", "stroke-*" }, "..." },
  "literal_color_map":   { "#tokenExternalHex": "#tokenHex", "..." },
  "allowed_literals":    { "values": ["#ffffff"] },
  "rgba_handling":       { "passthrough": true, "oklch_white_alpha_to_rgba": true },
  "color_attribute_scope": { "attributes": [...], "inline_style": true, "css_blocks": "inline-then-strip" },
  "sanity_invariants":   { "invariants": [...] }
}
```

**현재 데이터 카운트 (2026-05-09 enumerate, scripts/tools/svg_color_map.json 직접 참조)**:
- **27 class entries** in `class_map` (전수 enumerate)
- **6 non-token oklch** in `oklch_extras` (토큰 oklch 12개는 §1.1·§1.2 토큰 표에서 직접 resolve, 본 섹션 진입 금지 — sanity invariant)
- **2 token+alpha** in `alpha_variants` (`peach_500/0.18`, `ink_700/0.35`)
- **24 literal mappings** in `literal_color_map` + **1 allowed literal** (`#ffffff`)
- white-alpha oklch (`oklch(1 0 0 / a)`) 3종 → rgba_handling으로 직접 변환

**resolve_order (svg_color_map.json `_about.resolve_order`와 1:1)**:
1. UI_GUIDE §1.1·§1.2 token table (oklch 컬럼) → token hex
2. alpha_variants (token oklch + alpha) → rgba
3. oklch_extras (non-token only) → mapped hex
4. white-alpha shortcut: `oklch(1 0 0 / a)` → `rgba(255,255,255,a)`
5. CSS Color 4 spec 변환 (4단계 모두 미스 시) → exit 1 if gamut fail

**디자이너 갱신 시**:
```
python scripts/tools/normalize_svg.py --scan docs/design_handoff/assets/
```
출력에서 새 oklch/class/literal/rgba 발견 시 svg_color_map.json에 매핑 추가 후 재실행. **미매핑 잔여 시 normalize_svg.py exit 1 → phase 8 complete 차단** (CI 게이트).

**`scripts/tools/normalize_svg.py`** (phase 8 신규):
```
입력: docs/design_handoff/assets/**/*.svg
출력: assets/**/*.svg (동일 상대경로)

색 등장 위치 (모든 변환·enumerate·sanity 검사가 본 위치 전부 커버):
  - `fill="..."` / `stroke="..."` 속성
  - `stop-color="..."` (gradient stop)
  - `flood-color="..."` (filter flood)
  - `lighting-color="..."` (filter lighting)
  - `color="..."` (currentColor 의존 inherit)
  - 인라인 `style="fill:...; stroke:...; stop-color:..."` 등 CSS 선언
  - `<defs><style>` 블록 안 CSS 선언
  - SVG 1.1 ICC paint 변종은 미지원 (등장 시 exit 1, 디자이너 수정)

변환 단계 (위 모든 색 위치에 일괄 적용):
  1. oklch 값 처리 (resolve_order **고정**):
     - **(1) 토큰 표(UI_GUIDE §1.1·§1.2) 우선** 매칭 → 토큰 hex 사용. svg_color_map.json.oklch_extras 동시 매칭 시에도 토큰 표가 우선.
     - **(2) svg_color_map.json.alpha_variants** 매칭 시 (oklch에 / alpha) → 매핑된 rgba 사용
     - **(3) svg_color_map.json.oklch_extras** 매칭 시 → 그 hex 사용 (단 sanity invariant: 본 키가 토큰 oklch와 충돌 시 phase 8 complete 차단)
     - **(4) 셋 다 미매칭** → CSS Color 4 spec 기반 oklch → oklab → linear-sRGB → sRGB 변환 함수 (Python 내장 구현, lib 의존 X). 변환 실패(gamut out + clamp 후에도 NaN) 시 exit 1
     - **(5) white-alpha 특수**: `oklch(1 0 0 / a)` → `rgba(255,255,255,a)` 직접 변환 (rgba_handling.oklch_white_alpha_to_rgba=true)
  2. literal hex 처리:
     - svg_color_map.json.literal_color_map 매칭 시 → 매핑된 토큰 hex로 rewrite
     - svg_color_map.json.allowed_literals.values 포함 시 → 그대로 통과
     - 둘 다 미매칭 시 exit 1 (사용자에게 literal_color_map 또는 allowed_literals 보강 강제)
  3. rgba() 처리:
     - svg_color_map.json.rgba_handling.passthrough = true 시 그대로 통과
     - false 시 (현재 정책 X) literal과 동일 매핑 강제
  4. class 속성 처리:
     - svg_color_map.json.class_map[name] 매칭 시 → fill/stroke/stroke-* 인라인. class 속성 제거.
     - 미매칭 class 발견 시 exit 1 (svg_color_map.json 보강 강제).
  5. `<defs><style>` 블록 인라인 후 제거.
  6. 인라인 `style="..."`도 동일 규칙으로 변환 (style 속성에 `fill:oklch(...)` 등이 들어 있으면 oklch 처리 단계에 포함).
  7. 멱등 — 재실행 시 결과 동일 (assets/ 위에 다시 실행해도 변환 0).

플래그:
  --scan <dir>     : 입력에서 등장하는 oklch / class / literal hex / rgba 값 4종을 모든 색 위치(fill/stroke/stop-color/flood-color/lighting-color/color/style/<style>)에서 enumerate (변환 X)
  --check          : assets/ 출력이 멱등인지 검사 (CI용)
  --strict         : 미매핑 잔여 0건 강제 (default)
```

### 산출 SVG (정규화 결과, production SoT)
- `assets/logo/{wordmark,icon,mascot}.svg` (3)
- `assets/icons/skills/{climber,floater,bomber,blocker,builder,basher,miner,digger}.svg` (8)
- `assets/sprites/{ant,ant_carrying,ant_climber,ant_floater,ant_bomber,ant_blocker,ant_builder,ant_basher,ant_miner,ant_digger,ant_faller,ant_dead,ant_saved,candy,home}.svg` (15)
- `assets/illustrations/stage_bg.svg` (1)
- `assets/icons/skills/_README.md` — 출처 + 라이센스 + placeholder 표기 + 정규화 절차 참조

### SVG 임포트 smoke test (필수, phase 8 complete 차단 조건)
- 신규 `tests/SvgImportSmokeTest.gd` — 27 production SVG에 대해:
  1. `load(path)` 성공 + `Texture2D.get_size()` > 0
  2. `get_image()` 비-blank 픽셀 비율 ≥ 5%
  3. **잔여 검사 (전 위치)**: 각 파일 텍스트에서 `oklch(`, `class="`, `<style` 0건
  4. **컬러 sanity (전 위치)**: 정규화된 SVG의 모든 색 등장 위치(`fill`, `stroke`, `stop-color`, `flood-color`, `lighting-color`, `color`, 인라인 `style="..."` 안의 모든 `*-color` 선언)에서 등장하는 hex 값이 (UI_GUIDE 토큰 표 hex ∪ svg_color_map.json.oklch_extras 값 ∪ svg_color_map.json.literal_color_map values ∪ svg_color_map.json.allowed_literals.values) 부분집합. 그 외 hex 등장 시 fail. rgba()는 통과(rgba_handling.passthrough=true).
  5. **토큰 oklch 중복 sanity** (svg_color_map.json.sanity_invariants[0]): `oklch_extras` 키 중 어느 하나라도 UI_GUIDE §1.1·§1.2 토큰 oklch와 일치하면 fail. 즉 토큰 oklch는 토큰 표에서만 resolve, extras에서 의도적/실수로 다른 hex로 덮어쓰는 것을 차단.
  6. 디자이너 갱신 시 매핑 표(svg_color_map.json) 동시 갱신 의무화 — 본 검사가 강제 게이트. fill/stroke 외 stop-color에 새 literal이 들어와도 동일 게이트가 막음.
- 한 파일이라도 실패 시 phase 8 complete 차단.

**참고 — 토큰 oklch와 svg_color_map.json**:
- handoff SVG에 등장하는 **22 oklch** 중:
  - **12개는 §1.1·§1.2 토큰** (peach_500=0.78 0.155 28, berry_500=0.70 0.20 15, lemon_500=0.88 0.16 95, lemon_300=0.95 0.10 95 등) — `oklch_extras`에 **있으면 안 됨** (sanity invariant 1번)
  - **6개는 진짜 토큰 외** (stage_bg illustration용 sky/grass 변종) — `oklch_extras`에 매핑됨
  - **3개는 white-alpha** (`oklch(1 0 0 / a)`, a=0.35/0.4/0.5) — rgba_handling으로 처리
  - **1개는 토큰+alpha** (peach_500/0.18, ink_700/0.35) — `alpha_variants`로 처리

### 수정
- `project.godot` — `gui/theme/custom = "res://theme/candyants.tres"` (default theme 등록), Korean locale 확인
- 임포트 설정 — 모든 SVG에 UI_GUIDE §2.5 값 적용 (mipmap on, antialias on, scale 1.0, lossless)

### 비-변경 (중요)
- `scenes/ui/HUD.tscn`, `SkillToolbar.tscn` — 본 phase 미수정 (phase 10에서 교체)
- `scripts/ui/*.gd` — 본 phase 미수정
- 기존 Ant/Candy/Home 시각 — sprite swap은 phase 10/11에서 (본 phase는 에셋 임포트만)

## 검증 방법

### 자동 (헤드리스)
1. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS
2. `python scripts/run_test.py tests/BlockerOverlapTest.tscn` PASS
3. `python scripts/run_test.py tests/SvgImportSmokeTest.gd` 신규 — 27 SVG 모두 비-blank 텍스처 PASS. **phase 8 complete 강제 조건**.
4. `python scripts/tools/normalize_svg.py --check` — 정규화 결과가 멱등인지 (재실행 시 차이 없음) 검증.
5. (모든 회귀 시나리오 — Theme 적용 후 0 회귀)

### 수동 (에디터)
1. Theme 인스펙터 열기 — Button×4 state, Panel, Label, LineEdit, SpinBox 모두 등록되었는지 확인
2. 빈 씬에 Button + Label + Panel 두고 Theme이 자동 적용되는지 (override 없이) 확인
3. 모든 SVG가 인스펙터 미리보기에 정상 표시되고 `.import` 파일이 생성됨
4. 폰트가 Korean glyph 모두 렌더 (사탕/잠시/등반 등 시험 문자열)
5. Stage01 실행 → 기존 HUD label들이 Jua 20px ink_900으로 자동 변경됨 (텍스트 내용은 그대로)
6. handoff `preview/buttons.html` 브라우저 캡처 vs Godot Theme inspector preview — 컬러 hex 일치

## 엣지 케이스 (필수)

- **그림자 hard-edge** — `StyleBoxFlat.shadow_*`는 항상 blur. **본 phase는 shadow_* 사용 금지**, sticker shadow는 phase 9 atoms에서 duplicate StyleBoxFlat 자식 노드로 구현. Theme에는 그림자 정의 0.
- **oklch → sRGB 재계산 금지** — UI_GUIDE §1.1·§1.2의 hex 그대로 사용. 재변환 X.
- **폰트 라이센스 누락** — `assets/fonts/LICENSE.txt` 미포함 시 phase 빌드 거부. CI 시 파일 존재 검사 추가 (스크립트 1줄).
- **Theme override 충돌** — 본 phase 후 어떤 노드도 `theme_override_*` 사용 금지. atom 노드도 Theme의 `theme_type_variation` 으로만 분기.
- **SVG anti-alias 누락** — flags/filter=true 강제. 끄면 cream/ink 외곽선이 깨짐.
- **SVG `oklch()` / class 잔여** — 정규화 스크립트가 모든 production SVG에서 `oklch(`와 ` class="`를 0건으로 만들어야 함. CI 검사: `grep -RE "oklch\(|class=\"" assets/*.svg assets/**/*.svg` → exit 1이면 phase 8 차단.
- **Korean glyph 누락** — Jua/Gaegu가 일부 한자/특수문자 미지원 시 fallback 폰트 미정의 → Theme `default_font_fallbacks` 비워두고 누락 시 `[?]`로 표시되는 것 허용 (post-MVP에서 보강).
- **Color enum 단일 SoT** — `scripts/ui/Tokens.gd` 신설하여 UI_GUIDE §1.3 `COUNTER_COLOR` 디셔너리를 코드로 박음. 카운터 atom (phase 9)이 본 enum 사용. Theme inspector 컬러와 코드 컬러 hex 1:1 검증 절차 추가.

## 산출물 요약

```
theme/candyants.tres                  ← 컬러/폰트/StyleBoxFlat × 5 + Panel + Label
scripts/ui/Tokens.gd                  ← COUNTER_COLOR enum + Color() 상수 (코드 SoT)
scripts/tools/normalize_svg.py        ← oklch/literal/class/rgba 변환 (멱등) — 본 phase 신규
scripts/tools/svg_color_map.json      ← 매핑 SoT (plan revision에서 enumerate 후 작성됨)
assets/fonts/                         ← Jua + Gaegu + LICENSE.txt
assets/logo/ icons/skills/ sprites/ illustrations/   ← 27 SVG (정규화 결과)
project.godot                         ← gui/theme/custom 등록
tests/SvgImportSmokeTest.gd           ← 27 SVG 비-blank + color sanity (전 위치)
```

## Phase 9~11과의 호환성

- **Phase 9 (atoms)**: 본 phase의 Theme + Tokens.gd가 모든 atom의 기반. atoms는 Theme를 상속만, override X.
- **Phase 10 (HUD/Toolbar)**: 본 phase 후에도 placeholder HUD에 Theme만 적용된 상태로 동작. 회귀 0.
- **Phase 11 (StageDialog)**: Panel StyleBoxFlat 그대로 사용.

## Substitution flag 처리
- Jua/Gaegu가 팀 최종 픽이 아닐 시 `theme/candyants.tres`의 `default_font` 한 줄만 교체. 모든 노드 자동 반영.
- 폰트 교체 시 `assets/fonts/LICENSE.txt`도 동시 갱신.

## 표준 절차
phase 시작 시 plan 작성 → `/codex:adversarial-review` → 구현 → 헤드리스+수동 검증 → impl review → complete. 상세는 `phases/mvp/README.md`. 명세 SoT는 `docs/UI_GUIDE.md`.
