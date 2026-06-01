# Impl-stage Adversarial Review — Phase 3 (square-tile-art-swap)

대상: working-tree (StageLayoutBuilder.gd + test_StageLayoutBuilder.gd + run_test.py + TERRAIN_TILE_RULES.md + 8 PNG + phase docs + status.json)

## Self-Review Round 1 (2026-06-02)

Verdict: **clean (CRITICAL/HIGH 0)**. MEDIUM 0 · LOW 1 (관찰).

가혹 기준(CRITICAL/HIGH/MEDIUM/LOW + hypothetical 위험 + cross-doc 일관성 + dead branch + circular SoT)으로 자체 검토.

### 검증한 항목 (이상 없음)
- **`_variant_index` 해시 안전성**: GDScript int=64bit signed, 곱셈 오버플로는 silent wrap(에러 아님) → 결정적. `h >> 13/16`은 arithmetic shift이나 `posmod(h, n)`가 [0,n) 정규화 → 음수 cell도 안전. 순수함수라 리빌드/에디터-프리뷰 결정성 보장.
- **분포 테스트 비-flaky**: `_test_variant_distribution_and_determinism`의 ≥2 variant는 결정적 해시 + 고정 입력(x=0..15) → 한 번 PASS면 영구 PASS. 공식 복제 아님(family 집합/분포만 검증) — plan R1-M1 준수.
- **whole-tile 렌더**: `_apply_square_tile`이 `region_enabled=false`, `centered=true`, `position=0`, `scale=cell_size/tex`. fresh Sprite2D라 stale region 없음. 32px 합성 케이스가 비-48 회귀 가드(plan R1-M2).
- **exposure 술어 불변**: `_solid_texture_for_cell`의 `not map.has(above_key)` SoT 그대로, 텍스처 타깃만 family로 교체. 슬로프 `_add_slope_visual`(cookie_tile_surface.png) 무변경.
- **background = solid family**: visual-only 채움은 interior 룩(SOLID_TILES) — Phase 2 `cookie_tile_background`(interior)와 동일 의미. exposure 술어 미적용은 의도적(background는 항상 interior 채움).
- **dead code 제거**: `_configure_repeating_region` 전 repo에서 완전 제거(grep 0건), 다른 호출처 없음.
- **회귀**: test_StageLayoutBuilder / EarthBackwardCompat(23 layouts all-earth) / Stage03(clear score=1.0) 전부 PASS. 충돌/점유/스코어 불변(텍스처 교체만).
- **cross-doc**: TERRAIN_TILE_RULES.md §2/§3/§4/§5/§7/§8/§9/§10/§11 모두 discrete 4-variant 모델로 정합. ground 맥락 "under-surface" 잔재 제거(sand-mound §11.2 자체 tier는 별개로 유지). 구 아틀라스 파일은 "(폐기)/(구)" 명시 + CookiePlatformVisual/슬로프 보존 사유 박제.

### [low] L1 — 프로덕션 타일이 `usable_square/`에 위치
8개 production 타일이 미사용 art(`biscuit_ladder_*`, `_preview_square_tiles.png`)와 같은 `usable_square/` 디렉토리에 섞여 있다. 동작엔 무해(코드가 정확 경로 참조). plan이 이 위치로 확정했고 사용자 자산 조직이므로 **수용** — 향후 정리 시 production 타일만 평탄 `terrain/`로 이동 후보. defer.

### plan-review L1 정정 (impl 단계 발견)
plan/plan-review L1은 "8 PNG + 8 `.png.import` explicit stage"를 지시했으나, **`*.import`는 repo 전역 `.gitignore:10`** 대상이라 커밋 불가. 기존 terrain PNG도 `.import` 없이 트래킹됨(머신마다 `--import` 재생성). → Phase 3 커밋은 **PNG 8개만**. L1의 "미사용 PNG의 .import 혼입" 리스크는 gitignore가 원천 차단 → 자동 해소.

