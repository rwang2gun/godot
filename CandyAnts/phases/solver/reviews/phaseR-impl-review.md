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

## Round 5 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] Single-seed sweep artifacts are certified with the >=2/3 pass label** (train.py
  run_training) — pass_rule이 ">=2/3 seeds…"로 하드코딩돼 단일-seed 탐사 스윕 산출물(S17: seeds=[0],
  pass:true)이 pinned 3-seed acceptance와 구별 불가 = 증거 과대표시. (게이트 자체는 seeds pin으로 스윕
  산출물을 거부하므로 인증 우회는 아니나, manifest 자기서술이 fail-open.)

### 처리 (수정)
- **writer 정직화**: `pass_rule = f">={need}/{len(seeds)} seeds…"`(verify와 동일식 need) + `mode` 필드
  신설(`pinned-acceptance` iff seeds==pinned [0,1,2], else `exploratory-sweep`). 3-seed 경로의 pass_rule
  문자열은 기존과 바이트 동일(">=2/3…") — stage11/12 pinned 산출물과 자연 정합, verify 무영향.
- **S17 메타 다운그레이드**(재학습 없는 정직 relabel — run 사실과 일치): pass_rule ">=1/1…" +
  mode "exploratory-sweep". actions/결과 무변경(탐사 스윕 증거로서 유효).
- **실증**: S11 단일-seed 저장 스모크 → 신규 필드 정확(">=1/1"+exploratory-sweep) 확인 후 git 복원 →
  verify-r0/r1 PASS(pinned 산출물 비영향).

## Self-Review Round 5 (2026-07-04) — clean (HIGH 0)

