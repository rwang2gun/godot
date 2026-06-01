# Phase 4 (basher-headroom-tier) — Plan-stage Adversarial Review

## Round 1 (codex, 2026-06-01)
Target: working tree diff | Verdict: **needs-attention** (HIGH 1 + MEDIUM 1)

- **[high]** verify 게이트가 plan이 "보존 필수"라 명시한 basher 회귀를 누락
  (phase04 verify는 BasherHeadroomTier+BasherExposedSurface+Stage03만, BasherTunnelThroughWall/EdgeStop/OnPlantRejected 빠짐).
  위로 2배 파괴라 edge-stop/plant-reject/tunnel-through에서 회귀가 날 지점인데 게이트 통과 가능.
  Rec: 3개 회귀를 verify + status.json에 추가.
- **[medium]** 머리공간(above) 파괴가 무관한 earth(동적 bridge/sand/builder, 윗길 바닥)까지 제거 — 게임플레이 계약 미정의.
  Rec: above 제거를 정적 solid cookie로 한정하거나, 전체 earth 의도면 오버헤드 구조물 회귀 테스트 추가.

### 처리 — 사용자 결정 (2026-06-01)
- **MEDIUM (설계)**: "정적 쿠키 벽만 제거" 선택 → above 제거를 정적 solid cookie 셀로 한정.
  동적 타일(bridge/sand/builder, `_placed`)·slope·plant는 보존. 신규 Terrain `destroy_static_cookie_cell(cell)`로 가드.
- **HIGH (게이트)**: BasherTunnelThroughWall/EdgeStop/OnPlantRejected를 phase04 verify 체인 + status.json에 추가.
- 둘 다 plan 반영 후 구현 진행 (재리뷰 없이; plan-stage 정책상 사용자 결정으로 진행).