→ self-review HIGH 0 → codex 재리뷰 진행.

## Codex Round 1 (2026-06-02)

Verdict: **needs-attention** — CRITICAL/HIGH 0 · MEDIUM 2.

- **[medium] M1** `execute.py complete` auto-stage가 whitelisted untracked `assets/**`를 전부 staging → 무관 art가 Phase 3 커밋에 섞일 수 있음(재현성/스코프).
- **[medium] M2** frontmatter `verify`가 `--import` 부트스트랩 미포함 → clean checkout/CI cache miss에서 새 PNG import 실패 → 비재현적.

CRITICAL/HIGH 0이나 둘 다 정당한 재현성 지적 → defer 없이 **둘 다 수정**.

### 수정 (Codex Round 1 대응)
- **[M2] 수정**: `scripts/run_test.py`에 `--import` 모드 추가(`run_import` — find_godot 재사용, `godot --headless --path . --import`).
  phase03 frontmatter `verify` 선두에 `python scripts/run_test.py --import &&` prepend → 자가완결. `sync-status`로 status.json 미러.
  재실행: import + test_StageLayoutBuilder + EarthBackwardCompat(23) + Stage03 전부 PASS.
  `.godot/`·`.import/`·`*.import` 전부 gitignore 확인 → `--import`가 tracked 파일 안 더럽힘(tree tracked 변경 = Phase 3 의도 5개뿐).
- **[M1] 수정**: phase03 plan "에셋(커밋 대상)" 섹션을 **명시적 un-bundle 절차**로 재작성 —
  `complete 3` → `reset --soft HEAD~1` → 무관 art `reset HEAD --` unstage → `git diff --cached` 확인 → 재커밋.
  `.import` 커밋 금지(gitignore) 명시. 무관 art는 untracked 복귀(사용자 art-untracked 정책 준수).

### Self-Review Round 2 (2026-06-02) — Codex R1 수정물 자체 검토
Verdict: **clean (CRITICAL/HIGH 0, MEDIUM 0)**.
- `run_test.py --import` 추가는 기존 씬-실행 경로 무변경(argv[1]=="--import" 분기만 선행) → 타 phase verify 회귀 없음. import는 one-shot quit이라 hang 없음. 실패 시 `&&` 체인 중단 → verify fail 전파.
- status.json verify가 phase md frontmatter와 동기(sync-status) → markdown↔status 불일치 없음.
- M1은 art-untracked 사용자 정책상 tree에서 art를 영구 제거할 수 없으므로, 완료-시점 결정적 un-bundle로 "결과 커밋이 정확히 의도 파일만 포함"을 보장(codex 권고 "explicit allow-list" 충족).
→ self-review clean → codex 재리뷰 진행.

## Codex Round 2 (2026-06-02)

Verdict: **needs-attention** — CRITICAL/HIGH 0 · MEDIUM 1. (M2 해소 확인 — 재지적 없음.)

- **[medium] M1-bis** un-bundle 절차가 현재 tree의 untracked phase 문서를 미처리: `RESUME-phase3-2026-06-01.md`는
  whitelist 밖(`phase*.md` 패턴 불일치) → `complete`가 step 10에서 abort. `reviews/phase03-plan-review.md`는
  whitelisted라 staging되나 expected keep-list에서 누락. → 결정적 완료 워크플로 아님.

정당한 정밀 지적 → 수정.

### 수정 (Codex Round 2 대응)
- WHITELIST_PATTERNS 실측(execute.py:308-340): `phases/{task}/phase*.md` + `reviews/*.md` + `status.json`만 매칭.
  `RESUME-*.md`는 어느 패턴도 불일치 → 확정 outside.
- **RESUME-phase3-2026-06-01.md 삭제** — Phase 3 재개 목적 달성한 transient 핸드오프. 삭제로 outside-whitelist abort 블로커 제거.
- un-bundle 절차 재작성: **step 0 전제**(whitelist-밖 untracked 없음 확인) 추가, **keep-list에 `reviews/phase03-plan-review.md` 포함**,
  expected 출력을 **정확히 16개**로 명시(8 PNG + 5 tracked code/doc + phase03.md + status.json + impl/plan review 2).
