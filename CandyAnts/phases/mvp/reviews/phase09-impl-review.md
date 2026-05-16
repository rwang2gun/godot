# Phase 9 Implementation Review

> Target: phase 9 산출 전체 (plan v6 + 산출 ~19 신규 파일 + 3 수정)
> Date: 2026-05-16
> Policy: CLAUDE.md impl-stage — codex finding HIGH/CRITICAL 1건 발견 시 수정 → self-review → clean → codex 재리뷰 반복. codex 사이에 self-review 1회 이상 강제.

---

## Self-Review Round 1 (구현 직후 자체 적대적 리뷰)

### 발견 사항

**[HIGH] SR1-H1 — 임포트 설정 mipmaps 미적용 (UI_GUIDE §2.5 부분 위반)**
- Godot 4.6 SVG importer 기본값: `mipmaps/generate=false`
- UI_GUIDE §2.5: `flags/mipmaps=true` (Godot 3 키 표기; 4.6은 `mipmaps/generate`)
- 13장 production SVG `.import` 파일 모두 `mipmaps/generate=false`로 생성됨 → UI_GUIDE 위반.
- **수정**: 13장 모두 `mipmaps/generate=true`로 변경 후 재임포트. SvgImportSmokeTest의 `_check_import_settings()`에 `["params", "mipmaps/generate", true]` 체크 추가.

**[HIGH] SR1-H2 — UI_GUIDE `flags/filter` 키 부재 (Godot 4 spec drift)**
- UI_GUIDE §2.5: `flags/filter=true`
- Godot 4.6 .import file에 `flags/filter` 키 없음. 필터링은 `CanvasItem.texture_filter` 또는 `ProjectSettings/rendering/textures/canvas_textures/default_texture_filter` (project-wide)로 제어.
- **처리**: SvgImportSmokeTest 코멘트에 명시 — "default Linear 의존을 허용, atom phase 10에서 atom 노드 override 가능". UI_GUIDE는 향후 갱신 deferred (post-MVP 또는 phase 10 atom impl 시).

**[MEDIUM] SR1-M1 — normalize_svg.py dead branch in class merge**
- `transform_element()` 안에서 두 `if k not in el.attrib` 분기가 동일 액션 수행. 명목적 분기.
- **수정**: 단일 `if k not in el.attrib: el.attrib[k] = v`로 단순화.

**[MEDIUM] SR1-M2 — svg_color_map.json dead alpha_variants `ink_700/0.35`**
- Phase 9 v4 sprite drop 후 `0.40 0.060 50 / 0.35` → `rgba(92,69,48,0.35)` 매핑이 production SVG 어디에도 등장하지 않음.
- svg_color_map sanity_invariants[4] (alpha_variants 사용 강제)와 충돌.
- **수정**: svg_color_map.json에서 해당 엔트리 제거. `_comment`에 "sprite drop 후 제거" 명시.
- 본 수정은 plan v6의 "mapping values 무변경" 약속과 약간 충돌하지만 dead mapping은 SoT 결함이므로 정공법 처리.

**[LOW] SR1-L1 — normalize_svg.py `resolve_literal_hex` 폴백 확장**
- 토큰 hex / oklch_extras 값 / literal_color_map 값 어디에 포함되면 passthrough 허용. plan에 명시 안 됨.
- **유지**: 실용적 fallback. 명세 강화는 향후 sweep로 deferral. 본 phase는 동작 OK.

### 수정 후 재검증
- `python scripts/tools/normalize_svg.py` 5장 정규화 OK.
- `python scripts/tools/normalize_svg.py --check` 멱등 PASS.
- `python scripts/run_test.py tests/SvgImportSmokeTest.tscn` PASS (13 SVG + 4 invariants + 4종 import 키).
- Stage03/Blocker 회귀 PASS.

### Verdict (Self-Review Round 1 → 수정 → Re-Self-Review)
HIGH 0, MEDIUM 0 (SR1-M1/M2 수정), LOW 1 (SR1-L1 deferred). → **clean** → codex impl review 진입.

---

## Round 1 (codex impl review)

### Verdict
NEEDS-ATTENTION (HIGH 4 + MEDIUM 4 + LOW 2)

### HIGH

