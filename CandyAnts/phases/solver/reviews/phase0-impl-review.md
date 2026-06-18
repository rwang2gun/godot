# Phase 0 — Impl Adversarial Review

대상: 커밋 `97ea271` (branch diff against `072ee26`) — SimConfig + 게임플레이 시계 프레임화 + DeterminismReplayTest.

## Round 1 (codex `/codex:adversarial-review`)

Target: branch diff against 072ee26
Verdict: needs-attention

No-ship: deterministic mode can run a materially different spawn schedule, and the replay guard can pass when the stage never terminates.

Findings:
- [high] Frame conversion can fire deterministic timers early and accumulate spawn drift (CandyAnts/scripts/core/SimConfig.gd:30-33)
  `seconds_to_frames()` uses `round()`, then `AntSpawner` adds that rounded interval repeatedly. For common stage `release_rate_initial = 30`, `_interval_for()` is about 1.42245s, or 85.35 physics frames at 60 Hz; rounding schedules 85 frames, so deterministic mode spawns before the requested wait time. Repeating the rounded interval compounds drift across ants. This breaks the claimed Timer-to-frame equivalence and means the solver can validate a schedule that the default game never runs.
  Recommendation: Do not round each interval independently. Track deadlines in seconds or fractional frames and fire on `ceil(absolute_deadline_frames)` so deadlines never occur before the requested duration and fractional error does not accumulate.
- [medium] Replay test treats non-termination as a passing deterministic result (CandyAnts/tests/DeterminismReplayTest.gd:65-69)
  When a run exceeds `DEADLINE_FRAMES`, the test records a synthetic `deadline` result and proceeds to compare the two runs. If both runs fail to emit `stage_cleared` or `stage_failed` because deterministic timeout, `_process` ordering, or signal cleanup is broken, the test still passes as long as both hit the same deadline. That leaves the most expensive failure mode for the solver, an in-process replay that never reaches a real terminal stage result, unblocked.
  Recommendation: Make deadline expiry a hard failure, or assert the expected terminal result for Stage11 before comparing snapshots. Keep a separate bounded hang test if non-termination needs diagnosis.

Next steps:
- Fix deterministic timer conversion and add a regression asserting spawn frames for a non-integer interval such as release rate 30.
- Change the replay test so timeout/deadline is failure, then run the deterministic replay twice in the same process.

### 처리 (impl-stage 정책: HIGH 필수 수정, MEDIUM도 함께 수정)
- **HIGH (spawn drift)**: 채택. `AntSpawner` 결정론 경로를 정수 interval 누적 → **분수-초 절대 데드라인 누적 + ceil 프레임 게이팅**으로 변경(드리프트 0, early-fire 0, Timer "누적≥wait_time" 의미 일치). `seconds_to_frames`도 `round`→`ceil`로(데드라인 early 차단). 비정수 interval(release_rate=30) 스폰 프레임 회귀 추가.
- **MEDIUM (deadline=pass)**: 채택. DeterminismReplayTest에서 deadline 초과를 **hard FAIL**로 변경(빈 플랜 S11은 ~960f에 정상 종료하므로 무영향, 비종료 마스킹 차단).

### 수정 (Round 1 대응)
- `SimConfig.seconds_to_frames`: `round`→`ceil` (단발 데드라인 early-fire 차단).
- `AntSpawner` 결정론 경로: 정수 프레임 누적 → **분수-초 절대 데드라인 누적**(`_next_spawn_elapsed_s += _interval_for(rate)`),
  발화 `elapsed_s(=정수프레임/fps) ≥ 데드라인초`. drift 0, early-fire 0.
- `tests/DeterminismSpawnScheduleTest.{gd,tscn}` 신규: release_rate=30(비정수 interval)에서 스폰 프레임이
  `ceil(k×interval×fps)`=[86,171,257,342,427]와 정확 일치 단언 → **PASS**.
- `DeterminismReplayTest`: deadline → hard FAIL. 재검증 **PASS**(962f 결정론 일치).
- 회귀 재확인: S11 default(1562, saved 4/4)·S13 default(1668, 5/5) 불변, S11 det+fixedfps 클리어(4/4) 유지.

