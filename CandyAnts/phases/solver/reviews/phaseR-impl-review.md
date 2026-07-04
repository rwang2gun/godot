# Phase R R0 (RL 파이프라인) — impl-stage 적대적 리뷰 트레일

> 대상: `tools/solver/rl/{mdp.py,train.py,requirements.txt}` + `data/solutions/stage11.rl.json`.
> codex `adversarial-review --scope working-tree`(신규 파일 staged). 사용자 Ch2 WIP(stage17/project.godot/
> stage26~33)·plan/review 문서는 리뷰 범위 밖으로 명시.

## Round 1 (2026-07-03) — needs-attention (HIGH 1 · MEDIUM 2)

- **[high] verify-r0 does not enforce the pinned acceptance contract or stage binding** (train.py:299-336)
  — 키 존재·seed 3개·≥2 cleared만 검사. pinned seeds 0,1,2 / envs_requested=4 / max_episodes=20000 /
  max_wall=7200 / grammar_version / meta.pass / stage·stage_id·deadline 바인딩 미검증 → 다른 config·다른
  스테이지 산출물이 replay만 통과하면 인증됨(fail-closed 계약 위반).
- **[medium] Preflight is sequential** — 순차 e.step 루프라 학습이 쓰는 ThreadPoolExecutor 병렬 경로를
  미검증. 동시성-전용 실패가 preflight를 통과해 학습 중 표면화 가능.
- **[medium] EnvPool construction can leak Godot processes on partial failure** — list comprehension 중간
  실패 시 이미 부팅된 env의 close 경로 없음(포트/프로세스 누수).

### 처리 (전부 수정)
- HIGH → `R0_PIN` 상수 + verify_r0에 스테이지 바인딩(stage_id/stage/deadline_frames==config.replay_deadline/
  expect.saved==hp_stage) + pinned 계약(seeds 정확히 [0,1,2]·envs_requested·예산·grammar_version·pass·no_hint)
  전부 fail-closed. **음성 실증 4종**: seed 2개 변조→FAIL / 예산 pin 변조→FAIL / stage 변조→FAIL / 복원→PASS.
- M1 → preflight를 `pool.evaluate([plan]×2N)`(학습과 동일 ThreadPoolExecutor 경로)로 변경, 재실행 PASS
  (envs=4 runs=8 parallel identical=True).
- M2 → EnvPool 생성을 try/except 증분 구성으로 — 부분 실패 시 만든 env 전부 close 후 재던짐.

## Self-Review Round 1 (2026-07-03) — clean (HIGH 0)

수정 후 자체 적대 리뷰(코드 전체 재독):
- verify_r0 R0_PIN이 S12 stretch에도 적용(plan §R0 item 6 "동일 예산·동일 predicate"와 정합) — OK.
- run_training이 pass:false manifest를 쓰는 경우(부분 성공) → verify-r0가 meta.pass!=true로 FAIL — 거짓 인증 없음.
- 집계식 `n_clear*2 >= len(seeds)+(len(seeds)%2)` = 3-seed에서 ≥2 (pinned 케이스 정확), 1-seed 스모크에서 ≥1.
- SUBMIT 스텝0 마스킹: Categorical(-inf logit) 확률 0·entropy 기여 0 — torch 시맨틱 안전. 마스킹으로
  logps 최소 1개 보장(zero-tensor fallback은 방어용 잔존).
- 결정론: 샘플링은 메인 스레드 순차(torch.manual_seed), 스레드는 평가만(결과 인덱스-순서 보존) — 학습 곡선
  seed-재현 주장 유지. pool.evaluate 예외는 전파(crash = 정직 실패), run_training finally가 pool.close().
- 게이트 비커플링 실증: stage11.rl.json 존재 상태에서 기존 verify 8종 전부 그린(selftest 19/19 — glob
  `*.solve.json` 비매칭 확인). no_hint = model.propose 미import(구조적).

## Round 2 (2026-07-03) — needs-attention (HIGH 1)

- **[high] verify-r0 accepts artifacts that move the replay deadline** (train.py:314-350) — deadline 검사가
  "artifact 자기-일관"(top-level == 자기 config.replay_deadline)뿐이라, deadline_frames=16000 +
  config.replay_deadline=16000으로 재생성/변조된 산출물이 통과 → 느슨한 deadline으로 거짓 인증 가능.

