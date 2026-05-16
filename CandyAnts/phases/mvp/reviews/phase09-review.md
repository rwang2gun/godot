# Phase 9 Plan Stage Review

> Target: `phases/mvp/plans/phase09-plan.md`
> Ctx: `phases/mvp/phase09-ui-theme-assets.md`, `docs/UI_GUIDE.md`, `phases/mvp/PRE_PHASE9_SPRITE_STATE.md`, `scripts/tools/svg_color_map.json`
> Mode: strict-adversarial · plan-only

---

## Round 1 (2026-05-16, plan v1)

### Verdict
CRITICAL-HALT (HIGH 4)

### HIGH

- **HIGH#1** `plan:89` — Fuzzy OKLCH tolerance not in SoT. `±0.005/±2°` 허용 매칭이 UI_GUIDE/svg_color_map의 1:1 invariant와 충돌.
- **HIGH#2** `plan:336-342` — SvgImportSmokeTest가 `sanity_invariants[4]` (alpha_variants 사용 검증) 누락.
- **HIGH#3** `plan:462,500` — phase 10 atom의 override 정책을 phase 9에서 freeze (UI authority 권한 외).
- **HIGH#4** `plan:448-455,467` — 시각 회귀가 UI_GUIDE §8 강제 절차(1280×720+1920×1080+handoff preview) 미충족.

### MEDIUM
- **MED#1** import settings 5종(scale/compress/filter/mipmaps/fix_alpha_border) 부분 누락.
- **MED#2** `_README.md` 문구가 plan scope와 모순.

### LOW
- typo "toekn" → "token"

### 처리
사용자가 운영 모델(1인 개발 + AI 생성·외부 자산) 전제 추가 결정. UI_GUIDE.md §0.5(운영 모델 신설) + §8(시각 회귀 1인 개발 기준 완화) 갱신. plan v2 작성.

---

## Round 2 (2026-05-16, plan v2)

### Verdict
CRITICAL-HALT (HIGH 5)

### HIGH

- **HIGH#1 (R1#1 미해결)** `plan:65-67` — "strict 1:1" 선언과 달리 `round(L,3), round(C,3), round(H,1)` 반올림이 approximate match window로 동작. UI_GUIDE §1.2 + svg_color_map._about과 충돌.
- **HIGH#2 (신규)** `plan:56` vs `:126-133` — normalize_svg.py 헤더는 "all SVGs" 선언, 본문은 "5장 + skill 8 제외"로 좁힘. phase09-ui-theme-assets.md:129-137(prod scope 13)와 모순.
- **HIGH#3 (신규)** `plan:274-279` — "5 sanity invariants 전수 검증" 주장 vs invariant[3]은 명시적 제외 — 게이트 문구 과장.
- **HIGH#4 (신규)** `plan:157-181 + :409` — `Tokens.gd`에 `SKY_300`, `GRASS_300` 누락. UI_GUIDE §1.2:67-68에 필수 포함. "1:1 검증" 게이트 통과 불가.
- **HIGH#5 (R1#3 미해결)** `plan:22,33,42` — plan은 phase 10으로 defer 명시, 그러나 `phase09-ui-theme-assets.md:188,213`에 atom override 정책 잔존. spec authority 간 충돌.

### MEDIUM
- **MED#1** alpha invariant — `rgba(...)` 텍스트 존재 확인만으로 resolve_order step 2 경로 검증 불충분.
- **MED#2** 운영 모델 단일 리뷰어 갭 — handoff preview non-blocking으로 shape/layout drift가 hex 검사를 통과 후 미검출 가능. 허용된 위험이지만 명시 필요.

### Cross-doc