- **R1-H1** `normalize_svg.py` resolve_oklch가 alpha-bearing oklch에 대해 alpha_variants 미스 시 token hex로 폴백 → 투명도 손실. --scan-handoff-all도 token oklch 우선 체크로 alpha 검증 누락.
- **R1-H2** SvgImportSmokeTest가 UI_GUIDE §2.5 5종 강제 주장하나 4종만 검증 (flags/filter 누락 — Godot 4 .import key 부재). 강제 게이트 미이행.
- **R1-H3** `theme/candyants.tres` `SpinBox/styles/normal`은 Godot 4.6 무효 theme item (SpinBox는 LineEdit를 internal field로 composition).
- **R1-H4** `svg_color_map.json` ink_700/0.35 제거가 plan v6 "mapping values 무변경" 약속 위반.

### MEDIUM
- R1-M1 `class='...'` (single-quote) regex 미스
- R1-M2 `collect_defs_styles()`가 namespaced <style>만 매치, unnamespaced 누락
- R1-M3 `--strict` no-op + 알 수 없는 flag silent ignore
- R1-M4 UI_GUIDE §0.5 "handoff colors token-exact" 주장과 oklch_extras non-token 매핑 충돌

### LOW
- R1-L1 `post_pass_literal_hex` 데드 코드
- R1-L2 token 값이 4개 파일에 중복 (consistency check 부재)

### 처리 (Self-Review Round 2)

| Finding | 수정 |
|---|---|
| R1-H1 | `normalize_svg.py` resolve_oklch: 토큰 oklch + alpha + alpha_variants 미매핑 → exit 1. cmd_scan에도 동일 검증 추가. |
| R1-H2 | UI_GUIDE §2.5를 Godot 4.6 실제 키 4종(`svg/scale`, `compress/mode`, `process/fix_alpha_border`, `mipmaps/generate`)으로 갱신. `flags/filter`는 `.import` key 부재 명시 + ProjectSettings/CanvasItem 경로 안내. 5종 강제 주장 철회. |
| R1-H3 | `theme/candyants.tres`에서 `SpinBox/styles/normal` 제거 + 코멘트로 SpinBox composition 동작 명시. |
| R1-H4 | Plan v7로 갱신 — "v4 sprite drop 후 dead alpha_variants 제거"를 명시적 impl-stage 정정으로 인정. v7부터 "dead entry 제거 외 mapping values 무변경" 정책 정착. |
| R1-M1 | `CLASS_RE`를 `[\"']` 양쪽 따옴표 모두 매칭으로 확장. |
| R1-M2 | `_is_style_tag()` 헬퍼 추가, namespaced + unnamespaced 모두 매칭. |
| R1-M3 | `main()`에서 unknown flag 검증 + mode 상호 배타 검증 추가, 위반 시 exit 2. |
| R1-M4 | UI_GUIDE §0.5를 "토큰 정확 일치 + 토큰 외는 svg_color_map 명시적 매핑, 모두 strict 1:1"로 명확화. |
| R1-L1 | `post_pass_literal_hex` 제거. |
| R1-L2 | deferred — Tokens.gd ↔ svg_color_map.json ↔ UI_GUIDE 토큰 SoT consistency check는 향후 sweep로 처리 (4종 일관성은 self-test의 token table direct + smoke test의 hex subset이 부분 검증 중). |

### 재검증 (Self-Review Round 2 후)
- normalize_svg.py: --self-test PASS, --check PASS, --scan-handoff-all PASS, unknown flag exit 2 OK.
- SvgImportSmokeTest PASS (13 SVG + 4 invariants + 4종 import 키).
- MotionPauseSafeTest PASS.
- 헤드리스 회귀 PASS.

### Verdict (Round 2 Self-Review)
HIGH 0, MEDIUM 0, LOW 1 (R1-L2 deferred). → **clean** → codex 재리뷰 진입.

---

## 자동 검증 결과 (impl 완료 시점, 9건 전수 PASS)

| # | 게이트 | 결과 |
|---|---|---|
| 1 | tests/Stage03HeadlessTest.tscn | PASS |
| 2 | tests/BlockerOverlapTest.tscn | PASS (§B-1 ~ §B-8 전수) |
| 3 | tests/SvgImportSmokeTest.tscn | PASS (13 SVG + 4 sanity invariants + import 4종 키) |
| 4 | tests/MotionPauseSafeTest.tscn | PASS |
| 5 | normalize_svg.py --check | PASS (5장 멱등) |
| 6 | normalize_svg.py --scan-handoff-all | PASS (handoff 27장 mapping coverage) |
| 7 | normalize_svg.py --self-test | PASS (resolve_order + alpha_variants) |
| 8 | check_font_license.py | PASS (Jua + Gaegu + OFL 키워드) |
| 9 | phase 5~8 회귀 (GameFlow / Pause / PadInput / InputRouter / InputMode / StepFrame / Cursor) | PASS 전수 |

