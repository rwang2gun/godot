# Phase 7 Implementation Adversarial Review

- **실행 시각**: 2026-05-10
- **포커스**: phase 7 impl: input pad + virtual cursor (v2 plan 기준 19/19 헤드리스 PASS)
- **scope**: working-tree
- **base ref**: 7a0487fa35c39ea426f2e4b2414e659347d1b136

## Self-Review Round 1

자체 가혹 리뷰. CRITICAL/HIGH/MEDIUM/LOW + cross-doc 일관성 + dead branch + circular SoT + fixture redundancy + 시간적 위험.

### Cross-doc 일관성
- plan v2 §변경 파일 ↔ 실제 working tree: VirtualCursor.gd/.tscn, CursorTargeting.gd, CursorTargetingResolver.gd, InputRouter.gd 본체, SceneFlow.gd RESTART_STAGE 라우터 + active stage provider, Main.tscn 신규 노드 2개, project.godot 패드 binding + pad_cursor_*, GameActionContractTest whitelist, Ant.is_alive() — 모두 매치. ✓
- plan v2 §시그널 흐름 ↔ 구현 코드 path: 좌 스틱 → _emit_cursor_move 단일 경로 / 패드 A → _emit_positional / D-Pad → throttle → _emit_positional / 패드 B raw → _on_pad_b/_tick_b_button / RESTART_STAGE → SceneFlow → request_replay — 모두 일치. ✓
- plan v2 invariants 5개 ↔ phase07-input-pad-cursor.md inline invariants 5개 — 동일 문구·동일 의미. ✓
- 상수 (B_HOLD_THRESHOLD=1.0, PAD_STICK_DEADZONE=0.15, PAD_CURSOR_SPEED=800.0, TARGET_EMIT_COOLDOWN_MSEC=100): plan v2 §상수 ↔ InputRouter.gd ↔ phase07-input-pad-cursor.md ↔ docs/INPUT_PLAN.md §6 — 모두 정합. ✓

### 단일 SoT invariants
- `_emit_cursor_move`만이 CURSOR_MOVE 발화 + cache 갱신 진입점: 5개 호출 site 확인 (마우스 motion, 패드 stick polling, 첫 init, _emit_positional CURSOR_MOVE 분기, request_cursor_jump). EventBus.action_triggered.emit(GameAction.CURSOR_MOVE, ...) 직접 호출 grep 결과 0건. ✓
- SceneFlow 단독 RESTART_STAGE 소비자: SkillToolbar, VirtualCursor, CursorTargetingResolver의 _on_action grep — 어디도 RESTART_STAGE 소비 안 함. ✓
- SkillToolbar 디바이스 분기 금지: SkillToolbar.gd grep — Input.is_joy*, InputModeTracker, VirtualCursor, _virtual_cursor 참조 0건. ✓
- Active-stage filter는 resolver._gather_candidates 단일 경로. 다른 곳에서 get_nodes_in_group("ants") + active 필터 반복 없음. ✓
- Pad B InputMap 미등록: project.godot grep — JOY_BUTTON_B(button_index=1) 등록 0건. ✓

### Dead branch / unused code
- `_last_cursor_*` cache: phase 5 이후 KbCursorCacheTest로 검증 중. dead 아님. ✓
- VirtualCursor `_suppress_next_show` flag: VirtualCursorMousePassThroughTest로 검증. ✓
- request_cursor_jump: CursorTargetingResolver가 호출 + CursorTargetingActiveStageTest로 검증. ✓
- Pad B raw timer (`_b_pressed`, `_b_press_time`): PadButtonBHoldTest single+hold 둘 다 검증. ✓

### Circular SoT 점검
- plan v2 → 구현 코드 → tests: 일방향 의존. 코드가 plan을 참조하는 주석은 있어도 plan이 코드 detail을 SoT로 가리키지 않음. ✓
- SceneFlow.get_active_stage_node ↔ resolver._active_stage_root: SceneFlow 단방향 push (load_stage / _unload_current_stage에서 set_active_stage_root 호출). resolver는 read-only. ✓

### Fixture redundancy
- CursorTargetingTest는 순수 계산만 (FakeAnt extends Node2D + add_to_group 안 함 — 호출자 활성-stage 필터 책임 OK).
- CursorTargetingActiveStageTest는 통합 (Main.tscn + SceneFlow active stage provider). 두 테스트 책임이 분리됨. 중복 X.

