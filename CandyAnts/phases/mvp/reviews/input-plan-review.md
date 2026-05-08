# Input Mapping Plan — Codex Adversarial Review (Pre-Phase)

- **대상 문서**: `docs/INPUT_PLAN.md`
- **scope**: working-tree
- **base ref**: 4f1e483d65195f44c1b4b520a9feef31358f885a (main branch HEAD)
- **포커스**: input mapping impl plan: action layer + Mouse/KB + Pad virtual cursor
- **상태**: Round 11에서 codex usage limit 도달 (2026-05-09 02:47 AM 리셋). Round 10까지의 verdict 모두 `needs-attention`이며 각 회차마다 발견된 HIGH/MEDIUM 이슈는 모두 plan에 반영됨. Round 11 결과 미확인 — 추가 이슈 가능성 있음.

본 리뷰는 phase 진입 전 사전 계획 단계. README.md 표준 절차 Step 2(plan 단계 리뷰)에 해당하지만 단일 phase가 아닌 phase 5~7에 걸친 영향 범위라 별도 파일로 보존.

---

## Round 1

**focus**: input mapping impl plan: action layer + Mouse/KB + Pad virtual cursor (docs/INPUT_PLAN.md)
**verdict**: needs-attention

### Findings

- **[HIGH] Router/cursor payload mixes screen/UI coordinates with world coordinates** (CandyAnts/docs/INPUT_PLAN.md:129)
  계획은 `skill_assign.world_pos`를 InputRouter에서 마우스 `get_global_mouse_position()` 또는 패드 `VirtualCursor.global_position`으로 계산한다 했으나 현재 SkillToolbar는 `get_viewport().get_canvas_transform().affine_inverse() * mb.position`으로 screen→world 변환 후 `Ant.global_position`(world)와 비교. CanvasLayer의 Control 가상 커서는 screen-space이므로 `global_position`을 그대로 쓰면 카메라 pan/zoom 시 잘못된 ant 선택.
  **권고**: payload 계약을 명시 — InputRouter가 항상 `screen_pos` 우선 산출 → `CoordSpace.screen_to_world(...)`로 world 변환. shifted-camera 회귀 테스트 추가.

### 적용
§2 좌표 계약 신설 (CoordSpace.gd, payload에 screen+world 둘 다 동봉, 디바이스별 source 표). §5.6에 InputRouterShiftedCameraTest 추가. 리스크 표 추가.

---

## Round 2

**focus**: Round 2 after coordinate-space fix
**verdict**: needs-attention

### Findings

- **[HIGH] Pad assign path still treats screen-space cursor coordinates as world-space** (CandyAnts/docs/INPUT_PLAN.md:173-279)
  §6.1 SkillToolbar 마이그레이션 텍스트에 여전히 "VirtualCursor.global_position"이라는 표현 잔재.
  **권고**: device-specific `get_global_mouse_position()` / `VirtualCursor.global_position` world-pos 가이드 모두 삭제. SkillToolbar는 payload.world_pos만 사용.

- **[MEDIUM] Mouse movement is modeled as an InputMap action even though it will not fire that way** (CandyAnts/docs/INPUT_PLAN.md:58-154)
  마우스 모션은 `InputEventMouseMotion`이라 `InputMap.is_action_pressed("cursor_move")`로 못 잡힘.
  **권고**: `cursor_move`를 synthetic action으로 정의. InputRouter가 raw event 처리에서 직접 emit. 디바이스별 분기는 router 내부에서만.

### 적용
§6.1 SkillToolbar 변경 텍스트 수정 (디바이스 분기 X 명시). §4.1 표에 "InputMap" / "synthetic" 종류 컬럼 추가. Synthetic 발화 규약 신설. §2 책임 분리에 InputRouter 두 진입점(`_unhandled_input` + `_process`) 명시. 리스크 표 추가.

---

## Round 3

**focus**: Round 3 after coord-contract + synthetic action fixes
**verdict**: needs-attention

### Findings

- **[HIGH] Pad cursor flow violates the required screen/world payload contract** (CandyAnts/docs/INPUT_PLAN.md:321)
  §6.2 시그널 흐름이 `{position: ...}` 형식으로 emit (계약은 `{screen_pos, world_pos}`).
  **권고**: 계약 일치시키기 + pad shifted-camera 테스트 추가.