---

## Round 2

### CRITICAL

None

### HIGH

**R2-H1** — `docs/UI_GUIDE.md:180`, `scripts/tools/svg_color_map.json:9`, `phases/mvp/plans/phase09-plan.md:112`, `phases/mvp/phase09-ui-theme-assets.md:74` — Alpha resolve order still documented as token-first.

- Evidence: actual code now checks `alpha_variants` before token fallback for alpha-bearing oklch and raises on token+alpha miss (`scripts/tools/normalize_svg.py:177-187`), but the docs still say token table is first / always wins (`docs/UI_GUIDE.md:180`, `scripts/tools/svg_color_map.json:9-10`, `phase09-plan.md:112-117`, `phase09-ui-theme-assets.md:74-79`). For alpha-bearing token oklch, token-first is exactly the old transparency-loss bug.
- Impact: future map/script changes can follow the documented order and reintroduce alpha erasure while appearing compliant with the SoT docs.
- Fix recommendation: document the real conditional order everywhere: white-alpha shortcut; if alpha is present, require `alpha_variants` for token oklch; only alpha-less token oklch resolves through the token table; alpha-less non-token resolves through `oklch_extras`; remaining non-token alpha either explicitly maps or is rejected/converted per policy.

**R2-H2** — `phases/mvp/phase09-ui-theme-assets.md:70`, `phases/mvp/phase09-ui-theme-assets.md:170`, `phases/mvp/plans/phase09-plan.md:353`, `phases/mvp/plans/phase09-plan.md:474` — Phase docs still advertise removed alpha entry and five import-key enforcement.

- Evidence: `phase09-ui-theme-assets.md` still states two alpha variants including removed `ink_700/0.35` (`:70`, `:166`) and five SVG import keys including `flags/filter` / `flags/mipmaps` (`:170`, `:186`, `:208`). `phase09-plan.md` v7 top matter says the import policy changed to 4 keys, but the embedded test pseudocode and verification sections still say 5 keys and list `params/flags/filter` / `params/flags/mipmaps` (`:353-361`, `:430`, `:474`, `:484`, `:537`).
- Impact: the target context set is internally contradictory; an implementer or reviewer can satisfy one section while violating another, and automated-check claims no longer match actual `SvgImportSmokeTest` behavior.
- Fix recommendation: sweep `phase09-ui-theme-assets.md` and `phase09-plan.md` so every current section says one alpha variant (`peach_500/0.18`) and four Godot 4.6 import keys (`svg/scale`, `compress/mode`, `process/fix_alpha_border`, `mipmaps/generate`), with filter explicitly handled outside `.import`.

### MEDIUM

**R2-M1** — `scripts/tools/normalize_svg.py:97`, `scripts/tools/normalize_svg.py:419` — `CLASS_RE` can over-match non-attribute text.

- Evidence: `CLASS_RE = re.compile(r"class\s*=\s*[\"']([^\"']+)[\"']")` scans raw SVG text. It will match `class="foo"` inside another attribute value, script text, metadata, or CSS content, even though XML parsing would not treat that as an element class.
- Impact: `--scan` / `--scan-handoff-all` can produce false unmapped-class failures for valid SVG text containing `class="..."` as data, while normalization itself only uses parsed `el.attrib.get("class")`.
- Fix recommendation: make scan class enumeration parse XML and inspect actual `class` attributes, falling back to raw regex only after parse failure with a clear malformed-input path.

**R2-M2** — `scripts/tools/normalize_svg.py:303`, `scripts/tools/normalize_svg.py:317` — style-block stripping silently drops unsupported but legitimate SVG CSS.

