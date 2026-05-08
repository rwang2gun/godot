# Issues Log — Phase별 발견 이슈 종합

각 phase의 review/검증/구현 단계에서 발견된 이슈를 한 곳에 모은 추적 문서. phase별 review 원본은 같은 폴더의 `phaseNN-*-review.md` 참조.

**범례**:
- 🔴 CRITICAL · 🟠 HIGH · 🟡 MEDIUM · ⚪ LOW
- **출처**: `codex-pre` (phase 시작 전 plan 리뷰) / `codex-post` (구현 후 누적 리뷰) / `self` (자체 검증 중 발견)
- **상태**: ✅ fixed / ⏸ deferred / ❌ wontfix

---

## Phase 1 — bootstrap

### #1 🟡 [MEDIUM] `.tdd_bypass` 영구 잔존 위험
- **출처**: codex-pre (`phases/mvp/reviews/phase01-review.md`)
- **상태**: ✅ fixed (커밋 `6e4eaf5`)
- **원본 인용** (Codex):
  > The plan adds `scripts/hooks/.tdd_bypass` as a Phase 1 artifact and only says it will be removed at final verification or before Phase 2. That removal is deferred rather than made an exit criterion of this change, so a partial completion, handoff, or status-only update can leave the bypass committed or present in the working tree. The likely impact is that subsequent `scripts/core/*.gd` additions can skip the TDD guard without an obvious failure signal.
- **근본 원인**: TDD Guard 우회 토큰을 Phase 1 작업용으로 만들었지만 제거 시점이 "검증 또는 Phase 2 시작 직전"으로 모호. 부분 완료/핸드오프 시 잔존 가능.
- **수정**: 3중 가드 도입 — (a) `.gitignore`에 `scripts/hooks/.tdd_bypass` 패턴 추가, (b) `execute.py complete` 직전 `rm` + `git status --porcelain` 부재 확인을 exit criterion화, (c) deferred 금지(반드시 phase 내부 종결).
- **검증**: phase 종료 시 `BYPASS_REMOVED` 출력 확인. 이후 Phase 2도 동일 패턴 재사용.
- **재발 방지**: 이후 모든 phase에 동일 3중 가드 적용. plan 템플릿화.

---

## Phase 2 — stage1-core

### #2 🟠 [HIGH] Home 핸들러가 grace 후 빈손 ant를 Saved 처리 → Candy 도달 전 사라짐
- **출처**: codex-pre (`phases/mvp/reviews/phase02-review.md`)
- **상태**: ✅ fixed (커밋 `7bdfe7f`)
- **원본 인용** (Codex):
  > The planned Home handler emits ant_saved and transitions to SavedState for any Ant once the 0.4s spawn grace expires; it does not require CarryingState before saving. Because Stage01 spawns ants at Home.position + (0,-32), inside or immediately adjacent to a 32x32 Home Area2D, an ant that remains overlapping Home or re-enters it after the grace window is treated as saved even with carrying=false. This can silently drain total ants without reducing Candy HP, leaving the stage unwinnable or producing misleading Saved/HUD counts.
- **근본 원인**: 두 결함의 합성:
  1. Home 핸들러가 `carrying` 여부와 무관하게 Saved 처리.
  2. spawn_position이 Home Area2D(32x32) 내부 또는 인접(겨우 32px 위)이라 grace 후에도 trigger 발화 가능.
- **수정** (plan 단계에서 사전 차단, 구현 시 적용):
  - **가드 1 (시간)**: 스폰 후 `spawn_grace_seconds=0.4`초 동안 Home 트리거 무시 (`Ant._grace_until`).
  - **가드 2 (의미)**: `has_been_carrying=false`인 fresh ant는 Home과 겹쳐도 Saved 안 됨. 운반 후 빈손 귀환자만 saved(false) 처리(메모리 누수 방지).
  - **가드 3 (geometry)**: spawn_position을 Home 우측 +48px로 분리해 Home Area2D 32x32와 물리적 비겹침.