| 쌍 | 결과 |
|---|---|
| plan ↔ UI_GUIDE | FAIL (HIGH#1, HIGH#4) |
| plan ↔ svg_color_map | FAIL (HIGH#3, MED#1) |
| plan ↔ phase09-ui-theme-assets | FAIL (HIGH#2, HIGH#5) |
| plan ↔ PRE_PHASE9_SPRITE_STATE | PASS |
| UI_GUIDE ↔ svg_color_map | PASS |
| phase09-ui-theme-assets ↔ PRE_PHASE9_SPRITE_STATE | PASS |

### 사용자 결정 필요 (CLAUDE.md plan-stage 정책)

5건 모두 mechanical fix:
1. HIGH#1: `round()` 제거, raw 문자열/float 비교
2. HIGH#2: 스코프 단일 정의 (5장 정규화 + skill 8 검증)로 통일
3. HIGH#3: "4 검증 + 1 normalize_svg.py 책임"으로 정정
4. HIGH#4: `Tokens.gd`에 `SKY_300`, `GRASS_300` 추가
5. HIGH#5: `phase09-ui-theme-assets.md`에서 atom override 구절 제거 또는 "phase 10 결정 예정"으로 교체

### 사용자 결정 (2026-05-16)
Option A로 진행 — normalize_svg.py 입력 5장 명시. 5건 모두 v3에서 mechanical fix 반영.

---

## Round 3 (2026-05-16, plan v3)

### Verdict
CRITICAL-HALT (HIGH 4 + MEDIUM 3)

### HIGH

- **HIGH#1 (MED#1 미해결)** `plan:430-432, 377-394` — `_check_import_settings()`가 UI_GUIDE §2.5 5종 중 3종만 검증, `flags/filter`/`flags/mipmaps` deferral.
- **HIGH#2 (R2#2 부분 미해결)** `plan:70-79, 146-150` vs `phase09-ui-theme-assets.md:81-90` — Option A가 plan엔 반영, phase 문서엔 미반영. 스코프 충돌 잔류.
- **HIGH#3 (신규)** `plan:286-293` — Option A로 normalize_svg.py가 5장만 처리, handoff 나머지 SVG의 class 매핑 누락이 phase 9 게이트에서 검출 안 됨. invariant[3] 부분 ungated.
- **HIGH#4 (R2#4 새 발현)** `plan:441` — SKY_300/GRASS_300이 Tokens.gd엔 있지만 Theme 비노출. plan의 3-way SoT 일치 검증이 구조적으로 불가능.

### MEDIUM (잔존)

- **MED#1** formatting drift 문구 부정확 — Python `float("0.78") == float("0.780")` 사실.
- **MED#2** skill icons handoff freshness 미검출 (Option A 의도된 trade-off).
- **MED#3** alpha resolve-path 검증 깊이 부족 (output-presence only).

### 처리 방향 (Option A 권장)

1. `_check_import_settings()` 5종 다 검증 (Godot 4.6 실제 키 이름 확인)
2. `phase09-ui-theme-assets.md` 정규화 스코프 섹션도 Option A로 동기화
3. `normalize_svg.py`에 `--scan-handoff-all` 모드 (handoff 전체 미매칭 class 발견 시 exit 1) + CI 게이트 추가
4. Tokens.gd `SKY_300`/`GRASS_300`에 "illustration 전용, Theme 비노출" 주석 + 3-way 검증을 "Theme/atom 토큰만"으로 축소
5. MED 3건: 문구 정정 + 운영 모델 §0.5 trade-off 명시 + alpha resolve-path 검증은 normalize_svg.py 단위 테스트로 deferral 명시

### 사용자 처리 (v4)
사용자가 plan을 v4로 직접 수정. 4건 mechanical 보강 추가 (illust-token 자동 강제, 자동 검증 9개 전체 차단 조건 명시, phase 문서 임포트 5종 + 검증 항목 확장).

---

## Round 4 (2026-05-16, plan v4 + 사용자 자체 보강)

### Verdict
needs-attention (HIGH 2 + MEDIUM 5 + LOW 1) — plan stage 정책상 HIGH 1건 이상 → 중단 + 사용자 결정.

### HIGH

- **R4-H1 — illust-token gate가 현재 소스로 항상 fail 가능성** `plan:402-407`
  - 사용자 자체 보강으로 추가한 stage_bg.svg `#CCDFEA` AND `#B0DCB4` 강제 검사가, 실제 `docs/design_handoff/assets/illustrations/stage_bg.svg`이 사용하는 oklch 값(`0.88 0.07 145` 등)이 token grass_300(`oklch(0.88 0.07 140)` → `#B0DCB4`)이 아닌 oklch_extras `#A9CFA5` 등으로 매핑되기 때문에 정규화 산출물에 `#B0DCB4`가 등장하지 않음.
  - 같은 이유로 sky 변종 색도 token sky_300(`#CCDFEA`) 대신 `#D6E5F0` 등으로 매핑.
  - 즉 R3 LOW에서 codex가 "deliberate completeness choice"로 받아준 SKY_300/GRASS_300 dead constant 위험을 닫으려 추가한 게이트가 오히려 항상 fail하는 dead test가 됨.

- **R4-H2 — UI_GUIDE normalize 절차가 Option A와 cross-doc drift**
  - `docs/UI_GUIDE.md` §2.6 "디자이너 갱신 시" 절차가 여전히 `--scan docs/design_handoff/assets/` 전체 실행 후 전체 normalize를 명시.
  - plan v4 Option A는 5장만 normalize, handoff 전체는 `--scan-handoff-all` mapping coverage gate만.
  - UI_GUIDE가 1차 SoT인데 절차가 plan과 불일치.

### MEDIUM (잔존)

- R4-M1 `--scan-handoff-all`은 mapping coverage만 닫고 skill icons handoff freshness 미검출 (Option A 명시 trade-off, 유지).
- R4-M2 drop된 sprite handoff SVG가 `--scan-handoff-all` 통과해야 함 (svg_color_map class_map 27 entries 전수 enumerate 했으니 통과 예상, hypothesis).
- R4-M3 REQUIRED_IMPORT_KEYS Godot 4.6 실제 키 이름 impl 확인 필요 (acceptable).
- R4-M4 Tokens.gd freeze vs phase 10 override 충돌 없음 (no circular SoT).
- R4-M5 운영 모델 §0.5 visual drift 비차단 명시 trade-off (유지).

### LOW
- **R4-L1** `svg_color_map.json` `_about.owner`가 "phase 8"로 남음. phase 9가 normalizer/gates를 소유하므로 갱신 필요.

### Cross-doc consistency
- plan ↔ phase09-ui-theme-assets.md: PASS
- plan ↔ UI_GUIDE.md: **FAIL** (R4-H2)
- plan ↔ svg_color_map.json: **FAIL** (R4-H1, illust-token gate hex가 실제 매핑과 충돌)
- plan ↔ PRE_PHASE9_SPRITE_STATE.md: PASS
- UI_GUIDE.md ↔ svg_color_map.json: PASS (토큰 매핑 자체 일치, metadata owner drift만)

### 사용자 결정 필요

1. **R4-H1**: 두 옵션
   - (a) illust-token gate 제거. SKY_300/GRASS_300은 documented but unused constants (R3 LOW codex 이미 인정).
   - (b) illust-token gate를 실제 stage_bg.svg에 등장하는 hex(예: `#A9CFA5`, `#D6E5F0`)로 변경. 이건 oklch_extras 매핑의 사용 검증으로 의미 확장.
2. **R4-H2**: UI_GUIDE §2.6 절차를 Option A scope(`--scan-handoff-all` + 5장 normalize)로 갱신.
3. **R4-L1**: svg_color_map.json `_about.owner` "phase 8" → "phase 9 (normalizer + smoke gate owner)".

### 사용자 처리 (v5)
사용자 (a) 권장 채택 — illust-token 게이트 제거 + UI_GUIDE §2.6 갱신 + svg_color_map owner 갱신.

---

## Round 5 (2026-05-16, plan v5 + UI_GUIDE/svg_color_map 갱신)

### Verdict
needs-attention (HIGH 2 + MEDIUM 2 + LOW 1) — plan stage 정책상 HIGH 1건 이상 → 중단 + 사용자 결정.

### HIGH

- **R5-H1 — Residual SKY/GRASS stage_bg verification still impossible** `plan:481`
  - illust-token 자동 게이트는 제거됐지만, 수동 검증 6번이 여전히 `Tokens.gd ↔ UI_GUIDE §1.2 ↔ 정규화된 assets/illustrations/stage_bg.svg 색 사용`을 요구. 현 svg_color_map은 stage_bg 색이 token 자체가 아닌 변종으로 매핑되도록 함 → manual gate도 통과 불가능.
- **R5-H2 — UI_GUIDE 전체에 atom = Phase 9 라벨 잔존**
  - `docs/UI_GUIDE.md:195` "Phase 9 = ui-atoms-foundation" + `:261-263` Motion이 phase 9 atom 호출. plan/phase09-ui-theme-assets는 atom = phase 10. UI_GUIDE가 1차 SoT라 구현자가 UI_GUIDE만 보면 잘못 판단.
  - 사실: 프로젝트 phase 6 game-flow 신설로 모든 phase 번호가 1씩 밀린 결과, UI_GUIDE는 옛 번호(theme=8, atoms=9)로 작성된 잔재. 8군데 phase 번호 갱신 필요.

### MEDIUM
- R5-M1 — UI_GUIDE 본문에 phase 8 (theme normalize) 잔재 6군데. 동작 영향 없지만 문서 일관성.
- R5-M2 — 5장 외 추가 normalize 경로 운영 절차 부재. Option A 의도 trade-off로 유지.

### LOW
- R5-L1 — plan summary "svg_color_map.json 무변경" 표기 drift. `_about.owner` 갱신 vs body 무변경 분리 명시 필요.

### Cross-doc consistency
- plan ↔ phase09-ui-theme-assets.md: PASS
- plan ↔ UI_GUIDE.md: **FAIL** (R5-H2 atom phase 라벨)
- plan ↔ svg_color_map.json: PASS (owner 갱신 완료); R5-L1 wording drift만 남음
- plan ↔ PRE_PHASE9_SPRITE_STATE.md: PASS
- UI_GUIDE.md ↔ svg_color_map.json: PASS (mapping); stale phase labels는 비동작적

### 사용자 처리 (v6)
- R5-H1: 수동 검증 6번에서 SKY_300/GRASS_300 stage_bg 사용 요건 제거. illustration 전용 documented constants는 3-way 비대상 명시.
- R5-H2 + R5-M1: UI_GUIDE.md phase 번호 8군데 일괄 갱신 (theme: 8→9, atoms: 9→10).
- R5-L1: plan의 "svg_color_map.json 무변경" → "mapping values 무변경, _about 메타만 갱신"으로 명확화.
- R5-M2: Option A 명시 trade-off 그대로 유지.

---

## Round 6 (2026-05-16, plan v6 + UI_GUIDE phase 번호 갱신)

### Verdict
**clean** (HIGH 0 + MEDIUM 2 + LOW 1) — plan stage 통과, impl 진입 가능.

### MEDIUM
- **R6-M1** `scripts/tools/svg_color_map.json` `sanity_invariants._comment` 가 여전히 "phase 8 complete / SvgImportSmokeTest 단독 게이트" 잔재. v6에서 split-gate 모델("normalize_svg.py + SmokeTest 분담, phase 9 complete 차단")로 갱신 완료.
- **R6-M2** `docs/UI_GUIDE.md` phase 범위 표기 미세 불일치 — line 3 "Phase 9~13" vs §0.5 "9~12" vs motion "phase 10/12". §0.5 → 9~13으로 갱신 완료. motion "phase 10/12"는 atoms 10 + stage-dialog 12 정확 표기로 유지. 추가: §3.5/§3.6/§5/§349/§415/§449~451 등 stage-dialog/title-menu phase 번호 +1 shift 잔재는 phase 10 진입 전 sweep로 deferral.

### LOW
- **R6-L1** plan footer "v4/round 4" → v6에서 정확 표기로 갱신 완료.

### 정리 결과
- R6-M1 + R6-L1: v6에서 정정.
- R6-M2 일부: §0.5 갱신.
- R6-M2 잔여 (stage-dialog/title-menu phase 번호 shift): phase 10 진입 전 sweep로 처리. phase 9 blocker 아님.

### 결정
**Phase 9 impl 진입.** plan v6 통과.
