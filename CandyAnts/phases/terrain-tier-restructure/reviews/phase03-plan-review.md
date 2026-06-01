# Plan-stage Adversarial Review — Phase 3 (square-tile-art-swap)

## Round 1 (codex, 2026-06-01)

Target: working tree diff (untracked plan `phase03-square-tile-art-swap.md`; NO code changed)
Verdict: **needs-attention** (CRITICAL/HIGH 0 · MEDIUM 2 + LOW 1)

Findings:
- **[medium] M1** Variant formula `posmod(cell.x + cell.y, 4)`가 대각 밴딩 유발 + 테스트가 그 공식을 그대로
  검증하면 아티팩트를 박제 (`phase03-square-tile-art-swap.md:28`). 큰 solid/background 필드에서 NW-SE 대각마다
  같은 variant → 반복 띠. 권장: 비선형 좌표 해시 + 밴딩을 잡는(공식 복제 아님) 테스트.
- **[medium] M2** verify가 shared builder를 바꾸면서 cell_size=32 `dev_*_layout.tres`를 검증 안 함
  (`phase03-square-tile-art-swap.md:21-23`). `_apply_square_tile`에 숨은 48px 가정이 있으면 32px에서 크롭/오프셋/
  스케일 회귀를 놓침. 권장: 32px solid+background build로 `region_enabled==false`/중앙/`scale==32/tex` assert.
- **[low] L1** untracked art 제외가 `.import` 사이드카를 명시적으로 제외 안 함 (`phase03-square-tile-art-swap.md:35-38`).
  같은 디렉토리에 미사용 PNG의 `.import`가 있어 광역 `*.import` add 시 미배포 자산 메타데이터가 잘못 커밋될 수 있음.
  권장: 정확히 8 PNG + 8 `.png.import`만 explicit pathspec, 제외 PNG·그 `.import`도 명시 제외.

Next steps (codex): variant 전략/테스트 보강, 32px 커버리지 추가, 자산 staging 정확화.

### 처리
Plan-stage 정책(CLAUDE.md 2026-05-25, 3-round cap): CRITICAL/HIGH 0 → STOP 불필요. MEDIUM/LOW만 남으면 plan
내 처리 또는 명시 defer로 종결. 세 지적 모두 plan을 더 정확하게 만들므로 **반영**(defer 없음). 추가 codex 라운드 불요.

- **[M1] 반영**: variant 선택을 `posmod(a*x+b*y, 4)` 선형식 → **비선형 bit-mixing 정수 해시 `_variant_index(cell, n)`**로
  변경(결정적·분산). 테스트는 "유효 4 variant 중 하나 + 결정성 + 넓은 필드에 2개 이상 등장"만 검증, **공식 복제 금지**.
- **[M2] 반영**: `test_StageLayoutBuilder`에 **cell_size=32 합성 케이스** 추가 — `region_enabled==false`/중앙/
  `scale==Vector2(32/tex_w, 32/tex_h)` assert. 비-48 shared builder 회귀 가드. 별도 32px 헤드리스 씬 불요.
- **[L1] 반영**: 정확히 8 PNG + 8 `.png.import`만 explicit pathspec stage. 제외 PNG·`.import`도 명시 제외, 광역 add 금지.

> **정정 (impl 단계, 2026-06-02)** — 위 [L1] 반영의 "`.png.import` stage" 부분은 **무효(superseded)**.
> impl 단계에서 `*.import`가 repo 전역 `.gitignore:10` 대상임을 확인함(기존 terrain PNG도 `.import` 없이 트래킹).
> → Phase 3 커밋은 **PNG 8개만**, `.import`는 커밋하지 않고 `python scripts/run_test.py --import`(verify에 포함)로 재생성한다.
> `.import` force-add(`git add -f`) 금지. L1의 "미사용 PNG `.import` 혼입" 리스크는 gitignore가 원천 차단.
> 최종 staging 규칙 SoT = `phase03-square-tile-art-swap.md`(에셋 섹션 + un-bundle 절차) + `phase03-impl-review.md`.

verdict: MEDIUM 2 + LOW 1 plan 반영 완료 → plan-stage 종결.

### ⏸ 구현 보류 (2026-06-01)
plan은 ready이나, 같은 working tree에서 **병렬 작업**(stair 동적 타일: `Terrain.gd`/`WorkerState.gd` +
`cookie_stair_tile*.png`, 엔티티 씬 `Candy.tscn`/`Home.tscn`)이 진행 중. 사용자 결정 = **병렬 작업 먼저 정리(커밋)
되어 tree가 깨끗해진 뒤 Phase 3 구현 재개.** 재개 시 `python scripts/execute.py terrain-tier-restructure next`로
Phase 3 진입.
