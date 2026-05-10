# Phase 6 — Deferred items

CLAUDE.md 정책: impl review에서 MEDIUM/LOW finding은 deferred 가능 (CRITICAL/HIGH는 즉시 수정).

## codex impl review Round 1 (2026-05-10) — deferred

### MEDIUM-D1: empty/degraded spawner regression test

**근거**: codex impl review 2026-05-10 R1 finding

**내용**: AntSpawner.start가 `total <= 0` 또는 `ant_scene == null`일 때 `spawn_finished`를 동기 emit하는 path가 있다. 이 시나리오에서 StageRunner가 prompt `no_more_ants` 결과를 produce하는지 검증하는 regression test가 없다.

**현재 상태**: phase 6 코드 자체는 connect-before-start 순서 fix로 동기 emit도 안전하게 잡도록 수정 (StageRunner.gd codex impl R1 R2 라인). 그러나 `total_ants = 0` 또는 missing `ant_scene`을 의도적으로 설정한 stage data 기반 헤드리스 회귀 테스트는 추가하지 않았다.

**처리 위치**: post-Phase 6 sweep 또는 phase 8(input-pause-step) 작업 중 stage 진행 robustness 검증할 때 함께. 별도 stage data fixture 추가 필요 (`data/stages/stage_empty.tres`) + 헤드리스 driver.

**위험도**: 낮음. phase 6 시점 stage 1~3은 모두 정상 configuration이라 production 영향 없음. 미래 stage configuration 오류 또는 dynamic spawn 추가 시 가드용.
