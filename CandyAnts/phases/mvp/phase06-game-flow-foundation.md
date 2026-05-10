---
name: game-flow-foundation
duration_estimate: 7200
verify:
large_change_ok: false
sot: docs/GAME_FLOW_PROPOSAL_V5.md
sot_aux: [phases/mvp/REVISION_2026-05-09.md]
---

# Phase 6: Game Flow Foundation

## 목표

Stage01 직접 실행 구조를 벗어나 `Main` / `SceneFlow`가 stage 1~3 플레이 세션을 소유한다. Clear/Fail 이후 Replay/Next/Menu 요청을 처리하는 최소 게임 루프를 완성한다.

## 전제

- Phase 5 완료 (InputRouter, `EventBus.action_triggered`)
- Pre-Phase 6 hot-fix 완료 (`ScoreSystem.stop()` + EventBus disconnect)
- `docs/GAME_FLOW_PROPOSAL_V5.md`가 1차 SoT

## 변경 대상 (요약 — 상세는 GAME_FLOW_PROPOSAL_V5 §3.2)

**신규**:
- `scripts/core/SceneFlow.gd`
- `scripts/ui/StageResultOverlayStub.gd`
- `scenes/ui/StageResultOverlayStub.tscn`
- `tests/GameFlowTest.gd`, `tests/GameFlowTest.tscn`

**수정**:
- `project.godot` — main scene을 `res://scenes/Main.tscn`으로 변경
- `scenes/Main.tscn` — `SceneFlow` / `CurrentStageRoot` (빈 Node) / `GlobalUI` (CanvasLayer layer=10) / `StageResultOverlayStub` 배치
- `scripts/core/EventBus.gd` — `stage_cleared(result: Dictionary)` / `stage_failed(result: Dictionary)`로 signature 변경 + `request_replay` / `request_next` / `request_menu` signal 추가
- `scripts/core/StageRunner.gd` — Dictionary payload emit, `_make_result()` helper 추가, `_living_ant_count()` helper, no_more_ants 판정 추가, callback signature 변경
- `scripts/core/ScoreSystem.gd` — 결과 payload용 4 카운터 노출 유지
- `scripts/core/GameManager.gd` — boot 검증 외 game flow 책임은 SceneFlow로 이양
- `tests/Stage02HeadlessTest.gd`, `tests/Stage03HeadlessTest.gd` — callback signature를 Dictionary로 변경

## 검증 방법 (요약 — 상세는 plan)

1. `Main.tscn` → Stage01 자동 로드
2. Stage01 clear → Next 버튼 → Stage02 로드
3. Stage02 fail → Replay 버튼 → Stage02 재시작
4. Stage03 clear → Next 버튼 disabled, `request_next` 직접 emit 시 `go_to_menu()` fallback (Stage01 reload)
5. Menu 버튼 → Stage01 reload (Phase 13에서 실제 menu로 교체)
6. 결과 overlay 표시 중 stage simulation 정지 (`CurrentStageRoot.process_mode = DISABLED`)
7. `no_more_ants` 실패가 time_out 전에 발생
8. 결과 Dictionary 8 키 모두 채워짐
9. `tests/Stage02HeadlessTest.tscn` / `tests/Stage03HeadlessTest.tscn` 직접 실행 경로 회귀 (run_test.py는 scene path 직접 실행 → main scene 변경과 독립)
10. `tests/GameFlowTest.tscn` 통과

## 엣지 케이스

- Phase 6 시점에서 Stage01 도중 Menu 클릭 = Replay와 같은 결과 (허용)
- 결과 overlay 첫 클릭 즉시 모든 버튼 disabled, hide 시 reset (중복 클릭 방지)
- 모든 stage scene은 `process_mode = INHERIT` (default) 유지

## 비범위

- TitleScene / MainMenu / StageSelect / SaveData → Phase 13
- 본격 StageDialog UI (stars / motion / saved/lost 상세) → Phase 12
- gamepad virtual cursor → Phase 7
- typed `StageResult` Resource → post-MVP
- `request_stage_select` signal → Phase 13
- 명시적 `AntSpawner.stop()` → 불필요 (process_mode DISABLED로 자동 정지)

## 표준 절차

plan은 `phases/mvp/plans/phase06-plan.md`에 작성. review는 `phases/mvp/reviews/phase06-review.md` (plan stage) / `phase06-impl-review.md` (impl stage). 상세 결정 사항은 `docs/GAME_FLOW_PROPOSAL_V5.md` 본문 참조.