- 사이즈 가드 확인: candidate ~27 ≪ `LARGE_COUNT`=100, PNG 각 ~5KB ≪ 5MB/25MB → complete 통과(abort 없음 → un-bundle 도달 보장).

### Self-Review Round 3 (2026-06-02)
Verdict: **clean (CRITICAL/HIGH 0, MEDIUM 0)**.
- `git status --short --untracked-files=all` 실측: 현재 모든 untracked가 whitelist 내(assets/** 또는 phases/{task}/{phase*.md,reviews/*.md}).
  outside-whitelist 파일 0 → complete step 10 abort 불가.
- un-bundle keep-list(16) = (tree 전체 − 무관 art 10) 정확 일치. unstage 6 pathspec(concepts dir + stair_flip + _preview + biscuit×3)이 무관 art 10개를 전부 커버.
- RESUME 삭제는 untracked 파일 제거라 git 이력/스테이징에 영향 없음.
→ self-review clean → codex 재리뷰 진행.

## Codex Round 3 (2026-06-02)

Verdict: **needs-attention** — CRITICAL/HIGH 0 · MEDIUM 1. (완료 워크플로↔tree 일치 확인.)

- **[medium] M1-ter** keep-list에 포함된 `phase03-plan-review.md:29`가 L1을 아직 "8 PNG + 8 `.png.import`"로 기록
  → 커밋될 phase docs 간 cross-doc 불일치(plan/impl review는 `.import` 미커밋). stale 기록을 따르면 자산-staging 리스크 재현.

정당한 cross-doc 지적 → 수정.

### 수정 (Codex Round 3 대응)
- `phase03-plan-review.md`에 **날짜 박은 정정 노트**(impl 단계 2026-06-02) 추가: L1의 ".png.import stage" 부분 **무효(superseded)**,
  PNG 8개만 커밋·`.import`는 `--import` 재생성·force-add 금지 명시 + 최종 staging SoT 포인터. 원본 finding/반영 기록은 이력으로 보존.
- 4개 keep-list docs(plan/plan-review/impl-review + TERRAIN_TILE_RULES §4) 전부 "PNG 8개만, `.import` 미커밋" 일치 확인(grep 대조).

### Self-Review Round 4 (2026-06-02)
Verdict: **clean (CRITICAL/HIGH 0, MEDIUM 0)**.
- grep 대조: phase03.md / plan-review(정정 후) / impl-review / TERRAIN_TILE_RULES.md §4 모두 동일 staging 규칙. plan-review는
  "원본 기록 + supersede 정정" 병존이라 독자가 최종 규칙을 오인하지 않음.
- 런타임 코드 무변경(R1 이후 동일) — 회귀 verify는 이미 PASS 박제.
→ self-review clean → codex 재리뷰 진행.

## Codex Round 4 (2026-06-02)

Verdict: **approve** — **No material findings.**

> Ship: stale plan-review `.png.import` instruction은 dated 2026-06-02 note로 명시 supersede됐고, 최종 staging SoT가
> 정정된 plan/impl docs를 가리키며, kept docs 전부 "PNG-only commit + `.import`는 `--import` 재생성 + force-add 금지"로 일관.

### 종결
impl-stage 루프 clean(Codex R4 approve). 라운드 요약: Self-R1 → Codex R1(M1·M2) → Self-R2 → Codex R2(M1-bis) →
Self-R3 → Codex R3(M1-ter) → Self-R4 → **Codex R4 approve**. CRITICAL/HIGH는 전 라운드 0; 모든 MEDIUM은 완료-프로세스
재현성/cross-doc 정합(런타임 코드 무관)으로 전부 수정 완료. → `complete 3` + un-bundle 진행 가능.