### 시간적 위험 (다음 phase에서 첫 활성될 때 검증 0인 코드)
- InputRouter `process_mode = PROCESS_MODE_ALWAYS`: 다음 phase 8 pause 도입 시점에 처음 의미 발현. 본 phase에서는 가시 효과 없음. 그러나 phase 8 회귀 가드로 PadButtonBHoldTest의 1.1초 timer가 _process 의존인 것 자체가 검증의 일부 (테스트 결과 PASS).
- VirtualCursor.idle fade 5초: 본 phase 자동 회귀 없음 (시간 비용 + headless 시각 검증 어려움). 수동 검증으로 위임. **MEDIUM (deferred)**.

### Hypothetical 위험 — implementer가 잘못할 수 있는 곳
- (M) InputRouter에 새 positional 액션 추가 시 GameAction.POSITIONAL_ACTIONS도 갱신 필요한데 잊을 가능성. 기존 phase 5 정책 유지 — 변경 없음, 본 phase에서 새 positional 추가 0건.
- (L) project.godot에 패드 button_index를 손으로 적었는데 Godot 4.6 keymap이 미래에 변경될 가능성. button_index 0~14는 stable. 안전.

### 발견된 위험 정리
- HIGH/CRITICAL: **0건**. ✓
- MEDIUM: 1건 — VirtualCursor idle fade 회귀 0 (수동 위임).
- LOW: 0건.

### 자체 리뷰 verdict: clean (HIGH 0건). codex 재리뷰 진입 가능.

---

## Round 1 (codex)

- **포커스**: phase 7 impl: pad + virtual cursor + RESTART_STAGE routing + active-stage scoping (19/19 headless PASS)

# Codex Adversarial Review

Target: working tree diff
Verdict: needs-attention

No-ship: the working tree adds a hidden external notification path to the phase completion workflow, creating an avoidable trust-boundary and metadata-leak risk outside the requested game input changes.

Findings:
- [high] Phase workflow can silently exfiltrate repository metadata to Discord (CandyAnts/scripts/execute.py:118-129)
  `cmd_complete` now calls `_notify(...)` on verify failure, successful phase completion, task completion, rollback failure, and commit failure. `_notify` unconditionally shells out to `scripts/notify.py` when that file exists; `notify.py` sends the supplied message to `DISCORD_WEBHOOK_URL`. This means anyone running the normal phase completion command with that env var set will send task names, phase names, commit SHA, durations, verify commands, and failure state to an external webhook without an explicit CLI opt-in at the call site. Impact is a hidden network side effect in a local repo workflow and possible leakage of project metadata or command contents.
  Recommendation: Remove the notifier from `execute.py`, or gate it behind an explicit command-line flag/config value such as `--notify discord` plus clear documentation of the exact fields sent. Do not trigger external webhooks merely because `DISCORD_WEBHOOK_URL` happens to be present in the environment.

Next steps:
- Block the working-tree change until the phase workflow has no implicit external notification side effect.
- After removing or explicitly gating notifications, re-run the review against the remaining phase 7 input/runtime changes.

**Round 1 처리**: codex 권고에 따라 `_notify`를 `--notify` CLI 플래그 뒤로 게이트(_NOTIFY_ENABLED 모듈 전역 + main()에서 argv 파싱). 환경변수만으로 실행 안 되도록 변경. 이 변경은 phase 7 본 작업 외이지만 working tree에 합쳐져 있어 codex가 잡음 — CLAUDE.md impl HIGH 정책상 즉시 수정.

## Self-Review Round 2 (notify 게이트 후)

자체 점검:
- `_NOTIFY_ENABLED = False` 모듈 전역 기본값. ✓
- main()에서 `--notify` 발견 시 True로 설정 + sys.argv에서 제거 → 이후 positional 파싱 정상. ✓
- _notify(message) 진입 시 `if not _NOTIFY_ENABLED: return` 조기 반환. ✓
- 비-게이트 경로: `cmd_complete` 등에서 _notify 호출은 그대로 유지. 게이트는 호출 site가 아닌 `_notify` 내부에서 결정 → 향후 다른 호출자 추가 시도 자동 보호. ✓
- 검증: `python scripts/execute.py mvp validate` 정상 동작. ✓

자체 리뷰 R2 verdict: clean. codex 재리뷰 진입.

---

## Round 2 (codex)

- **포커스**: phase 7 impl R2: notify gated behind --notify flag (HIGH addressed)

# Codex Adversarial Review

Target: working tree diff
Verdict: approve

Ship assessment: I do not see a defensible blocking issue in R2. `execute.py` now defaults notifications off, only enables them when `--notify` is present, strips that flag before normal command parsing, and `_notify()` itself returns before touching `notify.py` unless the explicit gate is set.

No material findings.

**최종 verdict: approve. Impl-stage clean — phase 7 complete 진입.**