- **검증**: A2 회귀 가드 추가 — 1초 시뮬에서 picked·saved·lost 모두 0건. headless로 자동 검증.
- **재발 방지**: 향후 새 stage 추가 시 spawn_position이 Home Area2D 외부인지 plan 단계에서 명시.

### #3 🔴 [CRITICAL] AntSpawner timer race — `start()`가 `_ready()` 전에 호출되면 null deref
- **출처**: codex-post (`phases/mvp/reviews/phase02-cumulative-review.md`)
- **상태**: ✅ fixed (커밋 `da3fa85`)
- **원본 인용** (Codex):
  > Stage01 declares `StageRunner` before `Spawner`, and `StageRunner._ready()` immediately calls `_spawner.start(_spawn_parent)`. `AntSpawner.start()` then calls `_timer.start()`, but `_timer` is only created in `AntSpawner._ready()`. In Godot ready ordering, sibling `_ready()` execution follows scene-tree order, so this ordering can dereference a null timer and prevent the vertical slice from spawning ants at all.
- **근본 원인**: `_timer = Timer.new()`가 `_ready()`에만 있고, `start()`가 `_timer.start()`를 호출. Godot의 형제 `_ready()` 순서가 트리 구조에 의존하므로 fragile. Stage01.tscn에서는 우연히 Spawner가 StageRunner의 자식이라 자식 → 부모 순서로 통과했지만, 트리 변경(또는 Spawner를 다른 위치로 이동) 시 null deref.
- **수정**: `_ensure_timer()` 헬퍼 추가, `_ready()`와 `start()` 양쪽에서 호출. 멱등이라 두 번 호출돼도 무해.
- **검증**: 회귀 검증 (A: cleared score=1.0 / A2: 0건) 통과.
- **재발 방지**: lifecycle 자원(Timer/AudioStreamPlayer/Tween 등)은 lazy `_ensure_*()` 패턴 권장. plan 작성 시 외부 호출 진입점 검토 항목으로 추가.

### #4 🟠 [HIGH] Carrying→Faller 전이 시 candy 분실 → in_transit 영구 잔존 → 클리어 데드락
- **출처**: codex-post (`phases/mvp/reviews/phase02-cumulative-review.md`)
- **상태**: ✅ fixed (커밋 `da3fa85`)
- **원본 인용** (Codex):
  > Candy ownership is inferred from `current_state is CarryingState`. `CarryingState` switches to `FallerState` when the ant is off-floor, and `FallerState` later returns to `WalkerState`, losing the carrying state. Home then emits `ant_saved` with `with_candy=false`, so `ScoreSystem` never decrements `in_transit_pieces`; after candy HP reaches 0, `is_cleared()` can remain false until timeout even though the ant reached home.
- **근본 원인**: 운반 사실(데이터)을 운반 상태(state machine)에 결합. CarryingState → FallerState → WalkerState 전이 사이클에서 운반 사실이 사라짐. ScoreSystem의 `in_transit_pieces`가 영구 +1 → `is_cleared()` 영구 false → 시간 초과 stage_failed.
  - **위장**: Stage 1은 평지뿐이라 Carrying 중 절벽 미발생. Phase 4(Hazard)나 Phase 5(절벽 + Basher) 도입 즉시 발현 예정.
- **수정**:
  - `Ant.has_candy: bool` 도입. state와 분리된 단일 진실 출처(SoT).
  - `CarryingState.enter()`에서 `has_candy=true` (`has_been_carrying`도 함께).
  - `Home._on_body_entered`의 carrying 판정을 `ant.has_candy`로 변경. Saved 직전 `has_candy=false`.
  - `Ant.effective_speed()`도 `has_candy` 기반으로 전환 — 운반자가 Faller→Walker로 잠시 빠져도 0.78배 속도 페널티 유지.