- **[HIGH] Plan reintroduces device-mode branching into SkillToolbar** (CandyAnts/docs/INPUT_PLAN.md:366)
  엣지 케이스에 SkillToolbar가 `_get_cursor_pos()`로 mode 분기. 책임 분리는 mode = UI 전용.
  **권고**: SkillToolbar에서 mode 분기 제거. payload.world_pos만 사용.

### 적용
§6.2 시그널 흐름 텍스트를 계약 일치형으로 재작성 (`screen_pos+world_pos`). 마우스+패드 동시 입력 엣지 케이스를 last-emit wins로 재정의 (SkillToolbar는 디바이스 분기 X). InputModeTracker는 UI 힌트 전용임을 명시.

---

## Round 4

**focus**: Round 4 after pad signal-flow + edge-case fixes
**verdict**: needs-attention

### Findings

- **[HIGH] Pad B is assigned to immediate and hold actions without a safe release-gated contract** (CandyAnts/docs/INPUT_PLAN.md:171-187)
  Pad B는 `skill_cancel`(단발), `restart_stage`(1초 홀드), `back_menu`(단발) 세 액션 매핑. `event.is_action_pressed`는 press 즉시 발화하므로 단발 emit 후 1초 후 홀드 또 emit = race + destructive.
  **권고**: B를 raw 처리. press 시 timer 시작 + `set_input_as_handled` 호출. release/expire 시점에 정확히 1개 액션 emit.

- **[MEDIUM] Coordinate contract is contradicted by direct global-position sources** (CandyAnts/docs/INPUT_PLAN.md:114-205)
  여전히 §2 책임 분리(line 62)와 §4.1 line 205 노트에 `get_global_mouse_position()` / `VirtualCursor.global_position` 잔재.
  **권고**: 모두 제거. CoordSpace 단일 SoT 유지.

### 적용
§4.1에 "Pad B 버튼 — 단발/홀드 분기 (raw 처리)" 섹션 신설 (timer + state 기반 release/expire 분기). §4.1 표에서 `skill_cancel`/`restart_stage`/`back_menu`의 Pad 컬럼을 raw 처리로 표시. §2 책임 분리의 VirtualCursor 표현 수정. line 205 잔재 노트를 §2 계약 인용으로 대체. 엣지 케이스에 B 버튼 race 항목 추가. PadButtonBHoldTest 회귀 가드. 리스크 표 추가.

---

## Round 5

**focus**: Round 5 after pad-B raw timer + coord-contract residue cleanup
**verdict**: needs-attention

### Findings

- **[HIGH] Pad A is specified as an InputMap action but still needs cursor-derived coordinates** (CandyAnts/docs/INPUT_PLAN.md:170-203)
  `skill_assign`이 InputMap 액션이지만 `InputEventJoypadButton`은 position 필드가 없음. `event.position`을 무조건 쓰면 패드 A에서 깨짐.
  **권고**: InputRouter가 event source별로 screen_pos 산출 — 마우스 button → `event.position`, 패드 A → `_virtual_cursor.position` + 재변환. 패드 + shifted-camera 회귀 테스트.

### 적용
§5.3에 `_resolve_screen_pos` helper 신설 (event source별 분기). PadShiftedCameraTest 시나리오 강화 (패드 A 케이스 명시). 리스크 표 갱신.

---

## Round 6

**focus**: Round 6 after _resolve_screen_pos event-source dispatch
**verdict**: needs-attention

### Findings

- **[HIGH] _resolve_screen_pos uses invalid event casts for positional events** (CandyAnts/docs/INPUT_PLAN.md:268-272)
  `InputEventWithModifiers`엔 `position` 필드 없음. `InputEventScreenDrag`을 `InputEventScreenTouch`로 캐스트 — 둘은 별개.
  **권고**: 캐스트는 position을 실제로 가진 구체 클래스로만 (`InputEventMouse`, `InputEventScreenTouch`, `InputEventScreenDrag` 각자).

- **[HIGH] Virtual cursor fallback is documented but not present in the dispatch logic** (CandyAnts/docs/INPUT_PLAN.md:273-281)
  helper가 `_virtual_cursor.position`을 unconditional 사용. null/uninitialized 가드 없음.
  **권고**: `_safe_cursor_pos()`로 가드 + viewport 마우스 fallback + 둘 다 없으면 push_error.

### 적용
`_resolve_screen_pos` 캐스트를 구체 클래스(`InputEventMouse` / `InputEventScreenTouch` / `InputEventScreenDrag`)로 정정. `_safe_cursor_pos` helper 신설 (3단 가드: virtual cursor → viewport mouse → push_error). InputRouterEventDispatchTest 회귀 가드 추가. 리스크 표 갱신.