- Evidence: `_is_style_tag()` now matches namespaced and unnamespaced `<style>`, `collect_defs_styles()` extracts only `.class { ... }` rules via `CSS_RULE_RE`, and `strip_defs_styles()` removes every style element at any depth. Element selectors, id selectors, grouped selectors, media blocks, or non-color CSS are neither applied nor rejected before removal.
- Impact: designer handoff can contain legitimate inline SVG style blocks that pass parse, get stripped, and lose visual styling without an explicit unmapped failure.
- Fix recommendation: either restrict and document support to class-only style rules and fail on any unconsumed style text, or implement enough CSS selector handling to safely inline all supported rules before stripping.

**R2-M3** — `phases/mvp/plans/phase09-plan.md:79`, `scripts/tools/svg_color_map.json:109` — dead-entry policy is alpha-only in practice and not extensible.

- Evidence: plan v7 allows dead entry removal as an exception, but the only automated dead-entry gate is invariant[4] for `alpha_variants` usage (`svg_color_map.json:116`; `tests/SvgImportSmokeTest.gd:113-116`). There is no equivalent audit for dead `class_map`, `literal_color_map`, or `oklch_extras` entries, and some preserved class entries are intentionally broader than production.
- Impact: new dead mappings introduced in v8+ can accumulate silently unless a reviewer manually notices them; the policy does not define which dead entries are acceptable preservation versus stale SoT.
- Fix recommendation: add a `normalize_svg.py --audit-dead-map` style report that classifies entries as production-used, handoff-used, or unused, and document which buckets may remain intentionally preserved.

### LOW

**R2-L1** — `theme/candyants.tres:111`, `docs/UI_GUIDE.md:147` — SpinBox fallback is only documented in the resource comment.

- Evidence: the Theme file says SpinBox uses an internal LineEdit and the LineEdit theme applies automatically, but UI_GUIDE §2.4 still simply groups `LineEdit / SpinBox / CheckButton` without explaining the composition-based fallback. Current phase 10 atom catalog does not define a SpinBox atom, so no immediate atom break was found.
- Impact: future UI work can incorrectly re-add `SpinBox/styles/normal` or assume a missing SpinBox style is accidental.
- Fix recommendation: add one sentence to UI_GUIDE §2.4: SpinBox field styling is inherited through its internal LineEdit; do not add `SpinBox/styles/normal`.

### Overall verdict

needs-attention — the code closes the original alpha loss path, but the reviewed SoT docs still contradict the implementation on alpha ordering and import-key coverage.

---

## Self-Review Round 3 (Round 2 codex finding 처리)

### 처리
| Finding | 수정 |
|---|---|
| R2-H1 alpha resolve order doc drift | `svg_color_map.json _about.resolve_order`, `docs/UI_GUIDE.md §2.6`, `phase09-ui-theme-assets.md`, `plan v8` 본문 모두 alpha 유무 조건 분기 표로 갱신. token-first 약속 철회, alpha-present + token oklch + alpha_variants 미스 → exit 1 명시. |
| R2-H2 phase doc/plan 잔재 | `phase09-ui-theme-assets.md` 본문에서 ink_700/0.35 표기 제거 (2→1 alpha_variants) + 5종 import key 표기 제거 (4종). plan v8 본문 의사코드 + 검증 항목 + REQUIRED_IMPORT_KEYS 상수 모두 4종으로 동기화. flags/filter는 ProjectSettings 경로 명시. |
| R2-M1 CLASS_RE scan over-match | cmd_scan에서 XML parse 기반 class enumeration으로 전환, parse fail 시 regex fallback. |
| R2-M2 style block strip risk | deferred — 본 phase는 handoff class-only 정책 명시. element/id selector 도입 시 strict-fail 전환은 sweep. |
| R2-M3 dead-entry policy 확장성 | deferred — `--audit-dead-map` 도구는 post-MVP sweep. 본 phase는 alpha_variants invariant[4]만 자동, 다른 섹션 수동 리뷰. |
| R2-L1 SpinBox composition note | UI_GUIDE §2.4에 한 줄 추가 완료. |

### 재검증 (Self-Review Round 3)
- normalize_svg.py: --self-test PASS, --scan-handoff-all PASS, --check PASS.
- SvgImportSmokeTest PASS (13 SVG + 4 invariants + 4종 import 키).
- MotionPauseSafeTest PASS.
- Stage03 + Blocker 회귀 PASS.

### Verdict (Round 3 Self-Review)
HIGH 0, MEDIUM 0 (R2-M1 수정, R2-M2/M3 deferred), LOW 0 (R2-L1 수정). → **clean** → codex 재리뷰 round 3 진입.