- **검증**: A 회귀 (75초, score=1.0) 통과. 단, 절벽 + Carrying 시나리오는 Phase 4+ 도입 후 별도 검증 필요.
- **재발 방지**: 데이터(소유권/HP/상태 카운터)와 행동 상태(state machine)를 명시적으로 분리. 미래 phase에서 새 상태 추가 시 "운반 정보가 보존되는가?"를 plan 체크리스트에 포함.

---

## 자체 발견 (self) — 도구/환경

### #S1 ⚪ [LOW] headless 검증 시 simulation 시간 ≪ wall-clock
- **출처**: self (Phase 2 검증 중)
- **상태**: ✅ fixed (운영 절차 변경)
- **현상**: `--quit-after 1800` (30초 기대) 실행했는데 첫 ant가 11초 분량(660 frames)만 시뮬됨. ant_saved/picked 0건이 거짓 음성 의심.
- **근본 원인**: Godot `--quit-after`는 main loop iterations이고, headless 모드는 vsync 없어 main loop이 매우 빨리 돈다. 한편 Timer의 wait_time과 `Time.get_ticks_msec()`은 wall-clock 기반. 결과적으로 simulation/wall-clock 분리.
- **수정**: 모든 headless 검증 명령에 `--fixed-fps 60` 강제. 1 frame = 1/60 초 보장.
- **권장 명령 템플릿**:
  ```bash
  godot --headless --path . --fixed-fps 60 --quit-after <FRAMES> res://scenes/stages/StageNN.tscn > log 2>&1
  ```
  여기서 `FRAMES = 60 * desired_seconds`.
- **재발 방지**: phase별 plan의 검증 시나리오에 `--fixed-fps 60` 명시.

### #S2 ⚪ [LOW] git config 미설정으로 `execute.py complete` 자동 커밋 스킵
- **출처**: self (Phase 1 완료 시점)
- **상태**: ✅ fixed (사용자가 `user.email`/`user.name` 설정 후 정상화)
- **현상**: `python scripts/execute.py mvp complete 1` 호출 시 `git commit`이 author identity 미설정으로 실패. status.json은 completed 마킹됐지만 모든 파일이 staged 상태로 남음.
- **근본 원인**: Claude Code의 git config 변경 금지 룰. 신규 환경에서 user.email/user.name 미설정.
- **수정**: 사용자가 직접 `git config` 설정 후 commit 진행. 이후 phase에서는 자동 커밋 정상.
- **재발 방지**: 새 환경에서 `/harness` 시작 시 git config 사전 검증을 README의 권장 사전조건에 추가 검토.

---

## 통계

- **총 발견**: 6건 (Codex 4 + 자체 2)
- **즉시 수정**: 6건
- **deferred**: 0건
- **wontfix**: 0건

| Severity | 건수 |
|----------|------|
| 🔴 CRITICAL | 1 |
| 🟠 HIGH | 2 |
| 🟡 MEDIUM | 1 |
| ⚪ LOW | 2 |

## 패턴

1. **Codex의 가치는 plan 단계에서 가장 큼** — 4건 중 2건은 plan 리뷰(codex-pre)에서 사전 차단. 구현 비용 0.
2. **Vertical Slice의 위장된 결함** — Stage 1 평지 환경이 #4(Carrying→Faller candy 분실)를 숨김. 누적 리뷰(codex-post)가 미래 phase 시나리오까지 추론해 발견.
3. **Lifecycle race는 Godot에서 흔함** — `_ready()` 순서 의존 대신 `_ensure_*()` 멱등 헬퍼 패턴이 더 안전.
4. **상태(state machine) ≠ 데이터(소유권)** — 게임 로직에서 둘을 결합하면 fragile. 명시적 분리.

## 운영 개선 항목

- [ ] phase plan 템플릿에 "lifecycle 진입점 검토" 체크박스 추가
- [ ] phase plan 템플릿에 "데이터 vs 상태 분리 검토" 체크박스 추가
- [ ] 검증 명령에 `--fixed-fps 60` 항상 명시
- [ ] phase별 `.tdd_bypass` 3중 가드 패턴 README 단일 SoT 유지