---

## Round 7

**focus**: Round 7 after _resolve_screen_pos cast + cursor fallback fixes
**verdict**: needs-attention

### Findings

- **[HIGH] Vector2.ZERO is used as an error sentinel for world coordinates** (CandyAnts/docs/INPUT_PLAN.md:307)
  SkillToolbar가 `world_pos == Vector2.ZERO`면 noop. 하지만 (0,0)에 ant 있는 stage에선 정상 입력 silent reject.
  **권고**: 명시적 validity flag (`position_valid: bool`) 사용.

- **[HIGH] Pad assign can fall back to stale mouse position before virtual cursor is initialized** (CandyAnts/docs/INPUT_PLAN.md:282-298)
  패드 A를 스틱 한 번도 안 움직이고 누르면 `_safe_cursor_pos`가 OS 마우스 위치 fallback → 잘못된 ant 부여 + 인벤토리 차감.
  **권고**: 패드 origin은 mouse fallback 금지. virtual cursor를 deterministic init (viewport 중앙 등).

### 적용
`_resolve_position`을 typed result(`{position_valid, screen_pos}`) 리턴으로 재설계. 패드 origin은 mouse fallback 금지 + viewport 중앙 eager init + 초기 `cursor_move` 1회 emit. 키 origin은 mode 분기. payload validity 계약 신설 (`position_valid` 키). InputOriginAtZeroTest 회귀 가드 추가. 리스크 표 갱신.

---

## Round 8

**focus**: Round 8 after position_valid flag + pad eager-init
**verdict**: needs-attention

### Findings

- **[HIGH] Position validity key is inconsistent across producer and consumer contracts** (CandyAnts/docs/INPUT_PLAN.md:278-343)
  resolver가 `valid` 키 리턴, payload 계약은 `position_valid`. 정상 입력이 invalid 처리.
  **권고**: 한 이름으로 통일 (`position_valid` 권장) 모든 pseudocode + SkillToolbar에 적용.

- **[HIGH] First stick movement bypasses pad eager-init and can start the virtual cursor at the wrong origin** (CandyAnts/docs/INPUT_PLAN.md:462-470)
  Eager init은 `_resolve_position`에만. Phase 6 `_process` 폴링은 가드 없이 `_virtual_cursor.position += stick * speed * delta`.
  **권고**: `_ensure_virtual_cursor_ready()` 단일 helper로 양쪽 통합 + 첫 stick 회귀 테스트.

### 적용
모든 키를 `position_valid`로 통일 (producer + consumer). `_ensure_virtual_cursor_ready` 단일 helper 신설 — `_resolve_position`과 `_process` 폴링 모두 경유. PadFirstStickInputTest 회귀 가드. 리스크 표 갱신.

---

## Round 9

**focus**: Round 9 after _ensure_virtual_cursor_ready unified helper + position_valid key alignment
**verdict**: needs-attention

### Findings

- **[HIGH] Final SkillToolbar handler drops the position_valid guard** (CandyAnts/docs/INPUT_PLAN.md:616)
  §8.1 마이그레이션 snippet이 `_try_assign(payload.world_pos)` 직접 호출 — 가드 없음.
  **권고**: 진입 직후 `if not payload.get("position_valid", false): return` 가드 추가.

- **[MEDIUM] Keyboard positional input depends on stale InputModeTracker.mode despite the plan saying mode is UI-only** (CandyAnts/docs/INPUT_PLAN.md:334-343)
  `_resolve_position`이 `InputEventKey` 분기에서 `InputModeTracker.mode`를 읽음. §2 책임 분리 위반 + stale state 위험.
  **권고**: `_resolve_position`에서 mode 제거. KB origin은 explicit cursor source 또는 `_last_cursor_*` 캐시.

### 적용
§8.1 SkillToolbar 마이그레이션에 position_valid 가드 추가. `_resolve_position`의 InputEventKey 분기에서 mode 제거 → `_last_cursor_*` 캐시 사용. `_emit_cursor_move` helper로 모든 cursor_move emit 단일 경로 + cache 갱신. SkillToolbarPositionGuardTest, KbCursorCacheTest 회귀 가드 추가. 리스크 표 갱신.

---

## Round 10

**focus**: Round 10 after consumer guard + last_cursor cache for KB origin
**verdict**: needs-attention

### Findings