### 처리
- `R0_PIN["replay_deadline"]=7000` 추가 — verify_r0가 `config.replay_deadline == pinned` AND
  `deadline_frames == pinned` 둘 다 강제(순환 신뢰 제거). 학습-전용 knob(train_deadline 등)은 인증 실체가
  아니므로 pin 비대상(사유 주석 명문화).
- **음성 실증**: deadline_frames+config.replay_deadline 동시(자기-일관) 16000 변조 → FAIL("deadline_frames
  != pinned 7000") / 복원 → PASS.

## Self-Review Round 2 (2026-07-03) — clean (HIGH 0)

- R0_PIN 확장이 run_training 산출 경로와 정합(deadline_frames=cfg.replay_deadline=7000 그대로) — 정상 산출물
  재검증 PASS 확인. S12 stretch manifest도 동일 경로라 pin 일치.
- 남은 manifest 자기-신뢰 = seed별 episodes/wall 수치(train.py 기록값) — R3-plan-review LOW로 이미 수용
  (독립 replay + 예산 pin이 보완, 로컬 비게이트 검사).

## Round 3 (2026-07-03) — **approve**

> Ship: the Round 2 deadline self-consistency bypass is closed, and I cannot support a remaining material
> fail-open finding in the staged R0 files. **No material findings.**

**impl-stage 종결**: R1(H1·M2) fix+음성실증 → Self-R1 clean → R2(H1) fix+음성실증 → Self-R2 clean → R3 approve.

---

# Phase R R1 (trace-shaped 보상+SIL) — impl-stage 적대적 리뷰 트레일 (사후 경로)

> 대상: 커밋 `431fdd6` diff(base `dc68a47`) — `tools/solver/rl/{mdp.py,train.py}` +
> `data/solutions/stage{11,12,17}.rl.json`. R1 커밋이 명시 박제한 "codex 리뷰 미실시 — 다음 세션 첫 작업"
> 이행. 사후(post-commit) 리뷰이므로 HIGH는 hot-fix 커밋(`fix: … (phase R sweep)`) 경로.

## Round 1 (2026-07-04) — needs-attention (HIGH 1 · MEDIUM 1)

- **[high] verify-r1 replays arbitrary actions without proving they are encodable by grammar r1.1**
  (train.py verify 경로) — grammar_version 문자열만 검사하고 `d["actions"]`를 그대로 replay. StageMDP
  encode→decode 왕복 검증·액션 수 vs pinned max_len 검사 부재 → grammar_version="r1.1"로 위조/수기 산출물
  (더 큰 max_len·ant-target/y_row 어휘 밖 액션 포함)이 replay만 통과하면 인증됨. "R1 문법의 산출물"이라는
  계약 파괴.
- **[medium] Trace preflight evidence can be self-forged with nonsensical run counts** — {ok,wall_s,runs}
  키 존재만 검사. runs가 preflight 계약(2×envs)과 일치하는지·zero/음수 wall·zero runs 거부 없음 →
  `preflight_trace={"ok":true,"wall_s":0,"runs":0}` 위조가 통과(trace 결정론 증거가 fail-closed 아님).

### 처리 (전부 수정 — hot-fix 커밋)
- HIGH → ① `R0_PIN`/`R1_PIN`에 `max_len=6` 추가(기존 extra_cfg 메커니즘이 cfg 존재+값 자동 강제) +
  `_verify_pinned`의 StageMDP를 pinned max_len으로 구성. ② `len(actions) ≤ 실효 max_len`(=min(ant-target
  인벤토리 합, pin.max_len)) + 빈 actions 거부. ③ **각 액션 encode→decode 라운드트립 자기재생산 검사** —
  문법 밖 액션은 격자 투영이 값을 바꾸거나(오프-그리드 x·비정렬 y밴드) 어휘 `.index`가 예외(미지 스킬·
  state) → fail-closed. 키 누락/잉여 키(at_frame 등)도 decode의 명시 키 재생산과 불일치로 검출. ④ replay
  대상을 라운드트립 canonical plan으로(문법 산출이 replay 권위; 통과 시 원본과 값 동일), 문법 실패 시
  replay 생략(이미 FAIL 확정).
- MEDIUM → `preflight_trace.runs == 2*envs_requested`(preflight 계약: env당 정확히 2회) + `wall_s > 0`
  (bool 배제 타입 검사) + `envs_effective≤1(강등)인데 ok=true`인 모순 manifest 거부.
- **음성 실증 6종 + 복원**(스크래치 하네스, stage12.rl.json 변조): ① off-grid trigger.x(+7px, 엔진 replay
  가능·문법 밖) → FAIL(라운드트립 불일치) ② 행 비정렬 y밴드 → FAIL ③ 액션 복제 길이 초과 → FAIL(4>실효 3)
  ④ config.max_len=8 변조 → FAIL(pin) ⑤ preflight runs=0 → FAIL ⑥ wall_s=0 → FAIL / 복원 → **verify-r1
  PASS**. verify-r0(S11)도 강화 후 PASS(회귀 0).
- 하네스 사고 1건 정직 기록: 1차 실행이 cp949 print로 중단돼 변조본이 디스크에 잔존 → 2차 실행 orig가
  오염본을 읽음(전 케이스 "actions 4개" 혼입). git restore로 원본 복원 후 재실행 = 클린 결과. 교훈:
  변조-복원 하네스는 git 권위 복원 + UTF-8 reconfigure 필수.

## Self-Review Round 1 (2026-07-04) — clean (HIGH 0)

- 위조 경로 전수 재점검: 키 누락(select/state/mode) → decode가 명시 키 재생산 → 불일치 FAIL / NaN·Inf x →
  round() 예외 → FAIL / picked_ge n 범위 밖·비정수 → clamp/int 불일치 FAIL / 잉여 키 → 불일치 FAIL — 열린
  경로 발견 못 함.
- `envs_effective==1 & ok==true` 모순 검사의 거짓 양성 없음: 강등은 preflight FAIL시에만 발생(build_pool
  유일 경로), N=1 요청 placeholder(runs=0)는 envs_requested pin에서 선차단.
- replay 생략 게이트(grammar_fails>0)는 fails 비어있지 않은 FAIL 확정 경로 — 거짓 통과 불가. PASS 경로
  digests[0] 접근 안전(fails 없으면 replay 2회 보장).
- 학습 경로(run_training/train_seed)·mdp.py·--coverage 무변경 — 게이트 강화만. HIGH 0.

## Round 2 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] preflight_trace remains self-forgeable because verify-r1 only validates claimed fields**
  (train.py:450-467) — 구조 검사(runs==8, wall>0, ok 일관성)는 위조 *값*을 좁힐 뿐, verify가 trace
  preflight를 재실행하거나 검증자 측 실측에 바인딩하지 않음 → `{"ok":true,"runs":8,"wall_s":0.01}`
  위조가 통과. preflight()/build_pool()/EnvPool.evaluate() 회귀를 JSON 편집으로 은폐 가능.

### 처리 (수정 — MEDIUM이지만 defer 대신 즉시 해소: 비용 낮고 finding의 원리(자기-보고≠증거)가 정당)
- `_verify_pinned` trace 블록에 **검증자 측 live preflight** 추가 — pinned env 수(4)로 EnvPool 구성 →
  `preflight(with_trace=True)` 직접 실행 → `ok==True AND runs==2*pin.envs` 실측 강제. 부팅/실행 예외는
  catch → fail-closed. finally에서 pool.close()(Godot 누수 0). manifest preflight_trace 구조 검사는
  *정직성 검사*로 유지하되 권위는 live 실행. wall_s는 진단 출력.
- 실측: verify-r1 PASS(live preflight envs=4 runs=8 identical wall=0.60s) + verify-r0 PASS(회귀 0 —
  R0 pin은 shaping 없음 → live preflight 비대상).

## Self-Review Round 2 (2026-07-04) — clean (HIGH 0)

- live preflight의 fail-closed 완결성: EnvPool 부팅 실패(RuntimeError)·preflight 내부 예외 전부 catch →
  fails 등재(크래시로 인한 미판정 없음). finally close로 부분 실패에도 프로세스 정리.
- 위조 관점 재점검: 이제 preflight 경로 회귀는 검증자 실행에서 직접 드러남 — manifest 편집으로 은폐
  불가. 남은 자기-신뢰 = seed별 episodes/wall 수치(R0 때 LOW 수용 — 독립 replay+예산 pin이 보완) 동일.
- 학습 경로 무변경. verify 실행 비용 +4 env 부팅(~0.6s) — 게이트 성격상 무시 가능.

## Round 3 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] Live trace preflight accepts missing traces as valid evidence** (train.py preflight) —
  `with_trace=True`가 `r.get("trace")` 동등성만 비교 → trace 수집이 조용히 사라지면(전부 None) 공허
  통과 = live 검증이 "빈-plan 결정론"으로 격하, trace-shaped 경로 인증이 무근거화.

### 처리 (수정)
- `preflight()`에 **trace 유효성 fail-closed**: 비어있지 않은 dict + 개미별 비어있지 않은 샘플 리스트 +
  첫 샘플 len>=4(소비자 `s[3]` 접근 정합) 전 결과 요구. 위반 시 `ok=False` + 반환에 `trace_present`
  필드 신설. `_verify_pinned` live 검사가 `trace_present is True`까지 명시 요구.
- **음성 실증(probe, EnvPool 서브클래스로 회귀 시뮬레이션)**: ① trace 필드 누락 풀 → ok=False·
  trace_present=False ② trace 빈 dict 풀 → 동일 FAIL ③ 정상 풀 대조 → ok=True·trace_present=True.
  verify-r1/r0 회귀 0 (verify-r1 live preflight trace_present=True 확인).
- 부수 정합: 학습 경로(build_pool)도 같은 guard를 타므로 trace 수집 회귀 시 N=1 강등+ok=False가
  manifest에 정직 기록되고, verify 측 live preflight가 독립적으로 FAIL — 이중 차단.

## Self-Review Round 3 (2026-07-04) — clean (HIGH 0)

- `_trace_valid` 경계: dict 아님/빈 dict/빈 샘플 리스트/기형 샘플(len<4) 전부 거부 — 소비자
  (best_goal_dist/count_retired)가 접근하는 최소 구조와 일치. 과잉 검증(값 시맨틱)은 하지 않음(형태만).
- `trace_present=None`(with_trace=False 경로)은 반환에 미포함 — R0 manifest 형태 불변.
- 동등성 비교는 trace_present 확인 후에만 수행 — None 간 공허 동등 경로 제거 확인.

## Round 4 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] Trace shaping can silently degrade after an empty-plan-only preflight** (mdp.py
  shaped_bonus + train.py) — trace 검증이 빈-plan preflight에만 있고, 실제 학습 롤아웃(actions 발화)은
  `shaped_bonus`가 부재 trace를 `{}`로 fail-safe 변환해 shaping 0으로 침묵 진행 → "빈 plan은 trace 정상·
  액션 발화 시 trace 소실" 회귀가 manifest·live preflight 둘 다 통과하면서 `shaping='trace'` 라벨 산출물이
  base 보상+SIL만으로 인증될 수 있음.

