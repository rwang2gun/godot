---
name: basher-exposed-surface
duration_estimate: 3600
verify: python scripts/run_test.py tests/BasherExposedSurfaceTest.tscn && python scripts/run_test.py tests/DiggerExposedSurfaceTest.tscn && python scripts/run_test.py tests/Stage03HeadlessTest.tscn
large_change_ok: false
sot: docs/TERRAIN_TILE_RULES.md
sot_aux: [scripts/world/Terrain.gd, scripts/ant/states/WorkerState.gd, phases/skill-tile-surface/REVISION_2026-06-01-skill-tile-surface.md]
---

# Phase 3: basher-exposed-surface

## 목표
basher(가로 굴착)가 터널을 뚫을 때, 뚫린 칸 **바로 아래(터널 바닥)**가 새 walkable 윗면이 되면
거기에 cookie surface 캡을 입힌다. **이것이 Stage 3의 실제 굴착 스킬이자 사용자가 처음 보고한
"어색함"의 진짜 원인** (Stage 3 available_skills = ["basher"], digger 없음).

## 배경 / 스코프 정정
- 최초 요청은 "땅파기"였으나 Stage 3의 실제 스킬은 **basher**(가로). 사용자 확정: digger/basher 혼동,
  "횡으로 팠을 때 걸을 수 있는 면(surface)이 더 중요".
- Phase 2 plan-stage 리뷰의 HIGH("basher에 캡이 새면 안 된다")는 **basher를 스코프 밖으로 둔다는 전제**에서
  맞았다. 이제 사용자가 basher를 명시적으로 스코프 안으로 넣음 → 그 전제가 바뀌었으므로 의도적으로 반영.
- `basher`의 뚫린 칸 = `body_cell + (direction, 0)`. 그 **아래 칸** = `+ (0,1)` = 터널 바닥 →
  Phase 2의 `_cap_exposed_below`가 바로 그 칸을 캡한다 (동일 메커니즘, 이미 구현·리뷰됨).

## 변경 대상
- `scripts/ant/states/WorkerState.gd`
  - `_destroy_basher_cell`의 `terrain.destroy_tile_at(target, ["earth"])` →
    `terrain.destroy_tile_at(target, ["earth"], true)`로 opt-in 활성화.
- (Terrain 코드 무변경 — `_cap_exposed_below` / `_is_solid_cookie_body` 재사용.)
- cutter는 계속 기본 false 유지 (식물 절단, surface 무관).

## ⚠️ Plan 리뷰 HIGH 반영 — 모순 테스트 계약 정리 (필수)
Phase 2에서 `DiggerExposedSurfaceTest._test_basher_does_not_cap_below()`가 "basher는 캡 안 함"을
단언했는데, 이제 basher가 캡하므로 모순. 해소:
- `DiggerExposedSurfaceTest`: `_test_basher_does_not_cap_below` → `_test_no_cap_when_optin_false`로 재정의
  (의미: opt-in=false 경로 = cutter 등은 캡 안 함. cap=false 유지 → 여전히 유효한 계약). "basher" 부정 주장 제거.
- 신규 `BasherExposedSurfaceTest`: basher(opt-in=true) positive 계약 검증 (터널 바닥 캡 + slope 미적용 + 중복 방지).
- phase03 verify 체인에 `DiggerExposedSurfaceTest.tscn` 포함 → 낡은 phase2 기대가 살아남지 못함.

## 비목표
- 터널의 **세로 측벽**(파낸 단면) surface — 범위 밖(기존과 동일).
- bridge·builder 동적 타일 — Phase 4.

## 검증 방법
- 신규 `tests/BasherExposedSurfaceTest.gd`: basher가 뚫은 칸 아래 정적 solid에 surface 캡 1장 추가 +
  slope-below 미적용 + 이미 SurfaceSprite 있는 칸 중복 방지(Phase 2 가드 재확인).
- `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` — Stage 3 회귀 0 (basher 게임플레이 불변).
- 기존 basher 회귀(BasherTunnelThroughWallTest / BasherEdgeStopTest / BasherOnPlantRejectedTest) 통과 유지.
- dev: `data/stage_layouts/dev_basher_wall_layout.tres` 등으로 터널 바닥 surface 시각 확인.
