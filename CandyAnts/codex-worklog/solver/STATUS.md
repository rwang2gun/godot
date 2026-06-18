# solver STATUS

## 목적
스테이지 자동 솔버 트랙(툴링, gameplay phase와 직교). 실제 Godot 게임을 헤드리스로 돌려(인-더-루프)
스테이지 클리어 가능 여부를 기계 검증하고, 이후 자동 레벨 디자인(풀이가능성·최소스킬·난이도)에 재사용.

- **Plan SoT**: [phases/solver/auto-solver-plan.md](../../phases/solver/auto-solver-plan.md) (4-phase: 0 결정론·속도 게이트 →
  1 플랜-리플레이 하니스 → 2 탐색 솔버 → 3 레벨 디자인 활용).
- **정답 기준(D4)**: "솔버가 실제 인벤토리로 달성한 클리어"를 무수정 게임 코드(`StageRunner._conclude_stage`)가
  판정한 결과만 정답. 기존 드라이버·주석은 ground truth 아님.

---

## 현재 상태 (2026-06-18) — **Phase 0 구현 완료, 게이트 통과**

### 결정론 모드 (opt-in)
- **`scripts/core/SimConfig.gd`** 신규 autoload(`project.godot` 등록, GameManager 직후). `deterministic` 플래그
  기본 `false` → 게임·기존 테스트 동작 불변. `CANDYANTS_DETERMINISTIC=1`(env) 또는 `set_deterministic(true)`로 켬.
  `seconds_to_frames(s)` = `round(s × physics_ticks_per_second)`.
- **게임플레이 시계 프레임화(결정론 모드 한정)** — 기본 경로는 종전 그대로:
  - 스폰 grace: `Ant.arm_spawn_grace()`/`in_spawn_grace()`로 캡슐화. det 모드 = `Engine.get_physics_frames()` 컷오프,
    기본 = 벽시계(`Time.get_ticks_msec`). Home이 위임(직접 `_grace_until` 비교 제거).
  - 스폰 타이밍: `AntSpawner` det 모드 = `_physics_process` 프레임 게이팅(`_interval_frames`), 기본 = Timer.
  - 리스폰: `Home` det 모드 = `_pending_respawns` 프레임 데드라인 펌프, 기본 = per-ant Timer.
  - 스테이지 타임아웃: `StageRunner` det 모드 = `begin()` 시점 물리프레임 경과로 `time_left` 산출, 기본 = `_process` delta 누적.
- **`Ant.spawn_index`** 노출 (AntSpawner가 `_spawn_one`에서 세팅). 결정론 셀렉터/리플레이 안정 tie-break 키
  (instance_id는 실행 간 달라져 부적합).

### 검증 (`tests/DeterminismReplayTest.{gd,tscn}`)
- Stage11을 det 모드 + 동일 빈 플랜으로 **2회 in-process** 실행, 매 프레임 개미 스냅샷
  (spawn_index·pos·vel·state·dir·has_candy) + 종단 결과 **byte-identical 단언**.
- **결과: PASS — 960 프레임 per-frame 완전 일치.** (빈 플랜이라 `no_more_ants` 실패가 정상; 핵심은 run1==run2.)

### 속도 게이트 (실측, RogallyX, Godot 4.6.2 headless console)
| 구성 | wall | frames | sim 속도 |
|---|---|---|---|
| S11 default, `--fixed-fps` 없음 | 26.77s | 1561 | **58 f/s ≈ 실시간** |
| S11 결정론 + `--fixed-fps 60` | 1.10s | 1560 | **1416 f/s (~24x 실시간)** |
| startup baseline (`--quit-after 1`) | 0.82s | — | — |
- **게이트 통과**: 한 롤아웃(≈26s 게임플레이) wall ≈ 1.1s(startup 포함), startup 상각 시 **롤아웃당 ~0.3s**.
  목표 "≤ 수 초/롤아웃" 충분히 충족. 인-더-루프 아키텍처 진행 OK(Phase 2 차단 사유 없음).
- **가속 메커니즘 = `--fixed-fps`**: 없으면 헤드리스가 실시간(58 f/s)으로 페이싱됨(plan CRITICAL-2 확인). 솔버 하니스는 `--fixed-fps` 필수.
- **부수 확증**: S11이 결정론+fixed-fps에서 **올바르게 클리어**(saved=4/4, 1560f) → 프레임화가 클리어 판정 불변.

### 회귀 (기본 모드, `--fixed-fps` 없음)
- **신규 회귀 0건.** Phase 0 변경 전/후 비교(git stash 베이스라인 대조):
  - PASS(불변): `CampaignS11ClearTest`(saved=4/4), `CampaignS13ClearTest`, `StageRunnerBeginGateTest`(time_scale), `HomeNoRespawnAfterDepletedTest`(grace 직접 세팅).
  - FAIL(**선존 결함, 변경 무관**): `CampaignS12ClearTest`·`CampaignS14ClearTest`(time_out saved=0 frame=6000), `GameFlowTest`(await_signal timeout) —
    셋 다 **베이스라인에서도 동일하게 실패**(WIP 커밋 f918346 "ch1 클리어 드라이버 수정 진행 중"의 미완 드라이버). Phase 0와 무관, 별도 트랙에서 처리.
- 기본 모드는 `--fixed-fps`에서 비결정적(벽시계 grace) → 기존 테스트는 `--fixed-fps` 없이(run_test.py 기본) 돌아 무영향.

---

## 다음 작업 (Phase 1 — 플랜 스키마 + 리플레이 하니스)
- `scripts/core/PlanRunner.gd`(씬 드라이버) + `scripts/core/SkillApplier.gd`(인벤토리-충실 적용 SoT, toolbar 위임) +
  `scripts/run_plan.py`(CLI, `--fixed-fps`·`--selftest`·배치).
- `tests/PlanReplayHarnessTest` + `data/solutions/stage11~13.solution.json`(손작성 메커니즘 골든 + negative).

## 블로커
- 없음.
