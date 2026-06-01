# Phase 3 (basher-exposed-surface) — Impl-stage Adversarial Review

## Self-Review Round 1 (2026-06-01)
구현: `WorkerState._destroy_basher_cell`가 `destroy_tile_at(target, ["earth"], true)`로 opt-in 활성화.
Terrain 코드 무변경 — Phase 2의 `_cap_exposed_below`/`_is_solid_cookie_body`(검증 완료) 재사용.
테스트 계약: `DiggerExposedSurfaceTest._test_basher_does_not_cap_below` → `_test_no_cap_when_optin_false`
(opt-in=false=cutter 경로 의미로 재정의, cap=false 유지). 신규 `BasherExposedSurfaceTest`로 basher positive 검증.

HIGH 0건:
- geometry: target=body_cell+(dir,0), below=+(0,1)=터널 바닥 → 정확. BasherExposedSurfaceTest로 실주행 확인.
- below 공기/slope/이미-surface → 기존 가드(`_cap_exposed_below`)가 모두 처리. basher가 새 분기 안 만듦.
- cutter는 기본 false 유지 → 무영향. D8/atomic 불변(Terrain 무변경).
- 테스트 모순 제거: false-경로 계약(cutter) + basher positive 계약 분리. verify 체인에 Digger+Basher+Stage03 포함.

검증: BasherExposedSurfaceTest PASS(실주행 터널 바닥 캡), DiggerExposedSurfaceTest PASS,
basher 회귀 3종/digger 회귀/CookieSurfaceOverlay/Stage03 전부 PASS. → 자체 clean, codex 리뷰 진행.

## Round 1 (codex, 2026-06-01)
Target: working tree diff | Verdict: needs-attention (MEDIUM 1)
- **[medium]** Phase 3 verify metadata drops the digger reconciliation test (status.json:phase03)
  status.json의 캐시 verify가 frontmatter 갱신을 안 따라가 DiggerExposedSurfaceTest 누락 → 추적 메타데이터 stale.
  (실제 complete 게이트는 phase 파일 frontmatter를 읽으므로 동작은 정상이나, 메타 일관성 지적은 타당.)
codex: "the implementation path looks coherent" — 코드 결함 0.

### 처리 (2026-06-01)
`sync-status`로 status.json 캐시 verify를 frontmatter와 동기화 → phase03 verify =
`BasherExposedSurfaceTest && DiggerExposedSurfaceTest && Stage03HeadlessTest`로 갱신 확인. completed 상태 무결.

## Round 2 (codex re-review, 2026-06-01)
Target: working tree diff | Verdict: needs-attention (MEDIUM 1)
- **[medium]** stale basher-negative 문구가 tracked spec/주석에 잔존 (DiggerExposedSurfaceTest 헤더, Terrain.gd:72-73, WorkerState.gd:430-431)
  실행 테스트는 opt-in=false로 리네임됐으나 헤더/주석이 "basher 기본 false·캡 미추가"로 남아 새 동작과 모순.
codex: status.json gate·런타임 basher call은 정상 — 코드 결함 0, 문서 일관성만.

### 처리 (2026-06-01)
3곳 모두 갱신: DiggerExposedSurfaceTest 헤더(opt-in=false 일반화 + basher는 Phase3에서 true 캡 명시),
Terrain.gd destroy_tile_at 주석(digger+basher 둘 다 opt-in=true, cutter만 false), WorkerState.gd digger 주석.
grep 확인: stale basher-negative 문구·`does_not_cap` 함수명 잔존 0. 검증: phase03 verify 체인 3종 PASS.

## Self-Review Round 2 (2026-06-01)
HIGH 0: 변경은 주석/헤더 문서뿐(로직 무변경). grep로 stale 문구 잔존 0 확인. 모든 spec이 일관:
opt-in=true=굴착(digger·basher) 캡 / opt-in=false=cutter 무캡. → 자체 clean, codex Round 3 진행.

## Round 3 (codex re-review, 2026-06-01)
Target: working tree diff | Verdict: needs-attention (MEDIUM 1)
- **[medium]** tracked Phase 2 spec(phase02 문서) + REVISION 스코프 문서가 여전히 "basher false/별도 task"로 기술 → Phase 3와 모순.
codex: 코드/테스트 주석은 OK(Round 2 해소), 남은 건 tracked 문서.

### 처리 (2026-06-01)
- `phase02-digger-exposed-surface.md`: 상단 SUPERSESSION 배너 추가 + 제목 Phase 2 정정 +
  비목표/검증 bullet 인라인 정정(basher는 Phase 3에서 opt-in true 캡; 구 가드는 cutter false 계약으로 재정의).
- `REVISION_2026-06-01-skill-tile-surface.md`: Phase 분해를 실제 순서(1 infra→2 digger→3 basher→4 bridge-builder)로
  개정, basher를 in-scope로 이동, 계약 명문화. SoT에 `_destroy_basher_cell` 추가.
- 잔존 grep 매치는 (a) reviews/*.md = append-only 감사 기록(불변), (b) phase03 문서의 reconciliation 설명,
  (c) supersession 배너/정정문 자체 → live spec에 모순 없음.

## Self-Review Round 3 (2026-06-01)
HIGH 0: 문서 일관성만 변경(로직·테스트 무변경). live spec(phase02/03 문서·REVISION) 전부 "굴착=opt-in true 캡,
cutter=false" 단일 계약으로 정합. 감사 기록(reviews)은 의도적으로 역사 보존. → 자체 clean, codex Round 4 진행.

## Round 4 (codex re-review, 2026-06-01)
Target: working tree diff | Verdict: needs-attention (MEDIUM 1)
- **[medium]** phase02 문서의 "Plan 리뷰 HIGH 반영" 섹션이 명령형("반드시 digger only", "_destroy_basher_cell false 유지")
  으로 남아 supersession 배너로 중화 안 되는 live imperative contract → Phase 3와 모순.

### 처리 (2026-06-01)
해당 섹션을 "opt-in 게이팅 설계"로 개제 + 현재 계약(digger·basher 둘 다 opt-in true, cutter false) 명문화 +
Phase 2 시점 basher-false 서술엔 "(Phase 2 시점)/(Phase 3에서 true로 supersede)" 인라인 표식. "변경 대상"도 동일 표식.
최종 grep: live spec(phase 문서·REVISION)에 명령형 basher-false 잔존 0 — 남은 매치는 전부 표식 달린 역사/설명/positive 계약.

## Self-Review Round 4 (2026-06-01)
HIGH 0: 문서뿐(로직 무변경). live spec 단일 계약 정합 확인. → codex Round 5 진행.

## Round 5 (codex re-review, 2026-06-01)
Target: working tree diff | Verdict: **approve** — No material findings.
"remaining basher-false references in phase02 are explicitly marked Phase-2-era/superseded, REVISION states the
current digger+basher opt-in true contract, and code/test comments align." → clean to ship.

### 최종: Phase 3 clean (codex approve). complete 진행.