### 처리 (수정)
- `_trace_valid`를 모듈 공용 헬퍼로 승격(3 소비자: preflight / 학습 롤아웃 / verify replay).
- **train_seed 롤아웃별 trace 검증**: use_trace면 각 배치 롤아웃의 trace 유효성 확인, 위반 시
  `RuntimeError`로 run 전체 fail(정직 크래시 — silent shaping 격하 산출물 원천 금지). run_training의
  finally가 pool.close() 보장.
- **verify-r1 ⑤ trace 재생 replay**: pinned actions(canonical)를 `trace=True`로 1회 재생 — ⓐ trace
  유효성 ⓑ digest가 non-trace replay와 동일(trace 관측이 시뮬레이션 비교란) 실측. 빈-plan preflight가
  못 보는 "액션 발화 시 소실"을 인증 대상 plan 자체로 검증.
- **음성 실증(probe)**: ActionTraceDropPool(빈 plan trace 정상·액션 plan만 소실 = R4 정확 시나리오) →
  ① train_seed RuntimeError fail-closed ② 빈-plan preflight는 통과(지적 재현 = 롤아웃 검증 필수 입증).
  정상 경로 스모크: S11 seed0 trace+SIL 80 eps 클리어(회귀 0) + verify-r1/r0 PASS(trace replay 포함).

## Self-Review Round 4 (2026-07-04) — clean (HIGH 0)

- RuntimeError 전파 경로: train_seed → run_training(catch 없음) → finally pool.close() → 프로세스 비정상
  종료 = 정직 실패(manifest 미기록이 옳음 — 부분 성공 위장 없음).
- greedy 평가 rollout은 trace 미요청·shaping 미사용 — 검증 비대상이 정확.
- verify ⑤는 grammar_fails==0 && replay 성공 경로 안에서만 실행 — canon 유효성 전제 성립.
- shaped_bonus의 {} fail-safe는 잔존하되(순수 함수 방어) 학습 경로에선 롤아웃 검증이 선행해 마스킹 불가.