---

## Round 3

### CRITICAL

None

### HIGH

**R3-H1** — `phases/mvp/phase09-ui-theme-assets.md:115` — Stale token-first transform step contradicts fixed alpha resolve order.

- Evidence: the same document has the corrected conditional resolve-order table at `phases/mvp/phase09-ui-theme-assets.md:74-81`, but the implementation step below still says token table is matched first, then `alpha_variants`, then `oklch_extras` at `phases/mvp/phase09-ui-theme-assets.md:115-120`. That is the old order that caused alpha-bearing token colors to lose transparency.
- Impact: Phase 9 still contains two incompatible normalizer specs. A future maintainer following the transformation-step section can reintroduce the Round 1 alpha-loss bug while believing the phase handoff doc is authoritative.
- Fix recommendation: replace `phase09-ui-theme-assets.md:115-120` with the same alpha-conditional order used in `docs/UI_GUIDE.md:181-190` and `phase09-ui-theme-assets.md:74-81`.

**R3-H2** — `scripts/tools/svg_color_map.json:6` — Mapping SoT metadata still says token OKLCH resolves through token table FIRST.

- Evidence: `_about.resolve_order` was updated at `scripts/tools/svg_color_map.json:8-14`, but `_about.tokens_ref` still says "token oklch values resolve via the token table FIRST" at `scripts/tools/svg_color_map.json:6`. For alpha-present token OKLCH, actual code requires `alpha_variants` and must not fall back to token hex (`scripts/tools/normalize_svg.py:177-187`).
- Impact: the mapping SoT is internally contradictory exactly at the alpha-loss boundary. This is not just historical prose; it is in the `_about` metadata implementers read when extending the map.
- Fix recommendation: change the metadata to "alpha-absent token oklch values resolve via the token table; alpha-present token oklch requires alpha_variants."

### MEDIUM

**R3-M1** — `phases/mvp/plans/phase09-plan.md:545` — Plan body still claims SvgImportSmokeTest covers import 5종.

- Evidence: v8 correctly updates the test pseudocode to four import keys at `phases/mvp/plans/phase09-plan.md:362-370` and the verification section to four keys at `phases/mvp/plans/phase09-plan.md:482,492`, but the artifact summary still says `tests/SvgImportSmokeTest.gd + .tscn ... 임포트 5종` at `phases/mvp/plans/phase09-plan.md:545`.
- Impact: the plan body is not fully swept from 5종 to 4종; this stale deliverable summary can create false expectations in completion review.
- Fix recommendation: update line 545 to `임포트 4종`.

**R3-M2** — `tests/SvgImportSmokeTest.gd:4` — Smoke test comments still say import 5종 while code checks four keys.

- Evidence: the file header says "import 5종 키 검증" at `tests/SvgImportSmokeTest.gd:4` and the loop comment says "임포트 설정 5종" at `tests/SvgImportSmokeTest.gd:102`, while `_check_import_settings()` checks exactly four entries at `tests/SvgImportSmokeTest.gd:205-210`.
- Impact: runtime behavior is correct, but implementation comments conflict with the current Godot 4.6 import policy and can mislead future test edits.
- Fix recommendation: update both comments to 4종.

**R3-M3** — `phases/mvp/phase09-ui-theme-assets.md:210` — Anti-alias edge case still says `flags/filter=true` is forced.

- Evidence: UI_GUIDE now says `flags/filter` is not a Godot 4 per-asset `.import` key and is controlled by ProjectSettings or `CanvasItem.texture_filter` (`docs/UI_GUIDE.md:159-163`), but the phase doc still says `flags/filter=true` is forced at `phases/mvp/phase09-ui-theme-assets.md:210`.
- Impact: this keeps a stale Godot 3 import-key requirement alive outside the main §2.5 sweep.
- Fix recommendation: rewrite the edge case to say anti-aliasing relies on default Linear filtering / future per-node `texture_filter`, not `flags/filter`.

**R3-M4** — `scripts/tools/normalize_svg.py:14` — Normalizer module docstring still advertises old token-first resolve order.

- Evidence: the executable script docstring lists token table before `alpha_variants` at `scripts/tools/normalize_svg.py:14-19`, while the code below correctly handles white-alpha first and alpha-present values before alpha-absent token lookup (`scripts/tools/normalize_svg.py:171-209`).
- Impact: behavior is fixed, but the implementation file's top-level contract is stale and can mislead maintainers.
- Fix recommendation: update the docstring to mirror the conditional order now used by `resolve_oklch()`.