## Self-Review Round 1 (자체 적대적 리뷰)

수정 결과물을 codex와 동일 기준으로 가혹하게 재검토.

- **[검토] 결정론 스폰이 "기본 게임이 실제 내는 스케줄"과 일치하는가? (HIGH의 핵심 우려 심화)**
  분석: 기본 게임의 스폰 Timer는 `process_callback` 미설정 = **idle Timer**라 실제 플레이에서 idle delta가
  프레임레이트 의존적 → **기본 게임의 스폰 프레임 자체가 비결정적**(머신/fps마다 다름). 즉 "기본 게임이 내는
  단일 ground-truth 스케줄"은 존재하지 않는다. 또 idle Timer는 one_shot=false로 매 사이클 누산기를 리셋하므로
  고정-60fps 가정 시 사이클당 `ceil(interval×60)`=86f로 **늦게 드리프트**(k×86: 86,172,258,344,430), 분수 잔여를 버린다.
  결정론 경로(ceil-누적: 86,171,257,342,427)는 **설계 의도 interval(1.42296s)을 무손실 추종** — 어느 스폰에서도
  의도 rate와 1프레임 이내, early-fire 0. 5마리 누적 시 idle-Timer 대비 최대 3f(0.05s) 차이뿐이고, idle-Timer
  자체가 비결정적이라 그쪽을 "정답"으로 둘 근거가 없다. → **결정론 경로 = 설계 의도에 가장 충실**, 채택 유지.
  판정: HIGH 잔존 아님. (구버전의 round-누적 = early-fire + 누적 드리프트가 진짜 결함이었고 해소됨.)
- **[검토] float 비교의 결정론성**: `elapsed_s = (정수 물리프레임 − _start_frame)/fps`(정수 뺄셈 후 나눗셈) +
  `_next_spawn_elapsed_s`(동일 float 연산 누적). 동일 입력→동일 IEEE754 결과. DeterminismReplayTest가 스폰 경로 포함
  962f per-frame 일치로 실증. 잔존 비결정 없음.
- **[검토] in-process 2회 재생 상태 누수**: `_start_frame`은 각 스테이지 start()에서 재캡처(상대 델타만 사용),
  전역 물리프레임 절대값 무관. `_pending_respawns` 반복은 삽입순(결정론). Home/StageRunner `_exit_tree`가 EventBus 정리.
  Replay PASS로 누수 0 확인.
- **[검토] 기본 모드 불변**: AntSpawner/Home `_physics_process`는 `_det_active`/빈 dict로 즉시 return.
  `set_release_rate`에서 det 캐시 제거 — 기본 경로는 Timer.wait_time만 갱신(종전과 동일). S11/S13 default 프레임·결과 불변 실측.
- **[검토] deadline-fail 헤드룸**: 빈 플랜 S11 962f ≪ 16000(16x). 비종료만 트립. 안전.
- **판정: 자체 리뷰 clean (HIGH 0건).** → codex 재리뷰 진행.

## Round 2 (codex `/codex:adversarial-review`)

Target: branch diff against 072ee26
Verdict: **approve**

No material no-ship finding supported from the diff. The R1 fixes replace rounded per-interval spawn accumulation with absolute fractional deadlines, switch one-shot frame conversion to ceil, and make replay deadline expiry a hard failure. I could not run the Godot tests because the sandbox policy rejected the test commands, so this approval is based on read-only diff inspection only.

No material findings.

### 종결
- **verdict = approve (clean).** impl-stage 루프 종료(R1 needs-attention → 수정 → 자체리뷰 clean → R2 approve).
- codex 샌드박스가 Godot 실행을 거부해 read-only 검토였으나, 모든 결정론/스폰/회귀 테스트는 **작성자가 직접 실행해 PASS 확인**
  (DeterminismReplayTest 962f 일치, DeterminismSpawnScheduleTest [86,171,257,342,427] 일치, S11/S13 default·S11 det+fixedfps 클리어).
