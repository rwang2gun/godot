# Phase 1 (surface-skin-infra) — Impl-stage Adversarial Review

## Round 1 (codex, 2026-06-01)

Target: working tree diff
Verdict: **approve**

No defensible no-ship finding in the reviewed Phase 1 diff. The new overlay path is visual-only,
null-safe for missing registration/body, and its region sampling matches StageLayoutBuilder.
The hardcoded under/background registration is a real limitation, but it mirrors existing builder
behavior and is not used by the new overlay helper, so it cannot justify blocking this infra-only phase.

No material findings.

Next steps (codex, non-blocking — Phase 2/3 대상):
- Phase 2/3 전에, 첫 적용 후 cap 모양을 바꾸려는 호출자가 있다면 다른 geometry로 재호출하는 테스트 추가.
- non-cookie_crust 동적 3-tier 사용 전에 under/background 등록을 theme-aware로 바꾸거나 API를 surface-only로 좁힐 것.

### 자체 적대적 리뷰 (self)
codex finding 0건 → CLAUDE.md impl-stage 정책상 자체리뷰 사이클 불요(finding 발생 시에만 트리거).
보강 점검 결과 추가 위험 없음:
- `apply_cookie_surface_overlay` 멱등: `has_node(COOKIE_SURFACE_CAP_NAME)` 선검사로 1장 보장. 현재 호출자는
  body당 1회만 적용 → 재호출-다른-geometry 시나리오는 Phase 2/3 설계상 미발생. codex next-step은 향후 가드로 기록.
- `_configure_cookie_region`은 `_configure_repeating_region`과 동일(source_size/posmod variant/세로 중앙/scale). drift 없음.
- 기존 destroy_tile_at/add_tile/sand/static 경로 무변경 → D8·atomic invariant 불변. 회귀 테스트 2종 PASS로 확인.
- theme: cap이 쓰는 surface만 theme-aware(`_surface_texture()`), under/background는 미소비 → Phase 1 무해.

### 검증
- `tests/CookieSurfaceOverlayTest.tscn` PASS (5케이스: 등록/셀캡/멱등/narrow geometry/null-safe)
- `tests/test_StageLayoutBuilder.tscn` PASS (invariant 회귀 0)
- `tests/Stage03HeadlessTest.tscn` PASS (스테이지 회귀 0)

Verdict: clean — Phase 1 완료 진행.