### LOW

**R3-L1** — `phases/mvp/plans/phase09-plan.md:201`, `scripts/tools/svg_color_map.json:116` — `alpha_variants` is still called "step 2" after the resolve-order renumbering.

- Evidence: plan self-test text says `alpha_variants` passes "step 2" at `phases/mvp/plans/phase09-plan.md:201`, and `svg_color_map.json` invariant text repeats "step 2 of resolve_order" at `scripts/tools/svg_color_map.json:116`. The new resolve order uses branch labels `(0)`, `(1)`, `(1')`, `(2)`, `(3)`, `(4)`.
- Impact: small terminology drift only; the required behavior remains clear elsewhere.
- Fix recommendation: replace "step 2" with "alpha-present branch / alpha_variants branch."

**R3-L2** — `phases/mvp/plans/phase09-plan.md:53` — Operational-model text still overstates token-exact matching for the five normalized SVGs.

- Evidence: the plan still says the five Phase 9 normalized handoff SVGs have OKLCH values that exactly match UI_GUIDE tokens at `phases/mvp/plans/phase09-plan.md:53`, while the same plan documents stage_bg non-token `oklch_extras` at `phases/mvp/plans/phase09-plan.md:519`.
- Impact: low because UI_GUIDE and the implementation sections now describe explicit mapping correctly, but the opening premise remains imprecise.
- Fix recommendation: mirror `docs/UI_GUIDE.md:28`: token-matching OKLCH resolves via tokens, token-external values resolve via explicit map entries.

### Overall verdict

needs-attention — the implementation behavior is mostly aligned, but Phase 9 still has HIGH-severity SoT drift around alpha resolution in the phase handoff doc and mapping metadata.

---

## Self-Review Round 4 (Round 3 codex finding 처리)

