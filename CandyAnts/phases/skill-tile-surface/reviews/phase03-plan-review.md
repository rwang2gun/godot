# Phase 3 (basher-exposed-surface) — Plan-stage Adversarial Review

## Round 1 (codex, 2026-06-01)

Target: working tree diff (new phase03 plan + phase04 rename)
Verdict: **needs-attention**

No-ship: the plan reverses the basher contract but leaves the existing regression contract unaddressed.

Findings:
- **[high]** Basher cap reversal conflicts with existing digger regression guard (`phase03-basher-exposed-surface.md`)
  The phase flips `_destroy_basher_cell` to `destroy_tile_at(..., true)`, but `tests/DiggerExposedSurfaceTest.gd`
  still runs `_test_basher_does_not_cap_below()` asserting a basher-style destroy must NOT cap. Once flipped, the
  broader suite carries a stale opposite contract — phase03 verify looks green while the full suite fails / reviewers
  see two incompatible specs.
  Rec: Make the reversal explicit — update/retire the `DiggerExposedSurfaceTest` basher-negative case, add the
  positive basher case, and include `tests/DiggerExposedSurfaceTest.tscn` in phase03 verify.

### 처리 — 사용자 결정 (2026-06-01): "반영하고 진행" (재리뷰 없이)
- `DiggerExposedSurfaceTest`의 `_test_basher_does_not_cap_below`는 **opt-in=false 경로**(cutter 등)가 캡하지
  않음을 검증하는 의미로 재정의(rename `_test_no_cap_when_optin_false`, cap=false 유지). "basher가 캡 안 함"
  주장 제거 → 모순 해소.
- 신규 `BasherExposedSurfaceTest`가 basher(opt-in=true) 경로의 positive 계약(터널 바닥 캡 + slope/중복 가드)을 검증.
- phase03 verify 체인에 `DiggerExposedSurfaceTest.tscn` 포함 → 낡은 기대가 살아남지 못함.
