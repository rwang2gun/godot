# Phase 8 Deferred

Phase 8 (input-pause-step) codex impl-review Round 2 verdict **clean** (CRITICAL/HIGH 0건). 본 문서는 Round 2에서 새로 발견된 MEDIUM/LOW 항목을 CLAUDE.md 정책에 따라 deferred 처리.

| Severity | ID | File:Lines | 내용 | 처리 방향 |
|---|---|---|---|---|
| MEDIUM | R2-M1 | `tests/PausedAssignTest.gd:89-96` | `btn.disabled = false` 강제 + `btn.pressed.emit()` 직접 호출이 실제 Control mouse dispatch 경로(hit-test / disabled refresh / mouse_filter / parent visibility)를 검증하지 않음. invariant + signal 분리 검증으로 일부만 cover. | Phase 9/10(UI theme/atoms) 진행 시 SkillToolbar 교체와 함께 paused click path를 stage-level integration test로 추가. Phase 10 sweep에서 처리. |
| LOW | R2-L1 | `tests/StepFrameTest.gd:52-59,106-110` | StepFrame test가 `physics_ticks >= 1` / `<= 2`만 assert — "정확히 1 tick" 계약을 lock하지 못함. 2-tick 회귀 시 silent pass. | StepFrame 구현이 catch-up 안전 패턴이므로 정상 동작 시 항상 1 tick. tighter assert로 변경하면 헤드리스 timing variance에서 flaky 가능. 일단 deferred — 실제 catch-up 회귀가 등장하면 그때 정밀화. |
| LOW | R2-L2 | `phases/mvp/phase08-input-pause-step.md` | (해결됨, Round 2 후속) `sot:` frontmatter는 컨벤션상 docs/ 유지, 본문은 plan v2 기준으로 갱신. INPUT_PLAN.md §7에 v2 redirect 노트 포함. | 해결 — 본 deferred에 기록만. |
| LOW | R2-L3 | `phases/mvp/plans/phase08-progress.md` | (해결됨, Round 2 후속) §5 stale 부분에 §8 정정 노트 추가. 최신 SoT는 review 로그 명시. execute.py phase glob 충돌로 `phases/mvp/plans/phase08-progress.md` 경로로 배치(plans/*.md 화이트리스트 매치). | 해결 — 본 deferred에 기록만. |

## CLAUDE.md 정책 근거

> CLAUDE.md plan-stage/impl-stage 정책:
> - impl-stage codex 재리뷰 결과 `CRITICAL/HIGH 0건` = clean.
> - MEDIUM/LOW만 `phaseNN-deferred.md` 허용.
> - 사후(=phase 커밋 후) 리뷰에서 HIGH 발견 시 즉시 후속 hot-fix.

본 phase 종료 후 다음 phase 진입 전까지는 본 deferred 항목들이 HIGH로 격상되지 않는지 모니터. R2-M1은 Phase 10/11 UI 교체 phase에서 자연스럽게 cover 가능.