- need 식이 verify `_verify_pinned`와 동일((n+(n%2)+1)//2) — 판정 이원화 없음, 집계 print에도 need 표기.
- mode 판정 기준 seeds==R0_PIN["seeds"]: R0/R1 pin 동일 세트라 단일 기준으로 충분. 스윕이 우연히
  [0,1,2]를 쓰면 pinned-acceptance로 표기되나 그 경우 예산/shaping pin은 verify가 잡음 — mode는
  가독 라벨이지 인증 필드가 아님(인증 권위=verify pin 검사 전체).
- S17 hand-edit 범위 = 서술 메타 2필드만, actions/seeds/curves 등 측정치 무변경 — 위조 아님(다운그레이드).

## Round 6 (2026-07-04) — **approve**

> Ship: no material fail-open path found in the scoped RL solver diff. The R5 evidence-label fix is
> present in the writer and S17 artifact; pinned certification still relies on independent
> seed/config/grammar/preflight/replay checks rather than the readability labels. **No material findings.**

**R1 impl-stage 종결(사후 경로)**: R1(HIGH 1·MED 1) → hot-fix `cd826dd`+음성 6종 → Self-R1 clean →
R2(MED: 검증자 실행 요구) → `cc9f1f4` live preflight → Self-R2 clean → R3(MED: trace 부재 공허 통과) →
`7d1ae6d` trace_present fail-closed+probe → Self-R3 clean → R4(MED: 롤아웃 trace 소실 침묵) →
`9a06f6e` 롤아웃 검증+trace 재생 replay+probe → Self-R4 clean → R5(MED: 스윕 라벨 과대표시) →
`93f58a5` pass 시맨틱 정직화+S17 다운그레이드 → Self-R5 clean → **R6 approve**.

# §R2 impl 사후 리뷰 (2026-07-04, base=1079481^)

## Round 1 (codex adversarial-review --base HEAD~1)
Verdict: needs-attention

- [high] verify-r2 allows pinned acceptance to pass with missing pinned seeds (train.py 결측-seed subset 허용)
  → 결측 seed를 "암묵 FAIL 집계"로만 다뤄 cherry-pick 경로(나쁜 seed 생략) 존재. 권고: 전원 기록 요구
  또는 결측의 상류-실패 근거 검증.
- [high] Transfer checkpoint provenance is verified only against mutable JSON, not checkpoint bytes
  → ckpt_loaded.sha를 chain/상류 JSON과만 대조 — 상류 ckpt "파일"의 실존·해시·내용 미검증. 위조/스테일
  JSON으로 임의 transfer 출처 위장 가능. 권고: 상류 ckpt 파일 resolve→sha 실측→load→내부
  stage/seed/cleared/digest/chain 검증(byte-backed).
- [medium] Saved checkpoint validation omits the per-stage mask digest
  → 저장 ckpt 무결 블록이 mask_digest 미대조 — exact-resume 계약 비이행 ckpt를 게이트가 인증 가능.
  권고: ck.mask_digest == mdp.mask_digest() 추가.

## Round 1 hot-fix (적용)
- HIGH-1: 결측 pinned seed = **상류 산출물의 미클리어 실증이 있어야만 허용**(from-scratch 사슬은 전원
  기록 필수) — "결측=FAIL 집계" 시맨틱은 유지하되 결측의 *근거*를 fail-closed 검증(cherry-pick 차단).
- HIGH-2: transfer 출처 **byte-backed** — 상류 ckpt 파일 실존+sha 실측(ckpt_loaded·상류 manifest 양쪽
  대조)+load 후 grammar/vocab·stage/seed/cleared_seg·layout/mask digest(상류 mdp 기준)·내부 사슬 검증.
- MED-3: 저장 ckpt 검증에 mask_digest 대조 추가.

## Self-Review Round 1 (hot-fix 자체 적대 리뷰)
- 결측-근거 로직: 상류 JSON 위조로 "미클리어 근거"를 조작해도 결측 seed는 여전히 FAIL 집계 —
  predicate 부풀림 경로 없음(근거 위조의 이득 = 0). 상류 산출물/기록 부재 = fail-closed FAIL 확인.
- byte-backed 블록은 JSON 교차 통과 후에만 진입(중복 보고 없음), 상류 mdp digest 기준값은 pinned
  cap(4500)·max_len(6)으로 학습 config와 정합(stage11/19 PASS 실증).
- 음성 실증 3종(P1 결측 무근거/P2 상류 ckpt 바이트 변조/P3 mask_digest+sha 정합 위조) 전부 검출,
  복원 PASS. verify-r0/r1 비접촉(코드 경로 분리). → HIGH 0, clean.

## Round 2 (codex adversarial-review --base HEAD~2)
Verdict: needs-attention

- [high] Missing ckpt_saved bypasses the mask_digest and byte-backed checkpoint checks
  → ckpt_saved가 dict일 때만 검증 — 항목 자체를 생략하면 파일/sha/digest/내부사슬 검사 전부 스킵
  (MED-3 픽스가 부재-fail-open). 권고: --save-ckpt가 pinned 계약인 스테이지(11/12/13)는 부재 = FAIL.
- [high] Missing-seed evidence still trusts unverified upstream JSON
  → 결측 근거로 상류 rl_meta.seeds[].cleared==false를 raw JSON에서 읽음 — 스테일/편집된 상류
  JSON으로 합성 실패 기록을 만들어 seed 생략 가능. 권고: 상류 검증을 fail-closed 공용 검사로 —
  최소한 상류 stage/config/grammar 정합 + 해당 실패 기록의 byte-backed ckpt 증거 요구.

## Round 2 hot-fix (적용)
- ckpt 파일 byte-backed 검증을 공용 helper(`_validate_ckpt_file`)로 통합(현-스테이지/transfer 출처/
  결측-근거 3경로 동일 계약): 실존+sha 실측(+대조 sha)+load 후 grammar/vocab·stage·seed·layout/mask
  digest·cleared_seg·내부 사슬.
- `R2_SAVE_CKPT_STAGES = {11,12,13}` pin 신설 — pinned 커맨드에 --save-ckpt 포함 스테이지는
  ckpt_saved **부재 = FAIL**(부재-fail-open 봉합; S19는 pinned 커맨드에 저장 없음 = 비대상).
- 결측-seed 근거 강화: 상류 산출물의 stage 바인딩/grammar/vocab digest/config 정합 + seed 중복 거부 +
  해당 seed 실패 기록의 **byte-backed ckpt 증거**(cleared_seg==False 실측) 요구 — raw JSON 신뢰 제거.

## Self-Review Round 2 (hot-fix 자체 적대 리뷰)
- 결측-근거 루프 제어흐름 검증: 상류 클리어 → 다음 상류로 continue / 기록 없음·pin 비정합 → 근거
  불인정 fail. 근거 위조는 여전히 predicate 부풀림 불가(결측=FAIL 집계 불변).
- helper 통합으로 3경로(현-스테이지/transfer 출처/결측 근거)가 동일 계약 — 계약 드리프트 원천 제거.
  expect_sha 배선(transfer=ckpt_loaded sha, 현-스테이지=말단 세그먼트 sha 별도 대조) 확인.
- 음성 실증 3종(Q1 ckpt_saved 생략/Q2 상류 근거 sha 위조/Q3 상류 config 위조) 전부 검출, stage11/19
  PASS·stage13 정직 FAIL(결측 근거는 byte-backed 인정, predicate만 미달) 회귀 확인. → HIGH 0, clean.

## Round 3 (codex adversarial-review --base HEAD~3)
Verdict: needs-attention

- [high] Checkpoint validator does not enforce the same load contract as training
  → _validate_ckpt_file이 메타데이터 필드만 검사 — dtype/model_cfg/policy·optimizer state_dict
  실재·shape 미검증. 메타데이터-온리 위조 .pt(+JSON sha 정합)가 결측 근거/transfer 출처로 통과 가능.
  권고: 검증자가 학습 로드 계약을 재사용(state_dict 실로드) + resume 직렬화 전수 필드 요구 +
  메타-온리 .pt 거부 회귀 픽스처.

## Round 3 hot-fix (적용)
- `CKPT_REQUIRED_KEYS`(직렬화 전수 계약) 상수화 — train_seed state와 validator가 같은 목록 공유,
  누락 필드 = FAIL.
- _validate_ckpt_file이 **학습과 동일한 로드 계약을 실행**: dtype·model_cfg(pinned DEFAULTS 파생)
  대조 + pinned 정책/옵티마이저 인스턴스에 `load_state_dict` 실로드(shape/key 불일치 = 예외 =
  FAIL) + torch_rng uint8 텐서 검증. 메타-온리 위조 .pt 음성 픽스처로 거부 실증.

## Self-Review Round 3 (hot-fix 자체 적대 리뷰)
- CKPT_REQUIRED_KEYS = train_seed state 구성과 대조(greedy_plan만 비필수 — 게이트 판정에 미사용,
  위조 이득 0). model_cfg 기준값 = DEFAULTS 파생(hidden/conv는 CLI 비노출 = pin의 실체) — 인증
  산출물 3종으로 정합 실증. 검증자는 전역 RNG 비오염(set_rng_state 미호출, 타입/shape 검사만).
- 음성 픽스처 2종(R3-N1 메타-온리 .pt + sha 정합 위장 / R3-N2 hidden-64 shape 위조 state_dict)
  전부 거부 + 복원 PASS. stage11/19 PASS 회귀 0. → HIGH 0, clean.

## Round 4 (codex adversarial-review --base HEAD~4)
Verdict: needs-attention

- [high] Checkpoint validation only compares internal chain stage IDs
  → ck['chain']를 stage-id 열로 축약 비교 — 내부 세그먼트의 seed/mode/cleared/ckpt_sha/path 위조가
  통과(resume/transfer 시 chain이 그대로 복사되므로 오염 전파). 권고: 신뢰 사슬(검증된 외부 JSON
  chain)과 세그먼트 전체 메타데이터 대조 + 회귀 픽스처.

## Round 4 hot-fix (적용)
- `_validate_ckpt_file`의 기대값을 stage-id 열 → **세그먼트 레코드 리스트**로 승격: 내부 chain을
  contract 키 전체(stage_id/seed/mode/episodes/batches/wall_s/cleared/ckpt_sha/ckpt_path)로
  세그먼트별 대조 + **ckpt 자기-세그먼트 결속**(seg_mode/batch_i/episodes_seg/wall_seg/cleared_seg가
  외부 사슬 말단 레코드와 일치 요구 — 내부 카운터 위조로 구간 예산 회계 우회 차단).
- 회귀 픽스처: 유효 state_dict + 내부 chain seed/mode 위조 ckpt → 거부 실증.

## Self-Review Round 4 (hot-fix 자체 적대 리뷰)
- 3 호출부 기대 사슬 배선(현-스테이지=chain / transfer 출처=chain[:-1] / 결측 근거=ue.chain — 전부
  자기-세그먼트를 말단으로 포함) 실 산출물 3종 PASS로 정합 실증. wall_s float 등가(json repr 왕복) 확인.
- 남은 신뢰 루트 = 산출물 JSON ↔ ckpt 바이트가 링크마다 상호-앵커(사슬 sha 교차 + 내부 세그먼트 전
  키 + 자기-세그먼트 결속 + state_dict 실로드) — 위조하려면 pinned shape의 실 학습 상태를 재구성해야
  하는 수준. 음성 픽스처 2종(R4-N1/N2) 검출·복원 PASS. → HIGH 0, clean.

## Round 5 (codex adversarial-review --base HEAD~5)
Verdict: needs-attention

- [high] S19 cleared-seed predicate can be forged without per-seed evidence
  → predicate가 JSON cleared 불리언 자기-보고 — ckpt 비대상(S19)에선 seed별 증거 0, top-level
  actions만 replay(출처 미결속). 권고: 클리어 seed의 greedy_plan을 seed별 replay 실증 후에만
  predicate 가산 + actions=best_seed greedy_plan 결속 + 픽스처.

## Round 5 hot-fix (적용)
- 문법 검사 helper(`_grammar_canon`) 공용화 — top-level actions와 seed별 greedy_plan이 동일
  계약(라운드트립+마스크-표현 가능성+길이).
- **predicate = 검증된 클리어만**: cleared seed마다 greedy_plan 존재 요구 + 문법 canon + 엔진
  replay(pinned deadline, cleared & saved==hp 실측) — 실패 시 그 seed는 predicate 비가산 + FAIL.
- top-level `actions` == `best_seed`의 greedy_plan(검증-클리어 seed) 결속 — 출처 불명 plan 차단.
- 픽스처: stage19 cleared 불리언 위조(+무관 top-level actions) 거부 실증.

## Self-Review Round 5 (hot-fix 자체 적대 리뷰)
- predicate가 seed별 replay 실측으로만 가산 — stage13 정직 FAIL 불변(검증-클리어 0), stage11/19
  PASS(클리어 seed 전원 replay 실증, 스테이지당 +3 replay 비용 수용). best_seed 결속은 actions 존재
  시에만(비어 있으면 별도 fail 기존재). helper 공용화로 top-level/seed-plan 계약 드리프트 0.
- 음성 픽스처 2종(R5-N1 cleared 위조=미클리어 plan replay 실측 거부 / R5-N2 top-level actions 출처
  결속 위반) 검출·복원 PASS. → HIGH 0, clean.

## Round 6 (codex adversarial-review --base HEAD~6)
Verdict: needs-attention

- [high] R2 verifier trusts unpinned config.batch for episode-budget enforcement
  → 구간 에피소드 예산 오버슛 허용치(+batch)가 산출물 자기-보고 config.batch — 부풀리면 예산 초과
  세그먼트 통과. 권고: 실효 knob 전량(batch/lr/entropy 스케줄/hidden/conv/greedy_every/
  baseline_decay) 값-pin + 오버슛은 pinned 상수로.

## Round 6 hot-fix (적용)
- R2_PIN에 실효 학습 knob 전량 편입(batch/lr/entropy/entropy_min/entropy_decay/hidden/
  conv_channels/greedy_every/baseline_decay/reward) — verify-r2가 pin 전 키를 값-대조(비-config
  키 seeds/envs/grammar 제외). 오버슛 허용 = pin["batch"](자기-보고 config 비신뢰).
- 동일 결함류 선제 봉합: R0_PIN/R1_PIN에도 같은 knob 편입(기존 extra_cfg 값-대조 메커니즘이 자동
  강제 — stage11/12 pinned 산출물은 DEFAULTS와 일치라 PASS 불변) + _verify_pinned 오버슛도
  pin 상수화.
- 픽스처: config.batch 부풀림 → pin 대조 FAIL 실증.

## Self-Review Round 6 (hot-fix 자체 적대 리뷰)
- _KNOB_PIN(batch/lr/entropy 3종/hidden/greedy_every/baseline_decay/reward)을 r0/r1/r2 pin에 공통
  편입 — 기존 pinned 산출물 DEFAULTS 일치로 4게이트 PASS 불변(강화-무회귀 실증). verify-r2 config
  대조를 pin 전 키 루프로 일반화(누락 위험 제거), 오버슛 상수 = pin["batch"]·+60s.
- 픽스처(R6-N1: config.batch 999999 + 예산 초과 세그먼트) → pin 대조와 예산 검사 이중 검출, 복원
  PASS. → HIGH 0, clean.

## Round 7 (codex adversarial-review --base HEAD~7)
Verdict: needs-attention

- [critical] Pinned stage13 R2 artifact cannot pass its own verifier
  → 커밋된 stage13.rl2.json이 pass=false·actions=null인데 독스트링이 `--verify-r2 --stage 13`을
  검증 커맨드로 광고 — 정직 FAIL 실험과 shippable 산출물의 구별 부재. (참고: 메인 execute 게이트
  (frontmatter verify)에는 verify-r2 미편입 — CI 차단은 없음.)
- [high] Checkpoint provenance is byte-backed but not repository-pinned
  → rec['path']를 그대로 resolve — 절대경로/저장소 밖 경로 허용, chain 메타에 절대 D:\ 경로 잔존
  (비이식). 권고: `ckpt_path(sid,seed)` repo-상대 정본 경로 강제 + 기존 메타 정규화.

## Round 7 hot-fix (적용)
- [critical] 광고/문서 정합: 독스트링 verify 예시를 `--stage {11,19}`(인증 산출물)로 교정 +
  stage12/13 rl2.json = acceptance 2 FAIL의 **정직 박제 기록**(verify-r2 거부가 기대 동작)임을
  독스트링·plan §R2 실측 결과에 명시. FAIL 조작(재생성 강제·박제 삭제)은 plan "silent 재스코프
  금지"에 반하므로 채택하지 않음 — 구별은 문서+rl_meta.pass가 담당.
- [high] `_validate_ckpt_file`에 **정본 경로 pin**(rec.path == ckpt_path(sid,seed) repo-상대,
  이탈 거부) + chain 세그먼트·ckpt_loaded의 ckpt_path 정본 검사 + `_ckpt_segment` 경로 _rel 정규화
  (forward) + **기존 ckpt/rl2 메타 마이그레이션**(절대경로 → repo-상대, sha 연쇄 재계산: S12 ckpt
  3개 → S13 ckpt → 산출물 사슬 기록).

## Self-Review Round 7 (hot-fix 자체 적대 리뷰)
- 정본 경로 pin이 3경로(rec 해석·chain 세그먼트 메타·ckpt_loaded)를 전부 커버 — 절대경로/이탈/임의
  로컬 파일 공급 우회 차단. 마이그레이션 후 stage12/13 정직 FAIL의 사유가 predicate/pass/actions
  **만**임을 실측(무결-오류 0 = sha 연쇄 재계산 정합; stage12 seed2 클리어는 replay-실증 1/3 반영).
- CRITICAL 처리 방식 검토: FAIL 산출물 재생성/삭제는 plan 정직-박제 원칙 위반 — 문서 정합(독스트링
  게이트 예시 교정 + plan 산출물 상태 명시)이 정공법. 메인 verify 게이트 비편입 재확인(CI 차단 없음).
- 픽스처(R7-N1 절대경로) 검출·복원 PASS, stage11/19 PASS. → HIGH 0, clean.

## Round 8 (codex adversarial-review --base HEAD~8)
Verdict: needs-attention

- [high] Checkpoint verification does not prove optimizer state is usable
  → opt.load_state_dict는 attach만 — Adam 슬롯 텐서(exp_avg/exp_avg_sq) shape/dtype 오염 ckpt가
  통과하고 첫 재개 opt.step()에서 크래시. 권고: 파라미터별 슬롯 검증 또는 dummy step + 픽스처.

## Round 8 hot-fix (적용)
- _validate_ckpt_file에 **optimizer 슬롯 전수 검증**: 파라미터별 exp_avg/exp_avg_sq shape·dtype
  일치 + step 카운터 존재 + param_groups lr == pinned — attach-만 통과하는 재개-불능 위조 거부.
- 픽스처: exp_avg shape 오염(+정합 sha 재기록) ckpt → 거부 실증.

## Self-Review Round 8 (hot-fix 자체 적대 리뷰)
- 최초 구현("슬롯 부재=위조")이 **실 ckpt에서 거짓양성** — Adam lazy 초기화: 스테이지에서 활성
  불가능한 head(S11의 col 등)는 그래프 밖 = 슬롯 없음이 정상이고 그 resume은 lazy 재초기화로 기능
  (실측으로 잡음). 계약 정정 = **존재 슬롯의 shape/dtype 정합**(진짜 재개-크래시 위험)만 fail-closed +
  step 존재 + 파라미터-범위 + lr pinned. 빈-state 위조는 기능적으로 재개 가능하므로 이 검사의 관할
  아님(학습-됨 여부는 카운터·사슬 결속이 별도 강제) — 근거 코드 주석 박제.
- 픽스처(R8-N1 exp_avg shape 오염+sha 정합 재기록) 거부·복원 PASS, stage11/19 PASS. → HIGH 0, clean.

## Round 9 (codex adversarial-review --base HEAD~9)
Verdict: needs-attention

- [high] Malformed torch RNG state can pass checkpoint verification but break exact resume
  → torch_rng 검사가 uint8·non-empty만 — 1바이트 텐서로 교체(+sha 재기록)하면 verify 통과 후
  --resume-ckpt의 set_rng_state에서 즉사. 권고: set/restore 왕복(전역 RNG 복원) 또는 정확 길이 대조.

## Round 9 hot-fix (적용)
- _validate_ckpt_file이 **set_rng_state 실왕복** 실행: old 저장 → set(tr) try/except → finally
  restore(old) — 로더와 동일 계약, 전역 RNG 무오염. 픽스처(1바이트 uint8 RNG) 거부 실증.

## Self-Review Round 9 (hot-fix 자체 적대 리뷰)
- set/restore 왕복이 로더와 동일 계약(실측: 1바이트 위조 → "size 5056 기대" RuntimeError 거부),
  finally 복원으로 검증자 전역 RNG 무오염(verify는 어차피 학습 RNG 미사용이지만 위생 유지).
- 픽스처 거부·복원 PASS, stage11/19 PASS. → HIGH 0, clean.

## Round 10 (codex adversarial-review --base HEAD~10)
Verdict: **approve** — "No ship-blocking fail-open, forgery, or verifier-bypass path found."
(codex 권고 런타임 확인 = verify-r2 --stage 11/19: 검증자 측에서 기실행 PASS — 아래 종결 스윕.)

## §R2 impl 리뷰 루프 종결 (2026-07-04)
- 경로: codex R1(2H+1M) → R2(2H) → R3(1H) → R4(1H) → R5(1H) → R6(1H) → R7(1C+1H) → R8(1H) →
  R9(1H) → **R10 approve**. 누적 = CRITICAL 1·HIGH 11·MED 1 전부 hot-fix(9커밋), 매 라운드
  자체리뷰 clean + 음성 픽스처 실증(누적 ~20종).
- 종결 스윕(전부 그린): verify-r0(3/3)·verify-r1(2/3)·verify-r2 stage11(3/3)/stage19(3/3)·
  coverage r1.1·coverage r2.1 — stage12/13은 정직 FAIL 박제(무결-오류 0, 사유=predicate/pass/actions).

## §R3 impl 리뷰 (2026-07-05) — trace-refinement MDP

### Round 1 (codex adversarial-review, working-tree) — verdict: needs-attention (HIGH 2·MED 2)
- **[HIGH-1] exec digest가 stage 파일 미해시(추정)** — *오탐*. codex가 `:02d`를 `:03d`("stage013.tres")로
  오독. 실측 반증: `data/stages/stage13.tres` 등 존재·content 해시(stage13 exec digest ≠ stage11).
  → **인접 유효점 채택**: `_exec_config_digest`가 스테이지 리소스 누락 시 `FileNotFoundError`(silent None 금지).
- **[HIGH-2] verify_r3가 자기보고 `throughput.floor_reached` 신뢰** — *유효*. 위조 floor_reached=true로
  under-budget FAIL을 legit model_fail로 위장 가능(replay 스킵 경로라 특히 위험). → **수정**: `_floor_reached()`
  = raw 카운터(episodes_completed/distinct_prefix_rollouts) 재계산. verify_r3가 산출물 bool과 대조(불일치
  FAIL) + outcome을 재계산 floor로 재판정. train_seed도 동일 헬퍼로 회계.
- **[MED-3] obs_schema_digest가 rasterize 시맨틱 미결속** — *유효*. 채널/스칼라 이름·분모만 pin →
  clamp·state→채널 매핑·마커·물사 로직 변경이 digest 불변(ckpt/산출물이 비호환 obs로 통과). → **수정**:
  rasterize를 순수 함수 `rasterize_channels/rasterize_scalars`로 추출 + 고정 합성 (layout,trace,res)의
  `_obs_golden()` 벡터를 obs_schema에 결속. 시맨틱 변경 = golden 변경 = obs_schema_digest 변경.
- **[MED-4] R3 ckpt가 `.r2.pt` 경로 재사용 → R2 ckpt 덮어씀** — *유효·파괴적*. `--refine --save-ckpt`가
  추적된 `stage13_seed2.r2.pt`(R2 byte-backed) 덮어씀 실측 확인. → git 복구 + **수정**: `ckpt_path(refine=True)`
  = `.r3.pt`. run_training r3 저장이 이 경로 사용.
- **자체 적대 리뷰(수정 후) clean**: floor 재계산·ckpt 경로·golden 결속·fail-closed 인접 전부 정합, 회귀 0.

### 수정 후 재검(전부 그린)
- verify-r3(S13, mode=primary, outcome=pass, 3/3, telescoping OK) + **음성 9/9 검출 + 복원 PASS**
  (refine_false·trace_channels·obs_digest·memo_members·off_grid·nonpinned_seed·max_len·floor_tamper·
  outcome_forge). floor_tamper 음성이 HIGH-2 수정 실증.
- 회귀 0: coverage-r2·verify-r0(3/3)·verify-r1(2/3)·verify-r2(S19 3/3) PASS(기존 frame byte-identical).
- 결정론: memo(on vs --no-memo) byte-identical·재개 등가성(refine, 파라미터 비트동일+곡선 일치) PASS.
- 산출물 재생성: stage13.rl3.json(new obs digest) + stage13_seed{0,1,2}.r3.pt(3/3 클리어, 결정론 동일 해).

### Round 2~6 (codex 재리뷰 — verify_r3 fail-closed 조이기, 매 라운드 자체리뷰 clean + 음성 확장)
- **R2 (1 MED)**: verify_r3가 `exec_config_digest` 재계산만 하고 값 미대조. → 재계산 digest == 산출물 대조
  (rollout 의존 drift/위조 fail-closed) + 음성 `exec_digest`.
- **R3 (2 MED)**: (a) exec digest가 raw `GODOT_BIN` env(미설정 시 빈 문자열, find_godot 폴백 미반영) →
  `str(Path(find_godot()).resolve())` 바인딩·fail-closed. (b) verify_r3가 mode=primary에 variant/trace_blind
  미강제 → variant↔mode + `config.trace_blind` falsy 강제 + 음성 `variant_masq`/`trace_blind_masq`.
- **R4 (2 MED)**: (a) 선택 경로↔mode 미결속(dense 아티팩트 primary 경로 복사 통과) → 선택 경로가 기대
  mode/variant/pin 결정(self-report pin 선택 폐기) + 음성 `mode_masq`. (b) `ckpt_saved` 생략 시 ckpt 검증
  침묵 스킵 → `rl_meta.save_ckpt` 플래그 계약(true=seed별 필수·false=부재 필수) + 음성 `ckpt_strip`.
- **R5 (2 MED)**: (a) `trace=True` replay 에러 침묵 통과(`"error" not in rt2` 조건) → error 명시 FAIL.
  (b) ckpt가 seed/경로 미결속 → 정확 경로(`_rel(ckpt_path(stage,seed,refine=True))`) + `_ckpt_compat(resume)`로
  seed/stage/grammar/vocab/layout/mask/model_cfg 대조 + 음성 `ckpt_crossseed`.
- **매 라운드 사이 자체 적대 리뷰 clean** + 산출물 재생성(R2·R3·R4는 digest/save_ckpt 필드 변경으로 재학습;
  전부 3/3 결정론 동일 해). 수정 후 스윕: verify-r3 PASS + 음성 **16/16 검출 + 복원 PASS** +
  회귀 0(verify-r0/r1/r2·coverage-r2·memo 결정론·재개 등가성).

### Round 6 (1 MED) — plan-pin 모순 → **사용자 표면화 → plan 개정(AND) 결정**
- codex 권고: `_floor_reached()` model_fail 인증을 OR→**AND**(episodes≥3000 **및** distinct≥1500)로.
- plan §R3가 THROUGHPUT_FLOOR를 명시적 "또는"(OR)로 pin했으므로 impl 임의 변경 불가 → **사용자 표면화**
  (AskUserQuestion, OR/AND 트레이드오프 설명). **현재 영향 0**(전 seed PASS라 floor 로직 dormant).
- **사용자 결정(2026-07-05) = AND**: MIN_DISTINCT의 pin 근거("해 공간 격자 하한 = 실패라 말할 자격이 되는
  최소 탐색 커버리지")와 정합. → `_floor_reached` AND + **plan §R3 텍스트 개정(또는→AND)** + 음성
  `floor_single_axis`(5000ep/100dist claiming floor_reached=true → AND면 미도달 → 대조 FAIL).

### Round 7 (1 MED) — verify_r2 §R2-R5 패턴 미계승 → 수정
- codex: verify_r3의 n_clear가 seed별 자기-보고 `cleared` bool 신뢰 + replay는 top-level plan만 검증
  (multi-seed predicate replay-미실증). verify_r2는 이미 `verified_clear`로 강화된 표준.
- **수정**: seed별 `greedy_plan`을 `_grammar_canon` + 엔진 replay(pinned deadline, saved==hp)해 **실증된
  것만** `verified_clear`에 가산 → `n_clear=len(verified_clear)`. outcome/mechanical_pass는 verified_clear
  파생. top-level `actions == best_seed.greedy_plan` ∧ `best_seed ∈ verified_clear` 결속. 음성
  `seed_evidence_forge`(2 seed cleared=true·greedy_plan 제거 → verify FAIL).

### Round 8 — **approve (no material findings)** = impl 리뷰 루프 종결
- verdict=approve("Ship: no remaining material fail-open or correctness gap"). 매 라운드 사이 자체 적대
  리뷰 clean + 음성 픽스처 **18종** 누적 전부 검출 + 복원 PASS.
- **8 라운드 요약**: R1(실버그 3 — 파괴적 ckpt 덮어쓰기·false-green)·R2~R5·R7(verify fail-closed 조이기
  = exec digest 대조·godot resolve·A/B 경로격리·ckpt seed결속·trace error·predicate replay실증)·
  R6(plan-pin OR→AND 사용자 결정). CRITICAL 0·HIGH 2(R1, 전건 수정)·MED 다수(전건 수정).

# §R4 impl-stage 적대 리뷰 (2026-07-10~11, 재개 세션 — 리뷰 범위 = acceptance-완료 세션 변경분)

> 범위: train.py 2건(verify_r4 문법-정확성 fail-closed + accept_resume_equiv r4 확장) +
> `rl/experiments/verify_r4_probes.py`(신규) + stage12/19.rl4.json(비회귀 산출물) + 문서 3종
> (세션 로그 §9~10 / STATUS §R4 종결 / plan §R4 실측 결과+개요 정정). 실측(acceptance 1~6·게이트)은
> 세션 로그 §9~10 박제. 리뷰 방식 = codex exec read-only(§R3 working-tree 선례).

## Round 1 (codex) — needs-attention: MEDIUM 1 + LOW 1 (CRITICAL/HIGH 0)
- **MEDIUM — acceptance 4 pinned-격리 계약 drift**: plan §R4 acceptance 4 문구가 verify-r3(S13)를
  격리 세트에 포함하는데, 실측 5/5 세트는 verify-r3 제외(세션 로그 §5의 cross-PC 판정 불가) —
  계약문 미개정 상태로 "게이트 종결" 주장은 모호.
- **LOW — probe 스크립트 경로 drift**: 워크로그 §10이 scratchpad 경로를 가리키나 실제 보존은
  `tools/solver/rl/experiments/verify_r4_probes.py`(STATUS/plan은 리포 경로).
- 코드-레벨 blocker 없음(codex 명시: exact-roundtrip 검사 fail-closed 적절 + refine r2.1-전용 가드 보존).

### 수정 (2건 전부)
1. plan §R4 acceptance 4에 **실측 개정 공시** 명문화: verify-r3 판정 불가 사유(exec digest godot
   경로 결박 — 선존 한계·회귀 아님·이 세션 수정 파일 0) + 실측 세트 = r0·r1·r2×2·r2.1 resume-equiv
   5/5(§14.4 동일 세트) + 재인증 경로(생성 PC or 경로→콘텐츠-해시 개정).
2. 워크로그 §10 probe 경로를 리포 보존 경로로 정정(리포 위치 재실행 13/13 재확인 문구 포함).

## Self-Review Round 1 (수정 후 자체 적대 리뷰) — clean (HIGH 0)
- 계약 공시가 "acceptance 4 = PASS" 주장과 정합(실측 세트 명시로 과대주장 제거, 5/5 산식 일치).
- cross-doc 재검: plan 실측 결과·STATUS·워크로그의 격리 세트 서술 모두 "r0/r1/r2×2/resume-equiv"로
  일치. probe 경로 3문서 일치. 수치(235/240·0.99·13/13·1/3·3/3·2/3) 상호 일치 재확인.
- 잔여 위험 없음 판단 → codex Round 2 재리뷰로.

## Round 2 (codex) — **approve (findings 0) = §R4 impl 리뷰 루프 종결**
- 수정 1 적정: acceptance 4 실측 개정 공시가 verify-r3 판정 불가 사유 + 실제 5/5 산식 명시로
  과대주장 해소, STATUS/워크로그/plan/트레일 동일 세트 정렬·신규 drift 없음(codex 확인).
- 수정 2 적정: probe 리포 경로 실존 + 정상 구조 확인(scratchpad 잔존 참조는 R4 coverage JSON 별건 —
  Round 1 LOW 재발 아님).
- 신규 CRITICAL/HIGH/MEDIUM 없음. verdict=approve.

# §16 stall-escalate (knowledge 정체-격발 레시피) impl-stage 적대 리뷰 (2026-07-11)

> 대상 = `746783e..389097b`(+후속 수정 워킹트리): train.py StallGovernor+train_seed_escalate+CLI,
> experiments/{stall_governor_probe,trap_v2_test}.py, 워크로그 §16. 사후 리뷰(389097b push 후 —
> CLAUDE.md 사후-리뷰 정책: HIGH=hot-fix 커밋+동일 루프).

## Self-Review Round 1 (codex 실행과 병행)
- [MEDIUM] 산출물 자기-기술 공백: r2 artifact writer per-seed entry가 stall_escalation/
  knowledge_governor 미동승 — 어느 seed가 escalate로 클리어했는지 산출물에서 식별 불가.
  → 수정: 있을 때만 entry에 동승(비-stall 런 entry는 키 구성 불변).
- [MEDIUM] 수치 오기: §16.7/커밋 메시지 "always 10/12" — 실측은 11/12(S12 s2는 2배 지연이지
  FAIL 아님). → 워크로그·STATUS 정정(커밋 메시지는 오기 사실을 문서에 박제).
- 그 외 clean(잔재 참조 grep 0, syntax OK, probe 그린 유지).

## Round 1 (codex) — needs-attention
- **[HIGH] escalated ckpt의 resume 계약 위반**: train_seed_escalate가 반환하는 state = 구출 런의
  always-포맷(knowledge_ledger 동승). 이를 같은 stall CLI로 --resume-ckpt하면 k_mode=stall이라
  ledger 미생성(ckpt ledger 무시) + fresh governor = **결정론 resume이 아님**(침묵 오염, 후속
  transfer 사슬 전파 위험).
- 수정(권고안 채택): ① ckpt에 `knowledge_mode_effective`("always"/"stall_detect", coef=0은 키
  부재=기존 구성 불변) 박제 ② resume 시 cfg 유효 모드와 fail-closed 대조(불일치=RuntimeError,
  escalate ckpt는 always CLI로 재개 안내). 레거시 ckpt는 동승 키(knowledge_ledger/governor)로
  추론(§14.4 ckpt 하위호환). transfer는 §12 SOP대로 리셋이라 비대상.
- 검증(codex 권고 probe 확장): D1 = escalated ckpt + stall CLI 재개 → fail-closed 거부 실증 /
  D2 = escalated 재개 등가성(무중단 2N vs N→save→always 재개 N: **파라미터 비트동일 + 곡선
  일치**). probe 13/13 PASS + pinned 격리 5종 재실행 PASS(coef=0 ckpt 키 불변 실증).

## Self-Review Round 2 (R1 수정 후)
- k_eff 산식 = ledger/governor 생성 조건과 동일 원천(불일치 불가능) / resume 가드는 transfer
  비적용(§12 정합) / coef=0 state 키 구성 불변(pinned resume-equiv 보존) / 레거시 추론 =
  §14.4-era ckpt 정상 재개 확인. 신규 HIGH 0 — clean.

## Round 2 (codex) — needs-attention
- **[HIGH] 재개된 stall-검출 런이 격발 시 구출 불가**: R1 가드의 인접 결함 — 중단된 stall_detect
  ckpt를 stall CLI로 재개(합법)한 뒤 격발되면, escalate가 원본 ckpt(stall_detect)를 always_cfg와
  함께 rescue에 전달 → R1 가드가 정확히 구출 시점에 RuntimeError. D1/D2는 이미-escalate된
  ckpt만 커버(경로 공백).
- 수정: rescue ckpt 라우팅 분기 — **resume-모드면 무-ckpt 재시작**(문서화된 escalate 의미론 =
  같은 seed × 처음부터 always; 검출 진행분은 진단용이라 폐기가 정합) / **transfer는 보존**
  (가중치 warm-start = 사용자 의도, §12 SOP 리셋이라 모드-가드 비대상 — codex 권고의 "transfer
  분리 취급" 채택).
- 검증: probe E 신설(미격발 stall_detect 저장 → stall 재개 → 격발@6 → 구출 완주 + 최종 상태
  effective=always) — **14/14 PASS**.

## Self-Review Round 3 (R2 수정 후)
- 라우팅 전수: scratch 검출(None 전달, 종전 동일) / resume 검출(→scratch rescue, E 실증) /
  transfer 검출(→transfer rescue, 가드 비대상·의도 보존). run_training 경유 wrapper는 비-stall
  cfg 무변경 통과(위임) — pinned 경로(verify-*, accept-resume-equiv)는 wrapper 미경유 또는
  비-stall이라 원천 무영향. 신규 HIGH 0 — clean.

## Round 3 (codex) — needs-attention
- **[HIGH] transfer-유래 검출 런의 재개→격발 하이브리드 경로**: R2 라우팅이 ckpt_mode만 보고
  분기해, transfer로 시작→중단→재개(seg_mode="transfer" 전파)된 검출 런이 격발하면 구출을
  **scratch로 silent 강등**(사용자의 transfer warm-start 의도 파기). 재개 ckpt엔 transfer 원본
  경로가 저장되지 않아 구출 레짐 재구성 불가.
- 수정: codex 권고 2안 중 **fail-closed 채택** — `ckpt_mode=="resume" and seg_mode=="transfer"`
  격발 시 RuntimeError + 명시 재실행 안내(--knowledge-mode stall --transfer-ckpt <원본>).
  재구성안은 ckpt에 원본 경로 부재로 불가(정직 사유).
- 검증: probe F 신설(미격발 검출 상태에 seg_mode="transfer" white-box 주입 — resume 전파 값과
  동형 — 재개→격발 시 "transfer" 명시 RuntimeError 확인) — **15/15 PASS**.

## Self-Review Round 4 (R3 수정 후)
- ckpt 라우팅 4경로 전수: scratch(무-ckpt 종전) / resume-scratch유래(→scratch rescue, E) /
  resume-transfer유래(→fail-closed, F) / direct transfer(→transfer rescue, 가드 비대상).
  seg_mode 전파는 train.py:1163/1190 실코드 확인. 신규 HIGH 0 — clean.

## Round 4 (codex) — **approve (종결)**
- "No ship-blocking issue found in the R4 stall-escalate fix. The four checkpoint routes are
  explicitly handled, the transfer-derived resume escalation now fail-closes, and probe D/E/F
  cover the adjacent resume/escalation regressions. No material findings."
- 루프 요약: codex R1[H1 escalated-ckpt 오재개] → fix(모드 박제+fail-closed 가드+D1/D2) →
  Self-R2 clean → codex R2[H1 재개-검출 격발 크래시] → fix(rescue 라우팅 분기+E) → Self-R3 clean
  → codex R3[H1 transfer-유래 재개 silent 강등] → fix(fail-closed+F) → Self-R4 clean →
  **codex R4 approve**. 자체 선제 수정 2건(MEDIUM: 산출물 escalate 회계 동승 + "always 10/12"
  수치 정정) 포함. 최종 게이트: probe 15/15 + pinned 격리 5/5(매 라운드 재확인, 값 전부 종전 동일).

---

# §17 전 스테이지 스윕 + '정리된 해' 레지스트리 impl-stage 적대 리뷰 (2026-07-12)

> 대상: 커밋 `fa525e5`(솔루션 레지스트리·궤적 보고서·스윕 러너, base `a107a40`). **사후 리뷰**
> (push 후 — 워크로그 "codex 리뷰 이월" 이행). 스코프 branch(워킹트리의 사용자 그림-레벨 WIP 제외).
> 부트스트랩: 핀 `gpt-5.6-sol`이 npm codex-cli 0.124.0에서 거부("requires a newer version") →
> CLI `0.145.0-alpha.4`(alpha 채널)로 업그레이드해 해결. 모델 probe: gpt-5.7/5.7-sol/5.6/5.6-codex
> 전부 400(ChatGPT 계정 미지원) — 핀 유지.

## Round 1 (codex) — needs-attention (HIGH 1 + MEDIUM 3)

- **[HIGH] 레지스트리 read-modify-replace 동시성·손상 불안전** (solution_registry.py):
  ① 병행 학습 2개가 같은 스테이지 기록 시 마지막 replace가 상대 갱신 유실 + 공유 `.json.tmp`
  경합 ② `load_registry`가 손상 JSON을 None으로 뭉개 다음 클리어가 **빈 레지스트리로 조용히
  전체 파기** ③ `_record_found` 예외 삼킴이라 stdout 외 흔적 없음.
- **[MEDIUM] 리플레이 캐시 레벨 미결속** (found_viewer.py): 키=stage 경로+deadline+actions뿐 —
  레벨 변경 후 같은 플랜이 같은 캐시 파일명을 얻어 **옛 레벨 궤적/지표를 현재 보고서에 재사용**.
- **[MEDIUM] 스윕 실패를 done으로 위장** (sweep_stages.py): 크래시·집계줄 부재도 done=true +
  runner exit 0 — 재개 시 스킵돼 실패 스테이지가 캠페인에서 조용히 증발.
- **[MEDIUM] partial이 최신-런 기준이라 최고-진척 아님** (train.py/found_viewer.py): 사이드카
  무조건 교체 + 뷰어 최신-ts 선택 → 나중의 약한 런이 이전 최고-진척을 보고서에서 제거
  ("가장 멀리 도달" 계약 위반, 재학습만으로 보고서 퇴행).

## 수정 (전 4건 hot-fix — MEDIUM 포함 전부 수정, defer 0)

- **H1**: `_stage_lock`(OS-수준 msvcrt/fcntl 논블로킹 잠금+타임아웃 — 프로세스 사망 시 자동
  해제라 stale-break 불필요) 으로 load→mutate→replace 직렬화 + 라이터-고유 tmp(`.tmp<pid>`) +
  `load_registry` missing(None)/corrupt(`RegistryCorruptError`) 구분 + 손상 시 **quarantine**
  (`.corrupt-<ts>.json` 보존-이동, durable 흔적) 후 raise — 조용한 전체 파기 원천 차단.
  예외 삼킴 계약(학습이 1차)은 유지하되 손상본이 durable 증거로 남는다.
- **M1**: 캐시 키를 `solution_registry.replay_cache_key`(현재 **레벨 digest+스키마 버전 결속**,
  migrate와 단일 출처)로 교체 + 캐시 payload `_cache` 결속(schema+level_digest) 검증(이중
  안전망). 레거시 키 캐시는 전량 자동 미스(--replay 재생성 필요 — 재생 가능 아티팩트).
- **M2**: 성공 판정 `run_ok(rc, tail)` = 집계줄 존재 AND rc∈{0,1}(1=무클리어 완주는 정당한
  발견 결과, 2=설정오류) — 실패는 done=false 잔존(재실행 자동 재시도)+attempts 카운트,
  실패 ≥1이면 runner exit 1 + 말미 요약.
- **M3**: 뷰어 partial을 **전-이력 로드**(정확 중복만 제거) → 플랜-클래스 병합 → 리플레이 부착
  → **스테이지별 리플레이-best 1개** 선정으로 재구성. 사이드카=최신 스냅샷·권위=partials.jsonl
  전 이력임을 train.py docstring에 명문화(동작 무변경).

## Self-Review Round 1 (수정 후)
- **[self-HIGH] O_EXCL 락파일 초안의 stale-break 삭제 레이스**(A의 stat→unlink 사이 B가 갓
  획득한 신선한 락을 삭제 가능) → OS-수준 잠금(msvcrt/fcntl)으로 교체해 해소(위 H1 최종형).
- 점검 clean: quarantine 파일명이 뷰어 glob(`*.solutions.json`) 비매칭·gitignore 대상 /
  registry 레코드(actions/stage/deadline_frames) 캐시 키 필드 충족 / 클래스 dedup의 deadline
  비포함은 선재 의미론(비악화) / probe monkeypatch 원복 확인. 잉여 빈 줄 1건 정리.

## 검증 (Round 1 수정)
- **신설 `experiments/registry_guard_probe.py` 19/19 PASS**: P1 손상=quarantine+보존+비파기
  +재시작 / P2 병렬 8프로세스 기록 유실 0 / P3 digest 변경→키 변경+결속 불일치 미스+일치 히트 /
  P4 성공판정 5조합 / P5 약한-나중-런이 이전 최고를 못 가림(전-이력+best 선정).
- **pinned verify 4/4 PASS 재확인**(r0·r1@12·r2@11·r2@19 — §17 보고서와 동일 세트, 값 동일:
  S11 f=1342/S12 f=2239/S11 f=1488/S19 f=1583).
- 실전 라운드트립: 뷰어 오프라인 빌드(15해/12스테이지 불변) + `--replay --stages 11` 신규-키
  캐시 생성 → 오프라인 재빌드 캐시 히트+궤적(폴리라인) 포함.

## Round 2 (codex) — needs-attention (HIGH 1 + MEDIUM 2)
- **[HIGH] parse-valid 손상 우회** (solution_registry.py): 유효 JSON이지만 구조가 깨진
  레지스트리(예: solutions는 남고 level_digest 누락)는 R1 수정의 JSONDecodeError 경로를 지나쳐
  **'레벨 변경'으로 오인 → 파기**. 기타 위반 형태는 무관 예외로 quarantine 미진입.
- **[MEDIUM] 레거시 state false-done 영구 스킵** (sweep_stages.py): 구버전 러너가 크래시에도
  done=true를 썼으므로, 업그레이드 후 기존 sweep_state.json 재실행 시 **정확히 그 실패
  스테이지들이 스킵**됨(run_ok는 신규 실행에만 적용됐음).
- **[MEDIUM] 클래스 dedup이 리플레이 전에 후보 폐기** (found_viewer.py): plan_key는 의도적
  손실(60f 버킷·셀 양자화) — 같은 클래스의 raw 플랜(at_frame 60 vs 119)이 리플레이 결과가
  달라도 부착 전 best_reward 비교만으로 더 나은 쪽이 영구 폐기될 수 있음.

## 수정 (Round 2 — 전 3건)
- **H1**: `_schema_error`(최상위 dict / stage_id 일치 / level_digest 키 존재+형식 / solutions
  list / 각 해의 plan_key·actions·seeds·exec_digest 타입) 검증을 `load_registry`에 편입 —
  위반 = RegistryCorruptError → 기존 quarantine 경로. 뷰어 `load_registries`도 동일 스키마로
  warn-skip(표시 전용). **커밋된 실 레지스트리 15해/12스테이지 전부 스키마 PASS 확인.**
- **M1**: `state_entry_ok` — done=true라도 저장된 rc/summary를 run_ok로 **재검증** 후에만 스킵
  (레거시 false-done 자동 재시도, 필드 결손도 재시도).
- **M2**: 파이프라인 재배열 — 리플레이를 **raw 플랜 전체에 선부착** → 클래스 병합(리플레이
  지표로 대표 선정) → 스테이지 best. 동일 raw 플랜은 캐시 히트라 실제 Godot 실행 수 = distinct
  플랜 수(알려진 비용: 이력 누적 시 리플레이 대상 증가 — 현 레벨·미클리어 스테이지 한정으로 bounded).

## Self-Review Round 2 (수정 후)
- state_entry_ok의 rc None→TypeError→False(fail-closed) / _schema_error가 커밋 레지스트리와
  정합(16-hex digest) / dedup 대표 병합 메타(_seeds/_runs) 불변 / 뷰어 스키마 가드는 표시
  전용이라 warn-skip이 적정(파기 권한은 record_clear에만). 신규 HIGH 0 — clean.

## 검증 (Round 2 수정)
- **probe 확장 33/33 PASS**: P1b parse-valid 손상 quarantine+기존 해 잔존+오인 파기 없음
  +위반 3유형 검출 / P4b 레거시 false-done 재시도·정상 완주 스킵 유지 / P5b 동일-클래스 리플레이
  변별(보상 열위·리플레이 우위 raw 플랜이 대표).
- 실 레지스트리 15해 스키마 ALL PASS + 뷰어 오프라인 빌드 15해/12스테이지 불변 + S11 --replay
  라운드트립 캐시 히트 유지.

## Round 3 (codex) — needs-attention (HIGH 1 + MEDIUM 2)
- **[HIGH] 비-hex digest가 스키마 통과 → 파기 재발**: R2 검증이 '16자 문자열'만 요구해
  `"x"*16` 같은 parse-valid 손상이 통과 → '레벨 변경' 오인 파기 경로 재개방.
- **[MEDIUM] 뷰어 stage_id 자기-대조**: `_schema_error(reg, reg.get("stage_id"))`는 자기 자신과
  비교라 무의미 — stage01 파일에 stage_id=2 내용이면 스테이지 2로 표시되고 covered 오염으로
  정당한 레거시 기록이 억제됨.
- **[MEDIUM] 스윕 state가 seeds/레시피 미결속**: `--seeds 0` 완료 후 `--seeds 0,1,2` 재실행이
  스테이지를 스킵해 seed 1,2가 조용히 누락. 레시피 변경에도 옛 완료가 생존.

## 수정 (Round 3 — 전 3건)
- **H1**: `_is_hex16`([0-9a-f]{16} 전수 검사)을 level_digest·plan_key·exec_digest에 적용.
- **M1**: 뷰어가 기대 stage_id를 **파일명**(`stage(\d{2,3}).solutions.json` 정규식)에서 파싱해
  `_schema_error` 대조, 비정규 파일명 warn-skip. sid의 SoT = 파일명.
- **M2**: `campaign_fingerprint`(정규화 seeds + RECIPE 전체 + STATE_SCHEMA sha16)를 state
  엔트리에 저장, `state_entry_ok`가 지문 일치까지 요구(지문 없는 레거시 = 재시도).
  기존 sweep_state의 S1·S2 완료 엔트리도 재시도 대상이 되나 dup 처리라 무해(보고서 §17 명시).
- **자체 선제 수정**: `_quarantine` 이름이 초 해상도라 같은 초 내 재격리가 선행 격리본을
  덮어씀 → 존재-검사 카운터 유일화(락 내부 호출이라 레이스 없음).

## Self-Review Round 3 (수정 후)
- sha256 hexdigest=소문자라 _is_hex16 정합 / 파일명 정규식이 dev fixture(stage990, 3자리) 포함 /
  fingerprint는 json sort_keys 결정론 / state_entry_ok 시그니처 변경의 호출측 전수 갱신 확인.
  신규 HIGH 0 — clean.

## 검증 (Round 3 수정)
- **probe 39/39 PASS**: 비-hex level_digest/plan_key 검출 + 비-hex digest→파기 아닌 quarantine
  + 재격리 이름 유일화 / 지문 없는 레거시·seeds 변경 재시도 + seeds 정규화 동치 / 뷰어 파일명↔
  내용 불일치 미표시·covered 미오염.
- 실 레지스트리 15해 hex-강화 스키마 ALL PASS + 뷰어 오프라인 빌드 15해/12스테이지 불변.

## Round 4 (codex) — needs-attention (MEDIUM 2, HIGH 0)
- **[MEDIUM] 캠페인 지문이 스윕 대상 콘텐츠 미포함**: 성공 후 레벨(씬/레이아웃/리소스)이나
  트레이너 구현이 바뀌어도 지문이 유효해 스킵 — 바뀐 스테이지가 미발견 상태로 남고 레지스트리
  파기-대기가 영구화될 수 있음.
- **[MEDIUM] 파일명 정규식이 숫자 별칭 허용**: `stage001.solutions.json`이 stage_id 1로 통과 —
  스키마-유효 빈 별칭이 covered를 오염해 정당한 레거시 기록 억제·카드 중복 가능.

## 수정 (Round 4 — 전 2건)
- **M1**: state 엔트리에 per-stage `level_digest` 저장 + 스킵 시 현재 digest 대조(변경/산출
  불가(None)/레거시 무-digest = 재시도). 캠페인 지문에 **train.py 소스 sha16** 포함(CLI 동일해도
  트레이너 개정이면 전량 재시도 — 가장 보수적·정직한 대리, 재실행은 dup 처리라 무해).
- **M2**: 파싱 sid의 canonical 이름(`registry_path(sid).name`)과 실제 파일명 일치 강제 —
  숫자 별칭 warn-skip. 이름 SoT = registry_path.

## Self-Review Round 4 (수정 후)
- sweep의 solution_registry 경로 삽입(tools/solver) 정확 / fingerprint의 TRAIN 바이트 읽기는
  main당 1회 / dev fixture(stage990)는 canonical 검사 통과(zero-pad 불변 3자리) / None-digest
  스킵 불가는 캠페인 1~25(레벨 파일 전부 존재)에서 비발화. 신규 HIGH 0 — clean.

## 검증 (Round 4 수정)
- **probe 43/43 PASS**: 레벨 digest 변경/None/레거시 무-digest 재시도 + 숫자 별칭 3종
  (stage001/099/000) 미표시·covered 미오염 + canonical 정상 통과.
- 뷰어 오프라인 빌드 15해/12스테이지 불변.

## Round 5 (codex) — needs-attention (HIGH 1 + MEDIUM 2)
- **[HIGH] 영속화 실패가 done으로 박제**: train.py가 레지스트리 기록 실패(quarantine·락 타임아웃·
  FS 오류)를 삼키고 정상 종료 → 스윕이 rc·집계줄만 보고 done=true → **유일한 발견 해가 유실된
  채 영구 스킵**(경고는 스테이지 로그 안에만 잔존).
- **[MEDIUM] 지문이 전이적 의존 미포함**: train.py만 해시 — mdp/model/env/solve/Godot 드라이버
  변경이 지문에 안 잡혀 의미론이 바뀌어도 완료가 생존(R4 "트레이너 개정 무효화" 주장 불완전).
- **[MEDIUM] 레벨 digest None이 오염 허용**: record_clear가 None 불일치를 리셋 조건에서 제외해
  None-바인딩 레지스트리 생성/옛 digest 레지스트리에 추가 기록 가능. 뷰어 mismatch 검사도 양쪽
  truthy 요구라 None=비-stale로 통과. 캐시도 None==None 우연 일치 가능.

## 수정 (Round 5 — 전 3건)
- **H1**: train.py `_PERSIST_FAILURES` 회계(“기록 실패 삼킴·학습 지속” 계약은 유지하되
  _record_found/_record_partial 실패를 적재) + `_final_rc` — 완주 후 실패 ≥1이면 기계-판독
  마커(`=== 영속화 실패 N건(rc=3)`) 출력 + **rc=3**(신설, 0=클리어/1=무클리어/2=설정오류와
  구별). sweep run_ok({0,1})가 rc=3을 거부 → done=false → 자동 재시도. run_training 시작 시
  카운터 리셋(in-process 재호출 안전).
- **M1**: `FINGERPRINT_MANIFEST` — import 체인 실사(train→mdp/env/model, mdp→model/solve/
  landmarks, env→run_test/solve) + _exec_config_digest driver_files 미러(PlanRunner/SimConfig/
  PlanServerHarness/project.godot/capabilities.tres) + solution_registry(기록 의미론) = 14파일
  소스 sha를 지문에 포함. 파일 부재도 None으로 지문 반영(삭제=변경).
- **M2**: ① record_clear — 현재 digest None이면 `LevelUnverifiableError`(신설)로 기록 거부
  (레지스트리 미생성/미변경) ② 뷰어 — 저장/현재 digest 어느 쪽이든 None = 검증-불가 →
  미표시+파기-대기 표기(불일치와 동일 취급), `_partial_level_ok`도 무-digest 제외로 전환
  ③ 캐시 — binding digest None이면 읽기/쓰기 생략(None==None 불인정, in-memory 부착만).

## Self-Review Round 5 (수정 후)
- rc=3은 신규 코드(기존 0/1/2와 비충돌)·pinned verify 경로는 run_training 밖(별도 반환) /
  probe 스테이지 99가 digest None이 되므로 기록 테스트는 FAKE_LD 모킹(spawn 워커별 재적용) /
  P6 canonical 케이스는 실 stage01 digest로 갱신 / dev fixture(레벨 파일 없는 990+)는 캐시
  생략=매회 리플레이(느리지만 정직). 신규 HIGH 0 — clean.

## 검증 (Round 5 수정)
- **probe 51/51 PASS**: P7(digest None → 기록 거부·레지스트리 미생성 / 저장 None → 미표시+
  파기-대기 / 캐시 None==None 불인정) + P8(기록 실패 주입 → 회계 적재 → rc=3 격상 → 스윕 거부)
  + P4b 지문이 매니페스트 기반으로 재계산됨(기존 케이스 전부 유지).
- 뷰어 오프라인 빌드 15해/12스테이지 불변. pinned verify 4종 재실행(아래 R6 전 확인).

## Round 6 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] Godot 게임플레이 전이 의존이 모든 digest 밖**: 스테이지 씬이 ext_resource로 로드하는
  StageRunner/AntSpawner/Terrain/엔티티 씬/hazard 스크립트 변경이 campaign_fingerprint에도
  level_digest에도 안 잡힘 — 옛 스윕 완료가 스킵 가능하게 잔존하고 레지스트리/리플레이 캐시가
  바뀐 롤아웃 의미론에서도 수용됨.

## 수정 (Round 6) + 의도적 스코프 결정
- **`solution_registry.runtime_digest` 신설**: 정밀 per-stage 전이 폐쇄 대신 **coarse 과대포함**
  (scripts/**/*.gd + scenes/**(stages 제외 — per-stage는 level_digest 소관) +
  tests/PlanServerHarness.* + data/solver/** + project.godot; 프로세스당 캐시). 과잉 무효화는
  무해(스윕 재실행=dup, 캐시=재생성)하고 누락이 해악이므로 보수 방향 선택.
- **결속 2면**: ① 리플레이 캐시 키+payload `_cache`에 runtime_digest 추가(REPLAY_CACHE_SCHEMA
  2→3, 기존 캐시 전량 자동 미스) ② campaign_fingerprint에 `runtime` 멤버 추가(파이썬 매니페스트는
  유지, Godot 드라이버 6파일은 runtime_digest가 포섭하므로 매니페스트에서 이관).
- **레지스트리 파기 스코프는 레벨 한정 유지(의도적 결정, 문서화)**: §17 사용자 계약 ③의 파기
  트리거는 명시적으로 "레벨 변경"이다. 엔진 의미론 드리프트에 해를 **파기하는 대신**, 보고서의
  지표·궤적이 전부 결정론 리플레이 재검증(이제 엔진-결속 캐시)에서 나오므로 더 이상 안 풀리는
  해는 리플레이 결과로 정직하게 드러난다 — 발견 provenance를 보존하면서 정직성 유지. selftest/
  verify 게이트도 엔진 변경 시 저장 해를 재검증하는 기존 안전망.

## Self-Review Round 6 (수정 후)
- runtime_digest 정렬 순회 결정론(rel 경로 sorted) / dev fixture(레벨 파일 없음)는 P7 fail-closed
  경로 유지 / train.py 무변경(pinned verify 직전 4/4 유효). 신규 HIGH 0 — clean.

## 검증 (Round 6 수정)
- **probe 55/55 PASS**: P9 — 게임플레이 .gd 변경(.tscn 무변경) → runtime digest 변경 /
  scenes/stages 변경은 불변(level_digest 소관 분리) / runtime 변경 → 캐시 키·스윕 지문 변경.
- 뷰어 오프라인 빌드 15해/12스테이지 불변 + S11 --replay가 v3 키로 재생성·동일 결과
  (saved=4 frame=1342).

## Round 7 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] 리플레이 하니스가 runtime digest 밖**: runtime_digest가 PlanServerHarness.*만 포함
  — 뷰어 리플레이(solve.run_plan)가 실제로 띄우는 **PlanReplayHarness.gd/.tscn**(SOLVER_RESULT
  방출 의미론 보유) 변경이 캐시 키/결속에 안 잡혀 옛 캐시가 현재 것으로 수용됨.

## 수정 (Round 7)
- runtime_digest groups에 `tests/PlanReplayHarness.*` 추가(하니스 2종 전부 결속) + P9 확장
  (하니스 .gd/.tscn 각각 변경 → digest 변경 확인).

## 검증 (Round 7 수정)
- **probe 57/57 PASS** + S11 --replay 확장-digest 키로 재생성·동일 결과(saved=4 frame=1342)
  + 뷰어 오프라인 빌드 15해/12스테이지 불변. train.py 무변경(pinned verify 4/4 유효).

## Round 8 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] 리플레이 digest가 Python 드라이버·Godot 러너 누락**: 뷰어 리플레이는
  solve.run_plan → run_test.py 경유인데 runtime_digest가 solve.py/run_test.py 미포함 —
  플랜 직렬화·러너 인자·결과 파싱·Godot 선택이 바뀌어도 캐시 수용. 선택된 Godot 실행파일
  정체성도 미결속(엔진 업그레이드 후 이전-엔진 캐시 재사용 가능).

## 수정 (Round 8)
- runtime_digest에 `tools/solver/solve.py` + `scripts/run_test.py` 편입 + **Godot 실행파일
  정체성**(`_godot_identity` = find_godot resolved 경로, _exec_config_digest godot_binary 선례;
  해석 불가=None → 엔진-존재 시점 캐시와 자동 불일치=fail-closed) 해시 결속.
  REPLAY_CACHE_SCHEMA 3→4. 캐시는 머신-로컬(gitignore)이라 경로 결속의 cross-PC 비용 없음.
- P9 확장: solve.py/run_test.py 변경 → digest 변경 + **옛 runtime payload 캐시 미스 negative**.

## 검증 (Round 8 수정)
- **probe 60/60 PASS** + S11 --replay v4 키 재생성·동일 결과(saved=4 frame=1342) + 뷰어
  오프라인 빌드 15해/12스테이지 불변. train.py 무변경(pinned verify 4/4 유효).

## Round 9 (codex) — needs-attention (HIGH 1)
- **[HIGH] Godot 부재 시 오프라인 뷰어 종료**: `find_godot()`는 실패를 `sys.exit()`로 보고 —
  `SystemExit`은 `except Exception` 밖이라 `_godot_identity`가 None을 반환하는 대신 전파,
  엔진 없는 머신의 오프라인 빌드(캐시 결속 검사 경유)가 죽음.

## 수정 (Round 9)
- `except (Exception, SystemExit)`로 명시 확장(BaseException 광역 삼킴은 회피 — KeyboardInterrupt
  등은 전파 유지). P9에 SystemExit 주입 → identity None 회귀 추가.

## 검증 (Round 9 수정)
- **probe 61/61 PASS** + `GODOT_BIN=<존재하지 않는 경로>` 오프라인 빌드 정상 완료(exit 0,
  15해/12스테이지). train.py 무변경(pinned verify 4/4 유효).

## Round 10 (codex) — needs-attention (HIGH 2)
- **[HIGH] 리플레이-실패 해가 여전히 '클리어'로 표시**: _card가 등재 해의 rep['cleared'/'saved'/
  'frame']을 무시하고 역사적 저장값+클리어 배지 고정 — "리플레이가 무효 해를 드러낸다"는
  레벨-한정 파기 설계의 전제와 모순.
- **[HIGH] 같은 경로 엔진 교체 미검출**: identity가 resolved 경로만 해시 — 패키지 관리/고정
  경로 설치에서 엔진 업그레이드가 캐시·스윕 완료를 그대로 통과.

## 수정 (Round 10 — 전 2건)
- **H1**: _card — 등재 해에 리플레이 결과가 있으면 그것이 권위: 실패 시 `등재 해 · 현행 런타임
  리플레이 실패` 적색 배지 + 현행 실측값 표시 + data-cleared=false(필터/집계 제외, 카드 자체는
  provenance 보존). 성공 시에도 저장값 대신 현행 실측 saved/frame 우선. render 요약 =
  현행-클리어만 집계 + `리플레이 실패 N개(엔진 변경 의심)` 명시 표기.
- **H2**: `_godot_identity` = resolved 경로 + **바이너리 내용 스트리밍 sha16**(프로세스당 1회
  캐시 — 수백 MB 해시 비용 상각). 같은 경로 교체/업그레이드도 결속.

## Self-Review Round 7~10 누적 (수정 후)
- identity 캐시와 probe의 monkeypatch 상호작용(전후 캐시 클리어) 정리 / _card의 rep-우선
  분기가 부분해(cleared=False) 경로 불변 / render 요약의 ok_groups 분리가 파기-대기 표기와
  독립. 신규 HIGH 0 — clean.

## 검증 (Round 10 수정)
- **probe 66/66 PASS**: P9 같은-경로 엔진 교체 → digest 변경 / P10 리플레이 성공=클리어 배지·
  집계 포함, 실패=stale 배지·현행 실측값·집계 제외+요약 명시.
- S11 --replay 재생성(내용-결속 identity 키)·동일 결과(saved=4 frame=1342) + 뷰어 오프라인
  빌드 15해/12스테이지 불변(전부 리플레이-성공 해). train.py 무변경(pinned verify 4/4 유효).

## Round 11 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] 일시 리플레이 오류가 권위 판정으로 캐시**: run_plan의 인프라 오류 응답
  (`{"error":"no SOLVER_RESULT"}` — Godot 크래시 등)이 현재 runtime identity로 캐시돼 이후
  --replay가 재시도 없이 재사용 — 정상 등재 해가 뷰어 집계에서 무기한 제외.

## 수정 (Round 11)
- attach_replays: `error` 응답/`cleared` 불리언 부재 = 게임플레이 verdict 아님 → **캐시·부착
  모두 생략**(리플레이-불가로 두고 다음 --replay 재시도, 오류의 stale-판정 박제 금지). 캐시
  읽기 측도 동일 유효성 요구(과거 오염 캐시 방어).

## 검증 (Round 11 수정)
- **probe 70/70 PASS**: P11 — 1회차 오류 응답=부착·캐시 없음 → 2회차 --replay 재호출(재시도)
  → 정상 verdict 부착+캐시. 뷰어 오프라인 빌드 15해/12스테이지 불변. train.py 무변경.

## Round 12 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] `error: null` 키가 양쪽 가드 우회**: R11 수정이 값-검사(`is None`/`is not None`)라
  `{"error": null, "cleared": true}`가 부착·캐시됨 — 저장소 관례는 error **키 존재** 자체가
  인프라 실패.

## 수정 (Round 12)
- 키-존재 계약으로 정정: 신규 응답 `"error" in res` 거부 / 캐시 읽기 `"error" not in cached`
  요구. P11 확장 — null-값 error 신규 응답(부착·캐시 없음+재시도) + 오염 캐시(error:null
  잔존물) 불인정+재시도.

## 검증 (Round 12 수정)
- **probe 73/73 PASS**. 뷰어·train.py 추가 변경 없음(오프라인 빌드 15해/12스테이지 불변,
  pinned verify 4/4 유효).

## Round 13 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] migrate가 오염 캐시 payload 수용**: migrate()는 truthy cleared+trace만 확인 —
  `{error:null, cleared:true, trace:...}`가 record_clear로 흘러 권위 해로 승격 가능. 73-probe는
  attach_replays 경로만 커버(소비자별 가드 드리프트).

## 수정 (Round 13)
- **공유 검증기 단일화**: `solution_registry.valid_replay_payload`(dict / error 키 부재 /
  cleared 불리언 / binding 지정 시 `_cache` 정확 일치) + `cache_binding(stage_id)` 신설 —
  뷰어 읽기·신규 결과·migrate 3소비자가 전부 이 검증기 경유(found_viewer._cache_binding은
  위임으로 전환). migrate는 추가로 cleared is True + trace 요구.
- probe 자체 결함 1건 자체 발견·수정: P12 첫 작성본이 migrate 기본 `stage_max=25`에 걸려
  스테이지 99가 순회 제외 — 검증기가 아닌 범위 필터로 "차단"되던 가짜 통과. `stage_max=99`
  명시로 검증기를 실제로 관통시킴(양성 케이스가 이를 드러냄 — 음성-only probe의 함정).

## 검증 (Round 13 수정)
- **probe 76/76 PASS**: P12 — 오염 payload(error:null) 승격 차단 / 결속 불일치 차단 /
  유효 payload 정상 이행(신규 1). 뷰어 오프라인 빌드 15해/12스테이지 불변. train.py 무변경.

## Round 14 (codex) — needs-attention (HIGH 1)
- **[HIGH] 리플레이 부재가 클리어로 통과**: 런타임 변경이 캐시를 무효화하면 `_replay` 부재 —
  _card/render가 이를 성공과 동일 취급해 기본 오프라인 재빌드가 **미검증 해를 현행 클리어로
  보고**(R10 안전망이 캐시-미스로 우회).

## 수정 (Round 14)
- **3-상태 모델**: 등재 해 = 검증-클리어(ok, 리플레이 성공) / 검증-실패(failed) /
  **미검증(unverified, 리플레이 부재)**. 미검증 = 회색 `등재 해 · 미검증(현행 런타임 리플레이
  필요)` 배지 + 역사값 표시 + data-cleared=false(집계·필터 제외). render 요약 =
  `클리어(검증)`·`고유 해(검증)`만 집계 + 미검증/실패 별도 명시(`--replay` 안내).

## 검증 (Round 14 수정)
- **probe 77/77 PASS**(P10 확장: 리플레이 부재 카드 = unverified 배지·집계 제외 + 요약 3-상태).
- **전체 15해 현행-런타임 재검증**: `--replay --stages 1-25` → 15해 전부 리플레이 성공
  (S17 3해 f=3920/2403/3857 등), 최종 보고서 = 클리어(검증) 12스테이지·고유 해(검증) 15개·
  미검증 0·실패 0. train.py 무변경(pinned verify 4/4 유효).

## Round 15 (codex) — 미완(usage limit)
- R14 수정 재리뷰 요청이 ChatGPT usage limit으로 거부("try again at 2:51 PM") — 2026-07-12
  11:09 시점. R15는 quota 해제 후 동일 인자로 재실행 예정(그때까지 hot-fix 커밋 보류 —
  clean verdict 전 커밋 금지 정책).

## Round 15 (codex, quota 해제 후 재실행) — needs-attention (MEDIUM 2)
- **[MEDIUM] failed/미검증이 '미클리어' 필터로 오분류**: data-cleared 불리언만으로 필터링 —
  미클리어 선택 시 실패/미검증 등재 해가 부분해처럼 표시.
- **[MEDIUM] sweep state 중단-손상 취약**: 손상 무처리 로드(기동 좌초) + 직접 덮어쓰기
  (비원자) + 동시 러너 상호 덮어쓰기.

## 수정 (Round 15 — 전 2건)
- **M1**: 카드에 명시적 `data-state`(verified-clear/partial/failed/unverified) + 필터 4버튼
  (전체/클리어(검증)/미클리어/**요주의(실패·미검증)**) — JS가 상태 정확 매칭(불리언 필터 은퇴).
- **M2**: `_load_state`(손상 = quarantine 보존 후 빈 state 재시작 — 재시도는 dup-무해) +
  `_save_state`(프로세스-고유 tmp + os.replace 원자 교체) + **단일-러너 락**(sweep.lock,
  레지스트리와 동일 OS-수준 잠금, 러너 수명 보유 — 동시 스윕 거부 exit 1).

## 검증 (Round 15 수정)
- **probe 85/85 PASS**: P10 확장(4-상태 data-state 부여 + JS 정확-매칭·attention 필터·불리언
  필터 은퇴 구조 검증) + P13(손상 state quarantine·빈 재시작 / 원자 저장 라운드트립·tmp 무잔존 /
  동시 러너 락 거부). 뷰어 재빌드 = 클리어(검증) 12·고유 해(검증) 15 불변. train.py 무변경.

## Round 16 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] 손상-복구의 기동-크래시 잔여 경로**: `_load_state`가 UnicodeDecodeError(비-UTF8)
  미포착 + parse-valid 구조 위반(`{"stage01": null}`)이 state_entry_ok/attempts 산술에서
  AttributeError/ValueError — 어느 쪽이든 quarantine 없이 러너가 죽어 R15 내구성 목표 미달.

## 수정 (Round 16)
- `_load_state` catch에 UnicodeDecodeError 추가 / `state_entry_ok` 비-dict 엔트리 = 재시도
  가능(False) / `_prev_attempts` 헬퍼(비-dict·비수치 = 0 관용).
- **probe가 잡은 자체 결함 1건**: sweep quarantine 이름이 초-해상도라 같은 초 재격리가 선행본
  덮어씀(레지스트리 R3 자체수정과 동일 패턴) → 존재-검사 카운터 유일화.

## 검증 (Round 16 수정)
- **probe 90/90 PASS**: 비-UTF8 → quarantine+빈 재시작(재격리 보존 포함) / null·list 엔트리
  재시도(크래시 없음) / 비수치 attempts 관용. train.py·뷰어 무변경.

## Round 17 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] 레지스트리 쪽 비-UTF8 손상 미포착**: R16이 sweep state에만 적용 —
  `load_registry`의 UnicodeDecodeError는 RegistryCorruptError로 안 감싸져 quarantine 미진입,
  train.py가 rc=3을 반복해 해당 스테이지 스윕 완료가 무기한 차단.

## 수정 (Round 17)
- `load_registry` catch에 UnicodeDecodeError 추가(기존 quarantine 경로 합류). P1b 확장 —
  비-UTF8 레지스트리 bytes → 유일화 quarantine+RegistryCorruptError + 후속 기록 재시작.

## 검증 (Round 17 수정)
- **probe 92/92 PASS**. 뷰어·train.py 무변경(보고서·pinned verify 유효).

## Round 18 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] 뷰어가 비-UTF8 레지스트리에 크래시**: `load_registries`가 UnicodeDecodeError
  미포착 — canonical 레지스트리 1개 손상이 보고서 전체를 중단.

## 수정 (Round 18)
- 뷰어 warn-skip에 UnicodeDecodeError 추가 + **동일 클래스 잔여 read 경로 전부 선제 적용**
  (뷰어 사이드카/캐시/analysis 읽기 3곳 + solution_registry migrate 입력 2곳 — 5개 사이트
  일괄, 클래스 단위 종결로 두더지잡기 방지). P6 확장 — 비-UTF8 canonical 레지스트리 warn-skip.

## 검증 (Round 18 수정)
- **probe 92/92 PASS**(P6 케이스 흡수) + 뷰어 재빌드 15해/12스테이지 불변. train.py 무변경.

## Round 19 (codex) — needs-attention (MEDIUM 2)
- **[MEDIUM×2] JSONL 통파일 read_text 2곳이 per-line 핸들러 밖**: 뷰어 `_load_all`과
  `migrate`의 log.jsonl 읽기 — 비-UTF8 1바이트가 보고서 전체/이행 전체를 중단(R18 "전 사이트
  봉합" 주장의 누락 — except 절만 교체하고 통파일 디코드 지점을 놓침).

## 수정 (Round 19)
- 두 곳 모두 **bytes 읽기 + 라인 단위 독립 디코딩**으로 전환 — 손상 라인만 스킵, 유효 레코드
  생존(파일 OSError는 warn 후 빈 처리). P6 확장(손상 log/partials 라인 스킵+유효 생존) +
  P12 확장(손상 log 공존에도 사이드카 이행 계속).

## 검증 (Round 19 수정)
- **probe 94/94 PASS** + 뷰어 재빌드 15해/12스테이지 불변. train.py 무변경.

## Round 20 (codex) — needs-attention (MEDIUM 2)
- **[MEDIUM] parse-valid 구조 위반 JSONL이 뷰어 크래시**: `null`/`[]`/스칼라 라인·비-int
  stage_id·비-list actions가 디코더는 통과하고 rec.get/정렬/plan_key에서 사망.
- **[MEDIUM] migrate 이중 카운트 + 비멱등**: train.py가 같은 발견을 사이드카+log 이중 기재 —
  무dedup 연결로 runs 2배, 재실행마다 재증가(부분 실패 후 재시도가 카운트 오염).

## 수정 (Round 20 — 전 2건)
- **M1**: `_valid_record`(dict / stage_id int / seed int|None / actions list-of-dict / ts str)
  검증을 per-line·사이드카 경계 안에 편입 — 위반 warn-skip.
- **M2**: migrate에 ① 이벤트 정체성 `(stage,seed,ts,plan_key)` 선-dedup(이중 기재 1회화)
  ② 재실행 멱등 가드(동일 exec_digest 해에 seed 등재 + last_ts ≥ 이벤트 ts = 이미 이행 →
  record_clear 미호출) + 구조 위반 레코드 스킵.

## 검증 (Round 20 수정)
- **probe 97/97 PASS**: 구조 위반 6종 라인 전부 스킵+유효 생존 / 이중 기재 1회 카운트(runs=1) /
  migrate 재실행 runs·seeds 불변(멱등). 뷰어 재빌드 15해/12스테이지 불변. train.py 무변경.

## Round 21 (codex) — needs-attention (MEDIUM 3)
- **[MEDIUM] 얕은 action 검증**: actions 원소가 dict인 것만 확인 — `{"target":1}`·비수치
  frame이 plan_key/canon_action에서 뷰어 전체를 죽임.
- **[MEDIUM] migrate의 seed/ts 타입 무검증**: 문자열 seed가 등재되면 이후 int seed와 정렬
  TypeError로 이행 중단. bool이 int 검사 통과.
- **[MEDIUM] ts 고수위 멱등의 이벤트 유실**: 늦게 캐시-적격이 된 이전 실행-동치 이벤트가
  해의 공유 last_ts에 가려 영구 미카운트 + seed 간 혼동 + 락 밖 프리체크.

## 수정 (Round 21 — 전 3건)
- **M1·M2**: `valid_event_record` **공유 검증기**(solution_registry — 뷰어 `_valid_record`는
  위임): `type() is int`(bool 배제)·seed int|None·ts str·actions list-of-dict + **plan_key
  시험-평가**(canon이 실제 소화 못 하는 중첩 손상 전부 사전 거부). migrate 프리필터 교체
  (스킵 건수 warn).
- **M3**: ts 고수위 폐기 → **영속 이벤트-원장**: `event_id`(stage,seed,ts,plan_key sha16)를
  `record_clear(event=...)`로 전달, 해별 `events` 목록을 **락 안에서** 원자 검사 — 등재된
  이벤트는 무갱신 "dup", 미등재면 카운트+원장 추가. 라이브 학습 경로는 event 미지정(매 발견
  카운트, 동작 불변). 스키마 검증에 events(hex16 list, 선택) 추가.

## 검증 (Round 21 수정)
- **probe 101/101 PASS**: 중첩 action 손상 3종+타입 손상 3종 라인 스킵(뷰어) / migrate 타입
  손상 거부(runs·seeds 불변) / **R21-M3 반례 재현-해소**: 다른 plan_key·같은 trace의 이전
  이벤트가 캐시 부재 시 미이행 → 캐시 생성 후 재실행에서 회수(runs 1→2, 해 1개 유지, events
  2건) → 추가 재실행 멱등. 뷰어 재빌드 15해/12스테이지 불변. train.py 무변경(신규 kwarg
  기본값 경로 = 종전 동작).

## Round 22 (codex) — needs-attention (MEDIUM 1)
- **[MEDIUM] 손실 event_id의 충돌 유실**: event_id가 plan_key(60f 버킷·셀 양자화) 기반 —
  같은 초·같은 seed의 다른 raw 플랜(at_frame 60 vs 119)이 같은 ID로 붕괴, migrate가 캐시
  읽기 전에 dedup해 검증된 해 하나가 조용히 누락(train.py ts는 초 해상도).

## 수정 (Round 22)
- **train.py가 기록 생성 시 고유 event ID(uuid hex16) 부여**(_record_found/_record_partial —
  사이드카·jsonl 동반, 무충돌 SoT). event_id는 ① 부여 ID 우선 ② 레거시 폴백 = **무손실**
  digest(stage_id/seed/ts/stage 씬/deadline/**raw actions 전체** — 양자화 없음). 레거시에서
  같은 초·동일 raw 플랜의 진짜 별개 런은 이중 기재와 구별 불가(한계 문서화, v2부터 해소).
  뷰어 load_partials 정확-중복 키도 event_id로 통일(동일 손실 문제 선제 해소).

## 검증 (Round 22 수정)
- **probe 104/104 PASS**: 충돌 반례(같은 초·같은 plan_key·다른 raw actions·다른 trace) —
  event_id 비충돌 + **둘 다 이행**(해 1→3) / 부여 event ID 패스스루. 뷰어 재빌드 15해/
  12스테이지 불변. train.py 변경(event 필드 추가) → pinned verify 4종 재실행(아래 확인).

## Round 23 (codex) — **approve (종결)**
- "Ship: no material adversarial finding remains in the scoped Round 23 changes. Assigned event
  IDs propagate unchanged through dual-writes, the legacy fallback includes full raw-plan
  identity, and migration/viewer dedup share the corrected event_id path. No material findings."

## §17 사후 리뷰 루프 요약 (R1~R23)
- **23 codex 라운드**(HIGH 7 + MEDIUM 18 전건 수정, defer 0) + 자체 선제 수정 3건(O_EXCL
  stale-break 레이스 → OS-락 / quarantine 이름 충돌 ×2). 매 라운드 사이 자체 적대 리뷰.
- 주제 축: ① 레지스트리 내구성(락·quarantine·스키마+hex·digest-None 거부·이벤트 원장)
  ② 리플레이 캐시 정직성(레벨+runtime+파이썬 스택+엔진 바이너리 결속, 오류 payload 불인정)
  ③ 뷰어 3-상태 현행-런타임 판정(검증-클리어/실패/미검증 + 4-상태 필터) ④ 스윕 fail-closed
  (rc=3 영속화 격상, 지문=seeds+레시피+의존 매니페스트+레벨 digest, state 원자화·단일 러너)
  ⑤ 손상 클래스 일괄 봉합(무효 JSON·parse-valid 스키마 위반·비-hex·비-UTF8·구조 위반 라인).
- **최종 게이트**: registry_guard_probe **104/104** · pinned verify r0/r1@12/r2@11/r2@19
  **4/4**(train.py 3회 편집마다 재확인, 값 전부 종전 동일) · 전체 15해 현행-런타임 --replay
  재검증 클리어(보고서 "클리어(검증) 12 · 고유 해(검증) 15") · 뷰어 오프라인/replay/Godot-부재
  3모드 빌드 정상. 사용량 한도로 2회 중단·재개(부트스트랩: codex CLI alpha 채널 업그레이드).