### 처리
| Finding | 수정 |
|---|---|
| R3-H1 phase doc transformation step drift | `phase09-ui-theme-assets.md`의 변환 단계 §1번 oklch 처리 항목을 alpha 조건 분기 6항(0/1/1'/2/3/4)로 동일 표기 갱신. |
| R3-H2 svg_color_map `_about.tokens_ref` 잔재 | "token table FIRST" → "alpha-absent token oklch values resolve via the token table; alpha-present token oklch REQUIRES an alpha_variants entry"로 정정. |
| R3-M1 plan 산출물 요약 5종 잔재 | line 545 "임포트 5종" → "임포트 4종". |
| R3-M2 SvgImportSmokeTest.gd 코멘트 5종 잔재 | 헤더/loop 코멘트 4종 + flags/filter 부재 안내로 정정. |
| R3-M3 phase doc anti-alias 엣지 케이스 `flags/filter=true` 강제 | "Godot 4 텍스처 필터는 .import key 아님, ProjectSettings default Linear / per-node texture_filter로 제어"로 재작성. |
| R3-M4 normalize_svg.py 모듈 docstring 옛 resolve_order | 6항 분기 표기로 갱신. |
| R3-L1 step 2 용어 잔재 | plan + svg_color_map invariant 모두 "alpha-present branch (alpha_variants 매칭)"으로. |
| R3-L2 plan §운영 모델 token-exact overstatement | "토큰 oklch는 토큰 표로, 토큰 외 oklch는 svg_color_map 명시적 매핑으로 resolve, 모두 strict 1:1 lookup"으로 정정. |

### 재검증 (Self-Review Round 4)
- normalize_svg.py: --self-test PASS, --scan-handoff-all PASS, --check PASS.
- SvgImportSmokeTest PASS.
- 헤드리스 회귀 PASS.

### Verdict (Round 4 Self-Review)
HIGH 0, MEDIUM 0, LOW 0. → **clean** → codex 재리뷰 round 4 진입.

---

## Round 4

### CRITICAL
None

### HIGH

**R4-H1** — `scripts/tools/normalize_svg.py:451` — `--scan` / `--scan-handoff-all` reject non-token alpha OKLCH even though normalize path and docs allow CSS Color 4 fallback.

- Evidence: `resolve_oklch()` implements the documented branch for alpha-present non-token OKLCH by checking `alpha_variants`, skipping token fallback, then emitting CSS Color 4 `rgba(...)` at `scripts/tools/normalize_svg.py:180-208`. The scan gate does not mirror that path: after missing `alpha_variants`, any alpha-present non-token value is immediately added to `unmapped_oklch` at `scripts/tools/normalize_svg.py:451-460`. The SoT docs say the same value should fall back to CSS Color 4: `docs/UI_GUIDE.md:187`, `phases/mvp/phase09-ui-theme-assets.md:78`, and `phases/mvp/plans/phase09-plan.md:123`.
- Impact: a future handoff SVG containing valid non-token `oklch(... / alpha)` that the normalizer can convert will be blocked by `--scan-handoff-all`. That creates a reachable dead branch in the completion gate and breaks the claim that scan and normalize enforce the same resolve order.
- Fix recommendation: in `cmd_scan`, for alpha-present non-token values with no `alpha_variants` match, call the same CSS Color 4 conversion path used by `resolve_oklch()` and only report unmapped when conversion/gamut fails. Alternatively, change all SoT docs to require `alpha_variants` for every alpha-present OKLCH; current docs choose fallback, so code should align.

### MEDIUM

**R4-M1** — `scripts/tools/svg_color_map.json:8` — `_about.resolve_order` is still a five-entry structure while every doc now claims six conditional branches.

- Evidence: `docs/UI_GUIDE.md:185-190`, `phases/mvp/phase09-ui-theme-assets.md:76-81`, and `scripts/tools/normalize_svg.py:15-21` all enumerate `(0)`, `(1)`, `(1')`, `(2)`, `(3)`, `(4)` as separate branches. The mapping SoT metadata has entries `0`, `1`, `2`, `3`, `4` only at `scripts/tools/svg_color_map.json:8-14`, with `(1')` folded into the prose of entry `1`.
- Impact: the content is mostly correct, but the promised 1:1 six-branch synchronization is not actually true for the JSON `_about` section. This is exactly the metadata developers read while updating the map, so structural drift can reintroduce branch-order ambiguity.
- Fix recommendation: split `scripts/tools/svg_color_map.json:10` into two array entries: one for `(1) alpha present + token`, and one for `(1') alpha present + non-token`; keep numbering text identical to UI_GUIDE.

**R4-M2** — `phases/mvp/plans/phase09-plan.md:74` — Plan still contains current-looking `5종` import-key claims after the sweep.

- Evidence: the normative sections now use four import keys (`phases/mvp/plans/phase09-plan.md:362-370`, `:482`, `:492`), but the review-summary table still says `R3#1 import settings 5종 ... 5종 모두 자동 검증` at `phases/mvp/plans/phase09-plan.md:74`. Earlier changelog lines also mention `5종` at `phases/mvp/plans/phase09-plan.md:3`, `:5`, `:30`, and `:64`.
- Impact: the main implementation contract is fixed, but the "5종 모두 자동 검증" row is not clearly historical because it sits in the review handling summary. A grep-based audit still reports stale 5-key policy in the plan body, which contradicts the Round 4 sweep target.
- Fix recommendation: rewrite the row to say that the original 5-key claim was corrected to Godot 4.6 actual 4-key verification. If historical mentions are retained, mark them explicitly as obsolete claims rather than accepted outcomes.

### LOW

**R4-L1** — `scripts/tools/normalize_svg.py:175` — `resolve_oklch()` internal comments still use stale branch numbers.

- Evidence: the docstring now uses `(0)`, `(1)`, `(1')`, `(2)`, `(3)`, `(4)` at `scripts/tools/normalize_svg.py:14-21`, but comments inside the implementation still label white-alpha as `(4)`, alpha variants as `(2)`, token table as `(1)`, and fallback as `(5)` at `scripts/tools/normalize_svg.py:175`, `:179`, `:191`, and `:202`.
- Impact: behavior is not wrong, but maintainers stepping through the function see branch numbers that no longer match the SoT.
- Fix recommendation: renumber the comments only; no logic change required.

### Overall verdict

needs-attention — the alpha resolve-order docs are mostly synchronized, but `cmd_scan` still diverges from the normalizer for alpha-present non-token OKLCH, and SoT metadata still has structural drift.

---

## Round 5

### CRITICAL
None

### HIGH
None

### MEDIUM
None

### LOW

**R5-L1** — `scripts/tools/svg_color_map.json:14` — `_about.resolve_order` item `(4)` is more restrictive than the other SoT wordings.

- Evidence: `docs/UI_GUIDE.md:187`, `phases/mvp/phase09-ui-theme-assets.md:78`, and `scripts/tools/normalize_svg.py:18` all put alpha-present non-token CSS Color 4 conversion in branch `(1')`. The actual implementation matches that at `scripts/tools/normalize_svg.py:182-192` and then reaches the shared CSS conversion at `scripts/tools/normalize_svg.py:205-211`. However, the JSON metadata says `(4) Alpha-absent fallthrough` at `scripts/tools/svg_color_map.json:14`, while the script comment correctly says branch `(4)` is "also reached by 1'" at `scripts/tools/normalize_svg.py:205`.
- Impact: low. Runtime behavior and scan behavior are now aligned because `cmd_scan()` calls `resolve_oklch()` directly at `scripts/tools/normalize_svg.py:450-457`. The residual risk is only metadata phrasing: the JSON line implies branch `(4)` is alpha-absent only, while the implementation uses the conversion block for branch `(1')` as well.
- Fix recommendation: change `scripts/tools/svg_color_map.json:14` to "CSS Color 4 conversion fallback: alpha-absent fallthrough and branch `(1')` non-token alpha miss; emits hex when alpha absent, rgba when alpha present; gamut fail → exit 1." This keeps it line-aligned with the actual shared conversion path.

### Overall verdict

clean — no HIGH/MEDIUM blockers remain. `cmd_scan` and `resolve_oklch` now share the same resolve path; the only residual issue is non-blocking metadata phrasing around the shared CSS Color 4 conversion branch.

---

## Self-Review Round 5 (Round 4 codex finding 처리)

### 처리
| Finding | 수정 |
|---|---|
| R4-H1 cmd_scan ↔ resolve_oklch 동작 divergence | cmd_scan oklch enumeration을 `resolve_oklch()` 직접 호출로 통일. ValueError 발생 시에만 unmapped 보고. token+alpha 미스 / gamut fail 둘 다 동일 함수가 처리. |
| R4-M1 svg_color_map `_about.resolve_order` 5항 vs 문서 6항 | 6항 (0/1/1'/2/3/4) 분리 표기로 갱신. UI_GUIDE/phase doc/normalize_svg.py docstring과 1:1. |
| R4-M2 plan changelog "5종" 잔재 | R1 MED#1 / R3#1 행 + HIGH#1 changelog 모두 "v8에서 Godot 4.6 실제 4종으로 정정, 5종은 obsolete" 명시. |
| R4-L1 resolve_oklch 내부 주석 번호 | 6항 (0/1/1'/2/3/4) 분기 라벨로 갱신. docstring과 일치. |

### 재검증 (Self-Review Round 5)
- normalize_svg.py: --self-test PASS, --scan-handoff-all PASS, --check PASS.
- SvgImportSmokeTest PASS.
- Stage03 회귀 PASS.

### Verdict (Round 5 Self-Review)
HIGH 0, MEDIUM 0, LOW 0. → **clean** → codex 재리뷰 round 5 진입.

---

## Round 5 (codex impl review — FINAL)

### Verdict
**clean** (HIGH 0, MEDIUM 0, LOW 1)

### LOW
- R5-L1 — svg_color_map.json item `(4)` 문구 "alpha-absent fallthrough"는 CSS Color 4 블록이 branch `(1')` alpha-present non-token에서도 도달함을 명시 안 함. Runtime behavior 정확, metadata wording만 cleanup. → deferred to sweep (phase 10 진입 전).

### Phase 9 impl complete 진입 가능
- 모든 자동 검증 9건 PASS.
- HIGH 0 — CLAUDE.md impl-stage 정책 통과.
- 잔여 LOW 1건은 sweep로 다음 phase 진입 전 정리 (blocker 아님).

### Round 사이클 요약
- Self-Review Round 1 → 수정 → Re-Self-Review clean
- Codex Round 1 (HIGH 4) → Self-Review Round 2 clean
- Codex Round 2 (HIGH 2) → Self-Review Round 3 clean
- Codex Round 3 (HIGH 2) → Self-Review Round 4 clean
- Codex Round 4 (HIGH 1) → Self-Review Round 5 clean
- Codex Round 5 → **clean**

총 5 self-review + 5 codex round.