- **[HIGH] Cursor emits bypass the cache that KB-origin targeting depends on** (CandyAnts/docs/INPUT_PLAN.md:298-388)
  `_ensure_virtual_cursor_ready`와 `_process` 폴링이 `EventBus.action_triggered.emit(GameAction.CURSOR_MOVE, ...)`를 직접 호출. `_emit_cursor_move`를 거치지 않으므로 cache 갱신 안 됨 → KB Tab 깨짐.
  **권고**: `_emit_cursor_move`가 CURSOR_MOVE의 유일한 발화 경로. 모든 producer가 helper 경유. KbCursorCacheTest가 pad eager init과 stick polling 케이스 모두 커버.

### 적용
`_ensure_virtual_cursor_ready`와 `_process`의 직접 emit 제거 → `_emit_cursor_move` 호출로 통일. §5.3 흐름 상자도 동일 수정. KbCursorCacheTest 케이스를 5개로 확장 (마우스 motion / 패드 eager init / 패드 stick polling / cursor_move 미emit / stale mode 가드). 리스크 표는 Round 9 항목에 통합.

---

## Round 11

**focus**: Round 11 after _emit_cursor_move single-producer enforcement
**verdict**: 미확인 — codex usage limit 도달 (`Codex error: You've hit your usage limit`). 2026-05-09 02:47 AM 리셋.

### 다음 행동
- 한도 초기화 후 Round 11 재실행
- 또는 다른 codex 계정/credits 충전
- Round 10 적용 후 새 HIGH가 또 나올 가능성 있음 (Round 1~10에서 매 round HIGH 1~2건씩 발견). verdict가 clean(=approve)이 될 때까지 루프 — CLAUDE.md 규칙에 따라 phase 진입 전 필수.

---

## 누적 변경 요약 (10 rounds)

### 신설 시스템
- `scripts/input/CoordSpace.gd` — screen↔world 변환 단일 SoT
- `scripts/input/GameAction.gd` — 액션 ID const (StringName)
- `scripts/input/InputRouter.gd` — `_unhandled_input` + `_process` 두 진입점, `_resolve_position` event-source 분기, `_emit_cursor_move` 단일 emit + cache 갱신, `_ensure_virtual_cursor_ready` 단일 init, `_last_cursor_*` 캐시
- `scripts/ui/VirtualCursor.gd` — CanvasLayer Control, screen-space
- `scripts/input/CursorTargeting.gd` — 스냅 계산기

### payload validity 계약
- 위치 동반 액션: `{position_valid: bool, screen_pos: Vector2, world_pos: Vector2}`
- 모든 producer/consumer 동일 키 사용
- 수신자 진입 직후 `position_valid` 가드 필수
- `Vector2.ZERO`를 sentinel로 사용 금지 (world origin 정상 좌표 보존)

### 회귀 테스트 패키지 (11개)
1. `tests/InputRouterTest.tscn` — 가짜 InputEvent 주입 + payload 형식 assert
2. `tests/InputRouterShiftedCameraTest.tscn` — 마우스 + 카메라 shifted
3. `tests/PadShiftedCameraTest.tscn` — 패드 A + 카메라 shifted
4. `tests/PadInputTest.tscn` — 기본 패드 입력
5. `tests/InputRouterEventDispatchTest.tscn` — event 타입별 `_resolve_position` 검증
6. `tests/InputOriginAtZeroTest.tscn` — world (0,0) 정상 처리 (Vector2.ZERO sentinel 금지)
7. `tests/PadFirstStickInputTest.tscn` — 첫 stick 입력 시 viewport 중앙 init
8. `tests/SkillToolbarPositionGuardTest.tscn` — position_valid:false → noop
9. `tests/KbCursorCacheTest.tscn` (5 케이스) — `_last_cursor_*` 캐시 single-producer 보장
10. `tests/PadButtonBHoldTest.tscn` — B 단발/홀드 race 방지
11. `tests/PausedAssignTest.tscn` — pause 중 부여 보장 (phase 7)

### 리스크 표 (5 항목)
- 좌표 변환 누락
- B 버튼 multi-action race
- `_resolve_position` 캐스트/cursor/sentinel/mode/single-producer 통합 항목
- cursor_move InputMap 등록 불가
- 액션 이름 오타 / InputMap 비대 (보조)

---

## 결론

Round 1~10에서 매 회차 HIGH 1~2건 발견됨. 모두 plan 본문에 반영하고 회귀 테스트로 가드. Round 11이 verdict=approve로 닫혀야 phase 5 진입 가능. 한도 리셋 후 즉시 재실행 권장.
